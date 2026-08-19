import type { Plugin } from "@opencode-ai/plugin"
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from "fs"
import { tmpdir } from "os"
import { join } from "path"

// OpenCode plugin: parse-validate every fenced mermaid block in Markdown a tool
// is about to write, and refuse the write when a block fails to parse.
//
// This is the OpenCode counterpart of validate-mermaid.sh, which runs as a Claude
// Code PostToolUse hook. The behaviour differs by design. Claude Code validates a
// file that already exists on disk. OpenCode's tool.execute.before receives the
// content before it is written, and throwing aborts the call, so a broken diagram
// never reaches the file.
//
// Canonical source: carlosboeing/claude-code-resources (hooks/validate-mermaid/).

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

export const ValidateMermaidPlugin: Plugin = async ({ $ }) => {
  let runner: string[] | undefined

  try {
    await $`which mmdc`.quiet()
    runner = ["mmdc"]
  } catch {
    runner = ["npx", "-y", "-p", "@mermaid-js/mermaid-cli", "mmdc"]
  }

  return {
    "tool.execute.before": async (input, output) => {
      const tool = String(input?.tool ?? "").toLowerCase()
      if (tool !== "write" && tool !== "edit") return

      const args = output?.args as Record<string, unknown> | undefined
      if (!args) return

      const filePath = args.filePath
      if (typeof filePath !== "string" || !filePath.endsWith(".md")) return

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

      const dir = mkdtempSync(join(tmpdir(), "oc-mermaid-"))
      const failures: string[] = []
      try {
        for (const block of blocks) {
          const src = join(dir, `block-${block.line}.mmd`)
          writeFileSync(src, block.body)
          const result = await $`${runner} -i ${src} -o ${src}.svg --quiet`.quiet().nothrow()
          if (result.exitCode !== 0) {
            const detail = String(result.stderr ?? "")
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
    },
  }
}
