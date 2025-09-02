#!/bin/bash

# This script provisions all necessary Azure infrastructure.
# - Azure Resource Group
# - AKS Cluster with Workload Identity
# - Entra ID App Registration, Groups, and Federated Credentials

# Exit immediately if a command exits with a non-zero status.
set -e

# Load environment variables
source ./env.sh

echo "--- 1. Creating Azure Resource Group: ${RESOURCE_GROUP} ---"
az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" -o none

echo "--- 2. Creating AKS Cluster: ${CLUSTER_NAME} ---"
az aks create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${CLUSTER_NAME}" \
  --node-count 2 \
  --enable-aad \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --generate-ssh-keys -o none

echo "--- 3. Getting AKS Credentials ---"
az aks get-credentials --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --overwrite-existing

echo "--- 4. Creating Entra ID App Registration: ${ENTRA_APP_DISPLAY_NAME} ---"
APP_ID=$(az ad app create \
  --display-name "${ENTRA_APP_DISPLAY_NAME}" \
  --web-redirect-uris "https://${ARGOCD_FQDN}/auth/callback" \
  --public-client-redirect-uris "http://localhost:8085/auth/callback" \
  --query appId -o tsv)

echo "--- 5. Creating Entra ID Groups ---"
az ad group create --display-name "${ENTRA_ADMIN_GROUP_NAME}" --mail-nickname "${ENTRA_ADMIN_GROUP_NAME}" -o none
az ad group create --display-name "${ENTRA_READONLY_GROUP_NAME}" --mail-nickname "${ENTRA_READONLY_GROUP_NAME}" -o none

echo "--- 6. Adding current user to ${ENTRA_ADMIN_GROUP_NAME} group ---"
CURRENT_USER_ID=$(az ad signed-in-user show --query id -o tsv)
az ad group member add --group "${ENTRA_ADMIN_GROUP_NAME}" --member-id "${CURRENT_USER_ID}" -o none
echo "Current user added successfully."

echo "--- 7. Configuring Federated Credentials ---"
AKS_OIDC_ISSUER=$(az aks show --name "${CLUSTER_NAME}" -g "${RESOURCE_GROUP}" --query "oidcIssuerProfile.issuerUrl" -o tsv)
az ad app federated-credential create --id "${APP_ID}" --parameters \
"{\"name\": \"argocd-server-federated-cred\", \"issuer\": \"${AKS_OIDC_ISSUER}\", \"subject\": \"system:serviceaccount:${ARGOCD_NAMESPACE}:argocd-server\", \"audiences\": [\"api://AzureADTokenExchange\"]}" -o none

echo "--- 8. Configuring Token Group Claims ---"
az ad app update --id "${APP_ID}" --set groupMembershipClaims=SecurityGroup -o none

# Persist dynamic variables for subsequent scripts
echo "export APP_ID=${APP_ID}" > ./scripts/generated-variables.sh
ADMIN_GROUP_OID=$(az ad group show --group "${ENTRA_ADMIN_GROUP_NAME}" --query id -o tsv)
READONLY_GROUP_OID=$(az ad group show --group "${ENTRA_READONLY_GROUP_NAME}" --query id -o tsv)
echo "export ADMIN_GROUP_OID=${ADMIN_GROUP_OID}" >> ./scripts/generated-variables.sh
echo "export READONLY_GROUP_OID=${READONLY_GROUP_OID}" >> ./scripts/generated-variables.sh

echo "✅ Infrastructure setup complete."
