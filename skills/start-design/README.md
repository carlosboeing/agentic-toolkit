# start-design

Writes a technical design from a product brief or PRD, reviewed exploration, research findings, or a clear request. Use it in a fresh session to produce the design for review before the next authorized phase. For bounded work it presents a short design in chat instead of a file.

## Usage

```text
/start-design path/to/brainstorm.md
/start-design path/to/brainstorm.md path/to/research.md
/start-design help
```

A clear brief in the current request can replace the brainstorm path. Without a source, the skill uses one clearly intended project-native candidate or asks you to choose. It reads the sources in full and inspects the relevant current architecture and product decisions. The design links consequential decision sources and explains what it preserves, proposes changing, or leaves outside this change.

## Contract and output

The [shared design contract](references/design-contract.md) covers the problem, audience, scope, constraints, sources, options, architecture, consequential interfaces, failure behavior, acceptance, and uncertainty. It includes compact and substantial examples. A project-named contract may replace presentation and extend the minimum. An explicit project exception must name the omitted answer and its consequence for later work.

The contract resolves beside the installed `SKILL.md`. Copy the complete directory so each installed skill reads its own version. Project instructions control artifact location, metadata, research and document checks, and review mechanics.

Research follows consequential uncertainty. The design cites checked assumptions, identifies stale facts, and names unresolved questions and the parts they block. Existing interfaces are preferred for observing acceptance; consequential interface choices can be compared under the same constraints.

## Review stop and recovery

The skill writes the complete draft, checks it against the source and contract, and presents its path and weakest assumption for the applicable review. It stops by default. An explicitly authorized autonomous run may complete the delegated review and hand off to its next included phase. The existing record identifies the reviewed revision, scope, review evidence, and authorizing instruction. Agent review does not establish personal human approval or permission for unrelated effects. The reviewed design becomes the source for a later planning or implementation session. If it already answers implementation readiness and recovery needs, the user can choose implementation with an in-session plan instead of a plan document.

If later work disproves a consequential assumption, the affected work stops for a reviewed design amendment. Independent unaffected work may continue. An incidental path moving does not itself change the approved behavior.

## Boundary examples

| Request or state | Expected behavior |
|---|---|
| Help argument | Show the synopsis without exploration or writes. |
| Reviewed brainstorm and optional research paths | Read them in full; treat research as evidence, not approval. |
| Clear brief without a brainstorm | Design from that brief; create no ceremonial brainstorm. |
| Bounded work | Present a short design in chat, use applicable review for real choices, then stop for a design-only request or continue within existing implementation or autonomous authority; write a file only when requested or warranted. |
| Several plausible source artifacts | Ask for a choice rather than treating the newest as authoritative. |
| No status field | Follow project readiness rules; do not invent a universal schema. |
| An optional project contract pointer is absent | Use the installed shared contract and ordinary project conventions. |
| A consequential question remains unresolved | Name the affected part and its planning blocker in the draft. |
| A prior-session handoff conflicts with the source | Ask once whether to adopt the rule unless the user already adopted it. |
| The draft passes self-review | Complete the applicable review. Stop by default or continue only under explicit workflow authorization; preserve retained human gates. |

## Install and dependencies

Use [Install one skill](../README.md#install-one-skill) or the repository's synchronizer. Git, Bash, and `rsync` are installation dependencies. The workflow needs repository-reading tools and access to primary documentation or authorized probes when consequential assumptions need checking. No planner, external skill, tracker, or worker facility is required.

## Sources and adaptation

Matt Pocock's [writing-for-agents](https://github.com/mattpocock/skills/blob/d81f3a183412e71a5b1e84ca21bc1a35eea03a60/skills/productivity/writing-for-agents/SKILL.md) informs the explicit completion conditions. [domain-modeling](https://github.com/mattpocock/skills/blob/d81f3a183412e71a5b1e84ca21bc1a35eea03a60/skills/engineering/domain-modeling/SKILL.md) informs terminology checks; [to-spec](https://github.com/mattpocock/skills/blob/d81f3a183412e71a5b1e84ca21bc1a35eea03a60/skills/engineering/to-spec/SKILL.md) informs acceptance through existing interfaces; [Design It Twice](https://github.com/mattpocock/skills/blob/d81f3a183412e71a5b1e84ca21bc1a35eea03a60/skills/engineering/codebase-design/DESIGN-IT-TWICE.md) informs conditional comparison of interfaces. Reviewed 2026-10-03.

The sizing rule and the builder check, where a fresh worker reads the design as its builder and reports what it would have to guess, come from [Superpowers 7.0.0](https://github.com/obra/superpowers/blob/2ce8aa15d05bd57213e6f746f953aafb7ded7a8b/RELEASE-NOTES.md).

This adaptation uses project-controlled artifacts and a design review stop. It does not adopt automatic tracker publication, fixed user-story counts, compulsory glossary writes, or parallel workers. Upstream skills are not runtime dependencies. See [LICENSE](LICENSE) for the upstream MIT notice.

## Phase scope and autonomy

Defaults and autonomous runs follow [Phase boundaries](../README.md#phase-boundaries).

An upstream accepted brief or PRD owns product behavior when present; design owns the technical solution. Original obligations, authorized changes, exclusions, and unresolved questions remain traceable. Source revision changes identify affected tasks, tests, and review evidence before downstream work proceeds. The builder check uses a worker only when delegation is available and authorized; otherwise it is a serial self-check.
