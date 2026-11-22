# OPS-20: The cluster clean-out

As the operator, I want the old fleet's remains -- the surviving CTs,
the templates, the HA orphan resources, and the tailnet's dead device
entries -- removed so that v2 builds on a bare, truthful platform
with nothing stale left for the IaC to drift against.

**Status**: planned
**Arc**: v1.5 (clean-out + access layer; the plan-shift story: old
CTs are cleaned out, NOT revived -- operator directive, revival
evening 2026-11-21; issues item 8's second revision)

## Acceptance criteria

- [ ] GATE: tier-0 extraction landed and verified OUTSIDE the truenas
      pool -- `legacy-extraction/manifest.txt` shows vm-109
      (vaultwarden), vm-108 (postgres), vm-106 (n8n) + the tier-1
      tarballs with sha256s; the operator says the word
- [ ] Guests destroyed: CTs 101 (running, stop first), 102, 110,
      116, 132 + VM templates 100, 114, 115, 117 (`pct`/`qm
      destroy`)
- [ ] HA orphans removed: every config-less resource in
      `ha/resources.cfg` (~24 entries) via `ha-manager remove`
- [ ] Old `.raw` images on pve-shared deleted (human-gated storage
      op; the extraction tarballs + B2 are the surviving copies)
- [ ] Tailnet graveyard purged: ~28 dead device entries (the old
      per-CT tailscale nodes) via the admin console -- the API token
      for automated cleanup arrives with OPS-21
- [ ] pve-ha-lrm verified armed + watchdog active on all 5 nodes
- [ ] Cluster verifies BARE: 5/5 quorate, zero guests, zero HA
      resources, zero templates; the API inventory (`/cluster/
      resources`) matches

## Notes

Destructive + storage ops keep the permanent human gate (identity
rule 2): nothing destroys before the manifest check, and the word
"clean it out" comes from the operator. Because CT rootfs lives on
truenas NFS, guest destruction leaves the pve-shared images until
the delete step -- deleting them is insurance against accidental
re-adds and makes the bare-cluster verification honest. The one
live CT (101 alpine-it-tools) is an HA auto-start artifact, not a
revival: it goes with the rest.
