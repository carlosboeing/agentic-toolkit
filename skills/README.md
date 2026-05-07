# Skills

[Claude Code skills](https://docs.claude.com/en/docs/claude-code/skills) are single-file (or small bundle) extensions that add behaviours and slash commands to Claude Code. Each skill in this directory is drop-in: copy the `SKILL.md` to `~/.claude/skills/<name>/`, restart Claude Code, done.

## Catalog

| Skill | Slash command | What it does |
|---|---|---|
| [`learn`](learn/) | `/learn` | Turns any commit, PR, file, folder, symbol, behaviour, or topic into a software-engineering lesson. Six target shapes, three audience levels (`expert`/`simple`/`eli5`), three depth dials (`quick`/`overview`/`deep-dive`), optional save-to-disk. |
| [`briefing`](briefing/) | `/briefing` | Adaptive project orientation. Convention-aware but not convention-coupled: reads git, GitHub, top-level files, and per-project memory universally; lights up with richer behaviour when canonical conventions (`## Project Context`, lifecycle dirs, status frontmatter, ROADMAP sections) are detected; renders a read-only maturity-check footer on partial adoption. Three depth dials (`quick`/`standard`/`deep`) controlling length × source breadth × speed; optional save-to-disk. |

(Add more rows as new skills land. Per-skill `README.md` carries the detail.)

## Install (any skill in this directory)

User-level — works in every project on your machine:

```bash
# from a clone of this repo:
SKILL=learn   # ← replace with the skill name
mkdir -p ~/.claude/skills/$SKILL
cp skills/$SKILL/SKILL.md ~/.claude/skills/$SKILL/SKILL.md
```

Or pull a single skill straight from GitHub without cloning:

```bash
SKILL=learn
mkdir -p ~/.claude/skills/$SKILL
curl -fsSL -o ~/.claude/skills/$SKILL/SKILL.md \
  https://raw.githubusercontent.com/carlosboeing/claude-code-resources/main/skills/$SKILL/SKILL.md
```

Restart Claude Code (or start a new session). Type `/` and the skill should appear in the slash-command menu.

### Project-level alternative

To install into one repo only (and travel with the repo for teammates):

```bash
SKILL=learn
mkdir -p .claude/skills/$SKILL
cp skills/$SKILL/SKILL.md .claude/skills/$SKILL/SKILL.md
```

Project-level skills override user-level skills with the same name.

### Verify

Most skills here support a `help` keyword, e.g.:

```
/learn help
```

If you see the synopsis (and no execution), the skill loaded correctly.

### Uninstall

```bash
rm -rf ~/.claude/skills/<skill-name>      # user-level
rm -rf .claude/skills/<skill-name>        # project-level
```

## Conventions for skills in this repo

- **One directory per skill** at `skills/<name>/`. The `<name>` matches the slash command (`learn` → `/learn`).
- **`SKILL.md`** is the entire skill — drop-in compatible with the harness layout under `~/.claude/skills/`.
- **`README.md`** alongside each `SKILL.md` documents the skill for humans (what it does, dials, examples, design notes). Not loaded by the harness.
- **Single-file by default.** If a skill needs bundled scripts, references, or assets, add them under the skill's directory (`skills/<name>/scripts/` etc.) and document the install steps in that skill's `README.md`.

## Dependencies

Each skill's README lists its own dependencies (e.g. `ripgrep`, `gh` CLI). The shared baseline assumed across all skills:

- A recent **Claude Code** install
- **`git`** (almost certainly already on your machine)
