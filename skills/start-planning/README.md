# start-planning

Starts an implementation plan from an approved design, in a fresh session. The skill keeps design and planning as separate steps. The project decides the details: where plans go, how they are named and reviewed, and which planning skill to use.

## What it does

```
/start-planning [design-path]
```

It also runs when you ask in plain words to start planning from a design. The path is optional. Without one, the skill finds the current design in the project's own files.

A new session can plan without the design conversation that came before it. The agent:

1. Resolves the design (explicit path, or project-native discovery).
2. Discovers this project's planning conventions from its instructions and existing files.
3. Inspects repository state materially implicated by the design.
4. Delegates structure to the project's planner (`writing-plans` when that is what the project uses).
5. Writes a plan that references the design, checks it against the design, and stops before implementation.

```mermaid
flowchart TB
    Design["Find the design"] --> Conventions["Read the project's planning conventions"]
    Conventions --> Inspect["Inspect the code the design affects"]
    Inspect --> Plan["Write the plan with the project's planner"]
    Plan --> Check["Check the plan against the design"]
    Check --> Stop["Stop before implementation"]
```

It does not rebuild requirements from the earlier design chat, reopen settled decisions unless you ask in the current session, or offer to start implementing.

## Example

In this repository:

```
/start-planning path/to/design.md
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

See [Install one skill](../README.md#install-one-skill) in the skills catalog, or run `scripts/sync-toolkit.sh --harness` to sync every skill.

## Help

```
/start-planning help
```

Renders the synopsis and does nothing else.
