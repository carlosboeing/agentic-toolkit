#!/bin/sh
# resume-session-warn.sh: a UserPromptSubmit hook for Claude Code and Codex.
#
# When a resume note names this session, print one line that asks the agent to confirm
# with the user before changing files. Both harnesses add a
# UserPromptSubmit hook's plain output to the agent's context. The hook never blocks:
# every path exits 0, and it prints nothing when there is no note, no jq, or bad input.

command -v jq >/dev/null 2>&1 || exit 0

session_id=$(jq -r '.session_id // empty' 2>/dev/null) || exit 0
[ -n "$session_id" ] || exit 0
case "$session_id" in
  *[!A-Za-z0-9-]*) exit 0 ;;
esac

notes="${XDG_STATE_HOME:-$HOME/.local/state}/resume-session/resumed"
for note in "$notes/claude-$session_id.json" "$notes/codex-$session_id.json"; do
  [ -f "$note" ] || continue
  jq -r '(.resumes[-1] // empty) as $r
    | select($r != null)
    | "This session was resumed in \($r.by_harness // "another harness") at \($r.time_local // $r.time_utc) for the project at \(.project_root). Work done here can conflict with that session. Ask the user to confirm before changing any file in this session."' \
    "$note" 2>/dev/null
  exit 0
done
exit 0
