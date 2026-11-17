---
title: "Lifecycle document templates and writing conventions"
type: guide
scope: [sdlc, documentation, templates, retrospective]
authors:
  - "Carlos Boeing"
  - "GPT-6 (Codex)"
  - "claude-opus-5-5 (claude-code)"
---

# Lifecycle document templates and writing conventions

This guide defines the default presentation of requirements, technical designs, implementation plans and retrospectives, and the use of diagrams and tables in every technical document. It keeps technical content separate from document control and history while preserving flexible routes and proportionate detail. It is for teams and agents adopting the lifecycle workflow.

## Which document owns a rule

| Rule | Authoritative source |
|---|---|
| Lifecycle folders, metadata, status/type vocabulary, assets, authorship and review attribution | [Project structure and conventions](guide-project-structure-and-conventions.md), sections 2.5, 5.4 and 5.5 |
| Artifact presentation, visuals and proportionate use of templates | This guide and the linked phase templates/contracts |
| A project's active document roots, local schema and accepted product decisions | Its instructions, Project Map and owning artifacts |
| Migration mapping, preservation, rehearsal and completion proof | [Lifecycle migration runbook](guide-lifecycle-migration.md) |
| Installation and publication of shared tooling | [Sync workflow](../skills/sync-toolkit/SKILL.md) and [script catalog](../scripts/README.md) |

Resolve an actual conflict against the owning source before changing dependent instructions or tools. An installed skill, parser or copied hook is a consumer of these rules. Its current behavior does not establish a new convention.

The target convention uses all seven lifecycle folders and `created`/`updated` fields. Readers and validators retain legacy folders, `date` and `discovery` during adoption. New records follow the project's declared active schema until its migration completes; migrated records follow the canonical schema. Preserve historical evidence and review provenance. Retire compatibility only after accounting for remaining consumers.

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

## Use visuals that carry a claim

A reviewer reads structure faster than prose. Use section headers, bullet lists for parallel items and tables for enumerable facts. Long unbroken text is a smell; if a section cannot be skimmed, restructure it. Use a diagram or table wherever the content has parts, steps, options or states. The table and quality bar below apply to every technical document; the minimums apply to the lifecycle documents listed.

Draw diagrams as Mermaid code in the Markdown file, so they diff, render on GitHub and move with the document. Use an image file only when Mermaid cannot express the content, such as a UI layout. [Project structure and conventions](guide-project-structure-and-conventions.md) sections 5.7 and 5.9 cover the Mermaid default and the HTML-to-PNG mockup steps.

| Content | Visual |
|---|---|
| Components and how they connect | Context diagram: Mermaid `flowchart` |
| Steps with branches or loops | Mermaid `flowchart` |
| A linear sequence | Numbered list, no diagram |
| Messages between actors over time | Mermaid `sequenceDiagram` |
| States and transitions | Mermaid `stateDiagram-v2` |
| Data entities and relations | Mermaid `erDiagram` |
| Options compared on criteria | Table: one row per option, one column per criterion, a verdict column |
| Before and after | Two Mermaid diagrams with the same layout, or a two-column table |
| Facts with shared attributes | Table |
| Dates and milestones | Table or list. A Mermaid `timeline` or `gantt` only when the spacing between dates is the point. |
| UI, layout or screen states | HTML mockup plus PNG |

Each visual meets this quality bar:

1. A lead sentence before it states its claim, such as "The guide owns the rules; every other file points to it." A topic caption such as "Architecture diagram" is not a claim.
2. It shows one idea. Split a diagram that answers two questions.
3. It has about 12 nodes at most. Group or split beyond that.
4. Its labels use the terms of the surrounding prose, in the reader's words.
5. It was rendered and inspected before commit.
6. It adds structure the prose does not have. Cut a visual that repeats a sentence.

### Show each document type's minimum or say why not

Each lifecycle document below includes its minimum visual, or one sentence in its place saying why the visual adds nothing, such as "No context diagram: the change touches one script." Review blocks a missing minimum only when that sentence is also missing.

| Document | Minimum |
|---|---|
| Design | A context diagram of components and boundaries, and a diagram of the main flow |
| Brainstorm | Current versus proposed: two diagrams with the same layout, or a two-column table |
| Research | A comparison table of options or sources against the decision's criteria |
| Plan | A dependency diagram when task order is not linear. A linear plan needs none. |
| Requirements, review, retrospective | None. Use the content-to-visual table above. |

### Render each diagram and look at it

The Mermaid validator checks syntax only. A valid diagram can still be hard to read, with crossing edges, scattered nodes or a dead-end box. Render every block to PNG in a scratch directory outside the repository, then look at each image:

```bash
mkdir -p <scratch-dir> && mmdc -i <doc.md> -o <scratch-dir>/<name>.md -e png -s 2
```

The command writes `<name>-1.png`, `<name>-2.png` and so on, one per Mermaid block. Do not commit them: GitHub renders the Mermaid source. Without a global `mmdc`, prefix `npx -y -p @mermaid-js/mermaid-cli`. For each image, ask whether it shows the claim without the prose. If the harness cannot display images, say "render not inspected" in the handoff instead of claiming the check.

### Review what a reader gets in two minutes

Review applies a skim test: from the summary, headings and visuals alone, a reader can state the document's decision in about two minutes. Each visual answers the question its lead sentence states, and its render shows it. A missing minimum with no explaining sentence is a blocking finding. Other failures against the quality bar are lesser findings.

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
