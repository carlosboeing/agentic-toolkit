# Changelog

All notable changes to this project are recorded here, newest first.

## 2026-11-02: RTK rewrite in Codex, Antigravity and OpenCode

- `scripts/register_hooks.py` registers `rtk hook codex` in `~/.codex/hooks.json` (`PreToolUse`, `Bash`) by the full path of `rtk`, when `rtk hook --help` lists it. RTK's own `rtk init --codex` is not used: it also writes into `AGENTS.md`, which here links to the shared instruction file, and refuses `--hook-only`. The Codex trust reminder now covers every hook it registers.
- Antigravity and OpenCode use RTK's own plugins, installed with `rtk init -g --agent antigravity` and `rtk init -g --opencode --hook-only`. Sync reports a missing plugin with that command and writes neither, so RTK's fixes reach them through RTK.
- Sync generates RTK's current agent text in a throwaway home and reports when it differs from `scripts/rtk-awareness.snapshot.md`, the text the brief's RTK section follows.
- The brief's RTK section follows RTK 1.1's agent text: treat condensed output as complete, batch related commands, and re-run with `rtk bypass` (the 1.0 name for `rtk proxy`) only when output is unusable or a test verdict is missing. Kimi Code, Grok and Muse keep the prefix, on each command in a chain. `cat` and `rtk read` are byte-exact in RTK 1.1, so exact-byte reads need no bypass.
- Live probes with RTK 1.1.0 confirmed the rewrite in Codex 0.166.0, Antigravity CLI 1.4.12 (project hooks file and RTK's plugin) and OpenCode 2.1.4. Muse 1.4.14 applies a rewrite only with `permissionDecision: "allow"`, and Grok could not be tested. The RTK setup guide, the harness hooks reference and the capability map record the results.

## 2026-11-02: narrower `rtk proxy` rule

- The global brief keeps `rtk proxy` for exact bytes, test runs and filter debugging, and sends `git`, `gh`, `rg`, `grep`, `find` and `ls` through the plain `rtk` prefix. It also asks for a line range instead of a whole large file. In a 14-day Codex sample, 89% of shell calls used `rtk proxy`; whole-file reads averaged 29,000 characters and made up half of the measured output.

## 2026-11-02: privacy guard home-path match

- The public pre-commit guard matches the macOS home-directory prefix case-sensitively, so a lowercase `users` path segment such as `/api/users/42` is accepted. The workbench, repository-name and commercial terms still match in any case. Tests cover both.

## 2026-11-01: resume sessions from four more harnesses

- `resume-session` reads OpenCode (2.x and 1.x database tables, opened read-only), Antigravity CLI, Grok Build and Muse Code sessions, with the same summary sections as Claude Code and Codex. Subagent sessions are left out of `list`. Grok sessions get a running check from `~/.grok/active_sessions.json`.
- `list` leaves out the session it runs in, found from each harness's shell variables, and says so. Each candidate shows the harness's title, or its first request when the title is missing or a placeholder, and a line with its last request. No model call is made.
- `resume-session-warn` covers Muse Code (plugin `UserPromptSubmit`), Antigravity CLI (`PreInvocation`), Grok Build (`PreToolUse`) and OpenCode (a dual-API plugin that adds the line next to the latest user turn and names the running session for `list`). Probes on each installed version are recorded in the harness hooks reference.
- `sync-toolkit.sh --harness` registers the toolkit's hooks in Claude Code, Codex, Grok, Antigravity and Muse settings through `scripts/register_hooks.py`: idempotent, backed up once, `--dry-run` aware, and leaving any file it cannot parse alone. It reports the one manual step, trusting the Codex hook in `/hooks`.

## 2026-11-01: resume an interrupted session

- Add the `resume-session` skill. It continues an interrupted Claude Code or Codex session in a fresh session of any harness from a summary built with no model call: live Git state for the root, worktrees and nested repositories; ranked project documents with their scope section, first open item and latest dated section; and, from the transcript, every request, short approvals with the message they answered, the last completion claim, files changed, side-effect commands and test verdicts.
- Find project records by generic layers that need no documentation method, and apply the toolkit's SDLC conventions from a data profile that only adds and reorders results. A contract test fails when the profile drifts from the plan checker or the conventions guide.
- Add `mark` and the optional `resume-session-warn` prompt hook for Claude Code and Codex. The hook adds one line to a resumed session's context asking the agent to confirm with the user before changing files, and never blocks. `sync-toolkit.sh` copies it beside `validate-mermaid` and registers neither.
- Record the probed hook facts in the harness hooks reference, and add a fresh-session resume row to the capability map.

## 2026-11-01: lifecycle document templates

- Add original requirements, technical design, implementation plan and retrospective templates alongside their quality contracts, packaged with the corresponding skills. Use readable acceptance tables, standalone technical prose and concise document control/history while preserving project overrides and proportionate detail.
- Support provisional design-first work for architecture and feasibility constraints, with derived requirements and design reconciliation before affected delivery planning or implementation. Retain requirements-first product work, routine clear-change routes and actual review authority.
- Add retrospective guidance for evidence, successes, problems, contextual lessons and owned improvement actions with later success checks. Preserve the distinction from artifact review, incident analysis and instruction authority. Brainstorm and research formats remain open.

## 2026-11-01: lifecycle folders and requirements capture

- Include all seven numbered lifecycle folders in bootstrap templates and migration previews/applications, with `.gitkeep` in empty folders. Retain working-memory routing, collision checks and idempotent reruns. Folder presence requires no phase or artifact.
- Clarify vague new ideas through recorded brainstorming, and persist new capability requirements before technical design. Ask focused questions about consequential gaps, reuse existing authoritative records, preserve explicit lighter routes and avoid retrospective paperwork for approved work.
- Add a requirements quality contract with suggested structure and examples, alongside the existing design and plan contracts. Keep product scope changes traceable to the same owner without adding a separate specification phase or approval ceremony.

## 2026-11-01: migration kickoff instructions

- Add copyable preview and apply prompts, fresh-session instructions, bounded batch selection examples and dated harness/model recommendations to the migration runbook. Distinguish routing recommendations from measured migration results and retain installation and publication boundaries.

## 2026-10-31: lifecycle migration entry

- Add a requested migration skill and runbook for one project or an explicitly selected batch. Keep classification decisions separate from deterministic execution and retain public/private repository boundaries.
- Add a manifest-driven runner with disposable rehearsal, preview by default, explicit staged apply, exact file moves and counted replacements, metadata conversion, source checks and target-tree verification. Continue independent batch entries when one is blocked; recognize exact reruns.
- Refuse unsafe paths, collisions, changed sources, unknown manifest fields and provenance edits. Compare supported Markdown references against the baseline; bare-text and custom metadata references still need integrated review. No installation or publication is automatic.

## 2026-10-31: briefing document recency

- Resolve document recency from frontmatter `updated`, falling back to Git author history with rename following. Never use filesystem modification times; report missing or invalid recency explicitly. Keep saved briefing logs on their event-date schema.

## 2026-10-31: harness hooks reference

- Add `reference/reference-harness-hooks.md` for Claude Code, Codex, Gemini CLI, Antigravity, Kimi Code, Grok Build, OpenCode, Cursor and Muse Code: configuration and trust, blocking, added context, rewriting tool calls, payload keys and session ID fields, which event does each common job, failure behavior, and open questions.
- Make the capability map the index of detail references. Fill in its Codex and Antigravity hook rows and add a row for context added on each prompt.
- Point the hooks catalog and the plugin parity guide at the reference instead of restating hook facts. Add a process to "Writing a hook": read the row, re-check stale sources, probe, adapt per harness, and write findings back.
- Record that Grok's documentation names `PreToolUse` as its only blocking event, which disputes this repository's 2026-08-17 record.
- Point the global brief at the reference before a hook is created or ported.

## 2026-10-31: lifecycle frontmatter migration

- Define `created` and `updated` for lifecycle records, with legacy `date` input accepted during transition. Keep review dates and review authority distinct from edit dates.
- Add a frontmatter migration CLI with preview, explicit apply, a fixed Git source revision, historical path mapping, and explicit mechanical-commit exclusions. Preserve prose, comments, other metadata, file modes and existing update dates; normalize the legacy research type and stop on conflicting or unsupported fields.
- Check canonical calendar dates and ordering in both hook copies while preserving legacy layouts and metadata. Include migration tests in the existing CI unit-test discovery.

## 2026-10-29: composable lifecycle workflow

- Add `/start-research`, `/start-requirements`, `/start-review`, and `/start-retrospective`. Keep `/research` as a compatibility entry, with adapted provenance and MIT notices.
- Distinguish accepted requirements from delivered scope. Identify one owner of accepted product scope, preserve original intent and architecture obligations across handoffs, and reconcile changed sources with affected work. Planning combines builder specifications, acceptance proof, tasks, dependencies, and integration without a mandatory intermediate spec document.
- Preserve selectable phases, optional documents, context kept in session for small work, native in-session plans, authorized autonomous progression, and retained human gates. Clarify artifact-specific review checks and proportionate integrated review without claiming agent review as personal human approval.
- Publish the target lifecycle layout with distinct requirements, review, and retrospective locations and continuous lessons. Support legacy layouts and historical document types; keep draft lessons out of delivery-work counts while retaining actionable follow-ups. New records use existing locations until an authorized migration; existing projects are not migrated automatically.
- Extend advisory graph checks for self-dependencies and cycles, preserving newline-separated fields, ignoring ordinary dependency prose, and reporting unsupported formats honestly. Align metadata validation, templates, packaging checks, and public documentation. Briefing scans the declared working-memory root and stops if it is missing. Mechanical checks and reader walkthroughs do not establish runtime reliability across harnesses.

## 2026-10-25: Superpowers parity and lifecycle skill trimming

- **Debugging:** add `/start-debugging`. It builds a failing feedback loop before any theory, minimises the repro, tests 3 to 5 ranked falsifiable hypotheses with tagged logs, and hands the fix to `/start-implementation` with a regression test at a correct seam. It stops after a third failed fix, offers an investigate-only mode, and drafts a blameless incident review when real users are affected. Written from Matt Pocock's `diagnosing-bugs` and Superpowers `systematic-debugging`.
- **Copied skills:** add `tdd`, `research` (Matt Pocock) and `receiving-code-review` (Superpowers), byte-identical to upstream apart from two link edits in `tdd`, with their MIT notices. Add `handoff`, adapted to save into the project's working-memory notes.
- **Lifecycle skills:** size the work in plain words, ask which build choices the user wants to own, and run a builder check on designs. `/start-planning` uses the plan contract as its method instead of defaulting to `writing-plans`; plans record decisions, not code. `/start-implementation` adds worker, reviewer and re-review prompts, one whole-branch review before delivery, and a handoff to `/start-debugging`. The four lifecycle skills shrink from 7,877 to 5,345 words without dropping a permission or safety rule.
- **Worktrees:** `git-worktrees` states its own creation procedure instead of correcting an upstream skill.
- **Superpowers removal:** `plugins/install-superpowers.sh uninstall` removes Superpowers through each harness's own command and prints the manual steps. The global brief drops the Superpowers bootstrap rule, and guides and references stop telling readers to install it.
- **Status after removal:** `install-superpowers.sh status` reports Claude Code as absent once `claude plugin uninstall` has run, instead of reading the version from the cache that the uninstall leaves behind.
- **Tests:** CI fails when a `SKILL.md` reaches 20,000 bytes, the point where Claude Code cuts skills after compaction; `briefing` and `learn` are listed exceptions. The sync suite checks the new skills reach the hub.

## 2026-10-21: flexible lifecycle skills

- **Skills:** add `/start-brainstorm` and `/start-design` as self-contained entry points. Brainstorming presents options, settled points, and open questions for review; design reads durable sources and current architecture, writes a complete draft, and reaches the applicable review checkpoint.
- **Contract:** package a shared design quality contract beside `/start-design`, with project presentation overrides, proportional research, acceptance methods, visible blockers, and compact and substantial examples.
- **Documentation:** document the four lifecycle entry points and review checkpoints and attribute adapted Matt Pocock techniques with MIT notices carried in each new skill directory. No upstream skill installation or chain call is required.
- **Flexible entry:** write a document only when it records a decision worth keeping, needs review across people or sessions, or supports large, risky or complex work. Bounded work gets a short design in chat and an in-session plan. The agent states its route in one line, asks when unsure, and follows a route the user picks after one stated risk.
- **Autonomy:** retain human review gates by default while allowing explicitly authorized full or partial autonomous workflows, with their included reviews, retained human gates, and stopping points. Record the run's authorization in a durable project record a fresh session can read. Commit drafts, and record review in `status` and `reviewed_by` with the accountable human's GitHub username, marking delegated agent review as such.
- **Decision context and approval:** identify applicable product and architecture decisions, account for their treatment in designs, and establish the actual authority for the reviewed revision. Distinguish personal human approval from readiness under explicitly delegated review.
- **Packaging:** verify both skill entry points, the installed design contract, license notices, and OpenCode command wrappers in the disposable sync suite.

## 2026-10-03: consistent SDLC artifacts, first increment

- **Delivery:** [PR 6](https://github.com/carlosboeing/agentic-toolkit/pull/6) integrates the shared plan quality contract, advisory plan checker, `/start-implementation` controller, and corrected progress and worktree guidance described in the September 24 entries.
- **Tracking:** consolidate the SDLC roadmap into one delivery record and retain `/start-brainstorm` and `/start-design` as subsequent work.

## 2026-09-30: agent memory selection guidance

- **Guide:** add a selection method for cross-harness memory, observer quality checks and migration verification.
- **Reference:** compare claude-mem, Engram, Basic Memory and MCP Memory Service, with dated observer API rates and evidence limits.
- **Setup:** distinguish MCP connectivity, existing-memory search and new observation capture; replace obsolete worker-file checks with the upstream status command.

## 2026-09-24: review fixes for checker classification and fixture links

Corrections found by the final independent review of this increment.

- **Checker classification:** requirement IDs now anchor outside YAML frontmatter (author lines can no longer become phantom requirements), coverage is credited only from mapping-shaped lines instead of prose mentions (a plan that maps nothing reports `absent design coverage` rather than a false clean), and a design requirement ID inside a dependency phrase is no longer flagged as an unresolved dependency. The verification keyword heuristic is stated in `--help`.
- **Link scanning:** `scripts/check-relative-links.py` excludes `tests/fixtures/`, so the intentional broken-link fixture no longer fails the required CI step while remaining a live negative fixture for the checker suite.

## 2026-09-24: advisory plan checker

A mechanical checker for plan artifacts, wired into the planning self-check and CI. Advisory only.

- **Checker:** new `skills/start-planning/scripts/check-plan.py` reports missing frontmatter, broken local design links, duplicate task IDs, unresolved dependency IDs, tasks without verification evidence and absent design coverage. It recognizes bullet, table, heading (`Task N`) and bare-ID task forms, and requirement IDs anchor to their line's identifier so prose noise never becomes a phantom requirement. Presentations it cannot parse report `unable to check` instead of claiming a field is missing. Finding reports exit 0; usage or file-read errors exit 2. Not wired to any push hook.
- **Skill:** `start-planning` runs the checker before presenting the draft; the checker's `--help` states what it checks. The plan contract is unchanged.
- **Tests:** `tests/test_plan_checker.py` runs 21 tests over synthetic fixtures in `tests/fixtures/sdlc/` — substantial and compact valid plans plus one labeled omission per finding class — and joins the CI test job.

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
