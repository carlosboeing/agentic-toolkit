---
name: start-planning
description: >
  Use when starting implementation planning from a design, including a fresh
  session and requests such as "write the plan from this design", "start
  planning this design", "start the planning phase", "create the implementation
  plan", "plan this design", or "start implementation planning". Use even when
  no design path is given. Also use for builder specifications with tasks, acceptance
  criteria, and dependencies from a usable design. Not for product-scope definition,
  writing the technical design, or implementing.
argument-hint: "[design-path] [help]"
---

# `/start-planning`

Combine builder specifications and executable task planning from a usable design. No mandatory specification document or phase sits between design and planning. This skill produces a durable plan when requested or warranted; native in-session planning belongs within implementation.

A later planner needs this skill, a design artifact, and the current repository, not a summary of the design conversation. A phase transition may reduce context; it must not increase authority. Human review is the default stop. An explicit autonomous full or partial workflow can already authorize the included reviews and handoffs: read its scope and stopping point from the durable project record where the run recorded it, and keep retained human gates.

## Synopsis

```
/start-planning [design-path]
/start-planning help
```

`<design-path>` is optional; without it, resolve the design as in step 1. If the entire argument is `help`, `--help`, `-h`, `?`, or `usage`, or one of those tokens follows the design path, render this synopsis and stop. Natural-language requests to plan from a design also activate this skill.

Not for writing or revising the design, implementing, or a conversation recap.

## Recipe

### 1. Resolve the design

Use the named or clearly identified design. Otherwise find candidates from the project's instructions, artifact conventions, and structure; do not assume a design directory, filename pattern, status schema, or readiness vocabulary. Rank by project-native signals first, recency second.

- One clearly intended candidate: use it and say which.
- Several materially plausible: show a short ranked set (path, date, status) and ask.
- None: ask for the design path.

### 2. Discover project conventions

Read the project instructions the harness provides, and the artifacts they name, for what this phase needs:

| Need | Look in |
|---|---|
| Planning method | A project-named planner or plan template; else the plan contract plus how this repository already writes plans |
| Plan content contract | A project-named contract when one is named; else [references/plan-contract.md](references/plan-contract.md) beside this skill's installed `SKILL.md` |
| Where plans go | Explicit project convention, then existing plan patterns |
| What "ready to plan" means | The project's approval, status, or review rules |
| Review after planning | The project's review workflow |
| Git, tests, naming, frontmatter | Project instructions. Never this skill. |

The shared contract resolves relative to this skill's installed `SKILL.md`; never guess its path from another project's layout. A project-named contract extends the shared minimum and may replace its presentation, but cannot drop a minimum answer without an explicit, named project exception stating the recovery consequence. A missing optional pointer is not a blocker.

Recent plans are examples, read after these sources. Ask only when missing information is required for a correct plan and cannot be found. Do not invent a schema, filename pattern, frontmatter block, test command, or review ritual, and do not copy another repository's status vocabulary or plan folder.

### 3. Confirm the design is usable

The file must exist and be readable; if not, stop and name the path. If it is not the design to plan from, say what it is and stop.

Follow the project's readiness rules and the user's actual authorization. Where the design uses frontmatter, read `status` and `reviewed_by`; the reviewed revision is the commit that set them. Personal human approval and readiness under delegated review are different authorities; do not label one as the other. A retained human gate needs that human's approval. A status field, self-review, model verdict, commit, or generic "continue" alone grants nothing. If the project says not to plan a draft, stop; delegated review does not override that. If the design is superseded, stop and point at the replacement. A file with no status field is not unready.

If the design cannot be planned without inventing decisions, name the holes and stop. Do not fill them from conversation.

If the design is small enough for an in-session plan, say so once and recommend the implementation skill; write the plan if the user still wants one.

### 4. Read and inspect

Read the design in full; it is the intended solution. Inspect the code, tests, configuration, and other state the design materially implicates, including Git facts that affect decomposition. Keep inspection scoped.

An explicit current request or accepted in-session agreement can own requirements. Transcripts and handoff summaries do not silently replace that owner or the authoritative product and architecture sources. Instructions the user gives in this session stay authoritative and may constrain the work; they do not silently override settled decisions unless the user says so. A pasted prior-session prompt is handoff material: if its rule conflicts with the design or project contract, ask once whether to adopt it. Its task counts, product requirements, and review gates do not travel.

### 5. Write the plan

The plan contract is the quality bar; the project's method and presentation decide the prose. A plan records decisions, not code: give exact interfaces or commands only where a failure mode needs them, and keep its length in proportion to the design.

- Argue from the named design, and link it so an implementer can find it.
- Check the design against the product and architecture decisions it or the project names; report an omitted or conflicting one before planning that part.
- Reconcile with current code. Work already satisfying a requirement is verified, not re-planned. Do not reverse a settled decision silently.
- Surface only true blockers: missing prerequisites, incompatible requirements, or a clash the design does not resolve.
- Keep scope inside the design.

Self-check:

- Each design requirement maps to planned work, an unchanged invariant, or an authoritative exclusion. The plan adds no requirement.
- Every contract answer is present: stable task IDs with dependency IDs or `none`, inputs, outputs, source obligations, relevant contracts, shared resources and integration ownership, a verification method or stated alternative proof per task, the design revision, and each execution-contract category answered or `none identified`.
- Run `python3 <this skill's installed directory>/scripts/check-plan.py <plan-path>`. Fix its mechanical findings or explain them. `unable to check` lines need direct review. The checker advises only. Validate known references and cycles before orchestrated dispatch; directly review the graph if its format cannot be parsed. An acyclic graph alone does not establish safe concurrency. Coverage against arbitrary stable source references remains a direct author and reviewer check.

### 6. Stop

Write the plan where step 2 says. Present the path and the plan's weakest handoff point.

Follow the project's review workflow; without a delegated review, ask for human review and stop. An authorized autonomous workflow records the review evidence and hands off to the implementation skill without asking again, stopping at a retained gate or its requested endpoint. A planning-only request does not authorize implementation, and implementation always runs under its own phase skill.

Weaker permission never implies a stronger one: inspecting does not allow unrelated edits, writing the plan does not allow implementing, and commit does not allow push or merge unless the project's planning workflow attaches that step to the plan.

## Red flags

| Excuse | Reality |
|---|---|
| "The design chat already decided X, it just isn't in the file" | Then it is not a settled requirement. Stop or ask. |
| "I'll add frontmatter and a Spec header so the plan is complete" | Only if the project already uses them. |
| "A planner default says offer execution" | The request decides authority. A planning-only run stops. |
| "No status field, so I should refuse" | Missing schema is not unreadiness. |
| "I'll update the roadmap, approve the design, and commit" | Only if the project requires those writes for planning. |
| "The user said plan it, so I can ignore the design's scope" | Current instructions may constrain; they do not silently override the design. |

## Context and boundaries

Use project conventions for storage, metadata, review, and Git actions. Discover actual locations and types, including legacy layouts. On resume, reconcile source revisions, Git state, checkpoints, and authority.

Read original product and architecture sources and relevant prior lessons. For substantial work, retain stable consequential references and account for preserved obligations, authorized changes, reasoned exclusions, and unresolved decisions. Reconcile source differences with affected work and reviews; block unresolved or unauthorized consequential changes. Keep scope, authority, verified progress, evidence, unresolved decisions, and next checkpoint visible in existing records.

Stop at a phase-only boundary. Explicit autonomous scope can include transitions and delegated reviews; record its scope, retained human gates, and endpoint once when recovery needs it. Stop at retained human gates or consequential choices outside that scope. Agent review never proves personal human approval, and status alone grants no authority. External effects follow actual authorization.

Capture reusable lessons with context, evidence, workaround and result, and confirmed cause or uncertainty, in an existing record or a standalone file when useful. Avoid logging every transient error. End with the outcome, material gaps, and next step. Recommend the same or a fresh session, and human or independent review, when context and consequence warrant it. Recommendations authorize no later phase.
