# USER-6: n8n automation

As the operator, I want my n8n instance back -- workflows and
credentials restored, not rebuilt by hand -- so that the old
fleet's automations run again on the new cluster.

**Status**: planned
**Arc**: v3 (carved out of USER-3's build list per operator
directive 2026-11-23: every old-fleet service gets its own story)

## Acceptance criteria

- [ ] Manifest + role; n8n pinned (upstream ships tagged releases)
- [ ] Workflows restored from the legacy extraction
      (legacy-extraction/from-dump-106/ on debbie, or the newer
      Nov-21 vzdump on pve-backups -- whichever carries more)
- [ ] Credentials restored AND decryptable: the encryption key in
      `.n8n/config` rides with `database.sqlite` -- one without the
      other is a dead restore
- [ ] A restored workflow executes green; serve front live

## Notes

Tier-0: the workflows ARE the
value (hand-rebuilding dozens of them is the expensive path). The
Nov-21 vzdump is NEWER than the on-debbie extraction -- diff the
two at build time and restore from the fresher. n8n is
sqlite-backed by default; keep it sqlite (the tier-0 vaultwarden
precedent: an automation tool should not depend on the shared
postgres guest being up).
