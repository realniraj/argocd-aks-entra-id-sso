#!/bin/bash

# This script provisions all necessary Azure infrastructure.
# - Azure Resource Group
# - Entra ID Group for AKS Administration
# - AKS Cluster with AAD integration and local admin disabled
# - Entra ID App Registration, Groups, and Federated Credentials for Argo CD

# Exit immediately if a command exits with a non-zero status.
set -e

# Load user-defined variables
source ./env.sh

echo "--- 1. Creating Azure Resource Group: ${RESOURCE_GROUP} ---"
az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" -o none

echo "--- 2. Setting up Entra ID Group for AKS Administration ---"
echo "Creating Entra ID group: ${AKS_ADMIN_GROUP_NAME}"
AKS_ADMIN_GROUP_ID=$(az ad group create --display-name "${AKS_ADMIN_GROUP_NAME}" --mail-nickname "${AKS_ADMIN_GROUP_NAME}" --query id -o tsv)
echo "Adding currently logged-in user to ${AKS_ADMIN_GROUP_NAME} group..."
CURRENT_USER_ID=$(az ad signed-in-user show --query id -o tsv)
az ad group member add --group "${AKS_ADMIN_GROUP_NAME}" --member-id "${CURRENT_USER_ID}" -o none
echo "Current user added successfully."

echo "--- 3. Creating AKS Cluster: ${CLUSTER_NAME} ---"
# Note: We disable local accounts for enhanced security and use the AAD group for admin access.
az aks create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${CLUSTER_NAME}" \
  --node-count 2 \
  --enable-aad \
  --enable-oidc-issuer \
  --aad-admin-group-object-ids "${AKS_ADMIN_GROUP_ID}" \
  --disable-local-accounts \
  --enable-workload-identity \
  --generate-ssh-keys -o none

echo "--- 4. Getting AKS Credentials ---"
# This will configure kubectl to use the AAD login flow.
az aks get-credentials --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --overwrite-existing
kubelogin convert-kubeconfig -l azurecli

echo "--- 5. Creating Entra ID App Registration for Argo CD: ${ENTRA_APP_DISPLAY_NAME} ---"
APP_ID=$(az ad app create \
  --display-name "${ENTRA_APP_DISPLAY_NAME}" \
  --web-redirect-uris "https://${ARGOCD_FQDN}/auth/callback" \
  --public-client-redirect-uris "http://localhost:8085/auth/callback" \
  --query appId -o tsv)

echo "--- 6. Creating Entra ID Groups for Argo CD Roles ---"
az ad group create --display-name "${ENTRA_ADMIN_GROUP_NAME}" --mail-nickname "${ENTRA_ADMIN_GROUP_NAME}" -o none
az ad group create --display-name "${ENTRA_READONLY_GROUP_NAME}" --mail-nickname "${ENTRA_READONLY_GROUP_NAME}" -o none

echo "Adding current user to ${ENTRA_ADMIN_GROUP_NAME} group for Argo CD testing..."
az ad group member add --group "${ENTRA_ADMIN_GROUP_NAME}" --member-id "${CURRENT_USER_ID}" -o none
echo "Current user added successfully."

echo "--- 7. Configuring Federated Credentials for Argo CD App ---"
AKS_OIDC_ISSUER=$(az aks show --name "${CLUSTER_NAME}" -g "${RESOURCE_GROUP}" --query "oidcIssuerProfile.issuerUrl" -o tsv)
az ad app federated-credential create --id "${APP_ID}" --parameters \
"{\"name\": \"argocd-server-federated-cred\", \"issuer\": \"${AKS_OIDC_ISSUER}\", \"subject\": \"system:serviceaccount:${ARGOCD_NAMESPACE}:argocd-server\", \"audiences\": [\"api://AzureADTokenExchange\"]}" -o none

echo "--- 8. Granting API Permissions and Admin Consent ---"
# Grant User.Read permission to allow Argo CD to read user profile information
az ad app permission add --id "${APP_ID}" --api 00000003-0000-0000-c000-000000000000 --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope
# Grant admin consent to suppress the user consent prompt on first login
az ad app permission admin-consent --id "${APP_ID}"
echo "Admin consent granted for User.Read permission."

echo "--- 9. Configuring Token Group Claims for Argo CD App ---"
az ad app update --id "${APP_ID}" --set groupMembershipClaims=SecurityGroup -o none

# Persist dynamic variables for subsequent scripts
echo "export APP_ID=${APP_ID}" > ./scripts/generated-variables.sh
ADMIN_GROUP_OID=$(az ad group show --group "${ENTRA_ADMIN_GROUP_NAME}" --query id -o tsv)
READONLY_GROUP_OID=$(az ad group show --group "${ENTRA_READONLY_GROUP_NAME}" --query id -o tsv)
echo "export ADMIN_GROUP_OID=${ADMIN_GROUP_OID}" >> ./scripts/generated-variables.sh
echo "export READONLY_GROUP_OID=${READONLY_GROUP_OID}" >> ./scripts/generated-variables.sh

echo "✅ Infrastructure setup complete."

