# Roadmap

This is the forward view of Agentic Toolkit: what is being worked on, what comes next, and what has shipped. To suggest or discuss an item, open an [issue](https://github.com/carlosboeing/agentic-toolkit/issues).

## In flight

- **Lifecycle standards consolidation and adoption.** Reconcile the authoritative conventions and their consumers, verify metadata and recovery behavior, then rehearse explicit project migrations with preservation and discovery checks.

## Next actions

- **Review the stale-record check (2026-12-02).** Read `housekeep-records.log` in each repository that merged pull requests, and re-run `housekeep records <n>` to see which listed records were edited. Decide from the numbers: keep as it is, follow `related` links when too few real problems are found, or tighten path matching when false alarms dominate. See [the drift-guard README](../git-hooks/drift-guard/README.md#what-the-merge-check-lists-in-working-memory-records).
- **Penmark anchors that survive Markdown formatters.** A formatter that runs on save can move a Penmark block comment away from the block it targets. Anchor block comments to the next non-blank Markdown block, and add formatter-survival tests.
- **Hook parity across harnesses, Codex first.** [Issue 44](https://github.com/carlosboeing/agentic-toolkit/issues/44).
- **RTK rewrite hook for Grok Build.** Grok's bundled hook reference documents `updatedInput`, and RTK's Claude processor cannot read Grok's camelCase payload. Test a mapping wrapper once the Grok account can run a session.

## Future considerations

- **Edge and Chromium profiles for `browser-profile`.** [Issue 40](https://github.com/carlosboeing/agentic-toolkit/issues/40).
- **Native-first tool routing.** Let each harness prefer its own built-in tools where they are equivalent, instead of prescribing one tool set for every harness.
- **`/init-project` skill.** One skill to scaffold a new project, fill an empty directory, or retrofit the documentation conventions onto an existing project.
- **Distribution for tools that bundle agent files.** Package a command-line tool together with its skills, hooks and commands so users do not assemble the pieces by hand.
- **Harness-agnostic memory.** [Selection guidance](../guides/guide-agent-memory-selection.md) and a [dated options comparison](../reference/reference-agent-memory-options.md) are documented. A trial of cheaper observers or local replacements remains open; verify capture, cross-harness recall and backup restoration before adopting one.
- **Shrink `briefing` and `learn` below the skill size limit.** Both are listed exceptions in `tests/test-skill-size.sh`. Simplify `briefing` to Git, GitHub and the Project Map; drop `learn` from sync or stop the model from loading it on its own.
- **Template variants per project type.** Split the project templates when the needs of different project types diverge.
- **Unify plan-driven dispatch with the toolkit.** Open questions: plugin or platform, dispatch from plan files or issues, whether difficulty labels become required, and which additional dispatch checks belong beyond the advisory cycle diagnostics.

## Open questions

None at the moment.

## Parked

- **Deferred: a `resume-session` reader for Cursor.** Its `store.db` keeps hex-encoded metadata and content-addressed blobs, and its hooks cannot add context on a prompt, so an open tab would get no warning.
- **Declined: `resume-session` readers for Kimi Code and Gemini CLI.** Neither is in use; both stay targets with the repository-only summary.
- **Deferred: retire `plugins/install-superpowers.sh`.** It stays as the rollback path until the per-harness skill trigger check passes and a stable period follows.

## Recently shipped

- **Session handoff timing (2026-11-18).** `/resume-session` records the new destination before its first substantive reply. Concurrent attempts share a lock, confirmed retries keep the selected source, and listing and reports stay read-only. See [the resume-session README](../skills/resume-session/README.md#the-reader) and [PR 51](https://github.com/carlosboeing/agentic-toolkit/pull/51).
- **"What's next?" answers show the big picture (2026-11-18).** The new `next` skill answers "what's next?", "where are we?" or `/next` in about ten lines: the workstream's SDLC phase, progress, the next action and why, gaps between the work and its records, and decisions waiting on you. The global brief now asks multi-turn replies to open with their SDLC phase and step. See [the `next` skill](../skills/next/README.md).
- **Drift-guard hooks in new repo scaffolding (2026-11-18).** `/repo-standards scaffold` and the new-project bootstrap guides now install `scripts/githooks` (`housekeep`, `pre-push`, `post-merge`) and configure `core.hooksPath = scripts/githooks` before the initial commit. See [the `repo-standards` skill](../skills/repo-standards/SKILL.md#scaffold) and [the templates README](../templates/README.md#start-a-new-project).
- **Stale records after a merge (2026-11-18).** The post-merge check lists working-memory records, in any folder name or nested repository, that refer to a merged pull request and changed before it merged; `housekeep records <n>` re-runs it. See [the drift-guard README](../git-hooks/drift-guard/README.md#what-the-merge-check-lists-in-working-memory-records).
- **Keep a Mac awake for remote sessions (2026-11-18).** `scripts/mac-stay-awake.sh on` stops idle sleep on AC power and saves the old timer, and `off` restores it. See the [Tailscale guide](../guides/guide-tailscale-setup.md#turn-idle-sleep-off-and-on-again-with-the-toolkit-script).
- **Visual standards for technical docs (2026-11-17).** Agents use Mermaid diagrams and tables where content has parts, steps, options or states. Each phase skill states its document type's minimum visual, or asks for one sentence saying why it adds nothing, and review checks both. Agents render each diagram and look at it before commit. See [Use visuals that carry a claim](../guides/guide-lifecycle-documentation.md#use-visuals-that-carry-a-claim).
- **Herdr and Tailscale guides (2026-11-17).** Run many agents in terminals that stay alive and show their status, from a native window or a terminal, on local and remote machines, with a phone app and agents that start other agents. Reach those machines and their MCP servers over a private network with SSH, Serve and Funnel. Both guides cover common uses, how each tool fits the toolkit, and alternatives. See the [Herdr guide](../guides/guide-herdr-setup.md) and the [Tailscale guide](../guides/guide-tailscale-setup.md).
- **Google Gemini API and Vertex AI guide (2026-11-16).** Compare the Gemini Developer API (Google AI Studio) and Vertex AI across coding harnesses, OpenCode multi-account setups, Google Cloud credits and free-trial rules, standalone agents, CI/CD, and troubleshooting (`Missing auth credential` and DSQ `429`). See [the Gemini and Vertex guide](../guides/guide-google-gemini-api-and-vertex-ai.md).
- **Your own Chrome profile for agents (2026-11-15).** Ask an agent in ordinary words to work in one of your Chrome profiles, on any page, in its visible window. The `browser-profile` skill connects through the Playwright extension, and your Allow click in Chrome confirms each connection. No token is stored. The [browser guide](../guides/guide-browser-automation-mcp-vs-cli.md#your-own-chrome-profile) replaces the WebBridge route.
- **Superseded-session warning (2026-11-12).** The resume warning now tells the old session it is superseded, opens with a highlighted switch-and-close banner, and allows writes only after an explicit stay-here reply in that session.
- **Migration preservation and relationship conversions (2026-11-04).** Refuse rehearsals that lose tracked files at ignored destinations. Support explicit `inputs` and `amended_by` conversions into `related`, preserving other metadata and original document bodies.
- **Additive requirements extraction in migrations (2026-11-03).** Assess requirements ownership in migration previews and optionally derive draft PRDs with the SDD template. Preserve original documents, distinguish source statements from inferences and keep authored additions separate from deterministic structural changes.
- **Lifecycle consumer consistency (2026-11-03).** Prefer file-relative metadata relationships, detect lifecycle repositories at their root and resolve numeric commit references. Reject absolute metadata paths in link checks. Identify authoritative standards and include search coverage in migration preparation.
- **Reliable toolkit synchronization (2026-11-03).** Add the sync skill, script catalog and explicit rollout reports. Verify installed hooks, isolated validator behavior and remote publication separately. Preserve custom hooks and local work, report incomplete installation and preview new skill command wrappers. Complete the selected repository hook rollout with verified remote publication, validator smoke tests and a no-op repeat.
- **Lifecycle docs in the first search across layouts (2026-11-02).** Discover declared knowledge roots regardless of repo visibility or Git boundaries, including nested private clones and single-repo working-memory or documentation folders. The [smoke test](../guides/guide-qmd-smoke-tests.md#2-check-a-question-about-the-current-project) uses ordinary questions without retrieval hints and checks initial lifecycle coverage.
- **QMD search scope and smoke tests (2026-11-02).** Start document discovery with the current project's main and private collections, include related repositories when the task needs them and broaden without a permission round. Keep excluded collections explicit and verify current sources. The [smoke-test guide](../guides/guide-qmd-smoke-tests.md) checks routing and retrieval across harnesses.
- **Optional QMD document discovery (2026-11-02).** The shared brief directs unfamiliar document topics to a registered lexical index with five results, then reads current files for facts and authority. Keep exact native search, one indexing writer and explicit corpus registration. Installation, models and MCP servers remain separate actions.
- **File-relative frontmatter relationship links and validation (2026-11-02).** Define `related`, `supersedes` and `superseded_by` paths as relative to the containing file so links work in every editor and in both `docs/` and split working-memory setups. Enforce the rule in `drift-guard` (`housekeep check --push`), `scripts/check-relative-links.py`, and the new `validate-frontmatter` hook for Claude Code and OpenCode.
- **RTK rewrite in Codex, Antigravity and OpenCode (2026-11-02).** Those harnesses no longer type the `rtk` prefix. Antigravity and OpenCode use RTK's own plugins; sync registers only the Codex hook, reports a missing plugin, and warns when RTK's agent text changes. Muse keeps the prefix: it applies a rewrite only for commands RTK auto-allows.
- **Narrower `rtk proxy` rule (2026-11-02).** The global brief limits `rtk proxy` to exact bytes, test runs and filter debugging, routes `git`, `gh`, `rg`, `grep`, `find` and `ls` through RTK's filters, and asks for line ranges from large files.
- **Privacy guard home-path match (2026-11-02).** The pre-commit guard matches the macOS home-directory prefix case-sensitively, so example code with a lowercase `users` path segment is no longer refused. The other denied terms still match in any case.
- **Resume sessions from four more harnesses (2026-11-01).** `resume-session` reads OpenCode, Antigravity CLI, Grok Build and Muse Code sessions, leaves the running session out of its list, and gives every candidate a readable title and its last request. The resume warning hook covers those harnesses too, and `sync-toolkit.sh` now registers every hook it installs, in each harness's own settings.
- **Resume an interrupted session in a fresh session (2026-11-01).** Add `resume-session`, a manual skill and standard-library reader that continue a Claude Code or Codex session in a fresh session of any harness from project records, live Git state and the old transcript, with no handoff document. Add an optional prompt hook that tells an old session it was resumed, without blocking it.

- **Lifecycle document templates (2026-11-01).** Add requirements, design, plan and retrospective templates with familiar sections, standalone technical prose and concise control/history. Support provisional design-first work and evidence-based retro follow-ups while keeping brainstorm/research formats and routine-change routes flexible.

- **Lifecycle folders and requirements capture (2026-11-01).** Keep all seven numbered folders visible in templates and migrations, clarify and persist new capability requirements before technical design, and add a requirements quality contract with examples. Routine clear changes retain the lightweight route.

- **Migration kickoff instructions (2026-11-01).** Save fresh-session preview and continuation prompts, bounded batch selection instructions, and dated harness/model guidance in the migration runbook.

- **Lifecycle migration entry (2026-10-31).** Add a requested skill, runbook and manifest-driven runner for single-project or selected-batch adoption, with disposable previews, staged apply, preservation checks and per-project recovery state.

- **Briefing document recency (2026-10-31).** Use lifecycle `updated` dates with Git-history fallback for draft actionability, document staleness and ADR ordering. Preserve briefing-log event dates and report unknown recency.

- **Harness hooks reference (2026-10-31).** Record hook facts for nine harnesses in one dated reference: configuration and trust, which events can block, add context or rewrite a tool call, payloads, failure behavior, and open questions where documentation and records disagree. The capability map becomes the index of detail references, and the hooks catalog gains a process for writing and porting hooks.

- **Lifecycle frontmatter migration (2026-10-31).** Define `created` and `updated` dates, retain legacy input compatibility, and add a reusable metadata migration CLI with preview, explicit apply and Git-based date recovery. Preserve content and review provenance; install compatible validators before adopting the schema.

- **Composable lifecycle workflow (2026-10-29).** Add research, requirements, review, and retrospective entry skills. Preserve optional phases and documents, combine builder specifications with planning, trace consequential source obligations, and support target and legacy layouts. Automated checks cover graph diagnostics and metadata compatibility; cross-harness behavior remains for real use.

- **Superpowers parity and lifecycle skill trimming (2026-10-25).** Add `/start-debugging` with a blameless incident review, copy `tdd`, `receiving-code-review` and `research`, adapt `handoff`, and merge the remaining Superpowers ideas into the lifecycle skills, which are now shorter. Add an `uninstall` mode to the Superpowers installer and drop the docs that required it.

- **Flexible lifecycle skills (2026-10-21).** Add `/start-brainstorm`, `/start-design`, and the shared design quality contract. Select phases across task categories, use native in-session plans when appropriate, and support explicitly authorized autonomous workflows while preserving retained human gates and prior decisions.

- **Consistent SDLC artifacts, first increment (2026-10-03).** [PR 6](https://github.com/carlosboeing/agentic-toolkit/pull/6) delivers the shared plan quality contract, `/start-planning` discovery and advisory checker, `/start-implementation` controller, and corrected progress and worktree guidance.

- **Agent memory selection guidance (2026-09-30).** Separate capture, retrieval and authority; document low-cost observer candidates and local alternatives, with limits on the evidence. No provider switch or migration is recorded as complete.

- **OpenCode 2.x plugin compatibility (2026-09-23).** The Mermaid validator plugin now serves both OpenCode plugin APIs from one file: 2.x, and 1.x from 1.18.29. Tests assert the installed plugin's shape and guard behavior against both APIs.
- **First public release (2026-09-23).** The repository is public, with branch protection, CI and security reporting in place.
- **Initial public release preparation.** Public documentation, governance files, privacy guard, relative-link checker and CI.
