apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: ${ARGOCD_NAMESPACE}
data:
  url: https://${ARGOCD_FQDN}
  oidc.config: |
    name: Microsoft
    issuer: https://login.microsoftonline.com/${TENANT_ID}/v2.0
    clientID: ${APP_ID}
    azure:
      useWorkloadIdentity: true
    requestedIDTokenClaims:
      groups:
        essential: true
    requestedScopes:
    - openid
    - profile
    - email
