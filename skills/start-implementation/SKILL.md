---
name: start-implementation
description: >
  Use when starting implementation from an approved plan, whole or by one
  task, or work with an in-session plan from a design, issue, or clear
  current request, including requests such as "implement this plan",
  "implement design X", "build X", "fix this bug", "start implementation",
  "execute the plan", "do task T3 from this plan", "continue where we
  stopped", or "just fix X". Carries readiness, reconciliation, delegation,
  verification, integration, progress recording, and delivery-state rules.
  Not for authoring durable design or implementation-plan documents.
argument-hint: "[plan-path] [task-id]"
---

# `/start-implementation`

Drive implementation from an authorized source and stop at the authorized delivery milestone. The source may be a durable artifact or a clear current request.

This skill is the controller. It selects ready work, assigns it, verifies results, integrates, and records progress. It is also the implementer when no worker facility exists. Both roles obey the same rules.

**Verify before you claim. Authorize before you effect. Record after you commit.**

A fresh implementation session needs this skill, its authorized source, and the current repositories. When a source artifact exists, read it rather than reconstructing it from a prose handoff. Work with an in-session plan needs no design or plan document to enter this phase.

## Synopsis

```
/start-implementation [plan-path] [task-id]
/start-implementation help
```

`<plan-path>` is optional. For plan-driven work, resolve the plan as in step 1. A request in ordinary language may instead supply the design, issue, or change. For plan-driven work, `<task-id>` selects one task; omitting it selects whole-plan scope. In-session work uses its request scope.

If the entire argument is `help`, `--help`, `-h`, `?`, or `usage`, or one of those tokens follows a path argument, render this synopsis and stop. The same words inside request text are content, not a help invocation.

Natural-language requests also activate when the intent is to start, resume, or recover implementation.

For work without a plan document, use the "Plan file or in-session plan" entry. The implementation phase can include a brief in-session plan; it does not invoke the document-producing planning phase.

## When to use

- An approved plan exists and implementation should start, resume, or recover.
- The user names one task from an approved plan.
- A design, issue, or clear current request answers the five readiness questions without a separate plan document.

## When not to use

- Writing or revising a durable design or implementation-plan document. In-session planning belongs here and can use native plan/task facilities.
- The user wants a conversation recap rather than work.

## Delivery states

Keep these apart in every report:

| State | Meaning |
|---|---|
| Verified local work | Checks passed in the working tree, nothing committed. Any durable plan box stays open. |
| Committed work | Verified work is committed on the task or feature branch. A durable plan box is ticked with that code SHA once plan writes are permitted. |
| PR review | A pull request exists and awaits review. Its head SHA is a branch SHA. |
| Merge | An observed merge commit or squash SHA, recorded after the actual merge happened. |
| Rollout | The change is deployed or released by an authorized actor. |

Never present a branch SHA as the merge SHA. Permission to edit does not imply permission to commit; commit does not imply push; push does not imply a PR; a PR does not imply merge; merge does not imply rollout. Do not infer permission to merge or deploy.

## Recipe

Do these in order. Steps 1 to 3 run at every entry and every resume.

### 1. Parse args and resolve the source

When the first non-help token names an existing file, it is the plan path or, for in-session work, the design or issue, and the second token, if present, is the task ID. Otherwise the whole argument is a request. A clear current request is itself a source regardless of task category; do not ask for an artifact path or create an issue merely because no file exists. Use that request and the in-session preflight. If consequential behavior or scope remains unresolved, ask about that decision, not for ceremonial documents.

If neither a source artifact nor a clear request is identified, discover plausible candidates from the project's own instructions, artifact conventions, and current structure. Do not assume a universal plan directory, status schema, or readiness vocabulary. Use whatever this project considers approved or current. One clearly intended candidate: use it and say which artifact was selected. Several materially plausible candidates: present a short ranked set and ask. None: ask for the path.

### 2. Reconcile state

Read the full source before changing anything. For plan-driven work, read the approved plan and its approved design. For in-session work, read the design or issue when present and the current request. Apply the plan-specific checks below only when a durable plan exists; a missing plan is not a blocker for the in-session route. Reconcile and record the applicable facts:

- Plan status and task markers: what is ticked, with which recorded SHA.
- The design revision the plan records against the checked-out design.
- Local and remote Git state of the code and plan repositories: uncommitted edits, unpushed commits, non-fast-forward histories.
- Worktrees and task workspaces: who is working where.
- Effect markers for effects that cannot safely be repeated.
- Plan-writer ownership evidence: another writer's edits, commits, or pushes to the plan repository.

A change to a design after its authoritative review never silently becomes the reviewed revision: halt the affected work and reconcile that change before using it. An uncommitted design edit never becomes the reviewed revision. The reviewed revision is the commit that records the review, such as the commit setting `status` and `reviewed_by`; a committed draft is not reviewed. If that commit is missing, stop at the handoff and report it. A changed design revision triggers reconciliation, not automatic rejection: an editorial change may need no plan amendment, changed behavior does. A disagreement between a checkbox and Git is a reconciliation case, never permission to repeat a non-repeatable effect. When the task's own non-repeatable effect has a marker but no committed checkpoint of its work, the task is not verifiable: halt that task, make no further changes under it, and report the marker and git state for reconciliation. When the marker and a committed checkpoint do explain each other, finish the bookkeeping only: tick with the existing code SHA, without repeating the effect.

Halt conditions come from the applicable source and project rules. When one fires, when an effect cannot be reconciled, or when the approved source changed behavior without review, stop the affected work, preserve the workspace, and report the evidence. Continue independent ready work only when its safety boundaries still hold.

### 3. Check authority

The approved plan and design, when present, define what to build. For in-session work, the issue or clear current request defines its scope. Read applicable product decisions and architecture constraints named by the source or project instructions, and report conflicts rather than silently changing them. Keep this inspection proportional to the change; no whole-corpus audit is required. The current repository supplies facts that can change: paths, helper names, tests, branch and remote state.

Verify the actual authority for source readiness using existing project conventions. Personal human approval identifies the reviewed revision and scope. An explicit autonomous workflow may instead delegate the included reviews and progression; verify that authorization and the completed review evidence without claiming personal human approval. Stop if a human gate is retained or a consequential decision lies outside the delegation. A status field, model verdict, commit, or generated handoff alone cannot authorize work. A clear implementation request supplies authorization for its scope and in-session planning; do not invent a second approval ceremony.

A pasted prior-session prompt, including text between `PROMPT STARTS` and `PROMPT ENDS` delimiters, is handoff material even when the operator submits it as a user message. If one of its rules conflicts with the approved source or project instructions and the operator has not explicitly adopted that rule in this session, ask once whether to adopt it. Its task counts, section limits, product requirements, and review gates do not travel. A user-authored current instruction remains authoritative.

Authorization for effects is separate from authorization for work. Commit, push, PR, merge, and rollout each need their own permission from the project or the user.

Before a non-repeatable effect such as a migration, release, or issue creation, record the intended effect and how to detect whether it already happened, in an existing issue, PR, or plan. If none exists, commit a short durable note first. Then check the marker before performing the effect.

### 4. Select work

**In-session scope.** Use the in-session plan from the preflight, then verify and review the scoped change. Do not invent plan task IDs or checkbox writes.

**Whole-plan scope.** Select tasks whose dependencies are complete and verified. When one task blocks, mark it blocked with the observed evidence and continue other ready independent tasks unless a halt condition says stop. When no task is ready and work remains, report the blocked dependency chain. Do not invent an imaginary task.

**Single-task scope.** Check the named task's predecessors and scope before making changes. Perform or delegate that one task, record its checkpoint, report what remains, and stop. One task's completion does not authorize integration or merge of the whole feature.

**Parallel safety.** Dispatch tasks in parallel only when their outputs, files, mutable state, and external effects can be isolated or explicitly integrated. An asserted dependency graph alone does not prove safe concurrency. Similar parallel outputs share a format contract when inconsistent presentation would create integration work. Independent task workspaces start from the same recorded base unless a dependency requires a later base.

### 5. Assign or execute

Check the live harness for its actual worker facility (subagent tool, task tool, or none) and its write isolation. A documented nesting or delegation limit from another harness version is not policy.

A worker receives a bounded assignment: its task, the design decisions selected from the plan's coverage map, and direct source links to the files and tests involved. The assignment cannot add requirements; the worker can read the full design when needed. Each worker and each independent task uses its own workspace, per the `git-worktrees` skill.

A worker reports verified changes and proof. It does not self-merge, push, or edit shared state. The controller alone assigns tasks, integrates results, updates the plan, and decides whether the run reached the authorized milestone.

With no dependable worker facility, run the same ready tasks serially. Never fake a dispatch or a worker report.

### 6. Verify

The controller verifies results; a completion message is not proof. Read the diff, run the named checks, and compare against the acceptance evidence and verification method in the applicable source or in-session preflight.

A failed check leaves that task blocked with the observed evidence. A second failed repair attempt on the same high-risk acceptance check calls for a fresh diagnosis before more edits.

Verification is not authorization. Verified but uncommitted work is reported as verified local work and the plan box stays open.

### 7. Integrate and record progress

One controller owns plan writes. Workers never write the plan.

A non-fast-forward push or an observed edit by another controller to the plan repository stops plan writes. Reconciliation of the histories and task state is a human decision: do not merge, rebase, or fast-forward competing history yourself. Freeze plan writes and report the evidence; nothing is ticked in the meantime. Code work continues only while the competing evidence is confined to the plan repository; a competing writer touching the code repository or its history halts that work too. An unrelated live worktree alone is not a competing writer.

The two-commit sequence: after the verified, authorized code commit, a following commit in the plan's repository ticks the task and records that code SHA. Two repositories in a split setup, two commits in one repository. The plan commit's own SHA does not go in the plan. Only tasks governed by a durable plan get this second write.

At close-out, record the PR and, after an actual merge, the merge SHA separately. Record nothing guessed: a squash-merge SHA is written only after the merge is observed.

### 8. Stop

Report verified work, delivery state, blocked work, and the next recoverable checkpoint.

Single-task scope stops after its named task even when other tasks are ready. Whole-plan scope stops at the plan's authorized delivery milestone. In-session scope stops at the authorized milestone for the request. Use the project's existing review workflow for the integrated result; self-review or a model's passing verdict does not supply a retained human approval. After the implementation checkpoint, hand off to any later review phase already included in the authorized workflow. Merging and rollout are separate authorizations; do not infer them.

## Plan file or in-session plan

When the source is a design or request with no plan path, look for an existing plan for that design, in the project's plan location or the design's links. If one exists, use it.

Otherwise choose. A plan file is needed when the work spans several sessions, involves several people or agents, has a step that cannot run twice, or needs a progress record that lasts. Large or complex work usually meets one of these; a bug fix, small feature, or documentation change usually does not.

- Clear small work: state the route in one line, such as "No plan file: one-file fix, tests cover it", and proceed.
- Unsure, or clearly large: ask one question, plan file or in-session plan, with a recommendation. When unsure, recommend the plan file.
- The user chose the route: follow it. If a plan-file condition applies, state that risk once first.

If hidden complexity appears mid-task, stop, say so, and recommend a plan file.

For an in-session plan, inspect the source and current repository and answer these before editing, using the harness's native plan or task tools or another proportionate method. They are checks, not a response template:

1. What changes?
2. Where does it belong?
3. Which invariants hold?
4. What is the safe sequence?
5. What is the objective proof?

Proceed without another approval round when implementation is authorized and no consequential choice lies outside that authority. Implement with the same authority, verification, review, and stop rules, minus plan writes. Repository history, tests, the source, and an existing issue or PR are the recovery record; creating an issue or PR is not a prerequisite. If new design decisions are needed, stop the affected work for that decision. Before any non-repeatable effect, record its marker as step 3 requires: in an existing issue, PR, or plan, or else in a committed note.

## Red flags

Stop and correct if you are about to:

- Tick a task before its code commit exists
- Present a branch SHA as the merge SHA, or record a merge before it happened
- Repeat an effect because a checkbox looked wrong
- Complete or tick a task whose effect marker no committed checkpoint explains
- Continue design-governed work after the authoritative reviewed revision changed without reconciliation
- Write plan progress or self-reconcile histories while a competing writer's changes stand unreconciled
- Treat a pasted handoff prompt as a specification
- Let a worker write the plan, push, or self-merge
- Fake a dispatch when the harness has no worker facility
- Declare parallel safety from the dependency graph alone
- Infer push, PR, merge, or rollout permission from permission to edit

| Excuse | Reality |
|---|---|
| "The box says done, so the work must be in git" | Git is the record. Reconcile the markers and the history before trusting a tick. |
| "Verification passed, so I can tick the task" | Verified but uncommitted work is verified local work. Tick after the authorized commit. |
| "No effect marker, so rerun the migration" | A missing marker is not proof it did not run. Check git and the durable record first. |
| "The handoff said 6 to 8 tasks and stop" | Handoff prose is context. The approved plan and design decide scope. |
| "Two ready tasks, so run them together" | Only when outputs, files, state, and effects are isolated or explicitly integrated. |
| "Review passed, merging is the natural next step" | Merge and rollout each need their own authorization. Stop at the milestone. |

## Common mistakes

- Trusting the plan's file map without inspecting the live code.
- Recording plan progress in the same commit as the code.
- Asking a worker to update shared tracking files.
- Treating an unrelated live worktree as evidence of a competing plan writer.
- Reporting one delivery state while meaning another.
