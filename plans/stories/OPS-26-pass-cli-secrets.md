# OPS-26: secrets home in Proton Pass (pass-cli)

As the operator, I want every fleet credential stored in my Proton
Pass vault so cloning this repo on a new machine is enough to
restore operations -- no credential lives only on one laptop's
disk.

**Status**: planned (recorded 2026-11-25; the audit's restore-path
gap)
**Arc**: v3 opening move (restores the repo's portability before
new services pile on)

## The gap

`local/*.env` is the working credential set (documented in
[`local/README.md`](../../local/README.md)), but it is a single
point of failure: debbie-only, laptop-disk-only. The dotfiles
setup already begins with `pass-cli login` (Proton Pass CLI,
`~/dotfiles/setup.sh` step 1) -- the vault is the operator's
established secrets home; the fleet should use it.

## Design

1. One Proton Pass item per credential (suggested vault name
   "Homelab", item per row of the local/README table -- pve token,
   tailscale api + authkey, truenas, opnsense, pg operator, forgejo
   db/user/admin/metrics, gitea-mirror x2, codeberg).
2. The REPO tracks one template per env file (`local/*.env.example`
   already exist for all 13) carrying pass-cli secret references
   instead of placeholder values.
3. `scripts/secrets-restore.sh` (the acceptance deliverable):
   checks `pass-cli info` (prompts for login if needed), then runs
   `pass-cli inject -i <template> -o local/<file>` for each pair,
   setting mode 600. Run on any machine after dotfiles setup.sh --
   that is the full new-machine restore story.
4. Re-mint flow unchanged: when a credential rotates (e.g. the
   tailscale preauth key via scripts/mint-tailscale-key.sh), the
   vault item is updated too -- the script prints the reminder.

## Honest constraints

- pass-cli session is per-machine and browser-authenticated: the
  initial vault population is operator-assisted (I can drive
  `pass-cli item create` once you are logged in; you watch).
- `pass-cli inject` reference syntax must be confirmed against a
  live session before the templates are finalized -- do not guess
  syntax into 13 files (the story's first work item).
- Proton Pass availability = fleet now depends on it for RESTORE
  (not for daily operation -- live systems keep working without
  it). Acceptable: restore-time dependency on an external service
  beats restore-time dependency on one laptop disk.

## Acceptance criteria

- [ ] All 13 credentials exist as Proton Pass items
- [ ] Templates carry working pass-cli references (syntax verified
      against a live session)
- [ ] On a clean machine: repo clone + `pass-cli login` +
      `scripts/secrets-restore.sh` -> `make converge` connects
      (proven at least by dry-run of the env sourcing)
- [ ] local/README.md's restore path updated from "re-mint each"
      to "run the script"
