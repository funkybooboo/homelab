# OPS-9: The forgejo mirror

As the operator, I want an on-cluster forgejo that mirrors this repo
from GitHub, so that the control-plane repo is readable even when
GitHub or the internet is not.

**Status**: planned
**Arc**: v2

## Acceptance criteria

- [ ] forgejo deployed from a guest manifest; mirror job pulls
      funkybooboo/homelab on a schedule
- [ ] Documented as the MIRROR only: GitHub stays canonical (the repo
      must survive the cluster it controls)

## Notes

No git push flows through the mirror in v1 -- it is a read mirror; the
push-to-apply runner comes later (OPS-12) and points at the canonical
remote.
