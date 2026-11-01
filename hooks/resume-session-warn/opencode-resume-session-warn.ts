import { readFileSync } from "fs"
import { homedir } from "os"
import { join } from "path"

// OpenCode plugin for resume-session. It does two things:
//
// 1. When a resume note names this session, it adds one line to each model request, next to
//    the latest user turn, asking the agent to confirm with the user before changing files. It is
//    the OpenCode counterpart of resume-session-warn.sh and prints the same sentence. It
//    never blocks: a missing or unreadable note adds nothing.
// 2. It sets RESUME_SESSION_CURRENT=opencode:<sessionID> for shell commands, so the
//    resume-session reader can leave the running session out of its list. OpenCode's own
//    OPENCODE_SESSION_ID does not match the stored session ID (probed on 2.1.4).
//
// One file serves both OpenCode plugin APIs through the documented dual entrypoint
// (https://opencode.ai/v2/docs/build/plugins/migrate-v1):
// - 2.x reads `id` and `setup`, with ctx.session.hook("context"), ctx.tool.hook(
//   "execute.before") and ctx.shell.hook("create.before"). The shell hook has no session
//   ID, so the tool hook, which runs first for the same command, records it.
// - 1.x calls `server()` and uses "experimental.chat.system.transform" and "shell.env",
//   which both carry sessionID.
// The module imports only Node built-ins.
//
// Canonical source: carlosboeing/agentic-toolkit (hooks/resume-session-warn/).

const SAFE_ID = /^[A-Za-z0-9_-]+$/

function notesDir(): string {
  return join(process.env.XDG_STATE_HOME || join(homedir(), ".local", "state"), "resume-session", "resumed")
}

export function warning(sessionID: unknown): string | undefined {
  if (typeof sessionID !== "string" || !SAFE_ID.test(sessionID)) return undefined
  let note: any
  try {
    note = JSON.parse(readFileSync(join(notesDir(), `opencode-${sessionID}.json`), "utf8"))
  } catch {
    return undefined
  }
  const resumes = Array.isArray(note?.resumes) ? note.resumes : []
  const last = resumes[resumes.length - 1]
  if (!last) return undefined
  return (
    `This session was resumed in ${last.by_harness ?? "another harness"} at ${last.time_local ?? last.time_utc} ` +
    `for the project at ${note.project_root}. Work done here can conflict with that session. ` +
    "Ask the user to confirm before changing any file in this session."
  )
}

function marker(sessionID: unknown): string | undefined {
  return typeof sessionID === "string" && SAFE_ID.test(sessionID) ? `opencode:${sessionID}` : undefined
}

export default {
  id: "resume-session-warn",

  async setup(ctx: any) {
    const pending = new Map<string, string>()
    await ctx.session.hook("context", (event: any) => {
      const text = warning(event?.sessionID)
      if (!text) return
      // Next to the latest user turn, where Claude Code and Codex put a UserPromptSubmit
      // hook's output. A system-prompt line alone did not stop three models from writing
      // (2026-11-01). The change applies to this request only; the stored prompt is unchanged.
      const user = Array.isArray(event.messages) ? [...event.messages].reverse().find((m: any) => m?.role === "user") : undefined
      if (user && Array.isArray(user.content)) user.content = [...user.content, { type: "text", text }]
      else if (Array.isArray(event.system)) event.system.push({ type: "text", text })
    })
    await ctx.tool.hook("execute.before", (event: any) => {
      const command = event?.input?.command
      if (typeof command === "string" && marker(event.sessionID)) pending.set(command, event.sessionID)
    })
    await ctx.shell.hook("create.before", (event: any) => {
      const sessionID = pending.get(event?.command)
      if (sessionID === undefined || !event.env) return
      pending.delete(event.command)
      event.env.RESUME_SESSION_CURRENT = marker(sessionID)
    })
  },

  async server() {
    return {
      "experimental.chat.system.transform": async (input: any, output: any) => {
        const text = warning(input?.sessionID)
        if (text && Array.isArray(output?.system)) output.system.push(text)
      },
      "shell.env": async (input: any, output: any) => {
        const value = marker(input?.sessionID)
        if (value && output?.env) output.env.RESUME_SESSION_CURRENT = value
      },
    }
  },
}
