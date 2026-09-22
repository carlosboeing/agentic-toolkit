# agentic-toolkit

A portable library of skills, hooks, instructions, templates and conventions for AI coding agents. It works with Claude Code, OpenAI Codex, Google Antigravity, Kimi Code, Grok Build TUI and OpenCode.

Use it if you work in more than one AI coding harness and want the same skills, rules and delivery process in each, without keeping separate copies in sync by hand.

## What it solves

| Problem | How the toolkit handles it |
|---|---|
| Every harness needs its own copy of the same skills, and the copies drift apart | One skill hub on disk. Each harness reads it through a link, and one script keeps it current. |
| Long instruction files use up context on every turn | A short global brief, plus skills that load only for the task that needs them |
| Agents skip design, testing or review | A delivery workflow with an explicit review stop between each phase |
| Private notes leak into public repositories | Public and private repositories kept apart, and a pre-commit guard that refuses private paths |
| Each harness has different install paths and hook support | Guides that map skills, plugins, MCP servers and hooks across harnesses |

## How it fits together

The repository is the source. `scripts/sync-toolkit.sh` copies its skills into a hub at `~/.claude/skills`, then links each harness's skill directory to that hub.

```mermaid
flowchart TB
    Repo["agentic-toolkit repository"] --> Sync["scripts/sync-toolkit.sh"]
    Sync --> Hub["Skill hub: ~/.claude/skills"]
    Hub --> Claude["Claude Code reads the hub directly"]
    Hub --> Agents["~/.agents/skills link"]
    Agents --> Codex["Codex"]
    Agents --> Kimi["Kimi Code"]
    Hub --> Gemini["~/.gemini/config/skills link"]
    Gemini --> Antigravity["Antigravity"]
    Hub --> OpenCode["OpenCode reads the hub, plus generated slash commands"]
    Hub --> Grok["Grok Build TUI reads the hub through Claude compatibility"]
```

Because every harness reads the same files, a skill updated in the repository reaches all of them after one sync.

## Delivery workflow

The toolkit's skills and conventions follow one delivery process. Each phase ends with a review, and implementation starts only after the plan is approved.

```mermaid
flowchart TB
    Brainstorm["Brainstorm"] --> Design["Design"]
    Design --> Plan["Implementation plan"]
    Plan --> Build["Build in an isolated worktree"]
    Build --> Verify["Tests and checks"]
    Verify --> Review["Review and CI"]
    Review --> Ship["Merge"]
```

The [project structure and conventions guide](guides/guide-project-structure-and-conventions.md) explains where each phase's documents live and how they link together.

## Quick start

You need Git, Bash and `rsync`. The contributor test suite also needs Python 3, `jq` and ShellCheck.

### Sync everything to your harnesses

Clone the repository, preview the changes, then apply them:

```bash
git clone https://github.com/carlosboeing/agentic-toolkit.git
cd agentic-toolkit
./scripts/sync-toolkit.sh --dry-run --harness
./scripts/sync-toolkit.sh --harness
```

`--harness` writes only under your home directory. It copies the skills into the hub, links each installed harness to it, and copies the Mermaid validation hook. OpenCode loads that hook automatically. Claude Code needs it registered in `settings.json`, as described in the [validator's README](hooks/validate-mermaid/README.md). The script skips any harness whose configuration directory does not exist.

The `--all` mode also installs Git hooks into the repositories it finds in your projects directory. Run `./scripts/sync-toolkit.sh --dry-run --all` first to see which repositories it would change.

### Install a single skill

Copy the whole skill directory, because some skills include scripts, schemas or reference files:

```bash
skill_name=schedule-resume
mkdir -p "$HOME/.claude/skills/$skill_name"
cp -R "skills/$skill_name/." "$HOME/.claude/skills/$skill_name/"
```

Claude Code reads `~/.claude/skills`. Codex and Kimi Code read `~/.agents/skills`, and Antigravity reads `~/.gemini/config/skills`. The [skills catalog](skills/README.md) explains how to link those directories to the hub.

### Use the shared instruction file

If you keep a local clone, link the global instruction file instead of copying it, so edits in the repository take effect everywhere:

```bash
mkdir -p "$HOME/.claude"
ln -s "$PWD/instructions/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
```

Back up any existing `~/.claude/CLAUDE.md` first. The [new-machine setup guide](guides/guide-new-machine-setup.md) covers the links for the other harnesses.

### Start a new project from the template

```bash
npx degit github:carlosboeing/agentic-toolkit/templates/default-project new-project
```

## Components

### Skills

| Skill | What it does |
|---|---|
| [`briefing`](skills/briefing/) | Summarizes a project's current state from Git, GitHub and its tracking files |
| [`learn`](skills/learn/) | Explains a commit, pull request, file, symbol or topic at the level you choose |
| [`schedule-resume`](skills/schedule-resume/) | Schedules an agent session to resume later, for example after a usage limit resets |
| [`repo-standards`](skills/repo-standards/) | Checks or applies a repository's governance files, workflows and branch protection |
| [`penmark-comments`](skills/penmark-comments/) | Reviews a local Markdown file and can write inline review comments into it |
| [`git-worktrees`](skills/git-worktrees/) | Sets where worktrees go and the checks to run before changing branches |
| [`housekeeping`](skills/housekeeping/) | Finds branches and worktrees left behind by merged pull requests, and removes them on request |
| [`start-planning`](skills/start-planning/) | Starts an implementation plan from an approved design |
| [`capture-meeting`](skills/capture-meeting/) | Turns a meeting recording and notes into a project record |
| [`externalize-deliverable`](skills/externalize-deliverable/) | Makes a client-safe copy of an internal document, with a required human review |
| [`oss-standards`](skills/oss-standards/) | Shortcut for `repo-standards` in open-source mode |

The [skills catalog](skills/README.md) lists each skill's commands, dependencies and install notes.

### Hooks

| Hook | When it runs | What it does |
|---|---|---|
| [Drift guard](git-hooks/drift-guard/) | Before push, after merge, or on demand | Blocks a push when tracking records are out of date, and reports branches left behind by merges |
| [Private workbench guard](git-hooks/private-workbench-guard/) | Before commit | Refuses commits that stage private paths or a nested private repository |
| [Mermaid validator](hooks/validate-mermaid/) | After an agent edits a Markdown file | Parses each Mermaid diagram and reports syntax errors |

### Guides and references

| Resource | Use it to |
|---|---|
| [Project structure and conventions](guides/guide-project-structure-and-conventions.md) | Organize a project's documents, frontmatter and tracking files |
| [AI model and effort routing](guides/guide-ai-model-and-effort-routing.md) | Choose a model and effort level for a task |
| [Harness plugin parity](guides/guide-harness-plugin-parity.md) | Match skills, plugins, MCP servers and hooks across harnesses |
| [Harness capability map](reference/reference-harness-capability-map.md) | Compare what each harness supports |
| [OSS repository standard](reference/reference-oss-standards.md) | Set up community files, pinned workflows and branch protection |

See [`guides/`](guides/) and [`reference/`](reference/) for the full lists.

### Other directories

| Directory | Contents |
|---|---|
| [`templates/`](templates/) | Project scaffolds for private and open-source repositories, and a lean Claude Code settings file |
| [`instructions/`](instructions/) | The global instruction file shared by every harness |
| [`plugins/`](plugins/) | An installer for the Superpowers plugin across harnesses |
| [`rules/`](rules/) | Rule files that a harness can load on every session |
| [`docs/adrs/`](docs/adrs/) | Architecture decision records |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | What is planned and what has shipped |
| [`docs/CHANGELOG.md`](docs/CHANGELOG.md) | Release history |

## Limitations

- The synchronizer installs this repository's own skills and hooks. It does not install third-party tools or create instruction-file links.
- A harness link is created only if that harness's configuration directory already exists.
- `--adopt` replaces a real skill directory in a harness with a link to the hub. Compare any same-named skills before using it.
- Guides that mention model names, quotas or prices record the date they were checked. Verify them against the vendor before relying on them.
- The Mermaid validator checks syntax, not layout.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. It covers the local checks, the commit message format and the required CI check.

Report security issues privately through [GitHub Security Advisories](https://github.com/carlosboeing/agentic-toolkit/security/advisories/new). The project follows the [Contributor Covenant](CODE_OF_CONDUCT.md), and [SUPPORT.md](SUPPORT.md) explains where to ask for help.

## License

The code and documentation are under the [MIT License](LICENSE). [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) lists material from other projects and its licenses.
