# Requirements quality contract

A brief or PRD owns intended behavior, scope and success. It gives technical design and later review a stable product source. This contract is for agents and humans clarifying a new product or capability; it defines required answers with a suggested structure, not a fixed-length form.

## Clarify before designing

Read the request, exploration, research and existing product decisions first. Ask about consequential gaps rather than run a fixed questionnaire. Useful questions concern who needs the outcome, the problem being solved, supported journeys, priorities, exclusions, observable success, failure expectations and constraints. Do not ask questions the sources already answer. Record unresolved questions and the work they block; do not hide assumptions in apparently accepted requirements.

A vague idea uses brainstorming to compare alternatives and preserve useful context. Exploration can stop without delivery. A clear new product or capability can start at requirements. Persist the resulting brief before technical design, reusing an existing sufficient requirements owner. Routine clear fixes, documentation, dependency changes and small improvements can keep scope in the request, issue or session. Honor a user-selected lighter route.

## Suggested structure and required answers

Use the project's frontmatter and naming rules. A compact brief can combine headings; omit a heading only when its answer is covered elsewhere or explicitly inapplicable.

| Suggested section | Required answer |
|---|---|
| Summary and problem | Who needs the result, their problem, intended outcome and why this change is worth doing. |
| Sources, scope owner and authority | Original intent and evidence, authoritative scope record, source revisions where needed, accepted decisions versus proposals, authorization and retained gates. |
| Scope and priorities | Included behavior, important journeys, priorities and explicit exclusions. |
| Requirements | Observable obligations with stable IDs for consequential requirements. Include relevant failure and recovery expectations. Separate product outcomes from architecture and task choices. |
| Acceptance and success | Observable scenarios or outcomes linked to requirement IDs, including important adverse cases. Name how success can be observed without prescribing implementation. |
| Constraints and dependencies | Applicable product and architecture constraints, external dependencies and supported environments that limit the solution. Distinguish an imposed constraint from a proposed technical choice. |
| Open questions and assumptions | What remains unknown, evidence and uncertainty, who must resolve it and which downstream work it blocks. |
| Decisions and changes | Meaningful clarifications, authorized scope changes and links to affected design, tasks or review evidence. Do not turn every conversation into a log. |

A useful requirement states the actor or situation, required behavior and observable result. Avoid arbitrary requirement counts, mandatory user-story syntax or an exhaustive task list. Research findings are evidence; they do not establish acceptance. Architecture belongs to [design](../../start-design/references/design-contract.md); builder tasks, dependencies and integration belong to [planning](../../start-planning/references/plan-contract.md).

## Ownership and amendments

Keep one authoritative owner for each product obligation. Downstream documents reference it instead of maintaining competing requirement tables. A technical design can contain technical constraints and acceptance refinements without becoming a second product brief. When design reveals a product choice, resolve it with the user or within existing delegation, amend the same requirements owner and reconcile affected downstream records and reviews.

An extracted historical brief must identify its source revisions and extraction date. Distinguish source-backed requirements from interpretations and unresolved gaps. It does not inherit personal human review or become authoritative by being written. Either retain the original owner and label the extraction as a reference example, or explicitly authorize a transfer and update downstream references. Do not reorganize active approved work solely to create an example.

Review and progression follow project rules and actual authorization. No new approval ceremony, issue hierarchy or standalone planning document is implied. A phase-only request stops at its boundary. An authorized autonomous workflow can continue through included responsibilities, retaining its human gates. Record acceptance separately from delivery.

## Compact example

This synthetic brief illustrates sufficient answers, not accepted repository scope.

**Problem and scope.** Support staff need to export the currently filtered customer list for their weekly audit. The request owns scope. Include the visible filter and current user's permissions; exclude scheduled exports and new integrations. Product selection and ordering already exist and remain unchanged.

**Requirements and acceptance.** R1: exported rows match the current filter and permissions. Check with two filters and a user who cannot see one matching customer. R2: the export identifies each column and preserves the displayed values. Check an empty result and values containing commas or line breaks. R3: an export failure gives a useful error and offers no apparently complete partial file. Check an interrupted export through the user-facing action.

**Constraints and questions.** Existing access rules apply. The supported output format remains a product question until the operator selects it; that decision blocks format-dependent technical design. No architecture or task decomposition is chosen here.

## Substantial example

This synthetic outline illustrates a larger PRD without adding a separate specification phase.

A support team needs interrupted bulk imports to continue without duplicate customer records. The product owner selects restartable imports, excludes background scheduling and replacing the destination, and requires existing access rules and audit retention. R1 requires previously accepted records to remain visible after interruption. R2 requires a resumed import not to create duplicates. R3 requires rejected records to remain identifiable with reasons. R4 requires an operator to distinguish partial progress, completion and failure. Acceptance covers interruption, an ambiguous last response, invalid input and an unauthorized operator. Whether corrected input may resume the same import remains an explicit product question. Checkpoints, idempotency mechanisms, persistence schemas and task order are technical design and planning decisions, not assumptions hidden in this PRD.
