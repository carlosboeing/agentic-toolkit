---
name: externalize-deliverable
description: >-
  Derive a clean, client-facing version of an internal document by stripping company-side private information and writing a sendable copy to the project's deliverables/ or equivalent client-facing folder. Use when the user wants to share an internal doc with a client, customer, partner, or external party, including phrases like "make a shareable version", "prep this for the client", "externalize this", "client-safe copy", "redact the internals", or "turn these minutes into something I can send". Not for polishing internal-only docs; this is a redaction aid with a mandatory human-review-before-send gate.
---

# Externalize Deliverable

Turn an internal document into a clean, client-facing one. The internal source stays untouched; you produce a separate, sendable derivative with every company-side internal detail removed.

## Why this exists

Internal documents — meeting minutes, strategy notes, status reports — legitimately carry things you'd never want a client to read: your negotiating position, what you'll concede, equity and pricing thinking, competitive analysis, candid open questions, audit flags. That's correct *for an internal record*. The danger is sharing that record directly, or hand-editing one copy into a "shareable" one and missing something.

This skill makes the internal→external transform a deliberate, repeatable step with a firewall and a review gate — instead of an ad-hoc scrub you hope was thorough.

**Important honesty about scope:** this is a *soft filter*, not a guarantee. You are a capable redactor but not a deterministic one. So the output always ends at a human-review gate, with an explicit list of what you stripped and softened, so the person sending it can verify nothing leaked and nothing important was lost. Never tell the user it's "safe to send" — tell them what you did and let them confirm.

## The pipeline

### 1. Locate and read the internal source

Identify the internal document being externalized (the user usually names it or has it open). Read it in full. If it's ambiguous which doc they mean, ask — don't guess.

### 2. Read the project's boundary

Check the project's `<instructions-file>` (and any README) for a declared internal-vs-client boundary — e.g. "`docs/` and `comms/` are internal; `deliverables/` is client-facing." Respect whatever the project declares: it tells you which folders are internal (sources) and where client-facing output belongs (destination). If nothing is declared, default the destination to a `deliverables/` folder and say so; ask if you're unsure where client output should live.

### 3. Derive fresh, applying Strip / Soften / Keep

Always derive from the **current** internal source. Never hand-maintain a parallel client copy across edits — the two drift, and a stale client doc is its own hazard. If a client version already exists and the source changed, re-derive it rather than patching.

Walk the source section by section and classify everything:

#### Strip — remove entirely

Internal-only content that must not reach the client:

- **Your negotiating position** — what you'll accept, concede, or hold firm on; your internal stance on any open term.
- **Equity / ownership thinking** — proposed splits, percentages, the logic behind your desired stake.
- **Pricing strategy** — internal pricing models, rate thinking, cost/margin reasoning, "what we could charge."
- **Competitive analysis & cross-references** — internal competitor assessments, and pointers like "reconcile with the X analysis" or "contrast with our Y finding."
- **Internal open questions & flags** — your unresolved questions, audit/verification flags, "confirm before this reaches them," anything tagged for internal follow-up.
- **Provenance internals** — recording/transcript links (e.g. Fathom), internal source frontmatter, timestamps into private recordings.
- **Candid internal framing** — blunt characterisations, doubts about the counterparty, anything written for your own consumption.

#### Soften — keep the substance, adjust the framing

- **Over-committal language** where you haven't actually committed. "Agreed to proceed" → "agreed to pursue, pending next steps," when the next steps are what actually gate the commitment. The test: does the wording claim more certainty than the room actually reached? Match reality, in both directions.
- **Do not misrepresent what happened.** The other parties were there. Softening is for accuracy and prudence, not revisionism — if something was genuinely agreed, say so; if it was directional, say that.

#### Keep — this is the shared record

- Mutually-agreed decisions and next steps / action items.
- Backgrounds and introductions shared openly in the room.
- Product, market, and strategy discussion *as it was discussed openly* with the client.
- Anything the client said or already knows.

When in doubt about a specific line, **lean toward stripping and flag it** for the user at the review gate rather than guessing it's safe.

### 4. Add a client-appropriate header (for minutes / reports)

If the deliverable is meeting minutes or a report, give it a clean header the client can read at a glance: title, date, subject, and attendees (grouped by organisation). Drop internal frontmatter.

### 5. Write to the client-facing folder

Write the derivative to the destination from step 2 (e.g. `deliverables/`), with a clear filename (date-prefixed where the project does that). Leave the internal source **unchanged** — confirm you haven't edited it.

### 6. Review gate — surface what changed, then stop

End by showing the user:

- **Where** you wrote the client version, and confirmation the internal source is untouched.
- **What you stripped** — a short bullet list, by category, so they can confirm nothing sensitive remains and nothing essential was lost.
- **What you softened** — each reframing, so they can confirm it still reflects reality.
- **Anything you were unsure about** — lines you stripped defensively or couldn't classify confidently.

Then explicitly hand off: this is ready for **their** review before sending — you are not certifying it safe. Don't commit it or send it without the user's go-ahead; sending is an external, irreversible act that's theirs to make.

## Instructions file resolution

To support multiple platforms and harnesses, abstract the project instructions file (e.g., `CLAUDE.md`, `AGENTS.md`, or `GEMINI.md`) as `<instructions-file>`:
- On Claude Code, default to `CLAUDE.md`.
- On agy, Cursor, and Codex, default to `AGENTS.md` (which may be a symlink to `CLAUDE.md` or `GEMINI.md`).
- If a symlink or pointer exists, resolve the target to write/edit directly to the resolved target file.

## Example

**Internal minutes line:**
> Equity split: Mat expects equal shares; OUR working model is milestone/time-weighted — reconcile before the term sheet. (Cannibalisation risk flagged, see competitive analysis.)

**In the client version:**
- The equity stance, the "reconcile before the term sheet" note, and the competitive cross-reference are **stripped**.
- If equity came up openly, it survives only as something neutral like "equity structure to be set out in the term sheet" — no positions, no numbers.

**Internal:** "The group *agreed to proceed* as equal co-founders."
**Client (softened):** "Both sides agreed to *pursue* a co-founder partnership, to be confirmed through the upcoming questionnaire and proposal." — because the commitment was genuinely contingent on those next steps.

## Common mistakes

- **Treating it as a guarantee.** It's a soft filter. The review gate and the strip/soften list are not optional — they're how a human catches what you missed.
- **Editing the internal source.** Always produce a separate file; never scrub the source itself.
- **Hand-maintaining two copies.** Re-derive from the current source instead; parallel copies drift.
- **Over-stripping into uselessness.** The client still needs a coherent, useful record. Strip internals, not substance — and flag borderline calls rather than silently gutting the doc.
- **Misrepresenting the meeting to make it cleaner.** Soften for accuracy and prudence, never to rewrite what happened.
