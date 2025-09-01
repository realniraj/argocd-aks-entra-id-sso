apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: ${ARGOCD_NAMESPACE}
data:
  policy.csv: |
    g, ${ADMIN_GROUP_OID}, role:admin
    g, ${READONLY_GROUP_OID}, role:readonly
