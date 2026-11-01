#!/bin/sh
# resume-session-warn.sh: tell an old session that resume-session continued it elsewhere.
#
# Usage: resume-session-warn.sh [plain|grok|antigravity]
#   plain (default)  UserPromptSubmit hook for Claude Code, Codex, and Muse Code, which add
#                    the hook's plain output to the agent's context.
#   grok             Grok Build PreToolUse hook: prints hookSpecificOutput.additionalContext.
#   antigravity      Antigravity CLI PreInvocation hook: prints an injectSteps message.
#
# When a resume note names this session, print one line that asks the agent to confirm
# with the user before changing files. The hook never blocks: every path exits 0, and it
# prints nothing (or `{}` for Antigravity) when there is no note, no jq, or bad input.
# OpenCode gets the same line from opencode-resume-session-warn.ts.

format="${1:-plain}"
quiet() {
  [ "$format" = antigravity ] && echo '{}'
  exit 0
}

command -v jq >/dev/null 2>&1 || quiet

session_id=$(jq -r '.session_id // .sessionId // .conversationId // empty' 2>/dev/null) || quiet
[ -n "$session_id" ] || quiet
case "$session_id" in
  *[!A-Za-z0-9_-]*) quiet ;;
esac

notes="${XDG_STATE_HOME:-$HOME/.local/state}/resume-session/resumed"
for harness in claude codex opencode antigravity grok muse; do
  note="$notes/$harness-$session_id.json"
  [ -f "$note" ] || continue
  line=$(jq -r '(.resumes[-1] // empty) as $r
    | select($r != null)
    | "This session was resumed in \($r.by_harness // "another harness") at \($r.time_local // $r.time_utc) for the project at \(.project_root). Work done here can conflict with that session. Ask the user to confirm before changing any file in this session."' \
    "$note" 2>/dev/null)
  [ -n "$line" ] || quiet
  case "$format" in
    grok) jq -cn --arg c "$line" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $c}}' ;;
    antigravity) jq -cn --arg c "$line" '{injectSteps: [{ephemeralMessage: $c}]}' ;;
    *) printf '%s\n' "$line" ;;
  esac
  exit 0
done
quiet
