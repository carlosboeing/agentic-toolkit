---
name: start-implementation
description: >
  Use when starting implementation from an approved plan, whole or by one
  task, or direct small work from an execution-ready design or issue,
  including requests such as "implement this plan", "start implementation",
  "execute the plan", "do task T3 from this plan", "continue where we
  stopped", or "just fix X". Carries readiness, reconciliation, delegation,
  verification, integration, progress recording, and delivery-state rules.
  Not for writing designs or plans.
argument-hint: "[plan-path] [task-id]"
---

# `/start-implementation`

Drive implementation from a durable approved source and stop at the authorized delivery milestone.

This skill is the controller. It selects ready work, assigns it, verifies results, integrates, and records progress. It is also the implementer when no worker facility exists. Both roles obey the same rules.

**Verify before you claim. Authorize before you effect. Record after you commit.**

A fresh implementation session needs this skill, an approved source, and the current repositories. It needs no prose handoff from an earlier session.

## Synopsis

```
/start-implementation [plan-path] [task-id]
/start-implementation help
```

`<plan-path>` is optional. When omitted, resolve the plan from the project as in step 1. `<task-id>` is optional: with it, the run is single-task scope; without it, whole-plan scope.

If `help`, `--help`, `-h`, `?`, or `usage` appears anywhere in the args, render this synopsis and stop.

Natural-language requests also activate when the intent is to start, resume, or recover implementation.

For direct small work, the source is an execution-ready design or issue instead of a plan. That entry is in "Direct small work".

## When to use

- An approved plan exists and implementation should start, resume, or recover.
- The user names one task from an approved plan.
- A small change has an execution-ready design or issue that answers the five readiness questions.

## When not to use

- Writing or revising the design or the plan.
- The user wants a conversation recap rather than work.

## Delivery states

Keep these apart in every report:

| State | Meaning |
|---|---|
| Verified local work | Checks passed in the working tree, nothing committed. The plan box stays open. |
| Committed work | Verified work is committed on the task or feature branch. The plan box is ticked with that code SHA once plan writes are permitted. |
| PR review | A pull request exists and awaits review. Its head SHA is a branch SHA. |
| Merge | An observed merge commit or squash SHA, recorded after the actual merge happened. |
| Rollout | The change is deployed or released by an authorized actor. |

Never present a branch SHA as the merge SHA. Permission to edit does not imply permission to commit; commit does not imply push; push does not imply a PR; a PR does not imply merge; merge does not imply rollout. Do not infer permission to merge or deploy.

## Recipe

Do these in order. Steps 1 to 3 run at every entry and every resume.

### 1. Parse args and resolve the source

The first non-help token, if present, is the plan path (or, for direct small work, the design or issue). The second, if present, is the task ID.

If no source is identified, discover plausible candidates from the project's own instructions, artifact conventions, and current structure. Do not assume a universal plan directory, status schema, or readiness vocabulary. Use whatever this project considers approved or current. One clearly intended candidate: use it and say which artifact was selected. Several materially plausible candidates: present a short ranked set and ask. None: ask for the path.

### 2. Reconcile state

Read the full approved plan and its approved design before changing anything. Then reconcile and record what you find:

- Plan status and task markers: what is ticked, with which recorded SHA.
- The design revision the plan records against the checked-out design.
- Local and remote Git state of the code and plan repositories: uncommitted edits, unpushed commits, non-fast-forward histories.
- Worktrees and task workspaces: who is working where.
- Effect markers for effects that cannot safely be repeated.
- Plan-writer ownership evidence: another writer's edits, commits, or pushes to the plan repository.

An uncommitted edit to an approved design never becomes the new approved revision and never authorizes work: halt every task that design governs, make no code or plan changes, and report the edit for reconciliation. A changed design revision triggers reconciliation, not automatic rejection: an editorial change may need no plan amendment, changed behavior does. A disagreement between a checkbox and Git is a reconciliation case, never permission to repeat a non-repeatable effect. When the task's own non-repeatable effect has a marker but no committed checkpoint of its work, the task is not verifiable: halt that task, make no further changes under it, and report the marker and git state for reconciliation. When the marker and a committed checkpoint do explain each other, finish the bookkeeping only: tick with the existing code SHA, without repeating the effect.

Halt conditions come from the plan. When one fires, when an effect cannot be reconciled, or when the approved source changed behavior without review, stop the affected work, preserve the workspace, and report the evidence. Continue independent ready work only when its safety boundaries still hold.

### 3. Check authority

The approved plan and design are the authority for what to build. The current repository supplies facts that can change: paths, helper names, tests, branch and remote state. A conflict among these inputs is reported, not resolved from an old conversation.

A pasted prior-session prompt, including text between `PROMPT STARTS` and `PROMPT ENDS` delimiters, is handoff material even when the operator submits it as a user message. If one of its rules conflicts with the approved source or project instructions and the operator has not explicitly adopted that rule in this session, ask once whether to adopt it. Its task counts, section limits, product requirements, and review gates do not travel. A user-authored current instruction remains authoritative.

Authorization for effects is separate from authorization for work. Commit, push, PR, merge, and rollout each need their own permission from the project or the user.

Before a non-repeatable effect such as a migration, release, or issue creation, record the intended effect and how to detect whether it already happened, in an existing issue, PR, or plan. If none exists, commit a short durable note first. Then check the marker before performing the effect.

### 4. Select work

**Whole-plan scope.** Select tasks whose dependencies are complete and verified. When one task blocks, mark it blocked with the observed evidence and continue other ready independent tasks unless a halt condition says stop. When no task is ready and work remains, report the blocked dependency chain. Do not invent an imaginary task.

**Single-task scope.** Check the named task's predecessors and scope before making changes. Perform or delegate that one task, record its checkpoint, report what remains, and stop. One task's completion does not authorize integration or merge of the whole feature.

**Parallel safety.** Dispatch tasks in parallel only when their outputs, files, mutable state, and external effects can be isolated or explicitly integrated. An asserted dependency graph alone does not prove safe concurrency. Similar parallel outputs share a format contract when inconsistent presentation would create integration work. Independent task workspaces start from the same recorded base unless a dependency requires a later base.

### 5. Assign or execute

Check the live harness for its actual worker facility (subagent tool, task tool, or none) and its write isolation. A documented nesting or delegation limit from another harness version is not policy.

A worker receives a bounded assignment: its task, the design decisions selected from the plan's coverage map, and direct source links to the files and tests involved. The assignment cannot add requirements; the worker can read the full design when needed. Each worker and each independent task uses its own workspace, per the `git-worktrees` skill.

A worker reports verified changes and proof. It does not self-merge, push, or edit shared state. The controller alone assigns tasks, integrates results, updates the plan, and decides whether the run reached the authorized milestone.

With no dependable worker facility, run the same ready tasks serially. Never fake a dispatch or a worker report.

### 6. Verify

The controller verifies results; a completion message is not proof. Read the diff, run the named checks, and compare against the task's acceptance evidence and the verification method in the plan.

A failed check leaves that task blocked with the observed evidence. A second failed repair attempt on the same high-risk acceptance check calls for a fresh diagnosis before more edits.

Verification is not authorization. Verified but uncommitted work is reported as verified local work and the plan box stays open.

### 7. Integrate and record progress

One controller owns plan writes. Workers never write the plan.

A non-fast-forward push or an observed edit by another controller to the plan repository stops plan writes. Reconciliation of the histories and task state is a human decision: do not merge, rebase, or fast-forward competing history yourself. Freeze plan writes and report the evidence; nothing is ticked in the meantime. Code work continues only while the competing evidence is confined to the plan repository; a competing writer touching the code repository or its history halts that work too. An unrelated live worktree alone is not a competing writer.

The two-commit sequence: after the verified, authorized code commit, a following commit in the plan's repository ticks the task and records that code SHA. Two repositories in a split setup, two commits in one repository. The plan commit's own SHA does not go in the plan. Only tasks governed by a durable plan get this second write.

At close-out, record the PR and, after an actual merge, the merge SHA separately. Record nothing guessed: a squash-merge SHA is written only after the merge is observed.

### 8. Stop

Report verified work, delivery state, blocked work, and the next recoverable checkpoint.

Single-task scope stops after its named task even when other tasks are ready. Whole-plan scope stops at the plan's authorized delivery milestone. Merging and rollout are separate authorizations; do not infer them.

## Direct small work

When the source is an execution-ready design or issue and no plan exists, answer the five readiness questions in the session before editing:

1. What changes?
2. Where does it belong?
3. Which invariants hold?
4. What is the safe sequence?
5. What is the objective proof?

Then implement with the same authority, verification, and stop rules as above, minus plan writes. Repository history, tests, and the PR are the recovery record. A separate plan becomes necessary when task dependencies, delegation, long pauses, risky external effects, or unresolved sequencing would be hard to reconstruct. Before any non-repeatable effect, commit the durable checkpoint from step 3 first.

## Red flags

Stop and correct if you are about to:

- Tick a task before its code commit exists
- Present a branch SHA as the merge SHA, or record a merge before it happened
- Repeat an effect because a checkbox looked wrong
- Complete or tick a task whose effect marker no committed checkpoint explains
- Continue design-governed work while the approved design has an uncommitted edit
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
