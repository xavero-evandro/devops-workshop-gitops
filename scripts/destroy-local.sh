#!/usr/bin/env bash
set -euo pipefail

K3D_CLUSTER_NAME="${K3D_CLUSTER_NAME:-workshop}"

log() {
  printf "\n[%s] %s\n" "$(date +"%H:%M:%S")" "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command not found: $1" >&2
    exit 1
  fi
}

require_cmd k3d

log "Checking for k3d cluster '$K3D_CLUSTER_NAME'"
if k3d cluster list "$K3D_CLUSTER_NAME" >/dev/null 2>&1; then
  log "Deleting cluster '$K3D_CLUSTER_NAME'"
  k3d cluster delete "$K3D_CLUSTER_NAME"
  log "Cluster deleted"
else
  log "Cluster '$K3D_CLUSTER_NAME' does not exist; nothing to delete"
fi
