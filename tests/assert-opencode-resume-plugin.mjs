#!/usr/bin/env node
// assert-opencode-resume-plugin.mjs — behavior assertions for the OpenCode
// resume-session-warn plugin, against both OpenCode plugin APIs from one module.
//
// Usage: <bun | node | node --experimental-strip-types> assert-opencode-resume-plugin.mjs <plugin-file>
//
// The tests call the plugin as each loader does: 2.x through `setup(ctx)` with
// ctx.session.hook, ctx.tool.hook and ctx.shell.hook; 1.x through `server()`.
// The warning line must equal the one resume-session-warn.sh prints, which
// tests/test_resume_session_notes.py checks against the same text.
//
// Exit codes: 0 when every assertion passes, 1 otherwise.

import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { pathToFileURL } from "node:url"

const pluginPath = process.argv[2]
if (!pluginPath) {
  console.error("usage: assert-opencode-resume-plugin.mjs <plugin-file>")
  process.exit(1)
}

const SESSION = "ses_fixture1"
const LINE =
  "This session was resumed in Codex CLI at 2026-10-31 10:47 +10:00 for the project at /home/dev/app. " +
  "Work done here can conflict with that session. Ask the user to confirm before changing any file in this session."

const state = mkdtempSync(join(tmpdir(), "oc-resume-test-"))
process.on("exit", () => rmSync(state, { recursive: true, force: true }))
process.env.XDG_STATE_HOME = state
const notes = join(state, "resume-session", "resumed")
mkdirSync(notes, { recursive: true })
writeFileSync(
  join(notes, `opencode-${SESSION}.json`),
  JSON.stringify({
    harness: "opencode",
    session_id: SESSION,
    project_root: "/home/dev/app",
    resumes: [{ time_utc: "2026-10-31T00:47:00+00:00", time_local: "2026-10-31 10:47 +10:00", by_harness: "Codex CLI" }],
  }),
)

const def = (await import(pathToFileURL(pluginPath).href)).default

let pass = 0
let fail = 0
async function check(name, fn) {
  try {
    await fn()
    pass += 1
    console.log(`  ok   resume plugin: ${name}`)
  } catch (error) {
    fail += 1
    console.log(`  FAIL resume plugin: ${name}\n       ${error && error.message ? error.message : error}`)
  }
}
function equal(actual, expected, what) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${what}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`)
  }
}

const hooks = {}
const ctx = {
  session: { hook: async (name, fn) => { hooks[`session.${name}`] = fn } },
  tool: { hook: async (name, fn) => { hooks[`tool.${name}`] = fn } },
  shell: { hook: async (name, fn) => { hooks[`shell.${name}`] = fn } },
}

await check("2.x shape: id and setup", () => {
  equal(def.id, "resume-session-warn", "id")
  equal(typeof def.setup, "function", "setup")
})
await def.setup(ctx)

await check("2.x context hook adds the warning to the latest user turn", () => {
  const first = { role: "user", content: [{ type: "text", text: "first" }] }
  const last = { role: "user", content: [{ type: "text", text: "Create hello.txt" }] }
  const event = { sessionID: SESSION, system: [], messages: [first, { role: "assistant", content: [] }, last] }
  hooks["session.context"](event)
  equal(last.content, [{ type: "text", text: "Create hello.txt" }, { type: "text", text: LINE }], "latest user turn")
  equal(first.content, [{ type: "text", text: "first" }], "earlier user turn")
  equal(event.system, [], "system")
})

await check("2.x context hook falls back to the system prompt without a user turn", () => {
  const event = { sessionID: SESSION, system: [], messages: [] }
  hooks["session.context"](event)
  equal(event.system, [{ type: "text", text: LINE }], "system")
})

await check("2.x context hook adds nothing without a note or with a bad ID", () => {
  for (const sessionID of ["ses_other", "../../etc/passwd", undefined]) {
    const user = { role: "user", content: [] }
    const event = { sessionID, system: [], messages: [user] }
    hooks["session.context"](event)
    equal([event.system, user.content], [[], []], `request for ${sessionID}`)
  }
})

await check("2.x shell commands get RESUME_SESSION_CURRENT from the tool hook", () => {
  hooks["tool.execute.before"]({ tool: "shell", sessionID: SESSION, input: { command: "echo hi" } })
  const shell = { command: "echo hi", env: {} }
  hooks["shell.create.before"](shell)
  equal(shell.env.RESUME_SESSION_CURRENT, `opencode:${SESSION}`, "env")
  const other = { command: "ls", env: {} }
  hooks["shell.create.before"](other)
  equal(other.env, {}, "env for an unmatched command")
})

const v1 = await def.server()

await check("1.x system transform adds the warning", async () => {
  const output = { system: [] }
  await v1["experimental.chat.system.transform"]({ sessionID: SESSION }, output)
  equal(output.system, [LINE], "system")
  const none = { system: [] }
  await v1["experimental.chat.system.transform"]({ sessionID: "ses_other" }, none)
  equal(none.system, [], "system without a note")
})

await check("1.x shell.env sets RESUME_SESSION_CURRENT", async () => {
  const output = { env: {} }
  await v1["shell.env"]({ cwd: "/", sessionID: SESSION }, output)
  equal(output.env.RESUME_SESSION_CURRENT, `opencode:${SESSION}`, "env")
})

console.log(`  resume plugin assertions: ${pass} passed, ${fail} failed`)
process.exit(fail ? 1 : 0)
