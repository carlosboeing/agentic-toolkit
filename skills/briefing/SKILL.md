---
name: briefing
description: |
  Use only when the user explicitly invokes /briefing, $briefing, or asks to run
  the briefing skill. Do not invoke automatically for "what's next?", session
  starts, resumes, or ordinary task follow-ups.
disable-model-invocation: true
argument-hint: "[depth] [save] [help]"
---

# `/briefing` — Adaptive project orientation

## Invocation boundary

This skill is manual-only. Run it only when the user explicitly invokes `/briefing`, `$briefing`, or asks to run the briefing skill. A mention while discussing or editing the skill is not an invocation. If a reminder or automatic skill selector loads it without that request, stop before source discovery and answer the user's actual question within the active task.

This skill produces a structured briefing of project state on demand. It auto-discovers what's in flight from git, GitHub, the project's `<instructions-file>` `## Project Map` section (when present), and whatever working-memory layout it can detect. The output reshapes based on what it finds — leads with active work if there is any, leads with what's next if everything is calm.

The audience is you, returning to a project after a session, a day, a week, or a vacation. You want to know where you are, what you were doing, and what to pick up — without re-reading every file. The skill is read-only on the project (it never modifies project files); the only exception is the briefing log it writes when you invoke it with `save`.

The skill is **convention-aware but not convention-coupled**. It works generically in any repo, but lights up with richer behaviour when the project follows the canonical conventions referenced below. When partial adoption is detected, the briefing's footer suggests what's missing — read-only suggestions, never edits.

## Canonical conventions reference

A single absolute URL, defined once and reused throughout the skill. If this is renamed or moved upstream, this is the single line to update.

```
<CANONICAL_CONVENTIONS_URL> = https://github.com/carlosboeing/agentic-toolkit/blob/main/guides/guide-project-structure-and-conventions.md
```

When the skill needs to point users at the conventions guide (e.g. in the convention-maturity footer block, or when explaining what `## Project Map` is), it renders this URL — optionally with a section anchor like `#58--project-map-section-in-claudemd` for §5.8 or `#65-ai-agent-update-triggers-working-memory-discipline` for §6.5.

## Synopsis

```
/briefing [depth] [save] [help]              # default — orientation briefing
/briefing sources [save] [help]              # self-documentation view (what this skill probes + finds)
/briefing setup [help]                       # add or update `## Project Map` in <instructions-file>

  depth     adaptive (default) | quick | standard | deep
            Length × source breadth. Adaptive is content-driven (sections appear
            based on project state). Explicit tiers force fixed-length output.
            Synonyms — quick: peek; deep: deep-dive
  sources   Render the self-documentation view: what this skill probes
            (Always-on / Declared / Default paths / Fallbacks) and what it
            found in the current project. Mutex with depth tiers and `setup`.
  setup     Add the `## Project Map` section to your `<instructions-file>`, or
            update it if it's already there. Future briefings then read
            your tracker, roadmap, changelog, and other locations from
            `<instructions-file>` directly instead of guessing.

            Setup mode reads what's already in your project, fills in
            each field where it can detect a value, marks the rest with
            `<placeholder>`, and shows you the proposed section. Nothing
            is written until you say yes. Before writing, it copies your
            `<instructions-file>` to `<instructions-file>.before-briefing-setup.bak` so you can
            restore the original.

            Can't be combined with depth tiers, `sources`, or `save`.
  save      Write the output to disk.                       default: off
            (synonyms: --save, export)
  help      Show this synopsis instead of running.          default: off
            (synonyms: ?, usage, --help, -h)

Examples:
  /briefing                    # adaptive default-mode briefing
  /briefing quick              # quick tier
  /briefing deep save          # deep tier, written to disk
  /briefing sources            # self-documentation view
  /briefing sources save       # self-documentation view, written to disk
  /briefing setup              # add or update `## Project Map` in <instructions-file>
```

Order of args does not matter. `/briefing deep save` and `/briefing save deep` are equivalent. If any help keyword (the full set is listed under **How to parse the args** below — `help`, `--help`, `-h`, `?`, `usage`) appears anywhere in the args, the skill renders this Synopsis as the response and stops — no briefing, no save.

The depth default is **adaptive**: when no depth keyword is provided, the briefing's length is content-driven — sections appear or disappear based on what the project state actually contains. `quick`, `standard`, and `deep` are explicit overrides for fixed-length tiers; "no dial" is its own behaviour, not a synonym for `standard`.

## Platform tool mappings

When executing the instructions in this skill (reading files, executing commands, creating files, asking user questions), use the appropriate tool for your active runtime:

| Action | Claude Code | Antigravity CLI (`agy`) | Cursor CLI | Codex | Kimi Code | Grok |
|---|---|---|---|---|---|---|
| **Read file** | `Read` | `view_file` | Native view / `cat` | `shell` (e.g. `cat`) | `Read` | `read_file` |
| **Write/Create file** | `Write` | `write_to_file` | Native edit | `apply_patch` / `shell` | `Write` | `write` |
| **Edit file** | `Edit` | `replace_file_content` | Native edit | `apply_patch` | `Edit` | `search_replace` |
| **Run command** | `Bash` | `run_command` | Native terminal | `shell` | `Bash` | `run_terminal_command` |
| **Search files** | `Grep` | `grep_search` | Native search | `shell` (e.g. `grep`) | `Grep` | `grep` |
| **Ask user** | `AskUserQuestion` | `ask_question` | Native input | `request_user_input` | `AskUserQuestion` | `ask_user_question` |
| **Dispatch subagent** | `Agent` | `invoke_subagent` | Native agent | `spawn_agent` | `Agent` | `spawn_subagent` |

## Instructions file resolution

To support multiple platforms and harnesses, the briefing skill abstracts the project instructions file (e.g., `CLAUDE.md` or `AGENTS.md`) as `<instructions-file>`. When reading or writing this file, resolve the path using these rules:

- **Active Runtime Defaults:**
  - On Claude Code, default to `CLAUDE.md`.
  - On agy, Cursor, Codex, Kimi, and Grok, default to `AGENTS.md`.
- **Existing Files Check:**
  - If only one file exists, use it.
  - If both exist, use the active runtime's default.
  - If neither exists, default to `CLAUDE.md` under Claude Code, and `AGENTS.md` under others.
- **Symlink / Pointer Resolution:**
  - If a project contains `AGENTS.md` pointing to `CLAUDE.md` (or vice-versa) or a symlink exists, resolve the target. To preserve the symlink itself and avoid overwriting it, all setup writes/edits must be written directly to the resolved target file (e.g., `CLAUDE.md`) rather than replacing the symlink path.
- **Backup File:**
  - The backup file is always `<instructions-file>.before-briefing-setup.bak`.

## How to parse the args

Walk the tokens once and bucket each one:

- **Mode keywords** (closed set): `sources`, `setup`. Default mode is briefing.
- **Depth keywords** (closed set): `quick`, `peek`, `standard`, `deep`, `deep-dive`. Default: adaptive (no override) if no depth keyword is present.
- **Save keywords** (closed set): `save`, `--save`, `export`. Default off.
- **Help keywords** (closed set): `help`, `--help`, `-h`, `?`, `usage`. If any appear, **short-circuit**: render the Synopsis above and stop.
- **Anything else**: respond with `unknown arg <X> — try /briefing help` and stop.

The parser is order-independent and case-insensitive. Two of the same bucket is an error of intent — pick the **rightmost** occurrence and surface the override via the depth-conflict bullet in the `★ About this briefing` block (see **About this briefing** section below). The bullet text follows the pattern `Depth received both '<X>' and '<Y>'; using '<Y>'`.

**Mutex rule — modes vs depth tiers:** when any mode keyword (`sources` or `setup`) is present AND a depth keyword is present, render the mode's view; the depth keyword is ignored. Surface the conflict via bullet 6 of `★ About this briefing` inside the mode's view: `Depth ignored when '<mode>' mode is active`.

**Mutex rule — modes are mutually exclusive:** when both `sources` and `setup` are present, that's an error of intent. Render `Cannot combine 'sources' and 'setup' modes — pick one.` and stop.

**Save compatibility:**
- `sources` + `save`: compatible (writes the sources view to `briefing-log/<TS>-sources.md`).
- `setup` + `save`: not compatible — setup mode's output is interactive (proposal + confirmation prompt), not a static document. Surface as bullet 6 of `★ About this briefing` inside the setup view: `Save ignored when 'setup' mode is active`. Proceed with setup.

## Source layering

The briefing reads from four layers, each with a clear failure mode. The same names are used throughout this spec and in user-facing output (e.g. `/briefing sources`) — no separate vocabulary.

| Layer | What it does | Fails when… |
|---|---|---|
| **Always-on — universal mechanics** | Probes git, GitHub, top-level files, per-project memory. Knows nothing about specific conventions. | The project isn't a git repo (skip git/gh; fall back to file discovery only). |
| **Declared — explicit declarations** | Reads `## Project Map` from `<instructions-file>`. Declared fields are authoritative. | The section is absent (skip Declared entirely; rely on Default paths). |
| **Default paths — convention sniffing** | Probes for canonical-conventions signatures (`docs/0-brainstorms/`, `docs/ROADMAP.md`, status frontmatter, ROADMAP section names). Fills in any field Declared didn't specify. | The project doesn't follow the canonical conventions (skip the lit-up behaviour; degrade to Always-on-only output). |
| **Fallbacks — graceful degradation** | Standing instructions for every failure mode. Names every gap in the output; never fabricates. | (Fallbacks is itself the failure-handling layer; it doesn't fail.) |

**Precedence and ordering:** Always-on runs unconditionally. Declared takes precedence over Default paths — read Declared if `## Project Map` is present in `<instructions-file>`. Default paths fills any field Declared didn't specify. Fallbacks applies to any source that fails along the way.

### Always-on — universal mechanics

These sources run unconditionally, with no project configuration required and no convention assumed. Probe each one in order; if a step fails, apply the matching Fallbacks instruction and continue.

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
> If the fetch fails (network down, no remote, auth error), continue
> with stale refs and surface the failure in the footer — see Fallbacks.

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

If `gh` is missing or unauthenticated, skip these and note the gap in the footer (Fallbacks).

**Top-level docs (well-known by name, not a convention):**

```bash
ls -l README.md <instructions-file> 2>/dev/null   # mtimes for staleness check
```

These files are typically already loaded in the conversation context; the recheck is for noticing recent edits, not for re-reading content unless mtimes suggest staleness. They are universal open-source-convention files, not project-specific — that's why they live in Always-on.

**Per-project memory:**

AI runtimes store per-project state or context under specific directories. For example, Claude Code uses a path slug (leading `/` becomes `-`, and every other `/` also becomes `-`) so `/Users/me/Projects/foo` lives at `~/.claude/projects/-Users-me-Projects-foo/`. Other runtimes use similar directory conventions.

Probe the following locations for project memory:

```bash
slug="$(pwd | sed 's|/|-|g')"               # /a/b/c → -a-b-c

# Probe Claude Code memory index
ls -l "$HOME/.claude/projects/$slug/memory/MEMORY.md" 2>/dev/null

# Probe Antigravity CLI (agy) memory index (using either default or -cli paths)
ls -l "$HOME/.gemini/antigravity/brain/projects/$slug/memory/MEMORY.md" 2>/dev/null
ls -l "$HOME/.gemini/antigravity-cli/brain/projects/$slug/memory/MEMORY.md" 2>/dev/null

# Probe Codex memory index
ls -l "$HOME/.codex/projects/$slug/memory/MEMORY.md" 2>/dev/null

# Kimi Code has no per-project memory index — nothing to probe
# Grok Build TUI has no per-project memory index — nothing to probe
```

If the index file exists in the active runtime's path (some users maintain one via an auto-memory system), read it for cross-session continuity notes. If not, skip silently — many projects do not maintain one. This is a runtime-specific mechanic, not a project convention, so it lives in Always-on.

### Declared — explicit declarations via <instructions-file>

Read the `## Project Map` section from `<instructions-file>` (already in your context). Each line is `- **Field**: value`. Recognised fields:

- **Tracker** — where work items live (e.g. `GitHub Issues`, `Linear team FOO`, `Jira project BAR`, `Notion`, `GitHub Project N`, file path, or `none`).
- **Board** — URL of the active board / project view.
- **Roadmap** — file path or external URL of the forward view.
- **Changelog** — file path or external URL of recent shipped work.
- **Architecture** — file path or directory of architecture docs.
- **Working memory** — directory holding the lifecycle artifacts (e.g. `docs/`).
- **Other** — free-form bullet list for project-specific context.

Declared fields are **authoritative** — they override any Default paths sniffing. A field set to `none` means "deliberately empty" (do not probe further); an absent field means "Default paths can probe a default" (see Default paths table below).

For complete examples (canonical + non-canonical project layouts), per-field decision guidance, and discovery hints (how to figure out what to put in each field), see [§5.8 of the canonical conventions guide](<CANONICAL_CONVENTIONS_URL>#58--project-map-section-in-claudemd).

Presence check: grep **case-insensitively** for `^## Project Map` OR the deprecated `^## Project Context` in the project's `<instructions-file>`. The canonical form is `## Project Map` (Title Case). Tolerate two earlier names for backward compatibility:

- `## Project Context` (Title Case) — the canonical name before the 2026-05-07 rename to Map.
- `## Project context` (sentence case) — the original canonical name before the 2026-05-07 Title Case rename.

The probe matches all variants:

```bash
grep -i -E '^## Project (Map|Context)' <instructions-file>
```

If absent, skip the Declared read entirely and proceed to Default paths. When a deprecated variant matches, Declared still reads the section as authoritative; the deprecation does not affect parsing. `/briefing setup` proposes a header rename to the canonical form when run on a project with a deprecated section name (see **Existing `## Project Map`** below).

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

### Default paths — convention sniffing

For each "what's the project's structure?" question that Declared did not declare, probe for canonical-conventions signatures. The canonical conventions are documented at `<CANONICAL_CONVENTIONS_URL>`; this skill is *aware* of them but not *coupled* to them — when none of the signatures match, the skill degrades gracefully to Always-on-only output.

| Question | If Declared specified it | Else, Default paths probe order | Fallback (no match) |
|---|---|---|---|
| Where's the roadmap? | Use `Roadmap` field | `docs/ROADMAP.md` (canonical) → `ROADMAP.md` (root) | Note in footer; skip roadmap section |
| Where's the changelog? | Use `Changelog` field | `docs/CHANGELOG.md` (canonical) → `CHANGELOG.md` (root) | Note in footer; skip changelog references |
| Where are lifecycle artifacts? | Use `Working memory` field | If `docs/0-brainstorms/`, `docs/2-design/`, `docs/3-plans/` all exist → canonical layout (lifecycle dirs are `docs/[0-9]-*` plus `docs/adrs/`). Else if any `docs/*/*.md` has `status:` frontmatter → use those dirs as discovered working memory. | Note in footer; skip lifecycle drafts in output |
| What `status:` values mean "in flight"? | (not declared) | If canonical layout detected: `draft`, `open`, `approved`. | Any `status:` not in `{shipped, superseded, abandoned, closed, done, resolved}` — including `active`, which reads terminal but isn't. Split those on `type:` per [Statuses that look terminal but aren't](#statuses-that-look-terminal-but-arent) |
| Which ROADMAP section means "in flight"? | (not declared) | If canonical detected: `## In flight` (per §6.3 of the canonical guide). | Case-insensitive match for headings containing `in flight`, `in progress`, `now`, `doing`, `wip` |
| Where are ADRs? | (not declared) | `docs/adrs/NNNN-*.md` (canonical) → `docs/6-adrs/`, `docs/architecture/decisions/`, `decisions/`, `adr/` | Not surfaced |

When probing the lifecycle for-loop, prefer the canonical glob if detected; otherwise list what was actually found:

```bash
# Canonical-conventions glob (used when Default paths detects the canonical layout).
# Emits "status|type|path" so the type-based split can happen in one pass —
# reading status alone can't tell an open review from a current brand guide.
for d in docs/[0-9]-* docs/adrs; do
  [ -d "$d" ] || continue
  find "$d" -maxdepth 1 -name '*.md' 2>/dev/null | while read -r f; do
    st=$(awk 'NR<=15 && /^status:/ {sub(/^status:[[:space:]]*/,""); print; exit}' "$f")
    ty=$(awk 'NR<=15 && /^type:/   {sub(/^type:[[:space:]]*/,"");   print; exit}' "$f")
    [ -n "$st" ] && echo "$st|${ty:-untyped}|$f"
  done
done | sort
```

In a multi-repo workspace, run this per repo — a workspace root that gitignores its subdirectories holds no working memory of its own, and the drafts all live one level down.

The glob `docs/[0-9]-*` covers the canonical numbered prefixes (`0-brainstorms`, `1-discovery`, `2-design`, `3-plans`, `4-reviews`) and any project-specific extensions (e.g. `5-guides`, `6-adrs` in some sister repos). `docs/adrs` is also probed because the canonical convention places ADRs there without a number prefix.

**zsh portability note:** if you write a follow-up command that extracts the `status:` value into a shell variable, **do not name the variable `status`** — it's read-only in zsh (it holds the last command's exit code). Use `st`, `state`, or similar instead. The canonical block above is safe because it uses `grep -l '^status:'` (file listing only); the trap is in ad-hoc rewrites that read the value.

#### Statuses that look terminal but aren't

`active`, `current`, `living` and similar words read like "settled" but are not in the terminal set, so they count as unresolved. In practice projects use them for two different things, and the discriminator is the doc's `type`, not its status:

- **Lifecycle artifacts** — `review`, `design`, `plan`, `brainstorm`, `handoff`, `note`, `research`. An `active` review is an open review. These belong in the inventory.
- **Evergreen docs** — `guide`, `reference`, `policy`, `architecture`, `template`, or no `type` at all. `active` here means "current and in use", not "in progress". A brand guide is never going to be finished.

Read both `status:` and `type:` in the same pass, and split on `type`. **Excluding the evergreen ones is correct; excluding them silently is not.** State the filter and its count in one line under the table — "5 evergreen prompts and guides excluded" — so the reader can audit the judgement instead of trusting it.

Two contradictions worth flagging when you see them, because they mean a status is stale rather than meaningful:

- A `resolution:`, `outcome:` or `superseded_by:` field present while the status is still non-terminal.
- A doc whose subject was decided elsewhere — an A/B comparison whose winner is already locked in the project's instructions file.

#### Prose-inference fallback

When Declared is absent (no `## Project Map` section in `<instructions-file>`, even after case-insensitive probe) AND Default paths's primary canonical-path probe finds nothing for a given field, attempt a soft prose scan of `<instructions-file>` and `README.md` as a last-resort fallback before declaring the field "not found".

Per-field inference rules (only the fields with high signal-to-noise; others stay "not found"):

| Field | Inference rule |
|---|---|
| **Roadmap** | Case-insensitive scan for markdown links to files matching `*roadmap*.md` (e.g. `[ROADMAP](docs/ROADMAP.md)`, `see [our roadmap](roadmap.md)`). One match → use it. Multiple → prefer the one in `<instructions-file>` over README.md (`<instructions-file>` is more authoritative). Zero or ambiguous → fall through to "not found". |
| **Changelog** | Same pattern, matching `*changelog*.md`. |
| **Architecture** | Same pattern, matching `*architecture*.md` or `*arch*.md`. |
| **Tracker** | Scan for explicit prose mentions of `GitHub Issues` (with capital G/I), `Linear team <name>`, `Jira project <name>`, `Notion`. Single explicit mention → infer that tracker; multiple distinct trackers mentioned → don't infer (real ambiguity), fall through to "not found". |

**Skipped fields** (not worth the inference complexity):

- `Board` — URL-based, low signal-to-noise.
- `Working memory` — directory inference is hard to do precisely; the user's project layout is rarely described in prose.
- `Other` — by definition unstructured; nothing to infer.

**Surfacing inferred values:**

- In default-mode briefing: inferred fields render the same as declared/canonical-detected fields, but with an `(inferred)` suffix in the snapshot bullet, e.g. `**Roadmap:** docs/ROADMAP.md (inferred from <instructions-file>) — 3 in flight, 5 next-action queued`.
- In `/briefing sources` "What was read in this project": inferred fields appear in a new line `**Inferred from prose:** <field>=<path> (<instructions-file>), ...` between `Default paths matched:` and `Not found:`.
- The `★ About this briefing` block is unchanged — inference doesn't fire any bullet by itself.

**No writes from inference.** Inferred values stay inferred. To make them authoritative, the user runs `/briefing setup`, which proposes the inferred values as detected starting points for the `## Project Map` section. Setup mode's detection rules use the same prose-inference logic.

### Convention-maturity check

This check is invoked specifically by the `/briefing sources` mode (and used to drive bullet 2 of `★ About this briefing` when applicable — see **About this briefing**). It is **not** rendered in default-mode briefings. Tally which canonical-conventions signatures are present vs missing.

| # | Signature | How to check |
|---|---|---|
| 1 | `## Project Map` section in `<instructions-file>` | `grep -i -E '^## Project (Map&#124;Context)' <instructions-file>` (case-insensitive — tolerates the deprecated `## Project Context` name and lowercase variants) |
| 2 | `docs/ROADMAP.md` exists | filesystem probe |
| 3 | `docs/CHANGELOG.md` exists | filesystem probe |
| 4 | Lifecycle dirs present (`docs/0-brainstorms/`, `docs/2-design/`, `docs/3-plans/` at minimum) | filesystem probe; require all three |
| 5 | Status frontmatter used in lifecycle artifacts | `grep -l '^status:' docs/*/*.md` returns ≥ 1 |
| 6 | ROADMAP uses canonical sections (`## In flight`, `## Next actions`, `## Recently shipped` at minimum) | grep on roadmap; require all three |
| 7 | ADRs at `docs/adrs/NNNN-*.md` | filesystem probe with name pattern |

The 7-signature tally feeds two outputs:

- **`/briefing sources` view** — populates the "What was read in this project" / "Not found" rows (see **`/briefing sources` mode** section).
- **Default-mode bullet 2** — when no canonical signatures hit and no `## Project Map` was declared, render bullet 2 of `★ About this briefing` (`Briefing relied on git/gh only — /briefing sources to see what else this skill can read.`).

Read-only. Descriptive, not prescriptive.

### Fallbacks — graceful degradation

Standing instructions for when a source fails. Never fabricate; always name the gap.

| Failure mode | Behaviour |
|---|---|
| Not in a git repo | Skip git/gh entirely; fall back to file discovery only |
| Git repo, no remote | Skip `git fetch` and `gh` queries; report local state only |
| `gh` missing or unauthed | Skip GitHub queries; render `★ About this briefing` bullet 4 (`GitHub queries skipped (gh not authenticated)` or `(gh not installed)`) |
| `git fetch` slow / network down | Use stale refs; render `★ About this briefing` bullet 3 (`Refs from last fetch <relative-date>`) |
| `git fetch` fails with auth error on a configured remote | Use stale refs; render `★ About this briefing` bullet 3 variant (`Fetch failed (auth) — refs may be stale; check credentials`) |
| Declared absent + Default paths detected nothing | Run Always-on only; render `★ About this briefing` bullet 2 (`Briefing relied on git/gh only — /briefing sources to see what else this skill can read.`) |
| Declared absent + Default paths partial | Stay quiet in default-mode output. User can run `/briefing sources` to see what was found. |
| Declared Declared source unreachable (auth-walled, missing CLI/MCP) | Render `★ About this briefing` bullet 1 (`Some sources unavailable — /briefing sources for details.`) or, when the unreachable source is specifically a tracker integration, bullet 5 (`<Tracker> declared but <CLI> not available — install or configure MCP`) |
| Working memory not found at any Default paths path | If a path was declared via `## Project Map` and failed → bullet 1. Otherwise stay quiet. |
| Diff over per-file cap (200 lines) | Summarise rather than dump |
| Detached HEAD | Render `★ About this briefing` bullet 7 (`On detached HEAD; reporting against nearest branch <X>`) |
| Empty repo / no `docs/` | Produce a minimal briefing; do not invent suggestions |
| Untracked file matches secret pattern (`.env*`, `*.pem`, `*.key`, `id_rsa*`, `credentials*`) | Skip silently — never read |

## In-flight detection

What triggers the briefing's adaptive output to lead with active work. Universal signals at the top, conventions-resolved signals below.

| Signal | Strength | Source / notes |
|---|---|---|
| Open PR authored by me | Strong | from Always-on `gh pr list --author @me --state open` |
| Unpushed commits on current branch | Strong | from Always-on `git rev-list --count @{upstream}..HEAD`; covers "branch ahead of upstream" |
| Unpushed commits on *other* local branches | Strong | from Always-on `git for-each-ref` + ahead counts |
| Stashes | Strong | from Always-on `git stash list`; the most-forgotten state in git |
| Working tree dirty (uncommitted edits) | Strong | from Always-on `git status --porcelain`; read content of changed files (200-line cap) |
| Tracker items in "in progress" status | Strong | from Declared tracker integration; only if a tracker is declared |
| ROADMAP "in-flight section" non-empty | Strong | from the resolved roadmap path + in-flight section regex (via Default paths) |
| Lifecycle artifacts with in-flight status | Strong | from the resolved working-memory dirs + in-flight status set (via Default paths) |
| Local-only branches (no upstream) | Medium | from Always-on `git branch -vv` filter |
| Worktrees (count > 1) | Medium | from Always-on `git worktree list` |
| Recent commits in last 24h | Weak | from Always-on `git log --since=1.day`; orientation only, never leads |

**Detection rule:** if any signal labelled **Strong** in the table above is present, **Summary** opens on the stopped work and **Status** leads with the in-flight threads. Otherwise **Summary** opens on what last shipped and what's next. Don't sum or score — any single Strong-labelled signal is enough to flip the lead. Medium-labelled signals never trigger the lead but are reported under **Status**. Weak-labelled signals never lead and feed the Recently shipped table only.

The table's row order is the order the resulting bullets should be reported in, not a priority ranking — Strong-labelled signals are equally sufficient to trigger the lead.

**Strong/Medium/Weak are internal classification only.** Never echo them in the rendered briefing — bullets describe their own subject ("Working tree dirty", "Open PRs", "Stashes"), not their detection strength.

(The output sections themselves are defined under **Output template** below.)

## Output template

The default-mode briefing is a decision brief: a header line, **Summary**, **Status**, **Findings**, and **Recommendations and next steps** as the closing section, plus the conditional `★ About this briefing` footer. Summary and the closing section always run; Status and Findings omit when they have nothing to say. Explicit depth keywords reshape this contract — `standard` forces all four, `quick` collapses, `deep` extends — and are codified under **Depth contract** below.

The briefing is a **navigation aid, not a report**. Someone returning after a week should be able to scan it in thirty seconds, understand where things stand, and find every action in one place at the end. Five rules make that work, and they bind every section:

1. **Scannable structure over prose.** Tables for anything enumerable — files, commits, drafts, repo states. One-line bullets otherwise. No paragraph over three lines, and never a wall of prose where a table would do.
2. **Decode every identifier on first use.** A briefing that says "S7 needs a ruling" is useless — the reader has to go open a file to learn what S7 *is*. Say what it is in plain words, then cite the code: "the homepage strip repeats itself one screen apart (S7)". Same for flags, ticket keys, task IDs, and internal shorthand. If you can't say what it is without opening the file, open the file.
3. **Every path is clickable.** Write file references as paths from the working directory — `website/.docs/plans/2026-08-04-launch.md`, never the bare basename `2026-08-04-launch.md`. Add `:line` when pointing at one specific item inside a long file. A reference the reader can't click is a chore, not a citation.
4. **The funnel.** Actionable content lives in exactly two places: Summary's "what's needed" clause (as a pointer) and **Recommendations and next steps** (as the ask). Status and Findings are read-only context — no `→` lines, no outstanding-steps checklists, no to-do bullets anywhere else.
5. **No silent drops.** Collapsing a group is allowed — parked drafts, stale branches, quiet repos — but the collapse is counted, named, and carries its escape hatch ("6 parked brainstorms — `/briefing deep` for the full list"). What the reader must be able to audit is the judgement, not every row.

Headers are plain (`## Summary`, not `# 1 · …`). Four sections don't need navigation handles; follow-up conversation can name them.

> **Spec annotations:** the `←` comments in the template below (e.g. `← always`, `← omit when empty`) are *spec annotations* explaining when each section renders — they must NOT appear in the actual briefing the user sees.

```markdown
# Briefing — <project name>
<date> · <branch> · <ahead/behind or clean> · <repo count if multi-repo>

## Summary                                        ← always
<2–3 sentences: what you were doing, where it stands, and what — if anything —
is needed from you. When nothing is needed, say so: "nothing waiting on you".>

## Status                                         ← omit when empty
**In flight** — <one dense line per thread: vehicle, age, size, CI/review state>
**Plan progress:** <X done, Y left, one clause on where the remainder lives>

**Uncommitted in `<repo>/` — <what these files have in common>:**   ← only if the working tree is dirty
| File | Change |
|---|---|
| `<path/from/cwd.ext>` | <one line; note staged deletes won't open> |

**Recently shipped**
| Commit | Change |
|---|---|
| `<sha>` | <one line> |

<How it was verified, one line.>

**Quiet** — <one line naming what's clean and in sync>
<Other local-only state as one-line bullets: other branches, stashes, worktrees.>

## Findings                                       ← omit when empty
<Read-only things worth knowing, tables where enumerable. Risks and blockers as
facts, stale statuses, structural gaps, stale work to triage.>

**Draft inventory** — <actionable unresolved docs>
| Doc | Status | Waiting on |
|---|---|---|
| `<path/from/cwd.md>` | <the project's own status value> | <one line> |

<Collapsed groups, counted and named: "6 parked brainstorms, 3 stale drafts —
/briefing deep for the full list". State every filter with its count.>

## Recommendations and next steps                 ← always
<A short paragraph: the recommended direction — what to do first and why, and
how the signals below shaped the order. The judgement lives here, not in the
items. When nothing waits, say so and point at the top of the roadmap.>

1. **<Signal>** — <Action item, imperative> — <steering: why this priority,
   what to watch, a suggestion where useful> · <clickable path>
2. Decide: <question> — <the options, with a lean where the evidence supports one>

<The list is numbered (1., 2., 3., …), not bulleted: the reader replies by
number ("do 1 and 3"), so the numbers must be stable within one briefing.
Priority order — item 1 is the recommended first move, and the order is
derived from the signals, not vibes.>

<Signal tags — a closed set, bold, leading the item, at most one per item.
Most items carry no tag; a tag is a claim the steering line must back up.
- **Urgent** — time-sensitive: stale state going staler, a live PR or branch
  at risk, a window that closes.
- **Quick win** — minutes of effort, real value, nothing waits on it.
  Quick wins go early only when they're nearly free — never ahead of an
  urgent item.
- **Blocking** — other queued work can't start until this lands; name what
  it blocks in the steering line.>

[★ About this briefing — conditional, see About this briefing section below]
[Optional: Saved to <path>]
```

### Output isolation

The default-mode briefing's output is the template above plus the conditional `★ About this briefing` block — nothing else. **Don't append response-style wrappers** that the model would normally add in a general task: no separate `## Open decisions` block, no extra `★ Insight` block, no free-form "what's next" paragraph outside the briefing's own closing section. The briefing's own structure (Summary / Status / Findings / Recommendations and next steps / `★ About this briefing`) covers everything a wrapper would. The skill output IS the response.

When the user's `<instructions-file>` or another global rule mandates a closing-block format (e.g. `## Open decisions` for blocking questions), that rule applies to general conversational replies — not to skill output. Skill specs override conversational defaults for their own scope.

### Section-by-section rules

**Summary:** Always present. Two to three sentences: what was being worked on, where it stands, and what is needed from the reader. If everything else got cut, these sentences alone should still be useful. The needed-clause is a pointer, not the ask — "three decisions wait on the model-seam brainstorm", not the decisions themselves. When nothing is needed, say so plainly; never manufacture an action.

**Status:** The facts of motion. When any Strong-strength signal fired, lead with the in-flight threads — the vehicle carrying the work (PR, branch, tracker item) on one dense line: age, size, CI state, review state. Plan progress renders as a counts line ("159 done, 16 left, all in Task 7") — the remaining steps are the plan file's job, and any that need the reader funnel to the close. If the working tree is dirty, render the uncommitted files as a table with a lead-in that says **what they have in common** ("one logical change", "two unrelated fixes"); note staged deletions inline, since those paths won't open; summarise diffs per the 200-line cap. Recently shipped is a commit table — synthesised, not dumped: group by theme, stop at the last 3–5 meaningful things, one line on verification when the project records it. The Quiet line names what's clean and in sync, so silence is stated rather than inferred. Other local-only state (branches, stashes, worktrees) is one-line bullets here. Group by what things are, **not** by Strong/Medium/Weak — those labels are internal classification and must never appear in the rendered briefing. Use the project's own vocabulary for its roadmap sections and status values.

**Findings:** Everything worth knowing that is not itself an action. Risks and blockers render as facts ("Task 7's remaining items all write to a live repository; neither review gate has been reached") — the response to them, if one is needed, is a bullet in the close. Stale frontmatter statuses get flagged inline, not silently corrected — a design whose plan shipped while it still says `approved` is the project's bookkeeping to fix, not the briefing's. Structural gaps, stale work to triage (old PRs, ancient stashes, forgotten branches), risky operations needed, and conventions worth a later decision land here as bullets. **Not for:** suggestions about adopting `## Project Map`, canonical conventions, or anything else about enriching future briefings — that's setup content, and it lives exclusively in `★ About this briefing` bullet 2 and the `/briefing sources` view.

**Findings — the draft inventory, and the collapse rule.** An unresolved doc is **actionable** when any of these hold: (1) it is referenced from the roadmap's in-flight or next-actions sections; (2) it was modified within the last 30 days; (3) it carries an explicit question or decision for the reader. Actionable docs render as table rows with the project's own status vocabulary (`draft`, `open`, `wip`, `ready-for-review`, `active`), never a normalised one, plus a one-line "waiting on". Everything else collapses into grouped count lines that name the groups and carry the escape hatch — "6 parked brainstorms, 3 June drafts — `/briefing deep` for the full list". Statuses like `active` count as unresolved, and evergreen docs (`guide`, `reference`, `policy`, `template`, or no type) stay excluded under the `type`-based split in [Statuses that look terminal but aren't](#statuses-that-look-terminal-but-arent), with the count stated. Every filter and every collapse states its count — an unstated exclusion and an accidental omission look identical from the reader's side. `/briefing deep` renders every unresolved row, no collapse.

**Recommendations and next steps:** Always present. This section is advisory, not a dump — it steers, it doesn't just list. Open with a short paragraph stating the recommended direction: what to do first, why, and how the signal tags shaped the order. Then a numbered list in priority order (`1.`, `2.`, `3.`, …): an imperative action, one line of steering (why this priority, what to watch, a suggestion where useful), and a clickable path. The list is numbered so the reader can reply by number ("do 1 and 3") — keep the numbers stable within one briefing. Items that earn it carry one bold signal tag up front — **Urgent** (time-sensitive, something going stale or a window closing), **Quick win** (minutes of effort, real value, nothing depends on it), **Blocking** (name what it unblocks) — and the priority order is derived from those signals: urgent first, then blocking, quick wins early when nearly free, everything else by judged value. Most items carry no tag; a tag is a claim the steering line must back up. Decisions render as `Decide:` items naming the options, with a lean where the evidence supports one; rule 2 binds hardest here, because a decision the reader can't understand is a decision they can't make. This section is the only place the ask lives — when genuinely nothing waits, the paragraph says so and the single numbered item points at the roadmap's top item. Don't pad it.

The **`★ About this briefing` block** is conditional — it renders only when at least one bullet has content (see **About this briefing** below for the bullet inventory and trigger rules). When no bullet applies, the block omits entirely and the briefing ends with whatever section ran last. The `[Optional: Saved to <path>]` line appears only when `save` was passed; the actual save path and write semantics are defined under **Save behaviour** below. Depth-override notes from the parser surface as bullet 6 inside `★ About this briefing` (text: `Depth received both '<X>' and '<Y>'; using '<Y>'`).

## About this briefing — conditional footer block

A short footer block that renders only when at least one bullet has content; omits entirely when no bullets apply (the typical healthy-project case).

Visual format — wrap the header and footer rule lines in backticks so they render as monospace inline code, matching the visual style of Claude Code's `★ Insight` blocks. Bullets between the rules are a tight list (no blank lines between siblings); the monospace rules act as bookends and give the block visual scope without needing inter-bullet padding. Bullets that have both an *observation* and a *context/action* use a **bold parent bullet for the observation plus an indented sub-bullet for the context/action**, so each bullet reads as two beats with a clear visual hierarchy. Short single-clause bullets stay on one line with bold on the observation phrase. When a bullet has *two distinct action options* (sources vs setup), render two indented sub-bullets — one per option — each as `` **`/<command>`** — <brief reason> `` so each command stands alone visually rather than getting buried in a "run X or Y" sentence.

Rendered shape (the literal markdown the model emits):

```
`★ About this briefing ─────────────────────────`
- **<observation>**
  - <context or action>
- **<short single-clause bullet>**
- **<observation>**
  - <context or action>
- **<observation>** — <inline cause>
  - **`<command-1>`** — <reason>
  - **`<command-2>`** — <reason>
`─────────────────────────────────────────────────`
```

The model emits the backticks around the rule lines (terminal renders them as monospace; the backticks themselves are hidden, just like in `★ Insight`). The sub-bullet pattern (`-` parent, indented `-` child) renders as parent + nested-child in any markdown renderer — both markers are dashes (consistent), and the indent gives the visual two-beat structure. Earlier iterations tried `<br>` (stripped by the terminal renderer) and a leading em-dash on a hard-line-break continuation (the renderer interpreted line-leading `—` as a list marker, producing inconsistent `-` and `—` siblings); sub-bullets are the renderer-native solution.

### Bullet inventory

Each bullet renders only when its trigger fires. Block omits when zero bullets apply. Bullets that have both an observation and a context/action use a bold parent bullet plus an indented sub-bullet (shown in fenced code blocks below). Single-clause bullets get inline bold on the observation phrase.

1. **Some sources unavailable** — fires when a declared or default-path source didn't resolve. Render:

   ```
   - **Some sources unavailable.**
     - **`/briefing sources`** — see details
   ```

2. **Briefing relied on git/gh only** — fires when neither declared nor default-path sources hit. Render:

   ```
   - **Briefing relied on git/gh only** — no `## Project Map` declared.
     - **`/briefing sources`** — see what else this skill could read
     - **`/briefing setup`** — declare paths in <instructions-file>
   ```

   Multi-action exception: bullet 2 is the only inventory entry that renders **two indented sub-bullets** (one per command — `sources` and `setup`). All other bullets render at most one sub-bullet per the standard observation/sub-bullet pattern.

3. **Stale or failed fetch** — render `- **Refs from last fetch <relative-date>**` (single line) OR, for the auth-failure variant:

   ```
   - **Fetch failed (auth).**
     - Refs may be stale; check credentials.
   ```

4. **GitHub unavailable** — render: `- **GitHub queries skipped** (gh not authenticated)` or `- **GitHub queries skipped** (gh not installed)`. (Single line — bold the observation, parens for context.)
5. **Tracker integration unavailable** — render:

   ```
   - **`<Tracker>` declared but `<CLI>` not available.**
     - Install or configure MCP.
   ```

6. **Depth or save conflict** — render one of: `- **Depth received both '<X>' and '<Y>'**; using '<Y>'`, `- **Depth ignored when '<sources|setup>' mode is active**`, OR `- **Save ignored when 'setup' mode is active**`. (Single line.)
7. **Detached HEAD** — render: `- **On detached HEAD**; reporting against nearest branch <X>`. (Single line.)

### Bullet priority

When more than one bullet would render, prefer the more specific signal:

- Bullet 1 (some sources unavailable) supersedes bullet 2 (briefing relied on git/gh only) when both fire — e.g. a declared path failed to resolve AND no other paths hit either. Bullet 1 names the specific gap; bullet 2 is the broader "shallow render" framing and becomes redundant when bullet 1 already named what failed.
- Bullet 5 (tracker integration unavailable) supersedes bullet 1 when the unavailable source is specifically a tracker integration declared via `## Project Map`. Bullet 5 names the tracker and the missing CLI/MCP; bullet 1 is the generic version.

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
| `quick` | Summary + Recommendations and next steps only | git/gh essentials only (status/log/diff, last PR, last commit) plus the resolved roadmap head if available — ~5–7 reads | < 5s | "Remind me where I am, fast" |
| (adaptive) | Whichever sections have content | full git/gh + declared sources from `## Project Map` + canonical-conventions sniffing | 5–15s | Default |
| `standard` | All four sections, empty ones stated as empty | All adaptive sources, no skipping | 10–20s | Forces full coverage |
| `deep` | All four; the draft inventory renders every unresolved row (no collapse), plus historical context in Status and Findings | Standard + historical sources + cross-source synthesis + per-project memory files | 20–60s | "Real planning session, audit the lot" |

Length is governed by section count and the five rules, not a word budget — a table of twenty drafts is short to *read* however many words it contains. The one rule that never bends across tiers: `quick` may drop whole sections, but it may not drop rows from a section it renders.

**Deep-mode-only sources** (extending the time window beyond "now"):

| Source | Why it earns deep |
|---|---|
| Closed PRs in last 30 days (`gh pr list --state merged --search "merged:>=$(date -u -v-30d +%Y-%m-%d)" --limit 50`) | Trend in shipping cadence; what got merged that **Recently shipped** missed |
| Closed issues in last 30 days (`gh issue list --state closed --search "closed:>=$(date -u -v-30d +%Y-%m-%d)"`) | What got resolved — useful for "is this old issue still relevant?" |
| Stale branches (`git for-each-ref --sort=-committerdate --format='%(refname:short) %(committerdate:relative) %(committerdate:short)' refs/heads/` — filter for `committerdate:short` older than 30 days) | Cleanup signal — branch graveyard surfaces |
| Stale open PRs (open > 14 days) | Forgotten work; different from in-flight because not moving |
| Recent ADRs (last 5 from any declared or detected ADR location) | Architectural context affecting next moves |
| Cross-source synthesis | Recurring themes across 3+ sources flagged as systemic |
| Tracker closed items | If a tracker is declared in `## Project Map`, fetch closed items from last 7 days, not just open |
| Trend analysis on changelog | Velocity / cadence / scope drift across last 5–10 entries (when a changelog was found) |
| Per-project memory files | Read individual files in the resolved per-project memory directory (e.g. `~/.claude/projects/<slug>/memory/` or `~/.gemini/antigravity/brain/projects/<slug>/memory/`) (MEMORY.md index already in context) |

**Not read at any depth:** raw conversation transcripts on disk. Reading them would undermine the working-memory discipline the canonical conventions describe (artifacts become optional if briefings can recover from transcripts), transcripts are noisy (corrections, abandoned approaches, false starts), and the on-disk format is undocumented Anthropic internals. The principled equivalent is a Stop hook with an explicit snapshot schema — deferred (Approach C in the design doc).

## /briefing sources mode

Triggered by passing `sources` as the mode keyword. Can't be combined with depth tiers (`quick`/`standard`/`deep`) — pick one or the other. Compatible with `save`. Produces a self-documentation view of what this skill probes and what it found in the project.

### Output template

Sources mode renders as markdown — H2 title, H3 sub-sections, fenced code blocks for column-aligned data rows, and a closing block that adapts to project state. Section ordering follows probe order (Project State → Project Map → Canonical Structure → Other Layouts Found), so the reader walks the same path the skill walks.

````
## Briefing Sources for <project-name>

A read-only view of every source `/briefing` checks — git/GitHub state, your declared `## Project Map`, canonical-structure signals, and non-default layouts found in the project. Use it to spot gaps; pair with `/briefing setup` to fill them interactively.

### Project State (git + GitHub)

Live universal probes — run in every project.

```
✓ git    <branch · clean/dirty · ahead/behind · stashes · worktrees>
✓ gh     <auth state · PR / issue / CI counts>
```

### Project Map (<state in <instructions-file>>)

Where you tell the skill which paths matter.

```
✓ <field>          <value>                  [optional one-line suffix]
⊘ <field>          declared none
✗ <field>          <one-line gap description, or — if no auto-detection>
```

### Canonical Structure (<state>)

Auto-fills undeclared Map fields when the project follows convention paths.

```
✓ <signal>         <one-line summary>
✗ <signal>         <one-line gap description>
```

### Other Layouts Found

Non-default paths the skill noticed.

```
• <path>            <one-line description>
                    <optional continuation lines>
```

---

**Legend:** ✓ found · ⊘ declared none · ✗ missing · — no auto-detection

**<status line>**

→ **`/briefing setup`**
<reason tailored to state>

*Last synced from the conventions guide: 2026-05-06*
````

### Heading state suffixes

Each H3 heading folds current state into a parenthetical so the reader sees status at scan-time without reading the body.

| Section | State condition | Heading |
|---|---|---|
| Project State | always | `### Project State (git + GitHub)` |
| Project Map | `## Project Map` declared in `<instructions-file>` | `### Project Map (Declared in <instructions-file>)` |
| Project Map | `## Project Map` absent | `### Project Map (No Section Found in <instructions-file>)` |
| Canonical Structure | ≥ 1 signal returns ✓ or ✗ | `### Canonical Structure` |
| Canonical Structure | No signal preconditions met | `### Canonical Structure (Not Detected)` — code block omitted, hint stays |
| Other Layouts Found | ≥ 1 non-canonical artifact found | `### Other Layouts Found` |
| Other Layouts Found | none found | section omitted entirely (no heading, no body) |

The `(git + GitHub)` parenthetical stays lowercase: `git` and `gh`/`GitHub` are tool names with established casing, not Title-Case content words.

### Marker rules

Every data row carries one of three markers, with zone-specific semantics:

| Zone | ✓ means | ⊘ means | ✗ means |
|---|---|---|---|
| **Project State** | Probe ran successfully | (not used — always-on probes have no deliberately-none state) | Probe failed (not a git repo, `gh` missing, `gh` unauthed) |
| **Project Map** | Field has a usable value (declared, detected, or inferred) | Field declared as `none` (deliberate empty) | Field undeclared AND not detected AND not inferred |
| **Canonical Structure** | Default-paths probe found the canonical signature | (not used) | Probe ran (precondition met) but signature not present |

For Project Map fields with no auto-detection mechanism in sources mode (Tracker, Board, Other), `✗` rows render the suffix as `—` rather than a probe-paths list.

`Other Layouts Found` rows use `•` (no status marker) — they are FYI findings, not state indicators.

The legend rendering is unconditional — render every time, even when only one marker type is in use, so users learning the symbols see them defined consistently.

### Adaptive closing

Below the `---` rule: legend, status, CTA, date stamp. The status line summarises Project Map state in plain English; the CTA always points at `/briefing setup` with reason text tailored to state.

| Project Map state | Status line | CTA reason |
|---|---|---|
| All fields ✓ or ⊘ (no ✗) | `**All declared Map fields resolved.**` | `Declare additional sources or fix any ✗ above.` |
| Any ✗ in Project Map zone | `**Project Map has <N> missing field(s).**` | `Probe the project, populate missing fields, write only after you confirm.` |
| `## Project Map` section absent | `` **No `## Project Map` section in <instructions-file>.** `` | `Adds the section interactively. Probes the project, fills detectable fields, writes only after you confirm.` |

The CTA always renders as two lines:

```
→ **`/briefing setup`**
<reason on its own line>
```

The arrow + bold backticked command on their own line is the visual anchor; the reason on the line below stays compact (single sentence).

### Date stamp

The `Last synced from the conventions guide: <YYYY-MM-DD>` stamp is a maintainer-tracked date carried in this `SKILL.md`. It records when the layer descriptions and probe paths in this view were last reconciled against the canonical conventions guide. Format: ISO date (e.g. `2026-05-03`). Update whenever the canonical guide changes in a way that affects this view's content.

### Parser interaction

- **Mutex with depth keywords.** If a user types `/briefing sources deep`, the parser still renders the sources view; bullet 6 of `★ About this briefing` renders inside the sources view's footer with text `Depth ignored when 'sources' mode is active`.
- **Compatible with `save`.** See **Save behaviour** for frontmatter shape.
- **`help` wins.** If `help` is present, render the synopsis and stop (existing rule).

### Tone

The view is descriptive, not prescriptive. The CTA points at `/briefing setup` because that's the dedicated entry point for declaring `## Project Map` — not as a recommendation to adopt canonical conventions. Declared paths are first-class even when non-canonical: a project declaring `decisions/` for ADRs is as resolved as one using `docs/adrs/`. Never imply canonical conventions are preferred over declared paths.

Section hints (one line under each heading) describe the section's *purpose*, not its contents (the rows do that). They orient first-time readers without lecturing returning ones.

### Output isolation

`/briefing sources` is a self-contained view. The output is *exactly* the template above (with the conditional `### Other Layouts Found` section rendered when artifacts are present, and the `### Canonical Structure` body omitted when no signal preconditions are met) — nothing else. Don't include:

- **Default-mode briefing sections** — Summary, Status, Findings, Recommendations and next steps. Those belong to `/briefing` (default mode), not sources mode. The user has explicitly asked for the self-documentation view; don't bolt the orientation view on top.
- **`★ About this briefing` bullets other than bullet 6 (depth conflict).** Bullet 2 ("Briefing relied on git/gh only — `/briefing sources` to see what else this skill can read") is *circular* when the user is already in sources mode — suppress it. Bullets 1, 3, 4, 5, 7 don't apply either: they describe the default-mode briefing's source coverage, not the sources view's own state. Only bullet 6 (depth conflict, e.g. `Depth ignored when 'sources' mode is active`) legitimately fires here.
- **Response-style wrappers from outside the skill** — no `## Open decisions` block, no extra `★ Insight` block, no "What's next" framing the model would add in a general task. The skill output IS the response.

When the user's `<instructions-file>` or another global rule mandates a closing-block format, that rule applies to general conversational replies — not to skill output. Skill specs override conversational defaults for their own scope.

## /briefing setup mode

Triggered by passing `setup` as the mode keyword. Adds (or updates) the `## Project Map` section in `<instructions-file>`.

This is the only mode that writes to a project file other than `briefing-log/`. The write happens after explicit user confirmation, with a one-time backup at `<instructions-file>.before-briefing-setup.bak` created first.

**Compatibility:**

- Mutex with depth tiers (`quick`/`standard`/`deep`).
- Mutex with `sources` (only one mode per invocation).
- `save` is not compatible — setup mode's output is interactive (proposal + confirmation prompt), not a static document. Surface bullet 6 of `★ About this briefing` (`Save ignored when 'setup' mode is active`) and proceed with setup.

### What it does

1. **Probe** the project state — same probes as `/briefing sources` (git remote, GitHub PRs/issues, canonical paths, working-memory dirs, ADR locations, per-project memory).
2. **Read** `<instructions-file>` (if it exists) and look for an existing `## Project Map` section.
3. **Propose** a `## Project Map` block populated from probes (see **Detection rules** below). Classify each field as **high confidence** (canonical path matched, tracker CLI returned data) or **low confidence** (defaulted to `none`, prose-inferred, or fell back to a non-canonical signal — see **Low-confidence prompts** below).
4. **Output** the proposal — a short summary of what was probed, the proposed block, and the insertion location.
5. **Invoke `AskUserQuestion`** with one structured question per low-confidence field (see **Low-confidence prompts** below). When every field is high confidence, invoke `AskUserQuestion` with a single yes/no question to confirm the write.
6. **Apply the user's choices** — override each field with the selected option (or the user's free-form `Other` value), then write to `<instructions-file>` after backup. The structured selection is itself the commitment; no separate confirmation step. If the user picks "Don't write" / "No", print the block for manual paste and stop.

### Output template

```
Setup proposal for `<project-name>`

## What I found

- <one bullet per probed source: detected value or "no detection">
- ...

## Proposed `## Project Map` block

```markdown
## Project Map

- **Tracker**: <detected or `<placeholder: ...>`>
- **Board**: <detected or `none`>
- **Roadmap**: <detected or `none`>
- **Changelog**: <detected or `none`>
- **Architecture**: <detected or `none`>
- **Working memory**: <detected or `none`>
- **Other**:
  - <suggested bullets, or `<placeholder>`>
```

## Where to insert

<line-number + anchor description, e.g. "After the title `# <name>` (line 1)" or "After `## What this project is` (line 9)">

## Apply

Answering the question(s) below writes the resolved block to `<instructions-file>` (creating `<instructions-file>.before-briefing-setup.bak` as a one-time backup first).
```

After printing the template above, the model invokes `AskUserQuestion` once with one question per low-confidence field (or, when every field is high confidence, a single yes/no question to confirm the write). See **Low-confidence prompts** below for the question shape and option rules. Do **not** render the numbered list, the four-option `Reply` block, or any free-form override syntax in the message body — the structured questions replace them.

If the proposed block contains `<placeholder>` markers, add a one-line note before the questions:

```
Note: <N> placeholder(s) remain (see fields marked `<placeholder: ...>` above).
You can write now and fill them in `<instructions-file>` afterwards, or cancel and edit
the proposal first.
```

### Detection rules

Pre-fill rules per field:

- **Tracker** — Try `gh issue list --limit 1` against the current GitHub remote. If it returns issues → `GitHub Issues`. Else apply the Default paths prose-inference rule (scan `<instructions-file>`/README for explicit mentions of `Linear team <name>`, `Jira project <name>`, `Notion`). Else if `linear-cli` is in `$PATH` → `<placeholder: Linear team <NAME>>`. Else if no detection → `<placeholder: GitHub Issues / Linear team X / Jira project Y / none>`.
- **Board** — No reliable detection. Default `none` with a note that the user can paste a URL.
- **Roadmap** — Probe `docs/ROADMAP.md` → `ROADMAP.md` (root) → Default paths prose inference (markdown links to `*roadmap*.md`) → `none`.
- **Changelog** — Probe `docs/CHANGELOG.md` → `CHANGELOG.md` (root) → Default paths prose inference (markdown links to `*changelog*.md`) → `none`.
- **Architecture** — Probe `docs/architecture.md` → `docs/system/` → Default paths prose inference (markdown links to `*architecture*.md`) → `none`.
- **Working memory** — Canonical layout (`docs/0-brainstorms/`, `docs/2-design/`, `docs/3-plans/` all present) → `docs/`. Else any directory containing `status:` frontmatter files → use that. Else `none`. (Prose inference skipped — directory inference is too low signal.)
- **Other** — Pre-suggest bullets based on detections: non-canonical working-memory layouts (e.g. `docs/plans/` with date-prefixed files), test-artefact directories (e.g. `tmp/tst_*`), custom scripts in `bin/` or `scripts/`. If nothing notable, leave a `<placeholder>` line.

When a value comes from prose inference, mark it in the proposal output with `(inferred from <instructions-file>)` or `(inferred from README.md)` so the user understands the source before they confirm.

### Low-confidence prompts

For new writes (no existing `## Project Map` section), classify each proposed field by detection confidence and surface low-confidence fields as structured questions via the `AskUserQuestion` tool. The pattern keeps the happy path one-turn for high-confidence projects while giving the user explicit per-field attention where detection is shaky — using the harness's native question UI rather than free-form override syntax in prose.

Existing-section updates use the same `AskUserQuestion` rendering for per-field diff confirmation (see **Existing `## Project Map`** below).

**Confidence classification per field:**

| Field | High confidence | Low confidence (prompt the user) |
|---|---|---|
| Tracker | `gh issue list` returned issues for the current GitHub remote | Prose-inferred, CLI-on-PATH-only (e.g. `linear-cli` present but not exercised), or no detection (default `<placeholder>`) |
| Board | (always low — no reliable auto-detection) | Anything found via prose inference; or default `none` when `<instructions-file>`/README contains URLs that look like project boards (GitHub Projects, Linear views, Notion boards) |
| Roadmap | Canonical path (`docs/ROADMAP.md`, `ROADMAP.md`) | Prose-inferred, default `none` |
| Changelog | Canonical path | Prose-inferred, default `none` |
| Architecture | Canonical path (`docs/architecture.md`, `docs/system/`) | Prose-inferred, default `none` (especially when `<instructions-file>`/README mentions architecture documentation in prose but the path didn't match `*architecture*.md` / `*arch*.md` — e.g. `docs/5-guides/PROJECT.md`) |
| Working memory | Canonical layout detected (`docs/0-brainstorms/` + `docs/2-design/` + `docs/3-plans/` all present) | `status:` frontmatter fallback (acceptable but flag the user so they can confirm or narrow), default `none` |
| Other | (none — see below) | Any auto-suggested bullet describing transitional / uncertain state (e.g. systems being replaced, gitignored runtime, branches with unmerged commits that touch the artifact) |

The model is the judge — if a detection looks shaky for project-specific reasons not enumerated above (e.g. the canonical path was found but contains conflicting evidence), prompt anyway. The bias is toward asking when in doubt; per-field prompts are cheap.

**`Other` bullets** are not prompted by default — they're inherently judgment-laden and a per-bullet flow would dominate the questions. Surface a question only for individual bullets describing state that may not survive (the `.workflow/items/` example: "transitioning to SQLite-backed server per BL#116" — that warrants a `Keep / Drop` question on that single bullet).

#### Rendering — `AskUserQuestion`

After printing the proposal block, invoke `AskUserQuestion` **once** with one question per low-confidence field (1–4 questions per call). When more than four low-confidence fields exist (rare — a Project Map only has seven total), batch into multiple `AskUserQuestion` calls in sequence; the model applies each batch's answers before invoking the next.

Per-question shape:

| Field | Description |
|---|---|
| `question` | Concise framing of the choice, ending with `?`. Reference the conflict or context in plain language. Examples: ``Tracker URLs don't match `gh issue list` (returned empty) and contradict your "no tracker in use" Other bullet — how to resolve?``; `Architecture path?`; `Keep the bullet about \`.workflow/items/\` (PR #362 reportedly removes it)?` |
| `header` | Short field label, ≤12 chars. Examples: `Tracker`, `Board`, `Roadmap`, `Architecture`, `Working mem`, `Other bullet`. |
| `options` | 2–3 options, each `{label, description}`. Always include a no-op option last (e.g. `Don't change`, `Leave as proposed`) so users can punt without typing into `Other`. |
| `multiSelect` | `false` for nearly all field questions. `true` only when reviewing several `Other` bullets together (each bullet a selectable item to drop). |

**Recommended option rule.** When one alternative is materially better — matches probed reality, resolves a contradiction, follows the project's other declared values — make it the **first** option and append `(Recommended)` to the `label`. The `description` says why. When no option is materially better than the others (genuinely a judgment call), omit the `(Recommended)` marker entirely; do not pick arbitrarily.

The user can also pick the auto-included `Other` to paste a custom value (path, URL, free-form text). Treat the `Other` text as the override value verbatim.

**Worked example** — a Tracker/Board conflict in an unconfigured project:

```
question: "Tracker and Board URLs don't match `gh issue list` (returned empty) and contradict your 'no tracker in use' Other bullet — how to resolve?"
header: "Tracker/Board"
options: [
  { label: "Match reality (Recommended)",
    description: "Set Tracker: none, Board: none. Drops the contradiction; reflects what gh reports." },
  { label: "Keep aspirations",
    description: "Keep both URLs (signalling intent to adopt). Drop or rewrite the contradicting Other bullet." },
  { label: "Leave unchanged",
    description: "No write; review and decide later." }
]
```

#### Reply handling

`AskUserQuestion` returns the user's selected `label` per question (or their custom `Other` text). Apply each selection as the override for the corresponding field, then:

- **All low-confidence answers were the no-op option** — write the proposal as-is (the user reviewed and accepted).
- **At least one override** — apply the overrides, write the resolved block to `<instructions-file>`, and show the user the actual diff (line range, what was written).
- **User picked "Don't write" / "No"** on the high-confidence yes/no question — print the block for manual paste, do not write.
- **User typed a paste-revised block in `Other`** — apply that block verbatim.

The `.bak` backup is the safety net if the user wants to undo.

#### When all fields are high confidence

Skip the per-field questions and invoke `AskUserQuestion` once with a single yes/no:

```
question: "Write the proposed `## Project Map` to <instructions-file>?"
header: "Apply"
options: [
  { label: "Yes, write it (Recommended)",
    description: "Adds the section. Creates <instructions-file>.before-briefing-setup.bak as a one-time backup." },
  { label: "No, just print",
    description: "Skips the write. The block stays in this conversation for manual paste." }
]
```

#### Fallback when `AskUserQuestion` is unavailable

If the runtime can't invoke `AskUserQuestion` (some subagent contexts, automated harnesses), fall back to a compact text form — one bullet per low-confidence field with a lettered option list:

```
Confirm or override (<N> field(s)):

1. **<Field>** — <one-line context>.
   - A. <option> (Recommended)
   - B. <option>
   - C. Don't change

Reply: `1: A, 2: B` (or paste a revised block).
```

The text fallback is the emergency path; the `AskUserQuestion` path is the default.

### Always write the canonical name

Always emit the canonical `## Project Map` (Title Case) header. The Declared probe matches both the canonical name and two deprecated earlier names (`## Project Context`, `## Project context`) for backward compatibility, but new writes always use `## Project Map`. When updating an existing section under any deprecated name, surface the rename as one of the diff items so the user sees and confirms it.

### Existing `## Project Map` (or deprecated variants)

If `<instructions-file>` already has a `## Project Map` section — or the deprecated `## Project Context` / `## Project context` — matched by the Declared case-insensitive probe:

1. Parse the existing fields.
2. Compute the diff against the proposed (detected) block.
3. Show the diff per-field: changing values, additions, fields that match. **If the existing header is a deprecated name**, list the rename as a top-level diff item: `Header: ## Project Context → ## Project Map` (or `## Project context → ## Project Map` for the doubly-deprecated lowercase form).
4. Invoke `AskUserQuestion` with one question per **changed** field (1–4 per call; batch if more). Each question's options are `{label: "Update", description: "<current> → <proposed>"}`, `{label: "Keep current", description: "<current>"}`, and `{label: "Use other value (Other)", description: "Paste a custom value"}` — `(Recommended)` goes on `Update` only when the proposal materially improves the field (e.g., resolves a probed contradiction, fills a missing path the model verified exists). Include the deprecated-header rename as its own question with `Update` recommended.
5. Apply only the changes the user selected; don't blanket-overwrite. Fields whose answer was `Keep current` retain their existing value.

### Insertion location (no existing section)

If `## Project Map` doesn't exist in `<instructions-file>`:

- If a `## What this project is` (or similar one-line "what this is" section) exists, insert after that section.
- Otherwise, insert directly after the title `# <name>` on line 1.

If `<instructions-file>` doesn't exist at all, propose creating one (as `CLAUDE.md` under Claude Code, or `AGENTS.md` under others) from the canonical scaffold (e.g., [`templates/default-project/CLAUDE.md`](<CANONICAL_CONVENTIONS_URL>/raw/templates/default-project/CLAUDE.md) or the platform's corresponding template) with the `## Project Map` populated. Tell the user the title is a placeholder.

### Backup mechanics

Before write, copy the existing `<instructions-file>` to `<instructions-file>.before-briefing-setup.bak` (overwriting any prior backup — single rolling backup). The backup copy must be a regular (dereferenced) file containing the target file's content (i.e., copying the target contents, not just copying the symlink pointer, to prevent backup data loss). On success, confirm: `Wrote ## Project Map to <instructions-file> (line N). Backup at <instructions-file>.before-briefing-setup.bak.`

If `<instructions-file>` doesn't exist, no backup is needed; create the new file (as `CLAUDE.md` under Claude Code, or `AGENTS.md` under others) with `# <project-name>` placeholder + the proposed `## Project Map`.

### Output isolation

Setup mode's output is *exactly* the template above (proposal + confirmation prompt) plus, after user reply, a write-confirmation or manual-paste-fallback line. Same exclusions as `/briefing sources`:

- No default-mode briefing sections (Summary / Status / Findings / Recommendations and next steps).
- No `/briefing sources` view layers.
- No `★ About this briefing` bullets except bullet 6 (depth or save conflict).
- No response-style wrappers (Claude's `## Open decisions`, `★ Insight`, free-form "What's next").

When the user's `<instructions-file>` or another global rule mandates a closing-block format, that rule applies to general conversational replies — not to setup mode's output. Skill specs override conversational defaults for their own scope.

### Tone

Helpful but tight. Show your work in the proposal — what was detected, where each field's value came from, what placeholders mean — but resist re-explaining the same context across multiple sections. The proposal block, the insertion location, and the structured questions are the load-bearing output; everything else is supporting prose and should be one or two lines, not paragraphs.

Each `AskUserQuestion`'s `description` carries the consequence of that option in one line. Avoid duplicating that context in the message body before the question — the question UI shows the description alongside the option, so a separate "two coherent options" / "to apply" / "reply with one of" pre-amble is redundant and adds noise.

Output isolation (subsection above) reinforces this: prose must not duplicate what the structured question already says.

## Save behaviour

Triggered by passing `save` (or synonyms `--save`, `export`) — see **How to parse the args**. Compatible with default-mode briefing and with `/briefing sources`; **not** compatible with `/briefing setup` (see the setup mode section above).

Determine the destination directory and a non-colliding filename, then create the directory if needed:

```bash
# Determine destination — repo-local if in a git repo, otherwise home
if git rev-parse --show-toplevel >/dev/null 2>&1; then
  ROOT="$(git rev-parse --show-toplevel)"
else
  ROOT="$HOME"
fi

# Detect platform prefix — the ACTIVE RUNTIME decides; substitute it into the
# case below. Directory existence is only the fallback for an undeterminable
# runtime: on machines with several harnesses installed, a fixed-order
# existence check misroutes (e.g. a Kimi session would match ~/.claude first).
case "<active-runtime>" in
  claude)             DEST="$ROOT/.claude/briefing-log" ;;
  kimi|kimi-code)     DEST="$ROOT/.kimi-code/briefing-log" ;;
  agy|antigravity)    DEST="$ROOT/.gemini/briefing-log" ;;
  codex)              DEST="$ROOT/.codex/briefing-log" ;;
  cursor)             DEST="$ROOT/.cursor/briefing-log" ;;
  grok)               DEST="$ROOT/.grok/briefing-log" ;;
  *)
    if [ -d "$ROOT/.claude" ] || [ -d "$HOME/.claude" ]; then
      DEST="$ROOT/.claude/briefing-log"
    elif [ -d "$ROOT/.kimi-code" ] || [ -d "$HOME/.kimi-code" ]; then
      DEST="$ROOT/.kimi-code/briefing-log"
    elif [ -d "$ROOT/.gemini" ] || [ -d "$HOME/.gemini" ]; then
      DEST="$ROOT/.gemini/briefing-log"
    elif [ -d "$ROOT/.codex" ] || [ -d "$HOME/.codex" ]; then
      DEST="$ROOT/.codex/briefing-log"
    elif [ -d "$ROOT/.cursor" ] || [ -d "$HOME/.cursor" ]; then
      DEST="$ROOT/.cursor/briefing-log"
    else
      DEST="$ROOT/.briefing-log"
    fi
    ;;
esac
mkdir -p "$DEST"
```

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

- **Lead with the most important thing.** The opening sentences of **Summary** carry the key message; if everything else got cut, they alone should be useful.
- **Plain English, humanizer-clean.** Generated prose follows the plain-English conventions and the humanizer patterns: short sentences, one idea each, no em-dash chains, no AI vocabulary ("delve", "leverage", "it's worth noting"), lead with the point. This binds the briefing's own sentences — quoted document titles and the project's own status vocabulary render verbatim.
- **Be specific, then translate.** File paths, SHAs, branch names, PR numbers, ROADMAP item names — cite them exactly, and gloss every code or identifier in plain words on first use. Vague briefings are worse than no briefing; so are briefings written in a shorthand only the last session understood.
- **Make it clickable.** Paths are written from the working directory, with `:line` when pointing at one item in a long file. A basename the reader has to go hunting for is not a citation.
- **Structure over prose.** Tables for enumerable facts, one-line bullets otherwise, nothing longer than a three-line paragraph.
- **Cite metrics, never compute them.** Read line counts, ahead/behind, dates from existing tooling. Don't aggregate token costs or estimate durations.
- **No emojis, no hype.** "Last shipped X" not "Successfully shipped X! 🎉".
- **Concise over comprehensive.** Bullets when structure helps scanning. No "It's worth noting that…"
- **Honest about gaps.** Source unreachable / empty → name it, don't fabricate.
- **Read-only on everything except `briefing-log/` and (in `setup` mode only) `<instructions-file>`.** Two writes the skill performs: (1) the save log writes to `briefing-log/` when `save` is passed; (2) the `setup` mode writes to `<instructions-file>` after explicit user confirmation, with a `.bak` backup created first. No other modes touch project files.
- **Suggest, don't impose.** Default-mode output never lobbies for convention adoption. Audit-style suggestions live in `/briefing sources` and are framed descriptively: equivalent info in different locations (declared via `## Project Map`) is a first-class hit, not a deviation. Never auto-applies a convention; never edits `<instructions-file>` or any other project file.
- **Prefer "you" framing.** This is a personal orientation tool ("you stopped mid-X"). For orientation, "you" is sharper than "we" or "the code" — the user invoked the skill *to be reminded what they were doing*.
- **No time estimates.** Don't say "this should take 2 hours." Estimate scope (small / medium / large by analogy to similar past items in the changelog) at most.

## Anti-fabrication

- **Don't generate from memory.** Every data point comes from a source read this invocation.
- **Don't compute metrics.** Read aggregates from existing artifacts; cite raw counts you can verify.
- **Don't fabricate URLs, PR numbers, file paths, commit SHAs.** If uncertain, omit or hedge ("there may be additional…").
- **Don't pretend a tracker integration worked when it didn't.** If the CLI is missing or the MCP failed, name the gap; do not invent items.
- **Don't overstate freshness.** If `git fetch` failed and refs are 2 days old, say so. The cost of stale data presented as fresh is higher than the cost of stale data labelled stale.
- **Don't synthesise patterns from thin data.** "Trend" requires 3+ data points. Below that, report individual facts; don't editorialise into a pattern.
- **Don't presume conventions.** Default-mode output never prescribes canonical adoption. The `/briefing sources` view shows what was probed and what was found regardless, and frames non-canonical paths as first-class via `## Project Map` declarations.

## What NOT to do

- Don't read raw conversation transcripts — see **Depth contract**, "Not read at any depth".
- Don't `git pull` — only `git fetch`. The fetch is read-only and never modifies the working tree (see the git-refs-refresh callout under Always-on above).
- Don't dump per-file diffs over 200 lines — summarise as `path:line-range (~N lines, looks like <one-line summary>)`.
- Don't fabricate PR numbers, file paths, commit SHAs, or URLs. If uncertain, omit or hedge.
- Don't compute metrics — cite them from existing tooling (line counts, ahead/behind, dates).
- Don't pad sections with nothing to say. In adaptive mode, omit empty sections entirely.
- Don't estimate time-to-completion. Estimate scope by analogy to similar changelog items at most.
- Don't write outside `briefing-log/` and (in setup mode only) `<instructions-file>`. Every other path this skill touches is read-only.
- Don't render the `★ About this briefing` block when no bullet has content — omit entirely.
- Don't put audit/setup content in default-mode briefing output. That belongs in `/briefing sources`.
- Don't presume canonical conventions are preferred over declared paths. Both are first-class in `/briefing sources`.
- Don't lobby for convention adoption in default-mode output. The Tone rule "Suggest, don't impose" applies: any content about the briefing skill's *setup* (declaring `## Project Map`, adopting canonical conventions, enriching briefings) lives in `★ About this briefing` bullet 2 and `/briefing sources` only — never in `Findings`, the closing section, or any other body section. If you find yourself writing a body bullet that ends with "…if you want richer briefings" or "…the briefing-readable fields", you've leaked setup content into orientation content; cut it.
- Don't wrap skill output with general response-style blocks. Both `/briefing` and `/briefing sources` produce complete outputs per their templates — appending Claude's normal `## Open decisions` block, an extra `★ Insight` block, or a free-form "what's next" paragraph is wrapper-creep. Global response-style rules (e.g., from `<instructions-file>`) govern conversational replies; the skill spec overrides them for skill output. See **Output isolation** in both `## Output template` and `## /briefing sources mode`.
- Don't cite a code, flag, ticket key, or task ID without saying what it means. `S7`, `D1`, `FF-204` and `BL#116` are lookups, not information. If you can't gloss it without opening the file, open the file.
- Don't write a bare basename as a file reference. `2026-08-04-launch.md` doesn't open; `website/.docs/plans/2026-08-04-launch.md` does.
- Don't put an action anywhere except Summary's needed-clause and Recommendations and next steps. A blocker checklist in Findings, a `→` line mid-briefing, a to-do under Status — all funnel violations. Context above; the ask at the end.
- Don't drop rows to shorten the briefing without saying so. Collapse is allowed — counted, named, with the escape hatch stated (see the collapse rule under Findings). Silent omission is the defect, not collapse.
- Don't filter silently. Excluding evergreen guides, reference docs or templates from the draft inventory is usually right; doing it without saying so is not. State the filter and its count — "5 evergreen prompts and guides excluded" — so the reader can overrule the judgement. An unstated exclusion and an accidental omission look identical from the outside.
- Don't read `status:` without also reading `type:`. `active` on a review means an open review; `active` on a brand guide means a current one. The status alone can't tell them apart.
- Don't tag every recommendation. **Urgent** / **Quick win** / **Blocking** are signal, not decoration — if more than about a third of the items carry a tag, the tags have stopped meaning anything. An item with no signal gets no tag, and a tag the steering line can't justify gets cut.
- Don't order the recommendations by vibes. The priority follows the signals — urgent first, then blocking, quick wins early when nearly free — and the opening paragraph says why. If the order can't be explained from the tags and the judgement, rework it.
