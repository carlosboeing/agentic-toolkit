# `/start-planning`

A drop-in skill that starts implementation planning from a design artifact in a fresh session. The skill holds the phase boundary. The project holds the mechanics: where plans go, how they are named, how they are reviewed, and which planning skill to follow.

---

## What it does

```
/start-planning [design-path]
```

Also activates from natural requests to start implementation planning from a design. A path is optional: if omitted, the skill resolves the design from the project's own artifacts.

A new session can plan without the previous design conversation. The agent:

1. Resolves the design (explicit path, or project-native discovery).
2. Discovers this project's planning conventions from its instructions and existing files.
3. Inspects repository state materially implicated by the design.
4. Delegates structure to the project's planner (`writing-plans` when that is what the project uses).
5. Writes a plan that references the design, checks it against the design, and stops before implementation.

It will not reconstruct requirements from the previous design chat, reopen settled decisions without an explicit current-session instruction, or offer to implement.

## Example

In this repository:

```
/start-planning docs/2-design/2026-08-20-start-planning-skill-design.md
```

Or, with one clearly current design:

```
/start-planning
```

A fresh session reads that design, inspects this repo, writes the plan where **this** project keeps plans, and stops. Other projects keep plans elsewhere; the skill discovers that layout instead of assuming this one.

## What it will not do

- Write or revise the design.
- Encode a universal frontmatter schema, plan folder, test command, or git policy.
- Duplicate `writing-plans` or any other planner the project already has.
- Start implementation, or treat planning as permission to implement.

## Install

See the [skills catalog README](../README.md#install-any-skill-in-this-directory). Copy or `curl` this `SKILL.md` into your harness skills directory, or run [`sync-skills.sh`](../sync-skills.sh) to author across harnesses.

## Help

```
/start-planning help
```

Renders the synopsis and does nothing else.
