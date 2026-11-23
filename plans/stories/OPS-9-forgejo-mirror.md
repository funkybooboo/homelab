# OPS-9: The forgejo hub restore

As the operator, I want my personal forgejo hub back -- 17 accounts,
347 repos (the class work, the DIRECTLab research mirrors, the homelab
read-mirror) -- so that the quarter's git history lives on the new
cluster, and the control-plane repo has its on-cluster mirror.

**Status**: building
**Arc**: v2

## Acceptance criteria

- [ ] forgejo deployed from a guest manifest; the restored DB (17
      users incl. admin nate) + 315 repo dirs from the 107 dump live
      on it; schema migrated forward by the new binary
- [ ] Operator logs in with the OLD credentials; a class repo spot
      check browses; the homelab mirror (funkybooboo/homelab) pulls on
      schedule -- GitHub stays canonical (the repo must survive the
      cluster it controls)
- [ ] The 32 mirror-only repos (DB rows without files, the
      Oct-17/Nov-21 gap) recover: all 32 are mirror=true, so they
      re-pull; any that need an admin nudge are listed
- [ ] Serve front + observability from birth (promtail, scrape, the
      watcher's front check)

## Notes

REVISED 2026-11-23 (operator chose B -- the full hub, not the
mirror-only letter): the scoping found the restored forgejo DB is the
whole personal hub (17 users, 347 repos), not just the homelab mirror.
The repo FILES were never extracted pre-clean-out (only tier-0 dumps
106/108/109 came out), but the Oct-17 vzdump of CT 107 holds them:
315 of 347 on disk (8.3G); the 32 DB-only repos are ALL mirrors (the
dump predates the DB's Nov-21 state by 5 quiet weeks -- last real
activity Oct 19) so they self-heal by re-pulling. Zero non-mirror
data lost.

RESTORE MODEL: extract from the dump tarball (the old live rootfs was
wiped in OPS-20; the dump is the tier-1 archive) ->
legacy-extraction/from-dump-107/ on debbie -> role restores
only-if-absent, like vaultwarden. app.ini restored VERBATIM (all
secrets: INTERNAL_TOKEN, LFS JWT, oauth keys) with the database +
server sections overridden by environment (LAN pg host, the new
role-per-service forgejo role, SSH clone disabled for v1 -- reads
work over https; the class is over).

Old forgejo 15.0.4 (schema 305) -> pinned v17.0.2 (codeberg ships
prebuilt amd64, unlike vaultwarden's upstream); migrations run
forward on first boot.
