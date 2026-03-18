#!/usr/bin/env bash
set -euo pipefail

K3D_CLUSTER_NAME="${K3D_CLUSTER_NAME:-workshop}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
APP_NAMESPACE="${APP_NAMESPACE:-workshop-local}"
APP_NAME="${APP_NAME:-workshop-local}"

log() {
  printf "\n[%s] %s\n" "$(date +"%H:%M:%S")" "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command not found: $1" >&2
    exit 1
  fi
}

require_cmd kubectl
require_cmd k3d

log "k3d cluster status"
k3d cluster list "$K3D_CLUSTER_NAME" || true

if ! k3d cluster list "$K3D_CLUSTER_NAME" >/dev/null 2>&1; then
  log "Cluster '$K3D_CLUSTER_NAME' not found. Run ./scripts/bootstrap-local.sh first."
  exit 0
fi

log "Using kubectl context k3d-$K3D_CLUSTER_NAME"
kubectl config use-context "k3d-$K3D_CLUSTER_NAME" >/dev/null

log "Argo CD pods ($ARGOCD_NAMESPACE)"
kubectl get pods -n "$ARGOCD_NAMESPACE" || true

log "Argo CD application ($APP_NAME)"
kubectl get application "$APP_NAME" -n "$ARGOCD_NAMESPACE" -o wide || true

log "Workshop namespace resources ($APP_NAMESPACE)"
kubectl get all -n "$APP_NAMESPACE" || true

log "Ingress ($APP_NAMESPACE)"
kubectl get ingress -n "$APP_NAMESPACE" || true

echo
echo "URLs:"
echo "  http://app.localtest.me"
echo "  http://api.localtest.me"
