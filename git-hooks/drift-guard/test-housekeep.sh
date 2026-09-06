#!/usr/bin/env bash
# test-housekeep.sh — scratch-repository assertions for housekeep.
# No test framework exists in this repository, so this script is the harness.
set -uo pipefail

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

_assert() { # _assert <label> <expected-exit> <actual-exit>
  if [ "$2" = "$3" ]; then pass=$((pass+1)); printf '  ok   %s\n' "$1"
  else fail=$((fail+1)); printf '  FAIL %s (expected exit %s, got %s)\n' "$1" "$2" "$3"; fi
}

R="$TMP/a"
git init -q -b main "$R"
git -C "$R" commit -q --allow-empty -m "c0"
mkdir -p "$R/docs/2-design"

# --- valid frontmatter passes ---
cat > "$R/docs/2-design/2026-09-04-good.md" <<'FIXTURE'
---
date: 2026-09-04
title: A good design
type: design
status: draft
authors:
  - "Carlos Boeing"
---
body
FIXTURE
git -C "$R" add -A && git -C "$R" commit -q -m "docs: good"
( cd "$R" && "$HOOK_DIR/housekeep" check --push "main~1" "main" ) >/dev/null 2>&1
_assert "valid frontmatter passes" 0 $?

# --- missing status fails ---
cat > "$R/docs/2-design/2026-09-04-bad.md" <<'FIXTURE'
---
date: 2026-09-04
title: A bad design
type: design
authors:
  - "Carlos Boeing"
---
body
FIXTURE
git -C "$R" add -A && git -C "$R" commit -q -m "docs: bad"
( cd "$R" && "$HOOK_DIR/housekeep" check --push "main~1" "main" ) >/dev/null 2>&1
_assert "missing status fails" 1 $?

# --- status outside the six fails ---
sed -i.bak 's/^type: design$/type: design\nstatus: open/' "$R/docs/2-design/2026-09-04-bad.md"
rm -f "$R/docs/2-design/2026-09-04-bad.md.bak"
git -C "$R" add -A && git -C "$R" commit -q -m "docs: still bad"
( cd "$R" && "$HOOK_DIR/housekeep" check --push "main~1" "main" ) >/dev/null 2>&1
_assert "status outside the six fails" 1 $?

# --- a published doc outside a lifecycle dir is ignored ---
printf '# Usage\n\nno frontmatter here\n' > "$R/docs/usage.md"
git -C "$R" add -A && git -C "$R" commit -q -m "docs: usage"
( cd "$R" && "$HOOK_DIR/housekeep" check --push "main~1" "main" ) >/dev/null 2>&1
_assert "non-lifecycle file is out of scope" 0 $?

# --- pre-push hook refuses invalid push ---
REMOTE="$TMP/remote.git"
git init -q --bare "$REMOTE"
git -C "$R" remote add origin "$REMOTE"
git -C "$R" push -q origin main >/dev/null 2>&1
mkdir -p "$R/scripts/githooks"
cp "$HOOK_DIR/housekeep" "$HOOK_DIR/pre-push" "$R/scripts/githooks/"
chmod +x "$R/scripts/githooks/housekeep" "$R/scripts/githooks/pre-push"
git -C "$R" config core.hooksPath scripts/githooks

cat > "$R/docs/2-design/2026-09-04-bad-push.md" <<'FIXTURE'
---
date: 2026-09-04
title: Bad push
type: design
authors:
  - "Carlos Boeing"
---
body
FIXTURE
git -C "$R" add -A && git -C "$R" commit -q -m "docs: bad push"
git -C "$R" push origin main >/dev/null 2>&1
_assert "pre-push hook refuses invalid push" 1 $?

# --- check B: changelog pairing ---
mkdir -p "$R/src" "$R/.github/workflows"

printf 'shiny\n' > "$R/src/thing.txt"
git -C "$R" add src/thing.txt && git -C "$R" commit -q -m "feat: shiny feature"
( cd "$R" && "$R/scripts/githooks/housekeep" check --push "main~1" "main" ) >/dev/null 2>&1
_assert "feat without changelog passes when marker is absent" 0 $?

touch "$R/scripts/githooks/drift-guard.on"
( cd "$R" && "$R/scripts/githooks/housekeep" check --push "main~1" "main" ) >/dev/null 2>&1
_assert "feat without changelog fails when marker is present" 1 $?

printf 'on: push\n' > "$R/.github/workflows/ci.yml"
git -C "$R" add .github/workflows/ci.yml && git -C "$R" commit -q -m "fix(ci): pin the runner"
( cd "$R" && "$R/scripts/githooks/housekeep" check --push "main~1" "main" ) >/dev/null 2>&1
_assert "infrastructure-only fix is exempt from the changelog check" 0 $?

printf '# Changelog\n' > "$R/CHANGELOG.md"
printf 'shinier\n' >> "$R/src/thing.txt"
git -C "$R" add CHANGELOG.md src/thing.txt && git -C "$R" commit -q -m "feat: shinier feature"
( cd "$R" && "$R/scripts/githooks/housekeep" check --push "main~1" "main" ) >/dev/null 2>&1
_assert "feat with a changelog entry passes when marker is present" 0 $?

# --- check A reads the pushed commit, not the working tree ---
W="$TMP/w"
git init -q -b main "$W"
git -C "$W" commit -q --allow-empty -m c0
mkdir -p "$W/docs/2-design"
printf -- '---\ndate: 2026-09-05\ntitle: T\ntype: design\nauthors:\n  - "C"\n---\nbody\n' > "$W/docs/2-design/x.md"
git -C "$W" add -A && git -C "$W" commit -q -m "docs: missing status"
printf -- '---\ndate: 2026-09-05\ntitle: T\ntype: design\nstatus: draft\nauthors:\n  - "C"\n---\nbody\n' > "$W/docs/2-design/x.md"
( cd "$W" && "$HOOK_DIR/housekeep" check --push "main~1" "main" ) >/dev/null 2>&1
_assert "an uncommitted repair does not hide a bad commit" 1 $?

rm "$W/docs/2-design/x.md"
( cd "$W" && "$HOOK_DIR/housekeep" check --push "main~1" "main" ) >/dev/null 2>&1
_assert "a working-tree deletion does not skip the file" 1 $?

# --- check C resolves a roadmap link against the roadmap's own directory ---
C="$TMP/c"
git init -q -b main "$C"
git -C "$C" commit -q --allow-empty -m c0
mkdir -p "$C/docs/2-design" "$C/docs/adrs" "$C/docs/0-brainstorms"
printf -- '---\ndate: 2026-09-05\ntitle: D\ntype: design\nstatus: draft\nauthors:\n  - "C"\n---\nbody\n' > "$C/docs/2-design/d.md"
printf '# Roadmap\n\n## Recently shipped\n\n- [D](2-design/d.md)\n' > "$C/docs/ROADMAP.md"
git -C "$C" add -A && git -C "$C" commit -q -m "docs: ship D"
( cd "$C" && "$HOOK_DIR/housekeep" check --push "main~1" "main" ) >/dev/null 2>&1
_assert "a Recently shipped link to a draft doc fails" 1 $?

sed -i.bak 's/^status: draft$/status: shipped/' "$C/docs/2-design/d.md"
rm -f "$C/docs/2-design/d.md.bak"
git -C "$C" add -A && git -C "$C" commit -q -m "docs: mark D shipped"
printf '# Roadmap\n\n## Recently shipped\n\n- [D](2-design/d.md)\n- [D again](2-design/d.md)\n' > "$C/docs/ROADMAP.md"
git -C "$C" add -A && git -C "$C" commit -q -m "docs: relist D"
( cd "$C" && "$HOOK_DIR/housekeep" check --push "main~1" "main" ) >/dev/null 2>&1
_assert "a Recently shipped link to a shipped doc passes" 0 $?

printf -- '---\ndate: 2026-09-05\ntitle: B\ntype: brainstorm\nstatus: resolved\nauthors:\n  - "C"\n---\nbody\n' > "$C/docs/0-brainstorms/b.md"
printf '# Roadmap\n\n## Recently shipped\n\n- [B](0-brainstorms/b.md)\n' > "$C/docs/ROADMAP.md"
git -C "$C" add -A && git -C "$C" commit -q -m "docs: ship B"
( cd "$C" && "$HOOK_DIR/housekeep" check --push "main~1" "main" ) >/dev/null 2>&1
_assert "a resolved brainstorm under Recently shipped passes" 0 $?

printf -- '---\ndate: 2026-09-05\ntitle: A\ntype: adr\nstatus: approved\nauthors:\n  - "C"\n---\nbody\n' > "$C/docs/adrs/0001-a.md"
printf '# Roadmap\n\n## Recently shipped\n\n- [A](adrs/0001-a.md)\n' > "$C/docs/ROADMAP.md"
git -C "$C" add -A && git -C "$C" commit -q -m "docs: ship A"
( cd "$C" && "$HOOK_DIR/housekeep" check --push "main~1" "main" ) >/dev/null 2>&1
_assert "an approved ADR under Recently shipped passes" 0 $?

# --- a nested bundle or assets file is out of scope ---
mkdir -p "$R/docs/2-design/assets/x"
printf '# Evidence\n\nno frontmatter\n' > "$R/docs/2-design/assets/x/README.md"
git -C "$R" add docs/2-design/assets/x/README.md && git -C "$R" commit -q -m "docs: evidence"
( cd "$R" && "$HOOK_DIR/housekeep" check --push "main~1" "main" ) >/dev/null 2>&1
_assert "a nested assets file is out of scope" 0 $?

# --- a Go test fixture is infrastructure too ---
mkdir -p "$R/internal/cli/testdata/help"
printf '0.6.0\n' > "$R/internal/cli/testdata/help/version.txt"
git -C "$R" add internal/cli/testdata/help/version.txt && git -C "$R" commit -q -m "fix(cli): update the version golden"
( cd "$R" && "$R/scripts/githooks/housekeep" check --push "main~1" "main" ) >/dev/null 2>&1
_assert "a nested testdata fixture is exempt from the changelog check" 0 $?

# --- cmd_check: what a merge left behind ---
K="$TMP/k"
git init -q -b main "$K"
mkdir -p "$K/docs/2-design" "$K/bin"
git -C "$K" commit -q --allow-empty -m c0

# a stub gh: one merged pull request, branch feat/thing, closing issue 7
cat > "$TMP/gh" <<'STUB'
#!/usr/bin/env bash
printf '{"closingIssuesReferences":[{"number":7}],"headRefName":"feat/thing","state":"MERGED"}\n'
STUB
chmod +x "$TMP/gh"

cat > "$K/docs/2-design/2026-09-06-thing.md" <<'FIXTURE'
---
date: 2026-09-06
title: "The thing"
type: design
status: approved
authors:
  - "Carlos Boeing"
---
body
FIXTURE
cat > "$K/docs/ROADMAP.md" <<'FIXTURE'
# Roadmap

## Next

- Build the thing (#7) — [design](2-design/2026-09-06-thing.md)

## Recently shipped
FIXTURE
git -C "$K" add -A && git -C "$K" commit -q -m "docs: seed"
git -C "$K" branch feat/thing
git -C "$K" tag ORIG_HEAD_MARK
git -C "$K" commit -q --allow-empty -m "feat(thing): build it (#12)"
git -C "$K" update-ref ORIG_HEAD "$(git -C "$K" rev-parse HEAD~1)"

out=$( cd "$K" && HOUSEKEEP_GH="$TMP/gh" "$HOOK_DIR/housekeep" check 2>&1 )
printf '%s' "$out" | grep -q 'branch feat/thing still here'
_assert "cmd_check reports the branch a merged pull request left" 0 $?
printf '%s' "$out" | grep -q 'a Next line names issue 7'
_assert "cmd_check reports a Next line naming a closed issue" 0 $?
printf '%s' "$out" | grep -q 'status is approved'
_assert "cmd_check reports the linked doc that is not shipped" 0 $?
printf '%s' "$out" | grep -q 'housekeep fix'
_assert "cmd_check ends with the command that fixes it" 0 $?
( cd "$K" && HOUSEKEEP_GH="$TMP/gh" "$HOOK_DIR/housekeep" check >/dev/null 2>&1 )
_assert "cmd_check exits 0 even with findings" 0 $?

git -C "$K" branch -D feat/thing >/dev/null 2>&1
out=$( cd "$K" && HOUSEKEEP_GH="$TMP/gh" "$HOOK_DIR/housekeep" check 2>&1 )
printf '%s' "$out" | grep -q 'branch feat/thing still here'
_assert "cmd_check stays quiet once the branch is gone" 1 $?

# --- fix: the guards ---
F="$TMP/f"
git init -q -b main "$F"
git -C "$F" commit -q --allow-empty -m c0
git -C "$F" branch feat/thing
git -C "$F" commit -q --allow-empty -m "feat(thing): build it (#12)"
git -C "$F" update-ref ORIG_HEAD "$(git -C "$F" rev-parse HEAD~1)"

cat > "$TMP/gh-open" <<'STUB'
#!/usr/bin/env bash
printf '{"headRefName":"feat/thing","state":"OPEN"}\n'
STUB
chmod +x "$TMP/gh-open"

out=$( cd "$F" && HOUSEKEEP_GH="$TMP/gh-open" "$HOOK_DIR/housekeep" fix 2>&1 )
git -C "$F" show-ref --verify --quiet refs/heads/feat/thing
_assert "fix keeps the branch when gh does not say MERGED" 0 $?
printf '%s' "$out" | grep -q 'is OPEN, not MERGED'
_assert "fix says why it kept the branch" 0 $?

cat > "$TMP/gh-merged" <<'STUB'
#!/usr/bin/env bash
printf '{"headRefName":"feat/thing","state":"MERGED"}\n'
STUB
chmod +x "$TMP/gh-merged"

git -C "$F" worktree add -q "$TMP/f-wt" feat/thing
printf 'dirty\n' > "$TMP/f-wt/uncommitted.txt"
out=$( cd "$F" && HOUSEKEEP_GH="$TMP/gh-merged" "$HOOK_DIR/housekeep" fix 2>&1 )
git -C "$F" show-ref --verify --quiet refs/heads/feat/thing
_assert "fix keeps the branch while a dirty worktree uses it" 0 $?

rm -f "$TMP/f-wt/uncommitted.txt"
out=$( cd "$F" && HOUSEKEEP_GH="$TMP/gh-merged" "$HOOK_DIR/housekeep" fix 2>&1 )
git -C "$F" show-ref --verify --quiet refs/heads/feat/thing
_assert "fix deletes the merged branch once its worktree is clean" 1 $?
printf '%s' "$out" | grep -q 'removed worktree'
_assert "fix removes the worktree before the branch" 0 $?

grep -q 'push origin --delete\|push --delete\|push .* :refs' "$HOOK_DIR/housekeep"
_assert "fix contains no remote delete, anywhere in the script" 1 $?

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]


