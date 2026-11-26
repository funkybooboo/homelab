# Debugging: the look order + the query toolbox

When something misbehaves. Companion docs:
[verify.md](./verify.md) (is it working?),
[maintenance.md](./maintenance.md) (keeping it working),
[quirks.md](./quirks.md) (known gotchas and their fixes).

## The look order (fastest signal first)

1. **The phone** -- ntfy topic `homelab` carries state changes:
   node up/down, front failures, down exporters, disk and memory
   thresholds. The debbie-side watcher checks every five minutes
   and deduplicates by state.
2. **Grafana** (https://grafana.tail54538d.ts.net) -- Explore:
   - Metrics (Prometheus): is the box up? node_* series.
   - Logs (Loki): `{host=~".+"}` -- every host's journal.
3. **The failing host** -- `ssh nate@<ip>` + journalctl (below).
4. **The cluster** -- the PVE UI (https://192.168.1.3:8006 or the
   tailnet front): node states, guest states, task log.
5. **[verify.md](./verify.md)** -- the endpoint checklist.

## Journal toolbox

```bash
journalctl -u <unit> -n 50 --no-pager          # a service's last lines
journalctl -k -b -1 --no-pager | tail -30      # the previous boot's last lines
journalctl -b -1 -p err --no-pager | tail -10  # previous boot's errors
journalctl --since "15 min ago" -p warning     # recent warnings
journalctl --list-boots                         # crash/cycle history
```

In grafana Explore (Loki datasource), the same view:
`{host="pve-framework", unit=~".*"}` -- no ssh needed.

## Prometheus queries worth memorizing

```text
up == 0                              # anything not scraped (the watcher alerts this)
100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)   # mem %
100 * (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})   # free disk %
node_systemd_unit_state{name=~"(.+)"}  # service states
pg_stat_database_size_bytes            # postgres db sizes
pg_stat_activity_count                 # postgres connections
```

## Facts about the observability stack

- Every guest is born with node_exporter and promtail (journald to
  loki); new services inherit both.
- The watcher reads `guests/*.yaml` for the front list: a new
  service with `tailnet_serve` is under watch on the next cycle.
- Retention: 14 days of logs (loki), about 15 days of metrics
  (prometheus).
- Alerting is the lean tier: debbie-side checks to ntfy. The v4
  upgrade path (prometheus rules + alertmanager) is in the
  [offsite alerting design](../plans/design/offsite-alerting.md).
