#!/usr/bin/env node
// assert-opencode-plugin.mjs — shape and behavior assertions for the OpenCode
// Mermaid plugin, checked against both OpenCode plugin APIs from one module.
//
// Usage: <bun | node | node --experimental-strip-types> assert-opencode-plugin.mjs <plugin-file>
//
// Both APIs mean:
// - OpenCode 2.x loads a default-exported definition with an `id` and a `setup`
//   function and registers hooks through `ctx.tool.hook("execute.before", ...)`.
// - OpenCode 1.x (1.18.29 and newer) calls the default export's `server()`
//   function and uses the returned hooks map keyed "tool.execute.before".
//
// The tests call the plugin exactly as each loader does, then exercise the
// Mermaid guard through both hook shapes. The runner stub on PATH named `mmdc`
// decides parse success the way Mermaid does for the common case this hook
// exists to catch: a ';' in label or message text. The real parser is exercised
// by the manual check in the plugin's README, not here, so this suite stays
// offline.
//
// Exit codes: 0 when every assertion passes, 1 otherwise.

import { mkdtempSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { pathToFileURL } from "node:url"

const pluginPath = process.argv[2]
if (!pluginPath) {
  console.error("usage: assert-opencode-plugin.mjs <plugin-file>")
  process.exit(1)
}

const GOOD = "# Title\n\n```mermaid\nflowchart TD\n  a-->b\n```\n\nDone.\n"
const BAD = "# Title\n\n```mermaid\nsequenceDiagram\n  A->>B: first half, second half; oops\n```\n"
const UNTERMINATED = "# Title\n\n```mermaid\nflowchart TD\n  a-->b\n"

const dir = mkdtempSync(join(tmpdir(), "oc-plugin-test-"))
process.on("exit", () => rmSync(dir, { recursive: true, force: true }))

const mod = await import(pathToFileURL(pluginPath).href)
const def = mod.default

let pass = 0
let fail = 0

function check(name, fn) {
  try {
    fn()
    pass += 1
    console.log(`  ok   plugin: ${name}`)
  } catch (error) {
    fail += 1
    console.log(`  FAIL plugin: ${name}\n       ${error && error.message ? error.message : error}`)
  }
}

async function checkRefusal(name, call, patterns) {
  try {
    await call()
    fail += 1
    console.log(`  FAIL plugin: ${name}\n       expected a refusal, the call passed`)
  } catch (error) {
    const message = String(error && error.message ? error.message : error)
    const missing = patterns.filter((p) => !p.test(message))
    if (missing.length > 0) {
      fail += 1
      console.log(`  FAIL plugin: ${name}\n       message missing ${missing.map(String).join(", ")}\n       got: ${message.split("\n")[0]}`)
      return
    }
    pass += 1
    console.log(`  ok   plugin: ${name}`)
  }
}

async function checkPass(name, call) {
  try {
    await call()
    pass += 1
    console.log(`  ok   plugin: ${name}`)
  } catch (error) {
    fail += 1
    console.log(`  FAIL plugin: ${name}\n       expected the call to pass, got: ${error && error.message ? error.message : error}`)
  }
}

// --- Shape: OpenCode 2.x reads the default export as a definition ---

check("default export is a definition object (2.x)", () => {
  if (typeof def !== "object" || def === null) throw new Error(`default export is ${typeof def}, expected an object`)
})

check("definition id is a non-empty string (2.x)", () => {
  if (typeof def.id !== "string" || def.id.length === 0) throw new Error(`id is ${JSON.stringify(def.id)}`)
})

check("definition exposes setup (2.x)", () => {
  if (typeof def.setup !== "function") throw new Error(`setup is ${typeof def.setup}, expected a function`)
})

check("definition exposes server (1.x object entrypoint)", () => {
  if (typeof def.server !== "function") throw new Error(`server is ${typeof def.server}, expected a function`)
})

// --- Shape: each loader gets its own hook registration ---

const registered = []
let setupError
try {
  await def.setup({
    tool: {
      hook: async (name, callback) => {
        registered.push({ name, callback })
        return { dispose: async () => {} }
      },
    },
  })
} catch (error) {
  setupError = error
}

check("setup registers tool hook execute.before (2.x)", () => {
  if (setupError) throw new Error(`setup() threw: ${setupError.message}`)
  const names = registered.map((r) => r.name)
  if (!names.includes("execute.before")) throw new Error(`registered hooks: ${JSON.stringify(names)}`)
  const hook = registered.find((r) => r.name === "execute.before")
  if (typeof hook.callback !== "function") throw new Error("execute.before callback is not a function")
})

let v1Hooks = {}
let serverError
try {
  v1Hooks = await def.server()
} catch (error) {
  serverError = error
}

check("server returns tool.execute.before hook (1.x)", () => {
  if (serverError) throw new Error(`server() threw: ${serverError.message}`)
  if (typeof v1Hooks["tool.execute.before"] !== "function") {
    throw new Error(`server() returned keys: ${JSON.stringify(Object.keys(v1Hooks))}`)
  }
})

const v2Hook = (registered.find((r) => r.name === "execute.before") || {}).callback
const v1Hook = v1Hooks["tool.execute.before"]

function v2(event) {
  if (typeof v2Hook !== "function") throw new Error("execute.before hook is not registered (2.x)")
  return v2Hook(event)
}

function v1(input, output) {
  if (typeof v1Hook !== "function") throw new Error("tool.execute.before hook is missing (1.x)")
  return v1Hook(input, output)
}

// --- Behavior through the 2.x hook shape: one mutable event ---

await checkPass("2.x write with a valid diagram passes", () =>
  v2({ tool: "write", input: { filePath: join(dir, "good.md"), content: GOOD } }),
)

await checkRefusal(
  "2.x write with ';' in a label is refused with guidance",
  () => v2({ tool: "write", input: { filePath: join(dir, "bad.md"), content: BAD } }),
  [/Common causes:/, /The write was refused/],
)

await checkRefusal(
  "2.x write using the path argument name is validated and refused",
  () => v2({ tool: "write", input: { path: join(dir, "bad-path.md"), content: BAD } }),
  [/The write was refused/],
)

await checkPass("2.x write to a non-Markdown file is not validated", () =>
  v2({ tool: "write", input: { filePath: join(dir, "notes.txt"), content: BAD } }),
)

await checkRefusal(
  "2.x write with an unterminated fence is refused",
  () => v2({ tool: "write", input: { filePath: join(dir, "open.md"), content: UNTERMINATED } }),
  [/Unterminated/],
)

// --- Behavior through the 1.x hook shape: (input, output) ---

await checkPass("1.x write with a valid diagram passes", () =>
  v1({ tool: "write" }, { args: { filePath: join(dir, "good-1.md"), content: GOOD } }),
)

await checkRefusal(
  "1.x write with ';' in a label is refused with guidance",
  () => v1({ tool: "write" }, { args: { filePath: join(dir, "bad-1.md"), content: BAD } }),
  [/Common causes:/, /The write was refused/],
)

const editTarget = join(dir, "edit-target.md")
writeFileSync(editTarget, GOOD)

await checkRefusal(
  "1.x edit that introduces a broken diagram is refused",
  () => v1({ tool: "edit" }, { args: { filePath: editTarget, oldString: "a-->b", newString: "a-->b; oops" } }),
  [/Common causes:/, /The write was refused/],
)

const editTarget2 = join(dir, "edit-target-2.md")
writeFileSync(editTarget2, GOOD)

await checkRefusal(
  "2.x edit that introduces a broken diagram is refused",
  () => v2({ tool: "edit", input: { path: editTarget2, oldString: "a-->b", newString: "a-->b; oops" } }),
  [/Common causes:/, /The write was refused/],
)

console.log(`  plugin assertions: ${pass} passed, ${fail} failed`)
process.exit(fail > 0 ? 1 : 0)
