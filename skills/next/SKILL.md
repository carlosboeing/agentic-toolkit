---
name: next
description: Use when the user asks "what's next", "where are we", "what now", "what's left" or for status, invokes /next, or returns after a break. Replies with a one-line TL;DR, the next action, and a short progress line through the SDLC phases, plus any gap or decision waiting on the user. Not for a full project briefing; that is /briefing.
---

# What's next

The user asks this to learn what happens next and where it sits in the big picture. They often switch in from another task and read only the top, so lead with context and the next action, in plain words.

## Gather

Stop as soon as you can answer.

1. Use what this session already knows. Most answers need no tool call.
2. When the session cannot answer, such as a fresh session or work you did not see, read at most five sources: the frontmatter `status` of the workstream's records (follow `related` from the active one), a record's `Next checkpoint` line when it has one, the plan's ticked and open checkbox counts, and `git status -sb`.
3. Do not scan the repository, read Git history, open the tracker, or read whole documents. That is `/briefing`.
4. Check for gaps before you write: a draft record treated as accepted, a phase that a record or the project's rules call for and that has not happened, a value still marked proposed, a `Next checkpoint` the work has passed, and uncommitted or unpushed work.

## Reply

Write Markdown, never a code block. Use these parts in this order, each with its bold label. Leave out a part with nothing to say, except TL;DR and What's next.

1. **TL;DR:** one sentence of context, under 20 words: the workstream, named by its record title or the user's words, and where it stands.
2. **What's next:** the one next action, who does it (you or the agent), and why now, under 30 words. Add "Then:" and the step after only when it helps.
3. **Where we are:** one progress line through the phases this workstream uses, in order. Each phase is its name plus at most one word: `done`, `draft` or `skipped` before the current phase, nothing after it. Put the current phase in bold with "(now)", and the step count when a plan exists. No other words or brackets. Show `skipped` only for a phase that a record or the project's rules call for. When the work follows session steps rather than SDLC phases, show those steps instead.
4. **Watch out:** the most important gaps from step 4, at most two, one short line each. Required when step 4 found one. Report gaps; do not fix them here.
5. **Needs you:** numbered decisions that block the next action, at most two, one short line each.

Example:

**TL;DR:** Saved search filters: the parser is built, but the requirements are still a draft.

**What's next:** The agent wires the parser into the search page, because the page blocks the demo. Then: saved-filter storage.

**Where we are:** Requirements draft → Design skipped → **Implementation, task 2 of 4 (now)** → Review

**Watch out:** No design record; the task order exists only in chat.

**Needs you:** 1. Is the filter limit 20? It is marked proposed.

Rules:

- Use the phases from the global brief: Brainstorm, Research, Requirements, Design, Plan, Implementation, Review, Retrospective, and Debugging while active.
- `done` means the record says reviewed, approved, accepted, shipped or resolved, or the user approved it in this session.
- Use plain English. Never coin a label.
- No preamble such as "I'll use the next skill", and no recap paragraph. Stay under about 80 words.
- Several workstreams: in the TL;DR, give one line each with its next action, up to three, then ask which one.
- No workstream: say so in one line and give the next action.
