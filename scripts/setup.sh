#!/usr/bin/env bash
# Prepare a cluster for the benchmark and print the env for perfscale:
#   eval "$(scripts/setup.sh)"
# 1. Applies the Crossplane provider-gcp CRDs (the same set HariKube's
#    Makefile applies; no provider/controller is installed — the test only
#    measures the API server + storage).
# 2. Creates a ServiceAccount allowed to create/list compute.gcp.crossplane.io
#    objects and mints a token for it. perfscale's std/http authenticates with
#    a bearer token instead of the k6 script's client certificate (mTLS).
set -euo pipefail
CTX="${KUBE_CONTEXT:-$(kubectl config current-context)}"
K="kubectl --context $CTX"
NS="${NAMESPACE:-default}"
PROVIDER_GCP_REF="${PROVIDER_GCP_REF:-master}"

work="${TMPDIR:-/tmp}/provider-gcp"
[[ -d "$work" ]] || git clone -q --depth 1 --branch "$PROVIDER_GCP_REF" \
  https://github.com/crossplane-contrib/provider-gcp.git "$work" >&2
$K apply -f "$work/package/crds/" >/dev/null

$K apply -f - >/dev/null <<YAML
apiVersion: v1
kind: ServiceAccount
metadata: { name: perfscale-bench, namespace: $NS }
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata: { name: perfscale-bench }
rules:
  - apiGroups: [compute.gcp.crossplane.io]
    resources: ["*"]
    verbs: [create, get, list, delete, deletecollection]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: { name: perfscale-bench }
roleRef: { apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: perfscale-bench }
subjects: [{ kind: ServiceAccount, name: perfscale-bench, namespace: $NS }]
YAML

echo "export API_ENDPOINT=$($K config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
echo "export API_TOKEN=$($K -n "$NS" create token perfscale-bench --duration "${TOKEN_TTL:-2h}")"
