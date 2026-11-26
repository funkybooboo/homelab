# Maintenance: updates, the fleet loop, reboots

Companion docs: [backups.md](./backups.md) (what is protected),
[debugging.md](./debugging.md) (what to do when something breaks),
[quirks.md](./quirks.md) (known gotchas).

## Update tiers (blast radius)

| Tier | Who | Automatic | Reboots |
| --- | --- | --- | --- |
| A | every CT guest | unattended-upgrades, security-only, daily; needrestart live-restarts upgraded services | never needed: CTs share the host kernel |
| B | 4 PVE nodes + Pi | unattended-upgrades, security-only; PVE packages wait for the weekly pass (pve-no-subscription mixes everything) | never self-reboot; cluster services restart only with the node |
| C | truenas, router | nothing; applied via UI with a console nearby | manual |

Unattended stays limited to the security repo (blind-applied
patches must be the safe class); full upgrades happen in the weekly
pass where the operator sees the list.

## The fleet loop

```
make converge   # guests/*.yaml -> running state, idempotent
make update     # tier-gated dist-upgrade pass; never reboots
make verify     # read-only drift check
```

Weekly habit, about ten minutes: `make update`, `make verify`,
read the reboot flags. When node kernels stack up, run the reboot
runbook.

## Node reboot runbook

`scripts/reboot-node.sh` is the runbook, executable. With no
arguments it reboots every node flagging reboot-required, one at a
time; name nodes to choose the order. It checks quorum and an idle
backup window before starting, verifies each node's return, full
quorum, and every guest's recovery before touching the next node,
and aborts on any failed gate. It is run by the operator only; it
is never scheduled. `--dry-run` rehearses the gates without
rebooting.

Background: HA placement for guests is not wired yet (OPS-6), so a
node reboot briefly interrupts the guests on that node; they
recover via `onboot: true`. Never reboot two nodes at once.
