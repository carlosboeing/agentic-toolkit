# Changelog

All notable changes to this project are recorded here, newest first.

## Unreleased: initial public release

The first public version of the toolkit.

- **Skills:** `briefing`, `learn`, `schedule-resume`, `repo-standards` (with the `oss-standards` alias), `housekeeping`, `penmark-comments`, `git-worktrees`, `start-planning`, `capture-meeting` and `externalize-deliverable`.
- **Git hooks:** drift guard (`housekeep`, `post-merge`, `pre-push`) and the private-workbench guard (`pre-commit`).
- **Harness hooks:** Mermaid validation for Claude Code and OpenCode.
- **Synchronizer:** `scripts/sync-toolkit.sh` copies authored skills into the shared skill hub and repairs the harness links to it.
- **Guides and references:** project structure and conventions, model and effort routing, cross-harness instructions, plugin parity, browser automation, skill authoring, and repository house standards.
- **Templates:** default and open-source project scaffolds, and a lean Claude Code settings template.
- **Governance:** code of conduct, contributing guide, security policy, support guide, third-party notices, issue templates and CI.
- **Documentation standard:** every public document follows the standard in `CONTRIBUTING.md`: purpose first, plain English, tables and diagrams where they help, and dated sources for anything that changes.
