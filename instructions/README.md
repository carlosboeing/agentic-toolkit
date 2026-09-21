# Instructions (`instructions/`)

The canonical global agent instruction file, and the regression test that guards it. Moved here on 2026-09-08 from `carlosboeing/claude-config`, which this directory retires.

| File | What it is |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | The instruction file every harness reads. `~/.claude/CLAUDE.md` is a symlink to it. |
| [`STABILITY.md`](STABILITY.md) | Observable success criteria, change discipline and a symptom log for the setup. The falsifiable test for any edit to `CLAUDE.md`. |

---

## How it reaches each harness

One real file, six readers, no copies.

```
agentic-toolkit/instructions/CLAUDE.md
  <- ~/.claude/CLAUDE.md                 (symlink)
       <- ~/.agents/AGENTS.md            (symlink, Kimi Code)
       <- ~/.codex/AGENTS.md             (symlink)
       <- ~/.gemini/GEMINI.md            (symlink, Antigravity)
       <- ~/.config/opencode/AGENTS.md   (symlink)
       <- Grok Build, through compat.claude.agents in ~/.grok/config.toml
```

A symlink chain was chosen over a generated file. Per-harness generation was evaluated and declined on 2026-09-07: it would save about 727 words per Claude Code session, and it would add the first artifact in this setup that can drift. A symlink cannot drift.

The cost of that choice is recorded, not hidden. Claude Code receives the CopyDesk writing rules twice, once here and once in `~/.claude/output-styles/copydesk.md`. `copydesk doctor` reports it without being asked.

---

## Rules for editing `CLAUDE.md`

- A change applies to every harness. Scope it to one only when the instruction is harness-specific, and label that section.
- Prefer harness-neutral wording.
- Do not add per-harness installer boilerplate.
- Antigravity stops reading at 24,023 characters. Measure before you commit a large addition: `wc -c instructions/CLAUDE.md`. It measured 16,275 on 2026-09-07.
- Ask the Anthropic question of every line: would removing this cause a mistake? If not, cut it.

---

## Rules for editing `STABILITY.md`

Append to the symptom log. Never rewrite an entry, because the log is the baseline a later regression is measured against.

Each entry names three things: the behaviour observed, the issue identified with a file or rule reference, and the action taken with a commit reference.

---

## What CopyDesk writes here

`copydesk setup` splices its block between `<!-- copydesk:start -->` and `<!-- copydesk:end -->` in `CLAUDE.md`. It resolves symlinks first (`wizard.py:458`), so it writes into this file rather than into `~/.claude/`.

Do not hand-edit that region. Run `copydesk setup --repair` instead.

---

## Verify the chain

```bash
ls -l ~/.claude/CLAUDE.md ~/.agents/AGENTS.md ~/.codex/AGENTS.md \
      ~/.gemini/GEMINI.md ~/.config/opencode/AGENTS.md
```

Every path must resolve to `instructions/CLAUDE.md` in this repository. A broken link means a harness runs with no instructions and says nothing about it.
