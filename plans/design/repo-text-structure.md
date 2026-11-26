# Repo text + structure plan

Operator directive 2026-11-26, consolidated from a full-repo read
(docs, plans, scripts, ansible, root files). Story:
[OPS-30](../stories/OPS-30-repo-text-structure.md). This plan is the
record of what was found and what will change.

## Principles

1. One file, one topic. A file answers one question or does one job.
2. Each kind of truth has one home (table below). Everywhere else
   links to that home.
3. Files state what is true now. Revision timing lives in git;
   shipped narrative lives in history.md.
4. Text helps a human act: what is true, what to do, or where to
   look. Nothing else.
5. Plain wording. No drama words, no hedging adverbs, no
   reassurance phrases, no caps for emphasis.

## Placement doctrine

| Kind of content | Home |
| --- | --- |
| Current state, how-to, reference | docs/ (one doc = one question) |
| Decisions + rationale | plans/issues.md answers, plans/design/ records |
| Work items (what/why/acceptance) | plans/stories/ |
| Shipped narrative, as-built | plans/history.md |
| Traps and quirks of live systems | docs/quirks.md (new) |
| Why-this-line in code | short comment + link to docs/quirks.md |
| Standing rules | plans/identity.md |
| The queue, forward-looking only | plans/roadmap.md |

## Findings

### docs/

- README.md: the index lists data-to-extract.md twice and omits
  debugging.md and verify.md.
- backups.md: July-era text describes already-fixed problems as
  pending; three links point to notifications.md, which does not
  exist.
- maintenance.md repeats the backup facts that backups.md owns.
- data.md carries a superset plan that
  design/observability-dashboards.md now owns.
- data-to-extract.md mixes a correction note, tier tables for CTs
  that no longer exist, and the live dump-archive reference.
- debugging.md carries an incident archive and a practices section;
  both belong elsewhere.
- network.md: the "Now" section describes a pre-v2 state with
  removed guests drawn as current.

### History told in non-history files

- roadmap.md: four shipped-era sections with as-built narrative;
  18 dated revision markers (REVISED/ADDED). The roadmap should hold
  the plan going forward only.
- Root README.md: a dated shipped-state blockquote.
- 8 story files: 16 dated revision markers.
- Shipped stories carry as-built and deviation sections (USER-2 is
  60+ lines of post-ship narrative). plans/README.md already says
  the as-built record lands in history.md.
- Dated or narrative comments in docs (maintenance.md, data.md,
  access.md, verify.md), inventory files (hosts.yml, host_vars),
  and 28 code files.

### Wording

- "honest/honestly" as a hedge: 58 hits in 23 files.
- ALL-CAPS drama (TRAP, TRUTH): 81 hits across 48 files.
- Anthropomorphic words (died, graveyard, ghosts, minutes away):
  14 hits.
- Journey phrasing (found live, misdiagnosed, burned): 15 hits.
- Reassurance phrases (recorded, not lost; on purpose): 5 hits.
- Standing rules re-preached in about 6 places instead of linked.
- 35 lines over 110 characters in docs/ and plans/; the worst are
  in data-to-extract.md.

## Writing rules (to be added to plans/README.md conventions)

1. Plain statements. No drama, no hedging, no reassurance.
2. Caps only for identifiers.
3. Every sentence says what is true, what to do, or where to look.
4. A standing rule is stated once, in identity.md or issues.md;
   other files link to it.
5. Short lines, one idea per line.

## Execution passes

Each pass applies the writing rules to every file it touches.
No pass changes fleet behavior; passes 1-3 touch text only.
Pass 4 touches comments only.

### Pass 1: docs/

- New docs/README.md: complete index grouped by reader intent
  (run the fleet, get in, what is where); one line per doc naming
  the question it answers.
- New docs/quirks.md: one entry per trap and quirk, collected from
  debugging.md, code comments, and story notes. Entries are calm:
  the condition, the fix, the reference.
- backups.md: rewritten to current state. The notifications story
  moves into quirks.md as entries; the dead links go.
- maintenance.md: update tiers, the loop, the reboot runbook; one
  link to backups.md for backup facts.
- data-to-extract.md: rewritten as the dump-archive reference:
  what exists, where, how to pull, what is already consumed.
- debugging.md: look order plus toolbox; incidents move to
  history.md; practices section shrinks to links.
- network.md: the Now section redrawn to the current fleet; the
  Planned section limited to what is still future.
- data.md: the superset section becomes a link to the design record.
- access.md, verify.md: dated phrases removed; facts stay.

### Pass 2: plans/ + root

- roadmap.md: shipped-era sections move to history.md; the file
  keeps the timeline table, the active era, queued eras, someday,
  policy, and one link to history.md. All dated revision markers
  go; git owns timing.
- Shipped stories: as-built, deviation, and note sections move to
  history.md as per-story entries. The story file keeps story,
  acceptance, status, links. Revision markers go.
- Root README.md: the state block becomes one undated line linking
  the roadmap. The docs row drops the tier claim.
- plans/README.md: the writing rules block, per above.

### Pass 3: code comments

- The 28 files with dated or narrative comments: each comment keeps
  the operative rule in one to three lines plus a quirks.md link.
  No dates, no incident narrative, no drama words.
- extract-legacy.sh: the heaviest file; its comments describe
  behavior and constraints only.
- No code changes beyond comments. make verify proves it.

### Pass 4: verification

- make verify green (comment-only changes to live-managed files
  still converge).
- grep audit: zero hits for honest|honestly as a hedge, TRAP,
  TRUTH, found live, graveyard, ghosts, recorded-not-lost, and
  dates in comments outside plans/history.md and issues.md.
- Link audit: every docs/ link resolves; every doc appears exactly
  once in the index.
- Spot-check pass: the operator reads README.md, roadmap.md, and
  one rewritten doc and says whether the repo reads clean.

## Open decisions (operator)

1. "tombstone" as the word for a state:absent manifest: keep as
   fleet vocabulary, or rename to "absent manifest"?
2. "deliberate": keep only where it marks an intentional exception
   to a standing rule (about 9 of 19 uses), or remove everywhere?

## Sequencing

Passes run in order, one commit each. The work is era-independent
and can run between v3 stories; OPS-30 carries it.
