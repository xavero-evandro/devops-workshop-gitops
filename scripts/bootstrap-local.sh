#!/usr/bin/env bash
set -euo pipefail

K3D_CLUSTER_NAME="${K3D_CLUSTER_NAME:-workshop}"
K3D_SERVERS="${K3D_SERVERS:-1}"
K3D_AGENTS="${K3D_AGENTS:-1}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_MANIFEST_URL="${ARGOCD_MANIFEST_URL:-https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml}"
APP_MANIFEST_RELATIVE_PATH="${APP_MANIFEST_RELATIVE_PATH:-clusters/local/argocd/app-workshop.yaml}"

BACKEND_IMAGE="${BACKEND_IMAGE:-workshop-backend:local}"
FRONTEND_IMAGE="${FRONTEND_IMAGE:-workshop-frontend:local}"
IMPORT_LOCAL_IMAGES="${IMPORT_LOCAL_IMAGES:-true}"

log() {
  printf "\n[%s] %s\n" "$(date +"%H:%M:%S")" "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command not found: $1" >&2
    exit 1
  fi
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
app_manifest_path="$repo_root/$APP_MANIFEST_RELATIVE_PATH"

require_cmd kubectl
require_cmd k3d
require_cmd docker

if [[ ! -f "$app_manifest_path" ]]; then
  echo "Error: application manifest not found at $app_manifest_path" >&2
  exit 1
fi

log "Ensuring k3d cluster '$K3D_CLUSTER_NAME' exists"
if ! k3d cluster list "$K3D_CLUSTER_NAME" >/dev/null 2>&1; then
  k3d cluster create "$K3D_CLUSTER_NAME" \
    --servers "$K3D_SERVERS" \
    --agents "$K3D_AGENTS" \
    -p "80:80@loadbalancer" \
    -p "443:443@loadbalancer"
else
  log "k3d cluster '$K3D_CLUSTER_NAME' already exists, reusing it"
fi

log "Configuring kubectl context"
kubectl config use-context "k3d-$K3D_CLUSTER_NAME" >/dev/null

log "Installing Argo CD in namespace '$ARGOCD_NAMESPACE'"
kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$ARGOCD_NAMESPACE"
kubectl apply -n "$ARGOCD_NAMESPACE" -f "$ARGOCD_MANIFEST_URL"

log "Waiting for Argo CD deployments to become Available"
kubectl wait --for=condition=Available deployment --all -n "$ARGOCD_NAMESPACE" --timeout=300s

if [[ "$IMPORT_LOCAL_IMAGES" == "true" ]]; then
  log "Optionally importing local images into k3d"
  if docker image inspect "$BACKEND_IMAGE" >/dev/null 2>&1; then
    k3d image import "$BACKEND_IMAGE" -c "$K3D_CLUSTER_NAME"
  else
    log "Skipping backend image import (not found locally): $BACKEND_IMAGE"
  fi

  if docker image inspect "$FRONTEND_IMAGE" >/dev/null 2>&1; then
    k3d image import "$FRONTEND_IMAGE" -c "$K3D_CLUSTER_NAME"
  else
    log "Skipping frontend image import (not found locally): $FRONTEND_IMAGE"
  fi
fi

log "Applying Argo CD Application for local overlay"
kubectl apply -f "$app_manifest_path"

log "Done. Useful checks:"
echo "  kubectl get applications -n $ARGOCD_NAMESPACE"
echo "  kubectl get pods -n workshop-local"
echo "  open http://app.localtest.me"
echo "  open http://api.localtest.me"
