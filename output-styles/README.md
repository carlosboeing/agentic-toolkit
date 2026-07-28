# Output styles

[Claude Code output styles](https://code.claude.com/docs/en/output-styles) are Markdown files that modify Claude Code's system prompt to change how it communicates — role, tone, and output format — without changing what it knows. A style with `keep-coding-instructions: true` keeps all of Claude Code's built-in software engineering instructions and only adds to them. Styles apply to the main conversation only (subagents run their own system prompt), and Claude Code injects periodic adherence reminders mid-session.

## Catalog

| Style | File | What it does |
|---|---|---|
| Plain English | [`plain-english.md`](plain-english.md) | Structured but plain writing — full technical content, simpler sentences, no AI-isms. Keeps coding instructions. The rules block is kept in sync with the `### Writing style` section of `~/.claude/CLAUDE.md` (claude-config repo), which carries the same rules to other harnesses and subagents. |

(Add more rows as new styles land.)

## Install

Symlink the style into the user-level output-styles directory (same authoring pattern as skills — edits in this repo are live immediately):

```bash
mkdir -p ~/.claude/output-styles
ln -s "$(pwd)/output-styles/plain-english.md" ~/.claude/output-styles/plain-english.md
```

Then activate it, either by running `/config` and selecting **Plain English** under **Output style**, or by setting it directly in a settings file (e.g. `~/.claude/settings.json`):

```json
{
  "outputStyle": "Plain English"
}
```

The `outputStyle` value must match the style's frontmatter `name` exactly, or Claude Code silently falls back to the Default style.

Output styles are read once at session start — changes (including activation) take effect after `/clear` or the next new session.

## Other harnesses

Output styles are a Claude Code mechanism — Codex, Antigravity, and Kimi Code have no equivalent. On those harnesses the same plain-English rules arrive through the `### Writing style` section of the shared `~/.agents/AGENTS.md` (which Kimi reads natively), without the system-prompt reinforcement layer.

If a symlinked style file is ever not recognized, replace the symlink with a real copy and re-copy after edits:

```bash
cp output-styles/plain-english.md ~/.claude/output-styles/plain-english.md
```

## Uninstall

```bash
rm ~/.claude/output-styles/plain-english.md
```

Remove or change the `outputStyle` setting to switch back to the Default style.
