---
name: penmark-comments
description: Use when the user asks to review, audit, critique, or comment on a writable local Markdown file, including read-only, no-write, or chat-only reviews, or explicitly asks for Penmark inline comments. Do not use for pull-request reviews or general code reviews.
---

# Penmark Comments

## Core contract

Activate this skill for every explicit review, audit, critique, or comment request targeting a writable local Markdown file, even when direct or project instructions require read-only work, no file changes, or findings in chat. Those instructions override only file mutation. When writing is allowed, put findings at the relevant passages in the primary target. When writing is forbidden, leave every file unchanged and return the same review findings in chat. Summaries, explanations, and extraction tasks do not activate this skill unless the user explicitly requests Penmark. Pull-request reviews and general code reviews do not activate this skill.

## Workflow

1. Read the entire target and identify direct and project constraints before taking any write action.
2. If the request is read-only, no-write, or chat-only, review the target and any source or comparison documents, return findings in chat, and leave every file unchanged. Do not run the writer-only steps below.
3. Otherwise, read `references/penmark-agent-contract-v1.md` and run `node <skill-dir>/scripts/validate-penmark-comments.mjs <target.md>`. If existing Penmark data is invalid or uses an unsupported version, leave the file untouched and report the diagnostics.
4. Review source and comparison documents read-only. Add findings only to the primary reviewed document.
5. Choose anchors using the table below. Generate unique valid IDs, use the current harness name with `(agent)`, use local time with numeric offset, and escape entry text as the contract requires.
6. Preserve existing Penmark marker and entry bytes. Append new entries in finding order inside the single EOF review block.
7. Apply all new anchors and entries in one atomic file mutation. Do not rewrite reviewed prose.
8. Run the validator again. If it fails, repair only the comments added in this operation; otherwise leave pre-existing content unchanged.
9. Do not run Git commands or commit unless separately requested. Report the comment count, target path, and validation result.

## Anchor choice

| Target | Anchor |
|---|---|
| Safe inline prose | Span |
| Table, code, frontmatter, link definition, image, diagram, or unsafe formatting | Block |
| Several complete contiguous blocks | Range |

## Common mistakes

- Skipping this skill because the review is read-only, no-write, or chat-only is an error. Activate the skill, use its read-only branch, and change only the output surface.
- Do not comment in source/reference documents when one primary target is being reviewed.
- Do not put span markers inside Markdown syntax or block internals.
- Do not invent IDs outside lowercase base32 or reuse an existing ID.
- Do not edit or reorder existing entries, emit v2 replies, leave half-pairs, place content after the review block, or write a bare `--` inside an entry.
