# Rules (`rules/`)

Harness-specific and cross-harness rule files. A rule is a targeted instruction injected into an AI harness's system prompt, to guide tool usage or configure agent behavior without editing the base instructions file.

**Nothing in this directory loads today.** The global install was removed on 2026-09-07, because every file here reached every session on six harnesses and the total pushed past Antigravity's 24,023-character instruction limit. The directory stays as the authoring source for the day a rule genuinely needs to load on every session.

---

## Where the guidance went

| Rule file | Where it reaches an agent now |
|---|---|
| [`context7.md`](context7.md) | The `find-docs` and `context7-mcp` skills. Both descriptions load every session, and the procedure loads only when a library question arrives. |
| [`antigravity-rtk-rules.md`](antigravity-rtk-rules.md) | The RTK section of `~/.claude/CLAUDE.md`, which names Antigravity, Codex, Kimi Code and Grok as the harnesses that need an explicit `rtk` prefix. |
| This README | Nowhere. A catalog for people is not an instruction, and it was reaching every session as one. |

---

## Topology and harness mapping

Recorded for the day a rule needs the global install back.

* **Claude Code**: reads rules from `~/.claude/rules/*.md`.
* **Google Antigravity (`agy`)**: discovers rules from global `~/.agents/rules/*.md` and project `.agents/rules/*.md`. Antigravity requires YAML frontmatter, either `trigger: always_on` or a matching trigger condition.
* **Kimi Code and Codex**: read rules shared via `~/.agents/rules/` or global instructions.

---

## Global install pattern

Removed on 2026-09-07. Run this only if a new rule must load on every session, and measure `wc -c ~/.claude/CLAUDE.md` plus the rules afterwards against the 24,023-character limit.

```bash
# Link rules directory into Claude Code and ~/.agents hubs
mkdir -p ~/.claude
ln -sfn "$(pwd)/rules" ~/.claude/rules
mkdir -p ~/.agents
ln -sfn ~/.claude/rules ~/.agents/rules
```

---

## Catalog

| Rule File | Target Harnesses | Purpose |
|---|---|---|
| [`antigravity-rtk-rules.md`](antigravity-rtk-rules.md) | Google Antigravity (`agy`) | Directs the Antigravity agent to prefix shell commands with `rtk` (e.g. `rtk git status`) to save tokens. Requires `trigger: always_on` frontmatter. Not installed. |
| [`context7.md`](context7.md) | Claude Code, Codex, Antigravity | Directs agents to fetch live documentation via the `ctx7` CLI when querying libraries and frameworks. Not installed. |
