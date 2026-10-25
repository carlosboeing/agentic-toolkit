#!/usr/bin/env bash
# test-skill-size.sh — fail when a SKILL.md reaches 20,000 bytes.
#
# After compaction, Claude Code re-attaches each skill cut off at 20,000
# characters, so rules past that point are lost for the rest of the session.
#
# Usage: test-skill-size.sh [skills-dir]   (default: the repo's skills/)
set -uo pipefail

LIMIT=20000
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${1:-$TEST_DIR/../skills}"

# Known exceptions, each with its reason. Remove an entry once the skill fits.
exception_reason() {
  case "$1" in
    briefing) echo "pending simplification to Git, GitHub and the Project Map" ;;
    learn) echo "pending removal from sync or disable-model-invocation" ;;
    *) return 1 ;;
  esac
}

fail=0
checked=0
for file in "$SKILLS_DIR"/*/SKILL.md; do
  [ -f "$file" ] || continue
  name="$(basename "$(dirname "$file")")"
  size="$(wc -c <"$file" | tr -d ' ')"
  checked=$((checked + 1))
  if [ "$size" -ge "$LIMIT" ]; then
    if reason="$(exception_reason "$name")"; then
      printf '  skip %s (%s bytes): %s\n' "$name" "$size" "$reason"
    else
      printf '  FAIL %s is %s bytes; the limit is under %s\n' "$file" "$size" "$LIMIT"
      fail=$((fail + 1))
    fi
  fi
done

if [ "$checked" -eq 0 ]; then
  echo "No SKILL.md found under $SKILLS_DIR"
  exit 1
fi
echo "Checked $checked skills, $fail over the limit"
[ "$fail" -eq 0 ]
