# pve-balance -- load-aware auto-balancer for the PVE cluster

Proxmox HA does **high-availability** (fence + relocate), not **load
balancing**. It never watches load and never redistributes guests to even
out utilization. `pve-balance` fills that gap: it scores each node's load
*relative to its hardware*, and when the spread exceeds a threshold it
live-migrates one guest from the hottest node to the coolest same-arch node
that can absorb it, then exits. Run on a timer, it converges the cluster
toward balance one migration per cycle.

Safe to auto-migrate because every CT rootfs lives on shared storage
([`pve-shared` NFS](../pve-shared-nfs-remount/)), so `ha-manager crm-command
migrate` / `pct migrate` move only live state + the pmxcfs config pointer --
no disk copy, a sub-second-to-seconds pause per migration.

## Files in this directory

| file | what
| --- | ---
| `pve-balance`         | The scheduler script (Python3 stdlib only; calls `pvesh`). Deployed to `/usr/local/sbin/pve-balance`.
| `pve-balance.service` | systemd oneshot unit (calls the script once, then exits).
| `pve-balance.timer`   | systemd timer: starts the service every 1h (+ once 3min after boot).

## Cluster coordination (why it runs on EVERY node, not one)

All 4 x86 cluster nodes run the same script + the same timer. They coordinate
through two files on `/etc/pve/` -- the Proxmox cluster filesystem (pmxcfs),
replicated to every node by corosync:

* `/etc/pve/pve-balance/state.json` -- shared cooldown memory. A guest moved
  by node A's run is in cooldown for node B's next run, so a guest is never
  bounced twice within `COOLDOWN_HOURS`.
* `/etc/pve/pve-balance/lock` -- a heartbeat lock
  (`<holder-node> <pid> <epoch>`). A peer defers while the lock is fresh
  (age < `LOCK_TTL` = 15 min) and the holder is online; a stale lock (the
  holder fenced/crashed) is taken over after `LOCK_TTL`. On clean exit the
  holder removes its lock.

pmxcfs is FUSE-backed and does **not** provide real POSIX `flock` mutual
exclusion across nodes, so the lock is a *heartbeat* (read age/holder, claim,
re-read to win a race) rather than an atomic CAS. Two peers can still both
win in the same wall-clock second on rare collision -- the consequence is two
migrations in one interval instead of one, and **both still monotonically
converge the cluster**; the shared cooldown prevents the same guest being
moved twice. A startup jitter (random `0..JITTER` = 0..120s sleep for
non-interactive `--apply`, e.g. the systemd timer) spreads the per-node timers
across a 2-minute window so collisions are rare. The lock is a strong
throttler, not a hard mutex -- by design, because the balancer is
safe-by-construction even if it double-fires.

**Redundancy:** if the node that currently holds the lock is fenced, its lock
goes stale and another node takes over within `LOCK_TTL` on its next tick. No
single node is the scheduler -- any of the 4 can be.

Not deployed to `raspberrypi` (arm64 quorum-witness; it cannot host amd64
guests and stays a pure witness -- see [`docs/cluster.md`](../../docs/cluster.md)).

## Install (identical on each of the 4 x86 nodes)

```sh
install -m 755 -o root -g root pve-balance         /usr/local/sbin/pve-balance
install -m 644 -o root -g root pve-balance.service  /etc/systemd/system/pve-balance.service
install -m 644 -o root -g root pve-balance.timer    /etc/systemd/system/pve-balance.timer
systemctl daemon-reload
systemctl enable --now pve-balance.timer
/usr/local/sbin/pve-balance          # dry-run sanity check
```

One-liner fan-out from a machine that can reach all nodes over Tailscale:

```sh
for n in pve-aspires pve-aspiree15 pve-thermaltake pve-framework; do
  scp pve-balance pve-balance.service pve-balance.timer "root@$n.tail54538d.ts.net:/tmp/"
  ssh "root@$n.tail54538d.ts.net" '
    install -m755 /tmp/pve-balance         /usr/local/sbin/pve-balance &&
    install -m644 /tmp/pve-balance.service  /etc/systemd/system/ &&
    install -m644 /tmp/pve-balance.timer    /etc/systemd/system/ &&
    systemctl daemon-reload && systemctl enable --now pve-balance.timer'
done
```

## How one run works

1. **gather** -- `pvesh get /nodes` (cores, cpu, mem, maxmem) +
   `pvesh get /nodes/<n>/status` (loadavg, mem.available, arch via
   `cpuinfo.model`/`kversion`). Each `pvesh` has a 12s subprocess timeout; a
   stalled node is skipped. `pvesh get /cluster/resources --type vm` (running
   guests + per-guest cpu/mem/maxmem). `pvesh get /cluster/ha/resources` (HA
   set).
2. **score** (stable, anti-flap) = `W_CPU * load15/cores + W_MEM * memused/memtotal`.
   Uses the **15-min** load average (not 1-min) for decision stability.
   Scoped **per arch**: the arm64 witness never anchors the min or receives a
   guest.
3. If the family gap <= `THRESHOLD` (0.15): no-op. Else src = hottest, dst =
   coolest same-arch with mem headroom. Pick candidate guest on src: rank by
   `maxmem`-first if src is mem-constrained, else `cpu`-first. Per-guest arch
   match enforced. Per-guest **shared** cooldown (`COOLDOWN_HOURS`=3). Mem-fit
   limit (`MEM_FIT_LIMIT`=0.85) on dst.
4. **accept** -- monotone convergence: move iff `new_dst_score <= new_src_score`
   (destination stays lighter than source after the move = no overshoot) AND
   the family gap strictly shrinks. One migration per run is one
   gradient-descent step; converge over runs, not close-in-one.
5. **execute** -- HA-managed -> `ha-manager crm-command migrate <sid> <dst>`;
   non-HA lxc -> `pct migrate`; non-HA qemu -> `qm migrate --online`.

## Config (edit top of `/usr/local/sbin/pve-balance`; no daemon-reload needed)

| name | default | meaning
| --- | --- | ---
| `EXCLUDE_NODES`      | `["pve-framework"]` | never RECEIVE guests here. pve-framework is the flaky USB-NIC fence node; remove once the NIC is fixed physically so it can receive.
| `W_CPU` / `W_MEM`    | 0.7 / 0.3           | score weights.
| `THRESHOLD`          | 0.15               | act only if the within-arch score gap exceeds this.
| `MEM_FIT_LIMIT`      | 0.85               | never push a target's mem_pressure above this.
| `COOLDOWN_HOURS`     | 3                  | don't move the same guest again within N hours (anti-thrash; shared via /etc/pve).
| `LOCK_TTL`           | 900 (15 min)        | freshness window for the cluster lock; takeover-after-crash latency.
| `JITTER`             | 120                 | max random startup delay (s) for timer runs (spreads peer collision).

## Operating it

```sh
/usr/local/sbin/pve-balance                 # dry-run: show what the NEXT run would do (no lock, no change)
/usr/local/sbin/pve-balance --apply --immediate   # run one cycle right now (manual; skips jitter)
/usr/local/sbin/pve-balance --json            # machine-readable
systemctl list-timers pve-balance.timer      # cadence + next fire
systemctl stop  pve-balance.timer            # pause cluster-wide (do on every node)
journalctl -u pve-balance.service           # systemd view of each run
tail /var/log/pve-balance.log                # per-node audit trail (logs stay LOCAL -- pmxcfs is size-limited)
cat /etc/pve/pve-balance/state.json          # shared cooldown history (cluster-wide)
cat /etc/pve/pve-balance/lock                # current lock holder ("node pid epoch")
```

Audit across the cluster: `for n in pve-aspires pve-aspiree15 pve-thermaltake pve-framework; do echo "== $n =="; ssh root@$n.tail54538d.ts.net tail -5 /var/log/pve-balance.log; done`

## Honest caveats

* `loadavg` includes uninterruptible (D-state / I/O-wait) tasks -- common
  here, since guests hit the `pve-shared` NFS store -- so the score reflects
  the load users *feel*, not pure %cpu. The monotone + cooldown guards absorb
  the imprecision of projecting a single guest's contribution.
* One live-migration pause (~sub-second to a few seconds) per hour when the
  cluster is imbalanced. It touches production CTs unattended. Raise the timer
  cadence / `THRESHOLD` if you want less churn.
* It only moves **FROM** the hottest node, so it will not drain a deliberately
  quiet/excluded node. `pve-framework`'s 4 media CTs remain reboot-with-node
  until the NIC is fixed; move them manually if you want them off the flaky
  box (`pct migrate <vmid> <stable-node>`).
* VMs: the 4 VMs are stopped templates today. If you run real VMs later they
  flow through the same balancer via `qm migrate --online`.