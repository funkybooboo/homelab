# OPS-21: The tailnet access layer

As the operator, I want the tailnet promoted to THE access layer of
the revived platform -- one subnet router advertising the LAN,
LE-cert serve fronts for the host UIs, and a Tailscale API token for
the v2 automation -- so that every system is reachable from outside
the house over HTTPS with no public exposure anywhere.

**Status**: done (shipped 2026-11-22: the serve front pre-existed
from the old era and verified live; the subnet router + token
landed today; the operator verified off-LAN reachability)
**Arc**: v1.5 (clean-out + access layer; issues item 10a, decided
2026-11-21: secure, idiomatic, HTTPS everywhere)

## Acceptance criteria

- [x] thermaltake (the tailnet's anchor node) advertises
      192.168.1.0/24 via `--advertise-routes`; the operator approves
      the route in the admin console; LAN hosts reachable from a
      tailnet client -- applied via `tailscale set` + persisted
      forwarding 2026-11-22; operator approved + verified from
      off-LAN
- [x] Host UIs fronted with LE certs: PVE 9.2's native tailscale
      integration for the node UIs (thermaltake first, other nodes
      as needed) + `tailscale serve` for service UIs; no plain-HTTP
      path remains the documented way in -- thermaltake's front
      verified live 2026-11-22: https://pve-thermaltake.tail54538d.ts.net
      -> :8006, HTTP 200, LE cert valid; other nodes = as needed
      (none yet)
- [x] Tailscale API token created (admin console Settings > Keys)
      -> `local/tailscale-api.env` (chmod 600; `.example` tracked)
      -- verified live against api.tailscale.com 2026-11-22
- [x] Verified from outside the LAN: the UI answers on its tailnet
      HTTPS name with a valid cert; the direct `:8006` path still
      works on-LAN (thermaltake .3 stays the canonical entry until
      the fronts exist) -- operator verified from phone, off-LAN,
      2026-11-22

## Notes

ONE subnet router, not per-node tailscale: the whole LAN is
reachable through the one advertised route, and a guest gets
tailnet presence only if a service genuinely needs it -- the
guest-mobility design (issues item 10e) keeps NAS mounts
node-agnostic, so nothing binds a service to a node's tailnet
identity. LE certs come from tailscale serve's own provisioning:
no certbot plumbing, no HTTP exposure. The API token lands here so
OPS-7 has device/ACL automation (auth keys for new nodes) on day
one. The 28 dead device entries are purged with OPS-20's clean-out;
the token then keeps the tailnet tidy from v2 on.
