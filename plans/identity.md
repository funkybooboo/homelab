# Identity: the homelab constitution

Every story obeys these rules. They are immutable in the erledigen
sense: a rule change is a new design record that supersedes, not an
edit here.

## The identity

The homelab is a **declaratively managed self-hosted service fleet**: a
small set of machines (Proxmox nodes + a TrueNAS) hosts services for the
household, and this repo describes what should exist -- nodes, network,
guests, services -- so that `make converge` rebuilds reality from the
repo. The fleet is a build artifact of this repo; a machine is a
replaceable part.

## The roles

1. **The household** -- the people who use the services. The homelab
   exists to serve them, not itself.
2. **The operator** -- the person who runs it. Reliable, boring,
   automatable.
3. **The craft** -- professional development is a legitimate homelab
   output; it gets stories of its own so it never competes with the
   other two roles silently.

## The rules

1. **The repo is the source of truth.** Nothing is done on a box that
   is not (re)expressible from the repo; convergence is idempotent.
2. **The human gate is permanent** for cluster-level, storage, and
   destructive ops; guest config may converge automatically.
3. **The tailnet is the access layer**; no service faces the public
   internet.
4. **One flat LAN** (192.168.1.0/24); the IP plan lives in one file.
5. **Every SPOF is documented, not denied** (truenas NFS, the OPNsense
   VM).
6. **Services earn resurrection**: curated, not wholesale; the unused
   stay archived, cheap to resurrect later.
7. **Boot order is a law**: truenas first (on a UPS), then nodes, then
   guests.
8. **The non-goals are constitution**: no Kubernetes, no Ceph, no VLANs
   in v1, no closed-loop push apply of cluster ops.
9. **Tool upgrades respect their pins** (never upgrade OPNsense ahead
   of the matching oxlorg release).
10. **Extract before wipe; the offsite backup (B2) never stops.**
11. **One noun per concept**, used everywhere.
