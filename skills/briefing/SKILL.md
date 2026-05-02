---
name: briefing
description: |
  Adaptive project orientation. Auto-discovers project state from git, GitHub,
  the canonical docs/ working-memory layout, and any project-tracker source
  declared in CLAUDE.md (## Project context section). Reshapes output based on
  what's in flight — leads with active work if there is any, leads with what's
  next if not. Use whenever you start a session and need to catch up:
  "where am I, what was I doing, what's next?", "what changed while I was
  away?", "where did I stop?", or just /briefing.
argument-hint: "[depth] [save] [help]"
---

# `/briefing` — Adaptive project orientation

This skill produces a structured briefing of project state on demand. It auto-discovers what's in flight from git, GitHub, the canonical `docs/` working-memory layout, and any project-tracker source declared in this project's CLAUDE.md `## Project context` section. The output reshapes based on what it finds — leads with active work if there is any, leads with what's next if everything is calm.

The audience is you, returning to a project after a session, a day, a week, or a vacation. You want to know where you are, what you were doing, and what to pick up — without re-reading every file. The skill is read-only on the project (it never modifies project files); the only exception is the briefing log it writes when you invoke it with `save`.

For the convention this skill consumes, see your project's CLAUDE.md `## Project context` section, or [the canonical reference in this repo's conventions guide](../../guides/guide-project-structure-and-conventions.md#58--project-context-section-in-claudemd).

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

The parser is order-independent and case-insensitive. Two of the same bucket is an error of intent — pick the **rightmost** occurrence in the input and mention the override in the briefing's source-coverage footer (e.g., `Note: depth received both 'quick' and 'deep'; using 'deep'`). The source-coverage footer itself is defined under **Output template** (added in a later task); until that section lands, surface the override inline at the top of the response so the user sees it.

## Source layering

The briefing reads from three layers: a universal baseline that runs in any project, a project-declared layer parsed from CLAUDE.md's `## Project context` section, and a graceful-degradation layer of standing instructions for when sources fail. The layers exist so the skill works in any repo without setup, gets richer where projects have declared what they use, and never fabricates when something is missing — every gap is named, never papered over. On each invocation, run Layer 1 unconditionally, run Layer 2 only if `## Project context` is present in the project's CLAUDE.md, and apply Layer 3's standing instructions to any source that fails along the way.

### Layer 1 — Universal baseline

These sources run unconditionally, with no project configuration required. Probe each one in order; if a step fails, apply the matching Layer 3 instruction and continue.

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
> Layer 2's `## Project context`; if it is `no`, omit the fetch entirely.
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

**Top-level docs (already in your context, but re-check for staleness signals):**

```bash
ls -l README.md CLAUDE.md 2>/dev/null   # mtimes for staleness check
```

These files are typically already loaded in the conversation context; the recheck is for noticing recent edits, not for re-reading content unless mtimes suggest staleness.

**Canonical working-memory:**

```bash
ls -l docs/ROADMAP.md docs/CHANGELOG.md 2>/dev/null   # presence + mtimes
```

Read each if present at the canonical path. If absent, do not search elsewhere — note the absence in the footer.

**Lifecycle dirs (status frontmatter + recency):**

```bash
for d in docs/0-brainstorms docs/2-design docs/3-plans docs/4-reviews docs/adrs; do
  [ -d "$d" ] || continue
  find "$d" -maxdepth 1 -name '*.md' -print0 2>/dev/null \
    | xargs -0 grep -l '^status:' 2>/dev/null
  ls -t "$d" 2>/dev/null | head -5
done
```

Use the `status:` frontmatter to filter (open/draft/approved/shipped/parked/superseded); use `ls -t` for recency. The lifecycle convention is documented in [`guides/guide-project-structure-and-conventions.md`](../../guides/guide-project-structure-and-conventions.md).

**Per-project memory:**

Claude Code stores per-project state under a slug derived from the project's full path: leading `/` becomes `-`, and every other `/` also becomes `-`. So `/Users/me/Projects/foo` lives at `~/.claude/projects/-Users-me-Projects-foo/`.

```bash
slug="$(pwd | sed 's|/|-|g')"               # /a/b/c → -a-b-c
ls -l "$HOME/.claude/projects/$slug/memory/MEMORY.md" 2>/dev/null
```

If the index file exists (some users maintain one via an auto-memory system), read it for cross-session continuity notes. If not, skip silently — many projects do not maintain one.

### Layer 2 — Project-declared via CLAUDE.md

Read the `## Project context` section from CLAUDE.md (already in your context). Each line is `- **Field**: value`. Recognised fields:

- **Tracker** — where work items live (e.g. `GitHub Issues`, `Linear team FOO`, `Jira project BAR`, `Notion`, `GitHub Project N`, file path, or `none`).
- **Board** — URL of the active board / project view.
- **Roadmap** — file path or external URL of the forward view.
- **Changelog** — file path or external URL of recent shipped work.
- **Architecture** — file path or directory of architecture docs.
- **Working memory** — directory holding the lifecycle artifacts (default: `docs/` following the numbered-lifecycle convention).
- **Auto-fetch** — `yes` (default) or `no`; controls whether the briefing may run `git fetch` to refresh refs.
- **Other** — free-form bullet list for project-specific context.

Absent fields fall back to Layer 1 defaults at canonical paths. Declarations are additive, not mandatory. A field set to `none` means "deliberately empty" (do not probe further); an absent field means "try the default" (use the Layer 1 canonical path).

Presence check: grep for `^## Project context` in the project's CLAUDE.md. If absent, skip the Layer 2 read entirely and record a footer note for output (the footer schema lives under **Output template** in a later section).

#### Integration recipes

For each declared source, use the matching query path. Name the gap explicitly when a CLI or MCP integration is missing — do not silently skip.

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

### Layer 3 — Graceful degradation

Standing instructions for when a source fails. Never fabricate; always name the gap.

| Failure mode | Behaviour |
|---|---|
| Not in a git repo | Skip git/gh entirely; fall back to file discovery only |
| Git repo, no remote | Skip `git fetch` and `gh` queries; report local state only |
| `gh` missing or unauthed | Skip GitHub queries; note the gap in the footer |
| `git fetch` slow / network down | Use stale refs; footer: *"ahead/behind from last fetch <date>"* |
| `git fetch` fails with auth error on a configured remote | Use stale refs; footer: *"fetch failed (auth) — refs may be stale; check credentials"* — distinct signal from "no remote" |
| No `## Project context` in CLAUDE.md | Run Layer 1 only; footer link to the conventions guide |
| Declared source unreachable (auth-walled, missing CLI/MCP) | Name the gap explicitly; continue with the remaining sources |
| Diff over per-file cap (200 lines) | Summarise rather than dump |
| Detached HEAD | Say so; find the nearest branch ref and report against it |
| Empty repo / no `docs/` | Produce a minimal briefing; suggest `/init-project` (once shipped) |
| Untracked file matches secret pattern (`.env*`, `*.pem`, `*.key`, `id_rsa*`, `credentials*`) | Skip silently — never read |

## In-flight detection

What triggers the briefing's adaptive output to lead with active work.

| Signal | Strength | Source / notes |
|---|---|---|
| Open PR authored by me | Strong | from Layer 1 `gh pr list --author @me --state open` |
| Unpushed commits on current branch | Strong | from Layer 1 `git rev-list --count @{upstream}..HEAD`; covers "branch ahead of upstream" — Layer 1 does not separately compute ahead-of-base |
| Unpushed commits on *other* local branches | Strong | from Layer 1 `git for-each-ref` + ahead counts |
| Stashes | Strong | from Layer 1 `git stash list`; the most-forgotten state in git |
| ROADMAP `## In flight` non-empty | Strong | from Layer 1 working-memory read (this repo's convention) |
| Designs/plans with `status: draft` or `status: open` | Strong | from Layer 1 lifecycle for-loop (the portable form, not the brace-glob in earlier drafts of the spec) |
| Tracker items in "in progress" status | Strong | from Layer 2 query; only if a tracker is declared |
| Working tree dirty (uncommitted edits) | Strong | from Layer 1 `git status --porcelain`; read the content of changed files (subject to Layer 1's 200-line cap) |
| Local-only branches (no upstream) | Medium | from Layer 1 `git branch -vv` filter |
| Worktrees (count > 1) | Medium | from Layer 1 `git worktree list` |
| Recent commits in last 24h | Weak | from Layer 1 `git log --since=1.day`; orientation only, never leads |

**Detection rule:** if any *Strong* signal is present, the output leads with the **What's in flight** section. Otherwise lead with **Recent activity** and **What's next**. Don't sum or score — any single Strong hit is enough to flip the lead. Medium signals never trigger the lead but are reported (under **What's in flight** when it runs, otherwise under **Recent activity**). Weak signals never lead and feed **Recent activity** only.

The table's row order is the order the resulting bullets should be reported in, not a priority ranking — Strong signals are equally sufficient to trigger the lead. Strong rows are listed first to make the "is the lead triggered?" check fast (read down until a Strong hit, or hit the first Medium row to know none was found).

(The output sections themselves are defined under **Output template** below. Until **Depth** ships in a later task, the `quick`/`standard`/`deep` keywords are accepted by the parser but produce the adaptive output unchanged — surface the unhandled override in the source-coverage footer.)

## Output template

In adaptive mode (the default), two sections always run and four are conditional on signal presence; sections with nothing to say are omitted entirely, not padded. Explicit depth keywords reshape this contract — `standard` forces all six, `quick` collapses, `deep` extends — and are codified under **Depth** in a later section.

```markdown
## Briefing — <project name>
<date> · <branch> · <ahead/behind summary>

### TL;DR                                      ← always
1–2 sentences. Leads with whatever matters most right now:
- in-flight present  → "You stopped mid-X. Y is the next move."
- clean state        → "Last shipped Z. Next priority is W."

### Snapshot                                   ← always
- Branch: <current> (<N> ahead, <M> behind <upstream>)
- Roadmap: X/Y items · next: <item>
- Recent activity: <last commit / last PR / last shipped lifecycle item>
- [Layer-2 bullets if declared: tracker counts, board column health, etc.]

### What's in flight                           ← only if any strong signal
- Working tree: <paths and one-line summary>
- Local-only: <unpushed commits / stashes / no-upstream branches / worktrees if > 1>
- ROADMAP "## In flight": <items + state>
- Open PRs: <your PRs + review status>
- Drafts: <designs/plans with status: draft|open>
- Tracker (if layer 2): <items in progress>

### Recent activity                            ← always (last 3-5 things)
Synthesised, not dumped. Group by theme. Reference SHA / PR# / file path.

### What's next                                ← always
Recommended next action with reasoning.
Reference roadmap priority, dependency chain, newly unblocked items.

### Decisions / attention                      ← only if there's something
- Design calls AI shouldn't make alone
- Recurring issues suggesting a convention change
- Risky operations needed (force push? release cut?)
- Stale work to triage (old PRs / ancient stashes / forgotten branches)

---
Sources: read <list>; skipped <list> (reason).
[Optional: No `## Project context` section — see <link> to enrich.]
[Optional: Saved to <path>]
```

### Section-by-section rules

**TL;DR:** 1–2 sentences. Always present. Lead with the most important thing:
- if in-flight present → "You stopped mid-X. Y is the next move."
- if clean state      → "Last shipped Z. Next priority is W."

If everything else got cut, the TL;DR alone should still be useful.

**Snapshot:** Always present. One-line bullets only. Branch line comes from `git rev-parse --abbrev-ref HEAD` plus the ahead/behind counts from Layer 1; roadmap line from `docs/ROADMAP.md`; recent-activity line from the most recent of `git log -1`, last merged PR, or last `status: shipped` lifecycle item. Add Layer-2 bullets (tracker counts, board column health) only when those sources were declared and read.

**What's in flight:** Only if any Strong signal. Group bullets by source category — working tree (paths from `git status --porcelain`), local-only (unpushed / stashes / no-upstream branches / worktrees), ROADMAP `## In flight`, open PRs, drafts (`status: draft|open` in lifecycle dirs), tracker. Don't dump diffs — summarise per Layer 1's 200-line cap.

**Recent activity:** Always present. Last 3–5 things, synthesised not dumped. Group by theme rather than listing commits chronologically. Cite SHA / PR# / file path so the human can drill in.

**What's next:** Always present. Recommended next action with reasoning. Reference roadmap priority, dependency chain, newly-unblocked items. One paragraph or 2–3 bullets, not a wall of text.

**Decisions / attention:** Only if there's something to say. Bullet list. Categories: design calls the AI shouldn't make alone; recurring issues that suggest a convention change; risky operations needed (force push, release cut); stale work to triage (old PRs, ancient stashes, forgotten branches).

The **source-coverage footer** (the block under the `---` rule, named for what it does — declare which sources backed the briefing) names every source actually read on the `Sources:` line and every source not read under `skipped <list>` with the reason in parens (auth, missing CLI, declared `none`, network failure, etc.). The `[Optional: No ## Project context section ...]` line appears only when the project's CLAUDE.md lacks that section, and links to the conventions guide [§5.8 — `## Project context` section in CLAUDE.md](../../guides/guide-project-structure-and-conventions.md#58--project-context-section-in-claudemd). The `[Optional: Saved to <path>]` line appears only when `save` was passed; the actual save path and write semantics are defined under **Save behaviour** in a later section. Depth-override notes from the parser (e.g. `Note: depth received both 'quick' and 'deep'; using 'deep'`) also surface in this footer.
