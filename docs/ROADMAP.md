# Roadmap

This is the forward view of Agentic Toolkit: what is being worked on, what comes next, and what has shipped. To suggest or discuss an item, open an [issue](https://github.com/carlosboeing/agentic-toolkit/issues).

## In flight

None at the moment.

## Next actions

- **Penmark anchors that survive Markdown formatters.** A formatter that runs on save can move a Penmark block comment away from the block it targets. Anchor block comments to the next non-blank Markdown block, and add formatter-survival tests.
- **Phase skills for the rest of the delivery workflow.** Add `/start-brainstorm`, `/start-design` and `/start-implementation` alongside the existing `/start-planning`, so each phase of brainstorm, design, plan and implementation has an explicit entry point.
- **Codex parity follow-up.** Decide whether Codex should get hook-level RTK filtering and Mermaid validation once its plugin packages support hooks.

## Future considerations

- **Native-first tool routing.** Let each harness prefer its own built-in tools where they are equivalent, instead of prescribing one tool set for every harness.
- **`/init-project` skill.** One skill to scaffold a new project, fill an empty directory, or retrofit the documentation conventions onto an existing project.
- **Distribution for tools that bundle agent files.** Package a command-line tool together with its skills, hooks and commands so users do not assemble the pieces by hand.
- **Harness-agnostic memory.** [Selection guidance](../guides/guide-agent-memory-selection.md) and a [dated options comparison](../reference/reference-agent-memory-options.md) are documented. A trial of cheaper observers or local replacements remains open; verify capture, cross-harness recall and backup restoration before adopting one.
- **Template variants per project type.** Split the project templates when the needs of different project types diverge.

## Open questions

None at the moment.

## Parked

None at the moment.

## Recently shipped

- **Agent memory selection guidance (2026-09-30).** Separate capture, retrieval and authority; document low-cost observer candidates and local alternatives, with limits on the evidence. No provider switch or migration is recorded as complete.

- **OpenCode 2.x plugin compatibility (2026-09-23).** The Mermaid validator plugin now serves both OpenCode plugin APIs from one file: 2.x, and 1.x from 1.18.29. Tests assert the installed plugin's shape and guard behavior against both APIs.
- **First public release (2026-09-23).** The repository is public, with branch protection, CI and security reporting in place.
- **Initial public release preparation.** Public documentation, governance files, privacy guard, relative-link checker and CI.
