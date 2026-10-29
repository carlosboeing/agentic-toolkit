---
name: start-review
description: >
  Start the review phase or coordinate an integrated review of lifecycle artifacts and delivered behavior against intent. Select applicable project and specialist review methods. Targeted local Markdown review uses penmark-comments, ordinary code review uses the harness review capability, and received findings use receiving-code-review. Not a replacement for CrossRev review-loop skills.
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

## Context, authority, and completion

Project instructions own location, metadata, review, and Git rules. Use the declared working-memory location and actual artifact types, including legacy layouts; do not create folders until needed. Read relevant prior lessons and applicable product and architecture sources. On resume, reconcile source revisions, uncommitted work, Git checkpoints, and current authorization rather than trust a recap or status alone.

A phase-only request stops at its boundary. Explicit full or partial autonomous scope can authorize included transitions and delegated reviews; record the scope, retained human gates, and stopping point once in an existing durable project record when recovery needs one. Personal human approval and readiness under delegated review are different. Use the project's review evidence and accountable reviewer convention; never claim the human read an artifact merely because an agent reviewed it. Commit, push, publication, installation, and other effects follow actual authorization and project rules.

For substantial handoffs, compare consequential obligations with their original authoritative sources as well as the preceding artifact. Retain stable references and account for preserved obligations, authorized changes, exclusions with reasons, and unresolved decisions. Inspect source revision differences and reconcile affected downstream work and reviews before proceeding. Keep scope, authority, verified progress, evidence, unresolved decisions, and next checkpoint visible through existing records. A small change can keep this context in session.

Capture reusable observations where encountered, with context, evidence, workaround and result, confirmed cause or uncertainty, and implications for later work. Use an existing record or a separate lesson when its discovery or concurrent writing value warrants it. Do not record every transient tool error as a permanent rule.

End with the result, material gaps, and a proportionate next-step recommendation. Explain whether the same session or a fresh session better fits context and review needs, and recommend independent or human review when consequence warrants it. A recommendation authorizes no later phase. Stop for retained human gates, the requested endpoint, or consequential decisions outside delegated scope.
