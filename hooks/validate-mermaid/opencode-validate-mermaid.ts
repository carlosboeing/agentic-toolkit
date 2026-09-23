import { execFile } from "child_process"
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from "fs"
import { tmpdir } from "os"
import { join } from "path"

// OpenCode plugin: parse-validate every fenced mermaid block in Markdown a tool
// is about to write, and refuse the write when a block fails to parse.
//
// This is the OpenCode counterpart of validate-mermaid.sh, which runs as a Claude
// Code PostToolUse hook. The behaviour differs by design. Claude Code validates a
// file that already exists on disk. OpenCode validates the content before it is
// written, and throwing aborts the call, so a broken diagram never reaches the
// file.
//
// One file serves both OpenCode plugin APIs through the documented dual
// entrypoint (https://opencode.ai/v2/docs/build/plugins/migrate-v1):
// - OpenCode 2.x reads the default export's `id` and `setup`, and registers
//   hooks through ctx.tool.hook("execute.before", ...).
// - OpenCode 1.x (1.18.29 and newer) calls the default export's `server()` and
//   uses the returned hooks map keyed "tool.execute.before".
// Each loader picks its own entrypoint and ignores the other, so no runtime
// version detection is needed. The module imports only Node built-ins, so it
// loads on both sides without depending on either plugin types package.
//
// Canonical source: carlosboeing/agentic-toolkit (hooks/validate-mermaid/).

const FENCE_OPEN = /^[ \t]*```mermaid[ \t]*$/
const FENCE_CLOSE = /^[ \t]*```[ \t]*$/

const CAUSES =
  "Common causes: ';' in message or label text (Mermaid reads it as a statement " +
  "separator), a leading '+' or '-' in a sequence message, and unquoted '()[]{}|' " +
  "in flowchart labels."

type Block = { line: number; body: string }

// `unterminated` carries the 1-indexed line of an opening fence that never closed.
// Returning zero blocks for that case would let malformed Markdown through, because
// the caller cannot tell "no diagrams here" from "the diagram never ended".
type Extraction = { blocks: Block[]; unterminated?: number }

function extractBlocks(source: string): Extraction {
  // Split on either line ending. A CRLF file split on "\n" alone leaves a trailing
  // carriage return on every line, which neither fence pattern matches because "\r"
  // is not in [ \t]. Both fences would then miss, extraction would return no blocks,
  // and the write would pass unvalidated. Dropping the CR here also keeps it out of
  // the .mmd file handed to mmdc.
  const lines = source.split(/\r?\n/)
  const blocks: Block[] = []
  let start = -1
  let buffer: string[] = []

  for (let i = 0; i < lines.length; i++) {
    if (start < 0) {
      if (FENCE_OPEN.test(lines[i])) {
        start = i + 2
        buffer = []
      }
      continue
    }
    if (FENCE_CLOSE.test(lines[i])) {
      blocks.push({ line: start, body: buffer.join("\n") })
      start = -1
      continue
    }
    buffer.push(lines[i])
  }

  // start holds the first body line, so the fence itself opened one line earlier.
  return start < 0 ? { blocks } : { blocks, unterminated: start - 1 }
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
type RunResult = { exitCode: number; stderr: string }

// 1.x names the path argument `filePath`; 2.x documents `path`. Accept both so
// one guard covers either loader.
function toolPath(args: ToolArgs): string | undefined {
  if (typeof args.filePath === "string") return args.filePath
  if (typeof args.path === "string") return args.path
  return undefined
}

function run(file: string, args: string[]): Promise<RunResult> {
  return new Promise((resolve) => {
    execFile(file, args, (error, _stdout, stderr) => {
      const code = (error as { code?: unknown } | null)?.code
      resolve({
        exitCode: typeof code === "number" ? code : error ? 1 : 0,
        stderr: String(stderr ?? ""),
      })
    })
  })
}

let runner: string[] | undefined

async function resolveRunner(): Promise<string[]> {
  if (runner) return runner
  const probe = await run("which", ["mmdc"])
  runner = probe.exitCode === 0 ? ["mmdc"] : ["npx", "-y", "-p", "@mermaid-js/mermaid-cli", "mmdc"]
  return runner
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
    // Reconstruct for every Markdown edit, not only for edits whose own text
    // carries a fence. Most edits to a diagram replace diagram body lines and
    // touch no fence at all, and skipping those let a broken diagram reach disk.
    // The fence test below runs against the reconstructed file, so mmdc still
    // only launches when the result actually contains a diagram.
    source = applyEdit(filePath, oldString, newString, args.replaceAll === true)
  }

  if (!source || !source.includes("```mermaid")) return

  const { blocks, unterminated } = extractBlocks(source)
  if (unterminated !== undefined) {
    throw new Error(
      `Unterminated \`\`\`mermaid fence in ${filePath}, opened at line ${unterminated}. ` +
        "The write was refused.\n\nClose the block with a ``` fence.",
    )
  }
  if (blocks.length === 0) return

  const command = await resolveRunner()
  const dir = mkdtempSync(join(tmpdir(), "oc-mermaid-"))
  const failures: string[] = []
  try {
    for (const block of blocks) {
      const src = join(dir, `block-${block.line}.mmd`)
      writeFileSync(src, block.body)
      const result = await run(command[0], [
        ...command.slice(1),
        "-i",
        src,
        "-o",
        `${src}.svg`,
        "--quiet",
      ])
      if (result.exitCode !== 0) {
        const detail = result.stderr
          .split("\n")
          .filter((l) => l.trim())
          .slice(0, 6)
          .join("\n")
        failures.push(`Block starting at line ${block.line}:\n${detail}`)
      }
    }
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }

  if (failures.length > 0) {
    throw new Error(
      `Mermaid parse failure in ${filePath}. The write was refused.\n\n` +
        `${failures.join("\n\n")}\n\n${CAUSES}`,
    )
  }
}

// --- OpenCode 2.x entrypoint: setup registers the hook on the tool domain, and
// the hook receives one mutable event. Throwing refuses the tool call. ---

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

// --- OpenCode 1.x entrypoint (1.18.29 and newer): server() returns the hooks
// map, keyed as in the 1.x plugin API. ---

const hooksV1 = {
  "tool.execute.before": async (
    input: { tool?: string },
    output: { args?: unknown },
  ): Promise<void> => {
    await guardWrite(String(input?.tool ?? "").toLowerCase(), output?.args as ToolArgs | undefined)
  },
}

const definition = {
  id: "validate-mermaid",
  async setup(ctx: V2Context): Promise<void> {
    await resolveRunner()
    await ctx.tool.hook("execute.before", onExecuteBefore)
  },
  async server(): Promise<typeof hooksV1> {
    await resolveRunner()
    return hooksV1
  },
}

export default definition
