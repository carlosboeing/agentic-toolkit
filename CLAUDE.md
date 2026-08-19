# claude-code-resources — instructions for AI agents

This file is auto-loaded on every session. It's the agent-facing brief; `README.md` is the human-facing one. `AGENTS.md` symlinks to this file for harnesses that expect that filename.

> **Note:** this `CLAUDE.md` is specific to a meta-resources catalog — it talks about `skills/`, `guides/`, `reference/` as content kinds. It is **distinct from** [`templates/default-project/CLAUDE.md`](templates/default-project/CLAUDE.md), which is the *generic* project brief used when bootstrapping a new project. The two share DNA but have different jobs; do not deduplicate them.

## What this repo is

A personal collection of Claude Code resources I've built up — skills, guides, references — designed to be portable and shareable. Public-ish (currently a private GitHub repo, may go public later). Not a polished product; opinionated to one workflow.

## Project Map

Declares where project-tracking information lives so the [`/briefing`](skills/briefing/) skill (and other AI tools) can read it without guessing. Convention: [§5.8 of the conventions guide](guides/guide-project-structure-and-conventions.md#58--project-map-section-in-claudemd).

- **Tracker**: GitHub Issues — defects (`bug`) and improvements (`enhancement`) alike. An issue is for work with a definite shape: something specific enough that someone could pick it up. ROADMAP.md stays the forward view — direction, sequencing, what's parked, what shipped — and is still the single source of truth for that. A roadmap line whose work has become concrete links to its issue rather than restating it, so there is one record and two ways in.
- **Board**: none
- **Roadmap**: [docs/ROADMAP.md](docs/ROADMAP.md)
- **Changelog**: [docs/CHANGELOG.md](docs/CHANGELOG.md)
- **Architecture**: none (per-type catalog READMEs serve the always-current-state role — see [README.md](README.md) and [skills/README.md](skills/README.md); this is documented in the `docs/` framing below)
- **Working memory**: `docs/` (numbered lifecycle convention)
- **Other**:
  - Repo is the source of truth for skills; the active harness loads from its user-level skills directory (e.g., `~/.claude/skills/` for Claude Code, `~/.gemini/config/skills/` for agy, `~/.codex/skills/` or `~/.agents/skills/` for Codex). Kimi Code reads `~/.agents/skills/` natively (plus its own `~/.kimi-code/skills/` for Kimi-specific entries), so the Codex target covers it. Grok Build TUI reads the hub through Claude compat (`~/.claude/skills`); do not add a `~/.grok/skills` spoke. After edits to `skills/<name>/`, the install needs syncing — offer the sync explicitly. If the harness config directory is under source control (e.g., `carlosboeing/claude-config`), commit and push the synced files there too as a separate `chore(<scope>): sync from claude-code-resources` commit.
  - No CI configured; validation is manual / via `/ultrareview` on demand.
  - CrossRev (formerly `revloop`) was extracted to its own public repository on 2026-08-13 and is external now — see [`carlosboeing/crossrev`](https://github.com/carlosboeing/crossrev). It files its own deferred findings as issues, labelled `crossrev-review`. The policy lives in [`.github/crossrev.yml`](.github/crossrev.yml). Findings at `medium` and above keep the loop alive. A cycle stops after 3 passes, so a person decides whether another is worth the quota. Asking for a single pass by hand runs it past that cap: `crossrev review --pr <n>` then `crossrev resolve --pr <n>`.
  - `skills/sync-skills.sh` pulls `pr-review` and `pr-resolve` from a local CrossRev checkout, expected at `~/Projects/carlos/crossrev/skills` unless `CROSSREV_SKILLS` overrides it. It prints a note rather than skipping silently when that checkout is missing.

## Layout

Three clusters at the top level. See [README.md](README.md) for the visitor-facing version; this is the operator-facing summary.

```
.
├── docs/                   — REPO INTERNAL: this repo's working memory (see below)
│
├── skills/                 — HARNESS MIRROR: drop-in to ~/.claude/skills/
│   └── learn/
│
├── output-styles/          — HARNESS MIRROR: drop-in to ~/.claude/output-styles/
│   └── plain-english.md
│
├── tools/                  — EXTRACTION-READY: multi-part tools that may split into repos
│   └── plain-english/
│
├── guides/                 — OTHER CONSUMABLE: evergreen how-tos
├── reference/              — OTHER CONSUMABLE: snapshots, inventories, lookups
├── templates/              — OTHER CONSUMABLE: project bootstrap scaffolds
│
├── README.md               — visitor-facing landing page
├── CLAUDE.md               — this file (auto-loaded; operator-facing brief)
└── LICENSE                 — MIT
```

Future harness mirrors (created when first content lands; never empty placeholders): `plugins/`, `commands/`, `agents/`, `mcp-servers/`. Future other consumables: `prompts/`.

## `docs/` — the project's working memory

`docs/` is durable, human-readable artifacts that record how this repo evolves: the lifecycle of each piece of work (brainstorm → design → plan → retro), the ongoing indexes that orient new readers (ROADMAP, CHANGELOG), and the persistent decisions that outlive any single phase (ADRs). Authored by whoever's working on the project — human, AI, or both — and structured so anyone can answer "what did we decide and why?" without archaeology. AI assistants reading it on session start is a benefit, not the purpose.

```
docs/
├── ROADMAP.md              — what's in flight / next / shipped
├── CHANGELOG.md            — what shipped, when
├── notes/                  — scratch, chat dumps, external research
├── 0-brainstorms/          — pre-design ideas (worth-elaborating; one-liners go in ROADMAP)
├── 1-discovery/            — research, spikes, comparative analyses
├── 2-design/               — specs + designs (conflated, by intent)
├── 3-plans/                — phased implementation plans
├── 4-reviews/              — retros, audits, reviews, analyses
├── adrs/                   — single-decision records (NNNN-title.md)
└── guides/                 — internal procedural how-tos
```

For the canonical conventions and project-level template, see [guides/guide-project-structure-and-conventions.md](guides/guide-project-structure-and-conventions.md). Note: this repo's `docs/` is a *subset* — `system/` and `architecture.md` are skipped because the per-type catalog READMEs already serve the always-current-state role.

## Conventions

- **Filename prefix carries the type.** `guide-*.md`, `reference-*.md`. Slightly redundant with the directory name, intentionally — files stay self-describing when emailed, gisted, or pasted out of context.
- **Skills follow the harness layout.** One directory per skill at `skills/<name>/`. Each contains `SKILL.md` (the skill itself, drop-in to `~/.claude/skills/<name>/`) and `README.md` (human-facing docs — what it does, dials, design notes; not loaded by the harness).
- **Catalogs first, content second.** When adding the *first* item of a new type (e.g. the first hook), create the type directory AND its `<type>/README.md` catalog at the same time. Use `skills/README.md` as the template. Don't create empty type directories speculatively.
- **One subdirectory per non-trivial item.** Multi-file artifacts (with their own README, scripts, references) get a dir. Single-file artifacts with no docs can live flat — but realistically each shareable item earns its own subdir + README.
- **Plugins are bundles.** They contain their own skills/hooks/commands. Keep `plugins/<name>/` intact rather than flattening into the per-type dirs. Standalone skills at `skills/foo/` and bundled skills at `plugins/bar/skills/foo/` are kept separate; don't symlink.

## Commits

Conventional Commits format: `<type>(<scope>): <description>`. Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`. Imperative mood. Subject under 72 chars. Body explains *why*, not *what*. Reference the file(s) being touched in the body when scope-relevant.

Don't use `#N` in the subject or body unless intentionally referencing a GitHub issue (auto-links).

### Pre-commit checklist (when shipping)

A "ship" is a commit that changes user-facing behaviour or content (new skill mode, new guide, refactor of how a skill renders). When you're about to commit one, **`docs/ROADMAP.md` and `docs/CHANGELOG.md` must be staged in the same commit** — one atomic unit covering "what shipped" plus "where it's recorded". Move the relevant ROADMAP item to `## Recently shipped`; append a CHANGELOG entry under today's date.

Heuristic for spotting a ship: the staged diff touches `skills/`, `plugins/`, `agents/`, `hooks/`, `mcp-servers/`, `output-styles/`, `commands/`, `guides/`, `reference/`, `prompts/`, or `templates/`. The decision rule is *user-facing behaviour change*, not *file path* — so doc-internal cleanup (typo fixes, comment polish, internal-note formatting) opt out and commit alone.

## Working principles for agent sessions

- **Branch and workspace isolation.** Verify the active branch and workspace state at the start of a session. Brainstorm, design and plan work happens in the main checkout — no branch, no worktree. At implementation, branch off `origin/main` and ask whether to use a worktree before the first branch command. More than one entry in `git worktree list` means another session is live, so a worktree is required rather than offered. Worktrees go at `.worktrees/<harness>/<branch>`, branch slashes preserved.
- **The repo is small and read-easy.** Don't dispatch search agents for cross-file analysis — `grep`/`rg` and direct reads are faster.
- **Don't add features the user didn't ask for.** No speculative scaffolding for future skill types, no auto-generated indexes, no CI configs unless requested.
- **Skills are single-file by default.** When iterating on a skill, edit the existing `SKILL.md` rather than splitting into `references/` files unless the skill genuinely outgrows ~500 lines.
- **The README claims MIT and the LICENSE file confirms it.** Anything contributed back is under MIT.
- **No emojis in files** unless the user explicitly asks.

## Working-memory discipline (required for AI sessions)

This repo's `docs/` is maintained primarily by AI agents. Conventions guide §6.5 enumerates the event triggers that require writes during a session — read it. Summary of the rules that bite most often:

- **When an initiative starts in conversation, write it down immediately.** Substantive new work creates `docs/0-brainstorms/<topic>.md` (`status: open`) AND a one-line pointer in ROADMAP `## Future considerations` or `## Next actions`. Don't wait for a commit prompt.
- **Status changes propagate.** When a design ships, the same commit updates ROADMAP (move to `## Recently shipped`), CHANGELOG, the design's frontmatter (`status: shipped`), AND the relevant evergreen state docs (per §6.2 change discipline).
- **Parked work goes to ROADMAP `## Parked`** with `Deferred:` / `Declined:` / `Superseded:` prefix (per §6.3 vocabulary).
- **Substantive audits or retros emerging from a conversation get saved** to `docs/4-reviews/YYYY-MM-DD-<topic>-{audit,retro,review,analysis}.md` before the session ends.
- **Session-end check:** before ending a non-trivial session, verify ROADMAP / CHANGELOG / artifact statuses reflect what we just did — that includes flipping each touched lifecycle doc's own frontmatter `status` (design *and* plan move to `shipped` when they ship), not just the tracking files. If not, propose the missing writes inline.
- **Plan checkboxes are the durable execution record.** When implementing a `docs/3-plans/` plan, mark its `- [ ]` steps `- [x]` as they land instead of tracking only in the session's todo tool — a fresh session resumes from the file, not from your todos. The session-end check includes reconciling any in-flight plan's checkboxes with reality.

## Where to look first

- For visitor-facing intent and quick-start: `README.md`.
- For the skill catalog and shared install snippet: `skills/README.md`.
- For per-skill detail: `skills/<name>/README.md`.
- For the conventions this repo's own docs follow: `guides/guide-project-structure-and-conventions.md` (it's about *project* docs, but the same principles inform this repo's structure).
