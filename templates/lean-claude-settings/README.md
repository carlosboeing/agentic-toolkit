# Lean Claude Code settings

A starting `settings.json` that turns off claude.ai connectors in Claude Code, so sessions start with less context used. It goes with the [startup context guide](../../guides/guide-trimming-claude-code-startup-context.md), which explains how to measure the effect.

## Where to put it

| Setup | Where the settings go |
|---|---|
| Lean everywhere (recommended) | Add `disableClaudeAiConnectors` to your user settings, `~/.claude/settings.json`. Every project inherits it, and this template is only a reference. |
| Lean in one project | Copy this file to that project's `.claude/settings.json`. Other projects are unaffected. |
| One project that needs connectors, when the user settings turn them off | Set `{ "disableClaudeAiConnectors": false }` in that project's `.claude/settings.json`. |

## Connectors are all or nothing

`disableClaudeAiConnectors` turns off every claude.ai connector. There is no setting for a single connector. To keep one integration, such as a meeting recorder or a notes app, add its MCP server yourself so it is not affected by the switch:

```bash
claude mcp add --scope user fathom -- npx mcp-remote@latest https://api.fathom.ai/mcp
```

Add and test the self-hosted server before turning connectors off.

## Turning off plugins

Plugins you rarely use also add to startup context. Turn one off with an `enabledPlugins` entry, using the plugin's exact `name@marketplace` key:

```json
{
  "enabledPlugins": {
    "some-plugin@some-marketplace": false
  }
}
```

List the keys you have with `jq '.enabledPlugins' ~/.claude/settings.json`.

## Notes

- This setting affects Claude Code only. The claude.ai web and desktop apps keep their connectors.
- `claude-in-chrome` is neither a plugin nor a connector. Start Claude Code with `claude --no-chrome` to leave it out.
- After changing settings, start a new session and check the result with `/context`.
