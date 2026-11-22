.DEFAULT_GOAL := help
.PHONY: help deps converge verify

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

deps: ## Install the ansible collections (user-level, per-project)
	ansible-galaxy collection install -r ansible/requirements.yml

converge: ## Idempotent fleet converge (guest manifests -> running)
	@set -a; . local/pve-api.env; set +a; \
		ANSIBLE_CONFIG=ansible/ansible.cfg \
		ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml

verify: ## Drift check: converge in check mode with diffs (read-only)
	@set -a; . local/pve-api.env; set +a; \
		ANSIBLE_CONFIG=ansible/ansible.cfg \
		ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml --check --diff
