# Templates

Project-bootstrap scaffolds for starting a new project that follows the conventions in [`guides/guide-project-structure-and-conventions.md`](../guides/guide-project-structure-and-conventions.md).

## Catalog

| Template | What |
|---|---|
| [`default-project/`](default-project/) | Private-base scaffold: `CLAUDE.md`, `README.md`, `docs/` skeleton, `.gitignore`, plus base governance (`.github/CODEOWNERS`, `.github/dependabot.yml`, `.github/PULL_REQUEST_TEMPLATE.md`). |
| [`default-project-oss/`](default-project-oss/) | Public OSS superset: `default-project` + `CODE_OF_CONDUCT.md`, `SECURITY.md`, `SUPPORT.md`, `CONTRIBUTING.md`, `LICENSE`, `.github/ISSUE_TEMPLATE/*.yml` (private -> public via `/repo-standards fix oss`). |
| [`lean-claude-settings/`](lean-claude-settings/) | A lean `.claude/settings.json` (connectors off + finance plugins off) for running Claude Code with minimal startup context. See [`guide-trimming-claude-code-startup-context.md`](../guides/guide-trimming-claude-code-startup-context.md). |

Additional variants remain out of scope until a real project needs them.

## Use

Two paths to bootstrap a new project from `default-project/`:

```bash
# Fetch only the template directory without cloning the full repository
npx degit github:carlosboeing/agentic-toolkit/templates/default-project ./new-project

# Or copy it from an existing agentic-toolkit clone
cp -R ./templates/default-project ./new-project

cd ./new-project
# Substitute <PROJECT_NAME> placeholders via editor or sed:
#   grep -rl '<PROJECT_NAME>' . | xargs sed -i '' 's/<PROJECT_NAME>/your-project-name/g'   # macOS
#   grep -rl '<PROJECT_NAME>' . | xargs sed -i 's/<PROJECT_NAME>/your-project-name/g'      # Linux
git init && git add . && git commit -m "chore: bootstrap repo with project structure conventions"
```

The first command downloads the subdirectory from GitHub. The second uses the current local clone and does not require `npx` or `degit`.

## Retrofitting an existing project

For applying these conventions to an *existing* project (not creating a new one), see the "Retrofitting an existing project" section in [`guides/guide-project-structure-and-conventions.md`](../guides/guide-project-structure-and-conventions.md). Manual procedure for now; future `/init-project` skill will automate both bootstrap and retrofit.

## What's in the template

```
default-project/  (private-base)
├── CLAUDE.md              — generic project brief (now includes OSS house-standard pointer)
├── README.md              — minimal stub with <PROJECT_NAME> placeholder
├── .gitignore             — sensible defaults
├── .github/
│   ├── CODEOWNERS         — * @<OWNER>
│   ├── dependabot.yml     — github-actions + npm weekly
│   └── PULL_REQUEST_TEMPLATE.md
└── docs/
    ├── ROADMAP.md         — six-section template
    ├── CHANGELOG.md       — empty stub
    ├── notes/             — scratch, chat dumps, research
    ├── 0-brainstorms/     — pre-design ideas
    ├── 1-discovery/       — research, spikes, analyses
    ├── 2-design/          — specs + designs
    ├── 3-plans/           — phased implementation plans
    ├── 4-reviews/         — retros, audits, reviews, analyses
    ├── adrs/              — single-decision records (NNNN-title.md)
    └── guides/            — internal procedural how-tos
```

`default-project-oss/` extends `default-project` with:
```
default-project-oss/
├── CODE_OF_CONDUCT.md
├── SECURITY.md
├── SUPPORT.md
├── CONTRIBUTING.md
├── LICENSE
└── .github/ISSUE_TEMPLATE/
    ├── bug_report.yml
    ├── feature_request.yml
    └── config.yml
```

The templates do not create `system/` or `architecture.md`. Add them only when the README's architecture section no longer holds the required detail. See the conventions guide for that promotion path.
