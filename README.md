# claude-code-resources

A personal collection of [Claude Code](https://docs.claude.com/en/docs/claude-code) skills, guides, and references I've built up while using the tool day-to-day. Public-ish — designed to be shareable with colleagues and portable across projects, but slightly opinionated to my workflow.

> If you've stumbled across this and find something useful, take what works. Nothing here is a polished product; it's working notes.

## Contents

The repo splits into three clusters. The cluster headers below also organise [`CLAUDE.md`](CLAUDE.md).

### Repo internals

| Path | What | Install? |
|---|---|---|
| [`docs/`](docs/) | This repo's working memory — brainstorms, designs, plans, retros, ADRs, ROADMAP, CHANGELOG. | — |

### Harness mirrors (drop-in to `~/.claude/<type>/`)

| Path | What | Install path |
|---|---|---|
| [`instructions/`](instructions/) | The canonical global agent instruction file, read by six harnesses. See [`instructions/README.md`](instructions/README.md). | `~/.claude/CLAUDE.md` (symlink) |
| [`skills/`](skills/) | Claude Code skills (drop-in `SKILL.md` files). See [`skills/README.md`](skills/README.md). | `~/.claude/skills/<name>/` |
| [`hooks/`](hooks/) | Lifecycle hooks (shell scripts + settings fragments). See [`hooks/README.md`](hooks/README.md). | `~/.claude/hooks/<name>.sh` |
| [`output-styles/`](output-styles/) | Output style prompts. See [`output-styles/README.md`](output-styles/README.md). | `~/.claude/output-styles/<name>.md` |
| [`rules/`](rules/) | Cross-harness and harness-specific rules. Nothing here is installed since 2026-09-07 — see [`rules/README.md`](rules/README.md) for where each rule's guidance went. | not installed |

Future cluster members (slots, not yet populated): `plugins/`, `commands/`, `agents/`, `mcp-servers/`. Created when the first item of each type arrives.

### Other consumables (read or copy-paste)

| Path | What |
|---|---|
| [`guides/`](guides/) | Evergreen how-tos for Claude Code workflows. |
| [`git-hooks/`](git-hooks/) | Git hooks installed into a target repository, not the harness. See [`git-hooks/README.md`](git-hooks/README.md). |
| [`reference/`](reference/) | Snapshots, inventories, lookups. |
| [`templates/`](templates/) | Project bootstrap scaffolds. See [`templates/README.md`](templates/README.md). |

Future cluster members: `prompts/` (when first prompt lands).

Each top-level directory has its own `README.md` acting as a catalog with install / usage details for the items inside.

## `docs/` — the project's working memory

`docs/` records how this repo evolves: the lifecycle of each piece of work (brainstorm → design → plan → retro), the ongoing indexes that orient new readers (ROADMAP, CHANGELOG), and the persistent decisions that outlive any single phase (ADRs). Authored by whoever's working on the project — human, AI, or both — and structured so anyone can answer "what did we decide and why?" without archaeology.

For the conventions that shape `docs/` (and that you can adopt in your own projects via [`templates/default-project/`](templates/default-project/)), see [`guides/guide-project-structure-and-conventions.md`](guides/guide-project-structure-and-conventions.md).

## Quick start

To install a skill from this repo:

```bash
SKILL=learn   # ← or whichever skill you want
mkdir -p ~/.claude/skills/$SKILL
curl -fsSL -o ~/.claude/skills/$SKILL/SKILL.md \
  https://raw.githubusercontent.com/carlosboeing/claude-code-resources/main/skills/$SKILL/SKILL.md
```

See [`skills/README.md`](skills/README.md) for the full skill catalog and project-level install instructions.

**Setting up on a new machine (or handing this to a colleague)?** See [`guides/guide-new-machine-setup.md`](guides/guide-new-machine-setup.md) — clone the two repos, run the skill link script, wire up the tools.

## Conventions (in this repo)

- **Filenames** carry their type as a prefix: `guide-*.md`, `reference-*.md`. Slightly redundant with the directory name, but means a file is self-describing if it gets emailed, gisted, or pasted somewhere on its own.
- **Skills** live one-per-directory under `skills/<name>/SKILL.md` to match the harness layout — drop-in compatible with `~/.claude/skills/`.
- **Guides** are stable how-tos. **Reference** docs are snapshots / inventories / lookups (status at a point in time, not a process).

## Adding a new artifact type

The repo scales by adding top-level directories within the **Harness mirrors** cluster — one per Claude Code artifact type, each mirroring the layout under `~/.claude/` so installs are obvious. Likely future additions: `plugins/`, `hooks/`, `commands/`, `agents/`, `mcp-servers/`, `output-styles/`. The **Other consumables** cluster grows similarly — `prompts/` is the most likely next addition.

When you add the *first* item of a new type, three rules:

1. **Create the directory only when you have the first real item.** No empty placeholders.
2. **Write `<type>/README.md` at the same time as the first item.** It's the catalog: a one-line description of the type, a shared install snippet, a table of items, and any conventions specific to that type. Use [`skills/README.md`](skills/README.md) as the template.
3. **One subdirectory per non-trivial item** (multi-file, has its own README, scripts, references). Single-file artifacts with no docs can live flat in the type directory, but realistically each item earns its own subdir + `README.md` once you want it shareable.

Notes on the awkward cases:

- **Plugins** are bundles — they contain their own skills, hooks, commands. Keep `plugins/<name>/` intact rather than flattening into the per-type dirs. The plugin's internal layout matches the marketplace install structure.
- **MCP servers** can be polyglot. `mcp-servers/<name>/` holds source in whatever language; the README documents how to wire it into `claude_desktop_config.json` or project `.mcp.json`.
- **Skills inside plugins** vs **standalone skills**: separate. A standalone skill at `skills/foo/` can be later bundled into `plugins/bar/skills/foo/` if it earns promotion. Don't symlink — install paths differ.

## Sharing individual files

Most files in this repo are designed to stand alone:

- A skill's `SKILL.md` is the entire skill — paste, install, done.
- Guides and references are self-contained markdown — gist them, slack them, copy into another project.

If something here references the wider repo (table of contents, sibling links), it's a bug — file an issue or send a PR.

## License

MIT. Take, fork, modify, attribute or don't.
