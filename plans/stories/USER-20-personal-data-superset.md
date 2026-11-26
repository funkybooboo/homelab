# USER-20: Personal-data BI -- the Superset layer

As the operator, I want a holistic view of my own data -- code
activity, learning progress, spending, media habits, and machine
usage -- assembled in Apache Superset so I can explore it with real
queries instead of a dozen websites' dashboards.

**Status**: planned (design:
[../design/observability-dashboards.md](../design/observability-dashboards.md))
**Arc**: v3 late / v4 (the goal state docs/data.md was pointing at;
OPS-29 builds the collection habits first)

## The split rule (recorded, from the design doc)

Superset owns RECORDS you JOIN (spend, progress, activity);
Grafana owns MEASUREMENTS you alert on (fleet health). The same
fact can live in both if it needs both (media counts now + growth
joined against spend later).

## Source inventory (from the operator's list)

- [ ] Code hosting: github + codeberg (clean REST APIs; codeberg
      is our own push chain -- easiest first win)
- [ ] Learning: leetcode (community graphql), neetcode (API),
      exercism (API), codecrafters (API), pluralsight + udemy
      (expect export files, weak APIs -- drop-box directory)
- [ ] Spend: privacy.com + cloaked.com (both have APIs), amazon
      (order-history export CSV)
- [ ] AI/tools: ollama.com + opencode.com (usage APIs/logs)
- [ ] Media: youtube (takeout watch history), odysee (LBRY API)
- [ ] Local usage: ActivityWatch self-hosted on debbie (the
      idiomatic personal time-tracker; its DB is a superset source
      directly -- no puller needed)

## Architecture per docs/data.md

- Per-source SCHEMAS in a dedicated analytics database on the
  shared postgres (one database + role per source, same rules).
- Pulls are code: systemd timers or n8n flows (the n8n keep), each
  reviewed in its own right -- nothing scrapes in the dark; sources
  with hostile ToS get a manual export drop-box instead of a
  scraper we would have to defend.
- Superset reads the analytics schemas + the per-service DBs
  (forgejo, navidrome, vaultwarden -- read-only credentials).

## Acceptance criteria

- [ ] The clean-API sources (github, codeberg, privacy.com,
      cloaked, exercism, codecrafters, ollama, opencode) land on a
      schedule with zero manual steps
- [ ] Export-shaped sources (udemy, pluralsight, youtube, amazon)
      have a documented drop-box + import path
- [ ] One cross-source dashboard exists (e.g. "spend vs learning
      time by month") proving the join layer works
- [ ] All credentials in the pass vault (OPS-26 pattern); all pull
      jobs converge-managed
