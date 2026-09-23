# Changelog

All notable changes to this project are recorded here, newest first.

## 2026-09-24: start-implementation controller skill

One controller skill for the implementation phase, with two entry scopes plus direct work.

- **Skill:** new `skills/start-implementation/SKILL.md` covers whole-plan and single-task scope and direct small work through five readiness questions. It reconciles plan status, design revision, local and remote git, workspaces, effect markers and plan-writer ownership before touching anything, keeps the five delivery states (verified local work, committed work, PR review, merge, rollout) apart, and never infers merge or deploy permission. Non-repeatable effects need a durable checkpoint first; an effect marker no committed checkpoint explains halts its task; competing plan-writer evidence freezes plan writes and is never self-reconciled.
- **Tests:** new `tests/sdlc-controller-fixture.py` builds disposable code and plan repositories for 14 cases — ready work, unmet predecessors, blocked tasks, parallel file collisions, missing worker facilities, dirty designs, competing writers, withheld commit authorization, performed effects, interrupted runs, direct fixes and simulated squash merges — with `setup`, `state` and `assert` commands. Assertions bind ticked SHAs to the task's own change and order plan ticks after their code commits.
- **Catalog:** `skills/README.md` lists the new entry.

## 2026-09-24: corrected progress and worktree guidance

Two guidance defects fixed where they misstated Git behavior.

- **Plan progress:** the global brief no longer asks a commit to record its own SHA. The rule is now a verified code commit first, then a plan-repository commit that ticks the task and records that code SHA — two repositories in a split setup, two commits in one. One controller owns plan writes, and PR and merge SHAs are recorded separately after a real merge.
- **Worktrees:** `git-worktrees` no longer claims that creating a branch moves other worktrees' HEAD or reverts their edits; a disposable two-worktree fixture disproved both. The worktree requirement stays, for session isolation.

## 2026-09-24: shared plan quality contract

`/start-planning` now plans against a written artifact contract, so two sessions planning the same approved design reach the same standard.

- **Contract:** new `skills/start-planning/references/plan-contract.md` fixes what a plan must answer (source and scope, current state, tasks, execution contract, completion) and the conditional detail rule, with substantial and compact examples. It explicitly rejects fixed task counts, per-task commit subjects, a universal failing-test rule and a single Markdown layout.
- **Discovery:** the skill reads a project-named contract or template first (it may replace presentation, not minimum answers), then the shared contract resolved relative to the installed `SKILL.md`, then the project's planner. Recent plans are examples only, and a missing optional project pointer never blocks planning.
- **Handoff authority:** a pasted prior-session prompt is context, not a specification. A handoff rule that conflicts with the approved design or project contract draws one clarification unless the user adopts it in the session.

## 2026-09-23: OpenCode 2.x plugin compatibility

OpenCode 2.0 replaced the plugin API, which left the Mermaid validator plugin failing to load with `Plugin must export a default definition`.

- **Plugin:** `hooks/validate-mermaid/opencode-validate-mermaid.ts` now default-exports one definition that serves both APIs: `id` and `setup` for OpenCode 2.x, `server()` for 1.x from 1.18.29. Guard behavior and messages are unchanged.
- **Tests:** `tests/assert-opencode-plugin.mjs`, wired into `tests/test-sync-toolkit.sh`, asserts the shape of the installed plugin against both APIs and exercises the guard through both hook shapes.
- **Compatibility:** verified 2026-09-23 against OpenCode 2.0.14 and 1.18.32. Command wrappers, the skill hub links and `AGENTS.md` keep working on 2.x. Two 2.x changes are documented: the `CLAUDE.md` fallback is gone, and the `instructions` config array is not loaded.
- **Docs:** the validator README, hooks catalog, plugin parity guide, capability map and README record the version matrix, the hook mapping and the tools the guard does not cover.

## 2026-09-23: initial public release

The first public version of the toolkit.

- **Skills:** `briefing`, `learn`, `schedule-resume`, `repo-standards` (with the `oss-standards` alias), `housekeeping`, `penmark-comments`, `git-worktrees`, `start-planning`, `capture-meeting` and `externalize-deliverable`.
- **Git hooks:** drift guard (`housekeep`, `post-merge`, `pre-push`) and the private-workbench guard (`pre-commit`).
- **Harness hooks:** Mermaid validation for Claude Code and OpenCode.
- **Synchronizer:** `scripts/sync-toolkit.sh` copies authored skills into the shared skill hub and repairs the harness links to it.
- **Guides and references:** project structure and conventions, model and effort routing, cross-harness instructions, plugin parity, browser automation, skill authoring, and repository house standards.
- **Templates:** default and open-source project scaffolds, and a lean Claude Code settings template.
- **Governance:** code of conduct, contributing guide, security policy, support guide, third-party notices, issue templates and CI.
- **Documentation standard:** every public document follows the standard in `CONTRIBUTING.md`: purpose first, plain English, tables and diagrams where they help, and dated sources for anything that changes.
