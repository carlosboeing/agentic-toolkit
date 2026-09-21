# Skills

Each directory contains a portable agent skill in the `SKILL.md` format used by Claude Code and compatible harnesses. Some skills also contain scripts, schemas, tests, or references, so install the complete directory unless its README explicitly says otherwise.

## Catalog

| Skill | Command | Purpose |
|---|---|---|
| [`briefing`](briefing/) | `/briefing` | Produces a manual project orientation from Git, GitHub, top-level files, and declared project records. It does not activate for focused follow-up questions. |
| [`learn`](learn/) | `/learn` | Explains a commit, pull request, file, folder, symbol, behavior, or topic at a selected audience level and depth. |
| [`schedule-resume`](schedule-resume/) | `/schedule-resume` | Bundled skill with a shell helper that schedules unattended continuation through launchd on macOS or cron on Linux. Supports Claude Code, Antigravity, Codex, and Kimi Code sessions. |
| [`repo-standards`](repo-standards/) | `/repo-standards` | Checks, fixes, or scaffolds the repository's public and private governance standards from the canonical reference. |
| [`oss-standards`](oss-standards/) | `/oss-standards` | Compatibility alias for `/repo-standards oss`. New automation should call `repo-standards` directly. |
| [`housekeeping`](housekeeping/) | `/housekeeping` | Audits local branches and worktrees against GitHub pull requests, then removes only verified merged residue in `fix` mode. |
| [`penmark-comments`](penmark-comments/) | Automatic or explicit | Reviews local Markdown and can write validated Penmark v1 comments after the user chooses the output location. |
| [`git-worktrees`](git-worktrees/) | Automatic | Defines the cross-harness worktree path and the checks required before branch-state changes. |
| [`start-planning`](start-planning/) | `/start-planning` | Starts implementation planning from an approved design and preserves the design-to-plan phase boundary. |
| [`capture-meeting`](capture-meeting/) | `/capture-meeting` | Converts a meeting recording, notes, and artifacts into an audited project record. |
| [`externalize-deliverable`](externalize-deliverable/) | `/externalize-deliverable` | Creates a client-safe copy of an internal document under a required human review gate. |

Each skill's README documents its arguments, dependencies, installation requirements, and design decisions.

## Install one skill

Clone the repository, then copy the complete directory into the Claude Code hub:

```bash
skill_name=learn
mkdir -p "$HOME/.claude/skills/$skill_name"
cp -R "skills/$skill_name/." "$HOME/.claude/skills/$skill_name/"
```

Start a new harness session after installing a skill. Skills with slash commands should appear in that harness's command or skill browser. Model-invoked skills may not appear in a slash menu.

## Synchronize every authored skill

The repository-level synchronizer copies authored skills into `~/.claude/skills`, then repairs the whole-directory spokes for Codex, Kimi Code, and Antigravity. It also writes OpenCode command wrappers and the OpenCode Mermaid validator.

Inspect the harness-only changes before applying them:

```bash
./scripts/sync-toolkit.sh --dry-run --harness
./scripts/sync-toolkit.sh --harness
```

`skills/sync-skills.sh` remains as a compatibility forwarder to `scripts/sync-toolkit.sh --harness`.

The topology is:

| Path | Role | Consumers |
|---|---|---|
| `~/.claude/skills` | Hub containing real skill directories | Claude Code, OpenCode, Grok through Claude compatibility |
| `~/.agents/skills` | Whole-directory symlink to the hub | Codex and Kimi Code |
| `~/.gemini/config/skills` | Whole-directory symlink to the hub | Antigravity |
| `~/.codex/skills` | Codex-owned system skills, not a spoke | Codex internals |

See the [harness parity guide](../guides/guide-harness-plugin-parity.md) for the product-specific discovery rules.

## Install a project-level skill

For a skill that should travel with one repository, copy it into the project-level directory supported by that harness. Claude Code uses `.claude/skills`:

```bash
skill_name=learn
mkdir -p ".claude/skills/$skill_name"
cp -R "skills/$skill_name/." ".claude/skills/$skill_name/"
```

Project-level skills can override a user-level skill with the same name. Check the harness's precedence rules before committing a duplicate.

## CrossRev review skills

`pr-review` and `pr-resolve` moved to the public [CrossRev repository](https://github.com/carlosboeing/crossrev) with their orchestrator. Install both from that source:

```bash
npx skills@latest add carlosboeing/crossrev
```

To include a local CrossRev checkout in synchronization, add its skills directory to `EXTRA_SKILL_SOURCES` in your local configuration. See [`sync-toolkit.conf.example`](../scripts/sync-toolkit.conf.example).

## Repository conventions

- Store one skill under `skills/<name>/`.
- Keep `SKILL.md` as the harness entry point.
- Put human-facing usage and maintenance notes in the adjacent `README.md`.
- Keep a skill in one file until scripts, schemas, tests, or reference material justify a bundle.
- Document every external command or service the skill requires.

The shared installation baseline is Git, Bash, and `rsync`. Individual skill READMEs list additional tools such as `gh`, `jq`, or `ripgrep`.
