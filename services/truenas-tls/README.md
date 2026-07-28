# TrueNAS UI TLS renewal -- `renew-truenas-tls.py`

Weekly TrueNAS cron job that re-issues a tailscale Let's Encrypt cert for
`truenas.tail54538d.ts.net` and re-imports it into the TrueNAS cert store,
rebinding the web UI. Idempotent: only re-imports when the SHA1 fingerprint
actually changes. See [`docs/https.md`](../../docs/https.md) for where this
fits.

TrueNAS can't use `tailscale serve` (UI runs on the host; Tailscale on
TrueNAS is an app container). Plan A from the original rollout: import an LE
cert into TrueNAS's own cert store + bind it to the UI.

## Install

TrueNAS root FS is read-only; only `/root`, `/var/tmp`, `/mnt/volume1`,
`/mnt/.ix-apps` are writable. Use the volume1 data pool so the script
survives upgrades + reboots.

```sh
# on TrueNAS as root:
mkdir -p /mnt/volume1/.admin
install -m 700 renew-truenas-tls.py /mnt/volume1/.admin/renew-truenas-tls.py

# register the cron via midclt (system dataset is on volume1 -> cron DB persists
# across upgrades):
python3 - <<'PY'
from truenas_api_client import Client
c = Client()
c.call("cronjob.create", {
  "description": "Renew tailscale LE cert for truenas UI",
  "command": "/usr/bin/python3 /mnt/volume1/.admin/renew-truenas-tls.py",
  "user": "root",
  "schedule": {"minute":"30","hour":"4","dom":"*","month":"*","dow":"0"},  # weekly Sun 04:30
  "enabled": True,
})
PY
```

Test it manually (positional bool for skip_disabled):
```sh
midclt call cronjob.run <cronjob_id> false
```

## Behavior

1. In the Tailscale app container `ix-tailscale-tailscale-1`, run
   `tailscale cert --min-validity=720h truenas.tail54538d.ts.net` (cache hit
   unless <30d left). Copy cert+key out via `docker cp`.
2. Compute SHA1 of the freshly-issued cert.
3. Fetch the currently UI-bound cert's SHA1 via `system.general.config` +
   `certificate.get_instance`.
4. Match -> defensively sweep any stray `_new_*` orphans, exit 0 (idempotent
   no-op).
5. Differ -> create a new imported cert (temp name `<NAME>_new_<ts>`),
   bind the UI to it (`system.general.update` + `service.control RESTART
   http`), verify the live SHA1, delete the old UI cert, rename the new one
   to canonical `truenas_tailscale`.

## Dependencies / fragility (acknowledged, low-risk)

* Assumes the Tailscale app container is still named `ix-tailscale-tailscale-1`.
* Assumes `tailscale cert` works from inside the container + `python3` and
  `docker` in cron PATH.
* If a TrueNAS major upgrade re-names the app container, the cron fails
  noisily (script errors); no harm to the UI (existing cert stays until it
  expires ~90d later -> browser warning, NOT a lockout). Recovery: edit the
  `CONT` variable at the top of the script.

## Revert UI to the original self-signed cert

```sh
midclt call system.general.update '{"ui_certificate":1}'   # id=1 = truenas_default (kept)
midclt call service.control RESTART http
```

## Persistence gap

The script + cron entry live only on the TrueNAS box (not in dotfiles; no
TrueNAS deploy mechanism). Reproduce from this README if the box is rebuilt.