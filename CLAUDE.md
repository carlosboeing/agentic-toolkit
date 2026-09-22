# Agentic Toolkit — instructions for AI agents

This file is auto-loaded on every session. It's the agent-facing brief; `README.md` is the human-facing one. `AGENTS.md` symlinks to this file for harnesses that expect that filename.

> **Note:** this `CLAUDE.md` is specific to a meta-resources catalog — it talks about `skills/`, `guides/`, `reference/` as content kinds. It is **distinct from** [`templates/default-project/CLAUDE.md`](templates/default-project/CLAUDE.md), which is the *generic* project brief used when bootstrapping a new project. The two share DNA but have different jobs; do not deduplicate them.

## What this repo is

A modular collection of harness-agnostic skills, configurations, hooks, guides, and conventions for AI-assisted engineering across Claude Code, Codex, Antigravity, Kimi Code, Grok Build TUI, and OpenCode. Opinionated to one workflow; portable across harnesses. Public repository under the MIT License.

## Project Map

Declares where project-tracking information lives so the [`/briefing`](skills/briefing/) skill (and other AI tools) can read it without guessing. Convention: [§5.8 of the conventions guide](guides/guide-project-structure-and-conventions.md#58--project-map-section-in-claudemd).

- **Tracker**: GitHub Issues — defects (`bug`) and improvements (`enhancement`) alike. An issue is for work with a definite shape: something specific enough that someone could pick it up. ROADMAP.md stays the forward view — direction, sequencing, what's parked, what shipped — and is still the single source of truth for that. A roadmap line whose work has become concrete links to its issue rather than restating it, so there is one record and two ways in.
- **Board**: none
- **Roadmap**: [docs/ROADMAP.md](docs/ROADMAP.md)
- **Changelog**: [docs/CHANGELOG.md](docs/CHANGELOG.md)
- **Architecture**: none (per-type catalog READMEs serve the always-current-state role — see [README.md](README.md) and [skills/README.md](skills/README.md))
- **Working memory**: `.workbench/` — a **separate private repository**, nested here as an independent clone when present. When absent, see Contributor route below.
- **Other**:
  - Repo is the source of truth for skills; the active harness loads from its user-level skills directory (e.g., `~/.claude/skills/` for Claude Code, `~/.gemini/config/skills/` for agy, `~/.codex/skills/` or `~/.agents/skills/` for Codex). Kimi Code reads `~/.agents/skills/` natively (plus its own `~/.kimi-code/skills/` for Kimi-specific entries), so the Codex target covers it. Grok Build TUI reads the hub through Claude compat (`~/.claude/skills`); do not add a `~/.grok/skills` spoke. After edits to `skills/<name>/`, the install needs syncing — offer the sync explicitly. `~/.claude/` is no longer under source control of its own: `carlosboeing/claude-config` was retired on 2026-09-08, and the skill hub is derived state rebuilt by `sync-toolkit.sh`. Nothing there needs a second commit.
  - `instructions/CLAUDE.md` is the global agent brief. `~/.claude/CLAUDE.md` symlinks to it, and five harness paths symlink to that. Editing it changes every harness, so measure `wc -c instructions/CLAUDE.md` against Antigravity's 24,023-character limit before committing an addition.
  - CI runs on push and pull request via `.github/workflows/ci.yml`.
  - CrossRev (formerly `revloop`) was extracted to its own public repository on 2026-08-13 and is external now — see [`carlosboeing/crossrev`](https://github.com/carlosboeing/crossrev). It files its own deferred findings as issues, labelled `crossrev-review`. The policy lives in [`.github/crossrev.yml`](.github/crossrev.yml). Findings at `medium` and above keep the loop alive. A cycle stops after 3 passes, so a person decides whether another is worth the quota. Asking for a single pass by hand runs it past that cap: `crossrev review --pr <n>` then `crossrev resolve --pr <n>`.
  - `scripts/sync-toolkit.sh` copies external skills only from directories listed in `EXTRA_SKILL_SOURCES` in local sync configuration. Add the CrossRev checkout's skills directory there to include `pr-review` and `pr-resolve`. It reports configured source directories that are missing. The same run writes OpenCode's `/`-menu command wrappers (one per hub skill) into `~/.config/opencode/command/` and copies `hooks/validate-mermaid/opencode-validate-mermaid.ts` to `~/.config/opencode/plugins/validate-mermaid.ts`. It does not write `plugins/rtk.ts`. OpenCode is not a spoke since it reads the hub through Claude compat; the wrappers only add slash entries its TUI otherwise withholds.

## The public/private gate

**This repository is public. `.workbench/` is a different, private repository.** Three layers keep them apart, and only the first needs no vigilance.

### 1. Structural

`.workbench/` is an independent clone nested at this root and named in `.gitignore`, so `git add -A` here can never sweep a workbench file into a public commit.

**Never cross-commit.** In this working tree, plain `git …` targets **whichever repository the shell is currently inside** — the public one at the root, the private one from anywhere under `.workbench/`. From the root, `git -C .workbench …` names the private one explicitly. Nothing in git's output says which repo it resolved, so when you are not certain where the shell is, name the target with `-C` rather than assuming. There is no command that legitimately stages both.

### 2. The routing table

| Goes to `.workbench/` (private) | Goes here (public) |
|---|---|
| Lifecycle working memory: `0-brainstorms/`, `1-discovery/`, `2-design/`, `3-plans/`, `4-reviews/`, `notes/`, internal procedural guides | Code, tests, templates, skills, hooks, rules |
| Working memory docs, retros, scratch notes, spikes, evaluation logs | Public documentation, reference catalogs, evergreen guides under `guides/` |
| Anything about brand, company, naming strategy, or commercial direction | ADRs (`docs/adrs/`), `docs/ROADMAP.md`, `docs/CHANGELOG.md` |

The line is sharper than lifecycle-versus-product. **Anything about brand, company, naming strategy, or commercial direction — a hosted service, monetisation, pricing, company naming — is workbench-only even when it is a settled decision.** The public record covers the *what* of the toolkit: features, bug fixes, user-facing guides, and public architectural decisions. It never covers the *why* of private business or commercial strategy.

### 3. Contributor route (when `.workbench/` is absent)

If `.workbench/` is absent, you are an outside contributor. Use issues, pull requests and, for a substantial architectural decision, an ADR under `docs/adrs/`. Do not create lifecycle directories under `docs/` or at the repository root, and do not create or nest a workbench repository. See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

### 4. What a public artifact may say

Commit messages, pull request and issue titles and bodies, review comments, and release notes are public and permanent.

**Never name a private or local source in one.** Not `.workbench`, not the workbench repository, not the bare phrase "the workbench", not a path to a document held there, not `/Users/...`, not a client name or an internal cost figure.

The damage is a citation the reader cannot follow. "See the plan in the workbench" says something exists and withholds it, which is worse than saying nothing. **Restate the fact instead:** put the reasoning in the body in its own words, or in an ADR under `docs/adrs/` that the artifact then links.

### 5. Pre-commit privacy guard

`scripts/githooks/pre-commit` enforces privacy rules automatically on staged changes. It refuses:
- Staged `.workbench` gitlinks (mode 160000)
- `.workbench` paths or references to workbench files
- `/Users/` absolute paths
- Commercial-strategy terms (`hosted service`, `hosted tier`, `monetiz`, `monetis`)

Vendor price tables (such as API token rates in reference docs) are legitimate and supported.

### Working Memory Location override

Any generic agent skill — `brainstorming`, `writing-plans`, or an equivalent — that instructs you to save specs, plans or brainstorms under `docs/` **must be overridden** when `.workbench/` is present. Save them under `.workbench/` instead. When `.workbench/` is absent, use issues, pull requests, and public ADRs under `docs/adrs/`. **Never write lifecycle directories (`docs/0-brainstorms/`, etc.) into this repo's `docs/`.**

## Layout

Three clusters at the top level. See [README.md](README.md) for the visitor-facing version; this is the operator-facing summary.

```
.
├── docs/                   — PUBLIC TRACKING & DECISIONS: ROADMAP, CHANGELOG, adrs/
│
├── instructions/           — HARNESS MIRROR: ~/.claude/CLAUDE.md symlinks here
│   └── CLAUDE.md           — the global brief every harness reads
│
├── skills/                 — HARNESS MIRROR: drop-in to ~/.claude/skills/
│   └── learn/
│
├── output-styles/          — HARNESS MIRROR: drop-in to ~/.claude/output-styles/
│                             (catalog only; Plain English moved to carlosboeing/copydesk)
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

## `docs/` — public tracking and decisions

`docs/` holds public tracking and architectural decision records:

```
docs/
├── ROADMAP.md              — what's in flight / next / shipped
├── CHANGELOG.md            — what shipped, when
└── adrs/                   — single-decision records (NNNN-title.md)
```

Working memory across the lifecycle directories lives in `.workbench/` (when present) or GitHub issues/PRs (for external contributors).

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

- **Branch and workspace isolation.** Verify the active branch and workspace state at the start of a session. Brainstorm, design and plan work happens in the main checkout or `.workbench/` — no branch, no worktree. At implementation, branch off `origin/main` and ask whether to use a worktree before the first branch command. More than one entry in `git worktree list` means another session is live, so a worktree is required rather than offered. Worktrees go at `.worktrees/<harness>/<branch>`, branch slashes preserved.
- **The repo is small and read-easy.** Don't dispatch search agents for cross-file analysis — `grep`/`rg` and direct reads are faster.
- **Don't add features the user didn't ask for.** No speculative scaffolding for future skill types, no auto-generated indexes, no CI configs unless requested.
- **Skills are single-file by default.** When iterating on a skill, edit the existing `SKILL.md` rather than splitting into `references/` files unless the skill genuinely outgrows ~500 lines.
- **The README claims MIT and the LICENSE file confirms it.** Anything contributed back is under MIT.
- **No emojis in files** unless the user explicitly asks.

## Working-memory discipline (required for AI sessions)

Summary of the rules that bite most often:

- **When `.workbench/` is present:**
  - **When an initiative starts in conversation, write it down immediately.** Substantive new work creates `.workbench/0-brainstorms/<topic>.md` (`status: open`) AND a one-line pointer in ROADMAP `## Future considerations` or `## Next actions`. Don't wait for a commit prompt.
  - **Status changes propagate.** When a design ships, the same commit updates ROADMAP (move to `## Recently shipped`), CHANGELOG, the design's frontmatter in `.workbench/2-design/` (`status: shipped`), AND the relevant evergreen state docs (per conventions guide §6.2 change discipline).
  - **Run `git` at repository root for public commits; run `git -C .workbench` for private commits.** Never cross-commit.
  - **Parked work goes to ROADMAP `## Parked`** with `Deferred:` / `Declined:` / `Superseded:` prefix (per §6.3 vocabulary).
  - **Substantive audits or retros emerging from a conversation get saved** to `.workbench/4-reviews/YYYY-MM-DD-<topic>-{audit,retro,review,analysis}.md` before the session ends.
  - **Session-end check:** before ending a non-trivial session, verify ROADMAP / CHANGELOG / artifact statuses reflect what we just did — that includes flipping each touched lifecycle doc's own frontmatter `status` (design *and* plan move to `shipped` when they ship), not just the tracking files. If not, propose the missing writes inline.
  - **Plan checkboxes are the durable execution record.** When implementing a plan, mark its `- [ ]` steps `- [x]` as they land instead of tracking only in the session's todo tool — a fresh session resumes from the file, not from your todos.
- **When `.workbench/` is absent (outside contributor):**
  - Work directly in GitHub issues and PRs.
  - For architectural decisions, propose an ADR in `docs/adrs/NNNN-title.md` (`status: open`, moving to `status: approved` on merge).
  - Do not create lifecycle directories (`0-brainstorms/`, etc.) in the public repository.

## Where to look first

- For visitor-facing intent and quick-start: `README.md`.
- For the skill catalog and shared install snippet: `skills/README.md`.
- For per-skill detail: `skills/<name>/README.md`.
- For the conventions this repo's own docs follow: `guides/guide-project-structure-and-conventions.md`.
