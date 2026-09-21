---
name: repo-standards
description: |
  Apply the repo house standard to any carlosboeing/* repo: check or fix community health files, pinned workflows, dependabot, and branch protection. Single source is reference/reference-oss-standards.md. Use when creating a new repo, promoting a private repo to public OSS, or auditing CI/governance drift. Deterministic - reads the reference, never generates pins.
argument-hint: "[check|fix|scaffold] [oss|private] [path|name] [help]"
---

# `repo-standards` - apply the house standard

Applies `reference/reference-oss-standards.md` to a repository. One skill for private and public - use a visibility keyword or let it auto-detect `gh repo view --json visibility`.

```
  /repo-standards check [oss|private] [path]      audit, report gaps
  /repo-standards fix [oss|private] [path]        audit + patch gaps
  /repo-standards scaffold <name> [oss|private]   scaffold from templates/default-project
  /repo-standards help                            show this synopsis

  path defaults to . (cwd)
  scaffold name is required (new directory)
  oss = public OSS (adds CODE_OF_CONDUCT, SECURITY, SUPPORT, CONTRIBUTING, LICENSE, THIRD_PARTY_NOTICES, yml forms)
  private = base only (workflows, CODEOWNERS, dependabot, docs/ lifecycle)
  Also accepted: public (= oss), help, ?, --help, -h, usage
```

## Reference

Single absolute URL, the one line to update if the reference moves:

```
<REPO_STANDARD_URL> = https://github.com/carlosboeing/agentic-toolkit/blob/main/reference/reference-oss-standards.md
```

## Platform tool mappings

| Action | Claude Code | Agy | Codex | Kimi | Grok | OpenCode |
|---|---|---|---|---|---|---|
| Read | Read | view_file | shell cat | Read | read_file | read |
| Write | Write | write_to_file | apply_patch | Write | write | write |
| Edit | Edit | replace_file_content | apply_patch | Edit | search_replace | edit |
| Bash | Bash | run_command | shell | Bash | run_terminal_command | bash |
| Search | Grep | grep_search | shell grep | Grep | grep | grep |

## How to parse the args

Walk the tokens once and bucket each one (order-independent, case-insensitive):

- **Mode keywords** (closed set): `check`, `fix`, `scaffold`. Default: `check` if no mode present.
- **Visibility keywords** (closed set): `oss`, `public` (-> oss), `private`. Default: auto-detect via `gh repo view --json visibility` if repo exists, else `private`; surface inference in first line.
- **Help keywords** (closed set): `help`, `?`, `usage`, `--help`, `-h`. If any appear, short-circuit: render Synopsis above and stop.
- **Save keywords** (not used here): none.
- **Everything else**: for `check`/`fix` -> `path` (single path, defaults to `.`); for `scaffold` -> `name` (required). If ambiguous (two paths), take last and note override.

Parser is order-independent: `/repo-standards oss fix` and `/repo-standards fix oss` are equivalent. Duplicate bucket -> use rightmost and note `Received both '<X>' and '<Y>'; using '<Y>'`.

## Modes

### check

1. Read `<REPO_STANDARD_URL>` via `Read` on local `reference/reference-oss-standards.md` if available, else fetch URL.
2. Resolve `visibility` (flag or auto-detect). State inference: `Visibility: oss (public repo)` or `Visibility: private (auto-detected)`.
3. For `path`:
   - Base (always): `grep -q 3d3c42e...` `8207627...` etc., `test -f` `CODEOWNERS`, `dependabot.yml`, `docs/` lifecycle; `required` gate present.
   - Git hooks: for the repository and `.workbench` (when `.workbench/.git` exists):
     1. `core.hooksPath` unset, or set to anything other than `scripts/githooks` (`git config --get core.hooksPath`).
     2. `scripts/githooks/pre-push` missing or not executable (`test -x scripts/githooks/pre-push`).
     3. `scripts/githooks/housekeep` missing or not executable (`test -x scripts/githooks/housekeep`).
     Reason: `core.hooksPath` is per clone, and git will not set it on clone, deliberately. Verified 2026-09-04: multiple local repositories had it unset.
   - If `oss`: additionally `! grep -q gmail` `CODE_OF_CONDUCT.md` `SECURITY.md`, `test -f` `SUPPORT.md` `SECURITY.md` `CODE_OF_CONDUCT.md` etc., yml forms `blank_issues_enabled: false`.
4. Render table: file | expected | found | status.

### fix

1. Run `check` first, keep gap table.
2. For each gap, patch:
   - Git hooks (`scripts/githooks`): for the outer repository and `.workbench` (when `.workbench/.git` exists):
     - Copy `housekeep` and `pre-push` from `<toolkit-path>/git-hooks/drift-guard/` to `scripts/githooks/`.
     - `chmod +x scripts/githooks/housekeep scripts/githooks/pre-push`.
     - `git config core.hooksPath scripts/githooks`.
   - Missing `SUPPORT.md` or yml forms -> copy `templates/default-project/.github/ISSUE_TEMPLATE/*` and `templates/default-project/SUPPORT.md`, fill `<OWNER>`/`<REPO>` via `gh repo view --json nameWithOwner`.
   - Missing health files (oss only) -> copy `templates/default-project/CODE_OF_CONDUCT.md` etc., replace `<PROJECT_NAME>`.
   - SHA drift -> `Edit` `replaceAll` to pinned SHAs from reference §2.
   - `gmail.com` found -> replace with `[@<OWNER>](https://github.com/<OWNER>)` + `security/advisories/new` per §5.
3. Do not touch `dependabot.yml` `npm` if no `package.json`.
4. Branch protection: `gh api .../rulesets` -> `["required"]` only after confirmation.
5. Summarise diff stat, CI impact, offer `gh pr create`.

### scaffold

```
npx degit carlosboeing/agentic-toolkit/templates/default-project <name>
# if oss: cp templates/default-project-oss extra files or run fix oss on new dir
# replace <PROJECT_NAME>, <OWNER>/<REPO> via sed, git init, first commit
```

Prefer template copy over generation - deterministic.

## Rules

- Never generate a SHA - read reference §2.
- Never write a personal email.
- Verify before claiming done: `! grep -q gmail` and `grep -q 3d3c42e`.
- Keep `CLAUDE.md` harness-neutral.
