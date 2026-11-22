# playbooks/

The v2 IaC skeleton (OPS-7):

- `site.yml` -- the `make converge` entrypoint (template + guests).
- `templates.yml` -- ensure the base Debian CT template on
  pve-shared:vztmpl (cluster-level, idempotent).
- `guests.yml` -- guest lifecycle from `guests/*.yaml` manifests:
  create via the PVE API (homelab-ops token), bootstrap the operator
  account via pct exec/push (console channel, no root ssh), then
  apply roles inside each guest over ssh.

`make verify` runs the same in check mode (`--check --diff`) -- the
OPS-15 drift detector grows from that.
