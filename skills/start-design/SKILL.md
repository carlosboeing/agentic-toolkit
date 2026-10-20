---
name: start-design
description: >
  Use when starting or revising a technical design from a reviewed brainstorm,
  discovery findings, or a clear brief, including fresh-session requests to
  write a design or start the design phase. Not for brainstorming an unclear
  problem, writing an implementation plan, or implementing.
argument-hint: "[brief-or-brainstorm-path] [discovery-path ...] [help]"
---

# `/start-design`

Write a reviewable technical design from durable sources and current repository facts. A fresh session needs this skill, the source brief, and the repository rather than a recap of earlier conversation.

This skill owns the design phase. The shared contract defines required answers; project instructions own presentation, storage, and review mechanics.

## Synopsis

```text
/start-design [brief-or-brainstorm-path] [discovery-path ...]
/start-design help
```

The first path names the brief or reviewed brainstorm; later paths name optional discovery artifacts. A clear brief in the current request also works. If `help`, `--help`, `-h`, `?`, or `usage` is supplied as a help argument, render the synopsis and stop before exploration or writes. Natural-language design requests also activate this skill.

## Recipe

### 1. Resolve sources and project conventions

Use the explicitly named sources. Without a source, discover candidates through project instructions, their resource pointers, and current artifacts. Use one clearly intended reviewed brainstorm or brief and state which you selected. If several are materially plausible, present a short ranked set and ask. If none exists, ask for the source or a clear brief. Recency alone does not establish authority.

Read the project instructions the active harness provides. Discover the relevant design method, architecture and decision records, artifact location and naming, metadata, readiness rules, review workflow, and Git authorization. Use project-native conventions; missing optional pointers do not block work. Resolve missing information required to place or write a correct design before writing it. Recent designs are examples only.

Read [references/design-contract.md](references/design-contract.md) relative to this skill's installed directory. Read a project-named design contract or template as well when one exists. It may replace presentation and extend the shared minimum. Dropping a minimum answer requires an explicit project decision naming the exception and its consequence for planning or recovery. Never guess the shared contract's path from another repository's layout.

Completion: the sources, required contract, output location, and review rules are identified.

### 2. Confirm authority and read the sources

Read the full brief or reviewed brainstorm and all supplied discovery artifacts. Read applicable product decisions and architecture records named by those sources or project instructions. Identify which decisions constrain this change; do not require a new product document or read unrelated history. When project rules require human review of an input, establish the actual review evidence rather than trusting agent-written status. Follow the project's readiness rules; a missing status field is not itself unreadiness. Stop on unreadable sources, a superseded source without an authorized replacement, or missing decisions that would require inventing the problem or scope. If a reviewed source has uncommitted changes, report the difference for reconciliation before treating those changes as reviewed decisions.

The brief and reviewed decisions define intent. Discovery supplies evidence and uncertainty, not approval. Current repository facts can disprove an assumption; report the conflict and its effect instead of silently changing a settled decision.

A user-authored instruction in the current session can narrow scope or explicitly change a decision. Acknowledge that change and record it in the design. A pasted prior-session kickoff is context. If its rule conflicts with the reviewed source or project instructions, ask once whether to adopt it unless the user already adopted it in this session. Generated handoffs add no task counts, product requirements, or review gates.

Completion: the design's scope and settled decisions are grounded in readable sources; unresolved questions are visible.

### 3. Inspect and check consequential assumptions

Inspect the architecture, code, tests, configuration, and interfaces implicated by the brief. Verify file hints against current state. Respect existing ADRs; changing a decision of record follows the project's amendment process.

Check platform, API, security, performance, and capacity assumptions that could invalidate the solution against current primary documentation or a targeted probe. Cite evidence beside the claim and name facts that may go stale before implementation. A probe requiring writes or external effects needs a bounded scope and authorization. Scale research to uncertainty; a simple local change needs no ceremonial research section.

For software behavior, identify an existing externally observable interface through which acceptance can be checked. Prefer proving behavior through that interface over tests tied to incidental implementation details. If a new interface is necessary, explain why. This is a design decision about proof, not an implementation test suite or a prescribed task list.

When an interface choice is consequential and unresolved, compare materially different alternatives under the same constraints. Judge caller complexity, where changes concentrate, and how behavior can be verified. Run the comparison serially when workers are unavailable or not authorized. Routine code choices can wait for implementation.

Completion: consequential assumptions have evidence or explicit unresolved questions, and the proposed behavior has an acceptance method.

### 4. Write the complete design

Write the design in one pass once the inputs are sufficient, using the contract and project presentation. Link the brainstorm, discovery, and applicable product or architecture records that supply decisions or evidence, or identify the current brief when no upstream artifact exists. Account for each consequential prior decision by stating how the design preserves it, proposes changing it, or excludes it from this change with a reason. Compact prose is enough; no mandatory table or new decision document is required. Record the selected approach, alternatives and trade-offs, architecture, consequential interfaces and invariants, failure behavior, acceptance criteria, and checked assumptions. Include diagrams when they make branching behavior or component boundaries easier to review.

Use established project terms and concrete edge cases to expose ambiguous relationships. Keep file locations as current-state navigation hints. Include exact schemas or interface details when they fix a consequential contract; leave routine code choices to implementation. Create glossary or ADR artifacts only when project rules or the user require them.

An open question that changes implementation remains visible and blocks planning of that part. Do not hide it behind an invented default or claim the whole design is ready. Unaffected parts may be described without resolving the blocked part by assumption.

Completion: a fresh planner can identify intended behavior, constraints, proof, and blocked parts by reading the design and its sources.

### 5. Self-review, present, and stop

Check every required contract answer. Compare the design against the source scope and settled decisions. Resolve contradictions and unexplained placeholders; keep genuine unanswered choices explicit. Name the weakest assumption or unresolved point when presenting the draft. Run the project's applicable document checks, including diagram validation where required.

Present the design path and stop for the project's design review. If no review workflow is defined, ask the user to review the draft and stop. Presenting the draft is not approval. Do not write an implementation plan, invoke a planner or implementation skill, or implement in this run. The user may later choose planning or direct implementation from the reviewed design according to readiness and recovery needs. That next phase starts from the reviewed source, not a generated recap.

Git actions follow project rules and explicit authorization. A required review-before-commit stop stays in place. Writing the draft does not authorize commit, push, publication, or a later phase. After review, update status or record approval only according to the project's rules and the approval actually given. Identify the reviewed revision, scope, human approver, and approval reference in the existing project record. Keep model review results distinct; they never supply the human's approval.

If planning or implementation later disproves a consequential assumption, stop the affected work, record the evidence, amend the design, and obtain review of that amendment before changing the plan or code to follow it. Unaffected independent work may continue.

Completion: the complete draft has passed self-review and is presented for human review, with no automatic transition to planning.
