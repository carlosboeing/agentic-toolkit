---
title: "Project structure and conventions"
type: guide
scope: [meta, conventions]
last_reviewed: 2026-05-02
---

# Project structure and conventions

A documentation structure for projects that run for months or years, with many pieces of work shipping over time. It gives each kind of document a fixed home: current-state docs, designs and plans for each piece of work, retrospectives and decision records, plus conventions for how they link together. It works for people and for AI agents, which both need a quick answer to "where does this go?" and "what is the current state?".

The guide is self-contained. Copy it into a new project, follow §8, and the same structure works there. Examples use an infrastructure project so the conventions have a concrete shape.

---

## Table of contents

1. [Philosophy](#1-philosophy)
2. [Core principles](#2-core-principles)
3. [Repository structure](#3-repository-structure)
4. [What each folder is for](#4-what-each-folder-is-for)
5. [Conventions](#5-conventions)
6. [Workflow](#6-workflow)
7. [Recommended tools and plugins](#7-recommended-tools-and-plugins)
8. [Adopting this in a new project](#8-adopting-this-in-a-new-project)
9. [Concrete examples](#9-concrete-examples)
10. [Retrofitting an existing project](#10-retrofitting-an-existing-project)
11. [Notes for adoption](#11-notes-for-adoption)
12. [Credits](#12-credits)

---

## 1. Philosophy

Most project docs fall into one of two failure modes:

- **Chaos** — a sprawling `docs/` with whatever happens to land there, no convention for what goes where, no way to answer "what's the current state?" or "what should I do next?".
- **Bureaucracy** — heavyweight templates, mandatory ceremonies, a system that's nice in theory but in practice no one uses because it's too much overhead.

This structure aims for the middle: **enough convention that orientation is instant; little enough overhead that solo work doesn't feel ceremonial.** It works equally well for human collaborators and AI agents (Claude Code, Cursor, etc.) — both benefit from deterministic answers to "where does X go?" and "what's the current state of Y?".

The structure is opinionated about *placement* (where things live) and *naming* (filenames carry semantic information), but proportionate about *content*: requirements, designs, plans and retrospectives use familiar default templates with project overrides; brainstorm and research formats remain open. Write only useful artifacts.

---

## 2. Core principles

### 2.1 Single source of truth

There's exactly one place to look for any given question:

- "What's the current state of the system?" → `README.md`'s `## Architecture`, or `docs/architecture.md` (or `docs/architecture/`) once it overflows
- "What's queued / in flight / shipped?" → `docs/ROADMAP.md`
- "What did we decide and why?" → `docs/adrs/NNNN-*.md`
- "What was the design for X?" → `docs/3-design/YYYY-MM-DD-X-design.md`
- "How do I do Y?" → `docs/guides/Y-guide.md`

**No `TODO.md`** — its overlap with ROADMAP creates drift. The ROADMAP itself has a "Next actions" section.

### 2.2 Self-describing filenames

A filename should tell you what kind of doc it is, when it was written, and what it's about — without any folder context. This matters when files travel: tab titles, search results, attachments, chat shares.

```
2026-05-12-install-plex-design.md
└─date────┘ └─topic──────┘ └─type─┘
```

The folder reinforces the type; the filename suffix is the durable marker.

### 2.3 Always-current vs frozen-in-time

Two distinct doc shapes:

- **Always-current** docs (`docs/architecture.md`, `docs/guides/`, `docs/adrs/`, single-file evergreen content at `docs/` root) describe how things ARE right now. They get updated, not appended. No `status:` field — they're always "current" by definition (ADRs use `superseded` only when replaced).
- **Lifecycle** docs (`docs/0-brainstorms/` through `docs/6-retros/`) describe a moment in time. They get a `status:` field using the vocabulary in §5.5 and rarely get edited after they ship. New work generates new lifecycle docs.

Confusing the two leads to "the design says X but the system does Y" drift.

### 2.4 Mandatory frontmatter for machine-readability

Every doc inside `docs/` carries YAML frontmatter with at least `type`, `status` (lifecycle docs only), `authors`, and `scope`. This lets AI agents and shell scripts query the corpus cheaply: "show me approved designs touching networking" becomes `grep -l "scope:.*network" docs/3-design/ | xargs grep -l "status: approved"`. The `authors` field also answers "which agent (or human) wrote this?" — load-bearing when several harnesses work the same corpus. Full schemas, exemptions, and format rules: §5.4.

### 2.5 Stage-first lifecycle, numbered for clarity

Folders fall into three groups by *what kind of content lives there*, and only the lifecycle group gets numbered:

- **Lifecycle phases (numbered, ordered by workflow):** `0-brainstorms/` through `6-retros/`. Numbers reflect workflow position; `ls docs/` shows the lifecycle in order.
- **Evergreen reference (plain names, alphabetical):** `adrs/`, `guides/`. No workflow position to encode — names describe what they hold.
- **Scratch / informal (plain name):** `notes/`. Not a phase; not evergreen reference; just a home for chat dumps and external research.
- **Standing indexes / single-file evergreen (UPPERCASE or lowercase at root):** `ROADMAP.md`, `CHANGELOG.md`, optional `architecture.md`.

Project-specific evergreen folders (`prompts/`, `art/`, etc.) are plain-named, NOT numbered. Numbered extensions (`5-prompts/`, `6-art/`) are discouraged — they were a sort-order workaround in older conventions and they imply a workflow position that doesn't exist.

```mermaid
graph LR
    subgraph "Lifecycle phases (numbered, ordered)"
        B[0-brainstorms] -.-> D[1-research]
        D -.-> Req[2-requirements]
        Req -.-> Des[3-design]
        Des -.-> P[4-plans]
        P -.-> R[5-reviews]
        R -.-> Retro[6-retros]
    end
    subgraph "Evergreen reference (plain names)"
        ADR[adrs]
        G[guides]
        Arch[architecture.md]
    end
    subgraph "Scratch / imports"
        N[notes]
    end
    subgraph "Standing indexes"
        RM[ROADMAP.md]
        CL[CHANGELOG.md]
    end
```

These are selectable responsibilities, not a required chain. Brainstorming can stop at exploration. Research can precede brainstorming or support any phase. Requirements defines accepted scope; design chooses the technical solution; planning combines builder specifications and task ordering. Implementation, review, debugging, and retrospective use the selected sources. No phase requires its own file, session, or agent solely because it appears in this structure.

Write a document when it preserves a decision, supports review across people or sessions, or enables coordination or recovery for substantial work. Otherwise use the current request, an existing issue, and an in-session plan as appropriate. State the selected route once. Create all seven numbered lifecycle folders in the declared working-memory root, with `.gitkeep` in empty folders. Their presence requires no document or phase; nested asset and lesson directories remain on demand.

Existing projects may still use `1-discovery/`, `2-design/`, `3-plans/`, and `4-reviews/`. Discover the declared Project Map and actual artifact types before assuming numbered paths. The bundled validators support both layouts. A migration must update live links, metadata, discovery, hooks, and project instructions together, after installed compatibility and active-session checks. Preserve historical types and evidence; never renumber another project automatically.

### 2.6 ADRs as first-class single-decision records

Architecture decisions live as individual files (`NNNN-short-title.md`, where `NNNN` is a 4-digit zero-padded sequence number), not as a section inside a larger document. Each captures considered options, the choice, and reasoning. They're append-only in spirit — superseded ones stay around with `status: superseded` and `superseded_by:` linking to the replacement.

### 2.7 Brainstorm-then-graduate

Exploratory thinking isn't scratch — it's a first-class artifact in `docs/0-brainstorms/`. Promotion establishes a delivery scope under an explicit user decision or authorized workflow. One brainstorm can produce several initiatives or none. Link resulting requirements and designs without automatically superseding useful exploration or rationale. Parked decisions stay as brainstorms with `status: parked` so they're not lost.

---

## 3. Repository structure

```
<project-root>/
├── README.md                       # short project overview + entry points
├── CLAUDE.md                       # auto-loaded brief for Claude Code sessions
├── .gitignore
├── .claude/
│   └── settings.local.json         # Claude Code workspace settings (gitignored)
│
├── docs/                          # project's working memory
│   ├── ROADMAP.md                 # forward view: in flight / next / shipped
│   ├── CHANGELOG.md               # backward view: what shipped, when
│   ├── architecture.md            # OPTIONAL single-file HLD (when README's ## Architecture overflows)
│   │
│   ├── notes/                     # scratch, chat dumps, external research, snippets
│   │
│   ├── 0-brainstorms/             # pre-design ideas (worth-elaborating; one-liners → ROADMAP)
│   ├── 1-research/                # research, spikes, comparative analyses
│   ├── 2-requirements/            # optional durable briefs and PRDs
│   ├── 3-design/                  # technical designs
│   │   └── assets/                # attachments for these docs (§5.10)
│   ├── 4-plans/                   # builder specifications and task plans
│   ├── 5-reviews/                 # artifact reviews, audits, analyses
│   ├── 6-retros/                  # process retrospectives
│   │   └── lessons/              # lessons/<workstream>/, captured in any phase
│   │
│   ├── adrs/                      # single-decision records (NNNN-title.md)
│   └── guides/                    # internal procedural how-tos
│
│ # Optional, per-project (created on demand):
│ # ├── architecture/              # promoted from architecture.md when one file isn't enough
│ # ├── system/                    # for ops projects with operational state
│ # ├── prompts/                   # stable reusable prompts (3+)
│ # └── <custom-evergreen>/        # project-specific (e.g., art/, gdd/)
│
├── archive/                        # frozen imported material; date-prefixed
│   └── YYYY-MM-DD-<source>/        # e.g., chat exports, retired docs
│
├── configs/                        # versioned configuration files
├── scripts/                        # tested ops scripts
└── skills/                         # Claude Code skills (or similar agent definitions)
```

Adapt the inner structure of `configs/`, `scripts/`, `skills/` to your project. The `docs/` structure stays consistent.

### 3.1 Private working-memory variant (`.workbench/`)

In open-source or public projects where the code and public documentation are shared, but active brainstorms, designs, plans, reviews, and internal notes are kept private, a dual-repository structure provides clean isolation:

- **Public repository (`<repo>/`):** Holds code, public documentation, architecture decision records (`docs/adrs/`), and public tracking (`ROADMAP.md`, `CHANGELOG.md`).
- **Private working memory (`.workbench/`):** A separate, private Git repository cloned directly into `<repo>/.workbench/` and added to `<repo>/.gitignore`. Its root mirrors the lifecycle structure (`0-brainstorms/`, `1-discovery/`, `2-design/`, `3-plans/`, `4-reviews/`, `notes/`, `guides/`).
- **Project Map routing:** The project brief (`CLAUDE.md` / `AGENTS.md`) sets `Working memory: .workbench/` so AI assistants route working-memory artifacts to the private repository automatically.
- **Contributor route:** Outside contributors who do not have access to `.workbench/` use standard public mechanisms: issues, pull requests, and public ADRs (`docs/adrs/`), without creating lifecycle folders under `docs/`.
- **Commit boundaries:** Local pre-commit hooks prevent accidentally committing `.workbench` gitlinks, internal paths, or private material into the public repository. Commits inside `.workbench/` are made with `git -C .workbench` and never touch public history.

The example above retains legacy directory names. New projects use the target layout in §3; existing clones keep their actual paths until compatible tools are installed and an authorized migration updates live references and shared sessions together.

---

## 4. What each folder is for

### 4.1 Root-level files

#### `README.md`

Short (~30 lines). Orients a new reader: what is this project, where does the current-state HLD live, where do queued/shipped views live. It does NOT duplicate content — it points at the canonical sources.

```markdown
# Project Name

One-line description.

**Current state:** see the `## Architecture` section below — or [docs/architecture.md](docs/architecture.md) once it has been promoted out of the README.
**What's in flight:** see [docs/ROADMAP.md](docs/ROADMAP.md).
**What's shipped:** see [docs/CHANGELOG.md](docs/CHANGELOG.md).

For Claude Code sessions: [CLAUDE.md](CLAUDE.md) is the auto-loaded brief.

## Repo layout
[brief table]

## Conventions
[brief summary, link to full guide]
```

#### `CLAUDE.md`

Auto-loaded by Claude Code at the start of every session. Contains: project at-a-glance (what, current state pointer), operator preferences (how to work with you), verification policy (when to search vs answer), repo structure summary, working conventions (filenames, status flow, change discipline, ROADMAP discipline, brainstorm graduation, commit format, diagram default), and "what NOT to do" guardrails.

Should be ~150–250 lines. Token cost is per-session, so brevity matters. Keep it scannable, not exhaustive — link to detailed docs (the doc-structure spec, etc.) for the full version.

If you're not using Claude Code, this file is still a useful "agents and contributors brief." Other AI tools and human collaborators benefit from the same content.

#### `docs/ROADMAP.md`

The single source of truth for "what's next." Seven sections, each with a clear semantic — see §6.3 for full detail.

#### `docs/CHANGELOG.md`

Date-grouped record of what shipped, when. Most recent first. Each entry references the LLD/plan/retro that drove the change. Mirrors what's in ROADMAP's "Recently shipped" section but with more depth per entry.

```markdown
# Changelog

## 2026-04-28

### foundation — Phase 0 complete

- BIOS updated F11 → F39
- DOCP enabled, RAM at 3200 MT/s, memtest 3 passes clean
- SVM enabled
- IPv6 audit: TCP/UDP firewalled (D-23)
- See [docs/6-retros/2026-04-28-foundation-retro.md], [docs/4-plans/2026-04-25-foundation-plan.md].
```

### 4.2 `docs/architecture.md` (or `docs/architecture/`) — always-current architecture

Optional, created when README's `## Architecture` section overflows. Two shapes:

- **Single-file:** `docs/architecture.md`. Use until one file isn't enough.
- **Directory:** `docs/architecture/overview.md` + per-aspect files (`network.md`, `services.md`, `data-model.md`, etc.). Promote when single-file outgrows itself.

This is the *only* convention-blessed promotion-to-folder path. Other single-file evergreen content stays flat at `docs/` root (e.g., `vision.md` if you treat it as internal content, `gdd.md` for a game-design doc, `best-practices.md`).

For operations projects with *operational state* (running containers, hardware inventory, network topology) that's broader than architecture alone: optionally add `docs/system/` (or `docs/state/`, `docs/ops/` — operator's call). Keep architectural and operational state separate when they have different update cadences. Examples of `system/*` files for an infrastructure project: `hardware.md`, `storage.md`, `containers.md`, `backups.md`.

**No frontmatter `status:` field** — these are evergreen. Optionally include `last_reviewed: YYYY-MM-DD` as a *deliberate* claim that you've personally verified the doc is up-to-date as of that date (NOT auto-bumped on every commit).

### 4.3 `docs/0-brainstorms/` — pre-design exploration

Holds **worth-elaborating ideas that haven't yet materialized into designs** — future thoughts, structured brainstorming sessions, proposals you want to capture before deciding whether to pursue.

The line worth drawing:
- **One-line ideas** ("we should look at X someday") → ROADMAP "Future considerations" section.
- **Worth-elaborating ideas** (~5+ lines, multiple aspects, options to weigh) → `0-brainstorms/<topic>.md` as a structured brainstorm.

Lower quality bar than the other lifecycle folders, but content here is *deliberate* — if it's just a passing thought, it belongs in ROADMAP or a comment, not its own file.

Frontmatter `status:`
- `open` — actively being explored
- `parked` — deferred for later (with notes on what would unpark it)
- `resolved` — exploration concluded; link any resulting initiatives
- `superseded` — actually replaced by another record, with `superseded_by:`
- `abandoned` — explicitly not pursuing

When exploration is promoted, identify the accepted scope owner: the request, issue, brief within a design, or separate PRD. Link the exploration and evidence. A new delivery artifact does not invalidate its source rationale.

### 4.4 `docs/1-research/` — authoritative research artifacts

Where research reports, comparative analyses, and option-space writeups live. Content with a thesis (not just exploratory thoughts).

Examples: "Comparison of self-hosted photo platforms" (informs the photo-platform design), "Analysis of restic vs borg vs duplicacy" (informs the backup-strategy design), "Survey of vector databases" (informs the memory-rag design).

Frontmatter `status:` follows the standard lifecycle (`draft → approved → superseded`).

### 4.4.1 `docs/2-requirements/` — accepted product scope

For product-led work, normally clarify and persist product requirements before technical design. Architecture-led or feasibility-led work may start from a provisional design, then derive and clarify requirements and reconcile the same design before affected delivery planning or implementation. Use `start-brainstorm` for a vague idea and retain a brainstorm document with useful exploration, alternatives, and open questions. When intent is clear, use `start-requirements` directly or after exploration to ask focused questions and write a brief or PRD in `2-requirements/`. Reuse an existing authoritative requirements record rather than duplicate it. Exploration can stop without promotion. Routine fixes, documentation, dependency updates, and other clear small changes can keep requirements in a request, issue, or session; honor an explicit lighter route. Identify one authoritative scope owner, with links to exploration and evidence.

Record the problem, audience, outcome, selected scope, priorities, exclusions, journeys, observable requirements and acceptance scenarios, constraints, success criteria, and unresolved consequential questions. Creating this record does not authorize implementation. Give consequential obligations stable references that design, planning, and review can preserve. Use the [requirements quality contract](../skills/start-requirements/references/requirements-contract.md) for the required answers and a suggested structure. The [design contract](../skills/start-design/references/design-contract.md) and [plan contract](../skills/start-planning/references/plan-contract.md) define their corresponding boundaries. Use the [four document templates and writing conventions](guide-lifecycle-documentation.md) for default presentation. Their contracts retain required answers, project overrides and proportional detail. Technical sections are standalone; concise control/history preserves authority and source evidence.

Requirements status follows `draft → approved → in-progress → shipped`, omitting `in-progress` when no execution checkpoint needs it. Approval accepts scope; it does not prove delivery. Mark a historical brief or PRD `shipped` only when its accepted scope is delivered and verified, alongside the applicable design and plan records. Partially delivered scope stays approved or in progress. A Recently shipped line that links an approved PRD is correctly refused; link the delivered change record or mark the fully delivered PRD shipped. A maintained current product specification remains distinct from that historical change record.

### 4.5 `docs/notes/` — scratch, imports, external research

Editable working content that doesn't (yet) belong in a structured phase folder:

- AI chat dumps from external sessions (claude.ai, ChatGPT, etc.)
- External research articles, snippets, links you've collected
- Personal scratch ("saw this technique, might be useful")
- Reference dumps from research sessions

Distinct from `archive/` (top-level, optional): `archive/` is for genuinely frozen historical content you specifically *don't* want loaded as session context. `notes/` is for content you *do* want loaded — chat dumps inform the next initiative, research dumps inform discovery work.

File naming: `YYYY-MM-DD-<topic>.md`. Subdirs optional (e.g., `notes/imports/`).

**Graduation path:** when content in `notes/` crystallises into a structured exploration, it graduates to `0-brainstorms/<topic>.md` with `status: open`, and the original notes can be linked from there.

No frontmatter required — `notes/` is informal by design. If you want to track origin, add a comment at the top of the file pointing at the source.

### 4.6 `docs/3-design/` — technical designs

Design owns architecture, component responsibilities, consequential interfaces, failure behavior, and technical trade-offs. An upstream accepted brief or PRD owns product requirements when present; normally establish that owner before product-led design. A design-first route may begin provisionally from a known problem and constraints, then derive requirements and reconcile the same design before affected delivery planning or implementation. Existing accepted briefs within historical designs remain valid. Routine clear changes can identify the brief in their request or design. High-level or low-level detail follows consequence, not a mandatory template.

Each design typically has: summary, goals, non-goals, architecture (with Mermaid diagrams where helpful), decisions (linked to relevant ADRs), open questions, future considerations.

Frontmatter `status:`: `draft → approved → shipped → superseded`.

### 4.7 `docs/4-plans/` — Implementation plans

A durable plan combines builder specifications and task ordering: stable task IDs, source obligations, inputs, outputs, contracts, acceptance proof, dependencies, shared resources, and integration ownership. No intermediate spec document is required. A reviewed design can instead support implementation with a native in-session plan when a separate file adds no value. PM tools are optional; declare which record owns definitions and progress before synchronizing another representation.

Frontmatter `status:` matches the design's lifecycle.

### 4.8 `docs/5-reviews/` — artifact reviews, audits, analyses

Reviews assess fidelity to intent, correctness, architecture, usability, and readiness at applicable checkpoints and on the integrated result. Use `-review.md`, `-audit.md`, or `-analysis.md` to identify the report. Existing specialist methods supply the review; the entry skill coordinates them. Personal human approval, review under delegation, and a serial self-check are different evidence.

### 4.8.1 `docs/6-retros/` — process retrospectives and continuous lessons

Retrospectives use `-retro.md` and assess how work was done, with evidence, limitations, and owned follow-ups. They are optional, not a required postscript to every change. Use the [retrospective template](../skills/start-retrospective/references/retrospective-template.md) and [contract](../skills/start-retrospective/references/retrospective-contract.md) for outcomes, successes, problems, contextual lessons and owned actions with follow-up success checks. No sprint cadence, action count or automatic instruction update is required. Incident reviews can retain the project's existing review location.

Capture reusable lessons in the encountering phase, not only after delivery. A short observation can stay in an existing record. When separate discovery or concurrent writing warrants a file, use `6-retros/lessons/<workstream>/YYYY-MM-DD-topic-lesson.md` with `type: lesson`. Record context, evidence, workaround and result, confirmed cause or uncertainty, and what later work should learn. Concurrent writers use separate files. A raw lesson can remain `draft` without becoming unfinished delivery work; briefing excludes lessons from delivery-work counts and reports their count. Actionable follow-ups belong in the authoritative task or tracker.

Read relevant prior lessons before repeating similar work. Retrospectives synthesize lessons, source changes, execution evidence, and review findings without inventing telemetry. Assign an owner and disposition to follow-ups, then check adopted improvements in later work. Consolidation preserves links to raw evidence and grants no automatic deletion, global configuration, or installation authority.

### 4.9 `docs/guides/` — Internal procedural how-tos

(Renamed from `5-guides/` — the number was forcing alphabetical sort, not signaling a workflow position.)

Operational reference docs that survive any single initiative. How to upgrade firmware, how to restore from backup, how to deploy a new service, performance primers, this guide itself.

Evergreen — no `status:` field. Optional `last_reviewed:`.

### 4.10 `docs/adrs/` — Architecture Decision Records

(Renamed from `6-adrs/` — see §4.9 note. ADRs are not lifecycle phase artifacts; they're persistent decision records.)

Single-decision files. One file per architecture decision, named `<NNNN>-<short-title>.md` (where `NNNN` is a 4-digit zero-padded sequence number). Example: `adrs/0001-database-choice.md`, `adrs/0023-rate-limit-strategy.md`.

Each ADR captures: considered options, picked option, reasoning, and cross-references to related ADRs and design docs.

```markdown
# <NNNN>: <Full Title>

## Considered
- Option A: ...
- Option B: ...

## Picked
<the choice>

## Why
<reasoning>

## Related
- [0017](0017-other-decision.md) — relationship
```

ADRs are decisions, not deliverables — they don't "ship." Their lifecycle is `draft → approved → superseded`.

### 4.11 `archive/`

Frozen imported material — chat exports, retired handover docs, third-party reports you want preserved alongside the project. Date-prefixed sub-folders for provenance:

```
archive/
├── 2026-04-25-design-chat/
│   ├── conversation-dump.md
│   └── original-handover.md
└── 2026-04-30-implementation-chat/
    └── conversation-transcript.md
```

Distinct from `docs/` — archive content is read-only historical, never updated. Distinct from `docs/notes/` — `notes/` holds editable scratch and imports you DO want loaded as session context; `archive/` holds frozen content you specifically DON'T want loaded.

### 4.12 `configs/`, `scripts/`, `skills/`, `.claude/`

Project-specific. Adapt to your needs:

- `configs/` — versioned config files (Docker Compose, Kubernetes manifests, IaC templates, app configs).
- `scripts/` — tested ops scripts. Half-finished work doesn't go here; use a `wip/` subfolder or keep it locally.
- `skills/` — Claude Code skills (or similar agent definitions). May or may not apply to your project.
- `tools/` — extraction-ready bundles for multi-part tools. Keep each tool's command, library, wrappers, skills, tests, and docs together so a later repository split stays mechanical.
- `.claude/` — Claude Code workspace settings (typically `settings.local.json` is gitignored).

---

## 5. Conventions

### 5.1 Filename conventions

| Folder | Pattern | Example |
|---|---|---|
| `notes/` | `YYYY-MM-DD-<topic>.md` (or freeform) | `2026-05-12-claude-design-chat.md` |
| `0-brainstorms/` | `YYYY-MM-DD-<topic>.md` | `2026-05-01-quarterly-ipv6-rescan-routine.md` |
| `1-research/` | `YYYY-MM-DD-<topic>-research.md` (or `-analysis.md`, `-spike.md`) | `2026-05-10-photo-platform-research.md` |
| `2-requirements/` | `YYYY-MM-DD-<topic>-prd.md` | `2026-05-10-photo-platform-prd.md` |
| `3-design/` | `YYYY-MM-DD-<topic>-design.md` | `2026-04-25-storage-architecture-design.md` |
| `4-plans/` | `YYYY-MM-DD-<topic>-plan.md` | `2026-04-25-storage-architecture-plan.md` |
| `5-reviews/` | `YYYY-MM-DD-<topic>-{audit,review,analysis}.md` | `2026-04-28-foundation-review.md` |
| `6-retros/` | `YYYY-MM-DD-<topic>-retro.md` | `2026-04-28-foundation-retro.md` |
| `6-retros/lessons/<workstream>/` | `YYYY-MM-DD-<topic>-lesson.md` | `2026-04-28-retry-lesson.md` |
| `guides/` | `<topic>-guide.md` (no date) | `bios-update-guide.md` |
| `adrs/` | `<NNNN>-<short-title>.md` | `0023-ipv6-enabled-eero-firewall.md` |
| `architecture.md` / `architecture/` | `<aspect>.md` (no date) | `architecture.md`, `architecture/network.md` |

**Why date prefixes on lifecycle docs:** sorts chronologically (`ls 3-design/` shows the design history in order); answers "when was this written?" without opening the file; future versions of the same topic don't collide on filenames.

**Why no date prefix on evergreen:** these get UPDATED, not appended. The git log shows when content changed; the filename should reflect what the doc IS, not when it was created.

**Why suffixes (`-design`, `-plan`, etc.):** filenames travel out of folder context (tab titles, attachments, search results). The folder tells you the stage when the doc is in the repo; the suffix tells you the stage when the file is anywhere else.

### 5.2 File-name casing (project-meta vs content)

| Class | Case | Examples |
|---|---|---|
| Front-page meta file (open-source convention level) | `UPPERCASE.md` | `README.md`, `LICENSE`, `CHANGELOG.md`, `ROADMAP.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md` |
| Internal content doc | `lowercase.md` or `kebab-case.md` | `architecture.md`, `services.md`, `vision.md` (if internal), `best-practices.md` |
| Lifecycle artifact | `YYYY-MM-DD-<topic>-<suffix>.md` | `2026-05-02-feature-x-design.md` |

The test: *"Would this file be expected at the front page of any open-source project, or is it specific content for this one?"* Front-page expected → UPPERCASE; specific content → lowercase.

### 5.3 Shareability rule

Any path or command that appears in repo content (skills, guides, templates, READMEs) should be runnable by a colleague without rewriting. Three patterns to follow:

1. **Use placeholders, not user-specific paths.** `<destination>`, `<path-to-repo>`, `<new-project-path>` — angle-bracketed placeholders are visually obvious as fill-ins. Avoid `~/Projects/` (presumes a specific home-dir layout).
2. **Use public GitHub URLs over local paths.** `https://raw.githubusercontent.com/<user>/<repo>/main/...` works for any cloner; `~/Projects/<user>/<repo>/...` doesn't.
3. **Use harness-standard paths over user layouts.** `~/.claude/skills/<name>/` is the harness's universal install path — works for everyone. `~/dev/claude/skills/...` is your layout.

The test before shipping any snippet: *"Could a colleague paste this and run it on their machine?"* If no, reformulate.

### 5.4 Frontmatter

All `docs/*.md` files carry YAML frontmatter, with the exemptions listed below. Two schemas.

**Format rules** (these bite in practice — see the 2026-07-24 audit):

- The frontmatter block starts **at byte 0** with a `---` fence line and closes with a second `---` fence. `status:` lines written as plain text under the H1 are pseudo-frontmatter — invisible to every parser and to `grep`-based corpus queries.
- **Core field names are a closed vocabulary**: `created`, `updated`, `title`, `type`, `status`, `scope`, `authors`, `reviewed_by`, `supersedes`, `superseded_by`, `related`, `last_reviewed`. Legacy `date` remains readable as the original document date during migration. New and migrated lifecycle records use `created` and `updated`. Existing projects keep their actively declared schema until compatible validators and local conventions are deployed. Use `scope`, not `tags`, and `authors`, not `owner`. Extra project-specific fields are allowed without replacing core fields.

**Schema A — lifecycle and decision docs** (`0-brainstorms/`, `1-research/`, `2-requirements/`, `3-design/`, `4-plans/`, `5-reviews/`, `6-retros/` including standalone lessons, legacy lifecycle directories, and `adrs/`):

```yaml
---
created: "2026-05-12"
updated: "2026-05-12"
title: "Install Plex"
type: design                       # brainstorm | research | requirements | design | plan | review | audit | analysis | retro | lesson | adr
status: draft                      # draft | approved | in-progress | shipped | resolved | superseded | open | parked | abandoned
authors: ["Jane Doe", "claude-fable-5 (claude-code)"]  # see "Authorship" below
scope: [containers, network]       # optional, multi-valued tags
reviewed_by: []                    # optional, accountable human GitHub username, with delegation qualifier when applicable
supersedes:                        # optional, path of doc this replaces
superseded_by:                     # optional, path of doc replacing this
related: []                        # optional, paths to related docs
---
```

**Dates.** `created` is the original document date and stays fixed. Set both fields to the creation date for a new lifecycle record. Advance `updated` when content, decisions, status, or execution progress changes. Folder moves, link repairs, and schema normalization preserve the pre-migration update date. Use calendar dates in `YYYY-MM-DD` form; quoted values keep their interpretation consistent across YAML readers. `updated` must not precede `created`.

Backfill a missing `updated` from the last recorded Git author date at a fixed pre-migration revision. This is an edit-history baseline, not proof of a substantive change. Preserve an existing valid update value. A missing history or conflicting date needs an explicit resolution; never substitute the migration date. Review provenance still identifies the reviewed revision, and `last_reviewed` remains a separate deliberate accuracy check. Evergreen records can use these date fields when useful; their schema does not require them. Saved event logs, raw evidence, and informal notes retain their own formats.

**Schema B — evergreen docs** (`architecture.md`, `architecture/`, optional `system/`, `guides/`, single-file evergreen at `docs/` root):

```yaml
---
title: "Container Roster"
type: system                       # system | guide | architecture | reference
authors: ["Jane Doe", "claude-fable-5 (claude-code)"]
scope: [containers]                # what aspect(s) this doc covers
last_reviewed: 2026-05-12          # optional — deliberate "I confirmed this is current"
---
```

**Authorship.** `authors` is an ordered, append-only list that always names the human plus the agent(s):

- First entry: the human operator, taken from `git config user.name` (matters in multi-person projects — it says whose session produced the doc).
- Then each contributing agent as `"<model> (<harness>)"` — e.g. `"claude-fable-5 (claude-code)"`, `"gpt-5.5-codex (codex)"`, `"gemini-3.1-pro (agy)"`. Use the real model id, not just the harness name, so multi-model work stays distinguishable.
- Append on authoring or substantial rewrite; don't append for typo fixes. Review passes are recorded in `reviewed_by`, never in `authors`: the accountable human's GitHub username, plus `(delegated to <model>, <harness>)` when that human did not read the artifact. The commit recording that outcome is the reviewed revision. Agent review never proves personal human review.
- Frontmatter is the source of truth for doc authorship, not git: commits batch multiple docs, and the committing session/harness often isn't the writing one. Git `Co-Authored-By` trailers are corroboration only.
- Backfilling old docs: don't fabricate authorship — omit `authors` (or use `authors: [unknown]`); backfill only the fields you can state accurately.

**Exemptions** (no frontmatter required):

- `notes/` — informal by design.
- `assets/`, `imports/`, and files *inside* a review/discovery bundle (raw model outputs, dispatched prompts, per-persona responses): the bundle's top-level report or README carries the frontmatter for the set.
- Project-level docs (`README.md`, `CLAUDE.md`, `CHANGELOG.md`, `ROADMAP.md`) — well-known by name.
- **Public user docs are out of scope entirely** (e.g. a public repo's end-user `docs/`): they may carry their own project standard, including none. Don't add agent attribution there unless the project says to.

The bundled [drift-guard](../git-hooks/drift-guard/) accepts the nine statuses in both layouts. Canonical lifecycle dates require valid `created` and `updated` values in order. Legacy `date` input remains accepted; when both creation fields exist they must agree. Legacy `type: discovery` remains readable and the migration normalizes it to `research`; `analysis` remains a canonical type. Standalone nested lessons receive lifecycle checks, with other nested bundle contents and assets exempt. The hook checks supported fields rather than validating every YAML construct. Install compatible hooks before migrating records; documentation edits do not update installed copies.

### 5.5 Status semantics

For lifecycle docs:

- `draft` — being written or pending review
- `approved` — accepted under the applicable review authority; actual authorization to proceed is checked separately
- `in-progress` — execution underway
- `resolved` — exploration or investigation concluded
- `open` — exploration or a question remains active
- `parked` — deferred with a condition for resuming
- `shipped` — implementation done; relevant evergreen docs (`architecture.md`, `system/*`, etc.) updated; CHANGELOG entry exists
- `superseded` — replaced by a newer doc (must set `superseded_by:` path)
- `abandoned` — explicitly not pursuing; kept as historical record

**ADR exception:** ADRs don't ship. Their lifecycle is `draft → approved → superseded`.

**Brainstorm exception:** exploration can remain `open`, become `parked`, conclude as `resolved`, or be `abandoned`. Use `superseded` only when another record replaces it, not simply because a design exists. Lessons may stay `draft`; actionable work is tracked separately.

### 5.6 Conventional Commits

```
<type>(<scope>): <description>
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `ci`. Imperative mood. Reference LLD and ADR paths in the body:

```
feat(plex): install Plex container with Tailscale exit

Closes LLD: docs/3-design/2026-05-12-install-plex-design.md
Updates docs/architecture.md (or system/containers.md, system/network.md if you use system/).
```

### 5.7 Diagrams (Mermaid as default)

```mermaid
graph TD
    A[Idea] --> B{Crystallised?}
    B -->|No| A
    B -->|Yes, research| C[1-research]
    B -->|Yes, design| D[3-design]
    D -.-> E[4-plans]
    E --> F[Implementation]
    D --> F
    Request[Clear request] --> F
    F --> G[5-reviews]
    F --> H[system/* updated]
```

Why Mermaid:
- Renders natively in GitHub, VS Code, Obsidian — no external image asset to keep in sync.
- Source is plain text — diffable in git, editable in any editor, AI-authorable.
- The diagram travels with the doc when files move.

Fall back to other tools (draw.io, Excalidraw) only when Mermaid genuinely can't represent what you need. Commit both source and rendered output if you do.

### 5.8 `## Project Map` section in CLAUDE.md

CLAUDE.md should declare where project-tracking information lives, so AI tools can read it without guessing. The canonical consumer is the [`/briefing`](../skills/briefing/) skill — it auto-discovers state across git, GitHub, the canonical `docs/` working-memory layout, and any tracker source declared here.

> **Renamed 2026-05-07.** Previously called `## Project Context` (Title Case) and originally `## Project context` (sentence case). The `/briefing` skill matches all three case-insensitively for backward compatibility. New CLAUDE.md files should use the canonical `## Project Map`. Existing adopters can migrate via `/briefing setup`, which proposes the rename as part of its diff.

Each line is `- **Field**: value`. Recognised fields:

| Field | Purpose |
|---|---|
| `Tracker` | Where work items live (`GitHub Issues`, `Linear team FOO`, `Jira project BAR`, `Notion`, `GitHub Project N`, file path, or `none`) |
| `Board` | URL of the active board / project view |
| `Roadmap` | File path or external URL of the forward view |
| `Changelog` | File path or external URL of recent shipped work |
| `Architecture` | File path or directory of architecture docs |
| `Working memory` | Directory holding lifecycle artifacts (default: `docs/` following this guide's numbered-lifecycle convention) |
| `Other` | Free-form bullet list for project-specific context (custom scripts, story-tracking quirks, telemetry sources) |

#### Complete examples

A fully-populated section for a typical solo project following the canonical conventions:

```markdown
## Project Map

- **Tracker**: GitHub Issues
- **Board**: none
- **Roadmap**: docs/ROADMAP.md
- **Changelog**: docs/CHANGELOG.md
- **Architecture**: docs/architecture.md
- **Working memory**: docs/ (numbered lifecycle convention)
- **Other**:
  - Test reports live in `tmp/tst_<name>/`, not in repo
  - Manual UI smoke tests via `npm run dev` before merge
```

A non-canonical project that uses flat `docs/plans/` and tracks work in Linear:

```markdown
## Project Map

- **Tracker**: Linear team SHARELOG
- **Board**: https://linear.app/sharelog/team/SHARELOG/board
- **Roadmap**: docs/plans/ROADMAP.md
- **Changelog**: none
- **Architecture**: none
- **Working memory**: docs/plans/
- **Other**:
  - Date-prefixed plan files in `docs/plans/` (e.g. `2026-02-19-feature-name-plan.md`)
  - Top-level `docs/<topic>-plan.md` files are also working memory
```

#### When to declare, omit, or use `none`

Three meaningfully different states per field:

- **Set a value** when the field has a concrete location or source. Most common case.
- **Omit the field entirely** when you want the briefing to fall back to the canonical default path (e.g. omit `Roadmap` if `docs/ROADMAP.md` is exactly where it should be — the briefing finds it via convention sniffing).
- **Set the field to `none`** when the absence is *intentional* — e.g. `**Tracker**: none` for a project that genuinely has no issue tracker, or `**Board**: none` when no project board exists. This tells the briefing to skip probing rather than treating absence as a gap.

The distinction matters because the briefing's `★ About this briefing` block fires "tracker integration unavailable" when a tracker is *declared but unreachable*; declaring `none` suppresses that bullet entirely.

#### Discovery hints

Working out what to put in each field — questions to ask yourself:

- **`Tracker`** — Where do you (and your collaborators) track issues? GitHub Issues / Linear / Jira / a file like `TODO.md` / nowhere (`none`)? If multiple, pick the canonical one and mention the others under `Other`.
- **`Board`** — Does the tracker have a kanban-style board view? Paste the URL. If you only use a flat list, `none`.
- **`Roadmap`** — Where do you write "what's next"? `docs/ROADMAP.md` is the canonical default; if you put it elsewhere (`ROADMAP.md` at repo root, a Notion page, a Linear cycle view), declare it.
- **`Changelog`** — Where does shipped work get recorded? Same rule as Roadmap.
- **`Architecture`** — Is there a single doc or directory describing the system's current shape? `docs/architecture.md` or `docs/system/` are common; `none` is fine if architecture is small enough to live in README.
- **`Working memory`** — Where do designs, plans, brainstorms, retros live? `docs/` (with numbered subdirs) is canonical; flat layouts like `docs/plans/` work too — declare the directory.
- **`Other`** — Anything else AI tools should know: custom scripts, where test artefacts live, naming conventions for non-canonical files, integration quirks. Free-form bullets.

#### Layered fallback

**Absent fields fall back to layer-1 defaults at canonical paths.** A field set to `none` means "deliberately empty" (the briefing won't probe further); an absent field means "try the default" (the briefing will look at the canonical path).

The canonical scaffold lives in [`templates/default-project/CLAUDE.md`](../templates/default-project/CLAUDE.md). Bootstrapped projects inherit the section for free; existing projects pick it up via §10.6.

### 5.9 Readable docs and illustrations (HTML → PNG mockups)

Docs in `docs/` — designs, plans, brainstorms, discovery, reviews, retros — are written for humans first. Structure over prose: section headers, bullet points, tables for enumerable facts, Mermaid for flows/architecture/sequences (§5.7). Long unbroken text is a smell; if a section can't be skimmed, restructure it.

**Illustrate, don't just describe.** When a doc discusses anything visual — UI/UX mockups, hi-fi concepts, screenshot examples, before/after comparisons — embed images:

1. Build a **self-contained single-file HTML mockup** (inline CSS, no build step, no external files) in the doc's `assets/` set — e.g. `docs/3-design/assets/2026-07-31-<topic>/concept.html`, per §5.10. Single-file keeps it git-native, openable in any browser, and editable by AI in one pass. Include a light/dark toggle when theming is part of the design.
2. **Screenshot it headlessly** with Playwright or a similar tool, one PNG per state or theme that matters. If Playwright MCP blocks `file://` URLs, start it with `--allow-unrestricted-file-access` (see the [browser automation guide](guide-browser-automation-mcp-vs-cli.md)) rather than running a local web server.
3. **Commit HTML and PNGs together** and embed the PNGs in the doc with relative links so they render on GitHub. The PNG is what the doc shows; the HTML is the editable source of truth and doubles as a visual spec for implementation.

Why this over design tools: artifacts version in git next to the doc, render in every markdown viewer, need no external account or export step, and an AI session can regenerate both halves when the design changes. (Same fallback rule as §5.7: reach for Figma/Excalidraw only when a hand-written mockup genuinely can't represent what you need — and still commit the rendered output.)

### 5.10 `assets/` — attachments that belong to a doc

Docs accumulate things that aren't Markdown: rendered mockups and their HTML source, probe scripts, raw model outputs, captured data, screenshots. They live in an `assets/` folder inside the same lifecycle directory as the doc that owns them.

**One folder name, one subfolder per set.** Not `mockups/` for one kind and `assets/` for another — a single name, with each artifact set getting its own subfolder:

```
docs/3-design/assets/
├── 2026-07-31-terminal-rendering-evidence/
│   ├── README.md
│   └── altscreen-probe.py
└── 2026-07-31-comment-preview-concept/
    ├── concept.html
    ├── concept-light.png
    └── concept-dark.png
```

**Dating follows the directory, not a judgment call.** You already know which directory you are in, so the naming is decided for you:

| Location | Subfolder name | Why |
|---|---|---|
| Numbered lifecycle dirs (`0-brainstorms/` … `6-retros/`) | `<YYYY-MM-DD>-<slug>/` | The doc is a dated point-in-time record, so its attachments are frozen with it |
| Evergreen dirs (`guides/`, `adrs/`, `docs/` root) | `<slug>/` | These docs get updated rather than appended (§2.3), and so do their attachments |

That rule exists to protect the record. A design doc dated 2026-07-31 embeds a diagram showing what was proposed *then*. If that file kept evolving in place, the doc would silently start illustrating a design it never described — the artifact would drift out from under the prose that references it.

**A living artifact belongs somewhere else.** If a mockup becomes the standing visual spec rather than a snapshot of one design, it graduates out of the numbered dirs — into `docs/guides/assets/`, a design-system folder, or the project's own UI code. Same lifecycle-versus-evergreen boundary this guide already draws for docs (§2.3), applied to their attachments.

**Add a `README.md`** when the set needs explaining: several files, non-obvious provenance, or measurements worth recording. State what the artifacts are, how they were produced, and anything a reader would otherwise misinterpret — a probe's inconclusive row, a capture's known gaps. A single HTML file and its PNG explains itself; skip it.

`assets/` contents are exempt from frontmatter (§5.4), including the README.

**Why not `artifacts/`:** this guide already uses "artifact" throughout for the lifecycle docs themselves — "each artifact stands alone", "each phase commits its own artifacts". A folder holding everything *except* those would collide with established vocabulary.

---

## 6. Workflow

### 6.1 Lifecycle of a piece of work

```mermaid
graph LR
    Idea[New idea] --> Brainstorm[0-brainstorms/]
    Brainstorm --> Discovery[1-research/<br/>research artifact]
    Brainstorm --> Design[3-design/<br/>LLD]
    Discovery --> Design
    Design --> Plan[4-plans/<br/>implementation plan]
    Plan --> Build[Implementation]
    Build --> Review[5-reviews/<br/>artifact review]
    Review -.-> Retro[6-retros/<br/>process retrospective]
    Request[Clear request] --> Build
    Design --> Build
    Discovery -.-> Requirements[2-requirements/<br/>accepted scope]
    Requirements --> Design
    ResearchFirst[Research question] --> Discovery
    Build -.-> Debug[Debugging]
    Debug --> Build
    Build --> SystemUpdate[architecture.md or system/* updated]
    Build --> Changelog[CHANGELOG entry]
    Build --> Roadmap[ROADMAP updated]
```

Not every piece of work touches every stage. Any clear authorized change can use implementation with an in-session plan and appropriate review. A design can suffice without a durable plan; size categories alone require no document. A multi-month initiative might cycle through multiple plans and reviews. Stop at a phase-only boundary by default. Explicit full or partial autonomous scope can authorize included transitions and reviews; record that scope once, preserve retained human gates, and never claim delegated review as personal human approval. Recommendations alone authorize nothing.

### 6.2 Change discipline

When a design or plan flips to `status: shipped`, the same commit (or commit series) must also:

1. Update relevant evergreen state docs to reflect the new reality — `docs/architecture.md` (or `docs/architecture/*`), or `docs/system/*.md` if the project uses operational state docs.
2. Add a `CHANGELOG.md` entry referencing the design/plan.
3. Update `ROADMAP.md` — move the item from "In flight" to "Recently shipped"; unblock dependents.
4. Set the design's frontmatter to `status: shipped`.

This keeps the always-current docs honest and the ROADMAP synchronised.

### 6.3 ROADMAP discipline

`docs/ROADMAP.md` is the single source of truth for "what's next." Seven sections:

| Section | Meaning |
|---|---|
| **In flight** | Active work right now |
| **Next actions** | Concrete, ready-to-do items; just not started yet |
| **Drafts (pending review)** | Designs/plans with `status: draft` needing review before they unlock execution |
| **Future considerations** | On the radar but not designed yet — not actionable until designed |
| **Open questions** | True unknowns — things to find out or decide *before* they could become actions |
| **Parked** | Items considered and deferred — kept visible so they're not forgotten (PEP-vocabulary prefix) |
| **Recently shipped** | Backward view; mirrors CHANGELOG with shorter entries |

**Lifecycle of an item in ROADMAP:**

1. New idea → **Future considerations** (or skip if it lands ready-to-design).
2. Designed → **Drafts** (a design + plan exist with `status: draft`).
3. Draft reviewed and approved → **Next actions** (or **In flight** if starting immediately).
4. Started → **In flight**.
5. Shipped → **Recently shipped** + CHANGELOG entry + evergreen-state updates + frontmatter `status: shipped`.
6. Parked at any stage → **Parked** with `Deferred:` / `Declined:` / `Superseded:` prefix.

**Triage question for any new item:**

- Do we know what to do? → **Next actions**
- Do we have a design but not approval yet? → **Drafts**
- Do we have an idea but no design? → **Future considerations**
- Do we need to figure something out first? → **Open questions**
- Did we consider it and decide not now? → **Parked**

**Substantial Next-actions get a brainstorm note.** When a Next action is more than a one-liner — e.g., setting up a recurring routine, planning a maintenance procedure, scoping out a comparative purchase — capture the *details* in `docs/0-brainstorms/YYYY-MM-DD-<topic>.md` with `status: open`. ROADMAP holds the one-line pointer and link; the brainstorm holds the full proposal.

**Parked-item vocabulary (borrowed from [PEP 1](https://peps.python.org/pep-0001/)).** Each entry in `## Parked` carries a one-word prefix that says *why* the door is closed:

| Prefix | Meaning | When to use |
|---|---|---|
| **Deferred:** | Stalled or paused; may revisit | Life happened; waiting on a trigger ("when X lands"); nothing wrong with the idea |
| **Declined:** | Decided against after consideration | We thought about it and chose not to pursue; brief reasoning attached |
| **Superseded:** | Replaced by another approach | A different design covers the same need; link to the replacement |

This is the three-way semantic split PEP, KEP, and most mature proposal-tracking systems converge on (see industry research across PEP, KEP, and RFC proposal systems). Each parked entry should link to the underlying brainstorm or design file with frontmatter `status: parked` (for `Deferred`), `status: abandoned` (for `Declined`), or `status: superseded` (for `Superseded`).

**Truncation rule for Recently shipped.** Keep the last 10 entries OR the last 90 days, whichever is shorter. Older shipped items live only in `CHANGELOG.md` (the long-term record). The ROADMAP's purpose is forward-leaning navigation, not historical archive.

### 6.4 Brainstorm promotion

Promotion follows an explicit user decision or authorized workflow scope. It can produce no initiative, one, or several. Research supplies evidence and does not itself approve scope. A separate Requirements phase or PRD is useful when product definition needs deliberate decisions; otherwise a clear request, issue, or brief within design can own accepted scope. Link that owner to the brainstorm and research. Do not set `superseded_by:` unless a record actually replaces the exploration.

### 6.5 AI-agent update triggers (working-memory discipline)

This convention assumes AI coding agents (Claude Code, Codex, etc.) are primary maintainers of `docs/` going forward. AI agents work in conversations and treat conversation as ephemeral by default — without explicit triggers, working-memory artifacts (ROADMAP, CHANGELOG, brainstorms, ADRs) lag behind reality.

**Event-triggered writes.** When any of the following happens during a session, the agent SHOULD make the listed change *in the same session*, not "later":

| Event | Required write |
|---|---|
| Agreed to start a substantial new initiative not yet in `docs/` | Capture the applicable source artifact during the session when the document test calls for it, using a brainstorm for exploration and the accepted scope owner for delivery. Add or update one ROADMAP line in the appropriate section. In a public/private split, restate the public-safe work without naming or linking private sources. |
| Brainstorm crystallises into a design during conversation | Create `docs/3-design/YYYY-MM-DD-<topic>-design.md` with `status: draft`. Move ROADMAP pointer from Future considerations / Next actions → `## Drafts (pending review)`. Link the design and accepted scope owner to the brainstorm; preserve still-applicable exploration and rationale. |
| Design approved | Flip frontmatter `status: approved`. Move ROADMAP pointer from Drafts → `## Next actions` (or `## In flight` if starting immediately). |
| Implementation begins | Move ROADMAP pointer to `## In flight`. |
| Implementation ships | Per §6.2 change discipline: flip design + plan to `status: shipped`; update evergreen state docs; add CHANGELOG entry; move ROADMAP pointer to `## Recently shipped`. All in the same commit (or commit series). |
| Work parked / deferred | Flip artifact frontmatter to `status: parked` (or `abandoned` / `superseded`). Move ROADMAP pointer to `## Parked` with the appropriate prefix. |
| New unresolved decision identified | Add to ROADMAP `## Open questions` with the question stated as a question. |
| Open question resolved | Remove from `## Open questions`. The resolved decision lands in an ADR (`docs/adrs/<NNNN>-<title>.md`) or in a design's "Decisions" section. |
| Substantive audit, retro, or analysis emerges from a conversation | Save artifact reviews and analyses under `docs/5-reviews/`, process retrospectives under `docs/6-retros/`, and reusable lessons in the encountering phase (§4.8.1). Don't let the work evaporate at session end. |

**Session-end check.** Before ending a session in which we made non-trivial decisions, discovered convention gaps, agreed on changes, or did substantive evaluative work, the agent should explicitly verify:

1. Has every status change in this session been written to the relevant artifact's frontmatter?
2. Does ROADMAP accurately reflect what's now In flight / Drafts / Next actions / Parked?
3. Did anything emerge that needs an exploration, review, retrospective, lesson, or ADR record but lacks one?
4. Is CHANGELOG up to date with shipped work?
5. Does every working-memory doc created or substantially edited this session have valid frontmatter per §5.4 — fenced at byte 0, core field names, `authors` naming the human plus the agent?

If the answer to any is "no," the agent should propose the missing writes inline before ending the session — not silently move on.

**Recurring audit (recommended).** Schedule a recurring agent (via `/schedule` or equivalent) to run this same check periodically — weekly for active projects, monthly for slower-moving ones. The agent reads ROADMAP, scans `docs/` for status drift between ROADMAP entries and lifecycle artifacts, and reports gaps. This is the [GTD weekly review](https://gettingthingsdone.com/) made into infrastructure.

**Why this needs to be explicit.** Conventions written for human authors assume an instinct to "save your work." AI agents have no such instinct — they treat the conversation as the work product unless told otherwise. The triggers above make the implicit instinct explicit and machine-actionable. Skipping them is the most common cause of working-memory rot in AI-maintained projects.

---

## 7. Recommended tools and plugins

This structure is tool-agnostic — git, markdown, and a text editor are enough. But it's *designed* to work well with AI coding harnesses (Claude Code, Cursor, Codex CLI), and there are specific plugins/skills that operationalise the conventions described above. The list below is for Claude Code, where the structure was developed. Other harnesses may have equivalents. Plugin names and features were current in 2026, so check each one before installing.

You don't need all of these — pick what fits your workflow.

### 7.1 Workflow plugins (the chain itself)

These implement or support the brainstorm → design → plan → implement → finish chain from §6.

| Plugin | Provides | Used for |
|---|---|---|
| This toolkit's skills | `start-brainstorm`, `start-design`, `start-planning`, `start-implementation`, `start-debugging`, `tdd`, `receiving-code-review`, `git-worktrees` | The full SDLC workflow, installed by `scripts/sync-toolkit.sh` rather than a plugin. See the [skill catalog](../skills/README.md#phase-boundaries). |
| `claude-md-management` | `claude-md-improver`, `revise-claude-md` | `/claude-md-improver` audits CLAUDE.md against quality criteria. `/revise-claude-md` updates it with end-of-session learnings. |
| `commit-commands` | `/commit`, `/commit-push-pr`, `/clean_gone` | Conventional-commit-formatted commits, push + PR creation in one step, clean-up of stale branches. |

### 7.2 Verification plugins (back the verification policy)

These support the "search before answering when unsure" policy from §5.

| Plugin | Provides | Used for |
|---|---|---|
| `context7` | `resolve-library-id`, `query-docs` | Fetches current library / framework / SDK docs on demand — preferred over web search for library-specific queries (covers React, Next.js, Prisma, Express, Tailwind, Django, etc.). |
| `security-guidance` | `/security-review` | Reviews pending changes on the current branch for security issues before merge. |
| `code-review` | `/review` | Single-shot PR code review against project conventions (CLAUDE.md). |
| `pr-review-toolkit` | `/review-pr` (multi-agent) | Comprehensive PR review using 6 specialised subagents: code-reviewer, code-simplifier, comment-analyzer, pr-test-analyzer, silent-failure-hunter, type-design-analyzer. |

### 7.3 Discovery and adoption plugins

| Plugin | Provides | Used for |
|---|---|---|
| `claude-code-setup` | `claude-automation-recommender` | Analyses a repo and recommends Claude Code automations (hooks, subagents, skills, plugins, MCP servers). Run this first when adopting Claude Code in a new project. |
| `skill-creator` | Skill scaffolding + evals | Create new skills, modify existing ones, run evals to measure skill triggering accuracy and performance. |
| `superpowers-developing-for-claude-code` | `working-with-claude-code`, `developing-claude-code-plugins` | Reference + workflows for building Claude Code plugins, hooks, MCP servers, and skills. Useful when extending the toolset itself. |

### 7.4 Output style

| Plugin | Provides | Used for |
|---|---|---|
| `explanatory-output-style` | `explanatory` output style | Adds inline `★ Insight` blocks that teach what's happening as work proceeds. Useful when learning a new domain or onboarding to a codebase. Toggle via `/output-style explanatory`. |

### 7.5 Project-type-specific plugins (optional)

Pick based on what your project does.

| Plugin | When useful |
|---|---|
| `feature-dev` | Software projects with discrete feature work — provides code-explorer, code-architect, code-reviewer subagents. Less critical for infra/docs projects. |
| `code-simplifier` | After writing code, refines for clarity and maintainability. |
| `frontend-design` | Projects with web frontends — generates production-grade React/Next.js components. |
| `ui-ux-pro-max` | Web/mobile UI/UX design — 50+ styles, 161 colour palettes, 57 font pairings, integration with shadcn/ui. |
| `playwright` | Browser-automation MCP — useful for testing web apps or scraping. |
| `typescript-lsp` | TypeScript projects — Language Server Protocol integration for diagnostics and refactoring. |
| `agent-sdk-dev` | Building Claude Agent SDK applications (Python or TypeScript). |
| `playground` | Building self-contained interactive HTML explorers/playgrounds. |

### 7.6 Built-in skills (no plugin needed)

These come with the harness itself and complement the structure:

- `/schedule` — create recurring or one-time remote agents. The natural home for proposals captured in `docs/0-brainstorms/` (e.g., quarterly maintenance routines, monthly health checks).
- `/loop` — run a prompt or slash command on a recurring interval within a session. Useful for "keep checking until X" workflows.
- `find-skills` is an external skill from [vercel-labs/skills](https://github.com/vercel-labs/skills), not a guaranteed built-in. Install it separately if wanted.
- `update-config` — configure the harness via `settings.json`, including hooks for automated behaviours.
- `keybindings-help` — customise keyboard shortcuts.

### 7.7 MCP connectors (claude.ai)

MCP (Model Context Protocol) connectors give Claude access to external services. These run in claude.ai (web/desktop) by default; some may also be available via CCR remote agents. Configure at https://claude.ai/customize/connectors.

| Category | Connectors | Useful for |
|---|---|---|
| Communication | Slack, Gmail | Sending notifications from routines, reading project communication |
| Knowledge | Notion, Google Drive | Cross-project notes, attachments, shared docs |
| Calendar | Google Calendar | Scheduling, reminders, time-blocking |
| Deployment | Vercel | Web app deployment + log access |
| Design | Canva | Asset generation |
| Library docs | context7 (also a plugin) | Up-to-date framework documentation |
| Browser | Playwright | Web automation |

For routine agents (created via `/schedule`), MCP connectors expand what the agent can do beyond reading the repo. E.g., a quarterly audit agent can post results to Slack instead of just printing to the routine page.

### 7.8 Marketplaces

Plugins come from marketplaces. Two to know:

- **`claude-plugins-official`** — Anthropic's official marketplace; most plugins above live here.
- **Project-specific marketplaces** (e.g., `ui-ux-pro-max-skill`) — single-plugin marketplaces from individual authors.

Manage via `/plugin` or the documented plugin CLI. Treat `~/.claude/plugins/installed_plugins.json` as generated state, not a hand-edited install manifest. Snapshot your installed set occasionally — versions and SHAs drift over time.

### 7.9 Minimum viable setup for this structure

If you only install three things:

1. **This toolkit's skills** — for the workflow chain, through `scripts/sync-toolkit.sh`.
2. **`claude-md-management`** — to keep `CLAUDE.md` healthy.
3. **`commit-commands`** — for clean commits.

That covers the core moves: brainstorm → plan → execute → ship → maintain CLAUDE.md → commit per convention. Everything else is incremental value depending on what your project does.

---

## 8. Adopting this in a new project

### Step 1: Bootstrap from the template

The canonical scaffold lives at `templates/default-project/` in [carlosboeing/agentic-toolkit](https://github.com/carlosboeing/agentic-toolkit). Two paths:

```bash
# Option A — without cloning (recommended; uses degit to fetch the subdirectory):
npx degit github:carlosboeing/agentic-toolkit/templates/default-project <new-project-path>

# Option B — from an existing local clone (replace <path-to-repo> with your clone path):
cp -r <path-to-repo>/templates/default-project <new-project-path>
```

The template ships with `CLAUDE.md`, `README.md`, `.gitignore`, standing tracking files, and a small set of empty starter directories. All seven numbered lifecycle folders are included, with `.gitkeep` in empty folders. These placeholders require no artifacts or phase execution. Create nested asset, lesson and evergreen directories when needed. `system/` and `architecture.md` are NOT scaffolded — they're created on demand when README's `## Architecture` section overflows.

### Step 2: Substitute placeholders

The template uses `<PROJECT_NAME>` placeholders in `CLAUDE.md`, `README.md`, and `docs/ROADMAP.md`. Replace them:

```bash
cd <new-project-path>
grep -rl '<PROJECT_NAME>' . | xargs sed -i '' 's/<PROJECT_NAME>/your-project-name/g'   # macOS
grep -rl '<PROJECT_NAME>' . | xargs sed -i 's/<PROJECT_NAME>/your-project-name/g'      # Linux
```

Then customise `CLAUDE.md` and `README.md` for your project specifics.

### Step 3: Initial commit

Use Conventional Commits from day one:

```bash
git init && git add . && git commit -m "chore: bootstrap repo with project structure conventions"
```

### Step 4: Select the route for the work

Explore an unclear idea; implement a clear authorized request with an in-session plan and appropriate review. Use durable sources only when their decision, review, or recovery value warrants them. A folder convention is not a requirement to create a brainstorm, design, or plan.

### Step 5: Build the muscle

The convention only works if you actually follow it. Specifically:

- When you make a decision worth remembering, write an ADR.
- When you ship something, update evergreen state (`architecture.md` or `system/*`), `CHANGELOG`, and `ROADMAP` in the same commit.
- When exploration produces decisions worth preserving, capture them in `0-brainstorms/`.

Six months in, the structure pays off — you can answer "what did we decide and why?" by reading the ADRs, "what's the current state?" by reading `architecture.md` (or `system/*`), "what's next?" by reading ROADMAP. Without the convention, all three answers require archaeology.

### Bootstrapping without the template (manual)

If you can't or don't want to use the template, scaffold by hand:

```bash
mkdir -p docs
# Create the selected lifecycle directory when its first artifact needs it.
touch docs/ROADMAP.md docs/CHANGELOG.md
# Then write README.md, CLAUDE.md, .gitignore by hand (or copy from your last project).
```

---

## 9. Concrete examples

The conventions earn their value in how artifacts cross-reference each other. The patterns below describe what each artifact looks like in practice — adapt them to your own project.

### A complete initiative

The full lifecycle of a single piece of work — a hardware upgrade, a service migration, a feature rollout — looks like:

- **Design** in `3-design/` lays out the architecture, options considered, and chosen approach. `status: draft` while in flight, `status: shipped` once done.
- **Plan** in `4-plans/` references the design and breaks it into phased steps with verification criteria, effort estimates (S/M/L), risks, and the smallest viable first step.
- **Retro** in `6-retros/` (optional, written after) captures what worked, what surprised, and follow-ups that came out of the work.
- **ADRs** in `adrs/` capture decisions made during the work — usually 1–4 per initiative, sometimes zero. Each ADR is single-decision; supersedes/superseded-by relationships are explicit.
- **Evergreen state updates** land in the same commit that ships the work — `docs/architecture.md` (or `docs/architecture/*`), or `docs/system/*` if the project uses operational state docs.
- **CHANGELOG entry** dated, referencing the design and (if applicable) retro.

The whole bundle is browseable from `ROADMAP.md → Recently shipped`, which links into the design, which links forward to the retro, which links back into ADRs.

### A parked brainstorm

A `0-brainstorms/<topic>.md` doc with `status: parked`, concrete deferral rationale, links to affected drafts, and triggers for when to revisit. Captures pre-design exploration without forcing a commitment.

### A Next-action with full proposal

ROADMAP "Next actions" holds a one-line pointer. The detailed proposal lives in `0-brainstorms/<topic>.md` with `status: open` — the full reasoning, options, and approach. Keeps ROADMAP scannable while preserving the thinking that informs each action.

### An ADR with cross-references

A `<NNNN>-<title>.md` file with: considered options, picked option, reasoning, and a `Related:` section linking to upstream ADRs and to designs that informed the decision. Single-decision per file — if a decision genuinely contains two, write two ADRs.

### An evergreen state doc with cross-references

`architecture.md` (or `architecture/<aspect>.md`, or `system/<aspect>.md`) describes current state with links to the originating design (rationale) and relevant ADRs (per-decision history). Pattern: evergreen state answers "what is the state?", linking out to "why is it that way?" and "what was the design?".

### This guide itself

The doc you're reading is an example of an evergreen how-to in `guides/`. Evergreen, no `status` field, one `last_reviewed:` date that's bumped only when you've personally re-verified the content.

---

## 10. Retrofitting an existing project

For single-project and selected-batch lifecycle adoption, use the [migration entry point and runbook](guide-lifecycle-migration.md).

Projects that follow earlier versions of these conventions (or partial conventions) can be migrated. The runner automates explicit mappings and metadata changes; project classification and the broader retrofit steps below still need judgment. Automatic project detection and bootstrapping remain future `/init-project` work.

### 10.1 Detect current state

Run from the project root:

```bash
ls docs/ 2>/dev/null
find docs -maxdepth 1 -type d 2>/dev/null
```

Identify which of these apply:
- `docs/5-guides/` exists → rename to `docs/guides/` (Step 10.2)
- `docs/6-adrs/` exists → rename to `docs/adrs/` (Step 10.2)
- `docs/system/` exists with multiple files → keep, or split per §4.2 (depends on content)
- `docs/system/architecture.md` only → flatten to `docs/architecture.md`
- `docs/notes/` missing → create when notes need it (Step 10.3)
- A selected lifecycle directory is missing → create when its first artifact needs it (Step 10.3)
- ADRs use `D-N-` or `YYYY-MM-DD-NNN-` patterns → standardise to `NNNN-` (Step 10.4)
- `BACKLOG.md` instead of `ROADMAP.md` → rename or document the alias
- Misplaced evergreen content (`VISION.md`, `gdd.md`, `BestPractices.md` in `1-research/`) → relocate to `docs/` root or appropriate evergreen folder (Step 10.5)

### 10.2 Folder renames

For the lifecycle transition, map `1-discovery/` to `1-research/`, `2-design/` to `3-design/`, `3-plans/` to `4-plans/`, and review records from `4-reviews/` to `5-reviews/`. Classify retrospective records by content and type for `6-retros/`; move exclusive attachments with their owner and retain shared evidence with corrected links. Create all seven numbered lifecycle folders with `.gitkeep` in empty folders. Create nested standalone lesson directories only when used. Normalize legacy `discovery` metadata to `research` during the frontmatter step; retain other types and frozen historical evidence. Classify requirements and lessons temporarily stored in legacy directories by their types before a whole-directory move; route them to `2-requirements/` and `6-retros/lessons/<workstream>/` respectively.

Before any authorized migration, inventory records and existing link failures, check collisions and concurrent writers, and rehearse on a disposable copy. Verify installed tools support both layouts and active sessions no longer depend on the old paths. Record the base revision, intended mapping, and completion marker. Update live navigation, frontmatter relationships, templates, and project instructions together. Compare inventories and link results; accept no migration-caused loss or failure. Preserve historical transcripts, review authority, and evidence. A source-tree edit is not proof of installed compatibility.

The migration includes the frontmatter step. From a toolkit checkout, preview the selected working-memory root, then apply the same command with `--apply` after reconciling its Git state:

```bash
python3 scripts/migrate-frontmatter.py --root <working-memory-root>
python3 scripts/migrate-frontmatter.py --root <working-memory-root> --apply
```

The script handles top-level lifecycle records in either layout, ADRs, and standalone nested lessons. It renames `date` to `created`, preserves or backfills `updated`, and normalizes the legacy research type. It preserves prose, comments, other metadata and file modes, and leaves notes, assets and bundled outputs untouched. It supports the conventional single-line date/type scalars and stops on ambiguous, duplicate or conflicting fields before writing. It makes no commits, installs no hooks, and performs no folder moves. A second run produces no further edits.

Run this step before mechanical folder edits when possible. If folders have already moved, supply the captured pre-migration commit and a JSON map of old-to-current paths, relative to the working-memory root:

```bash
python3 scripts/migrate-frontmatter.py --root <working-memory-root> --source-revision <pre-migration-commit> --path-map <mapping.json>
```

For example, `{"2-design/example.md": "3-design/example.md"}` lets history lookup use the old path. If mechanical folder edits are already committed and later content or progress updates must count, use the current source revision with repeatable `--ignore-revision <mechanical-commit>` arguments. This skips only the named commits during date lookup, follows renames, and retains later genuine edits. Review each ignored commit; do not exclude changes to decisions or execution evidence. The report identifies the selected source commit for each backfilled date. Preview reports the resolved source revision and proposed dates. Keep the source revision and path map with the migration record, and preserve existing update values on reruns. Only apply to a clean selected working-memory tree after compatible tools are available.

The older evergreen renames below apply only when those source directories exist:

```bash
git mv docs/5-guides docs/guides
git mv docs/6-adrs docs/adrs
```

Update any cross-references in CLAUDE.md, README.md, ROADMAP.md, CHANGELOG.md, and per-doc frontmatter `related:` fields.

### 10.3 Keep the lifecycle scaffold visible

Create `0-brainstorms/`, `1-research/`, `2-requirements/`, `3-design/`, `4-plans/`, `5-reviews/` and `6-retros/` in the declared working-memory root, including empty folders with `.gitkeep`. Bootstrap templates and authorized migrations supply this scaffold. Do not create it in the public tree when working memory lives in a separate private repository. Folder presence requires no phase, approval, or document. Create nested lesson and asset directories only when used; never manufacture documents to fill the structure.

### 10.4 ADR naming standardisation

Renumber ADRs to `NNNN-title.md`:

```bash
# Example: D-1-storage.md → 0001-storage.md
cd docs/adrs
for f in D-*.md; do
  num=$(echo "$f" | sed 's/^D-\([0-9]\+\)-.*$/\1/')
  rest=$(echo "$f" | sed 's/^D-[0-9]\+-//')
  printf -v padded "%04d" "$num"
  git mv "$f" "${padded}-${rest}"
done
```

Update internal cross-references: ADRs often reference each other (e.g., "see D-22"). Search and replace:

```bash
grep -rl "D-[0-9]" .
# Update each match: D-1 → 0001, D-22 → 0022, etc.
```

### 10.5 Relocate misplaced evergreen content

Audit `docs/1-research/` for files that aren't actually research artifacts (no thesis, no recommendation):

- `VISION.md`, `*-vision.md` → consider top-level `VISION.md` (front-page meta) or `docs/vision.md` (content)
- `*-gdd.md`, `*-game-design.md` → `docs/gdd.md` (or `docs/architecture.md` if game-design IS the architecture)
- `*-best-practices.md`, `*-analysis.md` (without research basis) → `docs/best-practices.md` or `docs/5-reviews/`

### 10.6 Update CLAUDE.md and verify

- Add/refresh the `docs/ = working memory` framing.
- Update the layout block to match the new structure.
- Add a `## Project Map` section per §5.8. Copy the field list from [`templates/default-project/CLAUDE.md`](../templates/default-project/CLAUDE.md) and fill in the values. If a field doesn't apply (no formal tracker, no separate architecture doc, etc.), set the value to `none` so the `/briefing` skill knows the absence is intentional.
- Run a fresh CC session and confirm context loading is coherent.

### 10.7 Verification

```bash
find docs -maxdepth 1 -type d | sort
ls docs/adrs | head -5
grep -r "5-guides\|6-adrs\|D-[0-9]" docs/ --include="*.md"  # should return only intentional historical references
```

### 10.8 Retrofit is plausibly ongoing alignment work

As the canonical conventions evolve, re-run this procedure. The `/init-project` skill (future) will automate detection and migration; until then, the procedure is the contract.

---

## 11. Notes for adoption

- **Don't try to backfill everything at once.** Adopt the structure for new work; let old docs sit until they're touched. Forced migration is a tax that often kills adoption.
- **The numbered prefixes aren't sacred for evergreen content.** Lifecycle phases are numbered (`0-brainstorms/` through `6-retros/`); evergreen folders (`adrs/`, `guides/`) are plain-named. If you prefer all-named folders (`brainstorms/`, `designs/`, etc.) and accept losing the workflow ordering that `ls` gives you, the rest of the convention still works.
- **`system/agents.md`** isn't in the standard set above — add it (or omit it) based on whether your project will have ongoing agent / automation work worth tracking.
- **Cadence of `last_reviewed:` updates** is a judgment call. For docs that age slowly (BIOS update guide), every 6–12 months is fine. For high-churn docs (current container roster), you might bump it whenever you ship.
- **Single-person vs team:** the conventions are designed for solo work but scale to small teams. For larger teams, you'd add review processes, ownership, and probably a more formal status flow — but the file shapes stay useful.

---

## 12. Credits

This structure was developed by [@carlosboeing](https://github.com/carlosboeing).

Free to adopt, adapt, ignore. If it works for you, use it. If parts don't fit your project, drop them. The principle that matters is "single source of truth for any given question, with conventions cheap enough to actually follow."
