# OPS-14: PBS backups

As the operator, I want Proxmox Backup Server as a VM with its
datastore on truenas, verify jobs scheduled, and one restore drill
completed, so that backups are deduplicated, verified, and provably
restorable.

**Status**: planned
**Arc**: v4 (pending: [../issues.md](../issues.md) item 5)

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

If issues item 5 lands on vzdump instead, this story becomes the
vzdump baseline + the same drill -- either way the deliverable is a
PROVEN restore, not a backup job.
