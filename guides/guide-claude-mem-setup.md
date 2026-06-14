---
title: Claude-mem Harness Configuration Guide
type: guide
scope: [harness-parity, claude-mem, mcp, database]
last_reviewed: 2026-06-14
related:
  - guide-harness-plugin-parity.md
  - guide-headroom-setup.md
---

# Claude-mem Harness Configuration Guide

This guide documents the unified configuration of **claude-mem** (the persistent memory plugin for Claude Code) across your AI coding harnesses: Claude Code, Antigravity (`agy`), Cursor, Codex, and OpenCode.

---

## Architecture Overview

`claude-mem` operates via a central background daemon (worker) and stores all observations, concepts, and project memories in a single, shared SQLite database.

*   **Plugin Install Directory**: `~/.claude/plugins/marketplaces/thedotmack/plugin`
*   **Active Cache Directory**: `~/.claude/plugins/cache/thedotmack/claude-mem/13.6.0`
*   **MCP Server Entrypoint**: `~/.claude/plugins/marketplaces/thedotmack/plugin/scripts/mcp-server.cjs`
*   **Database & State Directory**: `~/.claude-mem/`
*   **Central SQLite DB**: `~/.claude-mem/claude-mem.db`

---

## Unified Config Map

Each harness is wired to invoke the exact same `mcp-server.cjs` entrypoint and access the same `claude-mem.db` instance, ensuring instant memory sync regardless of which tool is active.

### 1. Claude Code (Native Plugin)
Claude Code manages the plugin lifecycle natively.
*   **Config File**: [~/.claude/settings.json](~/.claude/settings.json)
*   **Registration**:
    ```json
    "enabledPlugins": {
      "claude-mem@thedotmack": true
    }
    ```

### 2. Antigravity (MCP Server)
Antigravity integrates `claude-mem` as an external Model Context Protocol server.
*   **Config File**: [~/.gemini/config/mcp_config.json](~/.gemini/config/mcp_config.json)
*   **Registration**:
    ```json
    "claude-mem": {
      "command": "/opt/homebrew/Cellar/node/24.1.0/bin/node",
      "args": [
        "~/.claude/plugins/marketplaces/thedotmack/plugin/scripts/mcp-server.cjs"
      ]
    }
    ```

### 3. Cursor (MCP Server)
Cursor integrates `claude-mem` as a global stdio MCP server.
*   **Config File**: [~/.cursor/mcp.json](~/.cursor/mcp.json)
*   **Registration**:
    ```json
    "claude-mem": {
      "command": "node",
      "args": [
        "~/.claude/plugins/marketplaces/thedotmack/plugin/scripts/mcp-server.cjs"
      ]
    }
    ```

### 4. Codex (Plugin)
Codex integrates `claude-mem` natively as a runtime plugin.
*   **Config File**: [~/.codex/config.toml](~/.codex/config.toml)
*   **Registration**:
    ```toml
    [plugins."claude-mem@claude-mem-local"]
    enabled = true
    ```

### 5. OpenCode (Plugin)
OpenCode integrates `claude-mem` as a local Javascript plugin.
*   **Config File**: [~/.config/opencode/opencode.json](~/.config/opencode/opencode.json)
*   **Registration**:
    ```json
    "plugin": [
      "./plugins/claude-mem.js"
    ]
    ```

---

## Verification & Troubleshooting

### Check Worker Daemon Status
To check if the central worker daemon is running and check its process ID:
```bash
cat ~/.claude-mem/worker.pid
cat ~/.claude-mem/supervisor.json
```

### Verify Tools in Sessions
*   **In Antigravity**: Start a session and run `/skills`. Check for the presence of `mcp__claude-mem__*` tools.
*   **In Claude Code**: Run `/plugin list` or `/skills` to confirm that the plugin is running.
*   **In Cursor**: Open **Cursor Settings > Features > MCP** and ensure the `claude-mem` entry shows a green "Connected" status dot during active chat.

---

## References
*   **Upstream Repository**: [thedotmack/claude-mem](https://github.com/thedotmack/claude-mem)
*   **Harness Parity Guide**: [guide-harness-plugin-parity.md](~/Projects/agentic-toolkit/guides/guide-harness-plugin-parity.md)
