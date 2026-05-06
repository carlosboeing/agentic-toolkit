# `/briefing` — Adaptive project orientation skill for Claude Code

A single-file [Claude Code skill](https://docs.claude.com/en/docs/claude-code/skills) that produces a structured briefing of project state on demand — built for the moment you return to a project after a session, a day, a week, or a vacation, and want to know **where you are, what you were doing, and what to pick up** without re-reading every file.

It auto-discovers what's in flight from git, GitHub, your project's CLAUDE.md `## Project context` section (when present), and whatever working-memory layout it can detect. The output reshapes by what it finds — leads with active work if there is any, leads with what's next if everything is calm.

The skill is **convention-aware but not convention-coupled**. It works generically in any repo and lights up with richer behaviour when a project follows the [canonical conventions in this repo](https://github.com/carlosboeing/claude-code-resources/blob/main/guides/guide-project-structure-and-conventions.md). Default-mode output stays focused on orientation; if you want to know what the skill probes and what it found in your project, run `/briefing sources` for a separate self-documentation view.

Designed for engineers using Claude Code who want substantive orientation, not the one-line summary the built-in `/recap` produces.

---

## What it does

Type `/briefing` in any Claude Code session and you get a structured briefing whose shape adapts to project state:

| Section | When it appears |
|---|---|
| **TL;DR** | Always — 1–2 sentences leading with the most important thing |
| **Snapshot** | Always — branch, ahead/behind, roadmap state, recent activity |
| **What's in flight** | Only if any Strong signal (open PR, unpushed commits, stashes, ROADMAP `## In flight`, drafts, dirty working tree, …) |
| **Recent activity** | Always — last 3–5 things, synthesised not dumped |
| **What's next** | Always — recommended action with reasoning |
| **Decisions / attention** | Only if there's something to flag (design calls, stale work, risky operations) |
| **`★ About this briefing`** | Only if a source failure, depth conflict, detached HEAD, or thin-input case applies — otherwise omitted entirely |

Sections with nothing to say are omitted entirely, not padded.

## Dials — how the briefing is shaped

Four knobs you can mix and match. Order doesn't matter.

| Dial | Keywords | Default | Effect |
|---|---|---|---|
| **Mode** | `sources`, `setup` | briefing | `sources` switches to the self-documentation view (what this skill probes, what it found). `setup` runs a wizard that builds/updates `## Project context` in CLAUDE.md (with backup). Mutex with depth tiers and with each other — see the dedicated subsections below. |
| **Depth** | `quick` (or `peek`), `standard`, `deep` (or `deep-dive`) | **adaptive (no override)** | Length × source breadth × wall-clock. `quick` < 300w, < 5s; `standard` 600–1000w, forces all six sections; `deep` 1200–2000w, adds historical sources, stale-branch sweep, ADR scan, per-project memory. Does not apply when `sources` mode is active. |
| **Save** | `save` (or `--save`/`export`) | off | Write the output to `<repo>/.claude/briefing-log/` (or `~/.claude/briefing-log/` outside a git repo). Compatible with all modes. |
| **Help** | `help` (or `?`/`usage`/`--help`/`-h`) | off | Render synopsis and stop |

The depth default is genuinely adaptive — when no depth keyword is provided, the output's length is content-driven (sections appear or disappear based on what the project state contains). `quick`/`standard`/`deep` are explicit overrides for fixed-length tiers; "no dial" is its own behaviour, not a synonym for `standard`. (`/learn`'s depth dial defaults to `standard`; `/briefing`'s defaults to adaptive — same canonical keyword vocabulary, different defaults that fit each skill's job.)

## Layered source model

The skill reads from four layers — each with a clear failure mode. **Always-on** mechanics run everywhere; **Declared** and **Default paths** are conditional on the project's setup; **Fallbacks** catches every gap.

### Always-on — universal mechanics

Runs in every project, knows nothing about specific conventions. Reads git state (branch, ahead/behind, dirty status, recent commits), uncommitted edits (`git status` + `git diff`, capped at 200 lines per file), local-only state (unpushed commits on any branch, stashes, worktrees, no-upstream branches), GitHub state via `gh` (your open PRs, all open PRs, assigned issues, current-branch CI status), top-level docs (`README.md`, `CLAUDE.md` — well-known by name, not a convention), and the per-project memory index at `~/.claude/projects/<slug>/memory/MEMORY.md`.

The skill never runs `git pull` — only `git fetch` (read-only). If `Auto-fetch: no` is declared in your CLAUDE.md, it skips the fetch entirely.

### Declared — explicit declarations via CLAUDE.md

Add a `## Project context` section to your project's CLAUDE.md to enrich the briefing with sources it can't auto-discover:

```markdown
## Project context

- **Tracker**: GitHub Issues
- **Board**: https://github.com/me/repo/projects/3
- **Roadmap**: docs/ROADMAP.md
- **Changelog**: docs/CHANGELOG.md
- **Architecture**: docs/architecture.md
- **Working memory**: docs/ (numbered lifecycle convention)
- **Auto-fetch**: yes
- **Other**:
  - Story tracking lives in Linear, team SHARELOG
  - Telemetry comments on issues via scripts/item-telemetry.sh
```

Recognised trackers: `GitHub Issues`, `GitHub Project N`, `Linear …`, `Jira …`, `Notion <ID or URL>`, file paths, URLs, `none`. Each kind has its own integration recipe (the skill knows which CLI or MCP tool to invoke). Declarations are authoritative — they override anything the default-path sniffer would have caught.

For the canonical schema, see [`guide-project-structure-and-conventions.md` §5.8](https://github.com/carlosboeing/claude-code-resources/blob/main/guides/guide-project-structure-and-conventions.md#58--project-context-section-in-claudemd).

### Default paths — convention sniffing

For any field you didn't declare in `## Project context`, the skill probes for canonical-conventions signatures (the structure documented in [the canonical guide](https://github.com/carlosboeing/claude-code-resources/blob/main/guides/guide-project-structure-and-conventions.md)). If they match — `docs/ROADMAP.md`, lifecycle dirs at `docs/[0-9]-*`, status frontmatter, ROADMAP sections like `## In flight` — the skill applies the canonical interpretation. If they don't match, it falls back to generic file discovery and names the gap.

This is the "lights up with conventions" tier. A project that follows the canonical layout gets richer briefings (in-flight detection wired to your ROADMAP sections, status frontmatter recognised, ADRs surfaced) for free. A project that uses different conventions just gets always-on + declared output, which still works — no broken behaviour.

Default-mode briefings don't lobby for convention adoption — orientation output stays focused on the project state. If you want to see what this skill probed and what it found (canonical paths matched, declarations honoured, gaps named), run `/briefing sources`. That view frames declared paths via `## Project context` as first-class equivalents to canonical defaults, not deviations.

### Fallbacks — graceful degradation

Standing instructions for every failure mode (no git repo, no remote, `gh` missing, network down, fetch auth failure, no `## Project context`, declared tracker unreachable, detached HEAD, secret-pattern files, working memory not found at any default path, …). Failures that affect orientation surface as bullets in the conditional `★ About this briefing` block; failures that don't surface in `/briefing sources` if you ask for them. Never papered over, never silently fabricated.

## Install

User-level — works in every project on your machine:

```bash
mkdir -p ~/.claude/skills/briefing
cp skills/briefing/SKILL.md ~/.claude/skills/briefing/SKILL.md
```

(If you're not in a clone of this repo, download `SKILL.md` directly from GitHub: `curl -o ~/.claude/skills/briefing/SKILL.md https://raw.githubusercontent.com/carlosboeing/claude-code-resources/main/skills/briefing/SKILL.md`.)

Restart Claude Code (or start a new session). Type `/` and you should see `briefing` in the slash-command menu, with the inline argument hint `[depth] [save] [help]`.

To verify it's loaded, type `/briefing help` — you should get the synopsis with no execution.

For the project-level install path and the shared install snippet, see [`skills/README.md`](../README.md).

## Usage examples

```
# ─── Standard cases ────────────────────────────────
/briefing                            # adaptive default
/briefing quick                      # < 300w, ~5–7 reads, < 5s
/briefing deep save                  # extended-window briefing, written to disk
/briefing standard                   # forces all six sections at 600–1000w

# ─── Sources mode (self-documentation) ─────────────
/briefing sources                    # what this skill probes + what it found here
/briefing sources save               # save the sources view to <TS>-sources.md

# ─── Setup mode (wizard for ## Project context) ────
/briefing setup                      # propose + apply a ## Project context block

# ─── Help ──────────────────────────────────────────
/briefing help
/briefing ?
```

## `/briefing sources` — self-documentation mode

A separate output that documents what this skill probes and what it found in the project. Mutex with depth tiers (`quick`/`standard`/`deep`); compatible with `save`. Run it when you want to know:

- What sources this skill *can* read in any project (always-on git/gh, declared `## Project context` fields, default canonical paths, fallbacks).
- What it *did* read in this specific project (which paths matched, which were declared, which weren't found).
- How to enrich future briefings — either by declaring additional locations in `## Project context`, or by adopting canonical conventions for zero-config behaviour.

The view is descriptive, not prescriptive. A project that uses `decisions/` instead of `docs/adrs/` and declares the path is a first-class hit, not a deviation. Both paths — declared and canonical — are equally valid. The view exists to make the skill's mechanics legible, not to lobby for any particular layout.

Output is organised by four user-facing layers (the same source model the skill uses internally, with friendlier labels): **Always-on**, **Declared (highest priority)**, **Default paths (when not declared)**, and **Fallbacks**. Empty layers render as `(none)` rather than disappearing — transparency is the point.

## `/briefing setup` — wizard for `## Project context`

The `setup` mode runs a one-shot wizard that builds (or updates) the [`## Project context` block](https://github.com/carlosboeing/claude-code-resources/blob/main/guides/guide-project-structure-and-conventions.md#58--project-context-section-in-claudemd) in your CLAUDE.md. Useful when you want richer briefings on a project that hasn't declared its tracker / roadmap / working-memory locations yet.

What it does:

1. Probes the project state (git remote, GitHub PRs/issues, canonical paths, working-memory dirs).
2. Reads CLAUDE.md (if present) and looks for an existing `## Project context` section.
3. Proposes a populated `## Project context` block — pre-filling detected fields, marking unknowable fields as `<placeholder>`, suggesting `Other` bullets based on what was found.
4. Shows the proposal + a confirmation prompt.
5. **On `yes`**, writes to CLAUDE.md (creating `CLAUDE.md.before-briefing-setup.bak` first as a one-time backup). **On `no`**, prints the block for manual paste.

This is the **only** mode that writes to a project file other than `briefing-log/`. Writes happen only after explicit user confirmation, with a backup created first. No silent edits.

If `## Project context` already exists, the wizard runs in **diff mode**: parses the existing fields, computes per-field changes against the proposal, and asks for field-by-field confirmation before applying anything. Doesn't blanket-overwrite.

`setup` is mutex with depth tiers (`quick`/`standard`/`deep`), with `sources`, and with `save`. Run it on its own, then optionally re-run `/briefing` to see how the new declarations enrich your briefings.

## Saved briefings (`briefing-log`)

When you append `save`, the briefing is written to disk so you can re-read it later or pin a known-good orientation point (useful before a long break).

- **Location**: `<repo>/.claude/briefing-log/` if you're in a git repo, else `~/.claude/briefing-log/`.
- **Filename**: `YYYY-MM-DDTHHMM.md` (UTC, ISO8601 to the minute, no colons in the filename for filesystem portability).
- **Frontmatter**: `type`, `date`, `project`, `branch`, then either `depth` + `in-flight` (default-mode saves) or `mode: sources` (sources-mode saves) — mutex, every record has exactly one of those two.
- **Overwrite policy**: never silent. If the filename already exists, a `-2`, `-3`, … suffix is appended.
- **Gitignore**: not auto-ignored. Whether to commit your `briefing-log/` is up to you and your team.

The save log is the only write the skill ever makes; everything else is read-only.

## Design philosophy

A few load-bearing rules — read these if you want to understand why the skill behaves as it does, or if you want to extend it:

- **Four layers, never more.** Always-on universal mechanics, declared sources, default-path sniffing, and fallbacks for graceful degradation. Each new source kind earns its place in one of the four. The split between declared (explicit) and default-path (sniffed) keeps convention-specific knowledge out of the universal baseline.
- **Convention-aware, not convention-coupled.** The skill is shareable to projects using any conventions. Adopting the canonical conventions in this repo lights it up with richer behaviour; not adopting them produces simpler but still-useful output. Never imposes; always suggests.
- **Adaptive over fixed.** The default has no depth keyword precisely because the right shape changes with project state. `quick`/`standard`/`deep` are escape hatches when you know what you want.
- **Read-only on the project.** The skill never modifies project files; the only exception is the briefing log it writes to `briefing-log/` when you invoke it with `save`.
- **`git fetch`, never `git pull`.** Fetching updates refs without modifying the working tree, so the briefing can compute accurate ahead/behind without risking a merge mid-task. `Auto-fetch: no` skips even the fetch.
- **Anti-fabrication.** Every data point comes from a source read this invocation. No invented PR numbers, file paths, SHAs, or URLs. Stale data labelled stale beats stale data presented as fresh.
- **Honest about gaps.** Source unreachable, declared tracker missing, no `## Project context` section, network down — orientation-affecting gaps name themselves in the conditional `★ About this briefing` block. Setup-affecting gaps surface in `/briefing sources` if you ask for them. Never papered over.
- **No transcripts.** The skill never reads raw conversation transcripts on disk, even at `deep`. That would undermine the working-memory discipline (`docs/` artifacts become optional if briefings can recover from transcripts), and the on-disk format is undocumented Anthropic internals.
- **Single file.** All ~530 lines live in one `SKILL.md`. Easy to share, easy to extend, easy to grep.

## Limitations

- **Single project only.** No cross-project briefings. If you have a portfolio question ("what's in flight across all five repos I'm working on?"), open each one in turn or build a wrapper.
- **No computed metrics.** The skill cites raw counts from existing tooling — number of PRs, number of unpushed commits, ROADMAP item counts. It does not aggregate token costs, estimate effort, predict ship dates, or otherwise produce numbers that aren't already in a tool somewhere.
- **No transcript reading.** As above — by design, not by oversight. The principled equivalent is a Stop hook with an explicit snapshot schema (Approach C in the design doc), deferred for a future version.
- **Tracker integrations are best-effort.** The skill knows the CLI/MCP path for `GitHub Issues`, `GitHub Project N`, `Linear`, `Jira`, `Notion`, file paths, and URLs. If a declared tracker has no CLI installed and no MCP configured, the briefing names the gap and continues — it doesn't try to scrape.
- **No `quick`/`standard`/`deep` learning.** The dial doesn't remember what you've asked for; every invocation is from-scratch.

## Requirements

- **Claude Code** installed (any recent version).
- **`git`** (almost certainly already installed).
- **`gh` CLI** authenticated, optional but strongly recommended — without it the skill skips GitHub PR/issue/CI lookups and notes the gap in the footer.
- A project-tracker CLI or MCP server, only if you've declared one in `## Project context` (e.g. `linear-cli`, Notion MCP).

## Sharing

This whole thing is one `SKILL.md` file. To share with someone:

1. Send them the GitHub link, or paste `SKILL.md` directly.
2. They put it at `~/.claude/skills/briefing/SKILL.md`.
3. Restart Claude Code.

For the briefing to be richer than Layer 1 in a colleague's repo, they also add a `## Project context` section to that repo's CLAUDE.md. The `templates/default-project/CLAUDE.md` in this repo includes the section as scaffolding.

That's it. No package install, no plugin marketplace, no auth setup beyond the optional `gh` CLI.

## See also

- **[`SKILL.md`](SKILL.md)** — the skill itself, drop-in to `~/.claude/skills/briefing/`.
- **[`docs/2-design/2026-05-03-briefing-footer-redesign-design.md`](../../docs/2-design/2026-05-03-briefing-footer-redesign-design.md)** — footer redesign (conditional `★ About this briefing` block + `/briefing sources` mode). Most recent design.
- **[`docs/2-design/2026-05-03-briefing-skill-shareability-design.md`](../../docs/2-design/2026-05-03-briefing-skill-shareability-design.md)** — prior design (4-layer architecture). Background for the layered source model. Superseded for the footer behaviour by the redesign above.
- **[`docs/2-design/2026-05-02-briefing-skill-design.md`](../../docs/2-design/2026-05-02-briefing-skill-design.md)** — original design (3-layer model). Historical reference; the layered-source-model rationale and the deferred Approach C (Stop-hook snapshot schema) live here.
- **[`guide-project-structure-and-conventions.md` §5.8](https://github.com/carlosboeing/claude-code-resources/blob/main/guides/guide-project-structure-and-conventions.md#58--project-context-section-in-claudemd)** — the canonical `## Project context` schema this skill consumes.
- **[`templates/default-project/CLAUDE.md`](../../templates/default-project/CLAUDE.md)** — generic CLAUDE.md scaffold that ships with the section pre-populated.
- **[`/learn`](../learn/)** — sibling skill in this repo. Same single-file shape, same closed-keyword parser pattern, same canonical depth vocabulary (`quick`/`standard`/`deep`) — different default behaviour and different problem domain (lessons, not orientation).

## License

MIT — share freely, modify freely.
