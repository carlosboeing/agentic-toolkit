# Output styles (`output-styles/`)

Claude Code output styles that shape how the assistant writes.

No styles live here now. The one this directory held, **Plain English**, moved to [`carlosboeing/copydesk`](https://github.com/carlosboeing/copydesk) on 2026-08-19, when the tool that generates it was extracted.

## Plain English lives in CopyDesk now

The style is no longer hand-maintained. It is generated from CopyDesk's rule data by `scripts/generate-carriers.py`, so the style, the linter and the per-turn reminder cannot drift apart.

```bash
npm install -g copydesk
```

Install the style by pointing at the generated file in a CopyDesk checkout:

```bash
ln -s "$(pwd)/output-styles/plain-english.md" ~/.claude/output-styles/plain-english.md
```

Then activate it with `/config`, selecting **Plain English** under **Output style**, or set it in a settings file:

```json
{
  "outputStyle": "Plain English"
}
```

Output styles are a Claude Code mechanism. Codex, Antigravity, Kimi Code and Grok Build TUI have no equivalent, and receive the same rules through their instructions files instead.

See [CopyDesk's README](https://github.com/carlosboeing/copydesk#readme) for the gate and the on-demand skill, which are the parts a style alone cannot provide.
