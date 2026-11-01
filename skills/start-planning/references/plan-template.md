---
created: "<YYYY-MM-DD>"
updated: "<YYYY-MM-DD>"
title: "<Title>"
type: plan
status: draft
authors:
  - "<Human operator>"
  - "<Model> (<Harness>)"
---

# <Title>

## Summary

<Describe the subject, intended outcome or decision, and audience. For a substantial document, use a short three-sentence abstract.>

## Document control

- Source baseline: <authoritative sources and revisions, or the current request>.
- Work authorization: <included work, retained gates and next checkpoint, with evidence>.

## Delivery scope

<Goal, exclusions, requirements owner and delivery milestone. Use the reviewed source baseline recorded in Document control; reconcile it before execution. A template or status field establishes no approval.>

## Current state

<Relevant repository observations, existing implementation and paths to verify.>

## Milestones and tasks

<Use only the tasks needed for the work. The row below illustrates one task, not a required count.>

| ID | Task | Depends on | Acceptance / verification |
|---|---|---|---|
| T1 | <Deliverable.> | none | <Observable acceptance and proof method.> |

### T1: <Task title>

- Depends on: none.
- Objective and source obligations: <deliverable and requirement references>.
- Inputs and outputs: <sources, expected result and likely files or an explicit discovery step>.
- Builder specifications: <relevant contracts, invariants and consequential details; link design instead of copying it>.
- Acceptance and verification: <observable result, applicable command or concrete alternative proof>.

<Use row summaries and task subsections together without maintaining conflicting specifications. The table and matching subsection describe the same task.>

## Dependencies and integration

<Order, shared files/state, isolation, integration owner and integration responsibilities. A dependency DAG alone does not establish safe parallelism. A linear sequence needs no diagram.>

## Verification and requirement coverage

| Source obligation | Task or unchanged invariant | Acceptance evidence |
|---|---|---|
| R1 | T1 | <Proof or linked criterion.> |

<Integrated verification and delivery criteria. Account for authorized changes, reasoned exclusions and unresolved obligations.>

## Rollout and recovery

<Relevant deployment, migration, rollback and recovery checkpoints. Omit when inapplicable.>

## Execution boundaries

- Checkpoints: <state and evidence to record>.
- Non-repeatable effects: <effects and how to detect them, or none identified>.
- Halt conditions: <conditions and affected work, or none identified>.
- Forbidden actions: <actions outside scope, or none identified>.
- Shared resources: <coordination needs, or none identified>.
- Integration owner: <accountable role>.

## Progress

- [ ] Complete T1. <Tick only after a verified authorized commit and record its actual SHA. Record the PR, observed merge and rollout separately.>

## References

<Source artifacts, relevant contracts and execution evidence.>

## Document history

- <YYYY-MM-DD>: <material decision, scope amendment or review outcome, with evidence and revision when applicable>.
