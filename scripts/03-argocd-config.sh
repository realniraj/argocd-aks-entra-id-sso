#!/bin/bash

# This script configures the Argo CD installation.
# - Creates the ClusterIssuer for Let's Encrypt.
# - Creates the Ingress resource for Argo CD.
# - Safely patches the existing Argo CD ConfigMaps with OIDC and RBAC settings.
# - Optionally disables the local admin user.

set -e
source ./env.sh
source ./scripts/generated-variables.sh

echo "--- 1. Applying Cert-Manager ClusterIssuer Manifest ---"
envsubst < ./manifests/letsencrypt-issuer.yaml.tpl | kubectl apply -f -

echo "--- 2. Applying Argo CD Ingress Manifest ---"
envsubst < ./manifests/argocd-ingress.yaml.tpl | kubectl apply -f -
echo "Waiting for Cert-Manager to issue certificate for ${ARGOCD_FQDN}..."
sleep 15 # Give the ingress controller a moment to process the new resource
kubectl wait --for=condition=ready certificate -n "${ARGOCD_NAMESPACE}" argocd-tls-prod --timeout=300s

echo "--- 3. Annotating Argo CD Service Account for Workload Identity ---"
kubectl annotate serviceaccount argocd-server -n "${ARGOCD_NAMESPACE}" \
  "azure.workload.identity/client-id=${APP_ID}" \
  "azure.workload.identity/tenant-id=${TENANT_ID}" --overwrite

echo "--- 4. Patching Argo CD ConfigMaps with OIDC and RBAC settings ---"
# Create a temporary patch file from the template for argocd-cm
envsubst < ./manifests/argocd-cm.yaml.tpl > ./manifests/argocd-cm.yaml.tmp
# Patch the live ConfigMap using the temporary file
kubectl patch configmap argocd-cm -n "${ARGOCD_NAMESPACE}" --patch-file ./manifests/argocd-cm.yaml.tmp
# Clean up the temporary file
rm ./manifests/argocd-cm.yaml.tmp

# Create a temporary patch file from the template for argocd-rbac-cm
envsubst < ./manifests/argocd-rbac-cm.yaml.tpl > ./manifests/argocd-rbac-cm.yaml.tmp
# Patch the live ConfigMap using the temporary file
kubectl patch configmap argocd-rbac-cm -n "${ARGOCD_NAMESPACE}" --patch-file ./manifests/argocd-rbac-cm.yaml.tmp
# Clean up the temporary file
rm ./manifests/argocd-rbac-cm.yaml.tmp

echo "--- 5. Restarting Argo CD Server to apply changes ---"
kubectl rollout restart deployment argocd-server -n "${ARGOCD_NAMESPACE}"
kubectl rollout status deployment argocd-server -n "${ARGOCD_NAMESPACE}"

echo "✅ Argo CD configuration complete."
echo "Your Argo CD instance is available at: https://${ARGOCD_FQDN}"
echo ""
echo "--- Optional Next Step: Disable Local Admin User ---"
echo "Once you have verified that SSO login is working, you can harden your installation by disabling the local 'admin' user."
echo "To do this, run the following command:"
echo "kubectl patch cm argocd-cm -n ${ARGOCD_NAMESPACE} -p '{\"data\":{\"admin.enabled\":\"false\"}}' && kubectl rollout restart deployment argocd-server -n ${ARGOCD_NAMESPACE}"

