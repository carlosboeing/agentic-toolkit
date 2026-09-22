# Templates

Starting points for new projects that follow the [project structure conventions](../guides/guide-project-structure-and-conventions.md), plus a lean Claude Code settings file.

## Catalog

| Template | Use it for | Contents |
|---|---|---|
| [`default-project/`](default-project/) | A private project | `CLAUDE.md`, `README.md`, a `docs/` skeleton, `.gitignore`, and base governance files: `.github/CODEOWNERS`, `.github/dependabot.yml` and a pull request template |
| [`default-project-oss/`](default-project-oss/) | Files to add when a project becomes open source | `CODE_OF_CONDUCT.md`, `SECURITY.md`, `SUPPORT.md`, `CONTRIBUTING.md`, `LICENSE`, `THIRD_PARTY_NOTICES.md` and GitHub issue forms |
| [`lean-claude-settings/`](lean-claude-settings/) | Claude Code sessions with less startup context | A `settings.json` that turns off claude.ai connectors. See the [startup context guide](../guides/guide-trimming-claude-code-startup-context.md). |

To turn a private project into an open-source one, run `/repo-standards fix oss`, which adds the open-source files.

## Start a new project

Copy the template with `degit`, which downloads only that directory:

```bash
npx degit github:carlosboeing/agentic-toolkit/templates/default-project ./new-project
```

Or copy it from a local clone of this repository:

```bash
cp -R ./templates/default-project ./new-project
```

Then replace the `<PROJECT_NAME>` placeholders and make the first commit:

```bash
cd ./new-project
grep -rl '<PROJECT_NAME>' . | xargs sed -i '' 's/<PROJECT_NAME>/your-project-name/g'   # macOS
# grep -rl '<PROJECT_NAME>' . | xargs sed -i 's/<PROJECT_NAME>/your-project-name/g'    # Linux
git init && git add . && git commit -m "chore: bootstrap repo with project structure conventions"
```

## Apply the conventions to an existing project

See "Retrofitting an existing project" in the [conventions guide](../guides/guide-project-structure-and-conventions.md). It is a manual procedure for now.

## What the templates contain

```
default-project/
├── CLAUDE.md              project brief for AI agents
├── README.md              short stub with a <PROJECT_NAME> placeholder
├── .gitignore
├── .github/
│   ├── CODEOWNERS         * @<OWNER>
│   ├── dependabot.yml     weekly GitHub Actions and npm updates
│   └── PULL_REQUEST_TEMPLATE.md
└── docs/
    ├── ROADMAP.md         seven-section roadmap template
    ├── CHANGELOG.md       empty changelog
    ├── notes/             scratch notes and research
    ├── 0-brainstorms/     early ideas
    ├── 1-discovery/       research, spikes and analyses
    ├── 2-design/          specifications and designs
    ├── 3-plans/           implementation plans
    ├── 4-reviews/         retrospectives, audits and reviews
    ├── adrs/              architecture decision records (NNNN-title.md)
    └── guides/            internal how-to guides
```

```
default-project-oss/
├── CODE_OF_CONDUCT.md
├── SECURITY.md
├── SUPPORT.md
├── CONTRIBUTING.md
├── LICENSE
├── THIRD_PARTY_NOTICES.md
└── .github/ISSUE_TEMPLATE/
    ├── bug_report.yml
    ├── feature_request.yml
    └── config.yml
```

The templates leave out `docs/system/` and `docs/architecture.md`. Add them when the README's architecture section outgrows a page, as the conventions guide describes.
