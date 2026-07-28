# Laptop PVE nodes -- lid-ignored + screen-off

Both laptop PVE cluster nodes (`pve-aspiree15` = 192.168.8.103, `pve-aspires`
= 192.168.8.102) must keep running with the lid closed (closing the lid would
trigger HA failover otherwise). Panel backlight is also turned off at boot to
save power and not backlight a headless server.

Needed only on these two; `pve-thermaltake` (desktop no lid), `pve-framework`
(unverified lid), `raspberrypi` (Pi no lid) do NOT get this.

## Files on each node

### 1. `/etc/systemd/logind.conf.d/no-lid-suspend.conf`

```ini
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
```

Then `systemctl reload systemd-logind` (SIGHUP re-reads drop-ins). The
default compiled-in `HandleLidSwitch=suspend` is why closing the lid
suspended the node before this drop-in was in place.

### 2. `/etc/systemd/system/screen-off.service`

```ini
[Unit]
Description=Turn off laptop panel backlight at boot
After=basic.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'echo 4 > /sys/class/backlight/intel_backlight/bl_power 2>/dev/null; setterm --blank force --powersave powerdown >/dev/console 2>&1 </dev/console || true'

[Install]
WantedBy=multi-user.target
```

Then `systemctl daemon-reload && systemctl enable --now screen-off.service`.

`bl_power=4` = `FB_BLANK_POWERDOWN` -> panel backlight OFF (not brightness=0;
brightness is `raw intel_backlight` type, separate control). `setterm
powersave powerdown` on `/dev/console` adds console DPMS.

## Verify

```sh
systemd-analyze cat-config systemd/logind.conf | grep HandleLidSwitch
systemctl is-enabled screen-off.service  # enabled
systemctl is-active screen-off.service    # active
cat /sys/class/backlight/intel_backlight/bl_power  # 4
```

The real proof is behavior: close the lid, check uptime continuity + journal
shows `Lid closed.` with NO following `PM: suspend entry`:
```sh
journalctl -b --since "5 min ago" | grep -iE "lid|suspend|PM:"
```

## Notes

* `systemctl show systemd-logind -p HandleLidSwitch` returns EMPTY on this
  systemd version -- do NOT trust that to verify; verify by behavior.
* `screen-off.service` is `oneshot` -- only runs at boot. If something
  unblanks the panel later (kernel event, getty input) it won't re-darken.
  Acceptable for a headless server (no keyboard). If needed, make a path/watch
  unit on `bl_power` or a timer.
* No inhibitors (`loginctl list-inhibitors` empty); no other power manager
  (upower/tlp/acpidpower) running -- systemd-logind is the sole lid actor on
  these server installs.

## Persistence gap

These PVE nodes aren't managed by `~/dotfiles/migrate.sh`; the two files live
only on the two nodes. Reproduce from this doc if a node is rebuilt.