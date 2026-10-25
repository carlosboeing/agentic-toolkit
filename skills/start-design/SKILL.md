---
name: start-design
description: >
  Use when starting or revising a technical design from a reviewed brainstorm,
  discovery findings, or a clear brief, including requests such as "design X",
  "how should we build X", or "write a spec", and fresh-session requests to
  start the design phase. Not for brainstorming an unclear
  problem, writing an implementation plan, or implementing.
argument-hint: "[brief-or-brainstorm-path] [discovery-path ...] [help]"
---

# `/start-design`

Write a reviewable technical design from durable sources and current repository facts. A fresh session needs this skill, the source brief, and the repository, not a recap of earlier conversation.

The shared contract defines required answers; project instructions own presentation, storage, and review mechanics. Human review is the default boundary. An explicit full or partial autonomous workflow can delegate review and continuation through its included phases, except at a retained human gate; record its scope and stopping point in a durable project record the next session reads, such as the design, an issue, or a PR.

## Synopsis

```text
/start-design [brief-or-brainstorm-path] [discovery-path ...]
/start-design help
```

The first path names the brief or reviewed brainstorm; later paths name optional discovery artifacts. A clear brief in the current request also works. If the entire argument is `help`, `--help`, `-h`, `?`, or `usage`, or one of those tokens follows a path argument, render the synopsis and stop. The same words inside brief text are content.

## Recipe

### 1. Resolve sources and project conventions

Use the named sources. Without one, find candidates through the project instructions and current artifacts: use one clearly intended reviewed brainstorm or brief and say which; with several plausible, ask; with none, ask for a source or a clear brief. Recency alone is not authority.

From the project instructions, find the design method, architecture and decision records, artifact location and naming, metadata, readiness rules, review workflow, and Git authorization. Resolve missing information needed to place or write the design before writing it. Recent designs are examples only.

Read [references/design-contract.md](references/design-contract.md) relative to this skill's installed directory, and a project-named contract when one exists. A project contract may replace presentation and extend the minimum; dropping a minimum answer needs an explicit project decision naming the exception and its consequence.

### 2. Confirm authority and read the sources

Read the full brief or brainstorm, the discovery artifacts, and the product and architecture decisions they or the project name. Establish the actual review evidence: personal human approval, or review under an explicit autonomous delegation. A retained human gate needs that human. Agent-written status alone establishes neither, and a missing status field is not itself unreadiness.

Stop on unreadable sources, a superseded source without an authorized replacement, or missing decisions that would require inventing the problem or scope. If a reviewed source has uncommitted changes, report the difference before treating them as reviewed.

The brief and reviewed decisions define intent; discovery supplies evidence, not approval. When current code disproves an assumption, report the conflict and its effect instead of silently changing a settled decision. A user instruction in this session can narrow scope or change a decision; record it in the design. A pasted prior-session kickoff is context: if its rule conflicts with the source or project instructions, ask once whether to adopt it, unless the user already did.

### 3. Size the work and check consequential assumptions

Size the work in plain words in one line, such as "bounded: a short design in chat" or "large: a design file". The user can override. Step up if complexity appears.

Inspect the architecture, code, tests, configuration, and interfaces the brief implicates, and verify file hints against current state. Respect existing ADRs.

Check platform, API, security, performance, and capacity assumptions that could invalidate the solution against current primary documentation or a targeted probe. Cite evidence beside each claim and name facts that may go stale. A probe with writes or external effects needs a bounded scope and authorization.

Identify an existing externally observable interface through which acceptance can be checked; explain any new one. When an interface choice is consequential and unresolved, compare materially different alternatives under the same constraints.

### 4. Write the design

For bounded work, present a short design in chat: intent, approach, affected surfaces, and proof, in a few short paragraphs. Ask for approval only when it contains a real choice, then hand off to implementation with an in-session plan; write no file.

Write a design file when the user asks, or when the work records a decision worth keeping, needs review across people or sessions, or is large, risky, or complex. When unsure, write the file.

Write the file in one pass, using the contract and project presentation. Link the sources that supply decisions or evidence. For each consequential prior decision, state whether the design preserves it, proposes changing it, or excludes it with a reason. Record the selected approach, alternatives and trade-offs, architecture, consequential interfaces and invariants, failure behaviour, acceptance criteria, and checked assumptions. Add a diagram when it makes branching behaviour or component boundaries easier to review. Give exact schemas only where they fix a consequential contract.

An open question that changes implementation stays visible and blocks planning of that part. Do not hide it behind an invented default.

### 5. Self-review, present, and stop

Check every contract answer against the source scope and settled decisions, and remove unexplained placeholders. Run the project's document checks, including diagram validation.

**Builder check.** Give the design to a fresh worker with the instruction to read it as the person who must build it and report everything it would have to guess. Fix what it finds or record it as open. With no worker facility, do one serial pass in that role yourself.

Present the design path and its weakest assumption. By default ask for human review and stop. An autonomous workflow that delegates this review continues to the next authorized phase after the review, recording its evidence and run authority. Stop at a retained human gate, the requested endpoint, or a consequential choice outside the delegation. A design-only request authorizes no later phase.

Git actions follow project rules and actual authorization. Writing a draft does not authorize commit, push, publication, or a later phase. Commit drafts as project rules allow. Where the project uses frontmatter, record review in `status` and `reviewed_by`: the accountable human's GitHub username, plus `(delegated to <model>, <harness>)` when that human did not read the document, in one commit; that commit is the reviewed revision. Never label delegated agent review as personal human approval.

If planning or implementation later disproves a consequential assumption, stop the affected work, record the evidence, amend the design, and get the amendment reviewed before the plan or code follows it. Unaffected work may continue.
