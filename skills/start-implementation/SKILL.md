---
name: start-implementation
description: >
  Use when starting implementation from an approved plan, whole or by one
  task, or work with an in-session plan from a design, issue, or clear
  current request, including requests such as "implement this plan",
  "implement design X", "build X", "fix this bug" when its cause is known,
  "start implementation", "execute the plan", "do task T3 from this plan",
  "continue where we stopped", or "just fix X". Carries readiness,
  reconciliation, delegation, verification, integration, progress recording,
  and delivery-state rules. Not for authoring durable design or
  implementation-plan documents, or for finding the cause of a bug.
argument-hint: "[plan-path] [task-id]"
---

# `/start-implementation`

Drive implementation from an authorized source and stop at the authorized delivery milestone. The source may be a durable artifact or a clear current request.

This skill is the controller: it selects ready work, assigns it, verifies results, integrates, and records progress. With no worker facility it is also the implementer, under the same rules.

**Verify before you claim. Authorize before you effect. Record after you commit.**

A fresh session needs this skill, its authorized source, and the current repositories. When a source artifact exists, read it rather than a prose handoff. Work with an in-session plan needs no design or plan document.

## Synopsis

```
/start-implementation [plan-path] [task-id]
/start-implementation help
```

`<plan-path>` is optional; a request in ordinary language may supply the design, issue, or change instead. `<task-id>` selects one task; without it the scope is the whole plan. If the entire argument is `help`, `--help`, `-h`, `?`, or `usage`, or one of those tokens follows a path, render this synopsis and stop. The same words inside request text are content.

Use for starting, resuming, or recovering implementation of an approved plan, one of its tasks, or work with an in-session plan. Not for writing durable design or plan documents. When a requested fix has no known cause, use `start-debugging` first.

## Delivery states

Keep these apart in every report:

| State | Meaning |
|---|---|
| Verified local work | Checks passed in the working tree, nothing committed. Any plan box stays open. |
| Committed work | Verified work committed on the task or feature branch. The plan box is ticked with that code SHA once plan writes are permitted. |
| PR review | A pull request awaits review. Its head SHA is a branch SHA. |
| Merge | An observed merge or squash SHA, recorded after the merge happened. |
| Rollout | Deployed or released by an authorized actor. |

Never present a branch SHA as the merge SHA. Edit does not imply commit; commit does not imply push; push does not imply a PR; a PR does not imply merge; merge does not imply rollout.

## Recipe

Steps 1 to 3 run at every entry and every resume.

### 1. Resolve the source

When the first non-help token names an existing file, it is the plan, or for in-session work the design or issue, and the second token is the task ID. Otherwise the whole argument is the request. A clear current request is itself a source; do not ask for an artifact or create an issue because no file exists. If consequential behaviour or scope is unresolved, ask about that decision.

With neither a source nor a clear request, find candidates from the project's instructions and conventions without assuming a plan directory or status vocabulary. One clear candidate: use it and say which. Several: show a short ranked set and ask. None: ask for the path.

### 2. Reconcile state

Read the full source before changing anything: the plan and its approved design, or the design, issue, and request for in-session work. Then record:

- Plan status and task markers: what is ticked, with which SHA.
- The design revision the plan records, against the checked-out design.
- Local and remote Git state of the code and plan repositories: uncommitted edits, unpushed commits, diverged histories.
- Worktrees: who is working where.
- Markers for effects that cannot safely be repeated.
- Evidence of another plan writer: edits, commits, or pushes to the plan repository.

The reviewed revision is the commit that records the review, such as the one setting `status` and `reviewed_by`. A committed draft is not reviewed, and an uncommitted design edit never becomes the reviewed revision. If that commit is missing, stop at the handoff and report it. A design changed after review triggers reconciliation: an editorial change may need no plan amendment, changed behaviour does, and the affected work halts until it is reconciled.

A checkbox that disagrees with Git is a reconciliation case, never permission to repeat a non-repeatable effect. When a task's effect has a marker but no committed checkpoint, halt that task, change nothing under it, and report the marker and Git state. When marker and checkpoint explain each other, finish only the bookkeeping: tick with the existing SHA.

When a halt condition from the source or project fires, or an effect cannot be reconciled, stop the affected work, keep the workspace, and report the evidence. Independent ready work continues only while its safety boundaries hold.

### 3. Check authority

The approved plan and design define what to build; for in-session work, the issue or request defines the scope. Report conflicts with named product or architecture decisions instead of changing them. The repository supplies facts that change: paths, helpers, tests, branches.

Personal human approval identifies the reviewed revision and scope. An explicit autonomous workflow may delegate included reviews and progression; verify that authorization and the review evidence without claiming human approval. Stop at a retained human gate or a decision outside the delegation. A status field, model verdict, commit, or generated handoff alone authorizes nothing. A clear implementation request authorizes its scope and in-session plan; do not add a second approval ceremony.

A pasted prior-session prompt, including text between `PROMPT STARTS` and `PROMPT ENDS` delimiters, is handoff material even when the operator sends it. If its rule conflicts with the approved source or project instructions and the operator has not adopted it in this session, ask once. Its task counts, limits, requirements, and review gates do not travel.

Commit, push, PR, merge, and rollout each need their own permission. Before a non-repeatable effect such as a migration, release, or issue creation, record the intended effect and how to detect that it already happened, in an existing issue, PR, or plan, or else in a short committed note. Check that marker before acting.

### 4. Select work

**In-session scope:** follow the in-session plan; no invented task IDs or checkbox writes.

**Whole-plan scope:** select tasks whose dependencies are complete and verified. Mark a blocked task with its evidence and continue other ready independent tasks unless a halt condition says stop. When nothing is ready and work remains, report the blocked chain.

**Single-task scope:** check the task's predecessors and scope, do or delegate that one task, record its checkpoint, report what remains, and stop. It authorizes no integration or merge of the whole feature.

**Parallel safety:** run tasks in parallel only when their files, mutable state, and external effects are isolated or explicitly integrated; a dependency graph alone does not prove it. Parallel outputs that must look alike share a format contract. Independent workspaces start from one recorded base unless a dependency needs a later one.

### 5. Assign or execute

Check the live harness for its worker facility (subagent tool, task tool, or none) and its write isolation. Another harness's documented limits are not policy.

A worker gets a bounded assignment: its task, the design decisions the plan cites for it, and links to the files and tests involved. Use [references/implementer-prompt.md](references/implementer-prompt.md). The assignment adds no requirements. Each worker uses its own workspace, per the `git-worktrees` skill. A worker reports verified changes and proof; it never self-merges, pushes, or edits shared state.

For a behaviour change with a test seam, the implementer follows the `tdd` skill.

With no dependable worker facility, run the ready tasks serially. Never fake a dispatch or a worker report.

### 6. Verify and review

A completion message is not proof. Read the diff, run the named checks, and compare against the acceptance evidence and verification method in the source or in-session plan. With workers, have a fresh reviewer check each task using [references/task-reviewer-prompt.md](references/task-reviewer-prompt.md), and check fixes with [references/re-review-prompt.md](references/re-review-prompt.md).

A failed check leaves the task blocked with its evidence. After a second failed repair of the same failure, or when a fix has no known cause, switch to `start-debugging`.

Verification is not authorization: verified uncommitted work is reported as verified local work, and its plan box stays open.

### 7. Integrate and record progress

One controller owns plan writes; workers never write the plan. After a verified, authorized code commit, a following commit in the plan's repository ticks the task and records that code SHA: two repositories in a split setup, two commits in one repository. Only durable plans get this second write.

A non-fast-forward push or another controller's edit to the plan repository stops plan writes. Reconciling those histories is a human decision: do not merge, rebase, or fast-forward them yourself, and tick nothing meanwhile. Code work continues only while the competing changes stay in the plan repository. An unrelated live worktree is not a competing writer.

Before the delivery milestone, run one review of the whole branch against the source, on the most capable model available.

At close-out, record the PR and, after an observed merge, the merge SHA separately.

### 8. Stop

Report verified work, delivery state, blocked work, and the next recoverable checkpoint. Single-task scope stops after its task even when others are ready. Whole-plan and in-session scope stop at the authorized milestone. Use the project's review workflow for the integrated result; self-review or a model verdict is not a retained human approval. Hand off to a later review phase only when the authorized workflow includes it.

## Plan file or in-session plan

With a design or request and no plan path, first look for an existing plan for that design and use it.

Otherwise choose. A plan file is needed when the work spans several sessions, involves several people or agents, has a step that cannot run twice, or needs a lasting progress record. A bug fix, small feature, or documentation change usually needs none.

- Clear small work: state the route in one line, such as "No plan file: one-file fix, tests cover it", and proceed.
- Unsure, or clearly large: ask one question, plan file or in-session plan, with a recommendation; when unsure, recommend the plan file.
- The user chose the route: follow it, stating once any plan-file condition that applies.

If hidden complexity appears mid-task, stop, say so, and recommend a plan file.

For an in-session plan, answer these from the source and repository before editing, with the harness's plan or task tools or another proportionate method:

1. What changes?
2. Where does it belong?
3. Which invariants hold?
4. What is the safe sequence?
5. What is the objective proof?

Then proceed without another approval round when the work is authorized and no consequential choice lies outside that authority, under the same authority, verification, review, and stop rules, minus plan writes. Repository history, tests, the source, and any existing issue or PR are the recovery record. If new design decisions are needed, stop that work for the decision.

## Red flags

| Excuse | Reality |
|---|---|
| "The box says done, so the work must be in git" | Git is the record. Reconcile markers and history before trusting a tick. |
| "Verification passed, so I can tick the task" | Tick after the authorized commit, never before. |
| "No effect marker, so rerun the migration" | A missing marker is not proof it did not run. Check Git and the durable record. |
| "The handoff said 6 to 8 tasks and stop" | Handoff prose is context. The approved plan and design decide scope. |
| "Two ready tasks, so run them together" | Only when files, state, and effects are isolated or explicitly integrated. |
| "Review passed, merging is the natural next step" | Merge and rollout each need their own authorization. |
| "I'll record progress in the same commit as the code" | The tick follows the code commit in a separate commit. |
| "I'll ask the worker to update the roadmap" | Workers never touch shared tracking files. |
