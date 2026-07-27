---
name: penmark-comments
description: Use when the user asks to review, audit, critique, or comment on a writable local Markdown file, including read-only, no-write, or chat-only reviews, or explicitly asks for Penmark inline comments. Do not use for pull-request reviews, or for broad change reviews whose diff contains non-Markdown files.
---

# Penmark Comments

## Core contract

Activate this skill for every explicit review, audit, critique, or comment request targeting a writable local Markdown file. A no-write instruction never suppresses activation.

Review the document first, then decide where the findings go. Adding comments changes the file, so that decision belongs to the user unless they have already made it. Summaries, explanations, and extraction tasks do not activate this skill unless the user explicitly requests Penmark.

## Scope

Resolve what is being reviewed before anything else, in this order:

1. **A named pull request or GitHub review** — never activate, whatever the changed files are. The deliverable is a review on the PR, not comments in local files.
2. **A document the user identified** — by filename ("review `design.md`") or by reference ("review my design", "review the plan", "review the design doc", "audit the spec"). Activate when the resolved target is Markdown, **regardless of what else is uncommitted**.

   When the reference names no file, resolve it before reviewing: check pending changes and recently modified working-memory documents for a matching design, plan, brainstorm, or review. Exactly one plausible candidate — use it and say which one you picked. Two or more — ask which before reviewing. None — say so instead of guessing. This disambiguation question is separate from the consent gate below, and only fires when the reference is genuinely ambiguous.

3. **Broad scope you must discover yourself** — "review my changes", "review the uncommitted work", "review the pending changes". Inspect the changed set. Activate only when every changed file is Markdown. One non-Markdown source file makes it a code review, which this skill leaves alone.

Content decides only in case 3, where the user did not say what to review. Never let discovered scope override a document the user identified — unrelated uncommitted code has no bearing on a review they asked for by name or by reference.

## Workflow

1. Read the entire target and any source or comparison documents. Form the findings. Write nothing yet.
2. Resolve the output surface using the first rule that matches:
   1. The request explicitly asks for inline or Penmark comments — use the file.
   2. The request explicitly refuses them — use chat. Only these count: "don't add comments", "no inline comments", "don't comment on the doc", "no penmark", "don't use penmark-comments", "findings in chat only", "chat-only".
   3. A `penmark-comments: <mode>` line in `CLAUDE.md` or `AGENTS.md` — obey it.
   4. A `mode` value in the config file — obey it.
   5. Otherwise — print the full findings, then run the gate below and obey the answer.
3. Chat surface: print the full findings and leave every file unchanged. Stop.
4. File surface: run the writer steps, then print the summary.

Anything absent from the 2.2 list is ambiguous and reaches the gate. "read-only", "don't modify `<file>`", "leave it unchanged", "don't edit anything", "no changes", and "don't implement" all gate — they refuse changes to the work, not to the review.

## Configuration

Precedence: instruction-file line, then config file, then ask.

- Instruction-file line in `CLAUDE.md` or `AGENTS.md`: `penmark-comments: write`. Also accepts `chat` and `ask`.
- Config file at `$XDG_CONFIG_HOME/penmark-comments/config.json`, defaulting to `~/.config/penmark-comments/config.json`:

```json
{ "mode": "write" }
```

Write the config file only for the "Yes, and stop asking" answer, creating the directory when missing. Never write `chat` from the gate — a standing refusal is the user's own instruction-file line. Never write config into the skill directory: that is shipped, Git-tracked content.

## Gate

Print the full findings first, then ask using the harness question tool: `AskUserQuestion` on Claude Code, `ask_question` on Agy, `request_user_input` on Codex, native input on Cursor.

Every one of these needs an interactive session. When the tool is unavailable for any reason — a headless run such as `claude -p` or `codex exec`, a subagent, or a harness that has none — use the text form below **verbatim**.

> These findings can also go into `<target>` as Penmark inline comments — N markers next to the relevant lines, plus one comment block at the end of the file.
>
> The document's content is preserved exactly as you wrote it. Comments are wrapped around the relevant text, never written over it.
>
> Add them?

| Label | Description |
|---|---|
| Yes, add them | Writes N markers and a comment block into `<target>`. Undo with `git checkout -- <target>`. |
| Yes, and stop asking | Same, and saves the preference to `~/.config/penmark-comments/config.json`. Edit or delete that file to change it back. |
| No, chat only | Leaves `<target>` byte-for-byte unchanged. The findings above are the complete review. |

Substitute the real target path and count. When the target is untracked or dirty, replace the undo sentence with: "The comments are additions — remove them by deleting the marker pairs and the comment block."

### Gate — text form

```
Add these N findings to `<target>` as Penmark inline comments?

The document's content is preserved exactly as you wrote it. Comments are
wrapped around the relevant text, never written over it.

  1. Yes — add them to `<target>`. Undo: `git checkout -- <target>`
  2. Yes, and stop asking — same, and remembers the choice for next time.
  3. No — leave `<target>` unchanged. The findings above are the full review.

Reply 1, 2, or 3.
```

Substitute the real count and path. Never write "the design" or "the doc" where a path belongs — with no interface chrome, that path is the only thing showing what is about to be touched.

This form is already a numbered list of the single question, placed at the end of the reply, so it satisfies a reply-format convention that asks for questions that way. It needs no further compression to comply with one. Keep each option on its own line with its consequence.

## Writer steps

1. Read `references/penmark-agent-contract-v1.md` and run `node <skill-dir>/scripts/validate-penmark-comments.mjs <target.md>`. If existing Penmark data is invalid or uses an unsupported version, leave the file untouched and report the diagnostics.
2. Add findings only to the primary reviewed document. Source and comparison documents stay unchanged.
3. Choose anchors using the rules below. Generate unique valid IDs, use the current harness name with `(agent)`, use local time with numeric offset, and escape entry text as the contract requires.
4. Preserve existing Penmark marker and entry bytes. Append new entries in finding order inside the single EOF review block.
5. Check every anchor before writing. Quote the anchored text in the entry's `> ` line, then read the body against that quote. If the two do not read as a comment on the same passage, move the anchor — never reword the body to fit the anchor you picked. A heading or title anchor is consistent when the body names that wider scope.
6. Apply all new anchors and entries in one atomic file mutation. Do not rewrite the reviewed text.
7. Run the validator again. If it fails, repair only the comments added in this operation.
8. Do not run Git commands or commit unless separately requested.

## Summary

Print after every write, including when no gate was shown:

> Added N comments to `<target>`.
>
> - one terse line per finding, each citing the anchored passage as a short quote plus `<target>:<line>`
>
> The document's content was preserved exactly as you wrote it — the comments are wrapped around the relevant text, not written over it. Validator passed.
> Undo: `git checkout -- <target>`

Quote the anchored passage, not a restatement of the finding. The quote is what lets the reader catch a wrong anchor without opening the document, so it has to be the text the marker actually wraps.

Group findings by theme instead of listing every one when a review is large.

## Anchor choice

Anchor each finding on the passage that would have to change for the finding to be resolved. When a finding says a section's scope is too narrow, the anchor goes inside that section. Topical relatedness is not an anchor — a section that merely governs the same outcome is the wrong target. When the finding's body names a specific section, requirement, or identifier, the anchor sits inside that one unless the finding is explicitly about a mismatch between two of them. Two findings may land in the same section on different blocks; that is expected, not a conflict to avoid.

A finding that fits no passage still needs an anchor, because Penmark has no document-level entry — every comment hangs off a marker. Widen the anchor rather than forcing a passage:

| Finding is about | Anchor |
|---|---|
| A specific claim, requirement, or passage | That passage |
| Something a section should cover but does not, or the section's overall approach | That section's heading |
| The document's framing, structure, or scope as a whole | The document title |

Each row is a fallback only when the row above genuinely does not apply. Test it: if you can name a passage whose change would resolve the finding, the finding is not document-level. Most findings that feel general fail that test. The title is not a home for anything awkward to place.

A heading or title anchor carries no scope of its own, so the body has to state it. Open with "Across the document" or "This section" instead of leaving the reader to infer how far the comment reaches. Wrap the entire heading or title text, never part of it.

Then pick the marker form:

| Target | Anchor |
|---|---|
| Safe inline prose | Span |
| Table, code, frontmatter, link definition, image, diagram, or unsafe formatting | Block |
| Several complete contiguous blocks | Range |

## Common mistakes

- Skipping this skill because the review is read-only, no-write, or chat-only is an error. Activate, review, and let step 2 pick the surface.
- Treating "read-only" or "don't edit anything" as a refusal of comments is an error. Those gate.
- Asking when the user already requested comments, or already stored a preference, is noise.
- Activating for a named pull request or GitHub review is an error, even when every changed file is Markdown. That review belongs on the PR.
- Refusing an identified Markdown target because unrelated code is also uncommitted is an error. An identified target decides on its own.
- Guessing which document "review my design" means when several are plausible. Ask which one, then review.
- Compressing the gate's three options into a sentence to satisfy a reply-format rule. The text form above already complies; squashing it further strips the consequences the user needs to choose.
- Writing the config file for any answer other than "Yes, and stop asking".
- Claiming the file is byte-for-byte unchanged on a write path. Span markers change the line — the guarantee is about wording.
- Using the document title as a home for findings that were merely hard to place. Widening the anchor is for findings with no passage, not for findings you did not locate.
- Anchoring a finding on a section that is merely related to it instead of the section it critiques. A comment whose body faults one requirement must not hang off a different requirement's heading, however closely the two are connected.
- Do not comment in source or reference documents when one primary target is being reviewed.
- Do not put span markers inside Markdown syntax or block internals.
- Do not invent IDs outside lowercase base32 or reuse an existing ID.
- Do not edit or reorder existing entries, emit v2 replies, leave half-pairs, place content after the review block, or write a bare `--` inside an entry.
