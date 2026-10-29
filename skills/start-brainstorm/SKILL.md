---
name: start-brainstorm
description: >
  Use when starting or resuming brainstorming about an idea, problem, or
  proposed change, including requests such as "I want to add X", "what if
  we", "should we", or "let's think through X", and requests to explore
  options or challenge the framing before design. Not for writing a
  technical design, planning implementation, or implementing.
argument-hint: "[idea or brainstorm-path] [help]"
---

# `/start-brainstorm`

Explore the problem, challenge assumptions, and compare options. Present a brainstorm for review, with settled points and open questions a later designer can read.

Project instructions own artifact location, metadata, and review mechanics. Human review is the default boundary. An explicit full or partial autonomous workflow can authorize review and continuation through its included phases, except at a retained human gate; record its scope and stopping point in a durable project record the next session reads, such as the brainstorm, an issue, or a PR. A phase-only request grants no later phase. A handoff to the next phase never skips that phase's own work.

## Synopsis

```text
/start-brainstorm [idea or brainstorm-path]
/start-brainstorm help
```

If the entire argument is `help`, `--help`, `-h`, `?`, or `usage`, or one of those tokens follows a path argument, render the synopsis and stop. The same words inside idea text are content.

## Recipe

### 1. Establish the brief and size the work

Use the current request as the idea. If the user names a brainstorm, read it in full and find what remains open. With neither, use one clearly intended active brainstorm from the project and say which; with several, ask; with none, ask what problem to explore. If a named source is missing or unreadable, stop and name the path. Follow project rules for superseded artifacts. A draft's recommendations are not reviewed decisions.

Read the project instructions and the resources they name: where brainstorms go, when a file is required, and how review and Git work. Resolve a missing required convention before writing; a missing optional pointer does not block discussion.

Size the work in plain words in one line, such as "a small change: I'll describe it and do it" or "a larger change: worth exploring options first". The user can override the size. If a clear request asks for implementation rather than exploration, use implementation with an in-session plan. An explicit brainstorm request still gets exploration and stops at its boundary unless a broader workflow is authorized. If hidden complexity appears later, step up and say so.

State the intended outcome, who needs it, constraints, and observable success. Separate the user's statements from your assumptions. Find facts in the repository or primary sources before asking for them.

### 2. Explore decisions in dependency order

Inspect current behaviour and applicable product and architecture decisions first. Surface a conflict between the brief and the code, and separate a requested change from a wrong description of current behaviour.

Ask which build choices the user wants to own. For the rest, pick sensible defaults and say which you picked.

Ask only questions whose prerequisites are settled; group independent ones. Give a recommendation and its trade-off for each real choice. A choice the user delegated is decided and recorded as an agent decision with its reason; any other choice waits for the user.

Challenge whether the proposed solution addresses the actual problem. Compare materially different options, including a smaller change or no change when credible, and recommend one. Test ambiguous terms and edge cases with concrete scenarios.

Research consequential uncertainty in proportion. Use `start-research` when investigation needs its own procedure. Research can precede brainstorming or support it, returns findings and sources, and approves nothing. A prototype or probe with changes or external effects needs its own scope and authorization.

Completion: the problem, scope, options, and consequential choices are settled or explicitly open. Design-level questions can stay open.

### 3. Record the brainstorm

Save a file when project rules require one, the user asks, or the discussion records decisions worth keeping. Otherwise the brainstorm stays in chat.

The brainstorm records the problem and audience, goal and exclusions, constraints and evidence, options with trade-offs, settled points with reasons, open questions, and discovery links. A recommendation stays marked as one until the user accepts it or it is resolved under an explicit delegation. When resuming, record an explicit current-session change instead of rewriting the source silently.

A pasted prior-session kickoff is context. If its rule conflicts with a reviewed source or project instructions, ask once whether to adopt it, unless the user already did. It adds no requirements, task counts, or review gates.

Completion: a fresh reader can tell accepted decisions, recommendations, assumptions, and open questions apart.

A brainstorm may stop without becoming a feature or produce several initiatives. Promotion to accepted product scope follows an explicit user decision or included autonomous authority. Identify the scope owner: request, issue, brief within design, or separate PRD when its value warrants one. Use `start-requirements` for deliberate product definition when needed. Link resulting artifacts and preserve exploration and rationale rather than automatically marking the brainstorm superseded.

### 4. Review and stop

Check the brainstorm against the brief: each consequential assumption has evidence or an open question, and alternatives and exclusions are clear. Present the path, or the in-chat brainstorm, and the decisions that still need review.

By default stop after presenting. An autonomous workflow that includes later phases continues to the next phase skill after the requested review, unless a retained human gate or a decision outside the delegation blocks it. Record review evidence and delegated decisions without claiming personal human approval.

Git actions follow project rules and explicit authorization. Writing or reviewing a brainstorm does not approve it or grant commit, push, publication, or later-phase permission.

## Context and boundaries

Use project conventions for storage, metadata, review, and Git actions. Discover actual locations and types, including legacy layouts. Create directories only when used. On resume, reconcile source revisions, Git state, checkpoints, and authority.

Read original product and architecture sources and relevant prior lessons. For substantial work, retain stable consequential references and account for preserved obligations, authorized changes, reasoned exclusions, and unresolved decisions. Reconcile source differences with affected work and reviews; block unresolved or unauthorized consequential changes. Keep scope, authority, verified progress, evidence, unresolved decisions, and next checkpoint visible in existing records. A small change can keep this context in session.

Stop at a phase-only boundary. Explicit autonomous scope can include transitions and delegated reviews; record its scope, retained human gates, and endpoint once when recovery needs it. Stop at retained human gates or consequential choices outside that scope. Agent review never proves personal human approval, and status alone grants no authority. External effects follow actual authorization.

Capture reusable lessons with context, evidence, workaround and result, and confirmed cause or uncertainty, in an existing record or a standalone file when useful. Avoid logging every transient error. End with the outcome, material gaps, and next step. Recommend the same or a fresh session, and human or independent review, when context and consequence warrant it. Recommendations authorize no later phase.
