# Lean Claude Code settings template

A starting `settings.json` that runs Claude Code lean — claude.ai connectors off and the finance plugins disabled. It pairs with [`guide-trimming-claude-code-startup-context.md`](../../guides/guide-trimming-claude-code-startup-context.md), which explains the mechanism and the measure loop.

## When to use it

Read this first — the right placement depends on your setup:

- **Global lean baseline (recommended).** Put `disableClaudeAiConnectors` and the plugin toggles in your **user** `~/.claude/settings.json`. Every project inherits leanness; a pure-code project needs **no** file of its own. This template is then just a reference for the keys.
- **Per-project opt-in.** If you did *not* set the global baseline, drop this file at a project's `.claude/settings.json` to make **that** project lean while others stay as-is.
- **Per-project opt-out.** For a project that genuinely needs connectors despite a global lean baseline, its `.claude/settings.json` sets `{ "disableClaudeAiConnectors": false }`.

## Important: connectors are all-or-nothing

`disableClaudeAiConnectors` is a single switch for **all** claude.ai connectors — there is no per-connector key. To keep **one** integration (e.g. Fathom, Notion) while cutting the rest, **self-host its MCP** so it survives the flag:

```bash
claude mcp add --scope user fathom -- npx mcp-remote@latest https://api.fathom.ai/mcp
```

Add and verify the self-hosted server **before** enabling the flag, so nothing breaks. See the guide for the full pattern.

## Notes

- Disabling connectors in Claude Code does **not** affect the claude.ai web/desktop apps.
- Adjust the `enabledPlugins` list to your own marketplace/plugin identifiers — confirm exact keys with `jq '.enabledPlugins' ~/.claude/settings.json`.
- `claude-in-chrome` is not a plugin or connector; drop it with `claude --no-chrome` (see the guide), not this file.
- Always re-measure with `/context` after a restart.
