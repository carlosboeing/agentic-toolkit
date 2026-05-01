# claude-code-resources

A personal collection of [Claude Code](https://docs.claude.com/en/docs/claude-code) skills, guides, and references I've built up while using the tool day-to-day. Public-ish — designed to be shareable with friends and portable across projects, but opinionated to my workflow.

> If you've stumbled across this and find something useful, take what works. Nothing here is a polished product; it's working notes.

## Contents

```
.
├── skills/        — Claude Code skills (drop-in SKILL.md files)
│   └── learn/     — /learn — explain a commit, PR, file, symbol, behaviour, or topic as an SWE lesson
├── guides/        — How-to guides for setting up Claude Code workflows
│   └── guide-project-structure-and-conventions.md
└── reference/     — Reference docs (snapshots, inventories, lookups)
    └── reference-claude-code-plugins.md
```

## Quick start — using the skills

Skills here are single-file `SKILL.md` files designed for the Claude Code skill harness. To install one user-wide (works in every project on your machine):

```bash
mkdir -p ~/.claude/skills/<skill-name>
cp skills/<skill-name>/SKILL.md ~/.claude/skills/<skill-name>/SKILL.md
```

Restart Claude Code (or start a new session). Slash commands appear in the `/` menu.

For project-level installs (commit the skill into a repo so teammates share it), drop the file at `<repo>/.claude/skills/<skill-name>/SKILL.md`. Project-level skills override user-level ones with the same name.

### Currently shipping

- **`/learn`** — Turns any commit, PR, file, folder, symbol, behaviour, or topic into a software-engineering lesson tailored to someone still learning. Six target shapes (diff / static / symbol / trace / topic / help), three audience levels (`expert` / `simple` / `eli5`), three depth dials (`quick` / `overview` / `deep-dive`), optional save-to-disk, anti-fabrication rules for citations and topic hits. See [`skills/learn/SKILL.md`](skills/learn/SKILL.md) for the full skill.

## Conventions (in this repo)

- **Filenames** carry their type as a prefix: `guide-*.md`, `reference-*.md`. Slightly redundant with the directory name, but means a file is self-describing if it gets emailed, gisted, or pasted somewhere on its own.
- **Skills** live one-per-directory under `skills/<name>/SKILL.md` to match the harness layout — drop-in compatible with `~/.claude/skills/`.
- **Guides** are stable how-tos. **Reference** docs are snapshots / inventories / lookups (status at a point in time, not a process).

## Sharing individual files

Most files in this repo are designed to stand alone:

- A skill's `SKILL.md` is the entire skill — paste, install, done.
- Guides and references are self-contained markdown — gist them, slack them, copy into another project.

If something here references the wider repo (table of contents, sibling links), it's a bug — file an issue or send a PR.

## License

MIT. Take, fork, modify, attribute or don't.
