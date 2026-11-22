# OPS-20: The cluster clean-out

As the operator, I want the old fleet's remains -- the surviving CTs,
the templates, the HA orphan resources, and the tailnet's dead device
entries -- removed so that v2 builds on a bare, truthful platform
with nothing stale left for the IaC to drift against.

**Status**: done (shipped 2026-11-22 -- the bare-cluster era flip:
guests, HA, images, fossil configs, and the tailnet graveyard all
swept; verified via the PVE API)
**Arc**: v1.5 (clean-out + access layer; the plan-shift story: old
CTs are cleaned out, NOT revived -- operator directive, revival
evening 2026-11-21; issues item 8's second revision)

## Acceptance criteria

- [x] GATE: tier-0 extraction landed and verified OUTSIDE the truenas
      pool -- `legacy-extraction/manifest.txt` carries sha256 lines
      for vm-109 (vaultwarden), vm-108 (postgres), vm-106 (n8n) from
      the 2026-11-21 whole-CT dumps (2026-11-22; vault at
      /opt/vaultwarden/data, n8n at /.n8n with HOME=/, PGDATA 17).
      The operator's "clean it out" is the remaining go signal
- [x] Guests destroyed: CTs 101 (running, stop first), 102, 110, 116,
      132 + VM templates 100, 114, 115, 117 (2026-11-22: the two
      template CTs + all four VM templates needed manual config
      removal -- their destroy stalled on `chattr -i` over NFS;
      disks were swept first so the configs came out by hand)
- [x] HA orphans removed: all 24 resources deregistered from
      ha/resources.cfg BEFORE destruction (no CRM fights)
- [x] Old `.raw` images on pve-shared deleted (the whole
      images/ tree swept; dumps on pve-backups untouched)
- [x] Tailnet graveyard purged: 30 dead device entries via the admin
      console. PROBE-VERIFIED: this tailnet's API exposes the device
      LIST but no per-device endpoints -- the DELETE route does not
      exist, so the console (Machines page) was the only mechanism.
      DONE 2026-11-22 (operator, incl. the kenny + Pixel 6a eyeballs);
      API verification: 9 devices remain (5 pve nodes, truenas,
      debbie, kelsey-laptop, MacBook Air), serve front still 200.
      Keys already clean (exactly one API token); ACL stays
      default allow-all (considered accept). Bonus delivered:
      jellyfin/navidrome hostnames freed for the fresh v2 CTs
- [x] pve-ha-lrm verified armed on the 4 real nodes (Pi = witness,
      no LRM by design); framework's LRM was found INACTIVE SINCE
      BOOT and started -- it is enabled, so it survives reboots
- [x] Cluster verifies BARE: 5/5 quorate, zero guests, zero HA
      resources, zero templates; API inventory = 5 nodes + 19
      storage + 5 network, nothing else. THE DISCOVERY: the "24 HA
      orphans" were ALSO registered as FOSSIL guest configs under
      /etc/pve/nodes/<node>/lxc/*.conf (invisible to pct/qm, fed
      straight into the resource index) -- swept per-node, plus a
      canary test proved the mechanism first

## Notes

Destructive + storage ops keep the permanent human gate (identity
rule 2): nothing destroys before the manifest check, and the word
"clean it out" comes from the operator. Because CT rootfs lives on
truenas NFS, guest destruction leaves the pve-shared images until
the delete step -- deleting them is insurance against accidental
re-adds and makes the bare-cluster verification honest. The one
live CT (101 alpine-it-tools) is an HA auto-start artifact, not a
revival: it goes with the rest.
