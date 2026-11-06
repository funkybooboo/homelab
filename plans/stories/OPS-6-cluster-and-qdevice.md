# OPS-6: The cluster + QDevice

As the operator, I want the greenfield cluster formed natively on
192.168.1.x with the Pi as a QDevice (not a PVE node), so that quorum
exists without ever hosting guests on arm64.

**Status**: planned
**Arc**: v1

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
it (and only manages HA-managed guests -- see the issues item before
choosing "no HA").
