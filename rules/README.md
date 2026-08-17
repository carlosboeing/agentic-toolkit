# Rules (`rules/`)

Harness-specific and cross-harness rule files. Rules are targeted instructions injected into the system prompt of AI harnesses to guide tool usage, enforce conventions, or configure agent behavior without modifying the base instructions file.

This directory is the canonical authoring source for rules, mirroring the installation topologies across harnesses (`~/.claude/rules/` and `~/.agents/rules/`).

---

## Topology & Harness Mapping

* **Claude Code**: Reads rules from `~/.claude/rules/*.md`.
* **Google Antigravity (`agy`)**: Discovers rules from global `~/.agents/rules/*.md` and project `.agents/rules/*.md`. Antigravity requires YAML frontmatter (`trigger: always_on` or matching trigger condition).
* **Kimi Code & Codex**: Read rules shared via `~/.agents/rules/` or global instructions.

---

## Global Install Pattern

To install authored rules globally so they are active across all projects without cluttering individual project trees:

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
| [`antigravity-rtk-rules.md`](antigravity-rtk-rules.md) | Google Antigravity (`agy`) | Directs the Antigravity agent to prefix shell commands with `rtk` (e.g. `rtk git status`) to save tokens. Requires `trigger: always_on` frontmatter. |
| [`context7.md`](context7.md) | Claude Code, Codex, Antigravity | Directs agents to fetch live documentation via `ctx7` CLI when querying libraries and frameworks. |
