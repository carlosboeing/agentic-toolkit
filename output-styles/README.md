# Output styles

Claude Code output styles change how the assistant writes. This directory is empty for now.

The Plain English style that used to live here now ships with [CopyDesk](https://github.com/carlosboeing/copydesk), which generates it from the same rule data as its linter and per-turn reminder, so the three stay consistent.

## Install Plain English

Install CopyDesk and run its setup wizard:

```bash
npm install -g copydesk
copydesk setup
```

Review the wizard's changes before you apply them. It can install hooks and write to instruction files. Keep the [toolkit's shared writing rules](../instructions/README.md#writing-rules) out of the wizard's changes. See [CopyDesk's setup instructions](https://github.com/carlosboeing/copydesk#readme), checked on 2026-09-22 at commit `0553163c3061b4a2db33ca7d8002ba3ba08374b7`.

The output style is for Claude Code. Supported harnesses read the toolkit's writing rules through the shared brief.
