# Browser off the cloud: the complete map

Operator directive 2026-11-28: know every way a browser touches
someone else's cloud, own what can be owned, and name what stays
cloud and why. This is the design context for USER-5 (firefox
sync) and any story that follows it. Present tense = the state
now; each row names its mechanism or its accepted residual.

## The map

| # | Capability | Cloud today | Homelab state | Mechanism |
|---|-----------|-------------|---------------|-----------|
| 1 | Search queries | Google/Bing/Bravo see the house IP | OWNED | searxng (.62, tailnet front; engines see the Proton exit, not the house) |
| 2 | DNS resolution | ISP + Mozilla DoH | OWNED | the OPNsense resolver serves the LAN + guests; blanket egress hides queries from the ISP |
| 3 | Password vault | Firefox store / Mozilla sync | OWNED (separate path) | vaultwarden (.17) is the household vault, fed by the Proton Pass sync (cronmaster job, OPS-24) |
| 4 | Sync storage (bookmarks, history, tabs, passwords-in-browser) | Mozilla's sync servers | SERVER LIVE (2026-11-28, client pairing pending) | USER-5: syncstorage-rs CT 216 (.58, framework), bundled tokenserver, mysql CT 107 (.20, thermaltake); https://sync.tail54538d.ts.net heartbeat 200, tokenserver 401-unauthed |
| 5 | FxA authentication | Mozilla issues the OAuth tokens our tokenserver validates | RESIDUAL, accepted | Firefox has no self-hostable FxA path; without it sync auth fails. The map's one hard residual |
| 6 | Extension downloads + updates (AMO) | addons.mozilla.org | RESIDUAL, accepted | self-hosting AMO is impractical (signed-xpi pipeline is Mozilla's); fetches are update-only, extensions run locally |
| 7 | Browser binaries + updates | Mozilla CDN / LibreWolf releases | RESIDUAL, accepted, but channeled | dotfiles migrations roll LibreWolf from the latest release tag; the download is cloud, the choice of when is ours |
| 8 | Telemetry, pocket, recommendations, new-tab ads | Mozilla endpoints | OWNED | LibreWolf strips them by build; enterprise policies finish any remainder if wanted |
| 9 | Homepage / new tab | Mozilla defaults | OWNED | set to searxng/blank; pure client config |
| 10 | WebRTC / IP leakage | STUN sees the real address | OWNED | blanket egress + exit node make "real address" = the Proton exit; LibreWolf disables WebRTC by default |
| 11 | Certificate checks (OCSP/CRL) | CA endpoints | RESIDUAL, accepted | removing this breaks TLS; it is infrastructure, not surveillance of the operator |

## How to read it

Four rows are already owned outright (1, 2, 3, 8-10). Row 4 is
the build in flight (USER-5). Three residuals are structural and
accepted with reasons on the record (5, 6, 7) -- the honest shape
of "browser off the cloud" is not zero cloud; it is: no cloud
party holds our bookmarks, history, tabs, or queries, and every
cloud party that remains gets a named reason in this table.

## What finishing the map takes

- USER-5 ships row 4 and with it the household's browser data
  never touches a Mozilla sync server again.
- After USER-5: a one-session client-config pass (dotfiles
  migration) that sets the tokenserver pref, homepage, and
  policy-blocks any remaining telemetry across the household
  browsers -- rows 4, 8, 9 in one sweep.
- Nothing else is queued: rows 5-7 and 11 are accepted residuals,
  revisited only if Mozilla's posture changes.
