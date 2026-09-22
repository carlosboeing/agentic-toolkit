# Output styles (`output-styles/`)

Claude Code output styles that shape how the assistant writes.

No styles live here now. The one this directory held, **Plain English**, moved to [`carlosboeing/copydesk`](https://github.com/carlosboeing/copydesk) on 2026-08-19, when the tool that generates it was extracted.

## Plain English lives in CopyDesk now

The style is no longer hand-maintained. It is generated from CopyDesk's rule data by `scripts/generate-carriers.py`, so the style, the linter and the per-turn reminder cannot drift apart.

```bash
npm install -g copydesk
```

Configure the installed CopyDesk version through its setup wizard:

```bash
copydesk setup
```

Review the wizard's changes before applying them. It can install more than an output style, including instruction text and hooks. Do not use the old `output-styles/plain-english.md` symlink recipe: that generated path is not a stable installation interface. See [CopyDesk's current setup instructions](https://github.com/carlosboeing/copydesk#readme), checked at commit `0553163c3061b4a2db33ca7d8002ba3ba08374b7` on 2026-09-22.

Output styles are a Claude Code mechanism. Codex, Antigravity, Kimi Code and Grok Build TUI have no equivalent, and receive the same rules through their instructions files instead.

See [CopyDesk's README](https://github.com/carlosboeing/copydesk#readme) for the gate and the on-demand skill, which are the parts a style alone cannot provide.
