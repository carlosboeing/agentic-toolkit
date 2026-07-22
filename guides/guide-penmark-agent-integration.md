---
title: Penmark agent integration
type: guide
scope: [penmark, markdown-review, skills, harness-parity]
last_reviewed: 2026-07-23
related:
  - guide-harness-plugin-parity.md
  - guide-cross-harness-project-instructions.md
---

# Penmark agent integration

Use the `penmark-comments` skill when an agent is explicitly asked to review, audit, critique, or comment on a writable local Markdown file. The skill adds validated Penmark v1 findings in the reviewed file. It is a global user preference, not a project-template requirement.

## Behavior and precedence

The default applies only to explicit review-like work on a writable local `.md` target. It adds findings at the relevant passage, preserves existing Penmark bytes, leaves reviewed prose unchanged, and does not commit.

Precedence is highest first:

1. Direct user instruction
2. Project instruction
3. Global Penmark default
4. Skill mechanics

`Do not modify files`, `read-only`, and `return findings in chat` override the default. Summaries, explanations, and extraction tasks do not create comments. With multiple documents, write only to the primary reviewed target; source and comparison documents stay read-only.

## Components

```text
Canonical global instruction
        ↓
penmark-comments skill
        ├── pinned Penmark v1 writer contract
        └── structural validator
        ↓
Reviewed Markdown document with one EOF review block
```

The global instruction stays small and selects the skill. `SKILL.md` supplies the read, validate, anchor, atomic-write, and revalidate workflow. The bundled contract is a pinned writer subset; Penmark's upstream format specification remains normative.

## Install and verify

For a development clone, run:

```bash
./skills/sync-skills.sh
```

It links the whole bundle, where the corresponding harness is installed:

| Harness | Skill directory |
|---|---|
| Claude Code | `~/.claude/skills/penmark-comments` |
| Codex | `~/.agents/skills/penmark-comments` |
| Agy | `~/.gemini/config/skills/penmark-comments` |

The script does not overwrite a real directory. A standalone installation must copy the complete `penmark-comments/` bundle, including `references/` and `scripts/`. Do not create an Agy slash-menu link unless normal skill discovery proves it necessary.

Verify the links and bundle before use:

```bash
readlink ~/.claude/skills/penmark-comments
readlink ~/.agents/skills/penmark-comments
readlink ~/.gemini/config/skills/penmark-comments
```

## Validate and smoke test

Run the bundled structural checks from the repository root:

```bash
node --test skills/penmark-comments/scripts/validate-penmark-comments.test.mjs
node skills/penmark-comments/scripts/validate-penmark-comments.mjs path/to/reviewed.md
```

When a local Penmark checkout is available, also parse the result with Penmark's production parser. The bundle must remain usable without that checkout.

For each harness, use disposable files and verify three cases:

1. A review of a writable Markdown file creates valid comments.
2. The same request with a read-only override leaves the file byte-identical and returns findings in chat.
3. A summary leaves the file byte-identical and does not invoke comment writing.

For a multi-source review, verify that only the primary document changes. Compare before/after SHA-256 values and validate the changed primary document.

## Evidence audit — 2026-07-22

The forward-test is intentionally incomplete. The results below distinguish completed behavioral evidence from execution blockers; deferred rows are not passes.

| Harness | Version | Installed path observed | Verified results | Deferred evidence |
|---|---:|---|---|---|
| Claude Code | 2.1.217 | `~/.claude/skills/penmark-comments` | Skill link resolved | Positive, negative, and multi-source runs blocked by session quota |
| Codex CLI | 0.145.0 | `~/.agents/skills/penmark-comments` | Two positive runs validated by bundled validator and Penmark parser; read-only target byte-identical; multi-source changed only primary and validated | Summary run left the target byte-identical but stalled before a final response; remaining matrix deferred |
| Antigravity (`agy`) | 1.1.5 | `~/.agents/skills/penmark-comments` shared with Codex in this audit | Correct noninteractive invocation form verified | Positive, negative, and multi-source runs stalled during file search; no behavioral pass recorded |

See the [evaluation report](../docs/4-reviews/2026-07-22-penmark-skill-evaluation.md) for commands, hashes, parser assertions, and rerun requirements.

## Manual cross-harness verification runbook

The 2026-07-23 release is shipped with the remaining Task 6 cross-harness evidence explicitly deferred. Completing the outstanding rows below and recording the results in the [evaluation report](../docs/4-reviews/2026-07-22-penmark-skill-evaluation.md) completes that deferred Task 6 evidence; it is not a prerequisite for using the released skill.

The existing evidence already covers two Codex positive runs, its read-only override, and its multi-source run. Run this outstanding matrix in fresh sessions: Claude Code — two positive runs, read-only override, summary, multi-source; Codex — summary; Agy — positive, read-only override, summary, multi-source. This brings the evidence to five successful positive runs, six completed negative runs, and three multi-source runs.

### 1. Prepare a disposable test directory

Run from the resources repository. This setup deliberately keeps every test artifact outside both repositories.

```bash
resources_repo="$PWD"
run_dir="$(mktemp -d -t penmark-task6.XXXXXX)"
cd "$run_dir"
cat > review-target.md <<'EOF'
# Checkout protocol

The checkout service writes an order and then charges the card. If charging fails, the caller retries the whole request.

## Recovery

Operators delete incomplete orders manually. The design does not define an idempotency key, concurrency behavior, or how a retry distinguishes an incomplete order from a completed one.
EOF
cp review-target.md pristine.md
cat > reference-a.md <<'EOF'
The charge is written before the order.
EOF
cat > reference-b.md <<'EOF'
The order is written before the charge.
EOF
shasum -a 256 review-target.md reference-a.md reference-b.md > before.sha256
```

Before each single-target scenario, reset the fixture and capture its hash:

```bash
cp pristine.md review-target.md
shasum -a 256 review-target.md > before-review-target.sha256
```

### 2. Use the exact prompts

Do not name the skill or supply Penmark grammar in these prompts.

```bash
positive_prompt='Review review-target.md for design defects. Add every finding as Penmark inline comments in that file. Do not search the web and do not commit. Return only the number of comments added.'
readonly_prompt='Review review-target.md for design defects, but do not modify any files. Return the findings in chat.'
summary_prompt='Summarize review-target.md in three bullets.'
multi_prompt='Review primary.md against reference-a.md and reference-b.md. Add all findings as inline review comments to the document being reviewed. Do not modify either reference and do not commit.'
```

### 3. Run each harness in a fresh session

For a positive, read-only, or summary scenario, run the selected command from `"$run_dir"` with the corresponding prompt variable. Capture the complete terminal response in a harness/scenario-named file for the evaluation report.

```bash
rtk proxy claude -p --no-session-persistence --permission-mode acceptEdits --allowedTools "Read,Edit,Write,Bash" "$positive_prompt" | tee claude-positive.out
rtk proxy codex exec --ephemeral --skip-git-repo-check -s workspace-write -C "$run_dir" "$positive_prompt" | tee codex-positive.out
(cd "$run_dir" && rtk proxy -- agy --dangerously-skip-permissions --print-timeout 9m -p "$positive_prompt") | tee agy-positive.out
```

Substitute `readonly_prompt` or `summary_prompt` for `positive_prompt` in the selected command. For the multi-source scenario, prepare and run it as follows:

```bash
cp pristine.md primary.md
shasum -a 256 primary.md reference-a.md reference-b.md > before-multi.sha256
rtk proxy codex exec --ephemeral --skip-git-repo-check -s workspace-write -C "$run_dir" "$multi_prompt" | tee codex-multi.out
```

For Claude Code or Agy, use their command above with `multi_prompt`; keep the working directory at `"$run_dir"` and replace `review-target.md` with `primary.md` only through the prompt. Do not run a Git command as part of these reviews.

### 4. Validate the outcome

For every positive or multi-source run, the reviewed primary file must contain one or more comments, pass both parsers, preserve existing prose except for Penmark insertions, and contain no commit. For a read-only or summary run, the target must be byte-identical and the final response must contain the requested findings or summary. For a multi-source run, only `primary.md` may change.

Run the bundle validator from the resources repository against each mutated primary file:

```bash
node "$resources_repo/skills/penmark-comments/scripts/validate-penmark-comments.mjs" "$run_dir/review-target.md"
node "$resources_repo/skills/penmark-comments/scripts/validate-penmark-comments.mjs" "$run_dir/primary.md"
```

Compare hashes and inspect the diff after every scenario:

```bash
shasum -a 256 "$run_dir/review-target.md"
diff -u "$run_dir/pristine.md" "$run_dir/review-target.md"
shasum -a 256 "$run_dir/primary.md" "$run_dir/reference-a.md" "$run_dir/reference-b.md"
diff -u "$run_dir/pristine.md" "$run_dir/primary.md"
```

When the pinned local Penmark checkout is available, run its production parser for every mutated primary file. Substitute the tested file path for `"$run_dir/review-target.md"` as needed:

```bash
(cd ~/Projects/penmark && PENMARK_TEST_FILE="$run_dir/review-target.md" npx tsx -e 'import { readFileSync } from "node:fs"; import { parseDoc } from "./src/core/comments/parser.ts"; const doc = parseDoc(readFileSync(process.env.PENMARK_TEST_FILE, "utf8")); const ok = doc.corruption.length === 0 && doc.reviewCount <= 1 && doc.review?.atEof === true && doc.anchors.size === doc.entries.length; console.log(JSON.stringify({ anchors: doc.anchors.size, entries: doc.entries.length, reviewCount: doc.reviewCount, atEof: doc.review?.atEof, corruption: doc.corruption.length })); if (!ok) process.exit(1);')
```

The assertion must report zero corruption, at most one review block at EOF, and a 1:1 anchor/entry count. If the production parser cannot be run, record that as incomplete evidence rather than a pass.

### 5. Record and close the deferred evidence

Append one row per run to the evaluation report's cross-harness smoke-test table: date, harness/version, installed skill path, scenario, exact terminal response, before/after SHA-256 values, validator result, production-parser result, and whether only the allowed file changed. Attach or retain the captured `*.out` output until the report has the relevant detail.

Mark a row `pass` only when every expected outcome above is met. Record a timeout, quota limit, missing response, parser failure, or unexpected file change as a blocker without changing the skill speculatively. When all outstanding rows pass, replace the report's deferred status with completed Task 6 evidence and update this guide's audit table and `last_reviewed` date.

## Failure handling and rollback

| Condition | Required behavior |
|---|---|
| Existing data is invalid or uses an unknown version | Do not mutate; report validator diagnostics. |
| A safe span anchor is impossible | Use a block or range anchor. |
| Validation fails after writing | Repair only comments written in this operation; if unsafe, remove only those additions. |
| Skill is missing | Return findings in chat; do not invent or rediscover the format. |
| The target cannot be written | Return findings in chat and state the limitation. |

To disable the default, remove the global instruction section or issue a direct read-only/chat-only instruction for the request. Removing the machine-local symlink disables discovery for that harness; it does not alter reviewed documents.

## Format upgrades

The writer contract is pinned to an upstream Penmark commit. For a new format version:

1. Read the upstream normative specification and identify the writer-facing changes.
2. Update the pinned contract, validator, fixtures, and skill as one compatible change.
3. Run the validator suite, production-parser check when available, and all three harness smoke cases.
4. Preserve existing documents; never silently migrate their comments.

## See also

- [Penmark Comments README](../skills/penmark-comments/README.md)
- [Harness plugin and skill parity](guide-harness-plugin-parity.md)
- [Cross-harness project instructions](guide-cross-harness-project-instructions.md)
