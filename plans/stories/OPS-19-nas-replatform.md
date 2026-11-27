# OPS-19: NAS re-platform (Proxmox on the truenas hardware)

As the operator, I want the NAS hardware eventually running Proxmox with
the storage function as a guest, so the box joins the managed fleet
instead of being a separate appliance OS.

**Status**: planned (operator-confirmed)
**Arc**: v5 (platform refresh: TrueNAS becomes a Proxmox guest)

## Notes

Raised 2026-11-21 during the revival evening. The idiomatic homelab
shape: PVE on the NAS hardware + truenas as a VM with HBA passthrough
(the disks get a real ZFS controller passthrough), OR the storage role
migrates to a PVE guest with the existing pool imported. Either way:

- This is a MAJOR migration touching the storage layer every CT depends
  on - it needs the v2 IaC converge loop proven first, PBS with a
  verified restore drill (OPS-14), and the B2 offsite current.
- Boot-order law inverts temporarily during migration (truenas-guest
  needs the cluster up before its VM starts) - that chicken/egg is the
  core design risk; the resolution (local-disk VM boot ordering, or a
  small storage VM on a node) is the first thing this story designs.
- Do NOT attempt while the cluster is young. The appliance works.
