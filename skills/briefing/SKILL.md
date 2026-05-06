---
name: briefing
description: |
  Adaptive project orientation. Auto-discovers project state from git, GitHub,
  CLAUDE.md's ## Project context section (when present), and any working-memory
  layout it can sniff. Reshapes output based on what's in flight — leads with
  active work if there is any, leads with what's next if not. Use whenever you
  start a session and need to catch up: "where am I, what was I doing, what's
  next?", "what changed while I was away?", "where did I stop?", or just
  /briefing.
argument-hint: "[depth] [save] [help]"
---

# `/briefing` — Adaptive project orientation

This skill produces a structured briefing of project state on demand. It auto-discovers what's in flight from git, GitHub, the project's CLAUDE.md `## Project context` section (when present), and whatever working-memory layout it can detect. The output reshapes based on what it finds — leads with active work if there is any, leads with what's next if everything is calm.

The audience is you, returning to a project after a session, a day, a week, or a vacation. You want to know where you are, what you were doing, and what to pick up — without re-reading every file. The skill is read-only on the project (it never modifies project files); the only exception is the briefing log it writes when you invoke it with `save`.

The skill is **convention-aware but not convention-coupled**. It works generically in any repo, but lights up with richer behaviour when the project follows the canonical conventions referenced below. When partial adoption is detected, the briefing's footer suggests what's missing — read-only suggestions, never edits.

## Canonical conventions reference

A single absolute URL, defined once and reused throughout the skill. If this is renamed or moved upstream, this is the single line to update.

```
<CANONICAL_CONVENTIONS_URL> = https://github.com/carlosboeing/claude-code-resources/blob/main/guides/guide-project-structure-and-conventions.md
```

When the skill needs to point users at the conventions guide (e.g. in the convention-maturity footer block, or when explaining what `## Project context` is), it renders this URL — optionally with a section anchor like `#58--project-context-section-in-claudemd` for §5.8 or `#65-ai-agent-update-triggers-working-memory-discipline` for §6.5.

## Synopsis

```
/briefing [mode] [save] [help]

  mode    adaptive (default) | quick | standard | deep | sources
          Depth tiers (quick/standard/deep) control how much briefing reads.
          `sources` is a separate mode that documents what this skill probes
          and what it found in the project. Can't be combined with depth
          tiers — use one or the other.
          Synonyms — quick: peek; deep: deep-dive
  save    write the output to disk                          default: off
          (synonyms: --save, export)
  help    show this synopsis instead of running             default: off
          (synonyms: ?, usage, --help, -h)
```

Order of args does not matter. `/briefing deep save` and `/briefing save deep` are equivalent. If any help keyword (the full set is listed under **How to parse the args** below — `help`, `--help`, `-h`, `?`, `usage`) appears anywhere in the args, the skill renders this Synopsis as the response and stops — no briefing, no save.

The depth default is **adaptive**: when no depth keyword is provided, the briefing's length is content-driven — sections appear or disappear based on what the project state actually contains. `quick`, `standard`, and `deep` are explicit overrides for fixed-length tiers; "no dial" is its own behaviour, not a synonym for `standard`.

## How to parse the args

Walk the tokens once and bucket each one:

- **Mode keywords** (closed set): `sources`. Default mode is briefing.
- **Depth keywords** (closed set): `quick`, `peek`, `standard`, `deep`, `deep-dive`. Default: adaptive (no override) if no depth keyword is present.
- **Save keywords** (closed set): `save`, `--save`, `export`. Default off.
- **Help keywords** (closed set): `help`, `--help`, `-h`, `?`, `usage`. If any appear, **short-circuit**: render the Synopsis above and stop.
- **Anything else**: respond with `unknown arg <X> — try /briefing help` and stop.

The parser is order-independent and case-insensitive. Two of the same bucket is an error of intent — pick the **rightmost** occurrence and surface the override via the depth-conflict bullet in the `★ About this briefing` block (see **About this briefing** section below). The bullet text follows the pattern `Depth received both '<X>' and '<Y>'; using '<Y>'`.

**Mutex rule — sources mode vs depth tiers:** when `sources` is present AND a depth keyword is present, render the sources view; the depth keyword is ignored. Surface the conflict via the depth-conflict bullet inside the sources view, with text `Depth ignored when 'sources' mode is active`.

## Source layering

> **Note on labels:** `L1`, `L2a`, `L2b`, and `L3` are internal architecture codes used inside this Source-layering section (and the Layer 3 failure-mode table + In-flight detection table) to discuss the model precisely. They are **not user-facing** — neither default-mode briefings nor `/briefing sources` ever emit them. Rendering instructions elsewhere in this spec use plain language (e.g. "the resolved roadmap path", "sources declared in `## Project context`"). The user-facing labels in `/briefing sources` are **Always-on** (≈ L1), **Declared** (≈ L2a), **Default paths** (≈ L2b), and **Fallbacks** (≈ L3).

The briefing reads from four layers, each with a clear failure mode:

| Layer | What it does | Fails when… |
|---|---|---|
| **L1 — Universal mechanics** | Probes git, GitHub, top-level files, per-project memory. Knows nothing about specific conventions. | The project isn't a git repo (skip git/gh; fall back to file discovery only). |
| **L2a — Explicit declarations** | Reads `## Project context` from CLAUDE.md. Declared fields are authoritative. | The section is absent (skip L2a entirely; rely on L2b). |
| **L2b — Convention sniffing** | Probes for canonical-conventions signatures (`docs/0-brainstorms/`, `docs/ROADMAP.md`, status frontmatter, ROADMAP section names). Fills in any field L2a didn't declare. | The project doesn't follow the canonical conventions (skip the lit-up behaviour; degrade to L1-only output). |
| **L3 — Graceful degradation** | Standing instructions for every failure mode. Names every gap in the footer; never fabricates. | (L3 is itself the failure-handling layer; it doesn't fail.) |

Run L1 unconditionally. Read L2a if `## Project context` is present in CLAUDE.md. Run L2b for any field L2a didn't declare. Apply L3's standing instructions to any source that fails along the way.

### Layer 1 — Universal mechanics

These sources run unconditionally, with no project configuration required and no convention assumed. Probe each one in order; if a step fails, apply the matching Layer 3 instruction and continue.

**Git state (branch, ahead/behind, dirty status, recent history):**

```bash
git rev-parse --abbrev-ref HEAD                         # current branch
git rev-list --count @{upstream}..HEAD 2>/dev/null      # commits ahead of upstream (if any)
git rev-list --count HEAD..@{upstream} 2>/dev/null      # commits behind upstream (if any)
git status --short                                      # dirty status one-liner
git log --oneline -10                                   # last 10 commits
```

**Git refs refresh:**

> **Never `git pull`.** Only `git fetch`. The fetch is read-only — it
> updates refs without modifying the working tree, so the briefing can
> compute accurate ahead/behind without risking a merge mid-task.
> Before running the command below, read the `Auto-fetch` value from
> Layer 2a's `## Project context`; if it is `no`, omit the fetch entirely.
> If the fetch fails with an authentication error (distinct from "no
> remote"), continue with stale refs and surface the auth failure in the
> footer — see Layer 3.

```bash
git fetch --quiet 2>/dev/null || true   # safe no-op if no remote
```

**Uncommitted edits:**

```bash
git status --porcelain               # dirty file list
git diff --stat                      # lines changed per file (unstaged)
git diff --staged --stat             # lines changed per file (staged)
git diff                             # actual hunks; cap at 200 lines per file
git diff --staged
```

If a per-file diff exceeds 200 lines, do not dump it — summarise: "uncommitted edits in `path:line-range` (~N lines, looks like <one-line summary>)". Trust `.gitignore`. Skip files matching: `.env*`, `*.pem`, `*.key`, `id_rsa*`, `credentials*`.

**Local-only state (unpushed, no-upstream, stashes, worktrees):**

```bash
git log @{upstream}..HEAD --oneline                                     # unpushed on current branch
git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads/   # ahead counts for all local branches
git branch -vv | grep -v '\['                                           # branches with no upstream
git stash list                                                          # stashes
git worktree list                                                       # worktrees
```

**GitHub (only if `gh` is installed and authenticated):**

```bash
gh pr list --state open --author @me        # your open PRs
gh pr list --state open                     # all open PRs in the repo
gh issue list --state open --assignee @me   # issues assigned to you
gh run list --branch "$(git rev-parse --abbrev-ref HEAD)" --limit 5   # CI status of current branch
```

If `gh` is missing or unauthenticated, skip these and note the gap in the footer (Layer 3).

**Top-level docs (well-known by name, not a convention):**

```bash
ls -l README.md CLAUDE.md 2>/dev/null   # mtimes for staleness check
```

These files are typically already loaded in the conversation context; the recheck is for noticing recent edits, not for re-reading content unless mtimes suggest staleness. They are universal open-source-convention files, not project-specific — that's why they live in L1.

**Per-project memory:**

Claude Code stores per-project state under a slug derived from the project's full path: leading `/` becomes `-`, and every other `/` also becomes `-`. So `/Users/me/Projects/foo` lives at `~/.claude/projects/-Users-me-Projects-foo/`.

```bash
slug="$(pwd | sed 's|/|-|g')"               # /a/b/c → -a-b-c
ls -l "$HOME/.claude/projects/$slug/memory/MEMORY.md" 2>/dev/null
```

If the index file exists (some users maintain one via an auto-memory system), read it for cross-session continuity notes. If not, skip silently — many projects do not maintain one. This is a Claude Code mechanic, not a project convention, so it lives in L1.

### Layer 2a — Explicit declarations via CLAUDE.md

Read the `## Project context` section from CLAUDE.md (already in your context). Each line is `- **Field**: value`. Recognised fields:

- **Tracker** — where work items live (e.g. `GitHub Issues`, `Linear team FOO`, `Jira project BAR`, `Notion`, `GitHub Project N`, file path, or `none`).
- **Board** — URL of the active board / project view.
- **Roadmap** — file path or external URL of the forward view.
- **Changelog** — file path or external URL of recent shipped work.
- **Architecture** — file path or directory of architecture docs.
- **Working memory** — directory holding the lifecycle artifacts (e.g. `docs/`).
- **Auto-fetch** — `yes` (default) or `no`; controls whether the briefing may run `git fetch` to refresh refs.
- **Other** — free-form bullet list for project-specific context.

Declared fields are **authoritative** — they override any L2b sniffing. A field set to `none` means "deliberately empty" (do not probe further); an absent field means "L2b can probe a default" (see L2b table below).

Presence check: grep for `^## Project context` in the project's CLAUDE.md. If absent, skip the L2a read entirely and proceed to L2b.

#### Tracker integration recipes

For each declared tracker, use the matching query path. Name the gap explicitly when a CLI or MCP integration is missing — do not silently skip.

| Declared as | Query path |
|---|---|
| `GitHub Issues` (or absent + GitHub repo) | `gh issue list --state open --assignee @me`, `gh issue list --state open` |
| `GitHub Project N` | `gh project item-list N --owner <owner>` |
| `Linear …` | Try `linear` CLI; if missing → "Linear declared but no CLI / MCP available — install `linear-cli` or configure Linear MCP" |
| `Jira …` | Try `acli` or `jira` CLI; same fallback message shape |
| `Notion <ID or URL>` | Use `mcp__claude_ai_Notion__notion-fetch` if Notion MCP is configured; same fallback otherwise |
| `<file path>` | Direct read |
| `<URL>` | `WebFetch` (best-effort; flag if auth-walled) |
| `none` | Skip; note in footer |

### Layer 2b — Convention sniffing

For each "what's the project's structure?" question that L2a did not declare, probe for canonical-conventions signatures. The canonical conventions are documented at `<CANONICAL_CONVENTIONS_URL>`; this skill is *aware* of them but not *coupled* to them — when none of the signatures match, the skill degrades gracefully to L1-only output.

| Question | If L2a declared it | Else, L2b probe order | Fallback (no match) |
|---|---|---|---|
| Where's the roadmap? | Use `Roadmap` field | `docs/ROADMAP.md` (canonical) → `ROADMAP.md` (root) | Note in footer; skip roadmap section |
| Where's the changelog? | Use `Changelog` field | `docs/CHANGELOG.md` (canonical) → `CHANGELOG.md` (root) | Note in footer; skip changelog references |
| Where are lifecycle artifacts? | Use `Working memory` field | If `docs/0-brainstorms/`, `docs/2-design/`, `docs/3-plans/` all exist → canonical layout (lifecycle dirs are `docs/[0-9]-*` plus `docs/adrs/`). Else if any `docs/*/*.md` has `status:` frontmatter → use those dirs as discovered working memory. | Note in footer; skip lifecycle drafts in output |
| What `status:` values mean "in flight"? | (not declared) | If canonical layout detected: `draft`, `open`, `approved`. | Any `status:` not in `{shipped, superseded, abandoned, closed, done}` |
| Which ROADMAP section means "in flight"? | (not declared) | If canonical detected: `## In flight` (per §6.3 of the canonical guide). | Case-insensitive match for headings containing `in flight`, `in progress`, `now`, `doing`, `wip` |
| Where are ADRs? | (not declared) | `docs/adrs/NNNN-*.md` (canonical) → `docs/6-adrs/`, `docs/architecture/decisions/`, `decisions/`, `adr/` | Not surfaced |

When probing the lifecycle for-loop, prefer the canonical glob if detected; otherwise list what was actually found:

```bash
# Canonical-conventions glob (used when L2b detects the canonical layout)
for d in docs/[0-9]-* docs/adrs; do
  [ -d "$d" ] || continue
  find "$d" -maxdepth 1 -name '*.md' -print0 2>/dev/null \
    | xargs -0 grep -l '^status:' 2>/dev/null
  ls -t "$d" 2>/dev/null | head -5
done
```

The glob `docs/[0-9]-*` covers the canonical numbered prefixes (`0-brainstorms`, `1-discovery`, `2-design`, `3-plans`, `4-reviews`) and any project-specific extensions (e.g. `5-guides`, `6-adrs` in some sister repos). `docs/adrs` is also probed because the canonical convention places ADRs there without a number prefix.

**zsh portability note:** if you write a follow-up command that extracts the `status:` value into a shell variable, **do not name the variable `status`** — it's read-only in zsh (it holds the last command's exit code). Use `st`, `state`, or similar instead. The canonical block above is safe because it uses `grep -l '^status:'` (file listing only); the trap is in ad-hoc rewrites that read the value.

### Convention-maturity check

This check is invoked specifically by the `/briefing sources` mode (and used to drive bullet 2 of `★ About this briefing` when applicable — see **About this briefing**). It is **not** rendered in default-mode briefings. Tally which canonical-conventions signatures are present vs missing.

| # | Signature | How to check |
|---|---|---|
| 1 | `## Project context` section in CLAUDE.md | grep `^## Project context` on `CLAUDE.md` |
| 2 | `docs/ROADMAP.md` exists | filesystem probe |
| 3 | `docs/CHANGELOG.md` exists | filesystem probe |
| 4 | Lifecycle dirs present (`docs/0-brainstorms/`, `docs/2-design/`, `docs/3-plans/` at minimum) | filesystem probe; require all three |
| 5 | Status frontmatter used in lifecycle artifacts | `grep -l '^status:' docs/*/*.md` returns ≥ 1 |
| 6 | ROADMAP uses canonical sections (`## In flight`, `## Next actions`, `## Recently shipped` at minimum) | grep on roadmap; require all three |
| 7 | ADRs at `docs/adrs/NNNN-*.md` | filesystem probe with name pattern |

The 7-signature tally feeds two outputs:

- **`/briefing sources` view** — populates the "What was read in this project" / "Not found" rows (see **`/briefing sources` mode** section).
- **Default-mode bullet 2** — when no canonical signatures hit and no `## Project context` was declared, render bullet 2 of `★ About this briefing` (`Briefing relied on git/gh only — /briefing sources to see what else this skill can read.`).

Read-only. Descriptive, not prescriptive.

### Layer 3 — Graceful degradation

Standing instructions for when a source fails. Never fabricate; always name the gap.

| Failure mode | Behaviour |
|---|---|
| Not in a git repo | Skip git/gh entirely; fall back to file discovery only |
| Git repo, no remote | Skip `git fetch` and `gh` queries; report local state only |
| `gh` missing or unauthed | Skip GitHub queries; render `★ About this briefing` bullet 4 (`GitHub queries skipped (gh not authenticated)` or `(gh not installed)`) |
| `git fetch` slow / network down | Use stale refs; render `★ About this briefing` bullet 3 (`Refs from last fetch <relative-date>`) |
| `git fetch` fails with auth error on a configured remote | Use stale refs; render `★ About this briefing` bullet 3 variant (`Fetch failed (auth) — refs may be stale; check credentials`) |
| L2a absent + L2b detected nothing | Run L1 only; render `★ About this briefing` bullet 2 (`Briefing relied on git/gh only — /briefing sources to see what else this skill can read.`) |
| L2a absent + L2b partial | Stay quiet in default-mode output. User can run `/briefing sources` to see what was found. |
| Declared L2a source unreachable (auth-walled, missing CLI/MCP) | Render `★ About this briefing` bullet 1 (`Some sources unavailable — /briefing sources for details.`) or, when the unreachable source is specifically a tracker integration, bullet 5 (`<Tracker> declared but <CLI> not available — install or configure MCP`) |
| Working memory not found at any L2b path | If a path was declared via `## Project context` and failed → bullet 1. Otherwise stay quiet. |
| Diff over per-file cap (200 lines) | Summarise rather than dump |
| Detached HEAD | Render `★ About this briefing` bullet 7 (`On detached HEAD; reporting against nearest branch <X>`) |
| Empty repo / no `docs/` | Produce a minimal briefing; do not invent suggestions |
| Untracked file matches secret pattern (`.env*`, `*.pem`, `*.key`, `id_rsa*`, `credentials*`) | Skip silently — never read |

## In-flight detection

What triggers the briefing's adaptive output to lead with active work. Universal signals at the top, conventions-resolved signals below.

| Signal | Strength | Source / notes |
|---|---|---|
| Open PR authored by me | Strong | from L1 `gh pr list --author @me --state open` |
| Unpushed commits on current branch | Strong | from L1 `git rev-list --count @{upstream}..HEAD`; covers "branch ahead of upstream" |
| Unpushed commits on *other* local branches | Strong | from L1 `git for-each-ref` + ahead counts |
| Stashes | Strong | from L1 `git stash list`; the most-forgotten state in git |
| Working tree dirty (uncommitted edits) | Strong | from L1 `git status --porcelain`; read content of changed files (200-line cap) |
| Tracker items in "in progress" status | Strong | from L2a tracker integration; only if a tracker is declared |
| ROADMAP "in-flight section" non-empty | Strong | from L2b-resolved roadmap path + L2b-resolved in-flight section regex |
| Lifecycle artifacts with in-flight status | Strong | from L2b-resolved working-memory dirs + L2b-resolved in-flight status set |
| Local-only branches (no upstream) | Medium | from L1 `git branch -vv` filter |
| Worktrees (count > 1) | Medium | from L1 `git worktree list` |
| Recent commits in last 24h | Weak | from L1 `git log --since=1.day`; orientation only, never leads |

**Detection rule:** if any signal labelled **Strong** in the table above is present, the output leads with the **What's in flight** section. Otherwise lead with **Recent activity** and **What's next**. Don't sum or score — any single Strong-labelled signal is enough to flip the lead. Medium-labelled signals never trigger the lead but are reported (under **What's in flight** when it runs, otherwise under **Recent activity**). Weak-labelled signals never lead and feed **Recent activity** only.

The table's row order is the order the resulting bullets should be reported in, not a priority ranking — Strong-labelled signals are equally sufficient to trigger the lead.

**Strong/Medium/Weak are internal classification only.** Never echo them in the rendered briefing — bullets describe their own subject ("Working tree dirty", "Open PRs", "Stashes"), not their detection strength.

(The output sections themselves are defined under **Output template** below.)

## Output template

In adaptive mode (the default), two sections always run and four are conditional on signal presence; sections with nothing to say are omitted entirely, not padded. Explicit depth keywords reshape this contract — `standard` forces all six, `quick` collapses, `deep` extends — and are codified under **Depth contract** below.

> **Spec annotations:** the `←` comments in the template below (e.g. `← always`, `← only if any strong signal`) are *spec annotations* explaining when each section renders — they must NOT appear in the actual briefing the user sees.

```markdown
## Briefing — <project name>
<date> · <branch> · <ahead/behind summary>

### TL;DR                                      ← always
1–2 sentences. Leads with whatever matters most right now:
- in-flight present  → "You stopped mid-X. Y is the next move."
- clean state        → "Last shipped Z. Next priority is W."

### Snapshot                                   ← always
- Branch: <current> (<N> ahead, <M> behind <upstream>)
- Roadmap: X/Y items · next: <item>     ← only if a roadmap was found (declared or detected)
- Recent activity: <last commit / last PR / last shipped lifecycle item>
- [Bullets from sources declared in `## Project context`: tracker counts, board column health, etc.]

### What's in flight                           ← only if any strong signal
- Working tree: <paths and one-line summary>
- Local-only: <unpushed commits / stashes / no-upstream branches / worktrees if > 1>
- <roadmap section title>: <items + state>     ← rendered with the project's actual ROADMAP section name (e.g. "## In flight", "## Now")
- Open PRs: <your PRs + review status>
- Drafts: <lifecycle artifacts with in-flight status>     ← rendered with the project's actual status vocabulary (e.g. "status: draft|open|approved")
- Tracker: <items in progress>     ← only if a tracker was declared in `## Project context`

### Recent activity                            ← always (last 3-5 things)
Synthesised, not dumped. Group by theme. Reference SHA / PR# / file path.

### What's next                                ← always
Recommended next action with reasoning.
Reference roadmap priority (if found), dependency chain, newly unblocked items.

### Decisions / attention                      ← only if there's something
- Design calls AI shouldn't make alone
- Recurring issues suggesting a convention change
- Risky operations needed (force push? release cut?)
- Stale work to triage (old PRs / ancient stashes / forgotten branches)

[★ About this briefing — conditional, see About this briefing section below]
[Optional: Saved to <path>]
```

### Section-by-section rules

**TL;DR:** 1–2 sentences. Always present. Lead with the most important thing:
- if in-flight present → "You stopped mid-X. Y is the next move."
- if clean state      → "Last shipped Z. Next priority is W."

If everything else got cut, the TL;DR alone should still be useful.

**Snapshot:** Always present. One-line bullets only. Branch line comes from `git rev-parse --abbrev-ref HEAD` plus the ahead/behind counts; roadmap line from the resolved roadmap path (whether declared in `## Project context` or detected at a default location); recent-activity line from the most recent of `git log -1`, last merged PR, or last shipped lifecycle item. Add bullets for sources declared in `## Project context` (tracker counts, board column health) only when those sources were declared and read.

**What's in flight:** Only if any Strong-strength signal from the In-flight detection table. Group bullets by what they describe (Working tree, Local-only, ROADMAP, Open PRs, Drafts, Tracker — see the output template above), **not** by Strong/Medium/Weak — those labels are internal classification and must never appear in the rendered briefing. Render the roadmap-section bullet using the project's actual ROADMAP heading (e.g. `ROADMAP "## In flight":` for canonical projects; `ROADMAP "## Now":` for a project using Now/Next/Later; omit entirely if no roadmap was found). Render the drafts bullet using the project's actual status vocabulary (e.g. `Drafts (status: draft|open|approved):` for canonical; `Drafts (status: wip):` for a project using a different vocabulary; omit if no working memory was found). Don't dump diffs — summarise per the 200-line cap.

**Recent activity:** Always present. Last 3–5 things, synthesised not dumped. Group by theme rather than listing commits chronologically. Cite SHA / PR# / file path so the human can drill in.

**What's next:** Always present. Recommended next action with reasoning. Reference roadmap priority (if found), dependency chain, newly-unblocked items. One paragraph or 2–3 bullets, not a wall of text.

**Decisions / attention:** Only if there's something to say. Bullet list. Categories: design calls the AI shouldn't make alone; recurring issues that suggest a convention change; risky operations needed (force push, release cut); stale work to triage (old PRs, ancient stashes, forgotten branches).

The **`★ About this briefing` block** is conditional — it renders only when at least one bullet has content (see **About this briefing** below for the bullet inventory and trigger rules). When no bullet applies, the block omits entirely and the briefing ends with whatever section ran last. The `[Optional: Saved to <path>]` line appears only when `save` was passed; the actual save path and write semantics are defined under **Save behaviour** below. Depth-override notes from the parser surface as bullet 6 inside `★ About this briefing` (text: `Depth received both '<X>' and '<Y>'; using '<Y>'`).

## About this briefing — conditional footer block

A short footer block that renders only when at least one bullet has content; omits entirely when no bullets apply (the typical healthy-project case).

Visual format — bullets are separated by blank lines (loose list) so the block reads at a glance even when several bullets co-render:

```
★ About this briefing ─────────────────────────
- <bullet 1>

- <bullet 2>

- <bullet 3>
─────────────────────────────────────────────────
```

### Bullet inventory

Each bullet renders only when its trigger fires. Block omits when zero bullets apply.

1. **Some sources unavailable** — when a declared or default-path source didn't resolve. Render: `Some sources unavailable — /briefing sources for details.`
2. **Briefing relied on git/gh only** — when neither declared nor default-path sources hit. Render: `Briefing relied on git/gh only — /briefing sources to see what else this skill can read.`
3. **Stale or failed fetch** — render: `Refs from last fetch <relative-date>` or `Fetch failed (auth) — refs may be stale; check credentials`.
4. **GitHub unavailable** — render: `GitHub queries skipped (gh not authenticated)` or `(gh not installed)`.
5. **Tracker integration unavailable** — render: `<Tracker> declared but <CLI> not available — install or configure MCP`.
6. **Depth conflict** — render: `Depth received both '<X>' and '<Y>'; using '<Y>'` OR `Depth ignored when 'sources' mode is active`.
7. **Detached HEAD** — render: `On detached HEAD; reporting against nearest branch <X>`.

### Bullet priority

When more than one bullet would render, prefer the more specific signal:

- Bullet 1 (some sources unavailable) supersedes bullet 2 (briefing relied on git/gh only) when both fire — e.g. a declared path failed to resolve AND no other paths hit either. Both point to the same command; bullet 1 is the more specific report.
- Bullet 5 (tracker integration unavailable) supersedes bullet 1 when the unavailable source is specifically a tracker integration declared via `## Project context`. Bullet 5 names the tracker and the missing CLI/MCP; bullet 1 is the generic version.

All other bullets are independent and may co-render with each other.

### Removed (compared to prior footer)

- The `Sources: read X, Y, Z` enumeration (briefing body shows what was read).
- Skip-mentions for declared-`none` sources (no signal value).
- The 7-row maturity table (relocated to `/briefing sources`).
- The "Adopt or learn more" link (relocated to `/briefing sources`).

## Depth contract

> Depth keywords (`quick`/`standard`/`deep`) control source breadth and output length. They do not apply to `/briefing sources`, which is a separate mode (see **`/briefing sources` mode** above).

The depth dial scales three things together — output length, source breadth, and wall-clock — because deep output requires deep input which takes time.

| Depth | Length | Sources read | Wall-clock | Use when |
|---|---|---|---|---|
| `quick` | < 300w | git/gh essentials only (status/log/diff, last PR, last commit) plus the resolved roadmap head if available — ~5–7 reads | < 5s | "Remind me where I am, fast" |
| (adaptive) | content-driven | full git/gh + declared sources from `## Project context` + canonical-conventions sniffing | 5–15s | Default |
| `standard` | 600–1000w | All adaptive sources, no skipping | 10–20s | Forces full coverage |
| `deep` | 1200–2000w | Standard + historical sources + cross-source synthesis + per-project memory files | 20–60s | "Real planning session, audit the lot" |

**Deep-mode-only sources** (extending the time window beyond "now"):

| Source | Why it earns deep |
|---|---|
| Closed PRs in last 30 days (`gh pr list --state merged --search "merged:>=$(date -u -v-30d +%Y-%m-%d)" --limit 50`) | Trend in shipping cadence; what got merged the briefing's "recent activity" missed |
| Closed issues in last 30 days (`gh issue list --state closed --search "closed:>=$(date -u -v-30d +%Y-%m-%d)"`) | What got resolved — useful for "is this old issue still relevant?" |
| Stale branches (`git for-each-ref --sort=-committerdate --format='%(refname:short) %(committerdate:relative) %(committerdate:short)' refs/heads/` — filter for `committerdate:short` older than 30 days) | Cleanup signal — branch graveyard surfaces |
| Stale open PRs (open > 14 days) | Forgotten work; different from in-flight because not moving |
| Recent ADRs (last 5 from any declared or detected ADR location) | Architectural context affecting next moves |
| Cross-source synthesis | Recurring themes across 3+ sources flagged as systemic |
| Tracker closed items | If a tracker is declared in `## Project context`, fetch closed items from last 7 days, not just open |
| Trend analysis on changelog | Velocity / cadence / scope drift across last 5–10 entries (when a changelog was found) |
| Per-project memory files | Read individual files in `~/.claude/projects/<slug>/memory/` (MEMORY.md index already in context) |

**Not read at any depth:** raw conversation transcripts on disk. Reading them would undermine the working-memory discipline the canonical conventions describe (artifacts become optional if briefings can recover from transcripts), transcripts are noisy (corrections, abandoned approaches, false starts), and the on-disk format is undocumented Anthropic internals. The principled equivalent is a Stop hook with an explicit snapshot schema — deferred (Approach C in the design doc).

## /briefing sources mode

Triggered by passing `sources` as the mode keyword. Can't be combined with depth tiers (`quick`/`standard`/`deep`) — pick one or the other. Compatible with `save`. Produces a self-documentation view of what this skill probes and what it found in the project.

### Output template

```
Briefing sources — <project-name>

What this skill reads:

  Always-on
    git status, recent commits, stashes, worktrees, GitHub PRs/issues/CI

  Declared (highest priority)
    `## Project context` in CLAUDE.md
    Fields: Tracker, Board, Roadmap, Changelog, Architecture, Working memory, Auto-fetch, Other

  Default paths (when not declared)
    Roadmap → docs/ROADMAP.md → ROADMAP.md
    Changelog → docs/CHANGELOG.md → CHANGELOG.md
    Working memory → docs/[0-9]-*/, docs/adrs/, files with `status:` frontmatter
    ADRs → docs/adrs/NNNN-*.md → docs/architecture/decisions/, decisions/, adr/

  Fallbacks
    When a source can't be reached or doesn't exist, this skill names
    the gap explicitly rather than inventing data.

What was read in this project:

  Always-on:    git (<state>), gh (<state>)
  Declared:     <field>=<path> | <field>=none, ...
  Default:      <paths that hit>, ...
  Not found:    <paths probed but absent>

Want richer briefings? Two paths, both equally valid:
  - Declare additional locations in `## Project context`. Example:
      - **Adrs**: docs/architecture/decisions/
  - Or adopt canonical conventions for zero-config: <CANONICAL_CONVENTIONS_URL>

Last synced from the conventions guide: <YYYY-MM-DD>
```

### Empty-layer rendering

When a layer has no entries (e.g. project declared no `## Project context` and no canonical default paths matched), render the layer header with `(none)` underneath rather than omitting the layer. Transparency is the purpose of this view.

### Date stamp

The `Last synced from the conventions guide: <YYYY-MM-DD>` stamp is a maintainer-tracked date carried in this `SKILL.md`. It records when the layer descriptions and probe paths in this view were last reconciled against the canonical conventions guide. Format: ISO date (e.g. `2026-05-03`). Update whenever the canonical guide changes in a way that affects this view's content.

### Parser interaction

- **Mutex with depth keywords.** If a user types `/briefing sources deep`, the parser still renders the sources view; bullet 6 of `★ About this briefing` renders inside the sources view's footer with text `Depth ignored when 'sources' mode is active`.
- **Compatible with `save`.** See **Save behaviour** for frontmatter shape.
- **`help` wins.** If `help` is present, render the synopsis and stop (existing rule).

### Tone

The view is descriptive, not prescriptive. The "Two paths, both equally valid" framing is non-preferential between Declared and Default-paths approaches: a project using `decisions/` instead of `docs/adrs/` and declaring the path is a first-class hit, not a deviation. Never imply canonical conventions are preferred.

## Save behaviour

Triggered by passing `save` (or synonyms `--save`, `export`) — see **How to parse the args**.

Determine the destination directory and a non-colliding filename, then create the directory if needed:

```bash
# Determine destination — repo-local if in a git repo, otherwise home
if git rev-parse --show-toplevel >/dev/null 2>&1; then
  DEST="$(git rev-parse --show-toplevel)/.claude/briefing-log"
else
  DEST="$HOME/.claude/briefing-log"
fi
mkdir -p "$DEST"

# Filename — ISO8601 to the minute, UTC. Sources-mode saves get a `-sources` suffix.
TS=$(date -u +%Y-%m-%dT%H%M)
if [ "$MODE" = "sources" ]; then
  FILE="$DEST/$TS-sources.md"
else
  FILE="$DEST/$TS.md"
fi

# On collision, append -2, -3, ...
N=2; while [[ -e "$FILE" ]]; do FILE="$DEST/$TS-$N.md"; N=$((N+1)); done
```

Once `$FILE` is computed, write the file using the Write tool (not `cat`/heredoc — the briefing body comes from your conversation render, not from a shell variable). The file's content is YAML frontmatter followed by the verbatim rendered briefing.

**Frontmatter** — six fields, in this order. Default-mode saves carry `depth:`; sources-mode saves carry `mode: sources` instead. The two fields are mutex — every save record has exactly one.

```yaml
---
type: briefing-log
date: YYYY-MM-DDTHH:MM
project: <git-repo-name or cwd basename>
branch: <current>
# Default-mode briefing save:
depth: <quick|standard|deep|adaptive>
in-flight: <yes|no>
# OR, for /briefing sources save:
# mode: sources
---
```

**Body:** the verbatim rendered output. For default-mode saves, that's the briefing including any `★ About this briefing` block. For sources-mode saves, that's the full `/briefing sources` view including the date stamp.

**Final line printed to the user** after the file is written:

```
Saved to <abs path>. briefing-log/ is unignored by default — commit or .gitignore your call.
```

The save log is the only write this skill ever makes; everything else is read-only.

## Tone

- **Lead with the most important thing.** TL;DR carries the key message; if everything else got cut, TL;DR alone should be useful.
- **Be specific.** File paths, SHAs, branch names, PR numbers, ROADMAP item names. Vague briefings are worse than no briefing.
- **Cite metrics, never compute them.** Read line counts, ahead/behind, dates from existing tooling. Don't aggregate token costs or estimate durations.
- **No emojis, no hype.** "Last shipped X" not "Successfully shipped X! 🎉".
- **Concise over comprehensive.** Bullets when structure helps scanning. No "It's worth noting that…"
- **Honest about gaps.** Source unreachable / empty → name it, don't fabricate.
- **Read-only on everything except `briefing-log/`.** The save log is the only write the skill ever makes; it lands in a dedicated directory, never in project files.
- **Suggest, don't impose.** Default-mode output never lobbies for convention adoption. Audit-style suggestions live in `/briefing sources` and are framed descriptively: equivalent info in different locations (declared via `## Project context`) is a first-class hit, not a deviation. Never auto-applies a convention; never edits CLAUDE.md or any other project file.
- **Prefer "you" framing.** This is a personal orientation tool ("you stopped mid-X"). For orientation, "you" is sharper than "we" or "the code" — the user invoked the skill *to be reminded what they were doing*.
- **No time estimates.** Don't say "this should take 2 hours." Estimate scope (small / medium / large by analogy to similar past items in the changelog) at most.

## Anti-fabrication

- **Don't generate from memory.** Every data point comes from a source read this invocation.
- **Don't compute metrics.** Read aggregates from existing artifacts; cite raw counts you can verify.
- **Don't fabricate URLs, PR numbers, file paths, commit SHAs.** If uncertain, omit or hedge ("there may be additional…").
- **Don't pretend a tracker integration worked when it didn't.** If the CLI is missing or the MCP failed, name the gap; do not invent items.
- **Don't overstate freshness.** If `git fetch` failed and refs are 2 days old, say so. The cost of stale data presented as fresh is higher than the cost of stale data labelled stale.
- **Don't synthesise patterns from thin data.** "Trend" requires 3+ data points. Below that, report individual facts; don't editorialise into a pattern.
- **Don't presume conventions.** Default-mode output never prescribes canonical adoption. The `/briefing sources` view shows what was probed and what was found regardless, and frames non-canonical paths as first-class via `## Project context` declarations.

## What NOT to do

- Don't read raw conversation transcripts — see **Depth contract**, "Not read at any depth".
- Don't `git pull` — only `git fetch`. The fetch is read-only and never modifies the working tree (see the git-refs-refresh callout under Layer 1 above).
- Don't dump per-file diffs over 200 lines — summarise as `path:line-range (~N lines, looks like <one-line summary>)`.
- Don't fabricate PR numbers, file paths, commit SHAs, or URLs. If uncertain, omit or hedge.
- Don't compute metrics — cite them from existing tooling (line counts, ahead/behind, dates).
- Don't pad sections with nothing to say. In adaptive mode, omit empty sections entirely.
- Don't estimate time-to-completion. Estimate scope by analogy to similar changelog items at most.
- Don't write outside `briefing-log/`. Every other path this skill touches is read-only.
- Don't render the `★ About this briefing` block when no bullet has content — omit entirely.
- Don't put audit/setup content in default-mode briefing output. That belongs in `/briefing sources`.
- Don't presume canonical conventions are preferred over declared paths. Both are first-class in `/briefing sources`.
- Don't lobby for convention adoption in default-mode output. The Tone rule "Suggest, don't impose" applies: suggestion content lives in `/briefing sources` only.
