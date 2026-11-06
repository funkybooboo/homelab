# OPS-16: Homelab auto-repair

As the operator, I want a self-healing layer revisited on top of the
new IaC fleet -- deterministic repair playbooks triggered by ntfy
alerts, with optional human-in-the-loop approval -- so that 3am
failures fix themselves only where that is provably safe.

**Status**: someday
**Arc**: unqueued (needs v4 done first)

## Acceptance criteria

- [ ] Alert -> deterministic playbook path for the safe repair classes,
      each repair idempotent + convergent with the repo (never a
      live-typed fix)
- [ ] Dangerous surfaces stay human-gated; LLM diagnosis, if used, is
      a non-load-bearing assistant
- [ ] Every automated repair published to ntfy with its diff

## Notes

The design record pressure-tested the original external pitch ("HAL")
against the old live stack and recorded what was theater vs real.
Re-anchor it onto the greenfield stack after v4. See
[../design/homelab-auto-repair.md](../design/homelab-auto-repair.md).
