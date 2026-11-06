# OPS-8: ntfy alerting

As the operator, I want ntfy back early, so that everything built after
it narrates its own failures to the phone.

**Status**: planned
**Arc**: v2

## Acceptance criteria

- [ ] ntfy CT deployed from a guest manifest
- [ ] Topic + phone subscription restored; the alert-helper role
      (publish wrapper) codified for later stories to reuse
- [ ] Old credentials sourced from the phone + the v0 legacy
      extraction (they live nowhere else)

## Notes

The old CT also hosted the Slack-to-ntfy bridge for truenas alerts --
re-adding that bridge is part of OPS-11 scope, not this story.
Design context: `services/ntfy/` (old deploy notes).
