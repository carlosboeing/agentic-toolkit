# hooks/

Claude Code lifecycle hooks — shell scripts wired into `settings.json` events (`PreToolUse`, `PostToolUse`, `Stop`, …) so the harness enforces behavior deterministically, instead of relying on the model remembering a convention. This directory mirrors `~/.claude/hooks/`.

**Looking for git hooks?** They are in [`git-hooks/`](../git-hooks/). These intercept the agent's tool calls; those run in git, for anyone committing, and install into a target repository rather than into `~/.claude/`.

## Install (shared pattern)

1. Copy the hook script into place and make it executable:

```bash
HOOK=validate-mermaid   # ← or whichever hook you want
mkdir -p ~/.claude/hooks
curl -fsSL -o ~/.claude/hooks/$HOOK.sh \
  https://raw.githubusercontent.com/carlosboeing/claude-code-resources/main/hooks/$HOOK/$HOOK.sh
chmod +x ~/.claude/hooks/$HOOK.sh
```

2. Merge the hook's settings fragment (in each item's README) into `~/.claude/settings.json` under `"hooks"`, then run `/hooks` once (or restart) so the session reloads config.

## Catalog

| Hook | Event | What it does |
|---|---|---|
| [`validate-mermaid/`](validate-mermaid/) | `PostToolUse` on `Write\|Edit` | Parse-validates every Mermaid block in a modified `.md` file; blocks with actionable feedback when a block won't render. |

## Conventions for this type

- One subdirectory per hook: `hooks/<name>/<name>.sh` + `README.md` (purpose, requirements, settings fragment, failure behavior).
- Scripts read the hook JSON payload from stdin and must **fail open** on infrastructure problems (missing tools, unparseable payload) — a hook that blocks all writes because its validator is missing is worse than no hook.
- Keep the fast path fast: bail out in milliseconds for files/events the hook doesn't care about — `PostToolUse` on `Write|Edit` fires on *every* file Claude touches.
- Exit `2` + stderr is the blocking-feedback channel on `PostToolUse`: the message is fed back to the model, which fixes the problem and retries. Write stderr for the model, not for a human log.

## Other harnesses

Kimi Code has a hooks system too (`[[hooks]]` in `~/.kimi-code/config.toml`), but its event semantics differ in two load-bearing ways: only `PreToolUse`, `Stop`, and `UserPromptSubmit` can block (its `PostToolUse` is observation-only), and no event can rewrite tool input. Blocking validators like `validate-mermaid` therefore stay Claude-only; interception hooks of the RTK command-rewriting kind are impossible on Kimi.
