# repo-standards

Applies the repo house standard (`reference/reference-oss-standards.md`) to any repo, private or public OSS.

## What it does

- `check [oss|private] [path]` - audit base (workflows, `CODEOWNERS`, `dependabot`, `required` gate, `docs/`) and, if `oss`, the 6 OSS health files (`CODE_OF_CONDUCT`, `SECURITY`, `SUPPORT`, etc.) + yml issue forms + no `gmail.com`.
- `fix [oss|private] [path]` - patch gaps from `templates/default-project` (fills `<OWNER>`/`<REPO>` via `gh`) and pins SHAs from reference §2.
- `scaffold <name> [oss|private]` - `degit templates/default-project` + optional OSS overlay.

Visibility auto-detects via `gh repo view --json visibility` if no flag; `oss` = `public`.

## Use

```
/repo-standards check
/repo-standards fix oss
/repo-standards scaffold my-tool private
```

Reads the single source `reference/reference-oss-standards.md` - no generated SHAs.

## Install

Via hub (already mirrored to `~/.agents/skills`, `~/.gemini/config/skills`):

```bash
./skills/sync-skills.sh
```

Or single skill:

```bash
mkdir -p ~/.claude/skills/repo-standards
cp skills/repo-standards/SKILL.md ~/.claude/skills/repo-standards/SKILL.md
```

Alias: `/oss-standards` remains as a deprecated wrapper pointing here.

## Conventions

- No personal email (`! grep -q gmail`).
- Pinned SHAs only from reference §2.
- `required` is the only `required_status_checks` entry.
