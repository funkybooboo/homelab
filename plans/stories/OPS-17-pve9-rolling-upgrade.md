# OPS-17: PVE 9 rolling upgrade + platform refresh

As the operator, I want the revived-but-still-PVE-8 fleet upgraded
in place to PVE 9.x (rolling, one node at a time) and the platform
refresh finished -- the Pi re-roles to a QDevice, pve-balance is
deleted in favor of the native Dynamic Load Balancer, and the router
re-platforms onto Proxmox -- so the fleet reaches the modern platform
the original greenfield plan targeted, without ever stopping the
services.

**Status**: superseded 2026-11-22 -- the rolling 8->9 upgrade
EVAPORATED at the revival: the cluster already ran PVE 9.2
(discovered while landing thermaltake; no dist-upgrade was ever
needed). The surviving pieces -- the Pi QDevice re-role, pve-balance's
replacement by the native Dynamic Load Balancer, the router
re-platform (OPS-3/OPS-6), framework's stability check -- continue
as the v5 arc per this file's criteria.
**Arc**: v5 (after the running fleet is converged by v2-v4)

## Acceptance criteria

- [ ] Rolling PVE 8 -> 9 dist-upgrade per node (supported Proxmox path,
      one node at a time, mixed-version windows tolerated; HA
      disarms/migrates guests around each node)
- [ ] Pi: removed from the cluster (pvecm delnode), re-roles to
      QDevice via scripts/setup-qdevice.sh (fresh Raspberry Pi OS +
      corosync-qnetd; the arm64 PVE port is retired for good)
- [ ] pve-balance deleted; HA-managed guests get the native Dynamic
      Load Balancer + the HA arm/disarm maintenance runbook
- [ ] Router re-platform (OPS-3, deferred 2026-11-21): config.xml
      exported, PVE on the V1210, OPNsense VM with imported config,
      LAN cutover window documented
- [ ] Framework's USB-NIC fix verified stable through an upgrade cycle

## Notes

This is where every greenfield platform goal lands, in the order that
keeps services running: services first (revival, v1), IaC second
(v2-v4), platform last (v5). The oxlorg.opnsense release must be
pinned to the OPNsense version at re-platform time (never upgrade
OPNsense ahead of the collection).
