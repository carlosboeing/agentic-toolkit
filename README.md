# agentic-toolkit

Cross-harness toolkit for AI coding agents: shared instructions, skills, hooks, and sync tooling for Claude Code, Codex, Antigravity, Kimi Code, Grok, and OpenCode, plus the SDLC conventions they run under.

## 1. Purpose

AI coding agents are most effective when guided by structured workflows, verifiable quality gates, and portable tooling. `agentic-toolkit` provides a shared foundation across six daily harnesses:
- **Harness-neutral instructions**: A single instruction brief and workflow rules shared across multiple harnesses.
- **Portable skills**: Reusable capabilities for planning, review, browser automation, and scheduled task continuation.
- **Workflow & quality gates**: Git hooks for drift guard and privacy boundaries that run uniformly across local environments.
- **Synchronization tooling**: Automated discovery and setup across user-level configuration directories.

## 2. Contents

The toolkit is organized into installable resources and adoptable methodology.

### Installable resources

| Directory | What it contains | Install target |
|---|---|---|
| [`instructions/`](instructions/) | Canonical global agent instruction brief. See [`instructions/README.md`](instructions/README.md). | `~/.claude/CLAUDE.md` (and symlinked harnesses) |
| [`skills/`](skills/) | Multi-file and single-file agent skills. See [`skills/README.md`](skills/README.md). | `~/.claude/skills/<name>/` (the hub) |
| [`hooks/`](hooks/) | Lifecycle hooks (prompt validation, tool filters). See [`hooks/README.md`](hooks/README.md). | `~/.claude/hooks/` |
| [`git-hooks/`](git-hooks/) | Repository git hooks (drift guard, workbench privacy). See [`git-hooks/README.md`](git-hooks/README.md). | Target repo `.git/hooks/` or `scripts/githooks/` |
| [`output-styles/`](output-styles/) | Output style definitions. See [`output-styles/README.md`](output-styles/README.md). | `~/.claude/output-styles/` |
| [`rules/`](rules/) | Cross-harness rule definitions. See [`rules/README.md`](rules/README.md). | Target harnesses |
| [`plugins/`](plugins/) | Installers and wrappers for plugins such as Superpowers. See [`plugins/README.md`](plugins/README.md). | Target harnesses |

### Adoptable methodology

| Directory | What it contains |
|---|---|
| [`guides/`](guides/) | Evergreen operational how-tos for browser automation, new machine setup, model and effort routing, and conventions. |
| [`reference/`](reference/) | Cross-harness model comparisons, capability maps, and OSS house standards. |
| [`templates/`](templates/) | Project bootstrap scaffolds for internal and open-source repositories. See [`templates/README.md`](templates/README.md). |
| [`docs/adrs/`](docs/adrs/) | Architectural Decision Records documenting persistent design choices. |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Forward view and progress tracking. |
| [`docs/CHANGELOG.md`](docs/CHANGELOG.md) | Historical record of changes and releases. |

## 3. Skill installation

Several skills in this repository (such as `schedule-resume`, `penmark-comments`, and `briefing`) are multi-file packages containing helper scripts, schemas, or reference assets. To install a skill, copy its complete directory rather than a single file:

```bash
# 1. Clone the toolkit into a temporary directory
TMP_DIR=$(mktemp -d)
git clone https://github.com/carlosboeing/agentic-toolkit.git "$TMP_DIR/agentic-toolkit"

# 2. Copy the desired skill directory to your harness skills directory
# Example for Claude Code (or the shared hub):
SKILL=schedule-resume
mkdir -p ~/.claude/skills/$SKILL
cp -R "$TMP_DIR/agentic-toolkit/skills/$SKILL/"* ~/.claude/skills/$SKILL/

# 3. Clean up the temporary clone
rm -rf "$TMP_DIR"
```

For harness-specific skill discovery and hub-and-spoke setup, see [`skills/README.md`](skills/README.md).

## 4. Synchronization tooling

The toolkit includes [`scripts/sync-toolkit.sh`](scripts/sync-toolkit.sh) to automate discovery and installation across all detected harnesses.

> [!NOTE]
> In non-interactive mode, `sync-toolkit.sh` writes into `$HOME` directories (such as `~/.claude/skills/`, `~/.agents/skills/`, `~/.gemini/config/skills/`) and installs git hooks into repository checkouts located beside this clone.

Always run with `--dry-run` first to preview changes:

```bash
./scripts/sync-toolkit.sh --dry-run
```

To apply the synchronization:

```bash
./scripts/sync-toolkit.sh
```

## 5. Methodology and conventions

The methodology behind this toolkit is documented in portable guides:
- [Project structure and conventions](guides/guide-project-structure-and-conventions.md): Numbered lifecycle phases, working-memory conventions, and frontmatter standards.
- [AI model and effort routing](guides/guide-ai-model-and-effort-routing.md): Task difficulty ladders and multi-model allocation.
- [Cross-harness model comparison](reference/reference-cross-harness-models.md): Benchmark metrics, token pricing cards, and quota dynamics.
- [Browser automation](guides/guide-browser-automation-mcp-vs-cli.md): Decision matrix for Playwright MCP versus CLI execution.
- [Project templates](templates/README.md): Bootstrap scaffolds for new repositories.

## 6. Contribution, support, and license

### Contributing

Contributions are welcome. Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) for local verification checks, coding conventions, and PR expectations.

### Security and support

To report security issues, please use the [GitHub Security Advisory](https://github.com/carlosboeing/agentic-toolkit/security/advisories/new). For general inquiries or defects, open an issue on the repository.

### License

This project is licensed under the MIT License. The copyright notice and permission notice must be retained in all copies or substantial portions of the software. See [`LICENSE`](LICENSE) for the full text.
