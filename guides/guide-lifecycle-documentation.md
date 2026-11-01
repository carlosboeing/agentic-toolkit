---
title: "Lifecycle document templates and writing conventions"
type: guide
scope: [sdlc, documentation, templates, retrospective]
authors:
  - "Carlos Boeing"
  - "GPT-6 (Codex)"
---

# Lifecycle document templates and writing conventions

This guide defines the default presentation of requirements, technical designs, implementation plans and retrospectives. It keeps technical content separate from document control and history while preserving flexible routes and proportionate detail. It is for teams and agents adopting the lifecycle workflow.

## Select the document and route

| Document | Owns | Template and quality contract |
|---|---|---|
| Requirements / PRD | Problem, users, intended behavior, scope and observable success. | [Template](../skills/start-requirements/references/requirements-template.md), [contract](../skills/start-requirements/references/requirements-contract.md) |
| Technical design | Solution, architecture, consequential contracts, rationale and verification strategy. | [Template](../skills/start-design/references/design-template.md), [contract](../skills/start-design/references/design-contract.md) |
| Implementation plan | Builder specifications, tasks, dependencies, integration and acceptance proof. | [Template](../skills/start-planning/references/plan-template.md), [contract](../skills/start-planning/references/plan-contract.md) |
| Retrospective | Evidence-supported lessons and owned improvements to how work is done. | [Template](../skills/start-retrospective/references/retrospective-template.md), [contract](../skills/start-retrospective/references/retrospective-contract.md) |

Use a template when writing that durable artifact; it does not require an artifact, extra session or approval gate. Project instructions and a project template control presentation while applicable quality contracts retain their required answers. Keep the default section order where applicable. Combine short sections and omit irrelevant sections without filler. Brainstorm and research remain open in format.

Requirements-first is the normal product route. Design-first is appropriate for existing architectures, technically constrained work, ports and feasibility exploration: start from the known problem and constraints, mark the design provisional, derive and clarify requirements, then reconcile the same design before affected delivery planning or implementation. Discovery or technical probes still need actual action authority. A design-first route does not accept inferred product scope or bypass a retained review gate. No second design file is required.

Routine clear changes can use a request, issue or in-session agreement and an in-session plan. Honor a user-selected lighter route. A plan file is optional when an existing design and session plan supply the necessary specification and recovery context. No intermediate specification phase is added.

## Keep the technical body standalone

Write for a reader who was not in the conversation. State the problem, behavior, decision and rationale directly. Use familiar headings and consistent terminology. Avoid chat narration, first-name anecdotes, quotations of short approvals and tool-by-tool session histories in the technical body.

| Session narration | Standalone presentation |
|---|---|
| A named participant asked for a broader survey midway through a session. | Research scope includes relevant existing solutions and alternative approaches. |
| A named participant selected option 1. | Decision: retain an informational warning without blocking continued use. Link the decision evidence in document history. |
| The agent says implementation is complete. | Implementation is committed at the recorded revision; verification and delivery state are listed in the execution record. |

Keep consequential rationale and disagreements. Put decisions in the relevant technical section and concise evidence of their authority in document control or history. Detailed research, transcripts and run logs remain linked records. Do not remove provenance while polishing prose.

## Standardize control and history

Frontmatter is the canonical current status, dates, authorship and review attribution. Use the project's active schema; templates provide placeholders to replace, not a new schema. Preserve original creation dates, append-only authorship and review provenance. Do not invent approval, dates, owners or source revisions.

Use `Document control` near the top for concise bullets identifying the source baseline and permitted work, retained gates and next checkpoint. Add accountable roles or teams when meaningful. Link evidence rather than repeat a transcript. Do not maintain another current-status field in prose.

Use `Document history` at the end for dated material decisions, scope amendments and review outcomes with evidence and revisions. Keep execution progress in the plan, using actual code, PR, merge and rollout states. A reviewed source changed for presentation still needs revision reconciliation downstream; formatting is not new product approval.

Keep identities in metadata or linked review records when accountability needs them. Use roles and neutral language in the technical body. This repository retains its existing human operator and agent authorship and GitHub review-attribution convention; adopting teams use their own established identity and approval system. An author is not automatically a reviewer, and delegated agent review is not personal human review.

## Make requirements readable and verifiable

Use `ID | Requirement | Acceptance criteria` by default. A short acceptance cell states a condition and expected result; an external criterion ID alone is insufficient. For long scenarios, link named detailed criteria from a readable summary. Keep original IDs and clearly distinguish source constraints in historical extractions. Add source or priority columns only when they convey useful differences.

Separate per-requirement acceptance from overall product success. Include relevant quality and failure expectations. Use agreed measures or explicit unresolved questions rather than invented numerical targets. Conditions and responses can use EARS; acceptance examples can use Given/When/Then. Neither is mandatory syntax.

Plans use stable task IDs, explicit dependencies or `none`, deliverables and verification. Use task subsections for longer builder specifications instead of an unreadable wide table. Retain requirements-to-task coverage, source revisions, shared-state coordination and integration ownership. A DAG is not permission to run parallel work.

## Turn retrospectives into checked improvements

Use retrospectives for a workstream or period when learning value warrants one. Do not require Scrum roles, a sprint cadence or a meeting. Distinguish an artifact review, a process retrospective, a continuous lesson and an incident analysis. Link existing incident evidence rather than require a duplicate report.

Capture what helped as well as problems. Separate observation, hypothesis, confirmed cause and unknowns. Give reusable lessons their context, evidence, confidence and limits. Retrieve relevant lessons in future work and check applicability; reading a lesson does not train model weights or authorize a new rule.

Actions identify an accountable owner, disposition or tracker reference, and a review checkpoint with observable success. Owners and dates must be established or explicitly proposed. Revisit earlier actions and record whether they helped. A report can conclude that no new action is justified. It does not automatically authorize issue creation, implementation, global instructions, installation or rollout.

## Prior art and scope of adoption

The templates are original toolkit conventions informed by established practices, not copied framework templates or a claim of formal standards compliance:

- [Spec Kit specification](https://github.com/github/spec-kit/blob/main/templates/spec-template.md) and [task templates](https://github.com/github/spec-kit/blob/main/templates/tasks-template.md): structured requirements, acceptance, task references and delivery increments.
- [Kiro feature specs](https://kiro.dev/docs/specs/feature-specs/): behavioral requirements, technical design and explicit requirements-first/design-first routes.
- [OpenSpec writing guidance](https://github.com/Fission-AI/OpenSpec/blob/main/docs/writing-specs.md): observable requirements with concrete scenarios.
- [Rust RFC template](https://github.com/rust-lang/rfcs/blob/main/0000-template.md), [arc42](https://arc42.org/overview/) and [Fuchsia RFC template](https://fuchsia.dev/fuchsia-src/contribute/governance/rfcs/TEMPLATE): familiar engineering structure, alternatives, architecture, quality and review context.
- [Scrum Guide retrospective guidance](https://scrumguides.org/scrum-guide.html#sprint-retrospective): inspect working practices and select improvements to quality and effectiveness.
- [Atlassian retrospective play](https://www.atlassian.com/team-playbook/plays/retrospective): reflect on successes and problems and assign improvement actions.
- [Google SRE postmortem guidance](https://sre.google/sre-book/postmortem-culture/): blameless evidence and follow-through. A process retrospective remains distinct from an incident postmortem.

Sources checked 2026-11-01. Adopt the useful documentation practices without importing their entire governance, file layout, meeting cadence or release process.
