# repo-standards

Checks a repository against the [repository house standard](../../reference/reference-oss-standards.md) and fixes what is missing. It covers CI workflows, pinned action versions, Dependabot, `CODEOWNERS`, the required status check, and for public repositories the community health files.

The standard is the maintainer's own, written for `carlosboeing/*` repositories. To use the skill elsewhere, adapt the reference file first.

## Modes

| Command | What it does |
|---|---|
| `/repo-standards check [oss\|private] [path]` | Reports gaps. Changes nothing. |
| `/repo-standards fix [oss\|private] [path]` | Reports gaps, then fixes them from `templates/default-project`, filling in the owner and repository name through `gh` |
| `/repo-standards scaffold <name> [oss\|private]` | Creates a new repository from `templates/default-project`, adding the open-source files for `oss` |

Without `oss` or `private`, the skill reads the repository's visibility with `gh repo view --json visibility`. A public repository is treated as `oss`.

| Area | Private | Open source |
|---|---|---|
| CI workflow with the `required` check | Yes | Yes |
| Action versions pinned to commit SHAs | Yes | Yes |
| `CODEOWNERS` and `dependabot.yml` | Yes | Yes |
| `docs/` tracking files | Yes | Yes |
| Drift guard Git hooks installed, with `core.hooksPath` set to `scripts/githooks` | Yes | Yes |
| Code of conduct, security, support and contributing files | No | Yes |
| Issue forms | No | Yes |
| No personal email addresses | No | Yes |

## Usage

```
/repo-standards check
/repo-standards fix oss
/repo-standards scaffold my-tool private
```

## Rules it follows

- It copies pinned commit SHAs from section 2 of the reference file and never generates one.
- `required` is the only required status check. `fix` applies branch protection only after you confirm.
- Public repositories contain no personal email address.

## Install

See [Install one skill](../README.md#install-one-skill) in the skills catalog, or run `scripts/sync-toolkit.sh --harness` to sync every skill.

`/oss-standards` is an older name for the open-source mode and forwards here.
