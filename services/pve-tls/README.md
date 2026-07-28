# PVE node TLS renewal -- `renew-pve-tls.sh`

Weekly cron on **each of the 5 PVE nodes** that re-issues a tailscale
Let's Encrypt cert for `<node>.tail54538d.ts.net` and installs it as the
native `pveproxy` cert (the `:8006` backend that `tailscale serve --https 443`
proxies to; see [`docs/https.md`](../../docs/https.md)).

The cert at `:443` is handled by `tailscale serve` and auto-renews via
tailscaled -- this script does NOT touch that. It only maintains the backend
pveproxy cert, which is what the proxy connects to (and what a user sees if
they fall back to the `:8006` URL).

## Install (on each node)

```sh
install -m 700 renew-pve-tls.sh /usr/local/sbin/renew-pve-tls.sh
cat > /etc/cron.d/renew-pve-tls <<'EOF'
# weekly Sunday 04:30 -- re-issue native pveproxy LE cert if <30d validity
30 4 * * 0 root /usr/local/sbin/renew-pve-tls.sh >/var/log/renew-pve-tls.log 2>&1
EOF
chmod 644 /etc/cron.d/renew-pve-tls
systemctl reload cron
# prime once now:
/usr/local/sbin/renew-pve-tls.sh
```

## Behavior

* `tailscale cert --min-validity 720h <host>` -> cache hit unless <30d
  validity left (returns cached cert).
* Compute SHA1 of the freshly-issued cert. Compare to the SHA1 of
  `/etc/pve/local/pveproxy-ssl.pem` (the currently-installed custom cert, if
  any).
* Match -> "fingerprint matches; nothing to do." exit 0 (idempotent no-op).
* Differ -> `pvenode cert set <crt> <key>` + `systemctl restart pveproxy`
  (because pvenode cert set does NOT auto-restart).
* `--min-validity 720h` keeps weekly runs cheap; a real re-issue fires only
  in the last 30 days before expiry (~90-day LE lifetime).

## Revert

```sh
pvenode cert delete   # removes pveproxy-ssl.pem, falls back to cluster-CA /etc/pve/local/pve-ssl.pem
```

## Persistence gap

PVE nodes are NOT managed by `~/dotfiles/migrate.sh` (no PVE-node deploy
mechanism). This script + cron live only on each node. If a node is rebuilt,
re-apply from this README.