#!/usr/bin/env bash
# Claude Code PostToolUse hook (Write|Edit): validate YAML frontmatter relationship
# paths (related, supersedes, superseded_by) in modified Markdown files.
# Reads the hook JSON payload on stdin; exits 2 with stderr feedback when any
# relationship path does not resolve relative to the file's own directory, so the
# model fixes the path in the same turn.
# Fast path: non-.md files and .md files without relationship keys exit 0 in milliseconds.
# Canonical source: carlosboeing/agentic-toolkit (hooks/validate-frontmatter/validate-frontmatter.sh).

set -u

payload=$(cat)
file=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)

[ -n "$file" ] || exit 0
case "$file" in *.md) ;; *) exit 0 ;; esac
[ -f "$file" ] || exit 0

# Fast exit if byte 0 is not a frontmatter fence or no relationship key appears in the first 60 lines.
head -n 1 "$file" 2>/dev/null | tr -d '\r' | grep -qx -- '---' || exit 0
head -n 60 "$file" 2>/dev/null | grep -qE '^(related|supersedes|superseded_by)[[:space:]]*:' || exit 0

file_dir=$(cd "$(dirname "$file")" 2>/dev/null && pwd -P) || exit 0

targets=$(awk '
  function clean(s) {
    sub(/(^|[ \t]+)#.*$/, "", s)
    gsub(/^[ \t]+|[ \t]+$/, "", s)
    if ((s ~ /^".*"$/) || (s ~ /^'\''.*'\''$/)) s = substr(s, 2, length(s) - 2)
    gsub(/^[ \t]+|[ \t]+$/, "", s)
    return s
  }
  { sub(/\r$/, "") }
  NR == 1 && $0 != "---" { exit }
  NR == 1 { next }
  $0 == "---" { exit }
  /^(related|supersedes|superseded_by)[ \t]*:/ {
    key = $0
    sub(/[ \t]*:.*$/, "", key)
    in_list = 1
    rest = $0
    sub(/^[^:]+:[ \t]*/, "", rest)
    rest = clean(rest)
    if (rest ~ /^\[.*\]$/) {
      inner = substr(rest, 2, length(rest) - 2)
      n = split(inner, parts, ",")
      for (i = 1; i <= n; i++) {
        v = clean(parts[i])
        if (v != "") printf "%d\t%s\t%s\n", NR, key, v
      }
      in_list = 0
    } else if (rest != "") {
      printf "%d\t%s\t%s\n", NR, key, rest
      in_list = 0
    }
    next
  }
  in_list && /^[ \t]+-[ \t]+/ {
    item = $0
    sub(/^[ \t]+-[ \t]+/, "", item)
    v = clean(item)
    if (v != "") printf "%d\t%s\t%s\n", NR, key, v
    next
  }
  in_list && /^[ \t]*($|#)/ { next }
  in_list { in_list = 0 }
' "$file")

[ -n "$targets" ] || exit 0

_suggest_relative() { # _suggest_relative <clean_target> -> prints suggested relative path if found
  local clean="$1" base cand
  command -v python3 >/dev/null 2>&1 || return 0
  for base in "$file_dir/.." "$file_dir/../.."; do
    cand="$base/$clean"
    if [ -e "$cand" ]; then
      python3 -c 'import os,sys; print(os.path.relpath(os.path.realpath(sys.argv[1]), os.path.realpath(sys.argv[2])))' "$cand" "$file_dir" 2>/dev/null
      return 0
    fi
  done
}

fail=0
while IFS=$'\t' read -r lno key target; do
  [ -n "$target" ] || continue
  case "$target" in
    http://*|https://*|mailto:*|file://*|'#'*|*'<''>'*|*'<'*'>'*) continue ;;
  esac
  clean="${target%%#*}"
  clean="${clean%%\?*}"
  clean="${clean%/}"
  [ -n "$clean" ] || continue
  case "$clean" in
    /*)
      echo "Frontmatter relationship path error in $file (line $lno, $key: $target): path must be relative to the file's directory, not absolute." >&2
      fail=1
      continue ;;
  esac
  if [ ! -e "$file_dir/$clean" ]; then
    suggestion=$(_suggest_relative "$clean")
    if [ -n "$suggestion" ]; then
      echo "Frontmatter relationship path in $file (line $lno, $key: $target) does not resolve from $file_dir. Replace '$target' with '$suggestion' (paths must be relative to the file's own directory, matching Markdown body links)." >&2
    else
      echo "Frontmatter relationship path in $file (line $lno, $key: $target) does not resolve from $file_dir. Write paths in related, supersedes and superseded_by relative to the file's own directory." >&2
    fi
    fail=1
  fi
done <<EOF_TARGETS
$targets
EOF_TARGETS

[ "$fail" -eq 0 ] || exit 2
exit 0
