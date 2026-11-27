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
| reboot-node.sh | live | the node reboot runbook, executable: gated, one-at-a-time, aborts on any failed check; operator-invoked only, never scheduled |
