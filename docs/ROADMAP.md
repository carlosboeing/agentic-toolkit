# Roadmap

This is the forward view of Agentic Toolkit: what is being worked on, what comes next, and what has shipped. To suggest or discuss an item, open an [issue](https://github.com/carlosboeing/agentic-toolkit/issues).

## In flight

None at the moment.

## Next actions

- **Penmark anchors that survive Markdown formatters.** A formatter that runs on save can move a Penmark block comment away from the block it targets. Anchor block comments to the next non-blank Markdown block, and add formatter-survival tests.
- **Codex parity follow-up.** Assess Codex's supported hooks for RTK filtering and Mermaid validation, adapt the existing hooks, and test their behavior before enabling them.
- **Privacy guard false positive.** The pre-commit pattern for macOS home paths ignores letter case, so example code with a lowercase `users` path segment is blocked. Make that match case-sensitive.

## Future considerations

- **Native-first tool routing.** Let each harness prefer its own built-in tools where they are equivalent, instead of prescribing one tool set for every harness.
- **`/init-project` skill.** One skill to scaffold a new project, fill an empty directory, or retrofit the documentation conventions onto an existing project.
- **Distribution for tools that bundle agent files.** Package a command-line tool together with its skills, hooks and commands so users do not assemble the pieces by hand.
- **Harness-agnostic memory.** [Selection guidance](../guides/guide-agent-memory-selection.md) and a [dated options comparison](../reference/reference-agent-memory-options.md) are documented. A trial of cheaper observers or local replacements remains open; verify capture, cross-harness recall and backup restoration before adopting one.
- **Shrink `briefing` and `learn` below the skill size limit.** Both are listed exceptions in `tests/test-skill-size.sh`. Simplify `briefing` to Git, GitHub and the Project Map; drop `learn` from sync or stop the model from loading it on its own.
- **Template variants per project type.** Split the project templates when the needs of different project types diverge.
- **Unify plan-driven dispatch with the toolkit.** Open questions: plugin or platform, dispatch from plan files or issues, whether difficulty labels become required, and whether `check-plan.py` checks for dependency cycles.

## Open questions

None at the moment.

## Parked

- **Deferred: retire `plugins/install-superpowers.sh`.** It stays as the rollback path until the per-harness skill trigger check passes and a stable period follows.

## Recently shipped

- **Superpowers parity and lifecycle skill trimming (2026-10-25).** Add `/start-debugging` with a blameless incident review, copy `tdd`, `receiving-code-review` and `research`, adapt `handoff`, and merge the remaining Superpowers ideas into the lifecycle skills, which are now shorter. Add an `uninstall` mode to the Superpowers installer and drop the docs that required it.

- **Flexible lifecycle skills (2026-10-21).** Add `/start-brainstorm`, `/start-design`, and the shared design quality contract. Select phases across task categories, use native in-session plans when appropriate, and support explicitly authorized autonomous workflows while preserving retained human gates and prior decisions.

- **Consistent SDLC artifacts, first increment (2026-10-03).** [PR 6](https://github.com/carlosboeing/agentic-toolkit/pull/6) delivers the shared plan quality contract, `/start-planning` discovery and advisory checker, `/start-implementation` controller, and corrected progress and worktree guidance.

- **Agent memory selection guidance (2026-09-30).** Separate capture, retrieval and authority; document low-cost observer candidates and local alternatives, with limits on the evidence. No provider switch or migration is recorded as complete.

- **OpenCode 2.x plugin compatibility (2026-09-23).** The Mermaid validator plugin now serves both OpenCode plugin APIs from one file: 2.x, and 1.x from 1.18.29. Tests assert the installed plugin's shape and guard behavior against both APIs.
- **First public release (2026-09-23).** The repository is public, with branch protection, CI and security reporting in place.
- **Initial public release preparation.** Public documentation, governance files, privacy guard, relative-link checker and CI.
