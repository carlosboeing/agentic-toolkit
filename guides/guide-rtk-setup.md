---
title: RTK Token Killer Setup Guide
type: guide
scope: [harness-parity, rtk, token-savings, CLI-proxy, hooks, kimi-code, grok]
authors:
  - "Carlos Boeing"
  - "k3 (kimi-code)"
  - "grok-4.6 (grok)"
last_reviewed: 2026-08-17
related:
  - guide-harness-plugin-parity.md
  - guide-claude-mem-setup.md
  - guide-headroom-setup.md
---

# RTK Token Killer Setup Guide

This guide documents the unified configuration and hook integrations of **RTK (Rust Token Killer)** across seven AI coding harnesses: Claude Code, Antigravity (`agy`), Cursor, Codex, OpenCode, Kimi Code, and Grok Build TUI.

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

### 2. Antigravity CLI & IDE (BeforeTool Hook)
Antigravity intercepts `run_shell_command` tool calls globally using a custom shell hook script. Both the Antigravity CLI and the Antigravity IDE load settings from their respective global user directories, ensuring a project-agnostic setup.

*   **Hook Script**: [~/.gemini/hooks/rtk-hook-gemini.sh](~/.gemini/hooks/rtk-hook-gemini.sh)
    ```bash
    #!/bin/bash
    exec rtk hook gemini
    ```
*   **Settings Files (Global Scope)**:
    *   **Antigravity CLI (`agy`)**: [~/.gemini/antigravity-cli/settings.json](~/.gemini/antigravity-cli/settings.json)
    *   **Antigravity IDE**: [~/.gemini/settings.json](~/.gemini/settings.json)
*   **Wiring**:
    Copy this block into the `"hooks"` object of **both** settings files:
    ```json
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
    ```

> [!NOTE]
> **Upstream Integration (PR 2093)**:
> An open pull request [rtk-ai/rtk#2093](https://github.com/rtk-ai/rtk/pull/2093) introduces a native hook command `rtk hook antigravity` (alias `rtk hook agy`) and initialization support via `rtk init --agent antigravity`. Until this PR is merged and released, we use the backward-compatible `rtk hook gemini` (via `rtk-hook-gemini.sh`), which successfully intercepts and rewrites the identical `run_shell_command` tool payload globally.


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

### 6. Kimi Code (Instruction-based)
Kimi's hook events can allow or deny a tool call but cannot rewrite `tool_input`, so the transparent rewrite hook RTK uses on Claude Code is impossible here. RTK runs instruction-driven, the same integration class as Codex.
*   **Setup**: `rtk init --agent kimi` (requires rtk ≥ 0.44.0 — earlier versions have no kimi target; upgrade with `brew upgrade rtk` and make sure the binary on your PATH is the new one)
*   **Method**: project-scoped `AGENTS.md` instructions direct the agent to prefix commands with `rtk`. The global `~/.agents/AGENTS.md` RTK section (loaded natively by Kimi) reinforces the same "no trusted hook → explicitly prefix" rule.
*   **Verify**: run a Kimi session, then `rtk gain` should show activity.

### 7. Grok Build TUI (Instruction-based)

Grok can deny and rewrite on PreToolUse, but Claude hook ingest is off, and the inherited `rtk hook claude` payload does not parse Grok's camelCase (`toolInput.command`). `rtk init --agent grok` does not exist. Do not run any other `rtk init` as a stand-in.

*   **Setup**: none beyond the global `~/.claude/CLAUDE.md` RTK section (Grok already loads it). Explicitly prefix shell commands with `rtk`.
*   **Method**: instruction-driven, the same class as Codex and Kimi.
*   **Verify**: in a Grok session run `rtk git status`, then `rtk gain` should show the record. No project `AGENTS.md` RTK boilerplate should appear.

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
