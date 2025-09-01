apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: ${ARGOCD_NAMESPACE}
  annotations:
    cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER_NAME}
    cert-manager.io/certificate-name: argocd-tls-cert
spec:
  ingressClassName: nginx
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
              number: 80
  tls:
  - hosts:
    - ${ARGOCD_FQDN}
    secretName: argocd-tls-cert
