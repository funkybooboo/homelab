# Access: how to sign in and use each guest

The access layer (issues item 4, model B): every UI-facing guest has
an https serve front -- `https://<name>.tail54538d.ts.net` with a
real LE cert, reachable from any tailnet device, off-LAN included.
LAN-direct also works (`http://<ip>:<port>`) for appliances without
tailscale.

## The sign-in table

| Guest | URL | Sign-in | First-use notes |
| --- | --- | --- | --- |
| postgres | (no UI; `psql -h postgres.tail54538d.ts.net` or .14) | user `nate` + password in `local/pg-operator.env` | the hub's `forgejo` database is LIVE here |
| adminer | https://adminer.tail54538d.ts.net | server `192.168.1.14:5432`, user `nate`, same password | the DB admin UI; pick a database from the dropdown |
| ntfy | https://ntfy.tail54538d.ts.net | open (topics are the access control) | subscribe from the phone app: add server, topic `homelab`; alert wiring lands with the service stories |
| prometheus | https://prometheus.tail54538d.ts.net | open (read-only) | Status > Targets should show the whole fleet UP (incl. the forgejo-app job) |
| grafana | https://grafana.tail54538d.ts.net | `admin` / `admin` -- CHANGE ON FIRST LOGIN | datasources (prometheus + loki) are pre-provisioned; build dashboards in the UI (old dashboards sit in the dump archive, see archive.md) |
| loki | (no UI; grafana is its face) | via grafana Explore | promtail on every node ships journald here |
| vaultwarden | https://vaultwarden.tail54538d.ts.net | the operator's vaultwarden account (client app + browser extension) | the restored vault; verify on phone + laptop |
| forgejo | https://forgejo.tail54538d.ts.net | `nate` / `funkybooboo`; API tokens in `local/forgejo-*.env` | the git hub (349 repos); sync legs: gitea-mirror nightly -> hub, push mirrors -> codeberg |
| gitea-mirror | https://gitea-mirror.tail54538d.ts.net | UI open; API key in `local/gitea-mirror-api.env` | github -> hub sync app; nightly 22:00 |
| jellyfin | https://jellyfin.tail54538d.ts.net | first-run wizard (operator account) | GPU transcode via the host's NVIDIA 580.142; libraries at the legacy in-CT paths ([quirks](./quirks.md)); playback needs a codec-capable browser (Brave/Firefox; see [quirks](./quirks.md)) |
| navidrome | https://navidrome.tail54538d.ts.net | first-run wizard (operator account) | music at /media/music; playlists + users live in the restored database |
| audiobookshelf | https://audiobookshelf.tail54538d.ts.net | first-run wizard (operator account) | audiobooks/books/podcasts pre-seeded; metadata + progress restored; playback needs a codec-capable browser (see [quirks](./quirks.md)) |
| it-tools | https://it-tools.tail54538d.ts.net | open | the developer Swiss-army knife; stateless, no data to lose |
| searxng | https://searxng.tail54538d.ts.net | open | the self-hosted metasearch; default settings |
| excalidraw | https://excalidraw.tail54538d.ts.net | open | the whiteboard; scenes live in browser storage |
| drawio | https://drawio.tail54538d.ts.net | open | the diagrams tool; diagrams live in browser storage (use File > Export for keepers) |
| freshrss | https://freshrss.tail54538d.ts.net | the old account returns with the dump 104 restore | until the extraction runs the front shows a fresh-install wizard -- do NOT set it up by hand; run `sudo ./scripts/extract-legacy.sh --copy-from-dump 104` + the chown, then `make converge` (the old account + 214 feeds come back) |

## The underlying rules

- Bookmarks work because each guest enrolls in the tailnet at
  converge (preauth key, `local/tailscale-authkey.env`) and serves
  https on 443 (`tailscale serve`).
- `tailnet_serve` in the manifest is what fronts a UI; backbone
  services (postgres, loki) enroll without a front.
- The LAN side is unchanged: every service also listens on its
  LAN IP; a tailscale-less TV still reaches `http://<ip>:<port>`.
- Backups of the cluster of record: `local/` env files (this repo,
  debbie). The `nate` pg password lives in `local/pg-operator.env`.

## MagicDNS names are for YOUR devices, not guest-to-guest

`postgres.tail54538d.ts.net` works from debbie / the laptop / the
phone (full tailscale, real tun, MagicDNS resolver). It does NOT
work from inside a guest: userspace-mode tailscaled hooks neither
the guest's resolver nor outbound routing. Guest-to-guest traffic
rides the LAN by design (faster, and the data plane survives a
tailscale outage) -- use the 192.168.1.x addresses inside guests.

## Verifying it all -- docs/verify.md

The kick-the-tires checklist (every check you can run yourself,
from bookmarks and copy-paste commands) lives in
[verify.md](./verify.md).
