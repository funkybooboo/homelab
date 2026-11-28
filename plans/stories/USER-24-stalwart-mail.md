# USER-24: Stalwart -- the own-mail experiment

As the operator, I want to run my own mail server, so that I learn
the full mail stack and hold a piece of my infrastructure that is
usually rented.

**Status**: planned (experiment scope)
**Arc**: v5 (after the v3 mail stories settle the household's
mail reality)

## Workflow

Experiment first: a domain, DNS records, TLS, IMAP/SMTP; the
operator's mail on a domain that can afford a mistake. NOT a
replacement for ProtonMail (the bridge + bichon keep the daily
mail) until the experiment earns it.

SECOND CONSUMER (decision #21, 2026-11-28): a self-hosted FxA
is the operator's wanted end-state for retiring the
browser-off-cloud map's row-5 residual, and FxA verification
codes make mail a tier-0 LOGIN dependency. That raises the bar:
the experiment must graduate to dependable delivery before FxA
leans on it -- stalwart earning daily-mail duty is the same gate.
See issues.md #21 for the full prerequisite chain.

## Acceptance criteria

- [ ] Manifest + role; a test domain sending + receiving real
      internet mail
- [ ] DNS (SPF/DKIM/DMARC) passing the public checkers
- [ ] A written verdict: keep as experiment, promote to daily
      mail, or retire

## Lenses

- Security: mail servers are the most attacked service on the
  internet -- isolated guest, tailnet-only admin front, no inbound
  exposure beyond required MX ports; human-gated to start.
- Reliability: an experiment domain can afford downtime; the
  household mail never rides on it.
- Scope guard: stalwart is a big service; if the experiment
  stalls, retire it without ceremony.
