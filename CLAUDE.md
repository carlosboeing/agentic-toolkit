# claude-code-resources — instructions for Claude Code

This file is auto-loaded on every session. It's the CC-facing brief; `README.md` is the human-facing one.

## What this repo is

A personal collection of Claude Code resources I've built up — skills, guides, references — designed to be portable and shareable. Public-ish (currently a private GitHub repo, may go public later). Not a polished product; opinionated to one workflow.

## Layout

```
.
├── skills/         — Claude Code skills (one dir per skill, each with SKILL.md + README.md)
├── guides/         — How-to guides for setting up Claude Code workflows
├── reference/      — Reference docs (snapshots / inventories / lookups)
├── README.md       — visitor-facing landing page
├── CLAUDE.md       — this file
└── LICENSE         — MIT
```

Each top-level directory has its own `README.md` acting as a catalog (one row per item, shared install pattern, conventions for adding new items). New artifact types — `plugins/`, `hooks/`, `commands/`, `agents/`, `mcp-servers/`, `output-styles/`, `status-line/` — get added the same way as needed.

## Conventions

- **Filename prefix carries the type.** `guide-*.md`, `reference-*.md`. Slightly redundant with the directory name, intentionally — files stay self-describing when emailed, gisted, or pasted out of context.
- **Skills follow the harness layout.** One directory per skill at `skills/<name>/`. Each contains `SKILL.md` (the skill itself, drop-in to `~/.claude/skills/<name>/`) and `README.md` (human-facing docs — what it does, dials, design notes; not loaded by the harness).
- **Catalogs first, content second.** When adding the *first* item of a new type (e.g. the first hook), create the type directory AND its `<type>/README.md` catalog at the same time. Use `skills/README.md` as the template. Don't create empty type directories speculatively.
- **One subdirectory per non-trivial item.** Multi-file artifacts (with their own README, scripts, references) get a dir. Single-file artifacts with no docs can live flat — but realistically each shareable item earns its own subdir + README.
- **Plugins are bundles.** They contain their own skills/hooks/commands. Keep `plugins/<name>/` intact rather than flattening into the per-type dirs. Standalone skills at `skills/foo/` and bundled skills at `plugins/bar/skills/foo/` are kept separate; don't symlink.

## Commits

Conventional Commits format: `<type>(<scope>): <description>`. Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`. Imperative mood. Subject under 72 chars. Body explains *why*, not *what*. Reference the file(s) being touched in the body when scope-relevant.

Don't use `#N` in the subject or body unless intentionally referencing a GitHub issue (auto-links).

## Working principles for CC sessions

- **The repo is small and read-easy.** Don't dispatch search agents for cross-file analysis — `grep`/`rg` and direct reads are faster.
- **Don't add features the user didn't ask for.** No speculative scaffolding for future skill types, no auto-generated indexes, no CI configs unless requested.
- **Skills are single-file by default.** When iterating on a skill, edit the existing `SKILL.md` rather than splitting into `references/` files unless the skill genuinely outgrows ~500 lines.
- **The README claims MIT and the LICENSE file confirms it.** Anything contributed back is under MIT.
- **No emojis in files** unless the user explicitly asks.

## Where to look first

- For visitor-facing intent and quick-start: `README.md`.
- For the skill catalog and shared install snippet: `skills/README.md`.
- For per-skill detail: `skills/<name>/README.md`.
- For the conventions this repo's own docs follow: `guides/guide-project-structure-and-conventions.md` (it's about *project* docs, but the same principles inform this repo's structure).
