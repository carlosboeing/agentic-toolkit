# `/briefing` — Adaptive project orientation skill for Claude Code

A single-file [Claude Code skill](https://docs.claude.com/en/docs/claude-code/skills) that produces a structured briefing of project state on demand — built for the moment you return to a project after a session, a day, a week, or a vacation, and want to know **where you are, what you were doing, and what to pick up** without re-reading every file.

It auto-discovers what's in flight from git, GitHub, the canonical `docs/` working-memory layout, and any project-tracker source declared in your project's CLAUDE.md `## Project context` section. The output reshapes by what it finds — leads with active work if there is any, leads with what's next if everything is calm.

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
| **Source-coverage footer** | Always — names every source actually read and every one skipped (with reason) |

Sections with nothing to say are omitted entirely, not padded.

## Dials — how the briefing is shaped

Three knobs you can mix and match. Order doesn't matter.

| Dial | Keywords | Default | Effect |
|---|---|---|---|
| **Depth** | `quick` (or `peek`), `standard`, `deep` (or `deep-dive`/`audit`) | **adaptive (no override)** | Length × source breadth × wall-clock. `quick` < 300w, < 5s; `standard` 600–1000w, forces all six sections; `deep` 1200–2000w, adds historical sources, stale-branch sweep, ADR scan, per-project memory |
| **Save** | `save` (or `--save`/`export`) | off | Write the briefing to `<repo>/.claude/briefing-log/` (or `~/.claude/briefing-log/` outside a git repo) |
| **Help** | `help` (or `?`/`usage`/`--help`/`-h`) | off | Render synopsis and stop |

The depth default is genuinely adaptive — when no depth keyword is provided, the output's length is content-driven (sections appear or disappear based on what the project state contains). `quick`/`standard`/`deep` are explicit overrides for fixed-length tiers; "no dial" is its own behaviour, not a synonym for `standard`. (`/learn`'s depth dial defaults to `standard`; `/briefing`'s defaults to adaptive — same canonical keyword vocabulary, different defaults that fit each skill's job.)

## Layered source model

The skill reads from three layers, each one optional except Layer 1.

### Layer 1 — Universal baseline

Runs in every project, no configuration required. Reads git state (branch, ahead/behind, dirty status, recent commits), uncommitted edits (`git status` + `git diff`, capped at 200 lines per file), local-only state (unpushed commits on any branch, stashes, worktrees, no-upstream branches), GitHub state via `gh` (your open PRs, all open PRs, assigned issues, current-branch CI status), top-level docs (`README.md`, `CLAUDE.md`), canonical working-memory (`docs/ROADMAP.md`, `docs/CHANGELOG.md`), lifecycle dirs (`docs/{0-brainstorms,2-design,3-plans,4-reviews,adrs}/` filtered by `status:` frontmatter), and the per-project memory index at `~/.claude/projects/<slug>/memory/MEMORY.md`.

The skill never runs `git pull` — only `git fetch` (read-only). If `Auto-fetch: no` is declared in your CLAUDE.md, it skips the fetch entirely.

### Layer 2 — Project-declared via CLAUDE.md

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

Recognised trackers: `GitHub Issues`, `GitHub Project N`, `Linear …`, `Jira …`, `Notion <ID or URL>`, file paths, URLs, `none`. Each kind has its own integration recipe (the skill knows which CLI or MCP tool to invoke). Absent fields fall back to Layer 1 defaults; declarations are additive, not mandatory.

For the canonical schema and the conventions repo's full take on this section, see [`guide-project-structure-and-conventions.md` §5.8](https://github.com/carlosboeing/claude-code-resources/blob/main/guides/guide-project-structure-and-conventions.md#58--project-context-section-in-claudemd).

### Layer 3 — Graceful degradation

Standing instructions for every failure mode (no git repo, no remote, `gh` missing, network down, fetch auth failure, no `## Project context`, declared tracker unreachable, detached HEAD, secret-pattern files, …). Every gap surfaces in the briefing's source-coverage footer with the reason — never papered over, never silently fabricated.

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
/briefing deep save                  # full audit, written to disk
/briefing standard                   # forces all six sections at 600–1000w

# ─── Help ──────────────────────────────────────────
/briefing help
/briefing ?
```

## Saved briefings (`briefing-log`)

When you append `save`, the briefing is written to disk so you can re-read it later or pin a known-good orientation point (useful before a long break).

- **Location**: `<repo>/.claude/briefing-log/` if you're in a git repo, else `~/.claude/briefing-log/`.
- **Filename**: `YYYY-MM-DDTHHMM.md` (UTC, ISO8601 to the minute, no colons in the filename for filesystem portability).
- **Frontmatter**: `type`, `date`, `project`, `branch`, `depth`, `in-flight` — searchable.
- **Overwrite policy**: never silent. If the filename already exists, a `-2`, `-3`, … suffix is appended.
- **Gitignore**: not auto-ignored. Whether to commit your `briefing-log/` is up to you and your team.

The save log is the only write the skill ever makes; everything else is read-only.

## Design philosophy

A few load-bearing rules — read these if you want to understand why the skill behaves as it does, or if you want to extend it:

- **Three layers, never more.** Universal baseline, project-declared, graceful degradation. Each new source kind earns its place in one of the three; no fourth tier.
- **Adaptive over fixed.** The default has no depth keyword precisely because the right shape changes with project state. `quick`/`standard`/`deep` are escape hatches when you know what you want.
- **Read-only on the project.** The skill never modifies project files; the only exception is the briefing log it writes to `briefing-log/` when you invoke it with `save`.
- **`git fetch`, never `git pull`.** Fetching updates refs without modifying the working tree, so the briefing can compute accurate ahead/behind without risking a merge mid-task. `Auto-fetch: no` skips even the fetch.
- **Anti-fabrication.** Every data point comes from a source read this invocation. No invented PR numbers, file paths, SHAs, or URLs. Stale data labelled stale beats stale data presented as fresh.
- **Honest about gaps.** Source unreachable, declared tracker missing, no `## Project context` section, network down — every gap names itself in the source-coverage footer.
- **No transcripts.** The skill never reads raw conversation transcripts on disk, even at `deep`. That would undermine the working-memory discipline (`docs/` artifacts become optional if briefings can recover from transcripts), and the on-disk format is undocumented Anthropic internals.
- **Single file.** All ~400 lines live in one `SKILL.md`. Easy to share, easy to extend, easy to grep.

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
- **[`docs/2-design/2026-05-02-briefing-skill-design.md`](../../docs/2-design/2026-05-02-briefing-skill-design.md)** — the design doc that drove this implementation, including the layered source model rationale and the deferred Approach C (Stop-hook snapshot schema).
- **[`guide-project-structure-and-conventions.md` §5.8](../../guides/guide-project-structure-and-conventions.md#58--project-context-section-in-claudemd)** — the canonical `## Project context` schema this skill consumes.
- **[`templates/default-project/CLAUDE.md`](../../templates/default-project/CLAUDE.md)** — generic CLAUDE.md scaffold that ships with the section pre-populated.
- **[`/learn`](../learn/)** — sibling skill in this repo. Same single-file shape, same closed-keyword parser pattern, same canonical depth vocabulary (`quick`/`standard`/`deep`) — different default behaviour and different problem domain (lessons, not orientation).

## License

MIT — share freely, modify freely.
