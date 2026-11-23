# Maintenance: updates, backups, reboots

The update + maintenance model, decided 2026-11-22 (before the v2
service build-out; operator-approved). Slim core now, polish (ntfy
digests, scheduled drift runs) in v4. The full old-fleet port lives
in [OPS-13](../plans/stories/OPS-13-auto-update-port.md); the v2 core
is [OPS-23](../plans/stories/OPS-23-update-model.md).

## Update tiers (blast radius)

| Tier | Who | Automatic | Reboots |
| --- | --- | --- | --- |
| A | every CT guest | unattended-upgrades, **security-only**, daily; needrestart live-restarts upgraded services (a 03:30 restart blip is accepted) | never needed: CTs share the host kernel |
| B | 4 PVE nodes + Pi | unattended-upgrades, **security-only** (Debian security repo; PVE packages wait for the weekly pass -- pve-no-subscription mixes everything, so it never auto-applies) | **never self-reboot**; cluster services restart only with the node |
| C | truenas, router | nothing; notify-only, applied via UI with a console nearby | manual |

Why security-only (a 2026-11-22 refinement of the old fleet's
full-update allowlist): full upgrades happen in the weekly `make
update` pass where the operator sees the list; unattended stays
limited to the patch class that is safe to apply blind.

## The maintenance loop

```
make converge   # config authority: guests/*.yaml -> running state
make update     # patch pass: apt dist-upgrade everywhere, tier-gated,
                #   NEVER reboots; prints reboot-required flags loudly
make verify     # drift check: --check --diff, read-only
```

Weekly operator habit (~10 min): `make update` + `make verify` +
eyeball the reboot-flags. When node kernels stack up, run the node
reboot runbook below.

## Backups (the other half of maintenance)

- vzdump: Sat 21:00, all guests -> pve-backups (snapshot mode;
  exists since the revival, automatically covers new guests)
- B2 cloud-sync: truenas datasets -> Backblaze (proven + running)
- PBS: v4 (OPS-14) -- until the restore drill passes, vzdump is the
  baseline
- The old-fleet archive: Nov-21 dumps on pve-backups (187 volumes),
  untouched

## Node reboot runbook (pre-HA)

HA placement for guests is not wired yet (the OPS-6 deferral), so a
node reboot briefly interrupts the guests on that node; they recover
via `onboot: true`. One node at a time:

1. `make update` first; note which nodes flagged reboot-required.
2. Check no vzdump job is mid-run (Sat 21:00 window).
3. Reboot ONE node. Guests on it come back on boot. Quorum holds
   (4/5 + Pi witness).
4. Verify: quorum, guest recovery (the monitoring pair shows it),
   then next node if another flag stands.

Never reboot two nodes at once; never schedule reboots; the LRM
watchdog stays unarmed for guest recovery until HA lands.
