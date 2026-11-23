# USER-12: protonmail-bridge

As the operator, I want the protonmail-bridge back with its
credentials intact -- so that mail flows to on-cluster consumers
without the re-login + 2FA + re-pairing dance.

**Status**: planned (operator-confirmed keep, 2026-11-23)
**Arc**: v3

## Acceptance criteria

- [ ] Bridge state extracted from the Nov-21 vzdump of old CT 126
      (`/var/lib/protonmail/bridge/`, path "to locate" per the old
      inventory) -- the gpg keyring + account state ARE the
      restore
- [ ] Manifest + role: bridge running headless in a CT (the old
      fleet's own shape)
- [ ] IMAP endpoint answers on the LAN; bichon (USER-11) pulls
      mail through it

## Notes

The entire value is avoiding the re-auth ritual -- if the
credentials turn out unreadable at extract time (gpg state
corrupt, or the account already de-paired server-side), the story
degrades to "fresh pairing, operator-run" and the honest move is
to say so rather than ship a hollow restore.
