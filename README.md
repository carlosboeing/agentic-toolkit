# claude-code-resources

A personal collection of [Claude Code](https://docs.claude.com/en/docs/claude-code) skills, guides, and references I've built up while using the tool day-to-day. Public-ish — designed to be shareable with friends and portable across projects, but opinionated to my workflow.

> If you've stumbled across this and find something useful, take what works. Nothing here is a polished product; it's working notes.

## Contents

```
.
├── skills/        — Claude Code skills (drop-in SKILL.md files). See skills/README.md for the catalog.
├── guides/        — How-to guides for setting up Claude Code workflows
└── reference/     — Reference docs (snapshots, inventories, lookups)
```

Each top-level directory has its own `README.md` acting as a catalog with install / usage details for the things inside. Start there.

## Quick start

To install a skill from this repo:

```bash
SKILL=learn   # ← or whichever skill you want
mkdir -p ~/.claude/skills/$SKILL
curl -fsSL -o ~/.claude/skills/$SKILL/SKILL.md \
  https://raw.githubusercontent.com/carlosboeing/claude-code-resources/main/skills/$SKILL/SKILL.md
```

See [`skills/README.md`](skills/README.md) for the full skill catalog and project-level install instructions.

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
