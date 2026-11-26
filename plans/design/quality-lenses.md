# Quality lenses: security, visibility, reliability

Operator directive: every era and every story considers these
lenses FIRST, not after. This record defines the lenses, audits
where the fleet stands against each, and lists the known gaps with
their homes. It feeds the era-opening protocol: Phase 0 of every
era walks this list against the era's stories.

Companion records:
[scheduled jobs (cronmaster)](./cronmaster-scheduled-jobs.md) --
the operator's scheduling decision,
[observability design](./observability-dashboards.md) -- the
visibility plan.

## The lenses

1. **Security** -- every story asks: what can reach this, what
   secret does it hold, where does the secret live, what happens
   when it leaks?
2. **Visibility** -- every story asks: how do I know it works,
   how do I know it broke, and where do I look when it does?
3. **Reliability** -- every story asks: what does it depend on,
   what breaks it, and how does it come back?
4. **Scalability** -- every story asks: what does it cost as the
   fleet grows (guests, hosts, data), and what is the ceiling?

A story that cannot answer its lens questions does not start; the
answers land in its acceptance criteria.

## Where the fleet stands (2026-11-26 audit)

### Security -- covered

- Access: tailnet-only services (identity rule 3), one subnet
  router, no inbound router ports; ssh hardened everywhere
  (password auth dead, root key-only); TOTP on both PVE UI
  identities.
- Secrets: none in git; local/ env files (mode 600) + the Proton
  Pass vault as the durable home (OPS-26); restore path proven.
- Storage: B2 backup contents + filenames encrypted (password +
  salt in the truenas middleware db -- the only unrecoverable-if-
  lost artifact, recorded).
- Appliances: API access under the nate identity; tokens scoped
  per system; one revocable PVE token.

### Security -- known gaps

| Gap | Home |
| --- | --- |
| Secret rotation policy: no schedule or drill for rotating API tokens, pg password, tailscale auth key expiry | issues (to file) |
| Audit review: sshd VERBOSE logs + sudo use are collected but nobody reads them; the security dashboard (OPS-29c) is the answer | OPS-29c |
| Backup encryption password + salt: single location (truenas middleware); a copy belongs in the Proton Pass vault | issues (to file) |
| truenas root ssh: enabled for appliance ops; consider API-only over time | issues (to file) |
| CVE/patch visibility: make update is weekly; no view of what is pending between passes | OPS-29a textfile collector |

### Visibility -- covered and gaps

The observability design
([observability-dashboards.md](./observability-dashboards.md))
owns this lens: metrics + logs ship from every host from birth;
dashboards are the gap; alerting tier is the v4 gap; superset data
extraction is USER-20. Nothing further to add here: that record is
the plan.

### Reliability -- covered

- Boot-order law (identity rule 7); reboot runbook executable and
  proven; nofail media mounts (a dead truenas degrades, never
  hangs a node); jellyfin's media-wait guard.
- Every converge idempotent and verified; drift is checkable
  read-only on demand.
- Standing rule: cluster-level actions stay human-gated (the
  armed-reboot-controller lesson).

### Reliability -- known gaps

| Gap | Home |
| --- | --- |
| Single pool holds live disks + backups (DR hole) | backups.md; OPS-14 |
| Restore path untested end-to-end; a backup counts only after a quarterly drill | OPS-14 acceptance |
| truenas is a SPOF for every pve-shared guest | documented (identity rule 5); PBS + the v4 tier narrow it |
| UPS: no power-loss choreography yet | OPS-25 |
| ssh-agent identity drops on session restarts | quirks.md; runbook = ssh-add first |

### Scalability -- covered

- One YAML + one role per service; adding a guest is a manifest;
  prometheus targets + watcher coverage auto-derive from manifests.
- Shared postgres with database-per-service keeps per-service blast
  radius bounded (data.md).

### Scalability -- known gaps

| Gap | Home |
| --- | --- |
| IP space: guests .50-.99 (49 slots); ~30 planned; enough, but the plan should note when the range fills | network.md |
| Node placement is manual; HA + the native balancer are v5 | OPS-6/v5 |
| loki/prometheus retention (14d/15d) fits the fleet; revisit at ~30 guests | OPS-29b |
| debbie is the single ops workstation (single point of operations, not services) | identity rule 5 covers the principle; no story yet |

## How the lenses enter the process

1. The era-opening protocol's Phase 0 walks each lens against the
   era's stories; findings land in the stories' acceptance
   criteria or in issues.md.
2. Every story file gains a fourth standing section after
   acceptance criteria: **Lenses** -- one line per lens that is
   non-trivial for that story (empty lines are fine for small
   stories; "none" is an answer).
3. The gap tables above are the backlog of lens fixes; each row
   names its home so nothing is remembered, only linked.
