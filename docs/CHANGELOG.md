# Changelog

All notable changes to this project are recorded here, newest first.

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
