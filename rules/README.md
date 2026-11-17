# Rules

A rule is a short instruction file that a harness adds to the agent's system prompt, to guide tool use without editing the main instruction file.

Nothing in this directory is installed by default. Every rule loaded globally reaches every session in every harness, and together they pushed the combined instructions past what Antigravity would read. The files stay here so a rule can be installed again if one ever needs to load on every session.

## Catalog

| Rule | Harnesses | What it tells the agent | Where the guidance lives now |
|---|---|---|---|
| [`context7.md`](context7.md) | Claude Code, Codex, Antigravity | Fetch current library documentation with the `ctx7` CLI | The `find-docs` and `context7-mcp` skills, which load their procedure only when a library question comes up |
| [`antigravity-rtk-rules.md`](antigravity-rtk-rules.md) | Antigravity | Prefix shell commands with `rtk`, for example `rtk git status`, to reduce output tokens | The RTK section of the global instruction file |

## Where each harness looks for rules

| Harness | Location |
|---|---|
| Claude Code | `~/.claude/rules/*.md` |
| Antigravity | `~/.agents/rules/*.md` globally and `.agents/rules/*.md` per project. Each file needs YAML frontmatter with `trigger: always_on` or another trigger condition. |
| Codex and Kimi Code | Their `AGENTS.md` instruction files. A link in `~/.agents/rules/` does not make either one load a Markdown rule. Codex's `.rules` files are a different format for command permissions. See [Codex instruction discovery](https://developers.openai.com/codex/guides/agents-md/). |

## Installing rules globally

Do this only if a rule must load on every session. Afterwards, check that each file stays under 24,000 bytes and that the global instruction file plus the rules fit Antigravity's 20,000-token budget for always-on rules ([rules docs](https://antigravity.google/docs/rules), checked 2026-11-17).

```bash
mkdir -p ~/.claude
ln -sfn "$(pwd)/rules" ~/.claude/rules
mkdir -p ~/.agents
ln -sfn ~/.claude/rules ~/.agents/rules
```
