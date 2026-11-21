# OPS-6: The cluster + QDevice

As the operator, I want the greenfield cluster formed natively on
192.168.1.x with the Pi as a QDevice (not a PVE node), so that quorum
exists without ever hosting guests on arm64.

**Status**: deferred 2026-11-21 (Pi never revives as a PVE node)
**Arc**: v5 (folded into [OPS-17](./OPS-17-pve9-rolling-upgrade.md))

## Acceptance criteria

- [ ] Corosync on 192.168.1.x from formation day (no renumbering debt)
- [ ] Pi runs corosync-qnetd only; never a guest host
- [ ] HA decision recorded per [../issues.md](../issues.md) item 3:
      fleet HA it is -- node-affinity rules (amd64 only) + the
      arm/disarm maintenance runbook + native-balancer policy

## Notes

The old failure modes (arm64 stranding, LRM watchdog resets) are what
the QDevice role and PVE 9.2's HA arm/disarm exist to prevent. The old
`pve-balance` is not rebuilt: the native Dynamic Load Balancer replaces
it (and only manages HA-managed guests -- decided, issues item 3).

REVISED 2026-11-21: under the revival path the Pi stays OFF -- the
3 revived nodes carry quorum (3 of 5) -- and it never comes back as a
PVE node. At v5 (OPS-17) it is removed from the cluster config and
returns as a QDevice. The fleet HA + arm/disarm decisions (issues
item 3) stay exactly as decided; the native balancer arrives with the
v5 platform refresh.
