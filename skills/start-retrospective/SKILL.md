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

## Context, authority, and completion

Project instructions own location, metadata, review, and Git rules. Use the declared working-memory location and actual artifact types, including legacy layouts; do not create folders until needed. Read relevant prior lessons and applicable product and architecture sources. On resume, reconcile source revisions, uncommitted work, Git checkpoints, and current authorization rather than trust a recap or status alone.

A phase-only request stops at its boundary. Explicit full or partial autonomous scope can authorize included transitions and delegated reviews; record the scope, retained human gates, and stopping point once in an existing durable project record when recovery needs one. Personal human approval and readiness under delegated review are different. Use the project's review evidence and accountable reviewer convention; never claim the human read an artifact merely because an agent reviewed it. Commit, push, publication, installation, and other effects follow actual authorization and project rules.

For substantial handoffs, compare consequential obligations with their original authoritative sources as well as the preceding artifact. Retain stable references and account for preserved obligations, authorized changes, exclusions with reasons, and unresolved decisions. Inspect source revision differences and reconcile affected downstream work and reviews before proceeding. Keep scope, authority, verified progress, evidence, unresolved decisions, and next checkpoint visible through existing records. A small change can keep this context in session.

Capture reusable observations where encountered, with context, evidence, workaround and result, confirmed cause or uncertainty, and implications for later work. Use an existing record or a separate lesson when its discovery or concurrent writing value warrants it. Do not record every transient tool error as a permanent rule.

End with the result, material gaps, and a proportionate next-step recommendation. Explain whether the same session or a fresh session better fits context and review needs, and recommend independent or human review when consequence warrants it. A recommendation authorizes no later phase. Stop for retained human gates, the requested endpoint, or consequential decisions outside delegated scope.
