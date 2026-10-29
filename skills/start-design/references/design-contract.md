# Design quality contract

A design owns the technical solution for later planning and implementation. An upstream accepted brief or PRD owns product requirements when present; otherwise identify the accepted brief within the design or current request. It must let a fresh reader understand the problem, chosen solution, consequential contracts, proof, and remaining uncertainty. This contract defines required answers, not a Markdown template.

## Authority and presentation

An explicit current-session user instruction can narrow scope or change a decision; record the change. Project instructions and a project-named design contract control presentation and extend this minimum. A project exception may remove a minimum answer only through an explicit decision naming the exception and its consequence for planning or recovery. The selected design method controls the writing process within these constraints. Recent designs are examples, and prior-session handoffs are context rather than requirements.

## Required answers

| Answer | Minimum content |
|---|---|
| Problem and audience | The problem, who needs the result, and observable improvement. |
| Goals and exclusions | Intended outcomes and explicit limits on the work. |
| Constraints and current state | Relevant existing behavior, dependencies, policies, and restrictions. Verify navigation hints against current code. |
| Sources and prior decisions | Links to the requirements owner, brainstorm, research, and applicable product or architecture records that supply decisions or evidence. Identify a current brief when there is no upstream artifact. Account for consequential prior decisions as preserved, changed under identified authority, outside this change with a reason, or unresolved. Unresolved obligations or unauthorized consequential changes block affected work. |
| Options and decision | Credible alternatives, the selected approach, and the trade-offs that explain the choice. |
| Architecture and contracts | Component responsibilities and relationships, consequential interfaces, invariants, and compatibility obligations. Exact detail is required when it fixes behavior or safety. |
| Failure behavior | Relevant errors, partial failures, recovery, and their observable effect. Scale this to the actual change. |
| Acceptance | Observable criteria and how to check them. Include adverse cases when their failure consequence warrants them. |
| Assumptions and uncertainty | Evidence for checked consequential assumptions, facts that may go stale, and open questions with the parts they block. |

Answers may share a paragraph or use the project's headings and tables. Do not add filler sections to satisfy a layout.

## Conditional detail and evidence

Research is proportional to uncertainty. Verify platform, API, security, performance, or capacity assumptions that could invalidate the architecture with current primary documentation or a targeted probe. Cite evidence beside the claim. A simple local edit does not need a separate research section.

For software, identify the interface through which acceptance can be observed. Prefer an existing interface and explain any new one needed for proof. For documentation or process changes, name a concrete alternative such as a reader walkthrough. The design defines what must be proved; the plan later fixes execution tasks and commands.

Compare materially different interface choices when the choice changes caller obligations or has substantial cost to reverse. Routine naming, helper structure, and incidental file choices can remain with implementation. Diagrams are useful when they clarify branching flows or component boundaries; neither a diagram nor a fixed number of alternatives is mandatory.

## Preserve intent across handoffs

For substantial work, retain stable references to consequential requirements and architecture constraints in their authoritative sources. Compare with those original sources as well as the preceding artifact; summaries alone do not establish fidelity. Link the accounting above and acceptance evidence to those references without copying a competing specification. Checks must express intended outcomes and important adverse cases, not merely implementation assumptions.

When a source changes, inspect its revision difference and identify affected design decisions, tasks, tests, and review evidence. Reconcile affected work before proceeding. Existing records must let a human inspect the current scope, consequential changes and authority, progress and evidence, unresolved decisions, and next checkpoint. A small change can provide this context in session.

## Review and amendments

The design reaches a review checkpoint before downstream work. Human review and a stop are the default. An explicit full or partial autonomous request may delegate that review and authorize continuation to the next included phase; preserve any retained human gate and the requested stopping point. The next phase may be durable planning or implementation with an in-session plan, according to readiness and recovery needs.

Record the reviewed revision, scope, review evidence, and authorizing instruction using existing project conventions. Distinguish personal human approval from readiness under delegated review. A status field, self-review, model verdict, commit, or search result alone grants no authority; completed review plus the actual delegation can establish readiness under project rules without claiming the human reviewed the artifact. Unresolved consequential decisions outside that delegation block affected downstream work. No new approval schema or policy file is required.

Approval fixes the behavioral boundary, not incidental file hints. If later work disproves a consequential assumption, stop that affected work, record evidence, amend the design, and obtain review before changing the plan or code to follow the amendment. Independent unaffected work may continue.

## Examples

These synthetic examples show different scopes. They are not required layouts or repository facts.

### Compact local change

> A maintainer needs the configuration error to identify the rejected key. The current parser reports only "invalid configuration". The brief is the issue's request to add the key name; values and credentials remain excluded. Adding the key to the existing diagnostic is preferable to a new validation command because it preserves the current invocation and exit status. The parser returns the key with the existing error, and the CLI prints it without printing the value. A malformed file still follows the existing parse-error path. Check acceptance by invoking the CLI with an unknown key containing a secret value: the key appears, the value does not, and the exit status is unchanged. The current parser and CLI error path were inspected; no external platform assumption or open question remains.

### Substantial architectural change

> Operators need interrupted export jobs to resume without duplicate records. The reviewed brief and discovery describe an append-only destination that supports an idempotency key; those artifacts are linked in the actual design. Scope covers export recovery, excluding destination replacement. Current jobs restart from the beginning. Compare restart-only export, destination deduplication, and a local checkpoint plus destination idempotency; select the third to bound recovery reads while keeping duplicate prevention at the write interface. The exporter persists the last acknowledged record and reuses a stable key when retrying an unacknowledged write. A checkpoint may lag an acknowledged write but must never precede acknowledgment. Lost responses retry with the same key; a corrupt checkpoint stops the job with a recovery diagnostic. Acceptance covers a disconnect before acknowledgment, a lost response after acknowledgment, and checkpoint corruption through the existing export interface. Cite the destination's current idempotency documentation and a disposable duplicate-write probe. Retention of keys remains an open capacity question that blocks the long-running-job portion; recheck that limit before planning it.
