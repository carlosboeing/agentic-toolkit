# Guides

These guides document repeatable operating procedures for AI coding harnesses and the repositories they modify. A guide describes the current method. Dated inventories and measurements belong in [`reference/`](../reference/).

## Catalog

| Guide | Use it for |
|---|---|
| [`guide-new-machine-setup.md`](guide-new-machine-setup.md) | Restoring the shared instructions, skill hub, hooks, plugins, and OpenCode configuration on a new machine |
| [`guide-project-structure-and-conventions.md`](guide-project-structure-and-conventions.md) | Structuring project documentation, lifecycle records, frontmatter, roadmaps, and private working-memory sidecars |
| [`guide-cross-harness-project-instructions.md`](guide-cross-harness-project-instructions.md) | Sharing one project brief through `CLAUDE.md`, `AGENTS.md`, and `GEMINI.md` |
| [`guide-harness-plugin-parity.md`](guide-harness-plugin-parity.md) | Mapping plugins, skills, Model Context Protocol (MCP) servers, hooks, and browser tools across harnesses |
| [`guide-ai-model-and-effort-routing.md`](guide-ai-model-and-effort-routing.md) | Selecting models and effort levels by task shape, cost, quota, and escalation signals |
| [`guide-agy-model-and-quota-selection.md`](guide-agy-model-and-quota-selection.md) | Choosing Antigravity models and handling its quota and session behavior |
| [`guide-browser-automation-mcp-vs-cli.md`](guide-browser-automation-mcp-vs-cli.md) | Choosing Playwright MCP, the Playwright command-line interface, or a live browser tool for agent-driven browser work |
| [`guide-creating-claude-code-skills.md`](guide-creating-claude-code-skills.md) | Designing a skill's activation boundary, command surface, instructions, file layout, and failure behavior |
| [`guide-penmark-agent-integration.md`](guide-penmark-agent-integration.md) | Installing and validating the Penmark inline-comment workflow |
| [`guide-rtk-setup.md`](guide-rtk-setup.md) | Installing RTK and selecting transparent-hook or explicit-prefix operation per harness |
| [`guide-claude-mem-setup.md`](guide-claude-mem-setup.md) | Installing and verifying claude-mem session memory |
| [`guide-trimming-claude-code-startup-context.md`](guide-trimming-claude-code-startup-context.md) | Measuring and reducing Claude Code startup context without removing required integrations |
| [`guide-headroom-setup.md`](guide-headroom-setup.md) | Understanding the retired Headroom setup and the steps needed to remove it safely |

The CrossRev credentials guide moved to the public [CrossRev repository](https://github.com/carlosboeing/crossrev/blob/main/docs/credentials.md) with the tool on 2026-08-13.

## Conventions

- Name files `guide-<topic>.md` so a copied file remains identifiable outside this repository.
- Start each guide with YAML frontmatter containing `title`, `type: guide`, `scope`, `last_reviewed`, `authors`, and relevant `related` links.
- Update `last_reviewed` only after verifying the procedure from start to finish.
- Keep paragraphs on one source line and use tables or lists where readers need to compare repeated fields.
- Move point-in-time measurements, inventories, and product snapshots to [`reference/`](../reference/).

## Share a guide

Copy the Markdown file or link to its public GitHub path. Relative links are kept narrow so a guide can travel without bringing the entire repository.
