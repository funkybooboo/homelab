# OPS-9: The forgejo hub restore

As the operator, I want my personal forgejo hub back -- 17 accounts,
347 repos (the class work, the DIRECTLab research mirrors, the homelab
read-mirror) -- so that the quarter's git history lives on the new
cluster, and the control-plane repo has its on-cluster mirror.

**Status**: sync layer building (hub itself is live and operator-verified)
**Arc**: v2

## Acceptance criteria

- [x] forgejo deployed from a guest manifest; the restored DB (17
      users incl. admin nate) + 315 repo dirs from the 107 dump live
      on it; schema migrated forward by the new binary
- [x] Operator logs in with the OLD credentials; a class repo spot
      check browses (operator-verified 2026-11-23)
- [ ] The 32 mirror-only repos (DB rows without files, the
      Oct-17/Nov-21 gap) recover via the sync layer; any that need
      an admin nudge are listed
- [x] Serve front + observability from birth (promtail, scrape, the
      watcher's front check) -- plus two API tokens now held in
      local/ (forgejo-token.env user-scope, forgejo-admin-token.env
      admin) for the sync layer and the future push-to-apply runner
- [ ] gitea-mirror deployed (CT 203, RayLabsHQ upstream, pinned
      v3.54.0/bun 1.4.5, bare-metal-Bun per their docs) and the
      operator connects GitHub -> forgejo through its UI; a first
      full sync runs green
- [ ] The CODEBERG leg returns: the old fleet ran a SECOND
      gitea-mirror (GitHub -> codeberg, the off-site public
      mirror). Two paths, in preference order: (1) if the
      Configuration page accepts a second destination card
      (Codeberg = Forgejo-type destination, the operator's
      codeberg token), add it to CT 203 -- one instance, two
      destinations; (2) if the UI allows only one destination per
      instance, spin CT 204 with the same role (base-URL
      parameterized) and keep the old two-instance model.
      Acceptance: a codeberg repo shows a fresh sync

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

SYNC LAYER DECISION (2026-11-23, operator): the old fleet's GitHub
-> forgejo sync never rode forgejo-native pull mirrors -- the
operator ran RayLabsHQ/gitea-mirror (push-based, auto-discovers new
GitHub repos). The restored DB confirms it: mirror rows frozen
mid-July while push-driven repo activity ran to Oct 19. Native is
dormant here too (the update_mirrors cron fired by admin API was a
silent no-op; 170 mirrors due, zero pulled) -- so the new hub keeps
the same division of labor: forgejo serves, gitea-mirror syncs
(CT 203, guests/gitea-mirror.yaml, bare-metal Bun, secrets
generated only-while-absent because a regenerated ENCRYPTION_SECRET
makes stored tokens unreadable). Native mirror rows are left as
legacy state; the homelab mirror created 2026-11-23 via the migrate
API (funkybooboo/homelab, 8h interval) stays -- it costs nothing
and a native pull is harmless alongside pushes.

TRAPS WORTH KEEPING: forgejo's FORGEJO__ env overrides are IGNORED
by the runtime when --config is passed (proven live); a pgdata-restored
DB is postgres-owned and migrations fail until a per-relkind DO-block
reassigns user objects (REASSIGN OWNED BY postgres is impossible);
forgejo rewrites app.ini post-migration (ReadWritePaths needed in a
hardened unit); apt auto-start crash-loops tailscaled in fresh CTs
and trips systemd's start limit (guest_common drop-in fixes it).
