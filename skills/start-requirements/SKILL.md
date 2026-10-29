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

## Context, authority, and completion

Project instructions own location, metadata, review, and Git rules. Use the declared working-memory location and actual artifact types, including legacy layouts; do not create folders until needed. Read relevant prior lessons and applicable product and architecture sources. On resume, reconcile source revisions, uncommitted work, Git checkpoints, and current authorization rather than trust a recap or status alone.

A phase-only request stops at its boundary. Explicit full or partial autonomous scope can authorize included transitions and delegated reviews; record the scope, retained human gates, and stopping point once in an existing durable project record when recovery needs one. Personal human approval and readiness under delegated review are different. Use the project's review evidence and accountable reviewer convention; never claim the human read an artifact merely because an agent reviewed it. Commit, push, publication, installation, and other effects follow actual authorization and project rules.

For substantial handoffs, compare consequential obligations with their original authoritative sources as well as the preceding artifact. Retain stable references and account for preserved obligations, authorized changes, exclusions with reasons, and unresolved decisions. Inspect source revision differences and reconcile affected downstream work and reviews before proceeding. Keep scope, authority, verified progress, evidence, unresolved decisions, and next checkpoint visible through existing records. A small change can keep this context in session.

Capture reusable observations where encountered, with context, evidence, workaround and result, confirmed cause or uncertainty, and implications for later work. Use an existing record or a separate lesson when its discovery or concurrent writing value warrants it. Do not record every transient tool error as a permanent rule.

End with the result, material gaps, and a proportionate next-step recommendation. Explain whether the same session or a fresh session better fits context and review needs, and recommend independent or human review when consequence warrants it. A recommendation authorizes no later phase. Stop for retained human gates, the requested endpoint, or consequential decisions outside delegated scope.
