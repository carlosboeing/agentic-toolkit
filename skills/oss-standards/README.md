# oss-standards

Applies the OSS house standard (`reference/reference-oss-standards.md`) to any public repo.

## What it does

- `check` - audit community health files, pinned workflow SHAs, `dependabot.yml`, branch protection `required` gate, and email exposure.
- `fix` - patch gaps in place (copies from `templates/default-project-oss/`, pins SHAs from reference §2).
- `scaffold` - create a new repo from the house-standard template.

## Use

```
/oss-standards check
/oss-standards fix
/oss-standards scaffold my-new-tool
```

Reads the single source `reference/reference-oss-standards.md` - no generated SHAs.

## Install

Via hub (already mirrored to `~/.agents/skills`, `~/.gemini/config/skills`):

```bash
./skills/sync-skills.sh
```

Install the `repo-standards` skill too: this compatibility alias delegates to it. For the alias directory:

```bash
mkdir -p ~/.claude/skills/oss-standards
cp skills/oss-standards/SKILL.md ~/.claude/skills/oss-standards/SKILL.md
```

## Conventions

- No personal email (`! grep -q gmail`).
- Pinned SHAs only from reference §2 table.
- `required` is the only `required_status_checks` entry.
