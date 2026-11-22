# roles/

One role per concern, data-driven from the `guests/` manifests
(OPS-7):

- `pve_template` -- ensure the base Debian CT template on shared
  storage (cluster-level).
- `guest_common` -- inside every guest: the operator account +
  passwordless sudo + key, good-ssh (password auth dead, root ssh
  dead), base packages. The standing identity contract.
- `test_service` -- the OPS-7 proof role: nginx + a page saying the
  pipeline works. Deliberately trivial.

Service roles land next (vaultwarden = USER-1, ntfy = OPS-8, ...):
one role per service, applied by manifest, never hand-run.
