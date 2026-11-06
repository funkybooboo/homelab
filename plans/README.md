# Plans

How work is planned, prioritized, and tracked. Organized like
`erledigen/plans/` (README + identity + roadmap + stories + history +
issues), adapted where a homelab differs from a product repo.

## The rule

Nothing runs that is not (re)expressible from this repo, and nothing is
built that does not serve one of three roles -- the household that uses
the services, the operator who runs the fleet, and the craft (the
operator's professional development). If a "for whom" question has no
story, write one before building; if a "why" question has no design
record, write one first.

## The pieces

| Path | What it is |
|------|------------|
| [identity.md](./identity.md) | The constitution: the homelab's identity + the rules every change obeys |
| [roadmap.md](./roadmap.md) | The queue: where we stand + the arcs, each arc carrying its stories |
| [stories/](./stories/) | One file per story, named by role + number |
| [design/](./design/) | Design records (the former `ideas/`): the "why" + "how" depth behind stories |
| [history.md](./history.md) | The shipped record: what ran, as built, and when it ended |
| [issues.md](./issues.md) | Open questions + self-audit notes -- story input, kept verbatim |

## Story IDs

The prefix names the role the story serves:

- **USER-nn** -- the household: the people who use the services
  (vaultwarden, media, rss, sync)
- **OPS-nn** -- the operator: cluster, network, storage, backups,
  alerting, the IaC layer itself
- **LEARN-nn** -- the craft: professional-development experiments that
  earn their place by what they teach, never by crowding out the other
  two roles

A story carries the story ("As a ..., I want ..., so that ..."), its
acceptance criteria, a status (planned / doing / done), its arc, and
links to the design records behind it.

## The workflow

1. Work is proposed as a story file (or a change to one).
2. The roadmap queues it into an arc; arcs land in numeric order, and
   every arc ends with something running.
3. Commits reference the story they serve.
4. When an arc's stories ship, they flip to done and the as-built
   record lands in [history.md](./history.md) (+ `docs/`, where the
   result becomes documentation).

## Conventions

- An arc is a milestone that ends with something running -- "v1" means
  "the first fleet that runs," not a package release.
- Design records in `design/` are historical once written: decisions
  change by superseding (a new record + a status header), never by
  editing old content in place.
- Differences from erledigen's `plans/`: `design/` here plays the role
  erledigen gives docs/build ADRs (this repo has no ADR system), and
  arcs play the role of versions.
