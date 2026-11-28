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
  never diverge. The pin is deliberate (Pascal's terminal branch) --
  `scripts/roll-pins.sh` never touches it.
- **Leftover `.run` residue breaks apt nvidia packages.** The
  `nvidia-installer-cleanup` postinst refuses (debconf exit 30) while
  `/usr/bin/nvidia-uninstall` exists, and debconf preseeding cannot
  answer it (the postinst resets the seen flag). Run the uninstaller
  first, then purge the debian nvidia packages, before any `.run`
  install. See the NVIDIA entries in [plans/history.md](../plans/history.md).

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
  disk images no longer exist; vmids 101-106 are reused by the
  new fleet, and the extractor skips those vmids and points at
  `--copy-from-dump`. See
  [archive.md](./archive.md).
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

- **framework's USB NIC drops off** (spontaneous bus-level
  reset; node stays up, network dies, no corosync leave).
  2026-11-27 postmortem: the death is an RTL8156 firmware-level
  flake -- NOT autosuspend (the keep-awake rule was active and
  it died anyway; rule deployed 36 s before the event). The
  11-hour outage was SOFTWARE: the heal rule matched
  `KERNEL=="nic0", ACTION=="add"` -- but a fresh USB netdev
  ADDs as `eth0` and only later MOVEs to nic0, so the rule
  matched NO event, and the rules file had not been armed
  anyway (udevd caches rulesets; a copy without
  `udevadm control --reload` is inert). The heal package
  (node_glue, gated by `usb_nic: true` in host_vars) is now:
  MAC-matched udev rule on add|move + the udevd reload + a
  one-minute watchdog ladder (ifreload -> bus replug via
  authorized toggle -> guarded reboot, max one per 30 min).
  LIVE DRILL PROOF (2026-11-27): deauthorized the NIC at
  12:21 -- watchdog noticed in 45 s, replugged at rung 3,
  udev heal re-enslaved, node back in 3.5 min, zero human.
  The drill script pattern (authorized-toggle + T+8 safety
  net) is the sanctioned way to re-verify after any change.
  Hardware notes: this is a laptop mainboard (11th-gen i7,
  USB-C power) in a desktop case -- NO PCIe slots exist, a
  PCIe NIC is impossible; the ethernet card is not on LVFS
  (fwupd survey: 19 devices, no NIC), so no firmware update
  path exists either. Operator decision 2026-11-27: keep the
  hardware, let the watchdog absorb the flake (revisit only
  if the journal shows frequent events); a generic USB-C
  dongle swap stays available as a data-driven fallback.

## Tooling

- **Each oxlorg release is pinned to one OPNsense version.** Verify
  the matching release before any router-as-code playbook; never
  upgrade OPNsense ahead of the collection. (ansible/requirements.yml.)
- **debby's ssh key has a passphrase.** BatchMode ssh works only
  while the user ssh-agent holds the unlocked key; after a reboot
  the agent is empty. `ssh-add -l` is the first check on any
  fleet-wide auth failure; one `ssh-add` restores all hosts.

## Restored media metadata

- **The restored media databases reference the legacy in-CT paths**
  (`/mnt/media/media/<library>`). The media manifests bind the node
  NFS mounts there on purpose, so the restored jellyfin library
  database and audiobookshelf metadata resolve files with zero
  database surgery. A fresh install would prefer `/media/<library>`;
  changing the bind paths later requires migrating the databases.

## Browser playback

- **H.264/AAC video spins forever in the browser while MP3/FLAC
  services play fine**: check which BROWSER first, then the
  machine's codecs. Two separate causes, same symptom:
  1. **LibreWolf upstream builds ship without the patented codec
     decoders** (H264/HEVC/AAC) -- deliberate upstream policy;
     about:support -> Media shows them "Unsupported" forever, and
     no package or pref adds back a decoder the build lacks. The
     web client then asks for a VideoCodecNotSupported transcode
     and its own HLS engine rejects the fallback manifest
     (manifestIncompatibleCodecsError). Media playback belongs in
     a codec-capable browser (plain Firefox on debbie).
  2. **A codec-capable Firefox-family browser still needs the
     system GStreamer set**: gst-libav on the browsing machine
     (dotfiles migration 000601) + a full browser restart.

## Docker inside unprivileged CTs

- **Container guests need two things the PVE API create call cannot
  give.** The generated apparmor profile denies the mounts
  docker/containerd/runc rely on; unlocking them is two guarded
  config lines plus nesting, all applied by play 2 on any
  manifest with a `container:` block (or `features:` entries):
  1. `features: nesting=1` -- PVE 9's `pct set` rejects the bare
     `nesting` form (key=value only), and the creation module has
     no features parameter at all.
  2. Two raw apparmor lines: `mount fstype=overlay,` AND
     `mount options=(rw, move),`. The parser rejects fstype and
     options in ONE rule (`mount fstype=overlay options=...` is
     invalid), so both lines are required; `options=(rw, move)`
     is the only valid form for the move-mount stage.
- **The manifests' `features:` field was consumed by nothing
  until USER-3** -- every CT ran without nesting since creation,
  which the ntfy manifest comment claimed was set. Play 2 now
  converges it, which restarted every CT once (the one-time cost
  of a config line the manifests always claimed).
- **Five CTs doing parallel dpkg over pve-shared (NFS) stall the
  host's I/O** (jbd2 on the loop rootfs in D-state, iO pressure
  ~95%, load ~28 with idle CPUs). Small-file writes over NFS are
  the fleet's known enemy; the first container-guest converge did
  this five at once. Not worth serializing -- the run finishes in
  tens of minutes -- but expect a slow node during any
  multi-CT package wave.

## Guest-to-guest service access uses LAN IPs

- **MagicDNS names do not resolve inside guests.** CT resolv.conf
  comes from the node (the router at 192.168.1.1); tailscaled
  answers 443 serve traffic but does not provide the resolver.
  A restored config pointing at a MagicDNS host name (the old
  fleet's freshrss used `postgresql.tail54538d.ts.net`) fails
  with "could not translate host name". Guest-to-guest uses the
  manifest IPs (postgres = 192.168.1.14, the adminer pattern);
  MagicDNS names are for tailnet DEVICES.

## Moving a CT off an offline node

- **Framework's USB-NIC death made the recipe relevant the same
  week the fleet grew.** With the source node unreachable and
  the rootfs on shared storage, relocating a guest is a pmxcfs
  config move: `mv /etc/pve/nodes/<down-node>/lxc/<vmid>.conf
  /etc/pve/nodes/<target>/lxc/` then `pct start <vmid>` on the
  target. Valid here because HA is idle BY DESIGN (no CRM to
  fight) and every disk lives on pve-shared. Update the
  manifest's `node:` to match or the next converge fights it.
  pct migrate cannot run against an offline node.

## LibreWolf on debbie

- **The profile lives at `~/.config/librewolf`** (XDG layout),
  not the documented `~/.librewolf` -- grep the right tree.
- **"LibreWolf is already running, but is not responding" with
  no live process = stale profile locks.** A wedged instance
  can exit without cleaning `.parentlock`/`lock` under
  `~/.config/librewolf/librewolf/<profile>/`; delete both files
  and the browser opens. The same wedge is what made webapps
  (excalidraw among them) misbehave -- a full close/reopen
  cures canvas apps in LibreWolf; only media playback is
  hardware-blocked (the codec build policy above).

## The OPNsense API surface (OPS-28 build notes)

- **Four surfaces are UI-only on OPNsense 25.7**: interface
  assignment (wg0/tailscale0), gateway groups, System > Settings
  > General ("Gateway switching"), and the DNS settings pages.
  Everything else (wireguard instance+peer, gateways, aliases,
  rules, source NAT, the tailscale plugin) drives via the API
  with /api/... routes -- the oxlorg collection's module files
  are the reliable route-name map when guessing fails.
- **This build selects the default gateway by the classic
  `defaultgw` flag, not the docs' newer "upstream + priority"
  model.** The election only happens at a trigger (startup /
  interface event) -- after flag changes, a router reboot is the
  clean trigger (and doubles as the boot-order drill).
- **Model field trivia that cost rounds**: alias `content` is
  newline-separated, not comma; the WG *peer's* AllowedIPs must
  be 0.0.0.0/0 + ::/0 (the conf's [Peer] section) or nothing
  routes through the tunnel; SNAT translation target wants a
  literal address (10.2.0.2), not an unassigned interface label
  -- `opt1` as target left pf with "no IP address found" and the
  ruleset fell back to the last good one.
- **os-tailscale**: settings are API-settable but the daemon's
  flag template (rc.conf.d) regenerates only through the plugin
  UI's Save/Apply -- API sets stage the model, the UI click
  applies it. Enrollment is the AuthURL flow (status page);
  the preAuthKey slot exists but did not consume a key.
- **The Proton conf's PrivateKey is redacted on re-download**
  ("*****"); it exists only in the creation popup.

## The OPNsense API surface (additions)

- **The mutable-settings POST shape needs the top-level model
  key**: `/api/unbound/settings/set` with a FLAT payload
  returns `"saved"` and persists NOTHING (silent no-op);
  `{"unbound":{"forwarding":{...}}}` is the real shape. Always
  re-GET after every set to prove the field landed.
- The template-cache converge check can time out (5 s) on a
  node busy after a CT migration wave -- transient; a re-run
  passes. Do not chase it.

## Firefox sync (USER-5 build, 2026-11-28)

- **The merged syncserver binary's config sections are
  `syncstorage` and `tokenserver`** (verified by grepping the
  image for its own strings + compiled defaults). Env names
  follow the config-crate `PREFIX_SECTION__KEY` convention, so
  the storage URL is `SYNC_SYNCSTORAGE__DATABASE_URL` -- NOT
  `SYNC_STORAGE__...`, which is silently ignored and the binary
  dials its compiled default `mysql://root@127.0.0.1/syncstorage`
  (fails as connection-refused-to-localhost, a misleading error).
  `SYNC_TOKENSERVER__DATABASE_URL` is correct as named.
- **The binary binds container-loopback by default**: without
  `SYNC_HOST=0.0.0.0` it listens on 127.0.0.1 INSIDE the
  container netns, which docker-proxy cannot reach -- every
  request resets at the kernel. ss in the CT still shows the
  LISTEN (that is docker-proxy), so "listening but resetting"
  is this trap's signature.
- **"env:" is 4 characters.** The container_guest secret-token
  slice is `[4:]`. `[5:]` looks up `YSQL_ROOT_PASSWORD` and the
  fail-loud guard fires on a secret that exists -- the guard
  worked as designed, on a bug inside itself. Off-by-one slices
  always present as "the controller env does not define it."
- **`--limit` cannot reach dynamically-added guest hosts** (the
  guests play add_hosts them at runtime; the pattern matches
  nothing and the run aborts with no hosts). Target one guest
  with a scratch playbook + a two-line inventory instead (then
  delete the scratch file; role resolution needs it under
  ansible/playbooks/).
- **There is no `:latest` tag on the syncstorage images** -- tags
  are `<commit>--<timestamp>`; pin the newest stamped tag's amd64
  digest from the registry API, never a floating name.

## Firefox sync pairing (the USER-5 close-out traps)

- **The bundled tokenserver ships with PLACEHOLDER FxA oauth
  credentials.** Every token exchange returns 401
  invalid-credentials, and Firefox surfaces it as a sign-in that
  never sticks -- the FxA web login succeeds, the settings pane
  still says "sign in." Fix: SYNC_TOKENSERVER__FXA_OAUTH_SERVER_URL
  / _CLIENT_ID / _CLIENT_SECRET set to the public oldsync pair
  Mozilla documents for self-hosters (client id 5882386c48d302ca;
  the secret rides the env: token channel even though public).
- **run_migrations defaults OFF** for the tokenserver database:
  the schema is embedded in the binary but never applied; the
  token exchange 500s with "Table 'tokenserver.services' doesn't
  exist." Fix: SYNC_TOKENSERVER__RUN_MIGRATIONS=true.
- **The migration does NOT seed the services row + node** (the
  image's own integration-test harness carries the TODO). Without
  them the exchange 500s after auth succeeds. Fixed as a
  converge-owned idempotent tokenserver_seed block in the mysql
  manifest (sync-1.5 + {node}/1.5/{uid} + our node URL).
- **The syncserver logs NOTHING at default level** -- empty
  docker logs never meant "no traffic"; twice in this build it
  misled the diagnosis. The authoritative client-side evidence
  is the profile's weave/logs/error-sync-* files: they name the
  exact failing stage, the HTTP status, and the server's error
  body. Read them before trusting server silence.
- **LibreWolf ships identity.fxaccounts.enabled=false**
  (librewolf.cfg:596, defaultPref) -- the sign-in UI requires
  flipping it (about:config or user.js). Verify against the LIVE
  cfg before assuming a pref is settable: lockPref entries are
  the only class user.js cannot override.

## cronmaster (the OPS-24 build traps)

- **fccview/cronmaster is an nsenter CONTROLLER**: docker mode
  manages its HOST's crontab via `nsenter -t 1`. From docker
  inside an UNPRIVILEGED LXC that is EPERM (cannot reassociate
  to ancestor namespaces); only a privileged LXC would allow it.
  It runs BARE in the CT instead (systemd + node), where its
  nsenter calls are same-namespace no-ops -- the old fleet's
  proven shape. The digest pin survives: `docker create` + `docker
  cp` stages the BUILT standalone app out of the pinned image.
- **INTERNAL_API_URL must point at loopback** for the app's proxy
  middleware (session check). Unset, it falls back to the request
  origin -- the tailnet name, unresolvable from inside the CT --
  and the UI sign-in silently never completes (the password is
  accepted; the session check fetch fails; nothing happens).
- **CTs were tailscale serve-only by workaround**: guest_common ran
  tailscaled with --tun=userspace-networking (documented as
  "outbound rides the LAN"), and no CT had the /dev/net/tun
  devnode. Manifest `tun: true` now gives a guest the real TUN
  (lxc devnode lines + tailscaled FLAGS conditional); with it,
  CT-to-peer tailnet works. ts.net names still need pinning
  (/etc/hosts, data-driven) -- the CT's resolvers never serve
  them.
- **The bw CLI hard-refuses plain http** (InsecureUrlNotAllowed) --
  the LAN path is out; it needs the https serve front + the TUN.
- **The vaultwarden account email is a passmail alias**
  (192.168.8.122.frosty957@passmail.com), not a nate.stott
  address -- bw login with the wrong email says "Username or
  password is incorrect", which reads like a password problem.
- **Exit-0 is not success**: with dead tokens the migrate job
  reported "Migration completed -- 0/0/0 SUCCESS" (empty list =
  nothing failed). Verify jobs against their EFFECTS (repo
  counts, vault rows), never the exit code.
- **.env pastes with surrounding quotes break token auth**: grep-
  parsing loaders see the literal quote chars; APIs then 401.
  Values unquoted, always.
- **The protonpass job's first run is CPU-bound**: bw per-item
  crypto pinned 2 cores at load 10; 4 cores halved it. Memory
  was never the constraint (321/1024 MB).
