.DEFAULT_GOAL := help
.PHONY: help converge verify

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

converge: ## v2 (OPS-7): idempotent fleet converge. Stub until the ansible skeleton lands.
	@echo "converge: lands with the v2 IaC skeleton (plans/stories/OPS-7-iac-skeleton.md)."
	@echo "Until then the live bring-up tooling is scripts/revive-node.sh (v1 revival)."

verify: ## v2 (OPS-7/OPS-15): check-mode drift diff. Stub until the ansible skeleton lands.
	@echo "verify: lands with the v2 IaC skeleton; becomes the drift detector (OPS-15)."
	@echo "Read-only checks that exist today: scripts/revive-node.sh --survey <ip>."
