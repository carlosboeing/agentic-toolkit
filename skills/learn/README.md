# learn

Turns a commit, pull request, file, folder, symbol, behavior or topic into a short software-engineering lesson. It is a single-file [agent skill](https://code.claude.com/docs/en/skills).

The lesson names the concrete decisions in the code, ties each principle to the lines that show it, and links every concept to a standard reference. When a change is too small to teach much, it says so.

It is for engineers who use an AI agent to write code and also want to understand the code it produced.

## What it does

Run `/learn`, with or without arguments, to get a lesson in five or six sections:

1. **What this is** / what changed
2. **Why it's structured this way** (the deliberate decisions, with alternatives shown)
3. **Concepts at play** — SOLID, design patterns, cohesion/coupling, error-handling style, etc., with inline links to Wikipedia / Martin Fowler's bliki / MDN / official language docs
4. *(Topic mode only)* **Where this lives in your codebase** — concrete `path:line` references mapping the concept to your actual code
5. **What an experienced engineer would still call out** — the honest critical-review pass
6. **Further reading** — one or two canonical pointers, only when warranted

Refactors, asynchronous changes and control-flow rewrites also get a Mermaid diagram when one helps.

## What you can point it at

The skill works out the target type from the shape of what you type.

| Target shape | Looks like | What you get |
|---|---|---|
| **Diff** *(default)* | empty, `pr [<N>]`, `<sha>`, `HEAD~N`, `HEAD^`, branch, tag, range | What changed in that commit/PR/range and why |
| **Static** | a path that exists (`src/auth/`, `package.json`) | File or folder walkthrough |
| **Symbol** | a bare identifier ripgrep finds as a function/class/type | What this symbol does + key call sites |
| **Trace** | quoted natural-language question (`"how does login work"`) | Path through the code end-to-end |
| **Topic** | the literal `topic <name>` | Concept-first lesson, then mapped to your codebase |
| **Help** | `help`, `?`, `usage`, `--help`, `-h` | Render usage and stop |

## Options

Three options shape the lesson. Combine them in any order.

| Dial | Keywords | Default | Effect |
|---|---|---|---|
| **Level** | `expert` (or `technical`/`staff`), `intermediate`, `beginner` (or `simple`/`plain`), `eli5` (or `grandma`/`grandmother`) | `intermediate` | Jargon density. `eli5` leads with non-code analogies before naming any concept. |
| **Depth** | `quick` (or `peek`), `standard` (or `overview`), `deep` (or `deep-dive`/`deepdive`/`audit`) | `standard` | Codebase coverage in topic and folder modes. `deep` is hard-capped at 20 files. |
| **Save** | `save` (or `--save`/`export`) | off | Write the lesson to `<repo>/.claude/learn-log/` (or `~/.claude/learn-log/` outside a git repo). |

The level and depth keywords match those of `/briefing`. Older forms still work: `simple` means `beginner`, `overview` means `standard`, and `deep-dive`, `deepdive` and `audit` mean `deep`. `deep` sets depth, not level, so use `expert`, `technical` or `staff` for the most technical lesson. `SKILL.md` lists every synonym.

## Built-in topic vocabulary

19 canonical topics ship with curated search terms and named sub-concepts:

`auth` · `dependency-injection` · `error-handling` · `logging` · `observability` · `validation` · `state-management` · `routing` · `caching` · `concurrency` · `security` · `performance` · `i18n` · `accessibility` · `layering` · `domain-modeling` · `api-design` · `data-access` · `testing`

For a topic not on the list, the skill says it is improvising, shows the search terms it chose, and continues.

## Install

See [Install one skill](../README.md#install-one-skill) in the skills catalog, or run `scripts/sync-toolkit.sh --harness` to sync every skill.

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
/learn topic auth                    # default depth (standard)
/learn topic dependency-injection eli5
/learn topic caching deep-dive save  # exhaustive audit, saved
/learn topic obscure-pattern         # off-list — skill admits and improvises

# ─── Help ───────────────────────────────────────────────────
/learn help
/learn ?
```

## Saved lessons (`learn-log`)

Add `save` to write the lesson to a file. You can read it again later, and any Mermaid diagrams render in a Markdown viewer, which the Claude Code terminal cannot do.

- **Location**: `<repo>/.claude/learn-log/` if you're in a git repo, else `~/.claude/learn-log/`.
- **Filename**: `YYYY-MM-DD-<short-sha-or-pr>-<level>.md` (e.g. `2026-05-01-cfc4afb-eli5.md`).
- **Frontmatter**: `type`, `target`, `level`, `date`, `target-title` — searchable.
- **Overwrite policy**: never silent. If the filename already exists, a `-2`, `-3`, … suffix is appended.
- **Gitignore**: not auto-ignored. Whether to commit your learn-log is up to you and your team.

## Design rules

These rules explain how the skill behaves. Read them before extending it.

- **Plain English first; jargon second.** Every named concept gets defined the first time it appears. The level dial controls how aggressively this rule fires.
- **Anti-fabrication, applied to citations.** Never invent a URL. If a link isn't certain, the skill verifies via WebFetch or writes a search hint instead. A wrong link is worse than no link.
- **Don't manufacture lessons.** A typo fix gets a one-paragraph response that says so. SOLID does not get dragged into every commit. Recognising "there's nothing big at play" is itself a lesson.
- **Don't manufacture diagrams.** Same rule, applied to Mermaid.
- **Don't manufacture topic hits.** If `/learn topic caching` finds no caching layer in your codebase, that's a finding, not a failure.
- **Concrete to abstract, every time.** Pattern: here's the line, here's the principle, here's why the principle matters in practice. Never a principle without the line that embodies it.
- **Bounded by design.** Hard 20-file cap on `deep`; the skill stops and says so. Reaching the cap is itself a finding.
- **Single file.** All of the skill's behavior, about 500 lines including the topic vocabulary, is in one `SKILL.md`. To add a topic, add a row to its vocabulary table.

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

No package, marketplace or sign-in is needed.

## Extending

Common edits:

- **Add a topic** — add one row to the *Built-in topic vocabulary* table in `SKILL.md`. Search terms go in column 3, named sub-concepts in column 4. The dispatcher picks it up automatically.
- **Add a level synonym** — add the keyword to the closed set in the *How to gather the change* section's args parser. Same pattern for save / help / depth synonyms.
- **Tweak the citation source allowlist** — the *Citations and links → Source preference* section. The anti-fabrication rule keeps the skill honest no matter what sources you allow.

## License

MIT, like the rest of the repository.
