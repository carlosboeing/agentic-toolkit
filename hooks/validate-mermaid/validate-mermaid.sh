#!/usr/bin/env bash
# Claude Code PostToolUse hook (Write|Edit): parse-validate Mermaid blocks in modified Markdown files.
# Reads the hook JSON payload on stdin; exits 2 with stderr feedback when any block fails to parse,
# which Claude Code feeds back to the model so it fixes the diagram before moving on.
# Fast path: non-.md files and .md files without mermaid fences exit 0 in milliseconds.
# Canonical source: carlosboeing/agentic-toolkit (hooks/validate-mermaid.sh).

set -u

payload=$(cat)
file=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)

[ -n "$file" ] || exit 0
case "$file" in *.md) ;; *) exit 0 ;; esac
[ -f "$file" ] || exit 0
grep -q '^[[:space:]]*```mermaid' "$file" || exit 0

# Resolve the validator: global mmdc, else npx fallback (slower, but the hook keeps enforcing).
if command -v mmdc >/dev/null 2>&1; then
  MMDC=(mmdc)
else
  MMDC=(npx -y -p @mermaid-js/mermaid-cli mmdc)
fi

tmpdir=$(mktemp -d) || exit 0
trap 'rm -rf "$tmpdir"' EXIT

# Extract each fenced mermaid block into its own .mmd file, tracking start lines.
awk -v dir="$tmpdir" '
  /^[[:space:]]*```mermaid[[:space:]]*$/ { n++; f=sprintf("%s/block%03d.mmd", dir, n); print NR+1 > sprintf("%s/block%03d.line", dir, n); inb=1; next }
  inb && /^[[:space:]]*```[[:space:]]*$/ { inb=0; next }
  inb { print >> f }
' "$file"

fail=0
for b in "$tmpdir"/block*.mmd; do
  [ -e "$b" ] || break
  if ! "${MMDC[@]}" -i "$b" -o "$b.svg" --quiet >/dev/null 2>"$tmpdir/err"; then
    line=$(cat "${b%.mmd}.line" 2>/dev/null || echo "?")
    echo "Mermaid parse failure in $file (block starting at line $line):" >&2
    grep -vE '^\s*$' "$tmpdir/err" | head -6 >&2
    echo "Fix the block before continuing — common causes: ';' in message/label text (statement separator), leading '+'/'-' in sequence messages, unquoted '()[]{}|' in flowchart labels." >&2
    fail=1
  fi
done

exit $((fail ? 2 : 0))
