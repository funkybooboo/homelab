# OPS-3: Router on Proxmox

As the operator, I want OPNsense re-platformed as a VM on a new PVE
node (`pve-router`), so that the router is a guest like everything else
and its box joins the fleet.

**Status**: planned
**Arc**: v1 (blocked: [../issues.md](../issues.md) item 1)

## Acceptance criteria

- [ ] PVE 9.2 on the router box; OPNsense VM built from the
      bare-metal config.xml export; LAN stays 192.168.1.1
- [ ] WAN bridge (or VLAN trunk) + LAN bridge; virtio NICs;
      CRC/TSO/LRO hardware offload disabled inside OPNsense
- [ ] VM start order 1, qemu guest agent on, generous stop timeout;
      VM disk on local storage
- [ ] `pve-router` excluded from auto-reboot tiers (notify-only)
- [ ] The SPOF documented: while this VM is down, the LAN loses
      internet/DNS but corosync + NFS keep working (L2)

## Notes

ACPI-shutdown hang is a known OPNsense-on-PVE failure mode: guest agent
+ stop timeout + never auto-reboot the host. Design record:
[../design/greenfield-rebuild.md](../design/greenfield-rebuild.md)
("Router on Proxmox").
