---
name: start-brainstorm
description: >
  Use when starting or resuming brainstorming about an idea, problem, or
  proposed change, including requests to explore options, challenge the
  framing, or think through an approach before design. Not for writing a
  technical design, planning implementation, or implementing.
argument-hint: "[idea or brainstorm-path] [help]"
---

# `/start-brainstorm`

Explore the problem, challenge assumptions, and compare options. Present a brainstorm for review, with settled points and open questions a later designer can read.

This skill owns the brainstorm phase. Project instructions own artifact location, metadata, and review mechanics.

## Synopsis

```text
/start-brainstorm [idea or brainstorm-path]
/start-brainstorm help
```

If `help`, `--help`, `-h`, `?`, or `usage` is supplied as a help argument, render the synopsis and stop before exploration or writes. Ordinary question marks in an idea are not help arguments. Natural-language brainstorming requests also activate this skill.

## Recipe

### 1. Establish the brief and project conventions

Use the current request as the idea or intent. If the user names an existing brainstorm, read it in full and identify what remains unresolved. If no idea or source is identified, look for project-native evidence of one clearly intended active brainstorm. Use that candidate and state which one you selected. If several are plausible, present a short ranked set and ask. If none exists, ask what problem the user wants to explore.

If a named source is missing or unreadable, stop and name the path instead of reconstructing it from conversation. Follow project rules for superseded artifacts. A draft can be resumed as a draft; its recommendations do not become reviewed decisions by being present in the file.

Read the project instructions provided by the active harness and the relevant resources they name. Discover where brainstorms belong, when a durable artifact is required, how it is named, and how review and Git actions work. Use the project's conventions; a recent artifact is an example, not a new rule. Resolve a missing required convention before writing. A missing optional pointer does not block discussion.

State the intended outcome, who needs it, known constraints, and observable success. Separate the user's statements from assumptions. Ask for missing facts only when they cannot be found in the repository or relevant primary sources.

Completion: the user can correct the problem framing, and the artifact and review conventions are known before any write.

### 2. Explore decisions in dependency order

Inspect current behavior and applicable product and architecture decisions before asking the user to describe facts you can verify. Link consequential decision sources and distinguish accepted constraints from proposals; a small discussion does not require a new product or architecture document. Surface a conflict between the brief and current code; distinguish a requested behavior change from a mistaken description of existing behavior.

Ask the questions whose prerequisites are settled. Group a small set of independent questions when that reduces back-and-forth; defer questions that depend on an unanswered choice. Give a recommendation and its trade-off for each genuine choice, then wait for the answers before treating it as settled. Research facts serially when delegation is unavailable or not authorized.

Challenge whether the proposed solution addresses the actual problem. Compare materially different options, including a smaller change or keeping current behavior when either is credible. Explain the trade-offs and recommend an option. Use concrete scenarios to test ambiguous terms, edge cases, constraints, and the cost of changing course. Follow an existing project glossary when it applies; record unresolved meanings in the brainstorm instead of creating a glossary or ADR automatically.

Research consequential uncertainties proportionally. Optional discovery returns findings, sources, uncertainty, and the question it answers. It does not approve an option or advance the phase. A prototype or other probe that requires changes or external effects needs its own scope and authorization.

Completion: the problem, scope, credible options, and consequential choices are either settled or explicitly open. Technical questions that belong to design remain visible; resolving every implementation detail is not required to finish brainstorming.

### 3. Record the brainstorm

When project rules require a durable artifact, write it as the discussion develops in the project's location. Save one when the user requests it. When a fresh-session handoff would be useful and saving is optional, ask whether to save before creating the file. A short discussion may stay in chat.

The brainstorm records the problem and audience, goal and exclusions, constraints and evidence, options with trade-offs, settled points with reasons, open questions, and any discovery links. Use the project's presentation and status rules. Mark a recommendation as a recommendation until the user accepts it. Preserve existing decisions when resuming; record an explicit current-session change rather than silently rewriting the source.

A pasted prior-session kickoff is context. If one of its rules conflicts with a reviewed source or project instructions, ask once whether to adopt it unless the user already adopted it in this session. Generated handoffs add no product requirements, task counts, or review gates.

Completion: a fresh reader can distinguish accepted decisions, recommendations, assumptions, and unresolved questions without reconstructing the conversation.

### 4. Review and stop

Check the brainstorm against the brief. Verify that each consequential assumption has evidence or an open question, and that alternatives and exclusions are clear. Present the artifact path, or the in-chat brainstorm, and the decisions that still need review.

Follow the project's review workflow and stop at brainstorm review. Ask about any unresolved choice to save and the appropriate next phase. The user may skip discovery, design, or a durable plan when the next phase has sufficient inputs; brainstorming does not itself grant implementation permission. The next phase requires the user's instruction after this review stop. Do not write the technical design, invoke a design or planning workflow, or implement in this run. Discussion techniques from another skill do not carry that skill's design-writing or planning handoff.

Git actions follow existing project rules and explicit authorization. Writing or reviewing a brainstorm does not approve it, authorize unrelated writes, or grant commit, push, publication, or later-phase permission.

Completion: the brainstorm is presented for review and the workspace contains only authorized brainstorm-phase changes.
