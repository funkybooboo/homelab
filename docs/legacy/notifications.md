# Notifications & alerting

How the homelab tells you when something broke. Goal: a job/cert/cron failure
is never silent again.

## TL;DR

```
[ TrueNAS ] alert (>= WARNING)
        |
        | HTTP POST Slack-format webhook
        v
https://ntfy.tail54538d.ts.net<tridge-secret-path>      (tailnet-only HTTPS, LE cert)
        |
        v
[ CT 128 ntfy -- ntfy-slack-bridge.py ]
        |  parse {text, attachments[]} -> {Title, Message, Priority, Tags}
        |  forward-publish to 127.0.0.1:2586/<topic>  (ntfy local server)
        v
[ ntfy topic: homelab-<secret-suffix> ]
        |  long-lived subscribe (auth: user nate + pass)
        v
[ phone: official ntfy app ]  -> push notification
```

Everything is self-hosted and tailnet-only. No external account, no SMTP relay,
no Google/Apple push dependency (ntfy delivers direct to the app over the
tailnet socket).

## Components

### ntfy server -- `ntfy.tail54538d.ts.net`

* A Proxmox LXC container (`ntfy`, CT 128) on pve-framework.
* ntfy 2.11 (Debian apt, no third-party repo).
* Listens on `127.0.0.1:2586` only -- never directly exposed.
* `auth-file: /var/lib/ntfy/user.db`, `auth-default-access: deny-all`.
* Config at `/etc/ntfy/server.yml`.
* Exposed over the tailnet by `tailscale serve --bg --https 443 --yes
  http://localhost:2587` -- the bridge is the single serve backend.
* HTTPS + Let's Encrypt cert is handled by tailscale serve (auto-renewed, no
  separate cron needed).

### Slack-to-ntfy bridge -- `ntfy-slack-bridge.py`

Python `http.server` on `127.0.0.1:2587`. Two jobs:

1. **Secret publisher endpoint:** on `POST <BRIDGE_PATH>` (a random unguessable
   path), parse the incoming Slack incoming-webhook JSON and re-publish it as a
   proper ntfy message (Title + Message + Priority + Tags via headers).
2. **Reverse proxy:** everything else goes straight through to ntfy at
   `127.0.0.1:2586`, so the phone app's web UI / JSON subscribe and direct
   `curl` publishers work unchanged.

systemd unit at `/etc/systemd/system/ntfy-slack-bridge.service` with the
secrets as `Environment=` lines (NOT in this repo).

### Why the bridge at all?

TrueNAS 25.10's alert service types are AWS SNS, InfluxDB, Mail, Mattermost,
OpsGenie, PagerDuty, **Slack**, Telegram, VictorOps. There is no ntfy type.
The `Slack` type has only one field -- a webhook URL -- and no auth-header
field, so the secret lives in the bridge URL path itself.

## Subscriber (phone)

Official ntfy app (Android / iOS). Tailscale must be running on the phone
(the server is tailnet-only -- not on the public internet). Add a subscription
with your server URL + topic + username + password.

## Where the secrets live

Credentials are intentionally NOT in this repo or in dotfiles. They live:

| secret | where |
| --- | --- |
| ntfy admin user password | CT `ntfy` user.db (`/var/lib/ntfy/user.db`); typed into the phone app; nothing written down by tooling |
| bridge publish token (`tk_...`) | systemd unit `Environment=NTFY_TOKEN=...` on CT `ntfy` only |
| bridge secret path | systemd unit `Environment=BRIDGE_PATH=...` on CT `ntfy` only; also embedded in the TrueNAS alertservice URL |
| topic name (unguessable suffix) | systemd unit `Environment=NTFY_TOPIC=...` on CT `ntfy`; also the topic you subscribe to on the phone |

Rotate with `ntfy user change-pass nate` and `ntfy token add --label bridge nate`.

## Publishing from anywhere in the homelab

The same ntfy server is a generic notification channel -- any box on the
tailnet can push:

```sh
curl -u nate:<pass> \
  -H 'Title: <short title>' \
  -H 'Priority: <1-5|default|high|urgent>' \
  -H 'Tags: bell,boom' \
  -d '<message body>' \
  https://ntfy.tail54538d.ts.net/homelab-<secret-suffix>
```

The TrueNAS path (Slack bridge) is just one publisher; we can wire PVE vzdump
notify, the cert-renewal crons (`renew-pve-tls.sh`, `renew-truenas-tls.py`),
and the jellyfin boot-race unit into the same topic later.

## Pitfalls hit during setup (so you don't repeat them)

1. **Debian LXC root is locked** by default (no password set) -- console login
   fails until `chpasswd` sets one.
2. **CT needs `/dev/net/tun`** for tailscaled. Add the two `lxc.cgroup2` /
   `lxc.mount.entry` raw lines to the CT config and reboot, or tailscaled
   fails to start.
3. **Don't put HA-managed CTs on the Pi node** -- it's a quorum witness with
   no `pve-lrm`; any HA CT there freezes.
4. **ntfy 2.11 JSON-body publish** to `/<topic>` stores the JSON as the literal
   message text. Use the *header-based* publish (Title / Priority / Tags as
   headers, message as body) -- that's what the bridge does.
5. **TrueDNS host reaches the tailnet directly.** The TrueNAS *host* has
   `tailscale0` and routes to `100.x`; the alert dispatcher (not the
   Tailscale app container) POSTs to the bridge over the real tailnet. No
   app-container gymnastics needed for outbound alerts.
6. **Tailscale MagicDNS intermittently SERVFAILs public names**, which breaks
   `tailscale cert` (needed to reach `acme-v02.api.letsencrypt.org`). Create
   the CT with `--nameserver 192.168.8.1` and `tailscale up
   --accept-dns=false` so cert issuance is independent of MagicDNS health.