# Output styles

Claude Code output styles change how the assistant writes. This directory is empty for now.

The Plain English style that used to live here now ships with [CopyDesk](https://github.com/carlosboeing/copydesk), which generates it from the same rule data as its linter and per-turn reminder, so the three stay consistent.

## Install Plain English

Install CopyDesk and run its setup wizard:

```bash
npm install -g copydesk
copydesk setup
```

Review the wizard's changes before you apply them. Besides the output style, it can add instruction text and hooks. See [CopyDesk's setup instructions](https://github.com/carlosboeing/copydesk#readme), checked on 2026-09-22 at commit `0553163c3061b4a2db33ca7d8002ba3ba08374b7`.

Output styles exist only in Claude Code. Codex, Antigravity, Kimi Code and Grok Build TUI get the same rules through their instruction files.
