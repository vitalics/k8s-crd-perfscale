#!/usr/bin/env bash
# Delete every custom resource the benchmark created (all six kinds).
set -euo pipefail
CTX="${KUBE_CONTEXT:-$(kubectl config current-context)}"
kubectl --context "$CTX" delete --all --wait=false \
  addresses.compute.gcp.crossplane.io,firewalls.compute.gcp.crossplane.io,globaladdresses.compute.gcp.crossplane.io,networks.compute.gcp.crossplane.io,routers.compute.gcp.crossplane.io,subnetworks.compute.gcp.crossplane.io
