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
/briefing [depth] [save] [help]

  depth   quick | standard | deep                      default: adaptive (no override)
          (synonyms — quick: peek
                      deep:  deep-dive, audit)
  save    write the briefing to disk                   default: off
          (synonyms: --save, export)
  help    show this synopsis instead of running        default: off
          (synonyms: ?, usage, --help, -h)
```

Order of args does not matter. `/briefing deep save` and `/briefing save deep` are equivalent. If any help keyword (the full set is listed under **How to parse the args** below — `help`, `--help`, `-h`, `?`, `usage`) appears anywhere in the args, the skill renders this Synopsis as the response and stops — no briefing, no save.

The depth default is **adaptive**: when no depth keyword is provided, the briefing's length is content-driven — sections appear or disappear based on what the project state actually contains. `quick`, `standard`, and `deep` are explicit overrides for fixed-length tiers; "no dial" is its own behaviour, not a synonym for `standard`.

## How to parse the args

Walk the tokens once and bucket each one:

- **Depth keywords** (closed set): `quick`, `peek`, `standard`, `deep`, `deep-dive`, `audit`. Default: adaptive (no override) if no depth keyword is present.
- **Save keywords** (closed set): `save`, `--save`, `export`. Default off.
- **Help keywords** (closed set): `help`, `--help`, `-h`, `?`, `usage`. If any appear, **short-circuit**: render the Synopsis above and stop.
- **Anything else**: respond with `unknown arg <X> — try /briefing help` and stop.

The parser is order-independent and case-insensitive. Two of the same bucket is an error of intent — pick the **rightmost** occurrence in the input and mention the override in the briefing's source-coverage footer (e.g., `Note: depth received both 'quick' and 'deep'; using 'deep'`). The source-coverage footer itself is defined under **Output template** below.

## Source layering

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

After L2 completes, tally which canonical-conventions signatures are present vs missing. The check feeds the optional footer block (see **Output template** below).

| # | Signature | How to check |
|---|---|---|
| 1 | `## Project context` section in CLAUDE.md | grep `^## Project context` on `CLAUDE.md` |
| 2 | `docs/ROADMAP.md` exists | filesystem probe |
| 3 | `docs/CHANGELOG.md` exists | filesystem probe |
| 4 | Lifecycle dirs present (`docs/0-brainstorms/`, `docs/2-design/`, `docs/3-plans/` at minimum) | filesystem probe; require all three |
| 5 | Status frontmatter used in lifecycle artifacts | `grep -l '^status:' docs/*/*.md` returns ≥ 1 |
| 6 | ROADMAP uses canonical sections (`## In flight`, `## Next actions`, `## Recently shipped` at minimum) | grep on roadmap; require all three |
| 7 | ADRs at `docs/adrs/NNNN-*.md` | filesystem probe with name pattern |

**Render the maturity block in the footer ONLY when partial adoption is detected** — i.e. at least one signature ✓ AND at least one signature ✗. If everything matches: the project is fully canonical, no maturity block. If nothing matches: the project doesn't follow these conventions at all, no maturity block (suggesting them would be presumptuous).

The block format:

```
Project orientation maturity (briefing quality could improve):
- [<✓|✗>] <signature 1 name> — <one-line note: what it gives you / where to fix>
- [<✓|✗>] <signature 2 name> — …
…

Adopt or learn more: <CANONICAL_CONVENTIONS_URL>
```

Read-only. Suggestions, not edits.

### Layer 3 — Graceful degradation

Standing instructions for when a source fails. Never fabricate; always name the gap.

| Failure mode | Behaviour |
|---|---|
| Not in a git repo | Skip git/gh entirely; fall back to file discovery only |
| Git repo, no remote | Skip `git fetch` and `gh` queries; report local state only |
| `gh` missing or unauthed | Skip GitHub queries; note the gap in the footer |
| `git fetch` slow / network down | Use stale refs; footer: *"ahead/behind from last fetch <date>"* |
| `git fetch` fails with auth error on a configured remote | Use stale refs; footer: *"fetch failed (auth) — refs may be stale; check credentials"* — distinct signal from "no remote" |
| L2a absent + L2b detected nothing | Run L1 only; if no maturity-block trigger, render the footer with a one-line *"No `## Project context` section detected and no canonical-conventions signatures found — orientation relies on git+filesystem discovery only. See `<CANONICAL_CONVENTIONS_URL>` to opt in."* |
| L2a absent + L2b partial | Render the convention-maturity block in the footer (see check above) |
| Declared L2a source unreachable (auth-walled, missing CLI/MCP) | Name the gap explicitly; continue with the remaining sources |
| Working memory not found at any L2b path | Footer note: *"no working-memory artifacts detected; orientation relies on git history."* |
| Diff over per-file cap (200 lines) | Summarise rather than dump |
| Detached HEAD | Say so; find the nearest branch ref and report against it |
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

**Detection rule:** if any *Strong* signal is present, the output leads with the **What's in flight** section. Otherwise lead with **Recent activity** and **What's next**. Don't sum or score — any single Strong hit is enough to flip the lead. Medium signals never trigger the lead but are reported (under **What's in flight** when it runs, otherwise under **Recent activity**). Weak signals never lead and feed **Recent activity** only.

The table's row order is the order the resulting bullets should be reported in, not a priority ranking — Strong signals are equally sufficient to trigger the lead.

(The output sections themselves are defined under **Output template** below.)

## Output template

In adaptive mode (the default), two sections always run and four are conditional on signal presence; sections with nothing to say are omitted entirely, not padded. Explicit depth keywords reshape this contract — `standard` forces all six, `quick` collapses, `deep` extends — and are codified under **Depth contract** below.

```markdown
## Briefing — <project name>
<date> · <branch> · <ahead/behind summary>

### TL;DR                                      ← always
1–2 sentences. Leads with whatever matters most right now:
- in-flight present  → "You stopped mid-X. Y is the next move."
- clean state        → "Last shipped Z. Next priority is W."

### Snapshot                                   ← always
- Branch: <current> (<N> ahead, <M> behind <upstream>)
- Roadmap: X/Y items · next: <item>     ← only if a roadmap was found (L2a or L2b)
- Recent activity: <last commit / last PR / last shipped lifecycle item>
- [Layer-2a bullets if declared: tracker counts, board column health, etc.]

### What's in flight                           ← only if any strong signal
- Working tree: <paths and one-line summary>
- Local-only: <unpushed commits / stashes / no-upstream branches / worktrees if > 1>
- <roadmap section title>: <items + state>     ← rendered with L2b-resolved heading
- Open PRs: <your PRs + review status>
- Drafts: <lifecycle artifacts with in-flight status>     ← rendered with L2b-resolved status set
- Tracker (if L2a): <items in progress>

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

---
Sources: read <list>; skipped <list> (reason).
[Optional: convention-maturity block, only when partial adoption — see L2b]
[Optional: Saved to <path>]
```

### Section-by-section rules

**TL;DR:** 1–2 sentences. Always present. Lead with the most important thing:
- if in-flight present → "You stopped mid-X. Y is the next move."
- if clean state      → "Last shipped Z. Next priority is W."

If everything else got cut, the TL;DR alone should still be useful.

**Snapshot:** Always present. One-line bullets only. Branch line comes from `git rev-parse --abbrev-ref HEAD` plus the ahead/behind counts from L1; roadmap line from the L2-resolved roadmap path (if found); recent-activity line from the most recent of `git log -1`, last merged PR, or last shipped lifecycle item. Add L2a bullets (tracker counts, board column health) only when those sources were declared and read.

**What's in flight:** Only if any Strong signal. Group bullets by source category. Render the roadmap-section bullet using the L2b-resolved heading (e.g. `ROADMAP "## In flight":` for canonical projects; `ROADMAP "## Now":` for a project using Now/Next/Later; omit entirely if no roadmap was found). Render the drafts bullet using the L2b-resolved status set (e.g. `Drafts (status: draft|open|approved):` for canonical; `Drafts (status: wip):` for a project using a different vocabulary; omit if no working memory was found). Don't dump diffs — summarise per L1's 200-line cap.

**Recent activity:** Always present. Last 3–5 things, synthesised not dumped. Group by theme rather than listing commits chronologically. Cite SHA / PR# / file path so the human can drill in.

**What's next:** Always present. Recommended next action with reasoning. Reference roadmap priority (if found), dependency chain, newly-unblocked items. One paragraph or 2–3 bullets, not a wall of text.

**Decisions / attention:** Only if there's something to say. Bullet list. Categories: design calls the AI shouldn't make alone; recurring issues that suggest a convention change; risky operations needed (force push, release cut); stale work to triage (old PRs, ancient stashes, forgotten branches).

The **source-coverage footer** (the block under the `---` rule) names every source actually read on the `Sources:` line and every source not read under `skipped <list>` with the reason in parens (auth, missing CLI, declared `none`, network failure, etc.). The optional **convention-maturity block** appears below the footer line when partial-adoption is detected (per the convention-maturity check above) — render the block with the 7 ✓/✗ rows and the canonical-conventions URL. The `[Optional: Saved to <path>]` line appears only when `save` was passed; the actual save path and write semantics are defined under **Save behaviour** below. Depth-override notes from the parser (e.g. `Note: depth received both 'quick' and 'deep'; using 'deep'`) also surface in this footer.

## Depth contract

The depth dial scales three things together — output length, source breadth, and wall-clock — because deep output requires deep input which takes time.

| Depth | Length | Sources read | Wall-clock | Use when |
|---|---|---|---|---|
| `quick` | < 300w | L1 essential only (git status/log/diff, last PR, last commit) plus L2-resolved roadmap head if available — ~5–7 reads | < 5s | "Remind me where I am, fast" |
| (adaptive) | content-driven | L1 full + L2a if declared + L2b sniffing | 5–15s | Default |
| `standard` | 600–1000w | All adaptive sources, no skipping | 10–20s | Forces full coverage |
| `deep` | 1200–2000w | Standard + historical sources + cross-source synthesis + per-project memory files | 20–60s | "Real planning session, audit the lot" |

**Deep-mode-only sources** (extending the time window beyond "now"):

| Source | Why it earns deep |
|---|---|
| Closed PRs in last 30 days (`gh pr list --state merged --search "merged:>=$(date -u -v-30d +%Y-%m-%d)" --limit 50`) | Trend in shipping cadence; what got merged the briefing's "recent activity" missed |
| Closed issues in last 30 days (`gh issue list --state closed --search "closed:>=$(date -u -v-30d +%Y-%m-%d)"`) | What got resolved — useful for "is this old issue still relevant?" |
| Stale branches (`git for-each-ref --sort=-committerdate --format='%(refname:short) %(committerdate:relative) %(committerdate:short)' refs/heads/` — filter for `committerdate:short` older than 30 days) | Cleanup signal — branch graveyard surfaces |
| Stale open PRs (open > 14 days) | Forgotten work; different from in-flight because not moving |
| Recent ADRs (last 5 from L2b-resolved ADR location) | Architectural context affecting next moves |
| Cross-source synthesis | Recurring themes across 3+ sources flagged as systemic |
| L2a closed items | If an L2a tracker is configured, fetch closed items from last 7 days, not just open |
| Trend analysis on changelog | Velocity / cadence / scope drift across last 5–10 entries (when a changelog was found) |
| Per-project memory files | Read individual files in `~/.claude/projects/<slug>/memory/` (MEMORY.md index already in context) |

**Not read at any depth:** raw conversation transcripts on disk. Reading them would undermine the working-memory discipline the canonical conventions describe (artifacts become optional if briefings can recover from transcripts), transcripts are noisy (corrections, abandoned approaches, false starts), and the on-disk format is undocumented Anthropic internals. The principled equivalent is a Stop hook with an explicit snapshot schema — deferred (Approach C in the design doc).

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

# Filename — ISO8601 to the minute, UTC
TS=$(date -u +%Y-%m-%dT%H%M)
FILE="$DEST/$TS.md"

# On collision, append -2, -3, ...
N=2; while [[ -e "$FILE" ]]; do FILE="$DEST/$TS-$N.md"; N=$((N+1)); done
```

Once `$FILE` is computed, write the file using the Write tool (not `cat`/heredoc — the briefing body comes from your conversation render, not from a shell variable). The file's content is YAML frontmatter followed by the verbatim rendered briefing.

**Frontmatter** — six fields, in this order:

```yaml
---
type: briefing-log
date: YYYY-MM-DDTHH:MM
project: <git-repo-name or cwd basename>
branch: <current>
depth: <quick|standard|deep|adaptive>
in-flight: <yes|no>
---
```

**Body:** the verbatim rendered briefing (the same text the user just saw), including the source-coverage footer and (if applicable) the convention-maturity block.

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
- **Suggest, don't impose.** When canonical-conventions adoption is partial, the maturity block surfaces the gaps and links the canonical guide. Never auto-applies a convention; never edits CLAUDE.md or any other project file.
- **Prefer "you" framing.** This is a personal orientation tool ("you stopped mid-X"). For orientation, "you" is sharper than "we" or "the code" — the user invoked the skill *to be reminded what they were doing*.
- **No time estimates.** Don't say "this should take 2 hours." Estimate scope (small / medium / large by analogy to similar past items in the changelog) at most.

## Anti-fabrication

- **Don't generate from memory.** Every data point comes from a source read this invocation.
- **Don't compute metrics.** Read aggregates from existing artifacts; cite raw counts you can verify.
- **Don't fabricate URLs, PR numbers, file paths, commit SHAs.** If uncertain, omit or hedge ("there may be additional…").
- **Don't pretend a tracker integration worked when it didn't.** If the CLI is missing or the MCP failed, name the gap; do not invent items.
- **Don't overstate freshness.** If `git fetch` failed and refs are 2 days old, say so. The cost of stale data presented as fresh is higher than the cost of stale data labelled stale.
- **Don't synthesise patterns from thin data.** "Trend" requires 3+ data points. Below that, report individual facts; don't editorialise into a pattern.
- **Don't presume conventions.** If L2b detects no canonical-conventions signatures, do NOT render the maturity block (it would be presumptuous to suggest "our" conventions to a project that hasn't adopted any of them).

## What NOT to do

- Don't read raw conversation transcripts — see **Depth contract**, "Not read at any depth".
- Don't `git pull` — only `git fetch`. The fetch is read-only and never modifies the working tree (see L1's git-refs-refresh callout).
- Don't dump per-file diffs over 200 lines — summarise as `path:line-range (~N lines, looks like <one-line summary>)`.
- Don't fabricate PR numbers, file paths, commit SHAs, or URLs. If uncertain, omit or hedge.
- Don't compute metrics — cite them from existing tooling (line counts, ahead/behind, dates).
- Don't pad sections with nothing to say. In adaptive mode, omit empty sections entirely.
- Don't estimate time-to-completion. Estimate scope by analogy to similar changelog items at most.
- Don't write outside `briefing-log/`. Every other path this skill touches is read-only.
- Don't render the convention-maturity block when nothing canonical was detected. Suggesting our conventions to a project that's chosen others is presumptuous; the block is for projects that have *partially* adopted, where naming the gap is helpful.
