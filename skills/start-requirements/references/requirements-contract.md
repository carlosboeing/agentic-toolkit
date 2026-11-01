# Requirements quality contract

A brief or PRD owns intended behavior, scope and success. It gives technical design and later review a stable product source. This contract is for agents and humans clarifying a new product or capability; it defines required answers with a suggested structure, not a fixed-length form.

## Default presentation

Use the [requirements template](requirements-template.md) for a durable document unless the project supplies its own. Keep its familiar section order where applicable; combine short sections and omit irrelevant ones without losing required answers. Write standalone technical prose. Keep source baseline and actual work authority in concise `Document control` bullets, and dated material decisions or review evidence in `Document history`. Frontmatter remains the canonical current status and attribution. Preserve stable IDs, source revisions and review provenance. Detailed transcripts and run logs belong in linked records. A template creates no document or approval obligation.

## Clarify before designing

Read the request, exploration, research and existing product decisions first. Ask about consequential gaps rather than run a fixed questionnaire. Useful questions concern who needs the outcome, the problem being solved, supported journeys, priorities, exclusions, observable success, failure expectations and constraints. Do not ask questions the sources already answer. Record unresolved questions and the work they block; do not hide assumptions in apparently accepted requirements.

A vague idea uses brainstorming to compare alternatives and preserve useful context. Exploration can stop without delivery. A clear new product or capability can start at requirements. Normally persist the resulting brief before technical design, reusing a sufficient requirements owner. Architecture-led or feasibility-led work may start with a provisional design, then derive and clarify requirements from original intent and constraints and reconcile the design before affected delivery planning or implementation. Routine clear fixes, documentation, dependency changes and small improvements can keep scope in the request, issue or session. Honor a user-selected lighter route.

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

Use an `ID | Requirement | Acceptance criteria` table by default. Each acceptance cell summarizes a concrete expected result; an external criterion ID alone is insufficient. Link longer named scenarios below the table. Preserve historical IDs and label technical constraints in extractions; add source or priority columns only when useful. A useful requirement states the actor or situation, required behavior and observable result. Avoid arbitrary requirement counts, mandatory user-story syntax or an exhaustive task list. Research findings are evidence; they do not establish acceptance. Architecture belongs to [design](../../start-design/references/design-contract.md); builder tasks, dependencies and integration belong to [planning](../../start-planning/references/plan-contract.md).

## Ownership and amendments

Keep one authoritative owner for each product obligation. Downstream documents reference it instead of maintaining competing requirement tables. A technical design can contain technical constraints and acceptance refinements without becoming a second product brief. When design reveals a product choice, resolve it with the user or within existing delegation, amend the same requirements owner and reconcile affected downstream records and reviews.

An extracted historical brief must identify its source revisions and extraction date. Distinguish source-backed requirements from interpretations and unresolved gaps. It does not inherit personal human review or become authoritative by being written. Either retain the original owner and label the extraction as a reference example, or explicitly authorize a transfer and update downstream references. Do not reorganize active approved work solely to create an example.

Review and progression follow project rules and actual authorization. No new approval ceremony, issue hierarchy or standalone planning document is implied. A phase-only request stops at its boundary. An authorized autonomous workflow can continue through included responsibilities, retaining its human gates. Record acceptance separately from delivery.

## Examples

The following synthetic excerpts use the default headings. Apply project metadata from the template for an actual document; these excerpts establish no accepted repository scope.

### Compact brief

```markdown
# Export the filtered customer list

## Summary

Support staff need a downloadable copy of the current customer list for a weekly audit.

## Scope and non-goals

Include the current filter and existing permissions. Exclude scheduled exports and new integrations.

## Requirements and acceptance criteria

| ID | Requirement | Acceptance criteria |
|---|---|---|
| R1 | Export the filtered rows within the user's permissions. | Different filters produce corresponding rows; a restricted matching customer is excluded. |
| R2 | Preserve column labels and displayed values. | An empty result retains labels; commas and line breaks survive export. |
| R3 | Report a failed export without offering a partial file as complete. | An interrupted export shows failure and no apparently complete download. |

## Assumptions and open questions

Output format requires a product decision before format-dependent design. Existing access rules remain binding.
```

### Substantial brief

```markdown
# Resume interrupted customer imports

## Summary

Support staff need imports to resume after interruption without duplicate records.

## Goals and success criteria

Resume work while preserving accepted records and identifying rejected input. Volume and time targets require agreement before capacity-dependent design.

## Scope and non-goals

Prioritize the existing import journey. Exclude scheduling and replacing the destination.

## Requirements and acceptance criteria

| ID | Requirement | Acceptance criteria |
|---|---|---|
| R1 | Preserve accepted records after interruption. | Previously accepted records remain available after interruption. |
| R2 | Avoid duplicates when an import resumes. | Retrying after an ambiguous response creates no duplicate customer. |
| R3 | Identify rejected input and its reason. | Invalid records remain identifiable with rejection reasons. |
| R4 | Distinguish partial progress, completion and failure. | An operator can identify each state through the import interface. |

## Quality requirements and constraints

Existing access rules and audit retention apply. No persistence schema or deduplication mechanism is selected here.

## Assumptions and open questions

Whether corrected input can resume the same import remains unresolved and blocks that portion of design.
```
