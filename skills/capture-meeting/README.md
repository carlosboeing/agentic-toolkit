# `/capture-meeting` — Ingest, audit, and file meeting records

A drop-in skill that turn an AI meeting recording (Fathom or other tool) plus manual notes/artifacts into an audited meeting document following the project's conventions, then propagates findings into the project's working memory (ROADMAP/tracker/ADRs).

---

## What it does

When you run `/capture-meeting` (or ask the agent to process meeting notes), it runs a structured ingestion pipeline:

1. **Identify & Gather**: Finds the meeting transcript/summary from Fathom MCP (or other MCP adapters/pastes) and manual notes.
2. **Context Matching**: Evaluates conventions defined in the `<instructions-file>` (e.g. `CLAUDE.md`, `AGENTS.md`) and a glossary file (`comms/glossary.md`).
3. **Draft & Audit**: Integrates the inputs, highlighting conflicts, unrecognized terms, or ambiguous action items.
4. **Review & Save**: Presents the draft and audit findings to the user for verification before saving to the codebase.
5. **Propagate**: Prompts to update the roadmap, issue tracker, or draft ADRs based on the decisions and action items.

## Install

See the [skills catalog README](../README.md#install-any-skill-in-this-directory) for the full options and platform notes. In short:

- **Consume just this skill** — copy (or `curl`) its `SKILL.md` into your harness's skills directory. Best for sharing a single skill.
- **Author across harnesses** — run [`sync-skills.sh`](../sync-skills.sh) to symlink every authored skill from this repo into all your installed harnesses (Claude, Codex, Agy) at once, with zero copy drift.

## Usage examples

```
/capture-meeting today's sync
/capture-meeting "meeting with Mat on equity"
/capture-meeting https://fathom.video/share/123456
```

## Design philosophy

- **Audit Gate**: Transcription AI is lossy and often mishears names. The human user is the final oracle — never bypass the review gate.
- **Notes override Transcript**: Human manual notes are treated as ground truth over machine transcripts when they contradict.
- **Convention-Aware**: Respects existing directory layouts, glossary locations, and instructions files.
