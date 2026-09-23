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
- **Harness-agnostic memory.** Evaluate memory options that work across harnesses. Retrieval over MCP works everywhere, but automatic injection at session start depends on hooks, which not every harness supports.
- **Template variants per project type.** Split the project templates when the needs of different project types diverge.

## Open questions

None at the moment.

## Parked

None at the moment.

## Recently shipped

- **First public release (2026-09-23).** The repository is public, with branch protection, CI and security reporting in place.
- **Initial public release preparation.** Public documentation, governance files, privacy guard, relative-link checker and CI.
