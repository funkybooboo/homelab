# OPS-22: Node hardening + LAN tails

As the operator, I want the good-ssh state enforced on every node
and the revival evening's temporary addresses and rules cleaned up,
so that the platform's access surface is exactly the designed model
and nothing stale from the renumbering survives into v2.

**Status**: done (shipped 2026-11-22 -- every criterion closed;
      root@pam TOTP added by the operator same day)
**Arc**: v1.5 (clean-out + access layer; issues item 9c, the
identity convention's standing rule)

## Acceptance criteria

- [x] `scripts/harden-ssh.sh` applied on all 5 PVE nodes: password
      auth off; root ssh stays KEY-ONLY (PVE's inter-node root ssh
      is load-bearing for migration/cluster operations); the
      physical console is the break-glass path -- DONE 2026-11-22:
      all five report permitrootlogin without-password,
      passwordauthentication no, kbdinteractiveauthentication no,
      loglevel VERBOSE
- [x] PVE web-UI second factor: TOTP enabled on nate@pam (QR
      scanned into vaultwarden) -- operator action in the UI
      (issues item 13, decided 2026-11-22) -- DONE + verified via
      the API TFA registry
- [x] truenas SSH service good-ssh pass in the web UI (root login +
      password auth off) -- RESOLVED 2026-11-22: NO ACTION NEEDED; the
      "pending hardening" note was stale old-fleet info. Verified via
      API (GET /api/v2.0/ssh: passwordauth false, no rootlogin toggle
      in the 25.x service model) + the effective sshd_config
      (PasswordAuthentication no, PermitRootLogin without-password)
      -- identical posture to the PVE nodes; the console remains
      root's only door
- [x] debbie: the stale 192.168.8.99 alias removed from
      enp0s13f0u2u4 + the stale port-8000 allows deleted -- DONE
      2026-11-22: the alias died with the reboot (live-only); the
      real archaeology was FOUR 8000 rules (revival-fetch scoped to
      192.168.1.0/24 + three old-era .8.117/.8.102/.8.103), all
      deleted; the numbered sweep shows only deliberate rules
      (libvirt auto-NAT + LocalSend 53317 from dotfiles 000582)
- [x] thermaltake: the stale 192.168.8.98 alias removed from vmbr0
      (2026-11-22; it was live-only, added ad-hoc during the
      revival, so it does not return)
- [x] framework: USB autosuspend hardening applied + a journal watch
      for the NIC (the no-fix revival's insurance) -- DONE 2026-11-22:
      the RTL8156 (0bda:8156) already ran power/control=on (r8152
      driver holds the device awake); pinned persistently via
      /etc/udev/rules.d/71-usb-nic-keepawake.rules + verified.
      Journal watch (run if the NIC ever drops):
      journalctl -k | grep -iE 'r8152|usb 2-4|nic0'
- [x] Verify: `sshd -T` on each node shows the expected state; the
      192.168.8.x addresses answer nowhere on the LAN -- verified:
      all 5 nodes report permitrootlogin without-password,
      passwordauthentication no, kbdinteractiveauthentication no,
      loglevel VERBOSE; .8.1/.8.117/.8.98 ping dead (correct)

## Notes

The revival left two temporary aliases by design: thermaltake's
.8.98 bridged the no-console root path (thermaltake -> aspires/
aspiree15 before they had sudo), debbie's .8.99 served the one-shot
HTTP fetch at truenas's console. Both outlived their purpose the
moment the LAN renumbered. Root key-only ssh is the deliberate
exception to "no root anywhere" -- PVE itself sshes between nodes
for migration; the identity convention records that nuance
explicitly (issues item 9c).
