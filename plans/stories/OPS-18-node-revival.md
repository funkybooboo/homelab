# OPS-18: Node revival

As the operator, I want the 3 healthy old PVE nodes revived in place
on the new LAN -- static IP from its host_vars, renumbered corosync,
storage + DNS refs fixed -- so that the entire existing service fleet
comes back without reinstalling anything.

**Status**: done (shipped 2026-11-21/22 -- see history.md v1; ALL 5
nodes revived: framework needed no hardware fix (a cold boot;
USB autosuspend hardening queued as insurance), Pi rejoined as a
5th member + witness per operator directive. The CT-side steps
(nameservers, HA auto-start, error-state dance) were MOOTED by the
same evening's plan shift: the old CTs clean out via OPS-20 and
never revive)
**Arc**: v1 (revival; supersedes the fresh-install approach -- issues
item 8, revised 2026-11-21)

## Acceptance criteria

- [ ] `scripts/revive-node.sh --survey` run against every booted node
      BEFORE any change (read-only state dump: pveversion, corosync
      nodelist, interfaces, storage.cfg)
- [ ] Per node, driven over ssh after the operator's console key-drop:
      static IP applied from `host_vars`, fleet `/etc/hosts`, `pvecm
      expected 1` + corosync.conf ring0_addr swap (name->new-ip map
      from the nodelist itself, self-verifying), detached ifreload +
      corosync restart; operator reconnects at the new IP
- [ ] Third node up = real 3-of-5 quorum (thermaltake, aspires,
      aspiree15); framework + Pi stay OFF (framework = NIC fix first;
      Pi = never revives as a PVE node, it re-roles at v5)
- [ ] `--post-quorum`: storage.cfg `.100` -> `.10`, thermaltake media
      fstab fix + remount, batch `pct set --nameserver 192.168.1.1`
      over every CT (the old dead `192.168.8.1` is hardcoded in all)
- [ ] HA auto-start settles; any `error`-state CTs cleared via the
      documented dance (docs/ha-recovery.md); jellyfin via its
      start-jellyfin unit; ntfy started manually (not HA)
- [ ] truenas moved (OPS-4) BEFORE quorum so NFS is right when LRM
      starts things

## Notes

No disk on any node is touched except config edits with backups to
`/root/*.pre-revive` -- CT rootfs lives on truenas NFS, never at risk.
When framework eventually boots (NIC fixed), it needs the same 2-minute
conf swap (its local corosync.conf missed the renumber). The Pi never
boots as a PVE node again; at v5 it is removed from the cluster config
and returns as a QDevice (OPS-17). pve-balance's timer dies with the
Pi staying off; disable it when the Pi re-roles.
