# Data architecture

Decided 2026-11-22 (issues item 15; the design conversation with the
operator). Companion docs: [maintenance.md](./maintenance.md) (updates,
backups, reboots), [network.md](./network.md) (access).

## The policy: one engine, database-per-service

Structured app data CENTRALIZES in the shared postgres (CT 101):
one cluster, **one database + one role per service**.

- One engine to patch, back up, monitor, and point analytics at.
- Never one shared schema: services must not read or migrate each
  other's tables (blast radius, migration collisions, no clean
  per-service restore).
- Per-service scram credentials in `local/` (gitignored); no app
  ever connects as a superuser; the postgres superuser has no
  remote password at all.

## The fleet map

| Service | Store | Why |
| --- | --- | --- |
| n8n, freshrss, linkwarden, forgejo | shared postgres | native support; they land there as their stories run |
| vaultwarden | SQLite (deliberate) | tier-0: its availability must not depend on shared infra; dumped + B2'd independently |
| ntfy | sqlite cache | transient state, not data |
| jellyfin, navidrome, audiobookshelf | embedded DBs | metadata is derived state; the media FILES on NFS are the data |
| prometheus, loki | their own stores | purpose-built; forcing metrics/logs into a RDBMS is an anti-pattern |
| grafana | sqlite + provisioning files | dashboards live in git; rebuild = converge |
| monero | LMDB | inherent to the blockchain |
| superset (when queued) | shared pg + valkey cache | metadata in the cluster; queries per-service databases as sources |

## Practices

1. Credentials: per-service role + password, `local/`, referenced by
   roles; never in git.
2. Migrations: apps own their schemas; we never hand-edit service
   tables; upgrades ride the app's own tooling.
3. Backups, layered: vzdump Saturdays (image, auto-covers new
   guests) + nightly per-database `pg_dump` once services land
   (fast logical restore) + B2 offsite (the pg CT rootfs sits on a
   truenas dataset, so offsite covers it twice) + the old-fleet
   dump archive. A backup is not proven until it has been restored
   (quarterly drill, OPS-14).
4. Monitoring: postgres_exporter on the OPS-11 backlog; slow-query
   log to loki when it matters.
5. Versions: Debian's postgres only (no PGDG); major upgrades ride
   distro releases as their own story.
6. Classification: tier-0 (vaultwarden, isolated), service data
   (shared cluster), media (NFS), ephemeral (metrics/logs/caches
   with retention -- never treated as precious).

## Apache Superset (the goal state)

The reason to centralize: one analytics layer reaches everything.
Superset (when queued) gets its metadata database in the shared
cluster + a valkey cache, then registers each per-service database
as a data source -- cross-service dashboards become possible
*because* the data lives in one engine.
