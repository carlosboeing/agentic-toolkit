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

# --- shared fixtures: a fetchable origin with a GitHub identity, and an ---
# --- argv-aware gh stub answering bulk list, --head list, and pr view ----
_mkorigin() { # _mkorigin <repo> — origin looks like GitHub but fetches locally
  local r="$1" base
  base="git@github.com:o/$(basename "$r").git"
  git init -q --bare "$r-remote.git"
  git -C "$r" remote add origin "$base"
  git -C "$r" config "url.$r-remote.git.insteadOf" "$base"
  git -C "$r" push -q origin --all 2>/dev/null || true
}

mkdir -p "$TMP/ghx"
cat > "$TMP/ghx/gh" <<'STUB'
#!/usr/bin/env bash
# Fixtures live in $GH_FIX: bulk.json, head-<branch>.json, view-<n>.json.
# Every call is appended to $GH_LOG so tests can assert the -R pin.
GH_LOG="${GH_LOG:-/dev/null}"
GH_FIX="${GH_FIX:-/nonexistent}"
echo "gh $*" >> "$GH_LOG"
if [ "${1:-}" = "pr" ] && [ "${2:-}" = "list" ]; then
  head=""
  prev=""
  for a in "$@"; do
    if [ "$prev" = "--head" ]; then head="$a"; fi
    prev="$a"
  done
  if [ -n "$head" ]; then
    f="$GH_FIX/head-$(printf '%s' "$head" | tr '/' '_').json"
  else
    f="$GH_FIX/bulk.json"
  fi
  if [ -f "$f" ]; then cat "$f"; else printf '[]\n'; fi
elif [ "${1:-}" = "pr" ] && [ "${2:-}" = "view" ]; then
  if [ -f "$GH_FIX/view-$3.sh" ]; then bash "$GH_FIX/view-$3.sh"; fi
  f="$GH_FIX/view-$3.json"
  if [ -f "$f" ]; then cat "$f"; else echo "gh: no such pull request" >&2; exit 1; fi
else
  echo "gh: unexpected call: $*" >&2; exit 1
fi
STUB
chmod +x "$TMP/ghx/gh"
GHX="$TMP/ghx/gh"

# --- fix: the guards ---
F="$TMP/f"
git init -q -b main "$F"
git -C "$F" commit -q --allow-empty -m c0
git -C "$F" checkout -qb feat/thing
git -C "$F" commit -q --allow-empty -m "build the thing"
FH_F="$(git -C "$F" rev-parse HEAD)"
git -C "$F" checkout -q main
git -C "$F" merge -q --squash feat/thing >/dev/null
git -C "$F" commit -q --allow-empty -m "feat(thing): build it (#12)"
FM_F="$(git -C "$F" rev-parse HEAD)"
_mkorigin "$F"

mkdir -p "$TMP/fofix"
cat > "$TMP/fofix/bulk.json" <<FIX
[{"number":12,"state":"OPEN","headRefName":"feat/thing","headRefOid":"$FH_F","baseRefName":"main","mergeCommit":null,"mergedAt":null,"closedAt":null}]
FIX

mkdir -p "$TMP/fmfix"
cat > "$TMP/fmfix/bulk.json" <<FIX
[{"number":12,"state":"MERGED","headRefName":"feat/thing","headRefOid":"$FH_F","baseRefName":"main","mergeCommit":{"oid":"$FM_F"},"mergedAt":"2026-09-16T00:00:00Z","closedAt":"2026-09-16T00:00:00Z"}]
FIX
cat > "$TMP/fmfix/view-12.json" <<FIX
{"state":"MERGED","headRefName":"feat/thing","closingIssuesReferences":[]}
FIX

out=$( cd "$F" && GH_LOG="$TMP/f-open.log" GH_FIX="$TMP/fofix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" fix 2>&1 )
git -C "$F" show-ref --verify --quiet refs/heads/feat/thing
_assert "fix keeps the branch when gh does not say MERGED" 0 $?
printf '%s' "$out" | grep -q 'nothing to do'
_assert "fix reports nothing to do with no removable branch" 0 $?
out=$( cd "$F" && GH_LOG="$TMP/f-opena.log" GH_FIX="$TMP/fofix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" audit 2>&1 )
printf '%s' "$out" | grep -q 'pull request #12 open, kept'
_assert "audit says why the open branch is kept" 0 $?

git -C "$F" worktree add -q "$TMP/f-wt" feat/thing
printf 'dirty\n' > "$TMP/f-wt/uncommitted.txt"
out=$( cd "$F" && GH_LOG="$TMP/f-dirty.log" GH_FIX="$TMP/fmfix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" fix 2>&1 )
git -C "$F" show-ref --verify --quiet refs/heads/feat/thing
_assert "fix keeps the branch while a dirty worktree uses it" 0 $?
out=$( cd "$F" && GH_LOG="$TMP/f-dirtya.log" GH_FIX="$TMP/fmfix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" audit 2>&1 )
printf '%s' "$out" | grep -q 'has uncommitted changes, kept'
_assert "audit names the dirty worktree blocker" 0 $?

rm -f "$TMP/f-wt/uncommitted.txt"
out=$( cd "$F" && GH_LOG="$TMP/f-clean.log" GH_FIX="$TMP/fmfix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" fix 2>&1 )
git -C "$F" show-ref --verify --quiet refs/heads/feat/thing
_assert "fix deletes the merged branch once its worktree is clean" 1 $?
printf '%s' "$out" | grep -q 'removed worktree'
_assert "fix removes the worktree before the branch" 0 $?
[ -d "$TMP/f-wt" ]
_assert "the worktree directory is gone after fix" 1 $?
printf '%s' "$out" | grep -q '^  inventory: '
_assert "fix prints the resulting inventory" 0 $?

grep -q 'push origin --delete\|push --delete\|push .* :refs' "$HOOK_DIR/housekeep"
_assert "fix contains no remote delete, anywhere in the script" 1 $?
grep -q 'worktree remove.*-f' "$HOOK_DIR/housekeep"
_assert "fix never force-removes a worktree, anywhere in the script" 1 $?

# --- check C judges only lines under Recently shipped ---
printf -- '---\ndate: 2026-09-06\ntitle: N\ntype: design\nstatus: in-progress\nauthors:\n  - "C"\n---\nbody\n' > "$C/docs/2-design/n.md"
printf '# Roadmap\n\n## Next actions\n\n- Still going [N](2-design/n.md)\n\n## Recently shipped\n\n- [D](2-design/d.md)\n' > "$C/docs/ROADMAP.md"
git -C "$C" add -A && git -C "$C" commit -q -m "docs: add a Next line"
( cd "$C" && "$HOOK_DIR/housekeep" check --push "main~1" "main" ) >/dev/null 2>&1
_assert "a Next actions line linking an in-progress doc passes" 0 $?

# --- audit: every branch classified, including outside the last pull ---
G="$TMP/g"
git init -q -b main "$G"
git -C "$G" commit -q --allow-empty -m c0
git -C "$G" checkout -qb feat/merged-old
git -C "$G" commit -q --allow-empty -m "old work"
GH_OLD="$(git -C "$G" rev-parse HEAD)"
git -C "$G" checkout -q main
git -C "$G" merge -q --squash feat/merged-old >/dev/null
git -C "$G" commit -q --allow-empty -m "feat(old): ship it (#12)"
GM_OLD="$(git -C "$G" rev-parse HEAD)"
git -C "$G" checkout -qb feat/reused
git -C "$G" commit -q --allow-empty -m "reused work"
GH_RE="$(git -C "$G" rev-parse HEAD)"
git -C "$G" checkout -q main
git -C "$G" merge -q --squash feat/reused >/dev/null
git -C "$G" commit -q --allow-empty -m "feat(reused): ship it (#13)"
GM_RE="$(git -C "$G" rev-parse HEAD)"
git -C "$G" checkout -q feat/reused
git -C "$G" commit -q --allow-empty -m "post-merge work"
git -C "$G" checkout -qb feat/open main
git -C "$G" commit -q --allow-empty -m "open work"
GH_OPEN="$(git -C "$G" rev-parse HEAD)"
git -C "$G" checkout -qb feat/closed main
git -C "$G" commit -q --allow-empty -m "closed work"
GH_CLOSED="$(git -C "$G" rev-parse HEAD)"
git -C "$G" checkout -qb lone/wolf main
git -C "$G" checkout -qb feat/behind-tmp main
git -C "$G" commit -q --allow-empty -m "behind one"
GH_BEHIND_BASE="$(git -C "$G" rev-parse HEAD)"
git -C "$G" commit -q --allow-empty -m "behind two"
GH_BEHIND_HEAD="$(git -C "$G" rev-parse HEAD)"
git -C "$G" checkout -q main
git -C "$G" merge -q --squash feat/behind-tmp >/dev/null
git -C "$G" commit -q --allow-empty -m "feat(behind): ship it (#16)"
GM_BEHIND="$(git -C "$G" rev-parse HEAD)"
git -C "$G" branch -D feat/behind-tmp >/dev/null 2>&1
git -C "$G" branch feat/behind "$GH_BEHIND_BASE"
git -C "$G" checkout -qb integration/x main
git -C "$G" checkout -qb feat/into-int
git -C "$G" commit -q --allow-empty -m "int work"
GH_INT="$(git -C "$G" rev-parse HEAD)"
git -C "$G" checkout -q integration/x
git -C "$G" merge -q --squash feat/into-int >/dev/null
git -C "$G" commit -q --allow-empty -m "feat(int): ship it (#17)"
GM_INT="$(git -C "$G" rev-parse HEAD)"
git -C "$G" checkout -qb feat/gone-dest main
git -C "$G" commit -q --allow-empty -m "dest work"
GH_GONE="$(git -C "$G" rev-parse HEAD)"
git -C "$G" checkout -q main
mkdir -p "$G/docs/2-design"
cat > "$G/docs/2-design/2026-09-06-old.md" <<'FIXTURE'
---
date: 2026-09-06
title: "Old thing"
type: design
status: approved
authors:
  - "Carlos Boeing"
---
body
FIXTURE
cat > "$G/docs/ROADMAP.md" <<'FIXTURE'
# Roadmap

## Next

- Build the old thing (#7) — [design](2-design/2026-09-06-old.md)

## Recently shipped
FIXTURE
git -C "$G" add -A && git -C "$G" commit -q -m "docs: seed roadmap"
_mkorigin "$G"
mkdir -p "$TMP/gfix"
cat > "$TMP/gfix/bulk.json" <<FIX
[{"number":12,"state":"MERGED","headRefName":"feat/merged-old","headRefOid":"$GH_OLD","baseRefName":"main","mergeCommit":{"oid":"$GM_OLD"},"mergedAt":"2026-09-16T00:00:00Z","closedAt":"2026-09-16T00:00:00Z"},{"number":13,"state":"MERGED","headRefName":"feat/reused","headRefOid":"$GH_RE","baseRefName":"main","mergeCommit":{"oid":"$GM_RE"},"mergedAt":"2026-09-16T00:00:00Z","closedAt":"2026-09-16T00:00:00Z"},{"number":14,"state":"OPEN","headRefName":"feat/open","headRefOid":"$GH_OPEN","baseRefName":"main","mergeCommit":null,"mergedAt":null,"closedAt":null},{"number":15,"state":"CLOSED","headRefName":"feat/closed","headRefOid":"$GH_CLOSED","baseRefName":"main","mergeCommit":null,"mergedAt":null,"closedAt":"2026-09-16T00:00:00Z"},{"number":16,"state":"MERGED","headRefName":"feat/behind","headRefOid":"$GH_BEHIND_HEAD","baseRefName":"main","mergeCommit":{"oid":"$GM_BEHIND"},"mergedAt":"2026-09-16T00:00:00Z","closedAt":"2026-09-16T00:00:00Z"},{"number":17,"state":"MERGED","headRefName":"feat/into-int","headRefOid":"$GH_INT","baseRefName":"integration/x","mergeCommit":{"oid":"$GM_INT"},"mergedAt":"2026-09-16T00:00:00Z","closedAt":"2026-09-16T00:00:00Z"},{"number":18,"state":"MERGED","headRefName":"feat/gone-dest","headRefOid":"$GH_GONE","baseRefName":"main","mergeCommit":{"oid":"ffffffffffffffffffffffffffffffffffffffff"},"mergedAt":"2026-09-16T00:00:00Z","closedAt":"2026-09-16T00:00:00Z"}]
FIX
cat > "$TMP/gfix/view-12.json" <<FIX
{"state":"MERGED","headRefName":"feat/merged-old","closingIssuesReferences":[{"number":7}]}
FIX
cat > "$TMP/gfix/view-16.json" <<FIX
{"state":"MERGED","headRefName":"feat/behind","closingIssuesReferences":[]}
FIX
cat > "$TMP/gfix/view-17.json" <<FIX
{"state":"MERGED","headRefName":"feat/into-int","closingIssuesReferences":[]}
FIX
cat > "$TMP/gfix/view-18.json" <<FIX
{"state":"MERGED","headRefName":"feat/gone-dest","closingIssuesReferences":[]}
FIX

out=$( cd "$G" && GH_LOG="$TMP/g.log" GH_FIX="$TMP/gfix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" audit 2>&1 )
_assert "audit exits 0 with findings" 0 $?
printf '%s' "$out" | grep -q 'branch feat/merged-old: pull request #12 merged, safe to remove'
_assert "audit reports a merged branch older than any pull" 0 $?
printf '%s' "$out" | grep -Fq "audit o/g at $G: 10 branches (2 protected), 1 worktrees, 7 pull requests resolved, 0 unresolved"
_assert "audit prints its scan scope and counts" 0 $?
printf '%s' "$out" | grep -q 'branch integration/x:'
_assert "audit never lists a protected branch" 1 $?
printf '%s' "$out" | grep -q 'branch feat/into-int: pull request #17 merged, safe to remove'
_assert "audit reports a branch merged into an integration branch" 0 $?
printf '%s' "$out" | grep -q 'branch feat/reused: commits past pull request #13 (MERGED), kept'
_assert "audit keeps a reused branch with post-merge commits" 0 $?
printf '%s' "$out" | grep -q 'branch feat/open: pull request #14 open, kept'
_assert "audit keeps an open pull request branch" 0 $?
printf '%s' "$out" | grep -q 'branch feat/closed: pull request #15 closed unmerged, kept'
_assert "audit keeps a closed-unmerged branch" 0 $?
printf '%s' "$out" | grep -q 'branch lone/wolf: no pull request found, kept'
_assert "audit keeps a branch with no pull request" 0 $?
grep -q -- '--head lone/wolf' "$TMP/g.log"
_assert "audit falls back to a targeted lookup for unmatched branches" 0 $?
grep '^gh pr' "$TMP/g.log" | grep -v -F -- '-R o/g'
_assert "every gh call carries the -R pin" 1 $?
printf '%s' "$out" | grep -q 'branch feat/behind: pull request #16 merged, local behind its head, safe to remove'
_assert "audit removes a merged branch whose tip is behind" 0 $?
printf '%s' "$out" | grep -q 'branch feat/gone-dest: merged pull request #18, but ffffffffffff is not in main history, kept'
_assert "audit keeps a merge it cannot find in destination history" 0 $?
printf '%s' "$out" | grep -q 'a Next line names issue 7'
_assert "audit reports roadmap drift for old merges too" 0 $?
printf '%s' "$out" | grep -q 'housekeep fix'
_assert "audit ends with the command that fixes it" 0 $?

# --- audit: worktree states block removal ---
WT="$TMP/wt"
git init -q -b main "$WT"
git -C "$WT" commit -q --allow-empty -m c0
printf '*.bin\n' > "$WT/.gitignore"
git -C "$WT" add .gitignore && git -C "$WT" commit -q -m "ignore binaries"
git -C "$WT" checkout -qb feat/wt-merged
git -C "$WT" commit -q --allow-empty -m "wt work"
GH_WT="$(git -C "$WT" rev-parse HEAD)"
git -C "$WT" checkout -q main
git -C "$WT" merge -q --squash feat/wt-merged >/dev/null
git -C "$WT" commit -q --allow-empty -m "feat(wt): ship it (#22)"
GM_WT="$(git -C "$WT" rev-parse HEAD)"
_mkorigin "$WT"
mkdir -p "$TMP/wtfix"
cat > "$TMP/wtfix/bulk.json" <<FIX
[{"number":22,"state":"MERGED","headRefName":"feat/wt-merged","headRefOid":"$GH_WT","baseRefName":"main","mergeCommit":{"oid":"$GM_WT"},"mergedAt":"2026-09-16T00:00:00Z","closedAt":"2026-09-16T00:00:00Z"}]
FIX
cat > "$TMP/wtfix/view-22.json" <<FIX
{"state":"MERGED","headRefName":"feat/wt-merged","closingIssuesReferences":[]}
FIX
git -C "$WT" worktree add -q "$TMP/wt-wt" feat/wt-merged
printf 'BINARY' > "$TMP/wt-wt/app.bin"
out=$( cd "$WT" && GH_LOG="$TMP/wt.log" GH_FIX="$TMP/wtfix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" audit 2>&1 )
printf '%s' "$out" | grep -q 'holds ignored files, kept'
_assert "audit blocks a worktree holding ignored files" 0 $?
printf '%s' "$out" | grep -q 'ignored files (1: app.bin)'
_assert "audit lists the ignored paths" 0 $?
out=$( cd "$WT" && GH_LOG="$TMP/wt-fix.log" GH_FIX="$TMP/wtfix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" fix 2>&1 )
git -C "$WT" show-ref --verify --quiet refs/heads/feat/wt-merged
_assert "fix refuses a worktree holding ignored files" 0 $?

rm -f "$TMP/wt-wt/app.bin"
git -C "$WT" worktree lock --reason "in use" "$TMP/wt-wt"
out=$( cd "$WT" && GH_LOG="$TMP/wt-lock.log" GH_FIX="$TMP/wtfix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" audit 2>&1 )
printf '%s' "$out" | grep -q 'is locked, kept'
_assert "audit blocks a locked worktree" 0 $?
printf '%s' "$out" | grep -q 'locked (in use), kept'
_assert "audit prints the lock reason" 0 $?
git -C "$WT" worktree unlock "$TMP/wt-wt"

git -C "$WT" worktree add -q --detach "$TMP/wt-det" HEAD
out=$( cd "$WT" && GH_LOG="$TMP/wt-det.log" GH_FIX="$TMP/wtfix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" audit 2>&1 )
printf '%s' "$out" | grep -q 'detached HEAD, not managed'
_assert "audit reports a detached worktree without managing it" 0 $?
out=$( cd "$WT" && GH_LOG="$TMP/wt-detf.log" GH_FIX="$TMP/wtfix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" fix 2>&1 )
[ -d "$TMP/wt-det" ]
_assert "fix leaves a detached worktree alone" 0 $?

# --- the main worktree is never removed ---
M="$TMP/m"
git init -q -b main "$M"
git -C "$M" commit -q --allow-empty -m c0
git -C "$M" checkout -qb feat/m
git -C "$M" commit -q --allow-empty -m "m work"
GH_M="$(git -C "$M" rev-parse HEAD)"
git -C "$M" checkout -q main
git -C "$M" merge -q --squash feat/m >/dev/null
git -C "$M" commit -q --allow-empty -m "feat(m): ship it (#23)"
GM_M="$(git -C "$M" rev-parse HEAD)"
_mkorigin "$M"
mkdir -p "$TMP/mfix"
cat > "$TMP/mfix/bulk.json" <<FIX
[{"number":23,"state":"MERGED","headRefName":"feat/m","headRefOid":"$GH_M","baseRefName":"main","mergeCommit":{"oid":"$GM_M"},"mergedAt":"2026-09-16T00:00:00Z","closedAt":"2026-09-16T00:00:00Z"}]
FIX
cat > "$TMP/mfix/view-23.json" <<FIX
{"state":"MERGED","headRefName":"feat/m","closingIssuesReferences":[]}
FIX
git -C "$M" checkout -q feat/m
out=$( cd "$M" && GH_LOG="$TMP/m.log" GH_FIX="$TMP/mfix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" audit 2>&1 )
printf '%s' "$out" | grep -q 'checked out in the main worktree, kept'
_assert "audit keeps a removable branch checked out in the main worktree" 0 $?
out=$( cd "$M" && GH_LOG="$TMP/m-fix.log" GH_FIX="$TMP/mfix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" fix 2>&1 )
git -C "$M" show-ref --verify --quiet refs/heads/feat/m
_assert "fix never deletes the main worktree branch" 0 $?

# --- fix rechecks state immediately before deleting ---
H="$TMP/h"
git init -q -b main "$H"
git -C "$H" commit -q --allow-empty -m c0
git -C "$H" checkout -qb feat/thing
git -C "$H" commit -q --allow-empty -m "build the thing"
FH_H="$(git -C "$H" rev-parse HEAD)"
git -C "$H" checkout -q main
git -C "$H" merge -q --squash feat/thing >/dev/null
git -C "$H" commit -q --allow-empty -m "feat(thing): build it (#12)"
FM_H="$(git -C "$H" rev-parse HEAD)"
_mkorigin "$H"
mkdir -p "$TMP/hfix"
cat > "$TMP/hfix/bulk.json" <<FIX
[{"number":12,"state":"MERGED","headRefName":"feat/thing","headRefOid":"$FH_H","baseRefName":"main","mergeCommit":{"oid":"$FM_H"},"mergedAt":"2026-09-16T00:00:00Z","closedAt":"2026-09-16T00:00:00Z"}]
FIX
cat > "$TMP/hfix/view-12.json" <<FIX
{"state":"OPEN","headRefName":"feat/thing","closingIssuesReferences":[]}
FIX
out=$( cd "$H" && GH_LOG="$TMP/h.log" GH_FIX="$TMP/hfix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" fix 2>&1 )
git -C "$H" show-ref --verify --quiet refs/heads/feat/thing
_assert "fix rechecks pull request state before deleting" 0 $?
printf '%s' "$out" | grep -q 'no longer removable (pull request #12 is OPEN), kept'
_assert "fix says what changed when a branch stops being removable" 0 $?

# --- unreachable GitHub resolves nothing, and that is not clean ---
out=$( cd "$G" && HOUSEKEEP_GH=/bin/false "$HOOK_DIR/housekeep" audit 2>&1 )
_assert "audit exits 0 when GitHub is unreachable" 0 $?
printf '%s' "$out" | grep -q 'unresolved (no answer from GitHub), kept'
_assert "audit marks every branch unresolved, never clean" 0 $?
printf '%s' "$out" | grep -Fq "10 branches (2 protected), 1 worktrees, 0 pull requests resolved, 8 unresolved"
_assert "audit counts the unresolved branches" 0 $?
printf '%s' "$out" | grep -q 'safe to remove'
_assert "nothing is removable without GitHub answers" 1 $?
out=$( cd "$G" && HOUSEKEEP_GH=/bin/false "$HOOK_DIR/housekeep" fix 2>&1 )
git -C "$G" show-ref --verify --quiet refs/heads/feat/merged-old
_assert "fix deletes nothing when GitHub is unreachable" 0 $?

# --- a repository without an origin has no GitHub identity ---
N="$TMP/n"
git init -q -b main "$N"
git -C "$N" commit -q --allow-empty -m c0
git -C "$N" branch feat/nothing
out=$( cd "$N" && GH_LOG="$TMP/n.log" GH_FIX="$TMP/nfix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" audit 2>&1 )
printf '%s' "$out" | grep -q 'no GitHub identity'
_assert "audit says when the repository has no GitHub identity" 0 $?
[ -s "$TMP/n.log" ]
_assert "audit never calls gh without an identity to pin" 1 $?
out=$( cd "$N" && GH_LOG="$TMP/n-fix.log" GH_FIX="$TMP/nfix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" fix 2>&1 )
git -C "$N" show-ref --verify --quiet refs/heads/feat/nothing
_assert "fix deletes nothing without a repository identity" 0 $?

# --- fix deletes nothing when the refresh fetch fails ---
E="$TMP/e"
git init -q -b main "$E"
git -C "$E" commit -q --allow-empty -m c0
git -C "$E" checkout -qb feat/thing
git -C "$E" commit -q --allow-empty -m "build the thing"
FH_E="$(git -C "$E" rev-parse HEAD)"
git -C "$E" checkout -q main
git -C "$E" merge -q --squash feat/thing >/dev/null
git -C "$E" commit -q --allow-empty -m "feat(thing): build it (#12)"
FM_E="$(git -C "$E" rev-parse HEAD)"
git -C "$E" remote add origin "https://github.com/o/e.git"
git -C "$E" config "url.file:///nonexistent-housekeep.insteadOf" "https://github.com/o/e.git"
mkdir -p "$TMP/efix"
cat > "$TMP/efix/bulk.json" <<FIX
[{"number":12,"state":"MERGED","headRefName":"feat/thing","headRefOid":"$FH_E","baseRefName":"main","mergeCommit":{"oid":"$FM_E"},"mergedAt":"2026-09-16T00:00:00Z","closedAt":"2026-09-16T00:00:00Z"}]
FIX
cat > "$TMP/efix/view-12.json" <<FIX
{"state":"MERGED","headRefName":"feat/thing","closingIssuesReferences":[]}
FIX
out=$( cd "$E" && GH_LOG="$TMP/e.log" GH_FIX="$TMP/efix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" fix 2>&1 )
git -C "$E" show-ref --verify --quiet refs/heads/feat/thing
_assert "fix deletes nothing when the refresh fetch fails" 0 $?
printf '%s' "$out" | grep -q 'fetch from origin failed'
_assert "fix says the fetch failed instead of deleting blind" 0 $?

# --- origin schemes parse to the same identity ---
S="$TMP/s"
git init -q -b main "$S"
git -C "$S" commit -q --allow-empty -m c0
git -C "$S" branch feat/s
git -C "$S" remote add origin "ssh://git@github.com/o/s.git"
out=$( cd "$S" && HOUSEKEEP_GH=/bin/false "$HOOK_DIR/housekeep" audit 2>&1 )
printf '%s' "$out" | grep -q 'audit o/s at'
_assert "audit parses ssh-scheme origins" 0 $?

# --- check states its window and points at the audit ---
out=$( cd "$K" && HOUSEKEEP_GH="$TMP/gh" "$HOOK_DIR/housekeep" check 2>&1 )
printf '%s' "$out" | grep -q 'last pull ORIG_HEAD..HEAD'
_assert "check states its window up front" 0 $?
printf '%s' "$out" | grep -q 'full branch inventory: housekeep audit'
_assert "check points at the full inventory" 0 $?
printf '%s' "$out" | grep -q 'could not contact origin; stale-ref state unknown'
_assert "check admits when stale-ref state is unknown" 0 $?
out=$( cd "$N" && HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" check 2>&1 )
printf '%s' "$out" | grep -q 'no ORIG_HEAD; nothing to compare'
_assert "check without ORIG_HEAD points at audit instead of guessing" 0 $?
out=$( cd "$K" && HOUSEKEEP_GH=/bin/false "$HOOK_DIR/housekeep" check 2>&1 )
printf '%s' "$out" | grep -q 'pull request 12: no answer from GitHub, unresolved'
_assert "check marks unanswered pull requests unresolved" 0 $?

# --- audit: prefer exact merged head over ancestry of older PRs ---
RPR="$TMP/rpr"
git init -q -b main "$RPR"
git -C "$RPR" commit -q --allow-empty -m c0
git -C "$RPR" checkout -qb feat/reused-prs
git -C "$RPR" commit -q --allow-empty -m "pr1 work"
RPR_H1="$(git -C "$RPR" rev-parse HEAD)"
git -C "$RPR" checkout -q main
git -C "$RPR" merge -q --squash feat/reused-prs >/dev/null
git -C "$RPR" commit -q --allow-empty -m "ship pr1 (#31)"
RPR_M1="$(git -C "$RPR" rev-parse HEAD)"
git -C "$RPR" checkout -q feat/reused-prs
git -C "$RPR" commit -q --allow-empty -m "pr2 work"
RPR_H2="$(git -C "$RPR" rev-parse HEAD)"
git -C "$RPR" checkout -q main
git -C "$RPR" merge -q --squash feat/reused-prs >/dev/null
git -C "$RPR" commit -q --allow-empty -m "ship pr2 (#32)"
RPR_M2="$(git -C "$RPR" rev-parse HEAD)"
_mkorigin "$RPR"

mkdir -p "$TMP/rprfix"
cat > "$TMP/rprfix/bulk.json" <<FIX
[{"number":31,"state":"MERGED","headRefName":"feat/reused-prs","headRefOid":"$RPR_H1","baseRefName":"main","mergeCommit":{"oid":"$RPR_M1"},"mergedAt":"2026-09-15T00:00:00Z","closedAt":"2026-09-15T00:00:00Z"},{"number":32,"state":"MERGED","headRefName":"feat/reused-prs","headRefOid":"$RPR_H2","baseRefName":"main","mergeCommit":{"oid":"$RPR_M2"},"mergedAt":"2026-09-16T00:00:00Z","closedAt":"2026-09-16T00:00:00Z"}]
FIX
cat > "$TMP/rprfix/view-32.json" <<FIX
{"state":"MERGED","headRefName":"feat/reused-prs","closingIssuesReferences":[]}
FIX
out=$( cd "$RPR" && GH_LOG="$TMP/rpr.log" GH_FIX="$TMP/rprfix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" audit 2>&1 )
printf '%s' "$out" | grep -q 'branch feat/reused-prs: pull request #32 merged, safe to remove'
_assert "audit prefers exact merged head over ancestry of older PRs" 0 $?

# --- local branch behind both merged PR and newer open PR is kept ---
DOP="$TMP/dop"
git init -q -b main "$DOP"
git -C "$DOP" commit -q --allow-empty -m c0
git -C "$DOP" checkout -qb feat/descendant-open
git -C "$DOP" commit -q --allow-empty -m "initial local work"
DOP_T="$(git -C "$DOP" rev-parse HEAD)"

git -C "$DOP" commit -q --allow-empty -m "merged pr1 work"
DOP_H1="$(git -C "$DOP" rev-parse HEAD)"
git -C "$DOP" checkout -q main
git -C "$DOP" merge -q --squash "$DOP_H1" >/dev/null
git -C "$DOP" commit -q --allow-empty -m "ship pr1 (#41)"
DOP_M1="$(git -C "$DOP" rev-parse HEAD)"

git -C "$DOP" checkout -q feat/descendant-open
git -C "$DOP" commit -q --allow-empty -m "open pr2 work"
DOP_H2="$(git -C "$DOP" rev-parse HEAD)"
git -C "$DOP" reset -q --hard "$DOP_T"
git -C "$DOP" checkout -q main
_mkorigin "$DOP"

mkdir -p "$TMP/dopfix"
cat > "$TMP/dopfix/bulk.json" <<FIX
[{"number":41,"state":"MERGED","headRefName":"feat/descendant-open","headRefOid":"$DOP_H1","baseRefName":"main","mergeCommit":{"oid":"$DOP_M1"},"mergedAt":"2026-09-15T00:00:00Z","closedAt":"2026-09-15T00:00:00Z"},{"number":42,"state":"OPEN","headRefName":"feat/descendant-open","headRefOid":"$DOP_H2","baseRefName":"main","mergeCommit":null,"mergedAt":null,"closedAt":null}]
FIX
cat > "$TMP/dopfix/view-41.json" <<FIX
{"state":"MERGED","headRefName":"feat/descendant-open","closingIssuesReferences":[]}
FIX
cat > "$TMP/dopfix/view-42.json" <<FIX
{"state":"OPEN","headRefName":"feat/descendant-open","closingIssuesReferences":[]}
FIX

out=$( cd "$DOP" && GH_LOG="$TMP/dop.log" GH_FIX="$TMP/dopfix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" audit 2>&1 )
printf '%s' "$out" | grep -q 'branch feat/descendant-open: pull request #42 open, kept'
_assert "audit keeps local branch behind both merged and open PRs" 0 $?

out=$( cd "$DOP" && GH_LOG="$TMP/dopf.log" GH_FIX="$TMP/dopfix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" fix 2>&1 )
git -C "$DOP" show-ref --verify --quiet refs/heads/feat/descendant-open
_assert "fix never deletes a branch with an open descendant PR" 0 $?

# --- targeted fallback with multiple PRs: open takes precedence over merged ---
TFB="$TMP/tfb"
git init -q -b main "$TFB"
git -C "$TFB" commit -q --allow-empty -m c0
git -C "$TFB" checkout -qb feat/multi-fallback
git -C "$TFB" commit -q --allow-empty -m "work"
TFB_H="$(git -C "$TFB" rev-parse HEAD)"
git -C "$TFB" checkout -q main
git -C "$TFB" merge -q --squash feat/multi-fallback >/dev/null
git -C "$TFB" commit -q --allow-empty -m "ship old (#21)"
TFB_M="$(git -C "$TFB" rev-parse HEAD)"
_mkorigin "$TFB"

mkdir -p "$TMP/tfbfix"
cat > "$TMP/tfbfix/bulk.json" <<'FIX'
[]
FIX
cat > "$TMP/tfbfix/head-feat_multi-fallback.json" <<FIX
[{"number":22,"state":"OPEN","headRefName":"feat/multi-fallback","headRefOid":"$TFB_H","baseRefName":"main","mergeCommit":null,"mergedAt":null,"closedAt":null},{"number":21,"state":"MERGED","headRefName":"feat/multi-fallback","headRefOid":"$TFB_H","baseRefName":"main","mergeCommit":{"oid":"$TFB_M"},"mergedAt":"2026-09-15T00:00:00Z","closedAt":"2026-09-15T00:00:00Z"}]
FIX
out=$( cd "$TFB" && GH_LOG="$TMP/tfb.log" GH_FIX="$TMP/tfbfix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" audit 2>&1 )
printf '%s' "$out" | grep -q 'branch feat/multi-fallback: pull request #22 open, kept'
_assert "targeted fallback preserves open PR precedence across multiple records" 0 $?

out=$( cd "$TFB" && GH_LOG="$TMP/tfbf.log" GH_FIX="$TMP/tfbfix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" fix 2>&1 )
git -C "$TFB" show-ref --verify --quiet refs/heads/feat/multi-fallback
_assert "targeted fallback never deletes an open-PR branch during fix" 0 $?

# --- fix: large output of ignored files does not break via SIGPIPE ---
LIO="$TMP/lio"
git init -q -b main "$LIO"
git -C "$LIO" commit -q --allow-empty -m c0
printf '*.bin\n' > "$LIO/.gitignore"
git -C "$LIO" add .gitignore && git -C "$LIO" commit -q -m "ignore binaries"
git -C "$LIO" checkout -qb feat/lio-merged
git -C "$LIO" commit -q --allow-empty -m "lio work"
LIO_H="$(git -C "$LIO" rev-parse HEAD)"
git -C "$LIO" checkout -q main
git -C "$LIO" merge -q --squash feat/lio-merged >/dev/null
git -C "$LIO" commit -q --allow-empty -m "ship lio (#55)"
LIO_M="$(git -C "$LIO" rev-parse HEAD)"
_mkorigin "$LIO"

git -C "$LIO" worktree add "$TMP/lio-wt" feat/lio-merged >/dev/null 2>&1

mkdir -p "$TMP/liofix"
cat > "$TMP/liofix/bulk.json" <<FIX
[{"number":55,"state":"MERGED","headRefName":"feat/lio-merged","headRefOid":"$LIO_H","baseRefName":"main","mergeCommit":{"oid":"$LIO_M"},"mergedAt":"2026-09-16T00:00:00Z","closedAt":"2026-09-16T00:00:00Z"}]
FIX
cat > "$TMP/liofix/view-55.json" <<FIX
{"state":"MERGED","headRefName":"feat/lio-merged","closingIssuesReferences":[]}
FIX
cat > "$TMP/liofix/view-55.sh" <<SH
python3 -c 'for i in range(15000): open("'"$TMP/lio-wt"'/f_" + str(i) + ".bin", "w").close()'
SH

out=$( cd "$LIO" && GH_LOG="$TMP/lio-fix.log" GH_FIX="$TMP/liofix" HOUSEKEEP_GH="$GHX" "$HOOK_DIR/housekeep" fix 2>&1 )
printf '%s' "$out" | grep -q 'branch feat/lio-merged no longer removable (worktree holds ignored files), kept'
_assert "fix recheck catches large volume of ignored files without SIGPIPE" 0 $?
[ -d "$TMP/lio-wt" ]
_assert "worktree with large volume of ignored files is preserved" 0 $?
git -C "$LIO" show-ref --verify --quiet refs/heads/feat/lio-merged
_assert "branch with large volume of ignored files is preserved" 0 $?

"$HOOK_DIR/housekeep" bogus >/dev/null 2>&1
_assert "an unknown mode exits 2" 2 $?

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]


