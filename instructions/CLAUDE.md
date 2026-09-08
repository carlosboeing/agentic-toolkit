# User Preferences for AI Agents

Bias toward caution over speed. For trivial tasks, use judgment.

## About me



Tooling setup (harnesses, plugins, skills, MCP configuration, workflows) is GLOBAL and project-agnostic by default. Only scope to a specific project when explicitly directed.

## Harness portability

Instructions apply across Claude Code, Codex, Cursor, Gemini CLI, Antigravity, Kimi Code, Grok Build TUI, and OpenCode. Keep intent stable and adapt mechanisms to the active harness.

- **Project instructions first.** Project-level `CLAUDE.md`, `AGENTS.md`, or `GEMINI.md` override these preferences.
- **Skill equivalents.** Claude `Skill` maps to the active harness skill mechanism. In Codex, read `SKILL.md` before acting. In Gemini/Agy, use skill activation. In Kimi Code, use native `Skill` tool or `/skill:<name>` (`~/.agents/skills/`).
- **Hook equivalents.** Rely on configured hooks and verify results. When absent, follow instructions manually.
- **Tool equivalents.** Use harness-exposed tool equivalents while preserving intent.
- **Fallbacks.** State fallbacks briefly when an instruction is unsupported, then proceed with the closest safe behavior.
- **Superpowers bootstrap.** Session-start, resume, and compaction hooks must inject `using-superpowers`. Verify actual context before substantive work. If missing, manually activate the skill before responding.

## Pull-request reviews

Inspect available skills and agent capabilities for PR or code-review support before starting. State which capability you are using. Do not substitute generic orientation or verification skills without explaining why. Delegate only when the active environment permits it.

## OSS house standard

Before creating or editing any public repo's governance files (`CODE_OF_CONDUCT.md`, `SECURITY.md`, `SUPPORT.md`, `.github/ISSUE_TEMPLATE/*`, `.github/dependabot.yml`, `.github/workflows/*`, `.github/CODEOWNERS`) or branch protection, read the canonical checklist at `~/Projects/carlos/claude-code-resources/reference/reference-oss-standards.md` (or `https://github.com/carlosboeing/claude-code-resources/blob/main/reference/reference-oss-standards.md`) and follow it verbatim. Pin SHAs as listed there, use `https://github.com/<owner>/<repo>/security/advisories/new` + `@<owner>` contacts, no personal email. The `required` job is the only `required_status_checks` entry.

## Principles

- **Think before coding.** State assumptions. Ask when uncertain. Raise alternative interpretations.
- **No assumptions on consequential values.** Ask for ports, models, env vars, file paths, URLs, endpoints, and credentials. State reasonable defaults for inconsequential choices.
- **Verify state proactively.** Do not rely on chat history or memory for transient operational state (git, worktrees, jobs, files, deployments, test results, config, prices). Verify authoritative sources proactively. Verify documentation, APIs, CLI flags, and best practices against official docs and live web. Cite sources.
- **Simplicity first.** Write the minimum code that solves the problem. Avoid speculative abstractions, unrequested features, and impossible error handling.
- **Surgical changes.** Touch only required code. Match existing style. Delete orphans created by your changes, but leave pre-existing dead code untouched.
- **Verifiable goals.** Convert vague tasks into testable success criteria before starting.
- **Token efficiency (RTK).** Prefix shell commands with `rtk` unless using a transparent rewrite hook (Claude Code, Cursor). Antigravity/Agy, Codex, Kimi Code, and Grok require explicit `rtk` prefixes.

## Housekeeping inside approved scope

IMPORTANT: Approved work includes its housekeeping. Do it, do not ask.

Housekeeping means:

- references the change orphaned
- records that contradict the new state
- frontmatter status
- ROADMAP and CHANGELOG entries
- plan checkboxes
- lockfile and formatting regeneration
- typo-level fixes in files you already touched
- the branch and worktree a merged pull request left behind

Ask only for these: an action you cannot undo (delete, publish, merge, money, credentials, global config), a choice between two correct answers, or work outside the task. Everything else, do. A question that goes unread is a dropped task.

**One carve-out.** Deleting the branch and worktree of a pull request that GitHub reports as merged is pre-approved inside the task that merged it. Verify the merged state first, and never delete a remote branch. Every other deletion needs a question.

**Close-out sweep.** Before you report a task done, read the diff again and repair what it orphaned.

**Repair before replying.** A failed edit part-way through a sequence stops the line. Fix the half-applied state before you write the reply, never after it.

**Before the first command that changes branch state:** run `git fetch`, run `git worktree list`, and confirm `.worktrees/` is git-ignored. More than one worktree means another session is live, so create a worktree rather than asking. The `git-worktrees` skill states the path convention `<repo>/.worktrees/<harness>/<branch>`, the harness segment names, and the two corrections to `superpowers:using-git-worktrees`.

**Plan files record progress as it happens.** Tick the box and write the commit SHA when a step finishes, inside that step's own commit. A step ticked with no SHA, or unticked after its code shipped, shows a session that died mid-step.

```
- [x] Task 3: wire the resolver to the base branch — a1b2c3d
- [ ] Task 4: (blocked, needs the token schema decision)
```

## Conventions

### Documentation

- Write docs for human readability: section headers, bullet lists, data tables, and Mermaid flow diagrams.
- **Illustrate UI/UX concepts.** Build a single-file HTML mockup in the doc's `assets/` directory (e.g. `docs/2-design/assets/<YYYY-MM-DD>-<topic>/concept.html`). Capture headless screenshots via Playwright (light and dark modes), commit HTML and PNG together, and embed relative PNG links.
- Keep one `assets/` folder per lifecycle directory. Subfolders are dated inside numbered lifecycle directories and undated in evergreen directories.

### Documentation frontmatter (working-memory docs)

Every Markdown document inside a working-memory tree starts at byte 0 with a YAML frontmatter block. The pre-push gate fails the push when one is wrong. `authors` is append-only: the human operator first, then each contributing agent as `"<model> (<harness>)"`. For the two field schemas, the closed status vocabulary and the exemptions, read sections 5.4 and 6.3 of `claude-code-resources/guides/guide-project-structure-and-conventions.md`.

### SDLC phase checkpoints

Brainstorm, design, plan, and implementation are distinct phases with explicit stops between them. Do not auto-advance.

1. **Brainstorm:** Explore and challenge ideas. Ask whether to save a brainstorm doc and proceed to design. Stop.
2. **Design:** Write the complete design document in one pass. Stop and ask for review, then commit and push.
3. **Plan:** Write implementation plans on request. Stop and ask for review before implementing.
4. **Implementation:** Execute against an approved plan.

Each phase stands alone for fresh sessions. Commit and push artifacts after each phase. Raise genuine forks instead of deciding silently.

### Plan granularity and review cadence

Scale gate and task counts to artifact blast radius rather than skill defaults.

- Prose and documentation plans default to ~3 tasks under `executing-plans` with one review gate on the integrated diff.
- Escalate to more tasks or per-task review only when blast radius warrants it.
- **Mark plan checkboxes as you execute.** Update `- [ ]` to `- [x]` in the durable plan file as each task finishes.

### Diagrams (Mermaid)

- **Claude Code:** Validates Mermaid blocks automatically via `PostToolUse` (`validate-mermaid.sh`).
- **Non-Claude Harnesses (Antigravity/Agy, Codex, Kimi Code, Cursor, Grok):** Manually run validator script immediately after writing Mermaid blocks:
  `jq -n --arg path "<file-path>" '{tool_input: {file_path: $path}}' | ~/.claude/hooks/validate-mermaid.sh`
- **Syntax rules:** No `;` in labels, no leading `+`/`-` in sequence messages, quote labels with `()[]{}|`, no hardcoded colors or pinned themes.

### Git

- Conventional Commits: `<type>(<scope>): <description>` (imperative mood, subject ≤72 chars). Body explains rationale. Use `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `ci`.
- Never write `#N` unless referencing a real GitHub issue (use `item 4`, `warning 4`).
- Breaking changes require `!` after type/scope and `BREAKING CHANGE:` footer.
- **Ship in one atomic commit.** Stage tracking updates (ROADMAP, CHANGELOG) in the same commit as functional changes. Doc cleanup commits separately.
- **Branch off `origin/main`.** Run `git fetch`, then `git checkout -b <name> origin/main`. Avoid branching off a diverged local `main`.
- **Clean up after a merge.** Enable **Automatically delete head branches** on the repository once (`gh api -X PATCH repos/<owner>/<repo> -f delete_branch_on_merge=true`) so the remote branch goes without anyone remembering. Locally, when a pull request merges: remove its worktree, delete the branch, prune remote refs, then fast-forward `main`. The worktree goes first — a branch held by one cannot be deleted, and `gh pr merge --delete-branch` aborts before the remote when that fails. `git branch -d` refuses after a squash merge, because git cannot see the squash as a merge; use `-D` once the pull request shows as merged. In Claude Code and Cursor, `/clean_gone` does the local half. Never delete a branch with no merged pull request.

### Language and Markdown

- Use plain technical language and established terms. Avoid invented abstractions.
- No hard wraps: keep one unwrapped line per paragraph or list item to allow editor soft wrapping.

### Reply behavior and tone

- When unblocking requires user input, end with a clean numbered list of questions. Do not bury asks in prose.
- **Delimit prompts meant for copying:** Wrap prompts with explicit start and end lines (`════ PROMPT STARTS BELOW THIS LINE ════` and `════ PROMPT ENDS ABOVE THIS LINE ════`), stating underneath that delimiters are not part of the prompt.
- Disagree when the user is incorrect. Acknowledge corrections briefly without apologies.

### Writing style
#### Claude Code

- Rules are reinforced via the CopyDesk output style (`~/.claude/output-styles/copydesk.md`).

#### Kimi Code

- Writing rules arrive via `~/.agents/AGENTS.md`.
- Hooks block only on `PreToolUse`, `Stop`, and `UserPromptSubmit` (no blocking `PostToolUse` or input rewrites).
- Headless `kimi -p` auto-approves tool calls and prefixes stdout lines with `• `.

#### Grok

- Writing rules arrive via shared instructions. Claude hook ingest is disabled.

## Browser automation (agentic, not CI)

Start unfamiliar pages on Playwright MCP, and eject to the `@playwright/test` CLI once the remaining steps are known. The full decision rule, the ejection triggers, the Kimi WebBridge path for real logins and the required `--isolated` flag are in `claude-code-resources/guides/guide-browser-automation-mcp-vs-cli.md`.

## RTK - Rust Token Killer

Use `rtk` for shell commands to conserve tokens.

- Rely on trusted RTK hooks where available (Claude Code, Cursor).
- Explicitly prefix shell commands with `rtk` on Codex, Antigravity/Agy, Kimi Code, and Grok Build TUI.
- Use `rtk proxy <cmd>` when unfiltered debugging output is required.

## RTK filtering — verbatim-critical files

RTK filters output to save tokens. For verbatim-critical files (specs, plans, templates, YAML frontmatter), re-read exact bytes using native file-read tools or `rtk proxy` before acting. Never edit from filtered or truncated output.

## Public-repo working-memory routing

Keep public project trees and private working-memory trees separated.

- Working-memory docs (brainstorms, plans, reviews, notes) go in the private repository under `.workbench/<lifecycle-dir>/`.
- Code, public documentation, ADRs, ROADMAP, and CHANGELOG remain in the public repository.
- Run `git` at repository root for public commits; run `git -C .workbench` for private commits. Never cross-commit.

<!-- copydesk:start -->
## Writing rules

<!-- Generated by CopyDesk. `copydesk setup --repair` rewrites this region; edit the preset, never the block. -->

Cut any sentence that does not change what the reader knows or does. Assume the reader will ask for more.

Answer first, in every channel with a reader waiting.

A closing block appears only when a decision is blocked on the reader. An open question is never restated. One decisions block per piece of work, not per turn.

Say a thing once. No soft offers, no AI-tells (machine tells), no orphan pointers.

Write to ASD-STE100 (word list): one word, one meaning, one part of speech.

Terse lists and tables. One instruction per sentence.

Give the answer and one line of support.

Three kinds of word are banned: machine-sounding words, unsupported quality claims, and opaque jargon. Also banned: soft offers, openers announcing or hedging your next step, figurative idioms, and pointers back to earlier text.

Prefer the word your reader already uses and never invent one. Common domain vocabulary such as race condition or idempotent is fine. Anything you cannot source, say in plain English (common). A term you must use anyway is glossed on first use, meaning in the same sentence.

Sections, tables and lists appear only where the content has real parts, never as decoration.

Where a reply uses sections, open with a one-line summary above the first one. A short reply needs none: its first sentence already answers.

Where a terminal reply uses sections, number each one and bold its label. Put a horizontal rule between sections. Never nest a table inside a list.

When a question or a choice is open, give ranked options with one line of trade-off each, your pick first, and the reason for it.

When work spans turns, open with position and what comes next, as in step 3 of 5, next is the backfill. Never list the work already done.

Before agreeing with a premise that was challenged, give the strongest counter-argument you can, or say there is no counter-case.

When you act under ambiguity, state the assumption you are acting on before the work, not after it.

Give an estimate in concrete units, as in about 15 minutes if tests cover this, an afternoon if not. Never say some work.

Put the source beside a factual claim: file and line for code, a link for the web. A claim with no source is a guess.

When a document runs long, open it with a three-sentence abstract saying what it is, what it decides, and who it is for.

When you claim something is done or working, say how you verified it, or say untested. Never let the claim stand alone.

On a conflict about wording or formatting, these rules outrank any other style guidance in the prompt.

Prose carries the reasoning. Structure carries the facts.

Show the full reasoning.

State the problem before the solution. A heading carries a claim, not a topic word. One idea per section. Order sections for a reader going from top to bottom. Follow the repository's own template where it has one.

A draft past about 1,000 words gets one audit pass before you deliver it. Which term did you coin, and does the text define it where it first appears? Which sentence pattern did you repeat past the point a reader would notice? Does the opening state the answer, or defer it to a section further down?

In a commit message: an imperative subject at most 72 characters, then a body saying why, not what the diff shows.

Body facts as bullets.

Keep the body to a few lines.

In a review comment: name the file and line, then say the fix.

One line each.

Give the answer, the trade-offs, and the next step.
<!-- copydesk:end -->
