# scripts/ -- what each is + when it runs

| script | status | what/when |
| --- | --- | --- |
| console-setup-operator.sh | runbook | paste at a FUTURE node's physical console: creates the nate account (v1 did all 5) |
| bootstrap.sh | parked | fresh-install node enrollment (future new/rebuilt nodes) |
| deploy-node-glue.sh | parked | same era as bootstrap |
| setup-qdevice.sh | parked | the Pi re-role (Raspberry Pi OS + corosync-qnetd) |
| revive-node.sh | historical | the v1 in-place revival (all 5 done; kept as the story record) |
| extract-legacy.sh | runbook | the legacy extraction (`--copy-from-dump <id>`); dumps remain on pve-backups so re-extracts stay possible |
| harden-ssh.sh | runbook | node good-ssh pass; re-run for future nodes |
| setup-pve-access.sh | historical | created nate@pam + the homelab-ops token; kept as the reproducibility record |
| truenas.sh | live | read-only TrueNAS API helper (GET) |
| opnsense.sh | live | OPNsense API helper |
| mint-tailscale-key.sh | live | re-mint the guest-enrollment preauth key (make update warns at <14d) |
| stage-pgdata.sh | one-shot, done | staged the root-owned PGDATA for the postgres restore; kept for restore reproducibility |
| truenas-network-move.sh | historical | the .10 move (done 2026-11-21) |
| secrets-restore.sh | live | materialize every local/*.env from the Proton Pass vault (OPS-26; run after `pass-cli login` on a new machine) |
| reboot-node.sh | live | the node reboot runbook, executable: gated, one-at-a-time, aborts on any failed check; operator-invoked only (proven live 2026-11-25, the Pi) |
