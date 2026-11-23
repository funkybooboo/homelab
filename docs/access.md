# Access: how to sign in and use each guest

The access layer (issues item 4, model B): every UI-facing guest has
an https serve front -- `https://<name>.tail54538d.ts.net` with a
real LE cert, reachable from any tailnet device, off-LAN included.
LAN-direct also works (`http://<ip>:<port>`) for appliances without
tailscale.

## The sign-in table

| Guest | URL | Sign-in | First-use notes |
| --- | --- | --- | --- |
| postgres | (no UI; `psql -h postgres.tail54538d.ts.net` or .14) | user `nate` + password in `local/pg-operator.env` | the old fleet's `forgejo` + `freshrss` databases are restored and waiting for their stories |
| adminer | https://adminer.tail54538d.ts.net | server `192.168.1.14:5432`, user `nate`, same password | the DB admin UI; pick a restored database from the dropdown |
| ntfy | https://ntfy.tail54538d.ts.net | open (topics are the access control) | subscribe from the phone app: add server, topic `homelab`; alert wiring lands with the service stories |
| prometheus | https://prometheus.tail54538d.ts.net | open (read-only) | Status > Targets should show the whole fleet UP |
| grafana | https://grafana.tail54538d.ts.net | `admin` / `admin` -- CHANGE ON FIRST LOGIN | datasources (prometheus + loki) are pre-provisioned; build dashboards in the UI (old grafana data sits in dump 123 if a restore is wanted) |
| loki | (no UI; grafana is its face) | via grafana Explore | promtail on every node ships journald here |

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
