# argocd-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: ${ARGOCD_NAMESPACE}
  annotations:
    # 1. Tell Cert-Manager to use our production issuer
    cert-manager.io/cluster-issuer: letsencrypt-prod
    # 2. Enable backend TLS for Argo CD's gRPC backend
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  # 3. Specify the Ingress Controller Class (the modern way)
  ingressClassName: nginx
  # 4. Define TLS configuration
  tls:
  - hosts:
    - ${ARGOCD_FQDN}
    secretName: argocd-tls-prod # Cert-Manager will create this secret
  # 5. Define routing rules
  rules:
  - host: ${ARGOCD_FQDN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              name: https