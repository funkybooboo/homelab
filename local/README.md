# local/ -- gitignored credentials + audit evidence

Nothing here is tracked by git except `*.example` templates and this
README. Real env files are mode 600. The `.gitignore` rule is
`local/*` with `!local/*.example`.

## The env files

Each `*.env` is sourced by `make converge/update/verify` (the
Makefile exports every one it finds). An `.env.example` sibling
documents the variable names + where the credential is minted.

| file | variables | minted where |
| --- | --- | --- |
| pve-api.env | PVE_API_TOKEN_SECRET | the PVE API (token `nate@pam!homelab-ops`) |
| tailscale-api.env | TAILSCALE_API_TOKEN | the Tailscale admin console (API key) |
| tailscale-authkey.env | TS_AUTH_KEY, TS_AUTH_KEY_ID | scripts/mint-tailscale-key.sh (guest-enrollment preauth key) |
| truenas-api.env | TRUENAS_API_KEY | TrueNAS UI (API key) |
| opnsense-api.env | OPNSENSE_KEY, OPNSENSE_SECRET | OPNsense UI (API user) |
| pg-operator.env | PG_OPERATOR_PASSWORD | the postgres role password (docs/access.md) |
| mysql-secrets.env | MYSQL_ROOT_PASSWORD, SYNC_DB_PASSWORD | the mysql CT 107 shared layer (USER-5 build; openssl rand -hex) |
| sync-secrets.env | SYNC_MASTER_SECRET, SYNC_TOKENSERVER__FXA_METRICS_HASH_SECRET, SYNC_STORAGE__DATABASE_URL, SYNC_TOKENSERVER__DATABASE_URL | the firefox sync CT 216 (USER-5 build; URLs embed the mysql sync-user password) |
| forgejo-db.env | FORGEJO_DB_PASSWORD | set at the forgejo restore (USER/OPS-9) |
| forgejo-token.env | FORGEJO_API_TOKEN | hub user `funkybooboo` token |
| forgejo-admin-token.env | FORGEJO_ADMIN_TOKEN | hub admin `nate` token |
| forgejo-metrics.env | FORGEJO_METRICS_TOKEN | in-app /metrics bearer (app.ini [metrics]) |
| gitea-mirror-api.env | GITEA_MIRROR_API_KEY | CT 203 UI (x-api-key header) |
| codeberg-api.env | CODEBERG_API_TOKEN | codeberg.org user token (repo rw) |

## Restore path (OPS-26, shipped 2026-11-25)

The durable home for these secrets is the operator's Proton Pass
vault (pass-cli; vault `homelab`, one item per env file, hidden
field per variable). Every `.env.example` in this directory is an
inject template carrying `{{ pass://... }}` references.

On a new machine: dotfiles `setup.sh` step 1 is `pass-cli login`,
then run `scripts/secrets-restore.sh` -- it materializes every
`local/*.env` (mode 600). Rotation updates the live env file AND
the vault item; templates are references, not values.

## WireGuard (OPS-28)

- `proton-wg.conf` -- the ACTIVE Proton tunnel config for the
  router's `proton-services` WG instance (block-malware-ads-and-
  trackers / NetShield 2). The two sibling confs are the same
  server + keypair at other filtering levels: `proton-wg-
  malware-only.conf` (NetShield 1) and `proton-wg-no-filter.conf`
  (NetShield 0). Swap = copy a variant over `proton-wg.conf`;
  the router only cares if the key or endpoint changed.
- These are hand-maintained (not pass-cli templates): the private
  key exists in the vault as item `proton-wg-opnsense`, and the
  `proton-wg.conf.example` sibling documents the shape + the
  Proton re-download redaction trap.

## Subdirectories

- `ops-9-audit/` -- evidence from the forgejo/codeberg sync-layer
  repair (manifests of DB-only rows deleted after per-repo
  verification, the push-chain map). Kept for the story record.
- `staging/` -- the one-shot PGDATA stage for the postgres restore.
  NOTE: this directory is root-owned (staged as root); harmless,
  but a chown one-liner would tidy it.
