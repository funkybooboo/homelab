.DEFAULT_GOAL := help
.PHONY: help deps converge verify update

ENVFILES := $(wildcard local/*.env)

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

deps: ## Install the ansible collections (user-level, per-project)
	ansible-galaxy collection install -r ansible/requirements.yml

converge: ## Idempotent fleet converge (guest manifests -> running)
	@set -a; for f in $(ENVFILES); do . $$f; done; set +a; \
		ANSIBLE_CONFIG=ansible/ansible.cfg \
		ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml

pins: ## Roll pinned releases to upstream latest (edit role defaults; then commit + converge)
	@bash scripts/roll-pins.sh

update: ## Patch pass: pin roll + tier-gated dist-upgrade, never reboots (OPS-23)
	@bash scripts/roll-pins.sh
	@set -a; for f in $(ENVFILES); do . $$f; done; set +a; \
		ANSIBLE_CONFIG=ansible/ansible.cfg \
		ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/maintenance.yml

verify: ## Drift check: converge in check mode with diffs (read-only)
	@set -a; for f in $(ENVFILES); do . $$f; done; set +a; \
		ANSIBLE_CONFIG=ansible/ansible.cfg \
		ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml --check --diff
