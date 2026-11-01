# Retrospective quality contract

A retrospective examines how work was done and selects evidence-supported improvements. It preserves reusable lessons for later teams and agents without turning anecdotes into policy. Use the [retrospective template](retrospective-template.md) as the default for a durable report; the project can tailor presentation and detail.

## Required answers

| Answer | Minimum content |
|---|---|
| Scope and intended outcomes | Workstream or period, expected result, observed delivery state, source evidence and material gaps. |
| Outcomes | What happened compared with intent; relevant results of earlier improvement actions. |
| What went well | Practices that helped and the context/evidence supporting their reuse. |
| What needs improvement | Problems and impacts, separating observations, hypotheses, confirmed contributing factors and unknowns. |
| Lessons | Applicable context, evidence, confidence or uncertainty, useful workaround/result, recommendation and limits. |
| Actions and follow-up | Specific improvement, confirmed or proposed owner, disposition/tracking, and when/how to check whether it helped. State when no action is justified. |
| Control and history | Source baseline, actual authority and checkpoint, and material decisions or review outcomes with evidence. |

Keep the report blameless and professionally worded. Do not assign a root cause without evidence or infer that an agent's error proves a model-wide limitation. Useful successes matter as much as failures. Link evidence and existing incident analysis rather than copying entire logs or requiring another postmortem.

## Learning and follow-through

A later agent should be able to find the lesson, recognize its triggering context, assess the evidence and limits, and check its current relevance. A lesson is not a higher-priority instruction, new product scope or proof that an improvement works. Distinguish proposing an action, completing it and measuring its effect. Preserve contrary evidence and revise a recommendation when follow-up disproves it.

Give each selected action a disposition: work already authorized, authoritative backlog reference, deferred, or rejected with reason. An unconfirmed assignment stays proposed. Do not invent due dates or create tracker items without authority. Record the later checkpoint and observable outcome. Raw lessons can stay draft; actionable follow-ups belong in delivery tracking.

A retrospective can remain in chat for small work, and continuous lessons need no separate retro. No sprint cadence, mandatory action count, meeting or standalone lesson file is required. Artifact readiness reviews remain reviews; active unknown failures use debugging. Retrospectives authorize no new code, instructions, installation or external action by themselves.

## Prior art

Informed by the [Scrum Guide](https://scrumguides.org/scrum-guide.html#sprint-retrospective), [Atlassian retrospective play](https://www.atlassian.com/team-playbook/plays/retrospective) and [Google SRE postmortem guidance](https://sre.google/sre-book/postmortem-culture/), checked 2026-11-01. These are selected practices, not an adoption of a framework's governance or a promise of automatic model learning.

## Example

This synthetic excerpt illustrates the template. It is not an incident finding, owner assignment or tracker action in this repository.

```markdown
# Export recovery retrospective

## Summary

Assess the completed export-recovery increment and select improvements to its verification process.

## Scope and intended outcomes

The increment was intended to resume exports without duplicates. The assessment covers the implementation and its review evidence, not the whole export platform.

## Outcomes and evidence

The routine retry fixture passed. A later lost-acknowledgment fixture exposed a duplicate. Existing evidence establishes a coverage gap; the production impact remains unknown.

## What went well

Stable requirement references made the missing case traceable to the original duplicate-prevention obligation.

## What needs improvement

Verification covered routine retries but not ambiguous acknowledgment. The review record does not explain why that case was omitted.

## Lessons and applicability

| ID | Lesson and applicable context | Evidence and confidence | Recommendation and limits |
|---|---|---|---|
| L1 | Recovery checks must distinguish confirmed failure from an ambiguous response. | Two fixtures show different outcomes; the review-process cause is unresolved. | Consider lost-response cases for retryable side effects. This does not establish a defect in every retry mechanism. |

## Improvement actions

| ID | Action | Owner | Disposition / tracking | Follow-up and success check |
|---|---|---|---|---|
| A1 | Add the lost-acknowledgment case to the recovery acceptance checklist. | Export maintainer, proposed. | Proposed follow-up; implementation not authorized by this retro. | Before the next export change, check that the case is included and the fixture detects duplicate creation. |

## Follow-up review

Pending owner confirmation and action authorization. No effectiveness claim is made yet.
```
