# `/learn` — Educational explainer skill for Claude Code

A single-file [Claude Code skill](https://docs.claude.com/en/docs/claude-code/skills) that turns any commit, PR, file, folder, symbol, behaviour, or topic into a software-engineering lesson tailored to someone who is still learning.

It names the concrete decisions in the code, ties principles to the lines that embody them, links every named concept inline to a canonical reference, and stays honest when there's nothing big to teach.

Designed for engineers using Claude Code to *write* code who also want to *understand* what just got produced — bridging the gap between code that works and knowing why it's structured the way it is.

---

## What it does

Type `/learn` (with or without args) in any Claude Code session and you get a structured 5- or 6-section lesson:

1. **What this is** / what changed
2. **Why it's structured this way** (the deliberate decisions, with alternatives shown)
3. **Concepts at play** — SOLID, design patterns, cohesion/coupling, error-handling style, etc., with inline links to Wikipedia / Martin Fowler's bliki / MDN / official language docs
4. *(Topic mode only)* **Where this lives in your codebase** — concrete `path:line` references mapping the concept to your actual code
5. **What an experienced engineer would still call out** — the honest critical-review pass
6. **Further reading** — one or two canonical pointers, only when warranted

Refactors, async changes, and control-flow rewrites also get a Mermaid diagram when one earns its keep.

## Targets — what `/learn` accepts

The skill auto-detects the target type from the syntactic shape of what you type.

| Target shape | Looks like | What you get |
|---|---|---|
| **Diff** *(default)* | empty, `pr [<N>]`, `<sha>`, `HEAD~N`, `HEAD^`, branch, tag, range | What changed in that commit/PR/range and why |
| **Static** | a path that exists (`src/auth/`, `package.json`) | File or folder walkthrough |
| **Symbol** | a bare identifier ripgrep finds as a function/class/type | What this symbol does + key call sites |
| **Trace** | quoted natural-language question (`"how does login work"`) | Path through the code end-to-end |
| **Topic** | the literal `topic <name>` | Concept-first lesson, then mapped to your codebase |
| **Help** | `help`, `?`, `usage`, `--help`, `-h` | Render usage and stop |

## Dials — how the lesson is shaped

Three knobs you can mix and match. Order doesn't matter; put them anywhere in the args.

| Dial | Keywords | Default | Effect |
|---|---|---|---|
| **Level** | `expert` (or `deep`/`technical`/`staff`), `simple` (or `beginner`/`plain`), `eli5` (or `grandma`/`grandmother`) | `standard` | Jargon density. `eli5` leads with non-code analogies before naming any concept. |
| **Depth** | `quick` (or `peek`), `overview`, `deep-dive` (or `deepdive`/`audit`) | `overview` | Codebase coverage in topic and folder modes. `deep-dive` is hard-capped at 20 files. |
| **Save** | `save` (or `--save`/`export`) | off | Write the lesson to `<repo>/.claude/learn-log/` (or `~/.claude/learn-log/` outside a git repo). |

## Built-in topic vocabulary

19 canonical topics ship with curated search terms and named sub-concepts:

`auth` · `dependency-injection` · `error-handling` · `logging` · `observability` · `validation` · `state-management` · `routing` · `caching` · `concurrency` · `security` · `performance` · `i18n` · `accessibility` · `layering` · `domain-modeling` · `api-design` · `data-access` · `testing`

Off-list topics are handled with a hybrid fallback: the skill admits it's improvising and lists the search terms it derived, then runs anyway.

## Install

User-level — works in every project on your machine:

```bash
mkdir -p ~/.claude/skills/learn
cp skills/learn/SKILL.md ~/.claude/skills/learn/SKILL.md
```

(If you're not in a clone of this repo, download `SKILL.md` directly from GitHub: `curl -o ~/.claude/skills/learn/SKILL.md https://raw.githubusercontent.com/carlosboeing/claude-code-resources/main/skills/learn/SKILL.md`.)

Restart Claude Code (or start a new session). Type `/` and you should see `learn` in the slash-command menu, with the inline argument hint `[target] [expert|simple|eli5] [quick|overview|deep-dive] [save] [help]`.

To verify it's loaded, type `/learn help` — you should get the synopsis with no execution.

### Project-level alternative

If you only want it in one repo (and want to commit it for teammates), drop the file at `<repo>/.claude/skills/learn/SKILL.md` instead. Project-level skills override user-level ones with the same name, and travel with the repo.

### Uninstall

```bash
rm -rf ~/.claude/skills/learn   # or the project-level path
```

## Usage examples

```
# ─── Diff mode — what changed ───────────────────────────────
/learn                               # last commit on HEAD
/learn pr 42                         # specific PR
/learn pr 42 simple                  # PR 42, plain language
/learn HEAD~3 eli5 save              # 3 commits back, analogy-first, saved
/learn main..feature                 # a range of commits

# ─── Static mode — what's there ─────────────────────────────
/learn src/auth/                     # folder walkthrough
/learn src/auth/login.ts             # single file, top-to-bottom
/learn package.json eli5             # explain dependency tree as analogy

# ─── Symbol mode — what this thing does ─────────────────────
/learn OrderProcessor                # class walk + key call sites
/learn handleLogin simple            # function walk in plain language

# ─── Trace mode — how a behaviour flows ─────────────────────
/learn "how does login work"
/learn "where does the API rate limit get applied"

# ─── Topic mode — concept + grounded in your code ───────────
/learn topic auth                    # default depth (overview)
/learn topic dependency-injection eli5
/learn topic caching deep-dive save  # exhaustive audit, saved
/learn topic obscure-pattern         # off-list — skill admits and improvises

# ─── Help ───────────────────────────────────────────────────
/learn help
/learn ?
```

## Saved lessons (`learn-log`)

When you append `save`, the lesson is written to disk so it can be re-read later — and so any Mermaid diagrams in it render properly (the Claude Code CLI doesn't render Mermaid; saved files do, in any markdown viewer).

- **Location**: `<repo>/.claude/learn-log/` if you're in a git repo, else `~/.claude/learn-log/`.
- **Filename**: `YYYY-MM-DD-<short-sha-or-pr>-<level>.md` (e.g. `2026-05-01-cfc4afb-eli5.md`).
- **Frontmatter**: `type`, `target`, `level`, `date`, `target-title` — searchable.
- **Overwrite policy**: never silent. If the filename already exists, a `-2`, `-3`, … suffix is appended.
- **Gitignore**: not auto-ignored. Whether to commit your learn-log is up to you and your team.

## Design philosophy

A few load-bearing rules — read these if you want to understand why the skill behaves as it does, or if you want to extend it:

- **Plain English first; jargon second.** Every named concept gets defined the first time it appears. The level dial controls how aggressively this rule fires.
- **Anti-fabrication, applied to citations.** Never invent a URL. If a link isn't certain, the skill verifies via WebFetch or writes a search hint instead. A wrong link is worse than no link.
- **Don't manufacture lessons.** A typo fix gets a one-paragraph response that says so. SOLID does not get dragged into every commit. Recognising "there's nothing big at play" is itself a lesson.
- **Don't manufacture diagrams.** Same rule, applied to Mermaid.
- **Don't manufacture topic hits.** If `/learn topic caching` finds no caching layer in your codebase, that's a finding, not a failure.
- **Concrete to abstract, every time.** Pattern: here's the line, here's the principle, here's why the principle matters in practice. Never a principle without the line that embodies it.
- **Bounded by design.** Hard 20-file cap on `deep-dive`; the skill stops and says so. Reaching the cap is itself a finding.
- **Single file.** All ~500 lines of skill behaviour, including the topic vocabulary, live in one `SKILL.md`. Easy to share, easy to extend (add a row to the vocabulary table; no new files).

## Requirements

- **Claude Code** installed (any recent version).
- **`git`** for diff mode (almost certainly already installed).
- **`gh` CLI** authenticated, if you want to use `pr <N>` mode against private repos.
- **`ripgrep`** (`rg`) for symbol, trace, and topic modes — install with `brew install ripgrep`, `apt install ripgrep`, etc.

## Sharing

This whole thing is one `SKILL.md` file. To share with someone:

1. Send them the GitHub link, or paste `SKILL.md` directly.
2. They put it at `~/.claude/skills/learn/SKILL.md`.
3. Restart Claude Code.

That's it. No package install, no plugin marketplace, no auth setup.

## Extending

Common edits:

- **Add a topic** — add one row to the *Built-in topic vocabulary* table in `SKILL.md`. Search terms go in column 3, named sub-concepts in column 4. The dispatcher picks it up automatically.
- **Add a level synonym** — add the keyword to the closed set in the *How to gather the change* section's args parser. Same pattern for save / help / depth synonyms.
- **Tweak the citation source allowlist** — the *Citations and links → Source preference* section. The anti-fabrication rule keeps the skill honest no matter what sources you allow.

## License

MIT — share freely, modify freely.
