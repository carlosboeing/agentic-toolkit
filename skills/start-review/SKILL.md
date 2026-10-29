---
name: start-review
description: >
  Use when starting the review phase or coordinating an integrated review of
  lifecycle artifacts and delivered behavior against intent. Not for a targeted
  document or code review, received findings, or a review-loop assignment that
  already has a specialist method.
argument-hint: "[artifact, change, or delivery scope] [help]"
---

# `/start-review`

Assess fidelity to intent and readiness using the project's review methods. This entry coordinates review; it creates no competing review engine.

## Synopsis

```text
/start-review [artifact, change, or delivery scope]
/start-review help
```

For an entire help argument (`help`, `--help`, `-h`, `?`, `usage`), show the synopsis and stop. The same words within a review request are content.

## Procedure

1. Resolve the artifact or change and review scope. Read project instructions and inspect available review skills and harness capabilities before starting. Reconcile the exact source revision, actual diff, product scope, architecture decisions, applicable acceptance obligations, and verification evidence. Ask only when materially different scopes remain plausible. Review sources directly rather than a chain of summaries.
2. State the selected capability and why it fits. An explicitly requested specialist keeps its method. Use `penmark-comments` for targeted local Markdown review, the harness's code-review capability for ordinary code review, and `receiving-code-review` when evaluating received findings. In a configured CrossRev PR loop, use its workflow and `pr-review` or `pr-resolve` as applicable. Follow applicable specialist instructions, including output or permission requirements. Do not start duplicate reviews for the same request merely because descriptions share words.
3. Scale depth and model choice to consequence and project requirements. Review applicable checkpoints and the integrated result, without inventing a review after every task. Independent review needs a separate authorized reviewer with original sources and identified scope. A serial self-check is valid limited evidence, never independent review. If a requested facility cannot run, report that limitation and use an authorized fallback or leave the review pending.
4. Check source fidelity, consequential contracts and adverse cases, correctness, architecture, usability where relevant, tests and integrated behavior, privacy, recovery, and scope. Inspect whether tests express intended outcomes rather than mirror implementation. Parseable graph checks do not establish safe concurrency. Verify claims against actual files and test evidence; do not invent runtime proof from a document walkthrough.
5. Report actionable findings with location, consequence, and a concrete correction. Distinguish blockers, lesser findings, and untested areas. Save a report or inline comments only when requested or the document test and project rules warrant it. Review authorization alone does not authorize fixes, publication of comments, or merging.
6. Record the reviewed revision, scope, evidence, authorizing instruction, and outcome in existing project conventions. Personal human review requires that human's review; delegated readiness needs actual delegation and completed review. Changes after review require proportionate reconciliation and re-review of affected behavior. A pass count, status field, model verdict, or merge alone grants no authority.

## Context and boundaries

Use project conventions for storage, metadata, review, and Git actions. Discover actual locations and types, including legacy layouts. Create directories only when used. On resume, reconcile source revisions, Git state, checkpoints, and authority.

Read original product and architecture sources and relevant prior lessons. For substantial work, retain stable consequential references and account for preserved obligations, authorized changes, reasoned exclusions, and unresolved decisions. Reconcile source differences with affected work and reviews; block unresolved or unauthorized consequential changes. Keep scope, authority, verified progress, evidence, unresolved decisions, and next checkpoint visible in existing records. A small change can keep this context in session.

Stop at a phase-only boundary. Explicit autonomous scope can include transitions and delegated reviews; record its scope, retained human gates, and endpoint once when recovery needs it. Stop at retained human gates or consequential choices outside that scope. Agent review never proves personal human approval, and status alone grants no authority. External effects follow actual authorization.

Capture reusable lessons with context, evidence, workaround and result, and confirmed cause or uncertainty, in an existing record or a standalone file when useful. Avoid logging every transient error. End with the outcome, material gaps, and next step. Recommend the same or a fresh session, and human or independent review, when context and consequence warrant it. Recommendations authorize no later phase.
