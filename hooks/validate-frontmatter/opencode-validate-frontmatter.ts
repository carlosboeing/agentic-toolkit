import { existsSync, readFileSync } from "fs"
import { dirname, relative, resolve } from "path"

// OpenCode plugin: validate YAML frontmatter relationship paths (related,
// supersedes, superseded_by) in Markdown a tool is about to write, and refuse
// the write when a local path does not resolve relative to the file's directory.
//
// This is the OpenCode counterpart of validate-frontmatter.sh, which runs as a
// Claude Code / Codex PostToolUse hook. One file serves both OpenCode plugin
// APIs through the documented dual entrypoint:
// - OpenCode 2.x reads the default export's `id` and `setup`, and registers
//   hooks through ctx.tool.hook("execute.before", ...).
// - OpenCode 1.x (1.18.29 and newer) calls the default export's `server()` and
//   uses the returned hooks map keyed "tool.execute.before".
//
// Canonical source: carlosboeing/agentic-toolkit (hooks/validate-frontmatter/).

const REL_KEY_RE = /^(related|supersedes|superseded_by)[ \t]*:(.*)$/
const LIST_ITEM_RE = /^[ \t]+-[ \t]+(.*)$/
const EXTERNAL_SCHEMES = ["http://", "https://", "mailto:", "ftp://", "file://", "data:", "javascript:"]

type RelEntry = { line: number; key: string; target: string }

function cleanScalar(raw: string): string {
  let s = raw.replace(/(^|[ \t]+)#.*$/, "").trim()
  if (s.length >= 2 && ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'")))) {
    s = s.slice(1, -1).trim()
  }
  return s
}

function isExternalOrPlaceholder(target: string): boolean {
  const clean = target.trim()
  if (!clean || clean.startsWith("#")) return true
  if (clean.includes("<") && clean.includes(">")) return true
  const lower = clean.toLowerCase()
  return EXTERNAL_SCHEMES.some((scheme) => lower.startsWith(scheme))
}

function extractRelationshipEntries(source: string): RelEntry[] {
  const lines = source.split(/\r?\n/)
  if (lines.length < 3 || lines[0] !== "---") return []

  let endIdx = -1
  for (let i = 1; i < lines.length; i++) {
    if (lines[i] === "---") {
      endIdx = i
      break
    }
  }
  if (endIdx < 0) return []

  const entries: RelEntry[] = []
  let activeKey: string | undefined
  for (let i = 1; i < endIdx; i++) {
    const line = lines[i]
    const lno = i + 1
    const keyMatch = REL_KEY_RE.exec(line)
    if (keyMatch) {
      activeKey = keyMatch[1]
      const rest = cleanScalar(keyMatch[2])
      if (rest.startsWith("[") && rest.endsWith("]")) {
        const inner = rest.slice(1, -1).trim()
        if (inner) {
          for (const part of inner.split(",")) {
            const v = cleanScalar(part)
            if (v) entries.push({ line: lno, key: activeKey, target: v })
          }
        }
        activeKey = undefined
      } else if (rest) {
        entries.push({ line: lno, key: activeKey, target: rest })
        activeKey = undefined
      }
      continue
    }

    if (activeKey) {
      const itemMatch = LIST_ITEM_RE.exec(line)
      if (itemMatch) {
        const v = cleanScalar(itemMatch[1])
        if (v) entries.push({ line: lno, key: activeKey, target: v })
        continue
      }
      if (line.trim() === "" || line.trimStart().startsWith("#")) continue
      activeKey = undefined
    }
  }

  return entries
}

function applyEdit(
  filePath: string,
  oldString: string,
  newString: string,
  replaceAll: boolean,
): string | undefined {
  let current: string
  try {
    current = readFileSync(filePath, "utf8")
  } catch {
    return undefined
  }
  if (!current.includes(oldString)) return undefined
  return replaceAll
    ? current.split(oldString).join(newString)
    : current.replace(oldString, newString)
}

type ToolArgs = Record<string, unknown>

function toolPath(args: ToolArgs): string | undefined {
  if (typeof args.filePath === "string") return args.filePath
  if (typeof args.path === "string") return args.path
  return undefined
}

function suggestRelative(fileDir: string, cleanTarget: string): string | undefined {
  for (const base of [resolve(fileDir, ".."), resolve(fileDir, "../..")]) {
    const candidate = resolve(base, cleanTarget)
    if (existsSync(candidate)) {
      return relative(fileDir, candidate).replace(/\\/g, "/")
    }
  }
  return undefined
}

async function guardWrite(tool: string, args: ToolArgs | undefined): Promise<void> {
  if (tool !== "write" && tool !== "edit") return
  if (!args) return

  const filePath = toolPath(args)
  if (!filePath || !filePath.endsWith(".md")) return

  let source: string | undefined
  if (tool === "write") {
    source = typeof args.content === "string" ? args.content : undefined
  } else {
    const oldString = args.oldString
    const newString = args.newString
    if (typeof oldString !== "string" || typeof newString !== "string") return
    source = applyEdit(filePath, oldString, newString, args.replaceAll === true)
  }

  if (!source || !source.startsWith("---")) return

  const entries = extractRelationshipEntries(source)
  if (entries.length === 0) return

  const fileDir = dirname(resolve(filePath))
  const failures: string[] = []

  for (const entry of entries) {
    if (isExternalOrPlaceholder(entry.target)) continue
    const clean = entry.target.split("#")[0].split("?")[0].replace(/\/+$/, "")
    if (!clean) continue
    if (clean.startsWith("/")) {
      failures.push(
        `Line ${entry.line} (${entry.key}: ${entry.target}): path must be relative to the file's directory, not absolute.`,
      )
      continue
    }
    const resolved = resolve(fileDir, clean)
    if (!existsSync(resolved)) {
      const suggestion = suggestRelative(fileDir, clean)
      if (suggestion) {
        failures.push(
          `Line ${entry.line} (${entry.key}: ${entry.target}): does not resolve from ${fileDir}. Replace '${entry.target}' with '${suggestion}'.`,
        )
      } else {
        failures.push(
          `Line ${entry.line} (${entry.key}: ${entry.target}): does not resolve from ${fileDir}. Write paths in related, supersedes and superseded_by relative to the file's own directory.`,
        )
      }
    }
  }

  if (failures.length > 0) {
    throw new Error(
      `Frontmatter relationship path failure in ${filePath}. The write was refused.\n\n` +
        `${failures.join("\n")}\n\n` +
        "Paths in related, supersedes and superseded_by must be relative to the file's own directory, matching Markdown body links.",
    )
  }
}

type V2ToolHookEvent = { tool?: string; input?: unknown }

async function onExecuteBefore(event: V2ToolHookEvent): Promise<void> {
  await guardWrite(String(event?.tool ?? "").toLowerCase(), event?.input as ToolArgs | undefined)
}

type V2Context = {
  tool: {
    hook(
      name: string,
      callback: (event: V2ToolHookEvent) => Promise<void> | void,
    ): Promise<unknown>
  }
}

const hooksV1 = {
  "tool.execute.before": async (
    input: { tool?: string },
    output: { args?: unknown },
  ): Promise<void> => {
    await guardWrite(String(input?.tool ?? "").toLowerCase(), output?.args as ToolArgs | undefined)
  },
}

const definition = {
  id: "validate-frontmatter",
  async setup(ctx: V2Context): Promise<void> {
    await ctx.tool.hook("execute.before", onExecuteBefore)
  },
  async server(): Promise<typeof hooksV1> {
    return hooksV1
  },
}

export default definition
