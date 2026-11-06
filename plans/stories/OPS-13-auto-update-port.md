# OPS-13: The auto-update port

As the operator, I want the tiered auto-update system ported into
ansible, so that patching survives the rebuild with the same blast
radius rules.

**Status**: planned
**Arc**: v4

## Acceptance criteria

- [ ] Tier A (guests): unattended-upgrades, no CT reboots, ntfy
      summaries
- [ ] Tier B (nodes): security updates, NEVER self-reboot; reboot
      flags surfaced loudly; serialized host reboots stay human-driven
      with HA arm/disarm around them
- [ ] `pve-router` + truenas: notify-only, never auto-reboot
- [ ] Tier C (truenas) notify-only, as before

## Notes

The shipped code + locked decisions live in `services/auto-update/`
(design record: [../design/auto-update.md](../design/auto-update.md)).
The port keeps the tiering decisions and drops the old
reboot-controller's GL-MT2500-era assumptions.
