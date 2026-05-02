# <PROJECT_NAME> — instructions for Claude Code

This file is auto-loaded on every session. It is the operator-facing brief; `README.md` is the visitor-facing one.

> **Note:** this CLAUDE.md was generated from `templates/default-project/CLAUDE.md` in [carlosboeing/claude-code-resources](https://github.com/carlosboeing/claude-code-resources). Customise it for your project. The template's CLAUDE.md is *generic*; once you've adapted it here, do not re-sync from the template — your customisations are the source of truth.

## What this project is

<one paragraph: what the project is, who/what it's for, current stage. Replace this placeholder.>

## `docs/` — the project's working memory

`docs/` records how this project evolves: the lifecycle of each piece of work (brainstorm → design → plan → retro), the ongoing indexes that orient new readers (ROADMAP, CHANGELOG), and the persistent decisions that outlive any single phase (ADRs). Authored by whoever's working on the project — human, AI, or both — and structured so anyone can answer "what did we decide and why?" without archaeology. AI assistants reading it on session start is a benefit, not the purpose.

```
docs/
├── ROADMAP.md              — what's in flight / next / shipped
├── CHANGELOG.md            — what shipped, when
├── notes/                  — scratch, chat dumps, external research; loaded as session context
├── 0-brainstorms/          — pre-design ideas (worth-elaborating; one-liners go in ROADMAP)
├── 1-discovery/            — research, spikes, comparative analyses
├── 2-design/               — specs + designs (conflated, by intent)
├── 3-plans/                — phased implementation plans
├── 4-reviews/              — retros, audits, reviews, analyses
├── adrs/                   — single-decision records (NNNN-title.md)
└── guides/                 — internal procedural how-tos
```

For the canonical conventions, see the source: [`guide-project-structure-and-conventions.md`](https://github.com/carlosboeing/claude-code-resources/blob/main/guides/guide-project-structure-and-conventions.md).

## Conventions

- **Single source of truth.** One canonical place per question. ROADMAP is "what's next"; ADRs are decisions; `docs/system/` or `docs/architecture.md` is current state.
- **Self-describing filenames.** Lifecycle artifacts: `YYYY-MM-DD-<topic>-<suffix>.md` (`-design.md`, `-plan.md`, `-retro.md`, etc.). ADRs: `NNNN-<short-title>.md`. UPPERCASE.md for front-page meta files (`README.md`, `LICENSE`, `CHANGELOG.md`, `ROADMAP.md`); lowercase / kebab-case for content (`architecture.md`, `services.md`).
- **Always-current vs frozen-in-time.** `docs/system/`, `docs/guides/`, `docs/architecture.md` are evergreen — updated, not appended. Lifecycle docs (numbered phases) freeze with `status:` field once shipped.
- **Status flow:** `draft` → `approved` → `shipped` → optionally `superseded` (linked via `superseded_by:` frontmatter). ADRs use `draft` → `approved` → `superseded`. Brainstorms use `open` → `parked` / `superseded` / `abandoned`.
- **Change discipline.** When a design ships, the same commit (or commit series) updates `system/` (or `architecture.md`), adds a CHANGELOG entry, moves the ROADMAP item from In flight to Recently shipped, and flips frontmatter to `status: shipped`.
- **Brainstorm graduation.** Crystallised brainstorms go to `2-design/` directly (or via `1-discovery/` if substantial research came out of it first). Status `superseded`, `superseded_by:` linked.

## Commits

Conventional Commits format: `<type>(<scope>): <description>`. Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`. Imperative mood. Subject under 72 chars. Body explains *why*, not *what*. Reference relevant design / plan / ADR paths in the body when scope-relevant.

## Working principles for CC sessions

- **Verify before answering.** When unsure about repo state (does file X exist? is convention Y followed?), check first via `ls`/`grep`/`rg`/`Read`. Don't guess.
- **Don't add features the user didn't ask for.** No speculative scaffolding, no premature abstractions.
- **Don't suppress errors.** Surface failure modes plainly; don't fabricate success.
- **No emojis in files** unless the user explicitly asks.

## Working-memory discipline (required for AI sessions)

`docs/` is maintained primarily by AI agents. The [conventions guide §6.5](https://github.com/carlosboeing/claude-code-resources/blob/main/guides/guide-project-structure-and-conventions.md) enumerates the event triggers that require writes during a session — read it. Summary of the rules that bite most often:

- **When an initiative starts in conversation, write it down immediately.** Substantive new work creates `docs/0-brainstorms/<topic>.md` (`status: open`) AND a one-line pointer in ROADMAP `## Future considerations` or `## Next actions`. Don't wait for a commit prompt.
- **Status changes propagate.** When a design ships, the same commit updates ROADMAP (move to `## Recently shipped`), CHANGELOG, the design's frontmatter (`status: shipped`), AND the relevant evergreen state docs (`docs/architecture.md`, or `docs/system/*` if used).
- **Parked work goes to ROADMAP `## Parked`** with `Deferred:` / `Declined:` / `Superseded:` prefix (per §6.3 vocabulary).
- **Substantive audits or retros emerging from a conversation get saved** to `docs/4-reviews/YYYY-MM-DD-<topic>-{audit,retro,review,analysis}.md` before the session ends.
- **Session-end check:** before ending a non-trivial session, verify ROADMAP / CHANGELOG / artifact statuses reflect what we just did. If not, propose the missing writes inline.

## Where to look first

- For visitor-facing intent and quick-start: [`README.md`](README.md).
- For "what's the current state?": `docs/system/` or `docs/architecture.md` (when they exist) — for now, see README's `## Architecture` section.
- For "what's next?": [`docs/ROADMAP.md`](docs/ROADMAP.md).
- For "what was shipped?": [`docs/CHANGELOG.md`](docs/CHANGELOG.md).
- For "what did we decide and why?": [`docs/adrs/`](docs/adrs/).
- For working-memory style: [`guide-project-structure-and-conventions.md`](https://github.com/carlosboeing/claude-code-resources/blob/main/guides/guide-project-structure-and-conventions.md) (canonical reference).
