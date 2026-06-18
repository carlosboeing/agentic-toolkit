---
name: capture-meeting
description: Use when the user wants a meeting captured, processed, or filed into the repo — "capture today's meeting", "pull the Fathom recording", "process my meeting with X", "add my meeting notes" — or mentions a meeting transcript, summary, recording, or minutes that should become a document.
---

# Capture Meeting

Turn an AI meeting recording (Fathom or other tool) plus the user's manual notes/artifacts into an audited meeting doc following the current project's conventions, then propagate findings into the project's working memory.

## Core principles

- **The user is the audit oracle.** Transcripts mishear names and conflate entities; only the user can catch this. Never save or commit without the review gate.
- **Manual notes are ground truth.** The user wrote them; the transcript is machine-heard. On conflict, notes win — flag the conflict.
- **Process is generic; context is per-project.** Conventions, glossary, and output paths come from the repo. The pipeline never changes.

## Pipeline

1. **Identify the meeting** — from the user's hint (topic, date, URL). No hint → list recent meetings from the source and ask which.
2. **Gather inputs** — summary + transcript from the source adapter, plus extras: manual notes (file path, pasted text, or image), artifacts presented (slides, docs). If none provided, ask once: "Any manual notes, slides, or docs from this meeting to include?"

   **Ingestion roles** — the three inputs are not equal:
   - *Transcript* = source of truth. Draft the minutes from this. (When too large for context, dispatch a subagent to digest it into: topic timeline, verbatim entity spellings, decisions, action items, figures, key quotes, ambiguities.)
   - *Tool summary* = scaffold only. Borrow its structure and timestamped deep links; never trust its claims — it's a lossy AI pass that mislabels entities and drops topics.
   - *Manual notes* = ground truth override. Beat both on conflict.

   The audit step flags any claim where transcript and tool summary disagree.
3. **Load project context**:
   - Conventions: `<instructions-file>` rules for meeting docs (output dir, filename pattern, frontmatter)
   - Glossary: `comms/glossary.md` or project equivalent
   - The latest existing meeting doc (style consistency)
   - Anything missing → Fallbacks table below
4. **Draft** — merge all inputs into the project's format. Weave extras into the relevant sections; never append them as a blob. **No hard wrap**: one line per paragraph and per list item — let editors soft-wrap.
5. **Audit** — list for the user:
   - Names/entities not in the glossary (suspected mistranscriptions)
   - Conflated entities (e.g. several companies merged under one transcript label)
   - Notes-vs-transcript conflicts (notes win by default)
   - Ambiguous decisions; action items without owners
6. **Review gate** — show the draft + audit flags. Apply the user's corrections. **Write every name/entity correction back to the glossary.** User can add more inputs here → re-draft.
7. **Save** — to the project's convention path.
8. **Propagate** (only into structures that exist): action items → ROADMAP next actions or tracker; open questions → ROADMAP; decisions → offer to draft ADRs.
9. **Commit** — propose a conventional commit (`docs(comms): …`). Commit only after explicit user confirmation.

## Instructions file resolution

To support multiple platforms and harnesses, abstract the project instructions file (e.g., `CLAUDE.md`, `AGENTS.md`, or `GEMINI.md`) as `<instructions-file>`:
- On Claude Code, default to `CLAUDE.md`.
- On agy, Cursor, and Codex, default to `AGENTS.md` (which may be a symlink to `CLAUDE.md` or `GEMINI.md`).
- If a symlink or pointer exists, resolve the target to write/edit directly to the resolved target file.

## Source adapters

Try in order; first available wins:

1. **Fathom MCP** — `list_meetings` / `search_meetings` to find; `get_meeting_summary` + `get_meeting_transcript` to fetch.
2. **Another meeting tool's MCP** — if one is connected.
3. **Pasted or exported transcript** — ask the user; universal fallback.

## Fallbacks

| Missing | Do |
|---|---|
| Fathom MCP / not authenticated | Ask for a pasted or exported transcript |
| Meeting not found from hint | List recent meetings to pick from |
| No meeting-doc conventions in `<instructions-file>` | Use Default format below; ask where to save |
| No glossary | Offer to create one seeded from this meeting, next to the meeting docs |
| No ROADMAP / ADR structure | Skip propagation silently |
| Extras file path doesn't exist | Name the missing path; continue only after the user confirms |

## Default format (when no project conventions exist)

Filename `YYYY-MM-DD-<topic>.md`:

```yaml
---
type: meeting
source: <tool>
participants: []
decisions: false
action-items: false
---
```

Sections: Purpose · Key takeaways · Topics · Decisions · Action items · Open questions.

## Common mistakes

- Saving before the review gate — transcription errors look plausible; the audit needs the user.
- Weaving failure — dumping manual notes/artifacts as an appendix instead of merging into sections.
- Correcting a name in the doc but not the glossary — the next run repeats the same error.
- Auto-committing — never; the user confirms every commit.
- Trusting the transcript over the user's notes when they disagree.
