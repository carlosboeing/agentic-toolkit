# validate-mermaid

`PostToolUse` hook on `Write|Edit` that parse-validates every fenced ` ```mermaid ` block in a modified Markdown file. When a block fails to parse, the hook exits `2` with the parser error plus the common causes, which Claude Code feeds back to the model — so a broken diagram gets fixed in the same turn it was written, instead of shipping as a red "Unable to render rich display" box on GitHub.

**Origin**: a sequence-diagram message containing `…regression; exit 1 + 180s timeout` shipped broken on 2026-06-12 — Mermaid treats `;` as a statement separator inside message text, so the line silently split and GitHub's renderer choked on the orphaned `+`. Conventions reduce the odds of writing that; this hook makes it impossible to ship.

## What it catches

Any Mermaid block the real parser rejects, including the classic silent killers:

- `;` inside message/label/note text (statement separator in every diagram type)
- Sequence-message text starting with `+`/`-` (activation markers)
- Unquoted `()[]{}|` and other grammar characters in flowchart labels

## Requirements

- `jq`
- [`@mermaid-js/mermaid-cli`](https://github.com/mermaid-js/mermaid-cli) (`npm install -g @mermaid-js/mermaid-cli`) — preferred; if `mmdc` is absent the script falls back to `npx -y -p @mermaid-js/mermaid-cli mmdc` (slower per call, but the hook keeps enforcing)

The first `mmdc` run downloads a headless browser — run it once manually after install so the hook never pays that cost: `printf 'graph TD\n a-->b\n' > /tmp/warm.mmd && mmdc -i /tmp/warm.mmd -o /tmp/warm.svg --quiet`

## Settings fragment

Merge into `~/.claude/settings.json` (global) or `.claude/settings.json` (per-project):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/validate-mermaid.sh",
            "timeout": 90,
            "statusMessage": "Validating Mermaid blocks"
          }
        ]
      }
    ]
  }
}
```

## Behavior notes

- **Fast path**: non-`.md` files, missing files, and `.md` files without a mermaid fence exit `0` in milliseconds — the browser only launches when there's something to validate.
- **Fails open**: if the payload can't be parsed or no validator is available, the hook exits `0` rather than blocking all writes.
- **Indented fences** (e.g. inside list items) are handled; each block is validated separately and reported with its starting line number.
- Validation is parse-level (the same parser GitHub uses) — it does not check styling conventions like pinned themes; those stay in your CLAUDE.md / conventions docs.
