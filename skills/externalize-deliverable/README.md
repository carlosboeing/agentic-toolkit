# `/externalize-deliverable` — Prep internal documents for client-facing sharing

A drop-in skill that derives a clean, client-safe version of an internal document by stripping company-side private details (negotiation stances, pricing, competitive audits, internal flags) and writing the sendable copy to the project's client-facing directory.

---

## What it does

When you run `/externalize-deliverable` on a file (or request a client-safe draft):

1. **Locate & Read**: Ingests the target internal document.
2. **Project Boundary Identification**: Resolves directory structures (e.g. `docs/` vs `deliverables/`) defined in the `<instructions-file>`.
3. **Classify (Strip / Soften / Keep)**:
   - **Strip**: Completely removes internal-only content (equity strategies, margins, transcript links, uncommitted remarks).
   - **Soften**: Reframes over-committal language to match real contractual progress without distorting facts.
   - **Keep**: Retains the shared record of decisions, actions, and open contexts.
4. **Header Generation**: Formats a professional, client-friendly heading (title, date, attendees organized by firm).
5. **Write**: Saves the new file to the client-facing directory (e.g., `deliverables/`).
6. **Review Gate**: Summarizes the strips, softens, and defensive decisions for human verification before sharing.

## Install

### User-level (works across all projects)

```bash
mkdir -p ~/.claude/skills/externalize-deliverable
cp skills/externalize-deliverable/SKILL.md ~/.claude/skills/externalize-deliverable/SKILL.md
```

To sync to your agent skills folder for Antigravity, Cursor, and Codex:

```bash
mkdir -p ~/.agents/skills/externalize-deliverable
ln -sf ~/Projects/carlos/claude-code-resources/skills/externalize-deliverable/SKILL.md ~/.agents/skills/externalize-deliverable/SKILL.md
```

### Project-level (travels with the repository)

```bash
mkdir -p .claude/skills/externalize-deliverable
cp skills/externalize-deliverable/SKILL.md .claude/skills/externalize-deliverable/SKILL.md
```

## Usage examples

```
/externalize-deliverable docs/notes/2026-06-18-equity-sync.md
/externalize-deliverable "meeting notes from today"
```

## Design philosophy

- **Firewall**: Never scrub the internal source document. Always create a new derivative to prevent accidental loss of internal context.
- **Human Verification**: The agent is a redaction helper, not a deterministic guarantee. It always halts at the review gate for the user to verify.
- **Substance Preservation**: Focuses on removing sensitive company-side metadata while preserving the usefulness and readability of the record.
