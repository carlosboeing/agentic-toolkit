#!/bin/sh
# resume-session-warn.sh: tell an old session that resume-session continued it elsewhere.
#
# Usage: resume-session-warn.sh [plain|grok|antigravity]
#   plain (default)  UserPromptSubmit hook for Claude Code, Codex, and Muse Code, which add
#                    the hook's plain output to the agent's context.
#   grok             Grok Build PreToolUse hook: prints hookSpecificOutput.additionalContext.
#   antigravity      Antigravity CLI PreInvocation hook: prints an injectSteps message.
#
# When a resume note names this session, print one line that tells the agent this session
# is superseded, to open with a bold blockquote banner telling the user to switch to the
# new session and close this one, and not to change files here unless the user explicitly
# replies in this session to stay here. The hook never blocks: every path exits 0, and it
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
    | (($r.by_harness // "another harness") as $h
       | (if ($r.by_session // "" | test("^[A-Za-z0-9_-]+$")) then " session \($r.by_session)" else "" end) as $sid
       | "SUPERSEDED SESSION: This session is superseded: it was resumed in \($h)\($sid) at \($r.time_local // $r.time_utc) for the project at \(.project_root), and that new session is now the active one. Make the warning stand out: start your reply with a separate blockquote banner headed, in bold capitals, SUPERSEDED SESSION - THIS IS THE OLD SESSION, naming the new harness, and telling the user to switch to the new session and close this one; do not bury it in a list or a status update. Do not change any file, commit, or run a side-effect command here unless the user explicitly replies in this session to stay here and keep working in this old session; if they do, tell them the new session is now stale.")' \
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
