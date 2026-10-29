---
name: start-requirements
description: >
  Define accepted product scope or write a product brief or PRD from an idea, exploration, research, or clear request, including requests to start the requirements phase. Not for technical architecture, implementation task planning, or turning every clear change into a PRD.
argument-hint: "[brief or source-path] [help]"
---

# `/start-requirements`

Establish intended behavior and success criteria. Requirements is a responsibility; it need not be a separate document or phase invocation when a request or issue already supplies accepted scope.

## Synopsis

```text
/start-requirements [brief or source-path]
/start-requirements help
```

For an entire help argument (`help`, `--help`, `-h`, `?`, `usage`), or one following a source path, show the synopsis and stop. Such words within the brief remain content.

## Procedure

1. Read the request, exploration, research, and applicable product and architecture decisions. An unclear problem may need brainstorming; missing evidence may need research. These recommendations do not authorize starting more phases. Do not infer acceptance from a draft or recency.
2. Identify promotion authority. Starting requirements authorizes defining a proposal, not implementing it. Exploration can stop, remain parked, or produce several initiatives. Promotion to accepted scope follows an explicit decision or included autonomous authorization. Link the exploration and rationale without automatically superseding them.
3. Identify the authoritative scope owner. A small clear change may use the current request, session agreement, or issue. A bounded feature may use a short brief within design. Write a separate PRD only when requested or when its decision, review, or recovery value warrants it. Avoid maintaining duplicate competing briefs. State the chosen route once.
4. Define the problem, audience, intended outcome, scope and priorities, exclusions, journeys, observable requirements, constraints, success criteria, important acceptance scenarios, and unresolved consequential questions. Scale detail to the work rather than add empty headings. Separate accepted decisions, recommendations, assumptions, and evidence. Technical architecture belongs to design; task breakdown and builder specifications belong to planning.
5. Give consequential obligations stable references for substantial work. Check intended outcomes and important adverse cases against the original intent, existing behavior, and evidence. Record deliberate changes with their authority; unresolved product choices block affected design or delivery. Routine implementation choices need no product gate.
6. Present the brief or PRD for applicable review. Follow the actual delegation and retained gates; do not mark a recommendation accepted without its authority. Link the resulting scope owner from exploration and the next authorized artifact. Creating a PRD does not authorize a design, plan, issue hierarchy, or implementation automatically.

## Context and boundaries

Use project conventions for storage, metadata, review, and Git actions. Discover actual locations and types, including legacy layouts. On resume, reconcile source revisions, Git state, checkpoints, and authority.

Read original product and architecture sources and relevant prior lessons. For substantial work, retain stable consequential references and account for preserved obligations, authorized changes, reasoned exclusions, and unresolved decisions. Reconcile source differences with affected work and reviews; block unresolved or unauthorized consequential changes. Keep scope, authority, verified progress, evidence, unresolved decisions, and next checkpoint visible in existing records.

Stop at a phase-only boundary. Explicit autonomous scope can include transitions and delegated reviews; record its scope, retained human gates, and endpoint once when recovery needs it. Stop at retained human gates or consequential choices outside that scope. Agent review never proves personal human approval, and status alone grants no authority. External effects follow actual authorization.

Capture reusable lessons with context, evidence, workaround and result, and confirmed cause or uncertainty, in an existing record or a standalone file when useful. Avoid logging every transient error. End with the outcome, material gaps, and next step. Recommend the same or a fresh session, and human or independent review, when context and consequence warrant it. Recommendations authorize no later phase.
