# Debugging -- the look order + the query toolbox

The observability foundation (2026-11-23): logs, metrics, and
notifications exist from birth on every host. This is the runbook
for when something misbehaves. Companion docs:
[verify.md](./verify.md) (is it working?), [maintenance.md](./maintenance.md)
(keeping it working), [access.md](./access.md) (getting in).

## The look order (fastest signal first)

1. **The phone** -- ntfy topic `homelab` carries state changes:
   node up/down (urgent), front failures, down exporters, disk/memory
   thresholds. The debbie-side watcher (every 5 min) is the first
   responder -- it found framework's vanish before anything else.
2. **Grafana** (https://grafana.tail54538d.ts.net) -- Explore:
   - **Metrics** (Prometheus): is the box up? node_* series
   - **Logs** (Loki): `{host=~".+"}` -- every node + guest journal
3. **The failing host** -- `ssh nate@<ip>` + journalctl (below).
4. **The cluster** -- PVE UI (https://192.168.1.3:8006) or the
   serve front: node states, guest states, task log.
5. **docs/verify.md** -- the endpoint checklist, curl by curl.

## Journal toolbox

```bash
journalctl -u <unit> -n 50 --no-pager          # a service's last words
journalctl -k -b -1 --no-pager | tail -30      # the PREVIOUS boot's last
                                               # words (post-crash forensics)
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
pg_stat_database_size_bytes            # postgres db sizes (the exporter)
pg_stat_activity_count                 # postgres connections
```

## The incident archive (what we already learned)

- **framework vanish x3 (Jul/Sep/Nov 2026)** -- signature:
  `r8152 ... USB disconnect` + same-second re-enumeration; node keeps
  running, network dead, no corosync leave message. Mitigation:
  node_glue's udev self-heal (ifreload on nic0 return). Permanent
  fix: PCIe NIC (pending operator).
- **The old fleet's reboot controller** -- armed automation
  reboots; the lesson: cluster-level actions stay human-gated.
- **Service crash-loops** -- check the unit + the data dir exists +
  the user's groups (grafana packages ship without data dirs and
  without the journal group; fs.protected_regular makes stale
  root-owned files poison O_CREAT).
- **Jinja '\1' in templates** = octal escape = invisible control
  chars in generated configs. The full trap index lives in the
  OPS-7 story's as-built notes.

## The practices

- **Every guest is born observable** -- guest_common installs
  node_exporter + promtail (logs to loki) + the tailscale front;
  new services inherit all three automatically.
- **Alerts are state changes, not states** -- the watcher dedups by
  state file; you hear when things CHANGE, never on a schedule.
- **The repo is the source of truth** -- the watcher reads
  guests/*.yaml for the front list; a new service with
  `tailnet_serve` is under watch on the next 5-minute cycle.
- **Log retention 14 days** (loki), metrics ~15 days (prometheus) --
  the debugging trail outlives the incident by weeks.
- **Lean alerting tier** (2026-11-23 decision): debbie-side checks.
  The v4 upgrade path is prometheus rules + alertmanager -> ntfy
  when the fleet's size asks for silences/grouping.
