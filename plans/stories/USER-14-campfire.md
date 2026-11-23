# USER-14: Campfire

As a household member, I want ONCE Campfire -- Basecamp's
subscription-free group chat -- running on-cluster, so that
household chat lives on our hardware instead of a vendor's.

**Status**: planned (operator request 2026-11-23; one of the
ONCE trio with USER-15/USER-16)
**Arc**: v3

## Acceptance criteria

- [ ] Manifest + role; CT with nesting (docker-in-LXC -- see the
      pattern note below)
- [ ] Campfire's official Docker image, pinned by digest, via
      `docker compose` + a systemd-managed `compose up`
- [ ] First-boot setup wizard completed by the operator; a
      household member joins and chats
- [ ] Serve front live (`campfire.tail54538d.ts.net`); logs ship
      via the guest journal (promtail picks up the container's
      stdout)

## Notes

PATTERN NOTE (shared by the ONCE trio): these are the fleet's
FIRST container guests -- OPS-20 deliberately retired container
machinery for the curated services, but the ONCE products ship
ONLY as containers (no bare-metal path short of a full Rails
source deploy via Kamal). The exception is made consciously:
docker + compose inside nested CTs, images pinned by digest,
updates via `make update` (OPS-23), never the vendor's `once`
installer -- it self-updates out from under the pin model and
wants to own its host. License check at build time: the repos
are source-available with self-hosting documented upstream.

Port plan: campfire :3000-ish inside the guest, front via
tailnet serve. Household-facing -- model B fits: no LAN exposure
beyond the tailnet.
