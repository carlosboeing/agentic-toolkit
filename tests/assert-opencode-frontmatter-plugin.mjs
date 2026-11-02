#!/usr/bin/env node
// assert-opencode-frontmatter-plugin.mjs — shape and behavior assertions for the
// OpenCode frontmatter relationship path plugin across both OpenCode plugin APIs.

import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { pathToFileURL } from "node:url"

const pluginPath = process.argv[2]
if (!pluginPath) {
  console.error("usage: assert-opencode-frontmatter-plugin.mjs <plugin-file>")
  process.exit(1)
}

const dir = mkdtempSync(join(tmpdir(), "oc-fm-plugin-test-"))
process.on("exit", () => rmSync(dir, { recursive: true, force: true }))

mkdirSync(join(dir, "0-brainstorms"), { recursive: true })
mkdirSync(join(dir, "1-research"), { recursive: true })
writeFileSync(join(dir, "0-brainstorms", "idea.md"), "# Idea\n")

const GOOD = [
  "---",
  'title: "Study"',
  "related:",
  "  - ../0-brainstorms/idea.md",
  "  - https://example.com/spec",
  "---",
  "",
  "# Body",
].join("\n")

const BAD_ROOT_REL = [
  "---",
  'title: "Study"',
  "related:",
  "  - 0-brainstorms/idea.md",
  "---",
  "",
  "# Body",
].join("\n")

const mod = await import(pathToFileURL(pluginPath).href)
const def = mod.default

let pass = 0
let fail = 0

function check(name, fn) {
  try {
    fn()
    pass += 1
    console.log(`  ok   frontmatter-plugin: ${name}`)
  } catch (error) {
    fail += 1
    console.log(`  FAIL frontmatter-plugin: ${name}\n       ${error && error.message ? error.message : error}`)
  }
}

async function checkRefusal(name, call, patterns) {
  try {
    await call()
    fail += 1
    console.log(`  FAIL frontmatter-plugin: ${name}\n       expected a refusal, the call passed`)
  } catch (error) {
    const message = String(error && error.message ? error.message : error)
    const missing = patterns.filter((p) => !p.test(message))
    if (missing.length > 0) {
      fail += 1
      console.log(`  FAIL frontmatter-plugin: ${name}\n       message missing ${missing.map(String).join(", ")}\n       got: ${message}`)
      return
    }
    pass += 1
    console.log(`  ok   frontmatter-plugin: ${name}`)
  }
}

async function checkPass(name, call) {
  try {
    await call()
    pass += 1
    console.log(`  ok   frontmatter-plugin: ${name}`)
  } catch (error) {
    fail += 1
    console.log(`  FAIL frontmatter-plugin: ${name}\n       expected the call to pass, got: ${error && error.message ? error.message : error}`)
  }
}

check("default export is a definition object (2.x)", () => {
  if (typeof def !== "object" || def === null) throw new Error(`default export is ${typeof def}`)
  if (def.id !== "validate-frontmatter") throw new Error(`id is ${JSON.stringify(def.id)}`)
  if (typeof def.setup !== "function") throw new Error("missing setup()")
  if (typeof def.server !== "function") throw new Error("missing server()")
})

const registered = []
await def.setup({
  tool: {
    hook: async (name, callback) => {
      registered.push({ name, callback })
      return { dispose: async () => {} }
    },
  },
})
const v2Hook = (registered.find((r) => r.name === "execute.before") || {}).callback
const v1Hooks = await def.server()
const v1Hook = v1Hooks["tool.execute.before"]

await checkPass("2.x write with file-relative related path passes", () =>
  v2Hook({ tool: "write", input: { filePath: join(dir, "1-research", "good.md"), content: GOOD } }),
)

await checkRefusal(
  "2.x write with root-relative related path is refused with suggestion",
  () => v2Hook({ tool: "write", input: { filePath: join(dir, "1-research", "bad.md"), content: BAD_ROOT_REL } }),
  [/The write was refused/, /\.\.\/0-brainstorms\/idea\.md/],
)

await checkRefusal(
  "1.x write with root-relative related path is refused with suggestion",
  () => v1Hook({ tool: "write" }, { args: { filePath: join(dir, "1-research", "bad1.md"), content: BAD_ROOT_REL } }),
  [/The write was refused/, /\.\.\/0-brainstorms\/idea\.md/],
)

const editFile = join(dir, "1-research", "edit.md")
writeFileSync(editFile, GOOD)
await checkRefusal(
  "2.x edit introducing a root-relative related path is refused",
  () =>
    v2Hook({
      tool: "edit",
      input: { path: editFile, oldString: "../0-brainstorms/idea.md", newString: "0-brainstorms/idea.md" },
    }),
  [/The write was refused/, /\.\.\/0-brainstorms\/idea\.md/],
)

console.log(`  frontmatter plugin assertions: ${pass} passed, ${fail} failed`)
process.exit(fail > 0 ? 1 : 0)
