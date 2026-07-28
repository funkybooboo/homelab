# ntfy -- self-hosted push notifications (homelab)

A single Proxmox LXC container running the [ntfy](https://ntfy.sh) push
notification server, exposed **tailnet-only** over HTTPS. It is the
homelab-wide notification channel: TrueNAS alerts land here, and any other
box (PVE vzdump jobs, cert-renewal crons, custom scripts) can push to the
same topic with a one-line curl.

* **Hosted on:** Proxmox CT `ntfy` (x86 node -- NOT the Pi, which is a
  quorum-witness and can't run HA-managed CTs).
* **Exposed at:** `https://ntfy.tail54538d.ts.net` (tailnet only, Let's
  Encrypt cert via `tailscale serve --https 443`).
* **Auth:** username + password, `auth-default-access: deny-all`.
* **No external account / no SMTP relay** -- direct push to the official
  ntfy phone app over the tailnet.

## Files in this directory

| file | what |
| --- | --- |
| `ntfy-server.yml.example` | ntfy server config (auth-file, proxy mode, cache). Install as `/etc/ntfy/server.yml`. |
| `ntfy-slack-bridge.py` | Small Python HTTP server: converts TrueNAS's Slack-format webhook into a proper ntfy publish, AND reverse-proxies everything else to ntfy. Single `tailscale serve` backend. |
| `ntfy-slack-bridge.service.example` | systemd unit template for the bridge (sets `NTFY_TOPIC` / `NTFY_TOKEN` / `BRIDGE_PATH` env -- fill in your secrets). |
| `truenas-alertservice.py` | Idempotently creates/updates the TrueNAS "Slack" alertservice pointing at the bridge. Run on the TrueNAS host as root. |

Deployed secrets (ntfy user password, bridge token, bridge path, topic name)
**are not stored in this repo.** See `docs/notifications.md` for where they
live and how to regenerate them.

## Why a bridge? (TrueNAS has no ntfy type)

TrueNAS 25.10 alert services are: `AWSSNS, InfluxDB, Mail, Mattermost,
OpsGenie, PagerDuty, Slack, Telegram, VictorOps`. There is no native ntfy
type. The `Slack` type POSTs Slack incoming-webhook JSON to a URL; ntfy
doesn't speak that format natively. So the bridge:

1. Listens on one secret path (the "publisher secret", since Slack type has
   no auth-header field).
2. Accepts the Slack JSON, extracts `text` (title) + `attachments[].text`
   (message), re-publishes to the ntfy topic with `Title` / `Priority` /
   `Tags` *headers* (the robust path -- see the script comment for why plain
   text + headers beats JSON body on ntfy 2.11).
3. Reverse-proxies all other paths straight through to ntfy, so the phone
   app (web UI + JSON subscribe) and direct `curl` publishers keep working.

## Deploy from scratch (reproducible)

On a Proxmox node, create the CT (this example matches the existing deploy):

```sh
pct create <VMID> local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst \
  --hostname ntfy --cores 1 --memory 512 --swap 0 \
  --rootfs local-lvm:4 --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --nameserver 192.168.8.1 --searchdomain tail54538d.ts.net --onboot 1 --start 1

# Tailscale needs /dev/net/tun inside the unprivileged CT:
printf "lxc.cgroup2.devices.allow: c 10:200 rwm\nlxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file\n" \
  >> /etc/pve/nodes/<node>/lxc/<VMID>.conf
pct reboot <VMID>
```

Inside the CT:

```sh
# 1. ntfy server + Tailscale
apt-get update && apt-get install -y ntfy curl ca-certificates
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --accept-dns=false --hostname=ntfy   # approve in Tailscale admin

# 2. ntfy config (copy ntfy-server.yml.example -> /etc/ntfy/server.yml)
install -m 644 ntfy-server.yml.example /etc/ntfy/server.yml
mkdir -p /var/lib/ntfy/attachments && chown -R _ntfy:_ntfy /var/lib/ntfy
systemctl enable --now ntfy

# 3. admin user + a long-lived token for the bridge
NTFY_PASSWORD=<your-pass> ntfy user add --role admin nate
ntfy token add --label bridge nate     # prints tk_...

# 4. bridge
install -m 755 ntfy-slack-bridge.py /usr/local/sbin/ntfy-slack-bridge.py
# fill NTFY_TOPIC / NTFY_TOKEN / BRIDGE_PATH in the .service, then:
install -m 644 ntfy-slack-bridge.service.example /etc/systemd/system/ntfy-slack-bridge.service
systemctl daemon-reload && systemctl enable --now ntfy-slack-bridge

# 5. expose over tailnet (LE cert auto-issued)
tailscale serve --bg --https 443 --yes http://localhost:2587
```

On the TrueNAS host (copy `truenas-alertservice.py` there first, fix the
`BRIDGE_URL`):

```sh
python3 truenas-alertservice.py --test
```

## Subscribe (phone)

Official ntfy app (Android/iOS). Make sure Tailscale is running on the phone
(server is tailnet-only). Add a subscription with your server URL, topic,
username, password. See `docs/notifications.md` for the high-level picture.