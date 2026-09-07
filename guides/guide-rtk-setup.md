---
title: RTK Token Killer Setup Guide
type: guide
scope: [harness-parity, rtk, token-savings, CLI-proxy, hooks, kimi-code, grok]
authors:
  - "Carlos Boeing"
  - "k3 (kimi-code)"
  - "grok-4.6 (grok)"
  - "gemini-3.7-flash (agy)"
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

*   **Binary Location**: `/opt/homebrew/bin/rtk` (managed via `brew install rtk` / `brew upgrade rtk`)
*   **Startup Overhead**: <10ms
*   **Configuration**: Statically compiled with intelligent rewrite rules. Output compression can be monitored via local telemetry checks.

---

## Unified Integration Map

RTK uses a combination of **native agent hooks** (to rewrite commands transparently before they run) and **instruction-based rules** (where transparent rewrite hooks are not yet supported).

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

### 2. Antigravity CLI & IDE (Instruction-based)
Antigravity executes shell commands via the `run_command` tool. Transparent hook rewriting is pending upstream release ([rtk-ai/rtk#2093](https://github.com/rtk-ai/rtk/pull/2093)), so Antigravity operates in **instruction mode** (the same model as Codex and Kimi Code).

*   **Source of the instruction**: the RTK section of `~/.claude/CLAUDE.md`, which Antigravity reads through `~/.agents/AGENTS.md`. It names Antigravity, Codex, Kimi Code and Grok as the harnesses needing an explicit prefix.
*   **Authored Rule, not installed**: [`rules/antigravity-rtk-rules.md`](../rules/antigravity-rtk-rules.md) (in `claude-code-resources`). The `~/.claude/rules/` and `~/.agents/rules/` symlinks were removed on 2026-09-07 to keep the instruction file under Antigravity's 24,023-character limit. Re-install it from [`rules/README.md`](../rules/README.md) if the `CLAUDE.md` wording ever stops working.
*   **Method**: System rules direct the agent to prefix shell commands explicitly with `rtk` (e.g. `rtk git status`, `rtk grep`).
*   **Verify**: Run commands in an `agy` session, then check `rtk gain`.

### 3. Cursor (beforeShellExecution Hook)
Cursor intercepts shell executions globally using a lifecycle event hook.
*   **Config File**: [~/.cursor/hooks.json](~/.cursor/hooks.json)
*   **Wiring**:
    ```json
    "beforeShellExecution": [
      {
        "command": "rtk hook cursor"
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
*   **Setup**: `rtk init --agent kimi` (requires rtk ≥ 0.44.0)
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
