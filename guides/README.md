# Guides

How-to guides for using Claude Code productively. Each guide is a stable, evergreen markdown file — not a snapshot, not a tutorial, but a contract that captures *how to do a thing well*.

## Catalog

| Guide | What it covers |
|---|---|
| [`guide-project-structure-and-conventions.md`](guide-project-structure-and-conventions.md) | A portable documentation structure for long-running projects: brainstorms → designs → plans → reviews → ADRs, with always-current state docs and a single ROADMAP. Originally developed for an infrastructure project; the conventions generalise. |
| [`guide-creating-claude-code-skills.md`](guide-creating-claude-code-skills.md) | A practitioner's guide to writing Claude Code skills — when to write a skill vs a hook/plugin/CLAUDE.md, how to design the command surface (arguments, dials, help mode, dispatchers), how to write the body (anti-fabrication, standing instructions), single-file vs multi-file tradeoffs, and a list of pitfalls. Drawn from shipping the `/learn` skill in this repo. |
| [`guide-cross-harness-project-instructions.md`](guide-cross-harness-project-instructions.md) | One canonical `CLAUDE.md` with `AGENTS.md` / `GEMINI.md` symlinks so Cursor, Claude Code, and Antigravity read the same project brief. |
| [`guide-harness-plugin-parity.md`](guide-harness-plugin-parity.md) | Official vs substitute vs skip mapping from Claude Code / Cursor plugins to Antigravity (`agy`) installs, skills, and MCP. |
| [`guide-browser-automation-mcp-vs-cli.md`](guide-browser-automation-mcp-vs-cli.md) | When to use Playwright MCP vs the Playwright CLI vs chrome-devtools-plugin for agentic (non-CI) browser work — exploratory browsing and aesthetics vs repeatable flows and goldens, per-harness defaults, the harness-dependent token-cost truth, and corrected myths. |
| [`guide-agy-model-and-quota-selection.md`](guide-agy-model-and-quota-selection.md) | Manual model and quota strategy for long Agy sessions — Gemini vs Claude pools, Flash/Pro/Sonnet/Opus defaults. |
| [`guide-trimming-claude-code-startup-context.md`](guide-trimming-claude-code-startup-context.md) | The durable recipe for cutting Claude Code startup context (~232k → ~74k measured): a global lean baseline (`disableClaudeAiConnectors` + finance plugins off), self-hosting the integrations you use in code (Fathom worked example) so they survive the connector flag, dropping redundant browser stacks, and the measure loop. Pairs with `reference/reference-claude-code-context-costs.md`. |

## Conventions

- Filenames are `guide-<topic>.md`. The prefix is redundant with the directory name on purpose — the file is self-describing if it gets emailed, gisted, or copied into another project.
- Each guide has YAML frontmatter (`title`, `type: guide`, `scope`, `last_reviewed`, optional `related`). The `last_reviewed` date is bumped only when the content has been verified end-to-end, not on every editorial edit.
- Guides are **evergreen** — they describe how things should be done, not how they were done at a point in time. For point-in-time material (a snapshot, an inventory, a one-off retrospective), use `reference/` or write it inside a project's own docs structure instead.

## Sharing one guide

Each guide is a self-contained markdown file. To share it, copy the file or paste a public GitHub link to it. References to other files in this repo are kept relative and minimal so guides travel cleanly.
