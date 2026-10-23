# start-brainstorm

Explores an idea or problem before technical design. Use it to challenge the framing, compare options, and record which choices are settled and which remain open.

## Usage

```text
/start-brainstorm Add offline access to the project dashboard
/start-brainstorm path/to/brainstorm.md
/start-brainstorm help
```

An idea or artifact path is optional when the project has one clearly intended active brainstorm. Several plausible sources require a choice. Plain-language requests to brainstorm also work.

The skill reads project conventions, inspects relevant facts, and asks decisions in dependency order. Independent questions may share a round. It gives recommendations with trade-offs and uses concrete scenarios to test assumptions. A consequential technical unknown can remain a question for discovery or design.

## Output and review stop

The result distinguishes accepted decisions, recommendations, assumptions, and open questions. It includes scope, alternatives, reasons, and evidence. Project rules control where artifacts go and their metadata. A short discussion can stay in chat unless the project requires a file.

The skill presents the brainstorm for its applicable review and asks about saving only when that choice remains open. The next phase may skip discovery, design, or a plan document when its inputs suffice. A brainstorm-only request stops here; an authorized autonomous workflow may continue after the requested review. A recommendation or review verdict alone grants no authority.

## Boundary examples

| Request or state | Expected behavior |
|---|---|
| Help argument | Show the synopsis and perform no exploration or writes. |
| An idea already states its audience and constraints | Use those facts; ask only about unresolved choices. |
| A choice depends on another open choice | Wait for the prerequisite answer before asking the dependent question. |
| A factual question can be answered from code | Inspect the code instead of asking the user to recall it. |
| An API constraint is uncertain | Research it or record a discovery question; do not declare the solution approved. |
| Discussion reaches a recommendation | Present it for review and stop before technical design. |
| Project rules require immediate artifact capture | Write in the project-designated store as discussion develops. |

## Install and dependencies

Install the complete directory using [Install one skill](../README.md#install-one-skill), or use the repository's synchronizer. Git, Bash, and `rsync` are installation dependencies. The workflow needs repository-reading tools; consequential external facts may need web access or a scoped probe. No other skill or worker facility is required.

## Sources and adaptation

The discussion method draws on Matt Pocock's [grilling](https://github.com/mattpocock/skills/blob/d81f3a183412e71a5b1e84ca21bc1a35eea03a60/skills/productivity/grilling/SKILL.md) and [domain-modeling](https://github.com/mattpocock/skills/blob/d81f3a183412e71a5b1e84ca21bc1a35eea03a60/skills/engineering/domain-modeling/SKILL.md), reviewed 2026-10-03. [writing-for-agents](https://github.com/mattpocock/skills/blob/d81f3a183412e71a5b1e84ca21bc1a35eea03a60/skills/productivity/writing-for-agents/SKILL.md) informs the completion conditions. This adaptation bounds questioning to brainstorm decisions, permits serial fact finding, and leaves glossary and ADR writes to project rules. The skill is self-contained and does not chain-call upstream skills. See [LICENSE](LICENSE) for the upstream MIT notice.

Useful discussion techniques also appear in [Superpowers brainstorming](https://github.com/obra/superpowers/blob/main/skills/brainstorming/SKILL.md). This skill keeps brainstorming separate from that workflow's design and planning handoff.

## Phase scope and autonomy

Defaults and autonomous runs follow [Phase boundaries](../README.md#phase-boundaries).
