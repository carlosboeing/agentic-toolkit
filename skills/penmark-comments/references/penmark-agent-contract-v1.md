# Penmark v1 writer contract

Pinned from `carlosboeing/penmark` commit `0a97d8c2a6b364b21166bc9b5841b071c6f0e25a`: `spec/penmark-format.md` and `AGENTS-GUIDE.md`. This is the self-contained writer subset for agents adding comments. The pinned upstream specification remains normative.

## IDs

Use exactly eight characters from `abcdefghijklmnopqrstuvwxyz234567` (`[a-z2-7]{8}`). Generate 40 random bits and check the result against every existing anchor and entry ID before use.

```bash
rtk node -e 'const {randomBytes}=require("node:crypto");const a="abcdefghijklmnopqrstuvwxyz234567";console.log([...randomBytes(8)].map(v=>a[v&31]).join(""))'
```

## Anchors

```text
<!--pmk:s ID-->safe inline prose<!--/pmk:s ID-->

<!--pmk:b ID-->
whole block on the immediately following line

<!--pmk:r ID o-->
one or more whole blocks
<!--pmk:r ID c-->
```

- Span markers may cross wrapped prose lines but must not cross a Markdown block boundary or split inline-code, emphasis, or link delimiters.
- Use a block anchor before tables, fenced code, frontmatter, link-reference definitions, images, diagrams, or any unsafe inline selection. The marker is alone on its line with no blank line before the target.
- Use a range pair for several complete contiguous blocks. Both halves are alone on their lines.

## Review entries

Keep at most one review block, as the last meaningful file content. Create it for the first comment and omit it when there are no comments. Append new entries without changing or reordering existing entries.

```markdown
This is the <!--pmk:s k7m2q5ax-->commented phrase<!--/pmk:s k7m2q5ax-->.

<!-- pmk:review v1 -->
<!--pmk:c k7m2q5ax
codex (agent) · 2026-07-22 14:30:00 +10:00
> commented phrase

Explain the failure behavior when the dependency times out.
-->
<!-- /pmk:review -->
```


Each entry has: exact ID-only first line, `<author> (agent) · YYYY-MM-DD HH:MM[:SS] ±HH:MM`, zero or more advisory quote lines prefixed by `> `, exactly one blank separator line, and a non-empty prose body. Use the current harness name as author. Escape every literal `--` in quote or body text as `&#45;&#45;`. A v1 writer never emits `re <parent-id>` replies.

## Mutation and preservation

Read the complete target first. Validate existing Penmark data before writing. Add every new anchor and entry in one atomic file edit, without rewriting reviewed prose. Preserve existing marker and entry bytes exactly. If the existing data is corrupt or uses an unknown review version, leave the file untouched and report the validator diagnostics.

After writing, run `node <skill-dir>/scripts/validate-penmark-comments.mjs <target.md>`. Repair only the comments added by the current operation if validation fails. Do not commit unless the user separately requests it.
