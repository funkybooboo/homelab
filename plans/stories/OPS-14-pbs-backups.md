# OPS-14: PBS backups

As the operator, I want Proxmox Backup Server as a VM with its
datastore on truenas, verify jobs scheduled, and one restore drill
completed, so that backups are deduplicated, verified, and provably
restorable.

**Status**: planned
**Arc**: v4

## Acceptance criteria

- [ ] PBS VM deployed; datastore on truenas; all guests on a backup
      schedule
- [ ] Scheduled verify jobs running (a PBS without verify jobs is
      vzdump with extra steps)
- [ ] One restore drill: a guest restored from PBS to a node, booted,
      verified
- [ ] Offsite story unchanged: truenas B2 keeps running; the old
      `pve-backups` vzdump dataset retired only after the drill

## Notes

If issues item 5 had landed on vzdump instead, this story would be
the vzdump baseline + the same drill -- either way the deliverable is
a PROVEN restore, not a backup job. (It landed on PBS; the operator
provisions truenas access for the datastore.)
