#!/bin/bash

# This script tears down all resources created by the deployment scripts.

set -e
source ./env.sh
source ./scripts/generated-variables.sh

echo "This script will delete all Azure and Kubernetes resources defined in env.sh."
read -p "Are you sure you want to continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

echo "--- 1. Deleting Entra ID App Registration: ${ENTRA_APP_DISPLAY_NAME} ---"
az ad app delete --id "${APP_ID}"

echo "--- 2. Deleting Entra ID Groups ---"
az ad group delete --group "${ENTRA_ADMIN_GROUP_NAME}"
az ad group delete --group "${ENTRA_READONLY_GROUP_NAME}"

echo "--- 3. Deleting Azure Resource Group: ${RESOURCE_GROUP} ---"
# This will delete the AKS cluster and all associated resources.
az group delete --name "${RESOURCE_GROUP}" --yes --no-wait

echo "✅ Cleanup process initiated. It may take several minutes for the resource group to be fully deleted in Azure."
