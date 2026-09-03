# Templates

Project-bootstrap scaffolds for starting a new project that follows the conventions in [`guides/guide-project-structure-and-conventions.md`](../guides/guide-project-structure-and-conventions.md).

## Catalog

| Template | What |
|---|---|
| [`default-project/`](default-project/) | Private-base scaffold: `CLAUDE.md`, `README.md`, `docs/` skeleton, `.gitignore`, plus base governance (`.github/CODEOWNERS`, `.github/dependabot.yml`, `.github/PULL_REQUEST_TEMPLATE.md`). |
| [`default-project-oss/`](default-project-oss/) | Public OSS superset: `default-project` + `CODE_OF_CONDUCT.md`, `SECURITY.md`, `SUPPORT.md`, `CONTRIBUTING.md`, `LICENSE`, `.github/ISSUE_TEMPLATE/*.yml` (private -> public via `/repo-standards fix oss`). |
| [`lean-claude-settings/`](lean-claude-settings/) | A lean `.claude/settings.json` (connectors off + finance plugins off) for running Claude Code with minimal startup context. See [`guide-trimming-claude-code-startup-context.md`](../guides/guide-trimming-claude-code-startup-context.md). |

(More variants may land later — software-with-tests, docs-only, infrastructure, etc. Out of v1 scope.)

## Use

Two paths to bootstrap a new project from `default-project/`:

```bash
# Option A — without cloning (recommended; uses degit to fetch the subdirectory):
npx degit github:carlosboeing/claude-code-resources/templates/default-project <new-project-path>

# Option B — from an existing local clone (replace <path-to-repo> with your clone path):
cp -r <path-to-repo>/templates/default-project <new-project-path>

cd <new-project-path>
# Substitute <PROJECT_NAME> placeholders via editor or sed:
#   grep -rl '<PROJECT_NAME>' . | xargs sed -i '' 's/<PROJECT_NAME>/your-project-name/g'   # macOS
#   grep -rl '<PROJECT_NAME>' . | xargs sed -i 's/<PROJECT_NAME>/your-project-name/g'      # Linux
git init && git add . && git commit -m "chore: bootstrap repo with project structure conventions"
```

Option A pulls the subdirectory directly from GitHub (no manual clone, no path assumptions); Option B is for operators who already have the repo cloned and prefer not to depend on `npx`/`degit`.

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

`system/` and `architecture.md` are NOT scaffolded — they're created on demand when README's `## Architecture` section overflows. See the conventions guide for the promotion path.
