# scripts/ -- what each is + when it runs

| script | status | what/when |
| --- | --- | --- |
| console-setup-operator.sh | runbook | paste at a future node's physical console: creates the nate account |
| bootstrap.sh | parked | fresh-install node enrollment (future new/rebuilt nodes) |
| deploy-node-glue.sh | parked | same era as bootstrap |
| setup-qdevice.sh | parked | the Pi re-role (Raspberry Pi OS + corosync-qnetd) |
| extract-legacy.sh | runbook | the legacy extraction (`--copy-from-dump <id>`); dumps remain on pve-backups so re-extracts stay possible |
| harden-ssh.sh | runbook | node good-ssh pass; re-run for future nodes |
| truenas.sh | live | read-only TrueNAS API helper (GET) |
| opnsense.sh | live | OPNsense API helper |
| mint-tailscale-key.sh | live | re-mint the guest-enrollment preauth key (make update warns at <14d) |
| secrets-restore.sh | live | materialize every local/*.env from the Proton Pass vault (OPS-26; run after `pass-cli login` on a new machine) |
| proton-wg-switch.sh | live | switches the router's Proton WG tunnel between the NetShield variants (ads / malware / nofilter) by updating the instance's private key via the API -- Proton binds the filtering level to each config's keypair, the peer never changes; `list` detects the live variant by pubkey match, `status` shows the handshake; records the choice in local/proton-wg.conf |
| reboot-node.sh | live | the node reboot runbook, executable: gated, one-at-a-time, aborts on any failed check; operator-invoked only, never scheduled |
| roll-pins.sh | live | rolls the pinned release versions (forgejo, gitea-mirror + bun, navidrome, vaultwarden) AND the container guests' image digests (guests/*.yaml `container:` blocks) to upstream latest by rewriting role defaults + manifests; runs inside `make update` and standalone; the roles' version gates apply the bump on the next converge. The NVIDIA driver pin is deliberately excluded (Pascal's terminal 580 branch) |
