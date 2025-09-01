#!/bin/bash

# This script installs the core Kubernetes components required for the setup.
# - NGINX Ingress Controller
# - Cert-Manager
# - Argo CD

set -e
source ./env.sh

echo "--- 1. Installing NGINX Ingress Controller ---"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --create-namespace \
  --namespace "${INGRESS_NAMESPACE}"

echo "--- 2. Installing Cert-Manager ---"
helm install \
  cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.18.2 \
  --namespace "${CERT_MANAGER_NAMESPACE}" \
  --create-namespace \
  --set installCRDs=true

echo "--- 3. Installing Argo CD ---"
kubectl create namespace "${ARGOCD_NAMESPACE}"
kubectl apply -n "${ARGOCD_NAMESPACE}" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "--- Waiting for Ingress IP Address... ---"
# Loop until the ingress controller gets a public IP
while true; do
    INGRESS_IP=$(kubectl get service ingress-nginx-controller -n "${INGRESS_NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [[ -n "$INGRESS_IP" ]]; then
        echo "✅ Ingress Controller IP Address: ${INGRESS_IP}"
        break
    fi
    echo "Still waiting for IP..."
    sleep 10
done

echo ""
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!!! MANUAL ACTION REQUIRED !!!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "You must now create a DNS 'A' record for your domain '${ARGOCD_FQDN}'."
echo "Point the A record to the following IP address: ${INGRESS_IP}"
echo "Wait for the DNS to propagate before running the next script."
echo ""
