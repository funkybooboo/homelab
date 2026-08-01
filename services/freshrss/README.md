# freshrss -- OPML subscription list (homelab)

The FreshRSS instance itself runs in Proxmox CT `freshrss` (CT 104 on
pve-thermaltake, apache2 + postgresql, tailnet-only HTTPS at
`https://freshrss.tail54538d.ts.net`). See `docs/services.md` for the host
details. FreshRSS has **no native "subscribe from a file" mode** -- it only
does a one-shot import -- so this directory holds the canonical feed list
(OPML) that is imported into FreshRSS on change.

This is **not** tied to a specific user: it is a generic developer-focused
firehose list, language-agnostic, covering devops / security / SWE / AI / IT
/ databases and all major programming languages.

## Files in this directory

| file | what |
| --- | --- |
| `feeds.opml` | The canonical OPML (214 feeds, 13 categories). Import into FreshRSS via the web UI. |

## Workflow (Option A: file is source of truth, manual re-import)

1. Edit `feeds.opml` here (add / remove / re-categorize feeds).
2. Commit the change in this repo.
3. In the FreshRSS web UI: **Subscription management -> Import/Export ->
   OPML/XML file -> Import**.
4. FreshRSS dedupes by feed URL -- existing feeds are kept, new ones are
   added. Import is **additive**: feeds removed from the OPML are **not**
   pruned from FreshRSS automatically. Tick "replace" in the importer or
   delete them manually if you want a true mirror.

No cron, no API token, no reconciler. The file is the record of what
*should* be subscribed; FreshRSS is the running state, reconciled by hand on
import.

## Adding a GitHub release feed

Every GitHub repo publishes a native Atom feed at
`https://github.com/<owner>/<repo>/releases.atom` -- no RSS-Bridge needed.
Append a line under the `GitHub Releases` category:

```xml
<outline text="<repo> releases" type="rss"
  xmlUrl="https://github.com/<owner>/<repo>/releases.atom" />
```

Repos without GitHub Releases enabled return 404 on `releases.atom`; use
`tags.atom` or `commits/<branch>.atom` instead. The Forgejo mirror is on
Codeberg, not GitHub: `https://codeberg.org/forgejo/forgejo/releases.rss`.

Note: unauthenticated Atom requests are rate-limited to ~60/hour per IP. At
214 feeds (~40 of them GitHub Atom) polled hourly the steady-state sits under
the limit; if you grow the GitHub set well past 50, consider configuring a
read-only Personal Access Token as HTTP Basic auth on those feeds (raises the
limit to 5000/h).

## What's in the list (214 feeds, 13 categories)

| category | feeds | highlights |
| --- | --- | --- |
| Aggregators & Discussion | 12 | Hacker News (7 views), Lobsters, Dev.to, Changelog, Product Hunt, Techmeme |
| Tech News Firehose | 8 | Ars Technica, The Verge (tech/AI/all), IEEE Spectrum, LWN, Phoronix, ScienceDaily CS |
| Engineering Blogs | 18 | Cloudflare, GitHub, Lyft, Netflix, Vercel, Google Research, FasterThanLime, Julia Evans, Martin Fowler, Joel on Software, Adrian Colyer, Dan Luu, Computer Enhance, Andrew Kelley, Dave Cheney, Eli Bendersky, Rob Pike, Russ Cox |
| Weeklies | 8 | Hacker Newsletter, TLDR (Tech/AI/DevOps/InfoSec/WebDev), Postgres Weekly, Haskell Weekly |
| Languages & Ecosystems | 24 | Rust, This Week in Rust, Go, Node, Deno, Bun, Python (Insider + Real + Planet), Kotlin, Ruby, PHP, ISO C++, Inside Java, Elixir, Erlang, Clojure (+ Planet), Scala, Crystal, Julia, Dart, Swift, Zig |
| GitHub Trending (mshibanami mirror) | 6 | daily/weekly, all/Rust/Go/TS/Python -- pre-built, no external dependency |
| GitHub Trending (RSS-Bridge) | 12 | Go/Rust/Python/TS/Java/C++/Zig/Elixir/Shell/Nim/Lua/Kotlin daily via `rss-bridge.org/bridge01` `GithubTrendingBridge` |
| GitHub Releases | 40 | native `releases.atom` for the homelab stack (Tailscale, pve-manager, Docker, k8s, Terraform, OpenTofu, Ansible, Prometheus, Grafana, FreshRSS, Caddy, Traefik, Nginx, DuckDB, Dragonfly) + the major runtimes (Rust, Go, Node, Deno, Bun, Zig, CPython, Kotlin, Elixir) + misc (Ollama, ntfy, Jellyfin, Vaultwarden, yay, pgvector, Nixpkgs, etc.) |
| Databases | 11 | Postgres Weekly, Planet PostgreSQL, DuckDB, ClickHouse, MongoDB, Redis, Timescale, Supabase, Neon, Cockroach, Crunchy Data |
| DevOps & Infrastructure | 23 | CNCF, k8s, Docker, HashiCorp, Argo, GitLab, Grafana, Prometheus, OpenTelemetry, Cilium (+newsletter), Istio, NixOS, Arch, Debian, Ubuntu, NGINX, Tailscale, TrueNAS, Proxmox Forum, LSIO, selfh.st |
| Security | 17 | Krebs, Schneier, The Hacker News, BleepingComputer, SANS ISC, Troy Hunt, PortSwigger, DFIR Report, CISA Advisories, Securelist, Cisco Talos, OWASP, EFF, Graham Cluley, Malwarebytes, Snyk, Trail of Bits |
| AI & Machine Learning | 14 | OpenAI, HuggingFace, Google AI, DeepMind, Simon Willison, Latent Space, Interconnects, ML Mastery, arXiv (cs.AI/LG/CL/SE/DB/OS) |
| IT, Sysadmin & Reddit | 21 | r/programming, devops, selfhosted, sysadmin, homelab, Proxmox, linux, linuxadmin, networking, datacenter, rust, golang, ExperiencedDevs, SQL, Database, MachineLearning, LocalLLaMA, InfoQ, SD Times, High Scalability, Rachel By The Bay |

## Feeds that have no public RSS (not in this list)

These publish no native feed and are deliberately omitted. Bridging them
needs a self-hosted RSS-Bridge instance (not yet deployed):

- Stripe Engineering, Uber Engineering, Discord Engineering (Webflow)
- Anthropic news (SPA, no alternate feed link)
- bytebytego (Substack custom domain without the `/feed` path)
- martinfowler.com blog feed
- deeplearning.ai The Batch
- SQLite (sqlite.org has no feed; not on GitHub)

## Verifying / re-verifying feed URLs

When adding feeds, probe the URL before committing -- a 200 with an
`application/rss+xml` / `application/atom+xml` / `text/xml` content type is
what FreshRSS expects. All 214 URLs in this list were probed live
(`curl -sL -o /dev/null -w '%{http_code} %{content_type} %{size_download}B'`)
before the initial commit (2026-07-29).

## Caveats

- **Reddit** (`/r/x/.rss`, no trailing slash) enforces an extremely tight
  per-IP burst limit on unauthenticated `/.rss` requests -- roughly 1 request
  per ~30 s burst window (Reddit returns `HTTP 429` with `Retry-After:` ~1
  min after the first request, then escalates the cooldown on repeated hits).
  With 17 Reddit feeds in this list, the default FreshRSS schedule (`*/15 *`
  cron in `/etc/cron.d/freshrss-actualize`, feed ttl = system default = 1 h)
  bursts all 17 requests inside a single actualize cycle, so all but the first
  few 429 and stay errored indefinitely (the per-feed cooldown that FreshRSS
  honours via `/opt/freshrss/data/Retry-After/` only staggers retries by the
  burst window, not the next cron tick, so the wave rolls every 15 min).

  Fix applied to the live instance (FreshRSS CT 104, DB on postgres CT 108,
  schema `public`, tables prefixed `nate_`):

  1. Set every Reddit feed's ttl from `120` (a stale over-aggressive 2-min
     value) to `21600` (6 h). `ttl = 0` would also work (system default 1 h)
     but 6 h keeps the per-cycle Reddit request count at <= 1 with headroom.
  2. Stagger each Reddit feed's `lastUpdate` by `+900 s` (15 min, one cron
     tick) so exactly one feed becomes due per actualize cycle instead of
     all 17 at once. This is the critical step -- the burst limit is the
     blocker, not total volume.
  3. Reset `error = 0` and `rm /opt/freshrss/data/Retry-After/www.reddit.com_*.txt`
     so FreshRSS does not keep honouring the prior backoff.

  SQL (idempotent -- re-running restores staggered phase from any drift):

  ```sql
  WITH ranked AS (
      SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn
      FROM nate_feed WHERE url LIKE '%reddit.com%'
  )
  UPDATE nate_feed f
  SET ttl = 21600, error = 0,
      "lastUpdate" = (extract(epoch from now())::bigint) - 21600 + 900 * (rn - 1)
  FROM ranked r
  WHERE f.id = r.id;
  ```

  Symptom if it regresses: the FreshRSS web UI `Subscription management ->
  Information` column shows a red error flag on Reddit feeds, and the per-user
  log (`/opt/freshrss/data/users/nate/log.txt`) shows repeated `HTTP 429 Too
  Many Requests!` lines followed by `will first retry after ...`
  backoff entries. Do NOT also bump the actualize cron tighter, and do NOT
  issue `force refresh` on Reddit feeds (it bypasses ttl and re-triggers the
  429 cascade).
- **Lobsters** (`lobste.rs/rss`) publishes an AAAA-only record; hosts without
  IPv6 will fail to fetch. The FreshRSS CT (nameserver `192.168.8.1`,
  per the bulk DNS fix) gets the A record fine.
- **Danluu's atom** is ~11MB (he never trims). Included anyway; if it floods,
  drop it.
- **arXiv** (`cs.LG`, `cs.AI`, `cs.CL`) is a heavy firehose. Keep only the
  sections you actually read; `cs.SE` is the smallest.
- **Hackertab.dev** (the browser extension that inspired this list) pulls
  from its own `api.hackertab.dev` backend; its source list is server-side
  and not subscribable directly. The GitHub-trending mirrors above cover the
  same ground.