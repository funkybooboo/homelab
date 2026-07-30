# HA recovery -- clearing an `error` state on a stopped CT

When pve-shared (the NFS-backed rootfs storage for almost every CT) goes away --
e.g. TrueNAS lost its static IP, NFS hangs, the TrueNAS host reboots -- every
CT whose rootfs lives on `pve-shared` becomes unstartable. The ones that were
**running** keep their cached pages and look fine; the ones that were **stopped**
for any reason (reboot, onboot race, HA relocation) cannot come back up, because
PVE can't read their disk.

Worse: HA-managed CTs that fail to start get stuck in an `error` state. `pct
start N` then refuses with:

```
Requesting HA start for CT <N>
service 'ct:N' in error state, must be disabled and fixed first
command 'ha-manager set ct:N --state started' failed: exit code 255
status: stopped
```

## The clear-error dance (proven 2026-07-30)

```sh
# 1. Take the CT OUT of HA scheduling -- clears the error flag.
ha-manager set ct:N --state disabled

# 2. Wait for the local resource manager (LRM) on the hosting node to
#    notice the disable + drain its watchdog. ~10-15 s on a healthy node.
sleep 15
ha-manager status | grep ct:N      # should now read "(<node>, disabled)"

# 3. Fix the underlying cause FIRST (the disk must be reachable). For an
#    NFS/pve-shared problem: `pvesm status` must show pve-shared active on
#    the node you intend to start the CT on. If not, fix TrueNAS / NFS first
#    (see services/pve-shared-nfs-remount/ + services/network/).

# 4. Start the CT directly.
pct start N
pct status N                       # -> status: running

# 5. Hand control back to HA (so it becomes managered/relocated again).
ha-manager set ct:N --state started
# HA flips it through "starting" -> "started" within ~10 s.
```

## Why this dance and not just `pct start`?

PVE HA refuses to start a service that's in `error` because the LRM's
watchdog might still consider it "owned + failing" -- starting it yourself
could collide with a pending watchdog reset. The `disabled` state tells
the LRM "stand down", after which `pct start` is safe. Skipping the disable
step gives the exit-255 refusal.

## Notes / edge cases

* **This is NOT for a host crash.** If a whole node dies, HA auto-migrates
  any runnable services it owns to another node (one with a working rootfs
  in pve-shared); those CTs come up cleanly and never go through `error`
  state. The dance above is for the specific case where the service tried
  to start, **failed** (NFS gone / disk IO timeout etc.), and got marked
  poisoned.
* **CTs on `local-lvm` do NOT migrate** -- e.g. ntfy CT 128 (rootfs on
  framework's local-lvm). If its hosting node dies, HA goes through an
  optimistic "started" phantom state on the failover target, but the disk
  is actually stuck on the dead node. Nothing to do about that except
  bring the dead node back; once the disk is reachable the CT restarts
  normally, no dance needed.
* The `disabled` -> `started` flip is reversible; do not leave a CT in
  `disabled` state unless you intend for HA to ignore it across reboots
  (some users do this on purpose for one-off services).
* See `docs/services.md` for which CTs are HA-managed (almost all the
  LXC services). See `services/network/` for the TrueNAS static-IP fix
  that prevents the pve-shared outage cascade at source.

## Reboot-required case: emergency read-only rootfs

A CT running during an NFS suspension can flip its rootfs to
`emergency_ro` (mounted `rw,relatime,emergency_ro`). Sysptoms:
FreshRSS touch/Utime warnings: "Read-only file system" in
`/opt/freshrss/lib/lib_install.php`. Fix is a clean CT reboot:

```sh
pct reboot N
pct exec N -- mount | grep ' / '         # should show (rw,relatime) only
pct exec N -- touch /tmp/rwtest && echo RW_OK || echo STILL_RO
```

The CT re-mounts its rootfs from pve-shared, which by then is active.
Purging `Retry-After` state inside the app cache also helps a stuck
freshrss-style feed daemon (see services/freshrss/README.md).