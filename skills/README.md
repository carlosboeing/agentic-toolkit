# Skills

[Claude Code skills](https://docs.claude.com/en/docs/claude-code/skills) are single-file (or small bundle) extensions that add behaviours and slash commands. Each skill here is drop-in: copy its `SKILL.md` into your harness's skills directory (e.g. `~/.claude/skills/<name>/`), or symlink the whole repo across all your harnesses with [`sync-skills.sh`](sync-skills.sh) — see [Install](#install-any-skill-in-this-directory).

## Catalog

| Skill | Slash command | What it does |
|---|---|---|
| [`learn`](learn/) | `/learn` | Turns any commit, PR, file, folder, symbol, behaviour, or topic into a software-engineering lesson. Six target shapes, three audience levels (`expert`/`simple`/`eli5`), three depth dials (`quick`/`overview`/`deep-dive`), optional save-to-disk. |
| [`briefing`](briefing/) | `/briefing` | Manually invoked project orientation. No automatic activation for task follow-ups. Convention-aware but not convention-coupled: reads git, GitHub, top-level files, and per-project memory universally; lights up with richer behaviour when canonical conventions (`## Project Map`, lifecycle dirs, status frontmatter, ROADMAP sections) are detected; renders a read-only maturity-check footer on partial adoption. Three depth dials (`quick`/`standard`/`deep`) controlling length × source breadth × speed; optional save-to-disk. |
| [`capture-meeting`](capture-meeting/) | `/capture-meeting` | Turn an AI meeting recording (Fathom or other tool) plus manual notes/artifacts into an audited meeting doc, then propagate decisions/action items to working memory. |
| [`externalize-deliverable`](externalize-deliverable/) | `/externalize-deliverable` | Derive clean, client-safe versions of internal documents by stripping sensitive company-side information (negotiations, margins, internal flags) under a human review gate. |
| [`schedule-resume`](schedule-resume/) | `/schedule-resume` | Bundled skill with a shell helper for scheduling unattended, cross-harness Claude/Agy/Codex/Kimi session continuation through cron (one crontab line per job; macOS-tested). |
| [`repo-standards`](repo-standards/) | `/repo-standards` | Apply the repo house standard - `check|fix [oss|private] [path]`, `scaffold <name> [oss|private]`. Auto-detects `gh repo view --json visibility`, reads `reference/reference-oss-standards.md`, never generates SHAs. |
| [`oss-standards`](oss-standards/) | `/oss-standards` | Alias for `/repo-standards oss` - deprecated, prefer `/repo-standards`. |
| [`housekeeping`](housekeeping/) | `/housekeeping` | Full audit of local branches and registered worktrees against GitHub pull requests, reporting what merges left behind and removing verified stale local state. `audit` (default) checks all branches and worktrees; `check` covers the last pull window; `fix` refreshes, rechecks, and deletes removable local branches/worktrees. Never deletes a remote branch. |
| [`penmark-comments`](penmark-comments/) | — | Reviews writable local Markdown, then asks once whether findings go in the file as validated Penmark v1 comments or stay in chat. Remembers the answer. |
| [`git-worktrees`](git-worktrees/) | — | The cross-harness worktree path convention `<repo>/.worktrees/<harness>/<branch>`, when a worktree is required rather than offered, and the two corrections to `superpowers:using-git-worktrees`. Moved out of `~/.claude/CLAUDE.md`, where it reached every session to serve implementation sessions only. |
| [`start-planning`](start-planning/) | `/start-planning` | Starts implementation planning from a design in a fresh session. Path optional: resolves the design from the project when omitted. Holds the planning-phase boundary; discovers the project's planner, paths, and review rules instead of defining them. |

(Add more rows as new skills land. Per-skill `README.md` carries the detail.)

### Skills that live in another repository

Two skills that used to sit under `tools/revloop/` are no longer in this repo at all. **CrossRev was extracted to [`carlosboeing/crossrev`](https://github.com/carlosboeing/crossrev) on 2026-08-13** and its skills travelled with it, the same way a plugin bundle keeps its own `skills/` intact rather than flattening into the per-type directory.

| Skill | Where | What it does |
|---|---|---|
| `pr-review` | [`carlosboeing/crossrev`](https://github.com/carlosboeing/crossrev/tree/main/skills/pr-review) | Reviews a pull request as one leg of the CrossRev loop. Reads a diff and prior threads supplied in the prompt and returns findings as schema-constrained JSON anchored to file and line. Holds no GitHub credential by design |
| `pr-resolve` | [`carlosboeing/crossrev`](https://github.com/carlosboeing/crossrev/tree/main/skills/pr-resolve) | Verifies each finding against the codebase, fixes what is real, pushes back on what is wrong, and returns dispositions and reply text as intent for the orchestrator to act on |

Install them from the public repo. No `--skill` filters: its `skills/` holds exactly these two, so naming them selects everything and can only go stale.

```bash
npx skills@latest add carlosboeing/crossrev
```

CrossRev itself does not need them installed — it reproduces their text into each prompt from its own checkout. Install them if you want to invoke them by hand.

`skills/sync-skills.sh` in this repo syncs them into the hub from a local CrossRev checkout, which it expects at `~/Projects/carlos/crossrev/skills` unless `CROSSREV_SKILLS` says otherwise.

## Install (any skill in this directory)

For a single-file skill, user-level installation works in every project on your machine:

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
  https://raw.githubusercontent.com/carlosboeing/agentic-toolkit/main/skills/$SKILL/SKILL.md
```

Restart Claude Code (or start a new session). Type `/` and the skill should appear in the slash-command menu.

Bundled skills need their full directory, not only `SKILL.md`. Follow the bundle's README for its required scripts and references; for example, [Penmark Comments](penmark-comments/README.md) includes a writer contract and validator.

### Mirror install (symlink — for authoring across harnesses)

If you *develop* skills here rather than just consume them, symlink instead of copying, so edits in this repo are live immediately — no re-copy step, one source of truth:

```bash
./skills/sync-skills.sh
```

It symlinks every authored `skills/<name>/` in this clone straight into each **installed** harness's skill directory — `~/.claude/skills/`, `~/.agents/skills/` (Codex + cross-harness agents), and `~/.gemini/config/skills/` (Antigravity) — using this clone's own path (portable, nothing hardcoded). Idempotent; skips harnesses that aren't installed; never overwrites a real directory (a non-symlink skill is skipped with a warning). Edit the `TARGETS` list in the script to change which harnesses it covers.

It is independent of the `find-skills` tool — it only creates symlinks and never touches find-skills' lockfile or its installed skills. The symlinks are local wiring; they stay untracked by design. See [`../guides/guide-harness-plugin-parity.md`](../guides/guide-harness-plugin-parity.md) for the full cross-harness model.

Use copy/curl above to *share* a skill; use this to *author* one across your harnesses.

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
