# services/ -- the old fleet's operational assets (archive + restore
# reference)

Old-fleet per-service assets. The v2 implementation lives in
`ansible/playbooks/roles/` + `guests/*.yaml`; these stay as:

- **restore-time data**: freshrss/feeds.opml (the operator's feed
  list -- the freshrss story needs it), ntfy bridge code
- **decision records**: auto-update/ (OPS-13's source; superseded
  by the node_glue + guest_common update roles, OPS-23),
  observability/ (the old pair's configs -- reference for fresh
  dashboards)
- **possibly still live**: nvidia-uvm-devnodes/ (thermaltake's GPU
  runtime; verify before assuming it is dead), pve-tls/ +
  truenas-tls/ (renewal scripts from the pre-serve-front era),
  pve-shared-nfs-remount/ (node glue from before node_glue)

Each v2 service story should check here before rebuilding -- these
are the human contracts the roles implement.
