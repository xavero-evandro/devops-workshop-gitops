# DevOps Workshop GitOps

GitOps repository for deploying the **workshop application** with **Kustomize overlays** and **Argo CD**.

This repo currently supports these environments:

- `dev`
- `staging`
- `prod`
- `local` (for k3d)

---

## Repository Layout

```text
apps/
  workshop/
    base/                 # Base Kubernetes manifests (deployments/services)
    overlays/
      dev/                # Environment-specific image tags + ingress
      staging/
      prod/
      local/              # Local k3d-friendly overlay

clusters/
  dev/argocd/app-workshop.yaml
  staging/argocd/app-workshop.yaml
  prod/argocd/app-workshop.yaml
  local/argocd/app-workshop.yaml
```

---

## How GitOps Works Here

Each `clusters/<env>/argocd/app-workshop.yaml` file defines an Argo CD `Application` that points to one overlay under `apps/workshop/overlays/<env>`.

Argo CD then:

1. pulls this repository,
2. renders the selected Kustomize overlay,
3. syncs the resources into the target namespace.

---

## Local Development with k3d + Argo CD

This setup lets you run the same GitOps pattern locally.

### Quick start (one command)

```bash
./scripts/bootstrap-local.sh
```

The script is idempotent (safe to run multiple times):

- creates/reuses the `workshop` k3d cluster,
- installs (or reconciles) Argo CD in `argocd`,
- applies `clusters/local/argocd/app-workshop.yaml`,
- optionally imports `workshop-backend:local` and `workshop-frontend:local` if they exist locally.

Optional overrides:

```bash
K3D_CLUSTER_NAME=workshop \
K3D_SERVERS=1 \
K3D_AGENTS=1 \
IMPORT_LOCAL_IMAGES=true \
./scripts/bootstrap-local.sh
```

### Local lifecycle scripts

```bash
# Bootstrap or reconcile local environment
./scripts/bootstrap-local.sh

# See cluster/app health quickly
./scripts/status-local.sh

# Destroy local k3d cluster
./scripts/destroy-local.sh
```

Optional cluster name override:

```bash
K3D_CLUSTER_NAME=workshop ./scripts/status-local.sh
K3D_CLUSTER_NAME=workshop ./scripts/destroy-local.sh
```

### Makefile shortcuts

```bash
make
make local-up
make local-status
make local-down
```

`make` (without arguments) prints the available local targets.

You can still pass environment variables when needed:

```bash
K3D_CLUSTER_NAME=workshop make local-status
K3D_CLUSTER_NAME=workshop make local-down
```

### 1) Prerequisites

- Docker
- k3d
- kubectl
- Argo CD CLI (`argocd`) _(optional but useful)_

### 2) Create a local k3d cluster

Create a cluster and expose HTTP/HTTPS ingress ports:

```bash
k3d cluster create workshop \
  --servers 1 \
  --agents 1 \
  -p "80:80@loadbalancer" \
  -p "443:443@loadbalancer"
```

### 3) Install Argo CD in the cluster

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available deploy/argocd-server -n argocd --timeout=180s
```

### 4) Bootstrap the local app via Argo CD

Apply the local Argo CD `Application` manifest from this repo:

```bash
kubectl apply -f clusters/local/argocd/app-workshop.yaml
```

This deploys the `apps/workshop/overlays/local` overlay into namespace `workshop-local`.

### 5) Provide local images to k3d

The local overlay expects these images:

- `workshop-backend:local`
- `workshop-frontend:local`

If you build images locally, import them into k3d:

```bash
k3d image import workshop-backend:local -c workshop
k3d image import workshop-frontend:local -c workshop
```

> If you prefer using a remote registry instead, update `apps/workshop/overlays/local/kustomization.yml` image mappings.

### 6) Access the app

The local ingress uses:

- `http://app.localtest.me`
- `http://api.localtest.me`

`localtest.me` resolves to `127.0.0.1`, so this works out of the box on most machines.

---

## Day-2 Operations

- Update image tags per environment in `apps/workshop/overlays/<env>/kustomization.yml`
- Commit and push changes
- Argo CD auto-sync applies the new desired state

---

## Useful Checks

Render a specific overlay locally:

```bash
kubectl kustomize apps/workshop/overlays/local
kubectl kustomize apps/workshop/overlays/dev
```

Check Argo CD applications:

```bash
kubectl get applications -n argocd
```

---

## Cleanup

```bash
k3d cluster delete workshop
```
