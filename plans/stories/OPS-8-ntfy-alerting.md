# OPS-8: ntfy alerting

As the operator, I want ntfy back early, so that everything built after
it narrates its own failures to the phone.

**Status**: in progress (infra live 2026-11-22; alert wiring lands with the service stories)
**Arc**: v2

## Acceptance criteria

- [x] ntfy CT deployed from a guest manifest -- DONE 2026-11-22:
      guests/ntfy.yaml (vmid 103, .16, aspires), :8080 (the Debian
      unit binds unprivileged), https front live at
      https://ntfy.tail54538d.ts.net
- [ ] Topic + phone subscription restored; the alert-helper role
      (publish wrapper) codified for later stories to reuse --
      INFRA LIVE, wiring pending: the phone subscribes (server
      https://ntfy.tail54538d.ts.net, topic `homelab`); the
      publish-wrapper role lands with the first story that alerts
- [ ] Old credentials sourced from the phone + the v0 legacy
      extraction -- pending with the wiring above

## Notes

The old CT also hosted the Slack-to-ntfy bridge for truenas alerts --
re-adding that bridge is part of OPS-11 scope, not this story.
Design context: `services/ntfy/` (old deploy notes).

REVISED 2026-11-21 (revival): ntfy revives with the fleet; the story
becomes verify + codify the alert-helper role for the stories after.

REVISED 2026-11-22 (plan shift final form): the old CT was cleaned out
(OPS-20). BUILD FRESH: manifest + role from the skeleton (OPS-7);
topics re-subscribed on the phone; the truenas alert bridge re-wired
via the truenas API. No data restore needed -- ntfy state is
ephemeral by design.
