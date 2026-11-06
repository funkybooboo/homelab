# OPS-3: Router on Proxmox

As the operator, I want OPNsense re-platformed as a VM on a new PVE
node (`pve-router`), so that the router is a guest like everything else
and its box joins the fleet.

**Status**: planned
**Arc**: v1

## Acceptance criteria

- [ ] PVE 9.2 on the router box; OPNsense VM built from the
      bare-metal config.xml export; LAN stays 192.168.1.1
- [ ] WAN bridge (or VLAN trunk) + LAN bridge; virtio NICs;
      CRC/TSO/LRO hardware offload disabled inside OPNsense
- [ ] VM start order 1, qemu guest agent on, generous stop timeout;
      VM disk on local storage (500GB NVMe)
- [ ] Memory budget holds: OPNsense VM gets 2GB of the 4GB LPDDR4
      (soldered, non-upgradable) -- the node stays single-purpose
- [ ] `pve-router` excluded from auto-reboot tiers (notify-only)
- [ ] The SPOF documented: while this VM is down, the LAN loses
      internet/DNS but corosync + NFS keep working (L2)

## Notes

ACPI-shutdown hang is a known OPNsense-on-PVE failure mode: guest agent
+ stop timeout + never auto-reboot the host. Design record:
[../design/greenfield-rebuild.md](../design/greenfield-rebuild.md)
("Router on Proxmox").

Hardware (issues item 1): Protectli Vault V1210 -- Intel N5105, 2x
Intel 2.5GbE (WAN + LAN bridges, one each; no spare port -- consistent
with the flat-LAN rule), 4GB LPDDR4, 500GB Kingston NV3 NVMe, coreboot.
The OPNsense 25.7 config.xml to import is the LIVE config on this box
(today's router at 192.168.1.1); export it before wiping the disk.
