# Plan quality contract

A plan is a durable handoff. A fresh implementer must be able to answer what changes, where it belongs, which invariants hold, the safe sequence, and how success is proved by reading the plan, its linked approved design, and current code. This contract states what a plan must answer. It is not a template: the project's presentation, headings, and metadata rules win wherever they apply.

Authority order when sources disagree:

1. An explicit instruction from the user in the current session.
2. A project-named plan contract or template (a presentation override).
3. This contract.
4. The selected planning method or planner.
5. Recent plans in the project, as examples only.

A pasted prior-session handoff is context, not authority. It cannot add requirements, task counts, or review gates.

## Required answers

| Required answer | Minimum content |
|---|---|
| Source and scope | Link to the approved design and its reviewed revision, the goal, exclusions, and the decisions whose alteration would change behavior, safety, release classification, or proof. |
| Current state | Relevant repository observations and locations to inspect, with paths treated as hints to verify at execution. |
| Tasks | Stable local IDs, objective, dependency IDs or `none`, likely files or interfaces or an explicit discovery step, acceptance evidence, and a verification method. |
| Execution contract | Checkpoints, effects that cannot safely be repeated, halt conditions, forbidden actions, and integration ownership. State `none identified` when a category has no item. |
| Completion | Integrated verification, design-to-task coverage, the delivery or review milestone, and any project-specific release classification fixed before execution. |

The plan may express these answers in any headings or tables the project uses.

## Conditional detail rule

Exact interfaces, commands, expected failures, independent verification, and mutation checks become required only when the change's failure mode warrants them. Everything else is optional detail.

- For code changes, the verification method gives a runnable command, or names a concrete check and how the implementer discovers its command.
- A task without an executable test explains its alternative proof: a reviewer read, a run-log excerpt, a fixture assertion, or similar observable evidence.
- A failing test before the fix is required only where the task's failure mode calls for one. Prose and documentation tasks state their proof instead.
- Release classification is fixed before execution when the project's policy makes it consequential.

## Stable IDs and dependencies

- Every task carries a stable local ID, and the plan uses that ID everywhere it refers to the task.
- Every task names its dependency IDs, or `none`.
- A single linear sequence needs no dependency graph; branches or parallel waves get a graph or an equally clear dependency table.
- Difficulty and worker labels are optional routing hints, with reasons when they affect assignment.

## Coverage and design revision

- Every approved design requirement maps to a task or to an explicit unchanged invariant. Nothing is dropped silently, and the plan adds no requirement the design lacks.
- The plan records the design revision it was built from, preferably the approved artifact's repository commit, so a later session can detect that the source changed and inspect the diff.
- Execution hazards named in the approved design, such as effects that cannot safely be repeated and authorization boundaries, appear in the execution contract.

## What this contract does not require

- A fixed task count or a task count target.
- A commit subject per task. Intermediate commit subjects stay with the implementer.
- A failing test or a command in every task.
- One Markdown layout, heading set, or template.
- A copy of the approved design. Link it; do not fork its requirements.

## Project presentation overrides

A project may name its own plan contract or template in its ordinary instructions. Such an override extends the minimum above and may replace its presentation entirely. It cannot drop a minimum answer without an explicit project decision that names the exception and its recovery consequence. When no project contract is named, this contract plus the project's ordinary conventions are enough: a missing optional pointer never blocks planning.

## Examples

Both examples are written from scratch. They show two scopes, not two required layouts.

### Substantial scope

```markdown
# Plan: split the settings store

Design: design.md (approved, revision 8b0c41f). Goal: move settings to per-project files. Exclusions: UI work. Binding decision: the global file stays readable forever; changing that would break recovery.

Current state: src/settings.py reads a single global file; tests/test_settings.py covers parsing only.

- S1: write per-project files alongside the global one. Depends on: none. Files: src/settings.py. Verification: python3 -m unittest tests.test_settings. Acceptance: a project file shadows the global key.
- S2: migrate existing data. Depends on: S1. Files: scripts/migrate_settings.py. Verification: a dry-run on a fixture copy, then the real run once. Acceptance: every existing key appears in exactly one file. Non-repeatable effect: the migration writes real data; record the intended effect and its detection marker before running.
- S3: document recovery. Depends on: S1. Verification: no executable test fits; proof is a reviewer following the recovery steps on a disposable copy. Acceptance: recovery restores a broken file.
- S4: remove the write path for the global file. Depends on: S2, S3. Verification: python3 -m unittest tests.test_settings plus one fixture asserting a global write is refused. Acceptance: writes go to project files only.

Execution contract. Checkpoints: one commit per task. Non-repeatable effects: S2's migration. Halt conditions: migration dry-run mismatches. Forbidden actions: deleting the global read path. Integration owner: the controller session.

Completion. Integrated verification: full unittest run and the migration fixture. Coverage: R1 -> S1, S2; R2 -> S3; R3 -> S4. Milestone: one PR for review. Release classification: minor, per the project's SemVer policy.
```

### Compact scope

```markdown
# Plan: link checker anchors

Design: design.md (approved, revision 4f1c02a). Scope: anchor validation in the relative-link checker. Exclusions: CI migration.

- P1: validate anchor fragments. Depends on: none. Files: scripts/validate_links.py, tests/test_validate_links.py. Verification: python3 -m unittest tests.test_validate_links, failing case first. Acceptance: anchor links resolve against real headings.
- P2: document the behavior. Depends on: P1. Verification: no executable test fits a prose task; proof is a reviewer reading the examples against merged behavior. Acceptance: one passing and one failing example.

Execution contract. Checkpoints: one commit per task. Non-repeatable effects: none identified. Halt conditions: unrelated suite failures. Forbidden actions: none identified. Integration owner: the controller session.

Completion. Integrated verification: full unittest run. Coverage: R1 -> P1; R2 -> P2. Milestone: PR for review. Release classification: none identified.
```
