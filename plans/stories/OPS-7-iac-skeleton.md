# OPS-7: The IaC skeleton

As the operator, I want the converge loop -- Debian CT template role,
the guest manifest format, `make converge` -- so that a guest is one
YAML + one role.

**Status**: done (shipped 2026-11-22, same day as the v1.5 close
-- the era flip ran straight into the greenfield)
**Arc**: v2

## Acceptance criteria

- [x] `guests/*.yaml` manifest format: name, vmid, template, resources,
      IP, mounts -- done: guests/README.md documents the format +
      the VMID (infra 1xx / services 2xx / test 299) + IP conventions
      (infra .11-.19, services .50-.99); bash-parsed group_vars keys
      untouched
- [x] Ansible playbooks data-driven from the manifests via
      community.proxmox; idempotent re-run proven -- done: second
      converge run = changed=0 on EVERY host (create-if-missing with
      update:false, guarded bootstrap, structural add_host marked
      not-changed)
- [x] `make converge` + `make verify` targets; access path per
      [../issues.md](../issues.md) item 4 = (a): one subnet router,
      `tailscale serve` fronts only on TLS-worthy hosts -- done:
      both targets real (verify = --check --diff, read-only proven:
      check-mode-safe guards on the shell bootstrap + the version
      probe). No per-CT tailscale anywhere in the skeleton; serve
      fronts wire per-service later
- [x] Adding a test guest from manifest to running service works
      end-to-end -- done: guests/test.yaml -> CT 299 @ 192.168.1.50
      -> bootstrap via pct exec (no root ssh) -> guest_common
      (good-ssh) -> nginx proof page verified via curl

## As-built notes (module traps, for every later service story)

- community.proxmox 2.1.0: proxmoxer >= 2.3 REQUIRED (Debian trixie
  ships 2.2.0 -> node_glue pip-overlays the newer one + asserts the
  import); proxmox_template takes an explicit `node` param;
  state=present creates, state=started only STARTS (two tasks);
  `disk` must be the volid form `storage:GB` or the non-root token
  hits "Only root can pass arbitrary filesystem paths";
  `update` defaults TRUE (every run re-applies + reports changed) --
  skeleton pins update:false, resource changes run one-off via
  `-e guest_update=true`; api_token_id takes the full user!token
  form natively.
- pct on PVE 9.2: `pct push` has no --mkdir and reads the source ON
  THE NODE (stage the key via ansible copy first); pct under
  non-root ssh = ipcc ENOTCONN, always run it through ansible's
  become (sudo).
- Debian 13 CT: socket-activated ssh crashes on reload (the socket
  owns port 22) -- guest_common disables ssh.socket and runs the
  plain service. getent exits 2 for a missing user (the bootstrap
  probe normalizes it to 1). Fresh-CT execs race init boot (the
  probe retries).
- debbie: ansible = distro package (dotfiles migration 000589;
  collections bundled system-wide, `make deps` tops up); the
  community.general yaml callback is gone (default callback +
  result_format=yaml); mise's python3 shadows the system python
  (use /usr/bin/python3.14 for yaml checks).
- The v1-era host_vars carried latent YAML bugs (colon+space in
  plain scalars) that no bash parser ever tripped -- ansible's
  real parser found + fixed two in pve-framework.yml.

## Notes

Ansible-only, no Terraform state layer (the 2026-11-05 research
decision; bpg stays the recorded fallback). Design record:
[../design/greenfield-rebuild.md](../design/greenfield-rebuild.md)
(tooling + repo layout).
