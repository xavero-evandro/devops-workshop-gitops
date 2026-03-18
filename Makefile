DEFAULT_GOAL := help

.PHONY: help local-up local-status local-down

help:
	@echo "Available targets:"
	@echo "  make local-up      # Bootstrap/reconcile local k3d + Argo CD"
	@echo "  make local-status  # Show local cluster/application status"
	@echo "  make local-down    # Destroy local k3d cluster"

local-up:
	./scripts/bootstrap-local.sh

local-status:
	./scripts/status-local.sh

local-down:
	./scripts/destroy-local.sh
