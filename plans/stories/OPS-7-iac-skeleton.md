# OPS-7: The IaC skeleton

As the operator, I want the converge loop -- Debian CT template role,
the guest manifest format, `make converge` -- so that a guest is one
YAML + one role.

**Status**: planned
**Arc**: v2

## Acceptance criteria

- [ ] `guests/*.yaml` manifest format: name, vmid, template, resources,
      IP, mounts
- [ ] Ansible playbooks data-driven from the manifests via
      community.proxmox; idempotent re-run proven
- [ ] `make converge` + `make verify` targets; access path per
      [../issues.md](../issues.md) item 4 = (a): one subnet router,
      `tailscale serve` fronts only on TLS-worthy hosts
- [ ] Adding a test guest from manifest to running service works
      end-to-end

## Notes

Ansible-only, no Terraform state layer (the 2026-11-05 research
decision; bpg stays the recorded fallback). Design record:
[../design/greenfield-rebuild.md](../design/greenfield-rebuild.md)
(tooling + repo layout).
