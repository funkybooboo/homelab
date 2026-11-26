# Quirks: the known gotchas and their fixes

One entry per quirk. Each entry gives the condition, the fix, and
where the fix lives. Code comments link here instead of retelling.

## Proxmox

- **pct has no device passthrough option.** CT device nodes need
  manual `lxc.cgroup2.devices.allow` and `lxc.mount.entry` lines in
  `/etc/pve/lxc/<vmid>.conf`. The nvidia-uvm major number is
  dynamic: read it from `/proc/devices` at apply time, never
  hardcode. (Implemented in `guests.yml`, USER-2.)
- **PVE kernel packages are renamed.** Headers for kernel `X` are
  `proxmox-headers-X`, which provides `linux-headers-X`; the plain
  name shows no candidates. (node_glue.)
- **Destroying a CT can fail with "Configuration file does not
  exist"** when the manifest names the wrong node; the running node
  is in `/cluster/resources`. (guests.yml.)
- **Unprivileged CTs have no /dev/net/tun.** tailscaled runs in
  userspace-networking mode; `PORT=41641` in `/etc/default/tailscaled`
  must stay (the unit runs `--port=${PORT}` and an empty expansion
  is a flag error). The tailscale apt auto-start crashes repeatedly
  before that file exists, so the service start limit is disabled.
  (guest_common.)

## NVIDIA

- **The GTX 1060 has no apt-managed driver.** Debian trixie's 550
  cannot compile against PVE kernel 7.x (mmap_lock API changes),
  and NVIDIA's CUDA repo has dropped the 580 branch, the last one
  supporting Pascal cards. The driver is the upstream `.run`
  580.142: pinned in `group_vars/all.yml`, installed by node_glue
  with `--dkms`; the jellyfin CT installs userspace-only
  (`--no-kernel-module`) from the same pin, so module and libraries
  never diverge.
- **Leftover `.run` residue breaks apt nvidia packages.** The
  `nvidia-installer-cleanup` postinst refuses (debconf exit 30) while
  `/usr/bin/nvidia-uninstall` exists, and debconf preseeding cannot
  answer it (the postinst resets the seen flag). Run the uninstaller
  first, then purge the debian nvidia packages, before any `.run`
  install. See OPS-25/USER-2 history entries.

## Services on the guests

- **sshd in a CT: restart, never reload.** The SIGHUP re-exec dies
  with "Cannot bind any address" after systemd rebinds; a restart
  re-runs the runtime-directory setup and always recovers.
  (guest_common handler.)
- **ssh.socket owns port 22 on Debian 13.** A service reload
  crashes when the socket holds the port; the socket is disabled and
  the plain service owns the port. (guest_common.)
- **Grafana packages create neither the data directory nor the
  journal group.** The role creates `/var/lib/grafana` and adds the
  promtail/grafana user to `systemd-journal`; without both, the
  scrape silently yields nothing.
- **forgejo rewrites `app.ini` at boot and eats blockfile END
  markers.** A blockfile in `app.ini` restart-loops. The role
  verifies the current state first and writes the blockfile only at
  bootstrap; the metrics token is checked by grep, never rewritten.
- **FORGEJO__ environment overrides are ignored when the runtime is
  passed --config.** The role writes app.ini directly instead of
  relying on env overrides.
- **Postgres: REASSIGN OWNED BY is impossible for the bootstrap
  owner.** A pgdata-restored database is postgres-owned; user
  objects need a per-relkind DO-block to reassign before
  migrations run.
- **gitea-mirror secrets are generated only-if-absent**: a
  regenerated ENCRYPTION_SECRET makes stored tokens unreadable.
- **Postgres DDL modules always report changed.** Ownership fixes
  are gated behind count queries so converge stays idempotent.
  (postgres role.)

## Ansible

- **A colon-space inside a task name breaks YAML parsing.** Avoid
  prose colons in `- name:` lines; run a yaml lint pass after
  editing roles.
- **The copy module is slow for thousands of small files** (per-file
  SFTP round trips). Use `ansible.posix.synchronize` with
  `rsync_opts` for large trees. (jellyfin role.)
- **community.proxmox token auth needs proxmoxer >= 2.3**; Debian
  trixie ships 2.2, so node_glue pip-overlays the newer version.

## Extraction and restores

- **The legacy dump archive is the only old-fleet source.** The raw
  disk images were removed in the OPS-20 cleanout, and vmids 101-106
  are reused by the new fleet; the extractor skips those vmids and
  points at `--copy-from-dump`. See
  [data-to-extract.md](./data-to-extract.md).
- **Extractions run under sudo land root-owned with mode 750.** The
  agent and ansible run as nate and cannot read them; `du` reports 0
  and `ls` fails on directories you do not own. Fix: chown the tree
  to nate after extracting.
- **Restore gates check for files, not directories.** An interrupted
  extraction leaves empty directories that an existence check would
  treat as a valid source; the roles test for at least one file, and
  restore markers are written only inside a real restore.

## Tailscale API

- **The v2 device-DELETE route is gone.** Device removal is a
  console action; the devices LIST and the keys routes still work
  (mint-tailscale-key.sh and the expiry check depend on the keys
  route). An unknown tailnet name returns HTTP 200 with an error
  body, not a 404.

## Hardware

- **framework's USB NIC drops off** (same-second disconnect and
  re-enumerate; node stays up, network dies, no corosync leave).
  node_glue installs a udev self-heal that re-applies the network
  config when `nic0` returns. Permanent fix is a PCIe NIC
  (operator-hardware decision).

## Tooling

- **Each oxlorg release is pinned to one OPNsense version.** Verify
  the matching release before any router-as-code playbook; never
  upgrade OPNsense ahead of the collection. (ansible/requirements.yml.)
- **debby's ssh key has a passphrase.** BatchMode ssh works only
  while the user ssh-agent holds the unlocked key; after a reboot
  the agent is empty. `ssh-add -l` is the first check on any
  fleet-wide auth failure; one `ssh-add` restores all hosts.
