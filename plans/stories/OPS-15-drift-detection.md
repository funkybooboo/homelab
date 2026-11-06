# OPS-15: Drift detection

As the operator, I want a scheduled converge-diff that publishes drift
to ntfy, so that divergence between repo and reality is loud instead
of silent.

**Status**: planned
**Arc**: v4

## Acceptance criteria

- [ ] Scheduled `make verify` (plan-only converge) on a timer; drift
      summarized to the ntfy topic from OPS-8
- [ ] Codify-instead-of-live-fix made the default response; the
      notification links the runbook line saying so

## Notes

The old system's weekly tofu-plan drift notification idea carried over
from [../design/proxmox-iac.md](../design/proxmox-iac.md) phase 5 --
now ansible check-mode instead of tofu plan.
