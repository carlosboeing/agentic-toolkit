---
name: penmark-comments
description: Use when the user asks to review, audit, critique, or comment on a writable local Markdown file, or explicitly asks for Penmark inline comments.
---

# Penmark Comments

## Core contract

Put review findings at the relevant passages in the primary writable Markdown target. Direct user and project instructions take precedence. If the user says `do not modify files`, `read-only`, `chat output only`, or equivalent, return findings in chat and do not mutate. Summaries, explanations, and extraction tasks do not create comments.

## Workflow

1. Read the entire target and `references/penmark-agent-contract-v1.md` before writing.
2. Resolve this skill's installed directory and run `node <skill-dir>/scripts/validate-penmark-comments.mjs <target.md>`. If existing Penmark data is invalid or uses an unsupported version, leave the file untouched and report the diagnostics.
3. Review source and comparison documents read-only. Add findings only to the primary reviewed document.
4. Choose anchors using the table below. Generate unique valid IDs, use the current harness name with `(agent)`, use local time with numeric offset, and escape entry text as the contract requires.
5. Preserve existing Penmark marker and entry bytes. Append new entries in finding order inside the single EOF review block.
6. Apply all new anchors and entries in one atomic file mutation. Do not rewrite reviewed prose.
7. Run the validator again. If it fails, repair only the comments added in this operation; otherwise leave pre-existing content unchanged.
8. Do not run Git commands or commit unless separately requested. Report the comment count, target path, and validation result.

## Anchor choice

| Target | Anchor |
|---|---|
| Safe inline prose | Span |
| Table, code, frontmatter, link definition, image, diagram, or unsafe formatting | Block |
| Several complete contiguous blocks | Range |

## Common mistakes

- Do not comment in source/reference documents when one primary target is being reviewed.
- Do not put span markers inside Markdown syntax or block internals.
- Do not invent IDs outside lowercase base32 or reuse an existing ID.
- Do not edit or reorder existing entries, emit v2 replies, leave half-pairs, place content after the review block, or write a bare `--` inside an entry.
