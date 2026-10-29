---
name: start-retrospective
description: >
  Synthesize lessons, execution evidence, and review findings into improvements to how work is done, including requests for a retrospective, retro, or workflow assessment after delivery or repeated problems. Not for artifact readiness review or finding the cause of an active failure.
argument-hint: "[workstream or source-path] [help]"
---

# `/start-retrospective`

Assess how work was done and choose evidence-supported improvements. A retrospective is optional; continuous lessons can be captured without one.

## Synopsis

```text
/start-retrospective [workstream or source-path]
/start-retrospective help
```

For an entire help argument (`help`, `--help`, `-h`, `?`, `usage`), or one following a source path, show the synopsis and stop. Such words within the work description are content.

## Procedure

1. Establish the workstream and question. Read the original goal, accepted requirements, architecture decisions, source changes, execution checkpoints, available logs and telemetry, continuous lessons, and artifact or code-review findings. Reconcile actual local, commit, PR, merge, and rollout state. Missing telemetry is a stated limitation, not a reason to invent measurements.
2. Separate observed outcomes, hypotheses, confirmed causes, and unknowns. Compare intended and delivered results, what helped, what failed, recurring roadblocks, context loss, and review limitations. Keep the assessment blameless. Do not generalize one observation into a universal rule or treat an anecdote as a settled diagnosis.
3. Synthesize reusable lessons and possible improvements. Link raw evidence instead of duplicating it. Distinguish reviews, which assess artifacts and behavior, from lessons recorded during work and this retrospective, which improves the process. An incident review can use the existing debugging method without requiring another report.
4. Give each follow-up an owner and disposition: implement within existing authorization, add to the authoritative backlog, defer, or reject with a reason. Assign a later check of adopted changes. Tracker writes and new implementation follow actual scope; the retrospective does not authorize them automatically.
5. Keep the result in chat for small work, or write a `type: retro` report in the declared retrospective location when requested or worth preserving. Standalone continuous lessons use `type: lesson`, normally under `6-retros/lessons/<workstream>/`, and can remain draft. Their actionable follow-ups belong in the delivery tracker. Consolidation preserves evidence and grants no deletion, global-instruction edit, or installation authority.

## Context and boundaries

Use project conventions for storage, metadata, review, and Git actions. Discover actual locations and types, including legacy layouts. On resume, reconcile source revisions, Git state, checkpoints, and authority.

Read original product and architecture sources and relevant prior lessons. For substantial work, retain stable consequential references and account for preserved obligations, authorized changes, reasoned exclusions, and unresolved decisions. Reconcile source differences with affected work and reviews; block unresolved or unauthorized consequential changes. Keep scope, authority, verified progress, evidence, unresolved decisions, and next checkpoint visible in existing records.

Stop at a phase-only boundary. Explicit autonomous scope can include transitions and delegated reviews; record its scope, retained human gates, and endpoint once when recovery needs it. Stop at retained human gates or consequential choices outside that scope. Agent review never proves personal human approval, and status alone grants no authority. External effects follow actual authorization.

Capture reusable lessons with context, evidence, workaround and result, and confirmed cause or uncertainty, in an existing record or a standalone file when useful. Avoid logging every transient error. End with the outcome, material gaps, and next step. Recommend the same or a fresh session, and human or independent review, when context and consequence warrant it. Recommendations authorize no later phase.
