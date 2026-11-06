# OPS-4: The truenas network move

As the operator, I want truenas moved to the new subnet (static
192.168.1.10, gateway 192.168.1.1) with NFS re-exported and B2 sync
continuing, so that the data layer survives the router swap unchanged.

**Status**: planned
**Arc**: v1

## Acceptance criteria

- [ ] Scripted midclt move (aliases + commit; the repro pattern in
      `services/network/README.md`)
- [ ] NFS exports re-exported on the new subnet; mounts verified from
      a PVE node
- [ ] B2 cloud-sync jobs verified running after the move

## Notes

Everything else on truenas stays as-is: datasets, ACLs, TLS cron, the
B2 task tree. Rule 10: extract before wipe; B2 never stops.
