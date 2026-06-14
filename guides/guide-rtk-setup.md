---
title: RTK Token Killer Setup Guide
type: guide
scope: [harness-parity, rtk, token-savings, CLI-proxy, hooks]
last_reviewed: 2026-06-14
related:
  - guide-harness-plugin-parity.md
  - guide-claude-mem-setup.md
  - guide-headroom-setup.md
---

# RTK Token Killer Setup Guide

This guide documents the unified configuration and hook integrations of **RTK (Rust Token Killer)** across all five AI coding harnesses: Claude Code, Antigravity (`agy`), Cursor, Codex, and OpenCode.

---

## Architecture Overview

`rtk` is a high-performance CLI proxy written in Rust that intercepts common shell command outputs (like `git status`, `npm run build`, `eslint`, etc.) and compresses them to save 60–90%+ context tokens before the AI agent sees them.

*   **Binary Location**: `~/.local/bin/rtk`
*   **Startup Overhead**: <10ms
*   **Configuration**: Statically compiled with intelligent rewrite rules. Output compression can be monitored via local telemetry checks.

---

## Unified Integration Map

RTK uses a combination of **native agent hooks** (to rewrite commands transparently before they run) and **instruction-based guides** (where hooks are not supported).

### 1. Claude Code (PreToolUse Hook)
Claude Code intercepts Bash executions and passes them to the RTK rewrite engine.
*   **Config File**: [~/.claude/settings.json](~/.claude/settings.json)
*   **Wiring**:
    ```json
    "hooks": {
      "PreToolUse": [
        {
          "matcher": "Bash",
          "hooks": [
            {
              "type": "command",
              "command": "rtk hook claude"
            }
          ]
        }
      ]
    }
    ```

### 2. Antigravity (BeforeTool Hook)
Antigravity intercepts `run_shell_command` tool calls using a custom shell hook script.
*   **Hook Script**: [~/.gemini/hooks/rtk-hook-gemini.sh](~/.gemini/hooks/rtk-hook-gemini.sh)
    ```bash
    #!/bin/bash
    exec rtk hook gemini
    ```
*   **Settings File**: [~/.gemini/settings.json](~/.gemini/settings.json)
*   **Wiring**:
    ```json
    "hooks": {
      "BeforeTool": [
        {
          "matcher": "run_shell_command",
          "hooks": [
            {
              "type": "command",
              "command": "~/.gemini/hooks/rtk-hook-gemini.sh"
            }
          ]
        }
      ]
    }
    ```

### 3. Cursor (beforeShellExecution Hook)
Cursor intercepts shell executions globally using a lifecycle event hook.
*   **Config File**: [~/.cursor/hooks.json](~/.cursor/hooks.json)
*   **Wiring**:
    ```json
    "beforeShellExecution": [
      {
        "command": "~/.local/bin/rtk hook cursor"
      }
    ]
    ```

### 4. Codex (Instruction-based)
Codex does not support pre-shell-execution hooks. Instead, it relies on instructions loaded from the user's configuration.
*   **Config File**: [~/.codex/RTK.md](~/.codex/RTK.md)
*   **Method**: System prompt instruction forcing the agent to prefix commands (e.g. `rtk git status`).

### 5. OpenCode (Instruction-based)
OpenCode also uses instruction-based prefixing.
*   **Config File**: [CLAUDE.md](~/Projects/agentic-toolkit/CLAUDE.md)
*   **Method**: Global `CLAUDE.md` instructions dictate prefixing shell commands with `rtk` (shared via root symlinks: `AGENTS.md` and `GEMINI.md`).

---

## Verification & Management

### Basic Command Checks
To verify that the binary is in your path and working correctly:
```bash
which rtk
rtk --version
```

### Viewing Savings
To see token-saving stats globally:
```bash
rtk gain
rtk gain --history
```

### Dry-run Command Rewrites
To inspect how the RTK engine rewrites a command:
```bash
rtk hook check "git status"
```
*(Should output the rewritten target command if supported).*

---

## References
*   **Upstream Repository**: [rtk-ai/rtk](https://github.com/rtk-ai/rtk)
*   **Harness Parity Guide**: [guide-harness-plugin-parity.md](~/Projects/agentic-toolkit/guides/guide-harness-plugin-parity.md)
