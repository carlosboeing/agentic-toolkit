# <PROJECT_NAME>

<One-line description of what this project is.>

**Current state:** see [`## Architecture`](#architecture) below. (When this section grows past one page, move content to `docs/architecture.md` and replace this section with a 1-line pointer.)
**What's in flight:** see [`docs/ROADMAP.md`](docs/ROADMAP.md).
**What's shipped:** see [`docs/CHANGELOG.md`](docs/CHANGELOG.md).
**For Claude Code sessions:** [`CLAUDE.md`](CLAUDE.md) is the auto-loaded brief.

## Architecture

<!--
Keep this section here while it fits in one page (~5 subsections, no per-aspect diagrams needed).
When it grows past that, move content to docs/architecture.md and replace this section with:
> See [docs/architecture.md](docs/architecture.md).
When architecture.md itself outgrows one file, promote to docs/architecture/overview.md + per-aspect files
(this is the only convention-blessed promotion path; other single-file evergreen content stays flat).
-->

<Replace this placeholder with a brief HLD: what the major components are, how they connect, what runs where.>

## Repo layout

```
.
├── CLAUDE.md           — Claude Code session brief
├── README.md           — this file
├── docs/               — project's working memory (brainstorms, designs, plans, retros, ADRs, ROADMAP, CHANGELOG)
└── ...                 — project-specific code, configs, scripts (add as needed)
```

## Conventions

This project follows [`guide-project-structure-and-conventions.md`](https://github.com/carlosboeing/agentic-toolkit/blob/main/guides/guide-project-structure-and-conventions.md). Key points:

- One canonical place per question (ROADMAP for "what's next", ADRs for decisions, etc.).
- Conventional Commits for git (`<type>(<scope>): <description>`).
- Self-describing filenames: lifecycle artifacts dated, evergreen content named for what it is.

## License

<Add a license. MIT recommended unless your project has different needs.>
