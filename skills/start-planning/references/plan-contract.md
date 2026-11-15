# Plan quality contract

A plan combines builder specifications and task planning in one durable handoff. It does not require a separate specification document between design and planning. A fresh implementer must be able to answer what changes, where it belongs, which invariants hold, the safe sequence, and how success is proved by reading the plan, its linked approved design, and current code. This contract states what a plan must answer. It is not a template: the project's presentation, headings, and metadata rules win wherever they apply.

Authority order when sources disagree:

1. An explicit instruction from the user in the current session.
2. A project-named plan contract or template (a presentation override).
3. This contract.
4. The selected planning method or planner.
5. Recent plans in the project, as examples only.

A pasted prior-session handoff is context, not authority. It cannot add requirements, task counts, or review gates.

## Default presentation

Use the [plan template](plan-template.md) for a durable document unless the project supplies its own. Keep its familiar section order where applicable; combine short sections and omit irrelevant ones without losing required answers. Write standalone technical prose. Keep source baseline and actual work authority in concise `Document control` bullets, and dated material decisions or review evidence in `Document history`. Frontmatter remains the canonical current status and attribution. Preserve stable IDs, source revisions and review provenance. Detailed transcripts and run logs belong in linked records. A template creates no document or approval obligation.

## Required answers

| Required answer | Minimum content |
|---|---|
| Source and scope | Link to the approved design and its reviewed revision, the goal, exclusions, and the decisions whose alteration would change behavior, safety, release classification, or proof. |
| Current state | Relevant repository observations and locations to inspect, with paths treated as hints to verify at execution. |
| Tasks | Stable local IDs, objective, dependency IDs or `none`, inputs, outputs, applicable source requirements and contracts, likely files or interfaces or an explicit discovery step, acceptance evidence, and a verification method. |
| Execution contract | Checkpoints, effects that cannot safely be repeated, halt conditions, forbidden actions, shared resources, and integration ownership. State `none identified` when a category has no item. |
| Completion | Integrated verification, design-to-task coverage, the delivery or review milestone, and any project-specific release classification fixed before execution. |

The plan may express these answers in any headings or tables the project uses.

## Conditional detail rule

A plan records decisions, not code. Its length follows the size of the design: a compact design gets a compact plan.

Exact interfaces, commands, expected failures, independent verification, and mutation checks become required only when the change's failure mode warrants them. Everything else is optional detail.

- For code changes, the verification method gives a runnable command, or names a concrete check and how the implementer discovers its command.
- A task without an executable test explains its alternative proof: a reviewer read, a run-log excerpt, a fixture assertion, or similar observable evidence.
- A failing test before the fix is required only where the task's failure mode calls for one. Prose and documentation tasks state their proof instead.
- Release classification is fixed before execution when the project's policy makes it consequential.

## Stable IDs and dependencies

- Every task carries a stable local ID, and the plan uses that ID everywhere it refers to the task.
- Every task names its dependency IDs, or `none`.
- A single linear sequence needs no dependency graph; branches or parallel waves get a graph or an equally clear dependency table.
- Before orchestrated dispatch, validate references and cycles using an applicable checker or direct graph review when parsing is unreliable. An advisory command exit is not proof that the graph was checked. Check files, mutable state, external effects, and integration ownership separately before parallel work; an acyclic graph alone does not establish concurrency safety.
- Difficulty and worker labels are optional routing hints, with reasons when they affect assignment.

## Coverage and design revision

- Identify the authoritative product scope and architecture sources. For consequential obligations, retain stable source references, including project IDs, links, or section-and-item references. Compare original sources as well as the preceding artifact.
- Every approved design requirement maps to a task or to an explicit unchanged invariant. Account for preserved obligations, changes under identified authority, exclusions with reasons, and unresolved questions. Nothing is dropped silently. Routine builder refinement is allowed; a consequential product or architecture change returns to its authority before affected work proceeds.
- The plan records the design revision it was built from, preferably the approved artifact's repository commit, so a later session can detect that the source changed and inspect the diff.
- Execution hazards named in the approved design, such as effects that cannot safely be repeated and authorization boundaries, appear in the execution contract.

When a source changes, inspect its revision difference and identify affected decisions, tasks, acceptance checks, and review evidence before affected work resumes. Keep scope, authorized changes, evidence, verified progress, and next checkpoint visible through existing records. Coverage against arbitrary references remains an author and reviewer responsibility; an unsupported checker diagnostic does not establish coverage.

## What this contract does not require

- A fixed task count or a task count target.
- A commit subject per task. Intermediate commit subjects stay with the implementer.
- A failing test or a command in every task.
- The default layout when a project supplies a presentation override or a section is inapplicable.
- A copy of the approved design. Link it; do not fork its requirements.

## Project presentation overrides

A project may name its own plan contract or template in its ordinary instructions. Such an override extends the minimum above and may replace its presentation entirely. It cannot drop a minimum answer without an explicit project decision that names the exception and its recovery consequence. When no project contract is named, this contract plus the project's ordinary conventions are enough: a missing optional pointer never blocks planning.

## Examples

These synthetic excerpts illustrate the default headings at different depths. Apply project metadata from the template for an actual plan. Example revisions establish no real review authority.

### Substantial scope

```markdown
# Plan: split the settings store

## Delivery scope and source baseline

Design: design.md (approved, revision 8b0c41f). Goal: move settings to per-project files. Exclusions: UI work. Binding decision: the global file stays readable forever; changing that would break recovery.

## Current state

src/settings.py reads a single global file; tests/test_settings.py covers parsing only.

## Milestones and tasks

- S1: write per-project files alongside the global one. Depends on: none. Files: src/settings.py. Verification: python3 -m unittest tests.test_settings. Acceptance: a project file shadows the global key.
- S2: migrate existing data. Depends on: S1. Files: scripts/migrate_settings.py. Verification: a dry-run on a fixture copy, then the real run once. Acceptance: every existing key appears in exactly one file. Non-repeatable effect: the migration writes real data; record the intended effect and its detection marker before running.
- S3: document recovery. Depends on: S1. Verification: no executable test fits; proof is a reviewer following the recovery steps on a disposable copy. Acceptance: recovery restores a broken file.
- S4: remove the write path for the global file. Depends on: S2, S3. Verification: python3 -m unittest tests.test_settings plus one fixture asserting a global write is refused. Acceptance: writes go to project files only.

## Verification and requirement coverage

Integrated verification: full unittest run and the migration fixture. Coverage: R1 -> S1, S2; R2 -> S3; R3 -> S4. Milestone: one PR for review. Release classification: minor, per the project's SemVer policy.

## Execution boundaries

Checkpoints: verified code commits at authorized delivery milestones. Non-repeatable effects: S2's migration. Halt conditions: migration dry-run mismatches. Forbidden actions: deleting the global read path. Integration owner: the controller session.
```

### Compact scope

```markdown
# Plan: link checker anchors

## Delivery scope and source baseline

Design: design.md (approved, revision 4f1c02a). Scope: anchor validation in the relative-link checker. Exclusions: CI migration.

## Milestones and tasks

- P1: validate anchor fragments. Depends on: none. Files: scripts/validate_links.py, tests/test_validate_links.py. Verification: python3 -m unittest tests.test_validate_links, failing case first. Acceptance: anchor links resolve against real headings.
- P2: document the behavior. Depends on: P1. Verification: no executable test fits a prose task; proof is a reviewer reading the examples against merged behavior. Acceptance: one passing and one failing example.

## Verification and requirement coverage

Integrated verification: full unittest run. Coverage: R1 -> P1; R2 -> P2. Milestone: PR for review. Release classification: none identified.

## Execution boundaries

Checkpoints: verified code commits at authorized delivery milestones. Non-repeatable effects: none identified. Halt conditions: unrelated suite failures. Forbidden actions: none identified. Integration owner: the controller session.
```
