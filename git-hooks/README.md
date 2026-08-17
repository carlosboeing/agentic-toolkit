# git-hooks/

Git hooks — `pre-commit`, `pre-push` and friends — installed into a **target repository**, not into the harness.

Not to be confused with [`hooks/`](../hooks/), which holds Claude Code *lifecycle* hooks wired into `settings.json` and mirrored to `~/.claude/hooks/`. Those intercept the agent's tool calls. These run in git, for anyone committing, agent or human.

## Install (shared pattern)

Each hook is versioned **inside** the target repository rather than sourced from here, so a fresh clone carries it:

```bash
HOOK=private-workbench-guard   # ← or whichever hook you want
REPO=~/Projects/carlos/crossrev

mkdir -p "$REPO/scripts/githooks"
cp "$HOOK/pre-commit" "$REPO/scripts/githooks/pre-commit"
chmod +x "$REPO/scripts/githooks/pre-commit"
git -C "$REPO" config core.hooksPath scripts/githooks
```

**`core.hooksPath` is per clone and git will not set it for you.** That is deliberate on git's part — a hook that ran automatically on clone would be a remote code execution vector — so the config line is repeated on every machine. Check it with `git config --get core.hooksPath`.

## Catalog

| Hook | Event | What it does |
|---|---|---|
| [`private-workbench-guard/`](private-workbench-guard/) | `pre-commit` | For a public repository with an independent private clone nested inside it. Refuses a commit that stages the workbench as a gitlink, or that adds private-side vocabulary to a public file. |
| [`plain-english/`](../tools/plain-english/git-hooks/) | `pre-commit` | Runs the Plain English test suite to ensure linter checks and canonical rules block sync do not regress. |

## Conventions for this type

- One directory per hook, named for what it guards rather than which event it uses.
- The script filename is the git hook name (`pre-commit`), so installing is a copy rather than a rename.
- Each directory's `README.md` carries the pattern it serves, what the hook checks, **and what it deliberately does not do** — the rejected designs matter as much as the shipped one, or they get rebuilt.
- Every pattern that can produce false positives is measured against real history before shipping, and the numbers go in the README. A hook that fires on legitimate commits gets bypassed reflexively, which is worse than no hook.
