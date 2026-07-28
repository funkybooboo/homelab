# HTTPS infrastructure

How every web surface in the homelab gets a browser-trusted TLS certificate,
served **tailnet-only** (nothing is exposed to the public internet). There are
three different cert mechanisms layered together, plus one DNS gotcha that
silently breaks renewal. This doc explains all of it.

## TL;DR map

```
                  https://<host>.tail54538d.ts.net
                              |
            +-----------------+-------------------+
            |                 |                   |
        CTs (web)      PVE node consoles    TrueNAS UI
            |                 |                   |
  tailscale serve       tailscale serve       nginx (native)
  --https 443           --https 443           on :443
  -> http://localhost    -> https+insecure:    cert imported into
     :<app-port>            //localhost:8006    TrueNAS cert store
                                 |             (midclt certificate API)
                            pveproxy :8006
                            (native LE cert via
                             pvenode cert set)

  Cert source:           Cert source:          Cert source:
  tailscale cert         tailscale cert        tailscale cert
  (auto-renew by         + renew-pve-tls.sh    renew-truenas-tls.py
   tailscaled; no        cron keeps the          (weekly cron re-imports;
   separate cron)        pveproxy-ssl.pem        tailscale cert cache hit
                         backend fresh)          unless <30d left)
```

Every cert is a real **Let's Encrypt** cert issued via Tailscale's
`tailscale cert` (DNS-01 over the tailnet name). No self-signed warnings
remain anywhere in the homelab.

## The three mechanisms

### 1. CTs (web apps) -- `tailscale serve --https 443`

~16 web-facing LXC containers (jellyfin, vaultwarden, forgejo, linkwarden,
searxng, n8n, grafana, prometheus, excalidraw, drawio, adminer, opengist,
speedtest-tracker, jupyternotebook, cronmaster, bichon, alpine-it-tools).

```sh
pct exec <vmid> -- tailscale serve --bg --https 443 --yes http://localhost:<port>
```

* `tailscaled` listens on 443 on the tailnet IP, presents an LE cert, and
  reverse-proxies to the app's localhost port.
* The cert is issued lazily on first HTTPS request (~15-30s) and
  **auto-renewed by tailscaled itself** -- no separate cron needed.
* Config persists in tailscaled state → survives CT reboot automatically.
* (postgresql-bridge has no web port; skipped.)

### 2. PVE node consoles -- native cert + tailscale serve layering

PVE's own web UI (`pveproxy`) is special: it serves the noVNC/SPICE WebSocket
console, so it got **two** cert layers, applied in sequence as the design
matured:

**Backend cert (still required):** install an LE cert natively into pveproxy
via `pvenode cert set`. This makes `:8006` itself browser-trusted and is the
backend the proxy connects to.

```sh
pvenode cert set <cert.crt> <cert.key>     # cert from `tailscale cert <node>.tail54538d.ts.net`
systemctl restart pveproxy                  # pvenode cert set does NOT auto-restart
```

* Installs to `/etc/pve/local/pveproxy-ssl.pem` (separate from the cluster-CA
  `/etc/pve/local/pve-ssl.pem`, which is left untouched → clean revert via
  `pvenode cert delete`).
* Kept fresh by **`/usr/local/sbin/renew-pve-tls.sh`** + a weekly cron on
  every node:

  ```
  # /etc/cron.d/renew-pve-tls   (30 4 * * 0 root ...)
  30 4 * * 0 root /usr/local/sbin/renew-pve-tls.sh >/var/log/renew-pve-tls.log 2>&1
  ```

  Idempotent: `tailscale cert --min-validity 720h` is a cache hit unless <30d
  left; compares SHA1 to installed cert; only re-installs + restarts pveproxy
  when the cert actually changed. Weekly runs are no-ops except in the last
  30d before expiry.

**Front-end (no-port URL):** put `tailscale serve` on top:

```sh
tailscale serve --bg --https 443 --yes https+insecure://localhost:8006
```

* 443 = tailscale serve listener (its own LE cert, tailnet-only).
* Backend = pveproxy on :8006 (native LE cert from `pvenode cert set` above).
* `+insecure` on the backend hop = don't validate pveproxy's cert from
  localhost (avoids SAN/hostname friction; both certs are LE anyway).
* Verified: the noVNC WebSocket console opens through the no-port URL on
  every node. (Earlier worry that a reverse proxy would break the WS console
  was wrong -- tailscale serve proxies WebSockets fine.)
* `:8006` still works as a fallback. Revert just the front-end:
  `tailscale serve --https=443 off` → falls back to :8006, native cert intact.

Both certs auto-renew: the 443 one by tailscaled, the 8006 one by the weekly
`renew-pve-tls.sh` cron. Keep `renew-pve-tls.sh` running even after adding
the proxy, because it maintains the backend cert.

### 3. TrueNAS UI -- cert import + `renew-truenas-tls.py`

TrueNAS can't use `tailscale serve` (the UI runs on the host, and Tailscale
on TrueNAS is an app container with no `host.docker.internal`). Instead:

* Issue a tailscale LE cert for `truenas.tail54538d.ts.net` from the
  Tailscale app container.
* **Import** the cert+key into TrueNAS's cert store via the midclt
  `certificate.create` API, and bind it as the UI cert
  (`system.general.update` + `service.control RESTART http`).
* Keep it fresh with **`/mnt/volume1/.admin/renew-truenas-tls.py`** + a
  weekly TrueNAS cron job (Sunday 04:30):

  ```
  # TrueNAS cronjob id=1, schedule {minute:30,hour:4,dom:*,month:*,dow:0}
  /usr/bin/python3 /mnt/volume1/.admin/renew-truenas-tls.py
  ```

  Idempotent + crash-safe: re-issues in the container
  (`tailscale cert --min-validity=720h` → cache hit unless <30d left), computes
  SHA1, compares to the currently UI-bound cert's SHA1, and only if they differ
  does it create a new imported cert, bind the UI to it, restart http, verify
  the live SHA1, delete the old, and rename the new one to canonical
  `truenas_tailscale`. The old self-signed `truenas_default` (id=1) is kept as
  a revert path.

The script lives on the volume1 data pool (TrueNAS root FS is read-only), so
it survives upgrades/reboots. Same reproducibility caveat as the PVE
scripts: not in dotfiles, lives on the box.

## The DNS gotcha (renewal time bomb)

`tailscale cert` needs to reach `acme-v02.api.letsencrypt.org` to issue or
renew a cert. Tailscale **MagicDNS** (`100.100.100.100`) is supposed to
forward public DNS, but in this tailnet it has intermittently returned
SERVFAIL for all public hostnames -- it only resolves
`*.tail54538d.ts.net`. When that happens, every tailscale-serve CT silently
fails to renew its cert at the ~90-day mark. Symptom:
`tlsv1 alert internal error` on HTTPS; cert cache has only
`acme-account.key.pem` (the leaf cert was never issued).

**Fix (applied to all CTs + all 5 PVE hosts):**

1. `pct set <vmid> --nameserver 192.168.8.1 --searchdomain tail54538d.ts.net`
   (PVE writes the CT's resolv.conf from this; persists across reboots).
2. `pct exec <vmid> -- tailscale set --accept-dns=false`
   (tailscale stops overwriting resolv.conf; pref persisted in tailscaled
   state).
3. Rewrite the live `/etc/resolv.conf` inside the running CT to
   `nameserver 192.168.8.1` + the search line (PVE only regenerates
   resolv.conf on next CT start, so a live rewrite is needed for immediate
   cert issuance).

`192.168.8.1` is the LAN router, which resolves public names reliably.
Tailnet names still resolve (tailscale keeps a local resolver active even
with `accept-dns=false`), so tailnet access is unaffected. The same
`accept-dns=false` was applied on the 5 host nodes.

Net: every CT and node host now has public DNS independent of MagicDNS
flakiness, so cert issuance + weekly renewals work regardless of Tailscale's
upstream DNS health. The HTTPS rollout is no longer sitting on a silent
90-day expiration.

## Renewals at a glance

| surface | cert owner | renewal mechanism | when |
| --- | --- | --- | --- |
| CT web apps | tailscale serve / tailscaled | automatic (tailscaled) | as needed, ~30d before expiry |
| PVE node :443 | tailscale serve / tailscaled | automatic (tailscaled) | as needed |
| PVE node :8006 (backend) | `pvenode cert set` + `/usr/local/sbin/renew-pve-tls.sh` | weekly cron `/etc/cron.d/renew-pve-tls` (Sun 04:30) | no-op weekly, real re-issue in last 30d |
| TrueNAS UI | imported into TrueNAS cert store + `/mnt/volume1/.admin/renew-truenas-tls.py` | weekly TrueNAS cron id=1 (Sun 04:30) | no-op weekly, real re-import in last 30d |

All renewals degrade safely on failure: a missed renewal leaves the existing
LE cert in place until it expires ~90d later → browser warning, **not** a
lockout (SSH + CLI still work for PVE; midclt still works for TrueNAS).

## Operator quick-checks

```sh
# From a tailnet box: verify any HTTPS surface is green (LE, browser-trusted)
curl -sI https://<host>.tail54538d.ts.net/ -w 'ssl_verify=%{ssl_verify_result}\n'

# Verify a CT has working public DNS + tailnet resolution
pct exec <vmid> -- getent hosts acme-v02.api.letsencrypt.org   # public
pct exec <vmid> -- getent hosts truenas.tail54538d.ts.net      # tailnet

# Re-issue a missing CT cert manually (idempotent; cache-populating no-op if present)
pct exec <vmid> -- bash -lc 'cd /tmp && tailscale cert --min-validity 720h <host>.tail54538d.ts.net && rm /tmp/<host>.*'

# Idempotent re-run of a renewal cron (should be a no-op if cert is fresh)
pct exec <vmid> -- /usr/local/sbin/renew-pve-tls.sh        # on a PVE node, not in a CT
```

## Persisted on the box, not in dotfiles

The renewal scripts (`renew-pve-tls.sh`, `renew-truenas-tls.py`), their crons,
the ntfy bridge, and the imported-TrueNAS cert are all stored on the hosts
they run on. They are **not** managed by `~/dotfiles/migrate.sh` (dotfiles has
no PVE-node or TrueNAS deploy mechanism). Reproduce from this doc + the
service READMEs if a node is rebuilt.