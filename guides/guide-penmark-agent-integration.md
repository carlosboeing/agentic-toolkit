---
title: Penmark agent integration
type: guide
scope: [penmark, markdown-review, skills, harness-parity]
authors:
  - "Carlos Boeing"
  - "gpt-5 (codex)"
last_reviewed: 2026-07-23
related:
  - guide-harness-plugin-parity.md
  - guide-cross-harness-project-instructions.md
---

# Penmark agent integration

Use the `penmark-comments` skill when an agent is explicitly asked to review, audit, critique, or comment on a writable local Markdown file. That request activates the skill even when direct or project instructions require read-only work, no file changes, or chat-only findings. The skill adds validated Penmark v1 findings only when mutation is allowed. It is a global user preference, not a project-template requirement.

## Behavior and precedence

The default applies only to explicit review-like work on a writable local `.md` target. It selects the skill; it does not by itself authorize mutation. When writing is allowed, the skill adds findings at the relevant passage, preserves existing Penmark bytes, leaves reviewed prose unchanged, and does not commit.

Precedence is highest first:

1. Direct user instruction
2. Project instruction
3. Global Penmark default
4. Skill mechanics

`Do not modify files`, `read-only`, and similar phrases refuse changes to the work, not to the review. They no longer route findings to chat on their own — the skill reviews the document, then asks once whether the findings should also go into the file, and remembers the answer. Only an explicit refusal of the comments themselves (`don't add comments`, `no penmark`, `findings in chat only`) skips that question. Summaries, explanations, and extraction tasks do not activate the skill unless Penmark is explicitly requested. Pull-request reviews and general code reviews do not activate the skill. With multiple documents, write only to the primary reviewed target; source and comparison documents stay unchanged.

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

The global instruction stays small and selects the skill. `SKILL.md` first selects the read-only or writer branch, then supplies the read, validate, anchor, atomic-write, and revalidate workflow when writing is allowed. The bundled contract is a pinned writer subset; Penmark's upstream format specification remains normative.

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

For each harness, use disposable files and verify the matrix below. Capture direct, harness-visible skill-activation evidence for every writable, read-only, and chat-only review scenario; do not infer activation from a valid comment or a correct chat response. Capture direct evidence that the skill did not activate for summary and a Markdown-containing general code review.

| Scenario | Expected result | Required evidence |
|---|---|---|
| Writable Markdown review | Valid comments in the primary file | Direct activation evidence, validator result, and mutation diff |
| Read-only Markdown review | Findings in chat; every file byte-identical | Direct activation evidence, chat response, and before/after hashes |
| Chat-only Markdown review | Findings in chat; every file byte-identical | Direct activation evidence, chat response, and before/after hashes |
| Summary | Summary response; target byte-identical | Direct absence-of-activation evidence and before/after hashes |
| Markdown-containing general code review | Code-review response; changed Markdown target byte-identical | Direct absence-of-activation evidence, terminal trace, and complete-tree manifests |

For a multi-source review, verify that only the primary document changes. Compare before/after SHA-256 values and validate the changed primary document.

A positive activation result requires either a native skill-invocation event or a trace-visible read/load of `penmark-comments/SKILL.md`. An agent announcement that it activated the skill is supporting evidence only. A non-activation result requires a complete trace from a harness that exposes the relevant trace and no native invocation or read/load event; if that trace is unavailable, record the result as incomplete rather than pass.

## Evidence audit — 2026-07-22

The forward-test is intentionally incomplete. The results below distinguish completed behavioral evidence from execution blockers; deferred rows are not passes.

| Harness | Version | Installed path observed | Verified results | Deferred evidence |
|---|---:|---|---|---|
| Claude Code | 2.1.217 | `~/.claude/skills/penmark-comments` | Skill link resolved | Positive, negative, and multi-source runs blocked by session quota |
| Codex CLI | 0.145.0 | `~/.agents/skills/penmark-comments` | Two positive runs validated by bundled validator and Penmark parser; read-only target byte-identical; multi-source changed only primary and validated | Summary run left the target byte-identical but stalled before a final response; remaining matrix deferred |
| Antigravity (`agy`) | 1.1.5 | `~/.agents/skills/penmark-comments` shared with Codex in this audit | Correct noninteractive invocation form verified | Positive, negative, and multi-source runs stalled during file search; no behavioral pass recorded |

See the [evaluation report](../docs/4-reviews/2026-07-22-penmark-skill-evaluation.md) for commands, hashes, parser assertions, and rerun requirements.

## Activation-guard evidence — 2026-07-26

The [activation-guard evaluation](../docs/4-reviews/2026-07-26-penmark-read-only-activation-evaluation.md) completed Codex 0.145.0's five-boundary matrix, including a Markdown-containing general code review; Claude Code 2.1.220 and Agy 1.1.7 completed read-only activation cases. Cursor's global instruction loading is structurally verified through its `AGENTS.md` symlink, while Cursor Penmark skill discovery and runtime behavior remain unverified. The durable negative Codex event streams are retained with that evaluation.

## Manual cross-harness verification runbook

> **Superseded as the default (2026-07-27).** This full matrix documents the 2026-07-26 activation-guard exercise and remains valid as reference. It is no longer the standard for routine changes: per the [consent gate design](../docs/2-design/2026-07-27-penmark-comment-consent-gate-design.md), routine changes verify activation only — four probes on one harness — because the gate and the disclosure summary make every other failure mode visible on first use. Run this full matrix only for high-risk changes, or when focused probes reveal harness-specific differences.

The 2026-07-23 release is shipped with the remaining Task 6 cross-harness evidence explicitly deferred. Completing the outstanding rows below and recording the results in the [evaluation report](../docs/4-reviews/2026-07-22-penmark-skill-evaluation.md) completes that deferred Task 6 evidence; it is not a prerequisite for using the released skill.

The existing evidence already covers two Codex positive runs, its read-only override, and its multi-source run. Preserve those historical behavioral facts, but do not infer the newly required trace evidence from them. Run the full matrix below in fresh sessions and record direct activation or non-activation evidence for every row.

| Harness | Scenarios to run in a fresh session |
|---|---|
| Claude Code | Writable positive, chat-only, summary, Markdown-containing general code review, multi-source |
| Agy | Writable positive, chat-only, summary, Markdown-containing general code review, multi-source |

### 1. Prepare a disposable test directory

Run from the resources repository. This setup deliberately keeps every test artifact outside both repositories.

```bash
resources_repo="$PWD"
run_dir="$(mktemp -d -t penmark-task6.XXXXXX)"
cd "$run_dir"
mkdir -p "$run_dir/evidence"
cp "$resources_repo/skills/penmark-comments/tests/fixtures/behavioral-review-target.md" review-target.md
cp review-target.md pristine.md
cat > reference-a.md <<'EOF'
The charge is written before the order.
EOF
cat > reference-b.md <<'EOF'
The order is written before the charge.
EOF
```

All captured stdout, JSONL traces, harness logs, and manifests belong under the scenario evidence directory. That directory is the only allowed output path. The snapshot helper below records the rest of the complete disposable tree: every relative path and type, SHA-256 for regular files, and symlink target. Paths and targets are hex-encoded. It intentionally does not capture permissions, ownership, timestamps, ACLs, or extended attributes. Snapshot only while no test process is modifying the tree. It requires `perl` and `shasum`; the completion assertions require `jq`.

```bash
set -o pipefail
capture_tree_manifest() {
  local snapshot_name="$1"
  local snapshot_output snapshot_paths_tmp snapshot_manifest_tmp
  local snapshot_path snapshot_relative snapshot_path_hex snapshot_target_hex
  local snapshot_sha_line snapshot_sha
  local snapshot_rc=0

  case "$snapshot_name" in
    ""|*/*)
      printf 'Manifest name must be one filename: %s\n' "$snapshot_name" >&2
      return 1
      ;;
  esac

  case "$scenario_evidence_dir" in
    /*) ;;
    *)
      printf 'Scenario evidence directory must be absolute: %s\n' "$scenario_evidence_dir" >&2
      return 1
      ;;
  esac
  mkdir -p "$scenario_evidence_dir" || return 1

  snapshot_output="$scenario_evidence_dir/$snapshot_name"
  snapshot_paths_tmp="$(mktemp "$scenario_evidence_dir/.snapshot-paths.XXXXXX")" || return 1
  snapshot_manifest_tmp="$(mktemp "$scenario_evidence_dir/.snapshot-manifest.XXXXXX")" || {
    rm -f "$snapshot_paths_tmp"
    return 1
  }

  if [ "$scenario_evidence_dir" = "$scenario_dir/evidence" ]; then
    set -- . -path './evidence' -prune -o ! -path . -print0
  else
    set -- . ! -path . -print0
  fi
  if ! find "$@" |
      LC_ALL=C perl -0ne 'push @paths, $_; END { print sort @paths }' \
      >"$snapshot_paths_tmp"; then
    rm -f "$snapshot_paths_tmp" "$snapshot_manifest_tmp"
    return 1
  fi

  while IFS= read -r -d '' snapshot_path; do
    snapshot_relative="${snapshot_path#./}"
    if ! snapshot_path_hex="$(perl -e 'print unpack("H*", $ARGV[0])' "$snapshot_relative")"; then
      snapshot_rc=1; break
    fi
    if [ -L "$snapshot_path" ]; then
      if ! snapshot_target_hex="$(perl -e 'my $target = readlink($ARGV[0]); exit 1 unless defined $target; print unpack("H*", $target);' "$snapshot_path")"; then
        snapshot_rc=1; break
      fi
      printf 'L\t%s\t-\t%s\n' "$snapshot_path_hex" "$snapshot_target_hex" >>"$snapshot_manifest_tmp" || { snapshot_rc=1; break; }
    elif [ -f "$snapshot_path" ]; then
      if ! snapshot_sha_line="$(shasum -a 256 "$snapshot_path")"; then snapshot_rc=1; break; fi
      snapshot_sha="${snapshot_sha_line%% *}"
      printf 'F\t%s\t%s\t-\n' "$snapshot_path_hex" "$snapshot_sha" >>"$snapshot_manifest_tmp" || { snapshot_rc=1; break; }
    elif [ -d "$snapshot_path" ]; then
      printf 'D\t%s\t-\t-\n' "$snapshot_path_hex" >>"$snapshot_manifest_tmp" || { snapshot_rc=1; break; }
    elif [ -e "$snapshot_path" ]; then
      printf 'O\t%s\t-\t-\n' "$snapshot_path_hex" >>"$snapshot_manifest_tmp" || { snapshot_rc=1; break; }
    else
      printf 'Path disappeared during snapshot: %s\n' "$snapshot_relative" >&2
      snapshot_rc=1; break
    fi
  done <"$snapshot_paths_tmp"

  rm -f "$snapshot_paths_tmp"
  if [ "$snapshot_rc" -ne 0 ]; then rm -f "$snapshot_manifest_tmp"; return "$snapshot_rc"; fi
  if ! mv "$snapshot_manifest_tmp" "$snapshot_output"; then rm -f "$snapshot_manifest_tmp"; return 1; fi
}

assert_only_allowed_tree_change() {
  local allowed_relative="$1"
  local before_manifest="$2"
  local after_manifest="$3"
  local allowed_hex before_tmp after_tmp assertion_rc=0
  local before_path_count before_regular_count after_path_count after_regular_count
  local before_sha after_sha

  if ! allowed_hex="$(perl -e 'print unpack("H*", $ARGV[0])' "$allowed_relative")"; then return 1; fi
  if ! before_path_count="$(ALLOWED_HEX="$allowed_hex" perl -F'\t' -ane '$count++ if $F[1] eq $ENV{ALLOWED_HEX}; END { print $count + 0 }' "$before_manifest")"; then return 1; fi
  if ! before_regular_count="$(ALLOWED_HEX="$allowed_hex" perl -F'\t' -ane '$count++ if $F[0] eq "F" && $F[1] eq $ENV{ALLOWED_HEX}; END { print $count + 0 }' "$before_manifest")"; then return 1; fi
  if [ "$before_path_count" -ne 1 ] || [ "$before_regular_count" -ne 1 ]; then
    printf 'Allowed path must appear exactly once as a regular-file F row before mutation: %s\n' "$allowed_relative" >&2
    return 1
  fi
  if ! after_path_count="$(ALLOWED_HEX="$allowed_hex" perl -F'\t' -ane '$count++ if $F[1] eq $ENV{ALLOWED_HEX}; END { print $count + 0 }' "$after_manifest")"; then return 1; fi
  if ! after_regular_count="$(ALLOWED_HEX="$allowed_hex" perl -F'\t' -ane '$count++ if $F[0] eq "F" && $F[1] eq $ENV{ALLOWED_HEX}; END { print $count + 0 }' "$after_manifest")"; then return 1; fi
  if [ "$after_path_count" -ne 1 ] || [ "$after_regular_count" -ne 1 ]; then
    printf 'Allowed path must appear exactly once as a regular-file F row after mutation: %s\n' "$allowed_relative" >&2
    return 1
  fi
  if ! before_sha="$(ALLOWED_HEX="$allowed_hex" perl -F'\t' -ane 'print $F[2] if $F[0] eq "F" && $F[1] eq $ENV{ALLOWED_HEX}' "$before_manifest")"; then return 1; fi
  if ! after_sha="$(ALLOWED_HEX="$allowed_hex" perl -F'\t' -ane 'print $F[2] if $F[0] eq "F" && $F[1] eq $ENV{ALLOWED_HEX}' "$after_manifest")"; then return 1; fi
  if [[ ! "$before_sha" =~ ^[0-9a-f]{64}$ ]] || [[ ! "$after_sha" =~ ^[0-9a-f]{64}$ ]]; then
    printf 'Allowed path lacks a valid SHA-256 row: %s\n' "$allowed_relative" >&2
    return 1
  fi
  if [ "$before_sha" = "$after_sha" ]; then
    printf 'Allowed path did not change: %s (%s)\n' "$allowed_relative" "$before_sha" >&2
    return 1
  fi
  before_tmp="$(mktemp "$scenario_evidence_dir/.allowed-before.XXXXXX")" || return 1
  after_tmp="$(mktemp "$scenario_evidence_dir/.allowed-after.XXXXXX")" || { rm -f "$before_tmp"; return 1; }
  if ! ALLOWED_HEX="$allowed_hex" perl -F'\t' -ane 'print unless $F[1] eq $ENV{ALLOWED_HEX}' "$before_manifest" >"$before_tmp"; then assertion_rc=1; fi
  if [ "$assertion_rc" -eq 0 ] && ! ALLOWED_HEX="$allowed_hex" perl -F'\t' -ane 'print unless $F[1] eq $ENV{ALLOWED_HEX}' "$after_manifest" >"$after_tmp"; then assertion_rc=1; fi
  if [ "$assertion_rc" -eq 0 ] && ! diff -u "$before_tmp" "$after_tmp"; then assertion_rc=1; fi
  rm -f "$before_tmp" "$after_tmp"
  return "$assertion_rc"
}

validate_positive_penmark() {
  local primary_file="$1"
  local validator_output comment_count
  local validator_evidence="$scenario_evidence_dir/$harness-$scenario.validator.txt"

  if ! validator_output="$(node "$resources_repo/skills/penmark-comments/scripts/validate-penmark-comments.mjs" "$primary_file")"; then
    printf 'Bundled validator failed for %s\n' "$primary_file" >&2
    return 1
  fi
  if ! printf '%s\n' "$validator_output" >"$validator_evidence"; then
    printf 'Could not record bundled validator output: %s\n' "$validator_evidence" >&2
    return 1
  fi
  if ! comment_count="$(printf '%s\n' "$validator_output" | perl -ne 'print "$1\n" if /:\s*([0-9]+)\s+comments\s*$/')"; then
    printf 'Could not parse bundled validator output for %s\n' "$primary_file" >&2
    return 1
  fi
  if [[ ! "$comment_count" =~ ^[0-9]+$ ]] || [ "$comment_count" -le 0 ]; then
    printf 'Bundled validator reported no positive comment count for %s: %s\n' "$primary_file" "${comment_count:-missing}" >&2
    return 1
  fi
}
```

Before each read-only, chat-only, or summary scenario, reset the Markdown fixture:

```bash
cp pristine.md review-target.md
```

For the Markdown-containing general-code-review boundary, create a disposable Git repository with one tracked baseline and one uncommitted changed Markdown document:

```bash
code_review_dir="$run_dir/markdown-code-review"
mkdir "$code_review_dir"
git -C "$code_review_dir" init
cp "$resources_repo/skills/penmark-comments/tests/fixtures/markdown-code-review-baseline.md" "$code_review_dir/design.md"
git -C "$code_review_dir" add design.md
git -C "$code_review_dir" -c user.name='Carlos Boeing' -c user.email='carlos@example.invalid' commit -m 'docs: establish design baseline'
cp "$resources_repo/skills/penmark-comments/tests/fixtures/markdown-code-review-changed.md" "$code_review_dir/design.md"
if git -C "$code_review_dir" diff --quiet -- design.md; then exit 1; fi
```

### 2. Use the exact prompts

None of these trigger-boundary prompts names the skill or the Penmark format.

```bash
positive_prompt='Review review-target.md for design defects. Do not search the web and do not commit.'
readonly_prompt='Review review-target.md for design defects, but do not modify any files. Return the findings in chat.'
chatonly_prompt='Review review-target.md for design defects. Return the findings in chat only and leave every file unchanged.'
summary_prompt='Summarize review-target.md in three bullets.'
code_review_prompt='Review the current uncommitted changes as a code review. Return findings in chat and do not modify files.'
multi_prompt='Review primary.md against reference-a.md and reference-b.md for design defects. Add every finding to primary.md. Do not modify either reference and do not commit.'
```

### 3. Run each harness in a fresh session

Set `harness` to `claude`, `codex`, or `agy`; set `scenario` to `positive`, `readonly`, `chatonly`, `summary`, or `code-review`; and assign the corresponding prompt. For a writable positive scenario, reset `review-target.md` and capture a complete-tree manifest before allowing its one changed path. For every no-write, chat-only, summary, or Markdown-containing code-review scenario, reset the relevant target and capture the complete-tree manifest before running. Writable, read-only, and chat-only reviews require activation evidence; summary and Markdown-containing code review require non-activation evidence.

```bash
harness=codex
scenario=positive
prompt="$positive_prompt"
cp pristine.md review-target.md
```

For a no-write, read-only, chat-only, or summary scenario, use `cp pristine.md review-target.md`. For the code-review boundary, use the committed-baseline and changed-Markdown setup above.

Set the scenario context in this standalone block before invoking a runner. The writable scenario names are exactly `positive` and `multi-source`; every other scenario keeps Codex read-only. Run this block again whenever `scenario` changes:

```bash
scenario_dir="$run_dir"
scenario_evidence_dir="$run_dir/evidence"
if [ "$scenario" = code-review ]; then
  scenario_dir="$code_review_dir"
  scenario_evidence_dir="$run_dir/evidence/markdown-code-review"
  case "$scenario_evidence_dir" in
    "$scenario_dir"/*)
      printf 'Code-review evidence must be outside its Git repository: %s\n' "$scenario_evidence_dir" >&2
      exit 1
      ;;
  esac
fi
mkdir -p "$scenario_evidence_dir"
codex_sandbox=read-only
case "$scenario" in
  positive|multi-source) codex_sandbox=workspace-write ;;
esac
```

The runner block starts by invoking the manifest helper from `"$scenario_dir"`. For default scenarios it prunes the in-tree `./evidence`; for the Markdown-containing code review it records the complete Git repository while writing evidence to the external `"$run_dir/evidence/markdown-code-review"` directory. Do not run a scenario until its complete before manifest is stored in `"$scenario_evidence_dir"`. Each harness must use `"$scenario_dir"`, `"$scenario_evidence_dir"`, and `"$codex_sandbox"`.

```bash
set -o pipefail
(cd "$scenario_dir" && capture_tree_manifest "before-$harness-$scenario.manifest")
if [ "$scenario" = code-review ]; then
  code_review_status="$(git -C "$code_review_dir" status --short --untracked-files=all)"
  if [ "$code_review_status" != ' M design.md' ]; then
    printf 'Unexpected Markdown code-review repository status:\n%s\n' "$code_review_status" >&2
    exit 1
  fi
fi
assert_codex_complete() {
  jq -e -s '
    length > 0
    and ([.[] | select(.type == "thread.started")] | length) == 1
    and ([.[] | select(.type == "turn.started")] | length) == 1
    and ([.[] | select(.type == "turn.completed")] | length) == 1
    and ([.[] | select(.type == "turn.failed" or .type == "error")] | length) == 0
    and (last | .type == "turn.completed")
  ' "$1" >/dev/null
}
assert_claude_complete() {
  jq -e -s '
    length > 0
    and ([.[] | select(.type == "result")] | length) == 1
    and (
      last
      | .type == "result"
        and .subtype == "success"
        and .is_error == false
        and .stop_reason == "end_turn"
        and (.session_id | type == "string" and length > 0)
        and (.result | type == "string" and length > 0)
    )
  ' "$1" >/dev/null
}
assert_agy_terminal_response() {
  jq -e -s '
    length > 0
    and (
      last
      | .source == "MODEL"
        and .type == "PLANNER_RESPONSE"
        and .status == "DONE"
        and (.content | type == "string" and length > 0)
        and ((.tool_calls // []) | length == 0)
    )
  ' "$1" >/dev/null
}

run_claude_trace() {
  (cd "$scenario_dir" && rtk proxy claude -p --output-format stream-json --verbose --no-session-persistence --permission-mode acceptEdits --allowedTools=Read,Edit,Write,Bash,Skill "$prompt") 2>"$scenario_evidence_dir/$harness-$scenario.stderr" |
    tee "$scenario_evidence_dir/$harness-$scenario.jsonl"
}
run_codex_trace() {
  rtk proxy codex exec --json --ephemeral --skip-git-repo-check -s "$codex_sandbox" -C "$scenario_dir" "$prompt" 2>"$scenario_evidence_dir/$harness-$scenario.stderr" |
    tee "$scenario_evidence_dir/$harness-$scenario.jsonl"
}
run_agy_trace() {
  (cd "$scenario_dir" && rtk proxy -- agy --dangerously-skip-permissions --add-dir "$scenario_dir" --print-timeout 9m --log-file "$scenario_evidence_dir/$harness-$scenario.log" -p "$prompt") 2>"$scenario_evidence_dir/$harness-$scenario.stderr" |
    tee "$scenario_evidence_dir/$harness-$scenario.out"
}

run_selected_harness() {
  case "$harness" in
    claude)
      if ! run_claude_trace; then printf 'Claude process or evidence pipeline failed\n' >&2; exit 1; fi
      if ! assert_claude_complete "$scenario_evidence_dir/$harness-$scenario.jsonl"; then printf 'Claude trace lacks a terminal success result\n' >&2; exit 1; fi
      ;;
    codex)
      if ! run_codex_trace; then printf 'Codex process or evidence pipeline failed\n' >&2; exit 1; fi
      if ! assert_codex_complete "$scenario_evidence_dir/$harness-$scenario.jsonl"; then printf 'Codex trace lacks terminal turn completion\n' >&2; exit 1; fi
      ;;
    agy)
      if ! run_agy_trace; then printf 'Agy process timed out, exited abnormally, or evidence writing failed\n' >&2; exit 1; fi
      ;;
    *)
      printf 'Unknown harness: %s\n' "$harness" >&2
      exit 1
      ;;
  esac
}
if ! run_selected_harness; then
  printf 'Selected harness did not complete\n' >&2
  exit 1
fi
```

Use the branch that matches `$harness`; do not run more than one branch for one scenario. After every fresh Agy `-p` command and its `tee` pipeline have exited, copy the full transcript into the scenario's evidence directory:

```bash
agy_log="$scenario_evidence_dir/$harness-$scenario.log"
conversation_ids="$(rtk proxy sed -nE 's/^.*Created conversation ([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/\1/p' "$agy_log")"
conversation_count="$(printf '%s\n' "$conversation_ids" | rtk proxy awk 'NF { count++ } END { print count + 0 }')"
if [ "$conversation_count" -ne 1 ]; then
  printf 'Expected exactly one Agy conversation UUID in scenario log %s, found %s\n' "$agy_log" "$conversation_count" >&2
  exit 1
fi
conversation_id="$conversation_ids"
agy_transcript="$HOME/.gemini/antigravity-cli/brain/$conversation_id/.system_generated/logs/transcript_full.jsonl"
if [ ! -s "$agy_transcript" ]; then
  printf 'Missing or empty Agy brain transcript: %s\n' "$agy_transcript" >&2
  exit 1
fi
evidence_transcript="$scenario_evidence_dir/$harness-$scenario.transcript_full.jsonl"
rtk proxy cp "$agy_transcript" "$evidence_transcript"
if [ ! -s "$evidence_transcript" ]; then
  printf 'Missing or empty copied Agy evidence transcript: %s\n' "$evidence_transcript" >&2
  exit 1
fi
if ! assert_agy_terminal_response "$evidence_transcript"; then
  printf 'Agy transcript lacks a terminal planner response\n' >&2
  exit 1
fi
```

Use a unique Agy log for every scenario and select exactly one UUID from it. Never select the newest brain directory by timestamp. Run only fresh conversations, not resumed ones, and wait for the Agy process and its pipeline to exit before copying the transcript. The required `PLANNER_RESPONSE` / `DONE` record is the strongest inspected Agy 1.1.7 completion shape, not a documented CLI sentinel; earlier `RUNNING` records are allowed, and this assertion never overrides process exit status. A timeout, abnormal exit, missing transcript, malformed JSONL, or partial trace is incomplete evidence, not a pass. For the multi-source scenario, prepare and run it as follows:

```bash
scenario=multi-source
scenario_dir="$run_dir"
scenario_evidence_dir="$scenario_dir/evidence"
mkdir -p "$scenario_evidence_dir"
codex_sandbox=workspace-write
cp pristine.md primary.md
(cd "$scenario_dir" && capture_tree_manifest "before-$harness-multi-source.manifest")
prompt="$multi_prompt"
```

Run the matching controlled harness branch with `scenario=multi-source` and `prompt="$multi_prompt"`:

```bash
if ! run_selected_harness; then
  printf 'Selected harness did not complete\n' >&2
  exit 1
fi
```

Keep the working directory at `"$run_dir"` and replace `review-target.md` with `primary.md` only through the prompt. If `$harness` is `agy`, immediately run the Agy transcript-copy and terminal-response assertion block above before validation. Do not run a Git command as part of these reviews.

### 4. Validate the outcome

For every positive or multi-source run, the reviewed primary file must contain one or more comments, pass both parsers, preserve existing prose except for Penmark insertions, and contain no commit. For read-only or chat-only runs, every path in the disposable tree must be unchanged and the final response must contain the requested findings. For summary and Markdown-containing code-review runs, every path in the disposable tree must be unchanged and the final response must contain the requested output. The scenario evidence directory is the only output allowlist. Hashes prove mutation results, not whether the skill activated; retain the direct harness-visible activation or non-activation evidence for that distinction. For a multi-source run, only `primary.md` may change.

After a read-only, chat-only, summary, or Markdown-containing code review, capture and compare a second complete-tree manifest. A diff means an input was added, removed, type-changed, retargeted, or content-changed, and the scenario fails:

```bash
(cd "$scenario_dir" && capture_tree_manifest "after-$harness-$scenario.manifest")
if ! diff -u "$scenario_evidence_dir/before-$harness-$scenario.manifest" "$scenario_evidence_dir/after-$harness-$scenario.manifest"; then
  printf 'Disposable-tree mutation detected\n' >&2
  exit 1
fi
```

After a positive run, assert that every path except `review-target.md` is unchanged, then inspect the allowed file. After a multi-source run, do the same with `primary.md` as the only allowed file:

```bash
(cd "$scenario_dir" && capture_tree_manifest "after-$harness-positive.manifest")
if ! (cd "$scenario_dir" && assert_only_allowed_tree_change review-target.md "$scenario_evidence_dir/before-$harness-positive.manifest" "$scenario_evidence_dir/after-$harness-positive.manifest"); then
  printf 'Unexpected disposable-tree mutation outside review-target.md\n' >&2
  exit 1
fi
if ! validate_positive_penmark "$run_dir/review-target.md"; then
  exit 1
fi
diff -u "$run_dir/pristine.md" "$run_dir/review-target.md"

(cd "$scenario_dir" && capture_tree_manifest "after-$harness-multi-source.manifest")
if ! (cd "$scenario_dir" && assert_only_allowed_tree_change primary.md "$scenario_evidence_dir/before-$harness-multi-source.manifest" "$scenario_evidence_dir/after-$harness-multi-source.manifest"); then
  printf 'Unexpected disposable-tree mutation outside primary.md\n' >&2
  exit 1
fi
if ! validate_positive_penmark "$run_dir/primary.md"; then
  exit 1
fi
diff -u "$run_dir/pristine.md" "$run_dir/primary.md"
```

Inspect the complete named evidence for native skill events and `SKILL.md` reads or loads. A positive requires a native event attributed to `penmark-comments` or a trace-visible read/load of `penmark-comments/SKILL.md`; an announcement in the response does not qualify. For a negative result, inspect the complete trace from a harness that exposes it and confirm there is no such event or read/load. For Agy, search only the copied `transcript_full.jsonl`, not its ordinary log or stdout. If the harness cannot provide a complete trace, record the result as incomplete.

```bash
case "$harness" in
  claude|codex) trace_file="$scenario_evidence_dir/$harness-$scenario.jsonl" ;;
  agy) trace_file="$scenario_evidence_dir/$harness-$scenario.transcript_full.jsonl" ;;
esac
if [ ! -s "$trace_file" ]; then
  printf 'Missing or empty complete trace: %s\n' "$trace_file" >&2
  exit 1
fi
rg -ni -C 3 'penmark-comments/SKILL\.md|"(type|event_type|kind)"\s*:\s*"[^"]*skill[^"]*"' "$trace_file"
rg -ni -C 3 'penmark-comments' "$trace_file"
```

`validate_positive_penmark` records the bundled validator output, extracts its reported integer comment count, and fails before a pass can be recorded unless that count is greater than zero.

After a writable positive run, compare `review-target.md` with its pristine copy:

```bash
shasum -a 256 "$run_dir/review-target.md"
diff -u "$run_dir/pristine.md" "$run_dir/review-target.md"
```

Only after the multi-source setup has created `primary.md`, compare that primary and its references:

```bash
shasum -a 256 "$run_dir/primary.md" "$run_dir/reference-a.md" "$run_dir/reference-b.md"
diff -u "$run_dir/pristine.md" "$run_dir/primary.md"
```

When the pinned local Penmark checkout is available, run its production parser for every mutated primary file. Substitute the tested file path for `"$run_dir/review-target.md"` as needed:

```bash
(cd ~/Projects/penmark && PENMARK_TEST_FILE="$run_dir/review-target.md" npx tsx -e 'import { readFileSync } from "node:fs"; import { parseDoc } from "./src/core/comments/parser.ts"; const doc = parseDoc(readFileSync(process.env.PENMARK_TEST_FILE, "utf8")); const ok = doc.corruption.length === 0 && doc.reviewCount <= 1 && doc.review?.atEof === true && doc.entries.length > 0 && doc.anchors.size === doc.entries.length; console.log(JSON.stringify({ anchors: doc.anchors.size, entries: doc.entries.length, reviewCount: doc.reviewCount, atEof: doc.review?.atEof, corruption: doc.corruption.length })); if (!ok) process.exit(1);')
```

For a writable or multi-source positive, the assertion must report zero corruption, at most one review block at EOF, more than zero entries, and a 1:1 anchor/entry count. If the production parser cannot be run, record that as incomplete evidence rather than a pass.

### 5. Record and close the deferred evidence

Append one row per run to the evaluation report's cross-harness smoke-test table: date, harness/version, installed skill path, scenario, exact terminal response, direct activation or non-activation evidence, before/after SHA-256 values, validator result, production-parser result, and whether only the allowed file changed. Attach or retain the named scenario evidence files until the report has the relevant detail.

Mark a row `pass` only when every expected outcome above is met. Record a timeout, quota limit, missing response, parser failure, or unexpected file change as a blocker without changing the skill speculatively. When all outstanding rows pass, replace the report's deferred status with completed Task 6 evidence and update this guide's audit table and `last_reviewed` date.

## Failure handling and rollback

| Condition | Required behavior |
|---|---|
| Existing data is invalid or uses an unknown version | Do not mutate; report validator diagnostics. |
| A safe span anchor is impossible | Use a block or range anchor. |
| Validation fails after writing | Repair only comments written in this operation; if unsafe, remove only those additions. |
| Skill is missing | Return findings in chat; do not invent or rediscover the format. |
| The target cannot be written | Return findings in chat and state the limitation. |

To disable automatic activation, remove the global instruction section. A direct read-only or no-write instruction does not disable activation and does not by itself choose the output surface; it reaches the consent gate. Deleting `~/.config/penmark-comments/config.json` restores the gate after "Yes, and stop asking" was used. Removing the machine-local symlink disables discovery for that harness; it does not alter reviewed documents.

## Format upgrades

The writer contract is pinned to an upstream Penmark commit. For a new format version:

1. Read the upstream normative specification and identify the writer-facing changes.
2. Update the pinned contract, validator, fixtures, and skill as one compatible change.
3. Run the validator suite, production-parser check when available, and the writable, read-only, chat-only, summary, code-review, and multi-source harness scenarios.
4. Preserve existing documents; never silently migrate their comments.

## See also

- [Penmark Comments README](../skills/penmark-comments/README.md)
- [Harness plugin and skill parity](guide-harness-plugin-parity.md)
- [Cross-harness project instructions](guide-cross-harness-project-instructions.md)
