#!/usr/bin/env bash
#
# tests/test-githooks.sh — offline assertions for scripts/githooks/pre-commit.
#
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"
HOOK="$REPO_ROOT/scripts/githooks/pre-commit"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

_assert_eq() { # _assert_eq <label> <expected> <actual>
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
    printf '  ok   %s\n' "$1"
  else
    fail=$((fail + 1))
    printf '  FAIL %s (expected %s, got %s)\n' "$1" "$2" "$3"
  fi
}

# Helper to create and initialize a clean repository
make_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test Runner"
  mkdir -p "$dir/scripts/githooks"
  cp "$HOOK" "$dir/scripts/githooks/pre-commit"
  chmod +x "$dir/scripts/githooks/pre-commit"
  # Initial commit so HEAD exists
  touch "$dir/.gitkeep"
  git -C "$dir" add .gitkeep
  git -C "$dir" commit -q -m "initial commit"
}

# Run hook in repo, returns 'accepted' or 'refused'
run_hook() {
  local dir="$1"
  if ( cd "$dir" && ./scripts/githooks/pre-commit ) >/dev/null 2>&1; then
    printf 'accepted'
  else
    printf 'refused'
  fi
}

echo "=== Testing pre-commit gitlink check ==="
repo_gitlink="$TMP/repo_gitlink"
make_repo "$repo_gitlink"

# 1. Stage a gitlink with mode 160000 at .workbench
mkdir -p "$repo_gitlink/.workbench"
git -C "$repo_gitlink/.workbench" init -q
git -C "$repo_gitlink/.workbench" config user.email "test@example.com"
git -C "$repo_gitlink/.workbench" config user.name "Test Runner"
touch "$repo_gitlink/.workbench/seed"
git -C "$repo_gitlink/.workbench" add seed
git -C "$repo_gitlink/.workbench" commit -q -m "seed"

# Stage the nested repository as a gitlink
git -C "$repo_gitlink" add -f .workbench
_assert_eq "staging .workbench gitlink (mode 160000) is refused" "refused" "$(run_hook "$repo_gitlink")"

# Reset gitlink
git -C "$repo_gitlink" reset -q HEAD .workbench 2>/dev/null || true

echo "=== Testing pre-commit added-line vocabulary scan ==="
repo_vocab="$TMP/repo_vocab"
make_repo "$repo_vocab"

# Helper to test staged file content
test_staged_content() {
  local file="$1"
  local content="$2"
  printf '%s\n' "$content" > "$repo_vocab/$file"
  git -C "$repo_vocab" add "$file"
  local result
  result="$(run_hook "$repo_vocab")"
  git -C "$repo_vocab" reset -q HEAD "$file"
  rm -f "$repo_vocab/$file"
  printf '%s' "$result"
}

# 2. Stage .workbench/2-design/example.md citation
_assert_eq "citing .workbench/2-design/example.md is refused" "refused" \
  "$(test_staged_content "note.md" "See .workbench/2-design/example.md for details.")"

# 3. Stage each remaining denied term
_assert_eq "denied term 'agentic-toolkit-workbench' is refused" "refused" \
  "$(test_staged_content "note.md" "Pushed candidate to agentic-toolkit-workbench remote.")"

_assert_eq "denied term '/Users/' is refused" "refused" \
  "$(test_staged_content "note.md" "Local checkout at /Users/carlos/Projects/repo.")"

_assert_eq "denied term 'hosted service' is refused" "refused" \
  "$(test_staged_content "note.md" "We will offer a hosted service.")"

_assert_eq "denied term 'hosted tier' is refused" "refused" \
  "$(test_staged_content "note.md" "Moving users to the hosted tier.")"

_assert_eq "denied term 'monetize' is refused" "refused" \
  "$(test_staged_content "note.md" "Plan to monetize this feature.")"

_assert_eq "denied term 'monetise' is refused" "refused" \
  "$(test_staged_content "note.md" "How we monetise the product.")"

# 4. Stage vendor price-table line containing pricing, per month and $20 -> accepted
_assert_eq "vendor price-table line with 'pricing', 'per month', '\$20' is accepted" "accepted" \
  "$(test_staged_content "prices.md" "| Claude Pro | Pricing is \$20 per month | Included |")"

# 5. Unstaged forbidden edit does not affect clean staged diff
printf '%s\n' "Clean line for staging" > "$repo_vocab/clean.md"
git -C "$repo_vocab" add "clean.md"
printf '%s\n' "Unstaged leak citing .workbench/notes/secret.md" > "$repo_vocab/unstaged.md"
# unstaged.md is not git added
_assert_eq "clean staged diff is accepted even with unstaged forbidden edits" "accepted" \
  "$(run_hook "$repo_vocab")"
git -C "$repo_vocab" reset -q HEAD "clean.md"
rm -f "$repo_vocab/clean.md" "$repo_vocab/unstaged.md"

echo "=== Testing _skip exemptions ==="

# Test each _skip exemption with forbidden terms:
_assert_eq "CLAUDE.md with forbidden term is exempt" "accepted" \
  "$(test_staged_content "CLAUDE.md" "Working memory: .workbench/ (private)")"

_assert_eq "AGENTS.md with forbidden term is exempt" "accepted" \
  "$(test_staged_content "AGENTS.md" "Working memory: .workbench/ (private)")"

_assert_eq ".gitignore with forbidden term is exempt" "accepted" \
  "$(test_staged_content ".gitignore" ".workbench/")"

mkdir -p "$repo_vocab/custom/githooks"
_assert_eq "custom/githooks/pre-commit with forbidden term is exempt" "accepted" \
  "$(test_staged_content "custom/githooks/pre-commit" "PATTERN='\.workbench'")"

mkdir -p "$repo_vocab/tests"
_assert_eq "tests/test-githooks.sh with forbidden term is exempt" "accepted" \
  "$(test_staged_content "tests/test-githooks.sh" "test .workbench citation")"

mkdir -p "$repo_vocab/git-hooks/private-workbench-guard"
_assert_eq "git-hooks/private-workbench-guard/README.md with forbidden term is exempt" "accepted" \
  "$(test_staged_content "git-hooks/private-workbench-guard/README.md" "Documentation for .workbench guard")"

# 6. Test a non-exempt file alongside an exempt one:
# Both staged together, hook must refuse
printf '%s\n' "Working memory: .workbench/" > "$repo_vocab/CLAUDE.md"
printf '%s\n' "Forbidden term: .workbench/2-design/" > "$repo_vocab/non-exempt.md"
git -C "$repo_vocab" add CLAUDE.md non-exempt.md
_assert_eq "non-exempt file alongside exempt file causes refusal" "refused" \
  "$(run_hook "$repo_vocab")"
git -C "$repo_vocab" reset -q HEAD CLAUDE.md non-exempt.md
rm -f "$repo_vocab/CLAUDE.md" "$repo_vocab/non-exempt.md"

echo ""
echo "test-githooks summary: $pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
