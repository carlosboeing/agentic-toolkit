---
name: next
description: Use when the user asks "what's next", "where are we", "what now", "what's left" or for status, invokes /next, or returns after a break. Answers in about ten lines with the workstream's SDLC phase, its progress, the next action and why, and any decision waiting on the user. Not for a full project briefing; that is /briefing.
---

# What's next

Give the user the big picture in one short reply: which workstream, where it sits in the SDLC, and the one next action. The user often switches in from another task, so the first line alone must say where they are.

## Gather

Stop as soon as you can answer.

1. Use what this session already knows. Most answers need no tool call.
2. When the session cannot answer, such as a fresh session or work you did not see, read at most five sources: the frontmatter `status` of the workstream's records (follow `related` from the active one), a record's `Next checkpoint` line when it has one, the plan's ticked and open checkbox counts, and `git status -sb`.
3. Do not scan the repository, read Git history, open the tracker, or read whole documents. That is `/briefing`.

## Reply

Use this shape. Drop any line with nothing to say, except Next.

```
<Workstream> · <Phase>, <step such as task 2 of 5>

Brainstorm done → Requirements draft → Design skipped → [Implementation] → Review

Last:  <last thing finished>
Next:  <one action and who does it> — <why it matters now>
Then:  <the step after>
Gaps:  <where the work and its records disagree>
Needs you:  1. <decision>
```

- **Phase strip.** Use the phases from the global brief: Brainstorm, Research, Requirements, Design, Plan, Implementation, Review, Retrospective, and Debugging while active. Show only phases the workstream used, plus any it skipped. Put the current phase in brackets.
- **Status words.** `done` means the record says reviewed, approved, accepted, shipped or resolved, or the user approved it in this session. `draft` means a record exists without review. `chat` means it was decided in conversation with no record. `skipped` means a record or the project's rules call for the phase and it has not happened.
- **Names.** Use the record's title or the user's words. Never coin a label.
- **Gaps.** Report a draft record treated as accepted, a skipped phase, a value still marked proposed, a next checkpoint the work has passed, and uncommitted or unpushed work. Report them; do not fix them here. List at most three, most consequential first.
- **Needs you.** Only decisions that block the next action, at most three.
- **Several workstreams.** Give one line each, up to three, then ask which one.
- **No workstream.** Say so in one line and give the next action.

Keep the reply under twelve lines, with no preamble and no recap paragraph.
