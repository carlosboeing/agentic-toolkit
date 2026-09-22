# Guides

Step-by-step guides for setting up and working with AI coding harnesses. Each guide describes the current method. Dated facts, such as product capabilities, belong in [`reference/`](../reference/).

## Catalog

### Setup

| Guide | Use it to |
|---|---|
| [`guide-new-machine-setup.md`](guide-new-machine-setup.md) | Set up the shared instructions, skill hub, hooks, plugins and OpenCode configuration on a new machine |
| [`guide-rtk-setup.md`](guide-rtk-setup.md) | Install RTK and choose between automatic hooks and explicit `rtk` prefixes for each harness |
| [`guide-claude-mem-setup.md`](guide-claude-mem-setup.md) | Install and check claude-mem session memory |
| [`guide-trimming-claude-code-startup-context.md`](guide-trimming-claude-code-startup-context.md) | Measure and reduce how much context Claude Code uses before your first message |

### Working across harnesses

| Guide | Use it to |
|---|---|
| [`guide-cross-harness-project-instructions.md`](guide-cross-harness-project-instructions.md) | Share one project brief through `CLAUDE.md`, `AGENTS.md` and `GEMINI.md` |
| [`guide-harness-plugin-parity.md`](guide-harness-plugin-parity.md) | Match plugins, skills, MCP servers, hooks and browser tools across harnesses |
| [`guide-ai-model-and-effort-routing.md`](guide-ai-model-and-effort-routing.md) | Choose a model and effort level by task, cost, quota and escalation signals |
| [`guide-agy-model-and-quota-selection.md`](guide-agy-model-and-quota-selection.md) | Choose Antigravity models and manage its quota and sessions |
| [`guide-browser-automation-mcp-vs-cli.md`](guide-browser-automation-mcp-vs-cli.md) | Choose between Playwright MCP, the Playwright CLI and a live browser tool |

### Project practices

| Guide | Use it to |
|---|---|
| [`guide-project-structure-and-conventions.md`](guide-project-structure-and-conventions.md) | Organize project documents, frontmatter, roadmaps and decision records |
| [`guide-creating-claude-code-skills.md`](guide-creating-claude-code-skills.md) | Design a skill: when it activates, its commands, instructions, file layout and failure behavior |
| [`guide-penmark-agent-integration.md`](guide-penmark-agent-integration.md) | Install and test the Penmark inline-comment workflow |

The CrossRev credentials guide now lives in the [CrossRev repository](https://github.com/carlosboeing/crossrev/blob/main/docs/credentials.md).

## Writing a guide

- Name the file `guide-<topic>.md`, so a copied file is still recognizable outside this repository.
- Start with YAML frontmatter: `title`, `type: guide`, `scope`, `last_reviewed`, `authors`, and any `related` links.
- Update `last_reviewed` only after following the procedure from start to finish.
- Follow the [documentation standard](../CONTRIBUTING.md#documentation-standard).
- Put point-in-time measurements and product snapshots in [`reference/`](../reference/).

## Sharing a guide

Copy the Markdown file or link to it on GitHub. Guides keep relative links to a minimum, so a single file still makes sense on its own.
