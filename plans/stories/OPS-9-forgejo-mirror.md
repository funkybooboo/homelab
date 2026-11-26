# OPS-9: The forgejo hub restore

As the operator, I want my personal forgejo hub back -- 17 accounts,
347 repos (the class work, the DIRECTLab research mirrors, the homelab
read-mirror) -- so that the quarter's git history lives on the new
cluster, and the control-plane repo has its on-cluster mirror.

**Status**: DONE 2026-11-25 (hub restored + verified by the operator;
both sync legs resolved -- hub via the app nightly, codeberg via
the push chain after codeberg's pull-mirror ban; CLOSED
2026-11-25: codeberg declined the pull-mirror request
[Community#3313], so the push chain is the PERMANENT codeberg leg
and CT 204 was decommissioned by manifest -- zero data inside,
schedule was off, repos ignored; env + vault item + docs swept.
Remaining note: the 3.54.0->3.56.1 pin bump rides the next
make update; the last 12 codeberg targets are blocked by the
account's 100-repo cap -- OPEN in issues.md item 16)
**Arc**: v2

## Acceptance criteria

- [x] forgejo deployed from a guest manifest; the restored DB (17
      users incl. admin nate) + 315 repo dirs from the 107 dump live
      on it; schema migrated forward by the new binary
- [x] Operator logs in with the OLD credentials; a class repo spot
      check browses (operator-verified 2026-11-23)
- [x] The 32 mirror-only repos (DB rows without files, the
      Oct-17/Nov-21 gap) recover via the sync layer; any that need
      an admin nudge are listed
      RESOLVED 2026-11-25: the gap class turned out to be the root
      disease of every sync stall (empty DB rows confuse the app's
      create path into a phantom-import 30-min wait-loop). All 17
      broken rows deleted (no data existed in any of them -- verified
      empty before each delete, manifests kept in local/) and
      re-mirrored fresh from GitHub. 108/108 hub repos live.
- [x] The CODEBERG leg returns ... RESOLVED 2026-11-25 as a
      PUSH CHAIN, not gitea-mirror: codeberg's site policy forbids
      pull-mirror creation (403: "the site administrator has
      disabled the creation of new pull mirrors"), and gitea-mirror
      only does pull mirrors for forgejo destinations -- so the
      backup rides FORGEJO'S OWN push-mirror feature instead:
      github ->(app)-> hub ->(native 8h push mirrors)-> codeberg
      flat under funkybooboo/<name> (the old fleet's layout;
      collisions get <owner>- prefixes; private sources stay
      private on codeberg). Final audit: 96/100 SHA-identical,
      zero differs. The app's CT 204 instance is now redundant
      (decommission candidate). One tail: 12 new codeberg targets
      hit codeberg's repo-creation rate limit -- push mirrors are
      pre-configured on the hub, content lands on the 8h interval
      once the targets exist (retry the creates later)
- [x] Serve front + observability from birth (promtail, scrape, the
      watcher's front check) -- plus two API tokens now held in
      local/ (forgejo-token.env user-scope, forgejo-admin-token.env
      admin) for the sync layer and the future push-to-apply runner
- [x] gitea-mirror deployed (CT 203, RayLabsHQ upstream, pinned
      v3.54.0/bun 1.4.5, bare-metal-Bun per their docs) and the
      operator connects GitHub -> forgejo through its UI; a first
      full sync runs green
      AS-BUILT 2026-11-24: connection made via the LAN URL form
      (http://192.168.1.52:3000 -- userspace tailscaled guests
      cannot dial tailnet IPs), nightly schedule 22:00
      America/Denver, autoMirror on, self-owned repos sync GREEN.
      Known wrinkle, OPERATOR POLICY (stale-but-present, decided
      2026-11-24): collaborator repos that already exist in the
      restored hub confuse the app's create path (phantom
      "still importing" -> 30-min wait -> failed, every run);
      the operator chose to keep those hub copies as-is rather
      than delete+re-create. Follow-up: after the first full
      batch settles, add the failed list to the app's per-repo
      EXCLUDE config so nightly runs skip the class (no deletion
      involved). Note: the app's cancel-pending endpoint is
      actually stop-pending-mirrors (sets repos to ignored);
      retry-repo with repositoryIds[] is the correct re-queue.
- [x] The CODEBERG leg returns: the old fleet ran a SECOND
      gitea-mirror (GitHub -> codeberg, the off-site public
      mirror). RESOLVED via the push chain above (codeberg
      forbids pull mirrors site-wide; see the resolved 32-repos
      entry)

## Notes

The full as-built record -- the scoping decision (the whole
personal hub, 17 users + 349 repos), the restore model, the sync
layer decision (forgejo serves, gitea-mirror syncs), and the traps
this build surfaced -- is in [../history.md](../history.md) (the
v2/v3 records). The live gotchas are in [../docs/quirks.md](../docs/quirks.md).
