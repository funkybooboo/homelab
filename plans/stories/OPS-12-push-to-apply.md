# OPS-12: Push-to-apply

As the operator, I want a runner that applies guest-config changes on
git push (webhook -> `make converge`), so that routine changes ship
without SSH.

**Status**: planned
**Arc**: v4

## Acceptance criteria

- [ ] Webhook (or short poll) from the canonical remote to a runner CT;
      converge runs guest config only
- [ ] Cluster-level, storage, and destructive ops remain
      human-gated (rule 2 -- enforced by what the runner is allowed to
      invoke, not by convention alone)
- [ ] git revert proven as the rollback path for a bad push

## Notes

Cost acknowledged: another moving part that can fail or drift; it
earns its place only after v2/v3 made converge boring.
