# OPS-16: Auto-repair via n8n

As the operator, I want the fleet's repair flows built in n8n, so
that when something breaks, an n8n workflow can heal it or page me
with everything it learned.

**Status**: planned (operator directive: the repair engine is n8n,
not bespoke scripts -- the design record's script-based approach is
superseded by this)
**Arc**: v4 (last, with the self-minding tier)

## Workflow

Something breaks; the alert lands in n8n; the flow runs the safe
heals (restart, re-converge a guest, re-run a script), pages me
with what it tried, and escalates when a heal does not work. The
daily workflow is the same as today (the phone), but the 2am cases
get a repair attempt before they get a human.

## Acceptance criteria

- [ ] n8n is live (USER-6 restores it first) and its flows are
      code-in-repo, not click-only state
- [ ] The first flows: service restart on crash-loop detection,
      guest re-converge on drift alert, disk-full first aid
- [ ] Every flow honors the human gate: destructive or
      cluster-level actions page the operator instead of acting
- [ ] Flows visible (results on a dashboard; ntfy on escalation)

## Lenses

- Security: n8n holds credentials; secrets in the pass vault
  (OPS-26 pattern); flows never hold secrets inline.
- Reliability: repair flows must be idempotent and rate-limited; a
  flapping repair must not flap harder than the fault.
- Design record: [../design/homelab-auto-repair.md](../design/homelab-auto-repair.md)
  (superseded in mechanism only; its diagnosis-of-failures halves
  still apply).
