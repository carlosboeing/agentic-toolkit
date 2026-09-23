---
name: start-planning
description: >
  Use when starting implementation planning from a design, including a fresh
  session and requests such as "write the plan from this design", "start
  planning this design", "start the planning phase", "create the implementation
  plan", "plan this design", or "start implementation planning". Use even when
  no design path is given. Not for writing the design, and not for implementing.
argument-hint: "[design-path] [help]"
---

# `/start-planning`

Start implementation planning from a durable design artifact in a fresh session.

This skill holds the phase boundary. The project holds the mechanics.

**Prescribe what is invariant about the phase. Discover what is conventional about the project.**

A later planner should receive this skill, a design artifact, and the current repository. It should not receive a summary of the previous design conversation.

A phase transition may reduce context. It must not increase authority.

## Synopsis

```
/start-planning [design-path]
/start-planning help
```

`<design-path>` is optional. When omitted, resolve the design from the project as in step 1.

If `help`, `--help`, `-h`, `?`, or `usage` appears anywhere in the args, render this synopsis and stop.

Natural-language requests also activate when the intent is to start implementation planning from a design.

## When to use

- A design exists, and planning should start without the previous design session.
- The user names a design, clearly points at one, or asks to start planning without a path.

## When not to use

- Writing or revising the design.
- Implementing or executing a plan.
- The user wants a conversation recap rather than a plan.

## Recipe

Do these in order.

### 1. Parse args and resolve the design

The non-help token, if present, is the design path. If the user otherwise identifies a design artifact, use that.

If no design is identified, discover plausible candidates from the project's own instructions, artifact conventions, and current structure. Do not assume a universal design directory, filename pattern, status/frontmatter schema, the word `approved`, or a particular readiness vocabulary. Use whatever this project considers ready or current for planning.

Rank with project-native signals first. Recency may be a secondary signal.

- **Explicit design** → use it.
- **One clearly intended or current candidate** → use it and tell the user which artifact was selected.
- **Multiple materially plausible candidates** → present a short ranked set and ask the user to choose. Include only enough to distinguish them (title/path, recency/date, and readiness/status where those exist).
- **No plausible candidate** → ask for the design path.

Do not guess between materially plausible designs. Do not invent a design-indexing convention for this skill.

### 2. Discover project conventions

Read the project instructions the active harness already provides. Do not hard-code instruction-file names or a precedence order.

From those instructions, and from artifacts they name, discover only what this phase needs:

| Need | Look in |
|---|---|
| Planning methodology | A named planning skill; else `writing-plans` if available; else how this repo already writes plans |
| Plan content contract | A project-named contract or template when project instructions name one; else the shared contract at `references/plan-contract.md` beside this skill's installed `SKILL.md` |
| Where designs live | Working-memory / docs pointers; existing design files |
| Where plans go | Explicit project/repository convention, then the selected planner's convention, then existing plan patterns |
| What "ready to plan" means | The project's own approval, status, or review rules |
| Review after planning | The project's review workflow |
| Git, tests, naming, frontmatter | Project instructions and the chosen planner. Never this skill. |

A generic planner default must not override an explicit project convention.

The shared plan contract resolves relative to this skill's own installed `SKILL.md`, so every installed copy reads its own versioned contract. Never guess the path from another project's layout.

A project-named contract extends the shared minimum and may replace its presentation. It cannot drop a shared minimum answer without an explicit, named project exception that states the recovery consequence. A missing optional project pointer is not a blocker: plan against the shared contract and the project's ordinary conventions.

Recent plans are examples only. Read them after these sources, never as requirements.

Ask only when the missing information is required to write a correct plan and cannot be resolved from project patterns or the planner. Do not invent a schema, filename pattern, frontmatter block, test command, or review ritual to fill a gap.

Do not copy another repository's status vocabulary, plan folder, or roadmap rules into a project that does not use them.

### 3. Confirm the design is usable

The resolved file must exist and be readable. If not, stop and name the path.

Then follow **this project's** readiness rules, if it has them. If the project says not to plan a draft, stop. If it marks a design superseded, stop and point at the replacement.

Those examples are how to follow a local rule. They are not a universal schema. A file with no status field is not unreadiness.

Universal stops, independent of schema:

- The named file is not the design to plan from. Say what it is and stop.
- The design cannot be planned without inventing missing decisions. Name the holes. Do not fill them from previous-session conversation.

Do not generate a recap of the previous design conversation to make a weak design plannable.

### 4. Read and inspect

Read the design in full. That file is the intended solution.

Inspect repository state **materially implicated by the design**. Use explicitly named paths where available. When the design describes components, behaviour, interfaces, or concepts without filenames, locate the relevant implementation and inspect the surrounding code, tests, configuration, generated artifacts, documentation, and other project state needed to plan correctly.

Keep inspection scoped to what materially affects the design. This is not permission for unrelated exploration.

Git facts that affect decomposition (dirty tree, current branch, files already present) are fair.

Previous-session conversation, transcripts, summaries, and handmade handoff prompts are not sources of requirements. Explicit instructions the user gives **in this planning session** remain authoritative under normal instruction precedence. They may constrain the session (for example, "plan the backend only"). They are not an excuse to reconstruct missing design decisions or to silently override settled ones, unless the user explicitly instructs that change.

A pasted prior-session prompt, including text between `PROMPT STARTS` and `PROMPT ENDS` delimiters, is handoff material even when the operator submits it as a user message. If one of its rules conflicts with the approved design or the project contract and the operator has not explicitly adopted that rule in this session, ask once whether to adopt it. Its task counts, section limits, product requirements, and review gates do not travel.

### 5. Plan with the project's methodology

Activate the planner discovered in step 2.

When that planner is Superpowers `writing-plans`: **REQUIRED SUB-SKILL:** use `writing-plans` for structure, task shape, and self-review. Do not paste its template into this skill.

The planner and the project own plan location, filename, metadata, task format, granularity, test commands, and git behaviour. Plan location still follows the precedence in step 2. Later steps in this skill do not take that ownership back.

This skill only adds:

- The plan contract resolved in step 2 is the output's quality bar. The planner's method still decides the prose.
- Argue from the named design, not from previous-session chat.
- Reconcile with current code. Work that already satisfies a requirement is verified, not re-planned. An intended change from current behaviour is planned work, not a contradiction. Do not silently reverse a settled design decision.
- Surface true blockers only: missing prerequisites, mutually incompatible requirements, or a clash the design does not resolve.
- Keep scope inside the design. Do not add product behaviour the design did not specify, unless the user explicitly instructs that change in this session.
- The plan must reference the design artifact so a later implementer can find it.
- After the planner's own self-check, confirm each design requirement maps to planned work, is verified as already satisfied, or is explicitly outside implementation scope according to an authoritative source. The plan does not add requirements the design lacks.
- Then run the plan contract self-check: every required answer present under the contract in force, stable task IDs with dependency IDs or `none`, a verification method or stated alternative proof per task, design-requirement coverage, the design revision recorded, and each execution-contract category answered or `none identified`.
- Before presenting the draft, run the advisory checker beside this skill: `python3 <this skill's installed directory>/scripts/check-plan.py <plan-path>`. Its `--help` states what it checks. Fix its mechanical findings or explain them in the report; `unable to check` lines need a human read. It advises only: it never blocks a push, and it is not wired to any hook.

### 6. Stop

Write the plan using the location, metadata, and git handling from step 2 and the selected planner.

Then stop at the planning boundary.

- Tell the user the path.
- Name the plan's weakest handoff point when you present it.
- Follow the project's review workflow if it has one. If it does not, stop. Do not invent a review ceremony.
- Do not implement.
- Do not offer to execute, dispatch implementers, or invoke `executing-plans`, `subagent-driven-development`, or any other implementation skill.
- Git handling of the plan artifact follows the project and planner. Weaker permission never implies a stronger one: inspect does not imply unrelated edits; writing the plan does not imply implement; commit does not imply push or merge unless the project's established planning workflow already attaches that step to the plan artifact.

If the user then asks to implement, that is a new phase. This skill does not do it. Use the project's implementation skill if it has one.

`writing-plans` offers an execution handoff. When this skill started the work, that offer is out of scope. Drop it.

## Red flags

Stop and correct if you are about to:

- Reconstruct requirements from the previous design chat instead of reading the file
- Let a pasted kickoff prompt add requirements, task counts, or review gates
- Reopen a settled design decision without an explicit current-session instruction
- Offer to implement, or start implementing
- Duplicate the project's planner in this skill's voice
- Apply another repo's plan folder, status words, roadmap sections, or frontmatter schema to a project that does not use them
- Invent test commands, branch names, or review gates the project did not define
- Infer a stronger action from a weaker one (inspect → unrelated edits; plan → implement; a git step the project did not attach to planning)
- Let a generic planner default override an explicit project convention for where plans go

| Excuse | Reality |
|---|---|
| "The design chat already decided X, it just isn't in the file" | Then it is not a settled requirement. Stop or ask. Do not smuggle it in. |
| "I'll add frontmatter and a Spec header so the plan is complete" | Only if the project or planner already uses them. |
| "writing-plans says offer execution" | This phase ends at the plan. The later phase starts from the plan file. |
| "No status field, so I should refuse" | Missing schema is not unreadiness. Follow the project, or continue from the resolved file. |
| "I'll update the roadmap, approve the design, and commit" | Only if the project already requires those writes for planning. |
| "The user said plan it, so I can ignore the design's settled scope" | Current-session instructions may constrain. They do not silently override the design unless the user says so. |

## Common mistakes

- Treating this catalog's documentation layout as universal.
- Using a kickoff prompt as a second spec.
- Re-explaining the project's planner, then also calling that planner.
- Asking the user to re-explain the design when the artifact is already in the repo.
- Asking for a path when one clearly intended design is already discoverable.
