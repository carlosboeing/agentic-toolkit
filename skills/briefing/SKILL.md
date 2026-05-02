---
name: briefing
description: |
  Adaptive project orientation. Auto-discovers project state from git, GitHub,
  the canonical docs/ working-memory layout, and any project-tracker source
  declared in CLAUDE.md (## Project context section). Reshapes output based on
  what's in flight — leads with active work if there is any, leads with what's
  next if not. Use whenever you start a session and need to catch up:
  "where am I, what was I doing, what's next?", "what changed while I was
  away?", "where did I stop?", or just /briefing.
argument-hint: "[quick|standard|deep] [save] [help]"
---

# `/briefing` — Adaptive project orientation

This skill produces a structured briefing of project state on demand. It auto-discovers what's in flight from git, GitHub, the canonical `docs/` working-memory layout, and any project-tracker source declared in this project's CLAUDE.md `## Project context` section. The output reshapes based on what it finds — leads with active work if there is any, leads with what's next if everything is calm.

The audience is you, returning to a project after a session, a day, a week, or a vacation. You want to know where you are, what you were doing, and what to pick up — without re-reading every file. The skill is read-only on the project (it never modifies project files); the only exception is the briefing log it writes when you invoke it with `save`.

For the convention this skill consumes, see your project's CLAUDE.md `## Project context` section, or [the canonical reference in this repo's conventions guide](../../guides/guide-project-structure-and-conventions.md#58--project-context-section-in-claudemd).

## Synopsis

```
/briefing [depth] [save] [help]

  depth   quick | standard | deep                      default: adaptive (no override)
          (synonyms — quick: peek
                      deep:  deep-dive, audit)
  save    write the briefing to disk                   default: off
          (synonyms: --save, export)
  help    show this synopsis instead of running        default: off
          (synonyms: ?, usage, --help, -h)
```

Order of args does not matter. `/briefing deep save` and `/briefing save deep` are equivalent. If `help` (or `?`, `usage`) appears anywhere in the args, the skill renders this Synopsis as the response and stops — no briefing, no save.

The depth default is **adaptive**: when no depth keyword is provided, the briefing's length is content-driven — sections appear or disappear based on what the project state actually contains. `quick`, `standard`, and `deep` are explicit overrides for fixed-length tiers; "no dial" is its own behaviour, not a synonym for `standard`.

## How to parse the args

Walk the tokens once and bucket each one:

- **Depth keywords** (closed set): `quick`, `peek`, `standard`, `deep`, `deep-dive`, `audit`. Default: adaptive (no override) if no depth keyword is present.
- **Save keywords** (closed set): `save`, `--save`, `export`. Default off.
- **Help keywords** (closed set): `help`, `--help`, `-h`, `?`, `usage`. If any appear, **short-circuit**: render the Synopsis above and stop.
- **Anything else**: respond with `unknown arg <X> — try /briefing help` and stop.

The parser is order-independent and case-insensitive. Two of the same bucket is an error of intent — pick the latter and mention the override in the briefing's source-coverage footer (e.g., `Note: depth received both 'quick' and 'deep'; using 'deep'`).
