# OPS-4: The truenas network move

As the operator, I want truenas moved to the new subnet (static
192.168.1.10, gateway 192.168.1.1) with NFS re-exported and B2 sync
continuing, so that the data layer survives the router swap unchanged.

**Status**: done (shipped 2026-11-21/22; see history.md v1 -- truenas
stable at .10, NFS re-scoped, API write channel live as nate, B2
verified)
**Arc**: v1

## Acceptance criteria

- [ ] Scripted midclt move (aliases + commit; the repro pattern in
      `docs/ha-recovery.md` covers the outage cascade this prevents)
- [ ] NFS exports re-exported on the new subnet; mounts verified from
      a PVE node
- [ ] B2 cloud-sync jobs verified running after the move

## Notes

Everything else on truenas stays as-is: datasets, ACLs, TLS cron, the
B2 task tree. Rule 10: extract before wipe; B2 never stops.

SHIPPED ARTIFACT: `scripts/truenas-network-move.sh` (--check /
--apply; interface + gateway + DNS + NFS-export networks in one
pass). It runs ON truenas as root -- and truenas needs NO console:
root ssh is enabled, so the flow is debbie-side temp alias
(`sudo ip addr add 192.168.8.99/24 dev <nic>`) -> ssh
root@192.168.8.100 -> `sh -s < scripts/truenas-network-move.sh
--apply` (the session drops at commit; reconnect at .10) ->
`sudo ip addr del ...` -> verify from debbie. The operator runs the
two debbie sudo commands; the rest is script-driven (by you or a
directed assistant).
