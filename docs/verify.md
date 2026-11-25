# Verify -- the kick-the-tires checklist

Every check you can run yourself. The "truth" column was captured
2026-11-23 after the infra batch shipped; expect the same shape
(guests grow, counts grow).

## 1. The https fronts (from any tailnet device)

```
https://adminer.tail54538d.ts.net      -> 200 (DB UI)
https://ntfy.tail54538d.ts.net         -> 200 (subscribe UI)
https://grafana.tail54538d.ts.net      -> 302 (login redirect)
https://prometheus.tail54538d.ts.net   -> 302 (redirect to /graph)
https://vaultwarden.tail54538d.ts.net  -> 200 (password manager UI)
https://forgejo.tail54538d.ts.net      -> 302 (login redirect)
https://gitea-mirror.tail54538d.ts.net  -> 200 (sync app UI)
```

Real LE certs (padlock in the browser). If a front 502s: the guest's
service is down (check 5, below); if it doesn't resolve: tailscale is
off on YOUR device (fronts are tailnet-only).

## 2. Loki (the log pipeline)

Easiest: grafana -> Explore -> datasource **Loki** -> query
`{host=~".+"}` -> logs from all four nodes should stream in.

CLI version (any tailnet device):

```
curl -sG 'http://192.168.1.19:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={host=~".+"}' --data-urlencode 'limit=50'
```

Truth: streams from all 4 nodes (pve-thermaltake, pve-framework,
pve-aspiree15, pve-aspires). The shippers:

```
for ip in 192.168.1.3 192.168.1.4 192.168.1.5 192.168.1.6; do
  ssh nate@$ip systemctl is-active promtail; done   # active x4
```

## 3. Prometheus (metrics)

grafana -> datasource Prometheus, or directly:
`https://prometheus.tail54538d.ts.net` -> Status > Targets.

CLI: `curl -s http://192.168.1.17:9090/api/v1/targets | grep -c '"up"'`

Truth: every target UP, zero down. Targets are generated from the
manifests at converge -- a destroyed guest (state: absent) leaves the
list on the NEXT converge + reload.

## 4. Postgres + adminer

In adminer: server `192.168.1.14:5432`, user `nate`, password in
`local/pg-operator.env` (debbie). The database dropdown shows the
restored `forgejo` + `freshrss`.

From debbie (full tailscale, MagicDNS works for YOUR devices):
`psql -h postgres.tail54538d.ts.net -U nate -d postgres`

From inside a guest: use LAN addresses (MagicDNS is not wired in
guests -- see [access.md](./access.md); the design note).

## 5. ntfy

Phone app (tailscale on) -> server `https://ntfy.tail54538d.ts.net`,
topic `homelab`. Test publish from any tailnet device:

```
curl -d "test ping" https://ntfy.tail54538d.ts.net/homelab
```

Truth: arrives on the phone within seconds.

## 6. The fleet itself (make targets, from ~/Projects/homelab)

```
make converge   # everything green, guests changed=0 (idempotence)
make verify     # read-only drift check, same
make update     # patch pass; prints REBOOT REQUIRED flags when kernels stack
```

Truth: 16 hosts converge green, guests changed=0. The 4 x86 nodes
flagged reboot-required after the first update pass (PVE kernels) --
the runbook is [maintenance.md](./maintenance.md) (one node at a time,
guests recover via onboot, quorum holds).

## 7. The cluster (the PVE view)

`https://192.168.1.3:8006` (or the tailnet front) -> Datacenter:
10 CTs (101 postgres, 102 adminer, 103 ntfy, 104 prometheus,
105 grafana, 106 loki, 201 vaultwarden, 202 forgejo,
203 gitea-mirror, 204 gitea-mirror-codeberg), 5/5 quorate.

CLI: `source local/pve-api.env` + the storage/guest API calls the
scripts use; or just `curl -sk -H "Authorization: Bearer ..."`.

## 8. Backups (the other half of "working")

vzdump: PVE UI -> Datacenter -> Backup -> the `Sat 21:00` job,
all guests -> pve-backups. B2: truenas UI -> Cloud Sync Tasks ->
SUCCESS history. Old-fleet archive: `dump/` on pve-backups (187
volumes), plus the tier-0 extracts on debbie (`legacy-extraction/`).
