# Roadmap

This is the forward view of Agentic Toolkit: what is being worked on, what comes next, and what has shipped. To suggest or discuss an item, open an [issue](https://github.com/carlosboeing/agentic-toolkit/issues).

## In flight

- **Plan quality contract for `/start-planning`.** A shared contract at `skills/start-planning/references/plan-contract.md` states what a plan must answer — source and scope, current state, tasks, execution contract and completion — with substantial and compact examples. The skill resolves a project-named contract first, then the shared contract beside its installed `SKILL.md`, then the project's planner. On the SDLC-artifacts review branch.
- **Corrected progress and worktree guidance.** The global brief prescribes the two-commit progress sequence — code commit, then the plan commit that ticks the task and records the code SHA — with one plan writer and a separately recorded merge SHA. The `git-worktrees` skill no longer claims that creating a branch moves other worktrees' HEAD or reverts their edits.
- **`/start-implementation` controller skill.** Drives implementation from an approved plan in whole-plan or single-task scope, or direct small work from an execution-ready design or issue: readiness preflight, state reconciliation, delegation only when isolated, verification, two-commit progress, and delivery states kept apart. Ships with `tests/sdlc-controller-fixture.py`, a 14-case disposable fixture suite for recovery and authorization behavior.
- **Advisory plan checker.** `skills/start-planning/scripts/check-plan.py` reports missing frontmatter, broken design links, duplicate task IDs, unresolved dependencies, tasks without verification evidence and absent design coverage, and says `unable to check` where a presentation cannot be parsed. `/start-planning` asks for a run before the draft is presented; 17 fixture tests run in CI. It never blocks a push.

## Next actions

- **Penmark anchors that survive Markdown formatters.** A formatter that runs on save can move a Penmark block comment away from the block it targets. Anchor block comments to the next non-blank Markdown block, and add formatter-survival tests.
- **Phase skills for the rest of the delivery workflow.** Add `/start-brainstorm`, `/start-design` and `/start-implementation` alongside the existing `/start-planning`, so each phase of brainstorm, design, plan and implementation has an explicit entry point.
- **Codex parity follow-up.** Decide whether Codex should get hook-level RTK filtering and Mermaid validation once its plugin packages support hooks.

## Future considerations

- **Native-first tool routing.** Let each harness prefer its own built-in tools where they are equivalent, instead of prescribing one tool set for every harness.
- **`/init-project` skill.** One skill to scaffold a new project, fill an empty directory, or retrofit the documentation conventions onto an existing project.
- **Distribution for tools that bundle agent files.** Package a command-line tool together with its skills, hooks and commands so users do not assemble the pieces by hand.
- **Harness-agnostic memory.** Evaluate memory options that work across harnesses. Retrieval over MCP works everywhere, but automatic injection at session start depends on hooks, which not every harness supports.
- **Template variants per project type.** Split the project templates when the needs of different project types diverge.

## Open questions

None at the moment.

## Parked

None at the moment.

## Recently shipped

- **OpenCode 2.x plugin compatibility (2026-09-23).** The Mermaid validator plugin now serves both OpenCode plugin APIs from one file: 2.x, and 1.x from 1.18.29. Tests assert the installed plugin's shape and guard behavior against both APIs.
- **First public release (2026-09-23).** The repository is public, with branch protection, CI and security reporting in place.
- **Initial public release preparation.** Public documentation, governance files, privacy guard, relative-link checker and CI.
