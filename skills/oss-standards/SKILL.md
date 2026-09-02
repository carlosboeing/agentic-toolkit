---
name: oss-standards
description: |
  Apply the OSS house standard to any carlosboeing/* repo: check or fix community health files, pinned workflows, dependabot, and branch protection. Single source is reference/reference-oss-standards.md. Use when creating a new public repo, aligning an existing repo, or auditing CI/governance drift. Deterministic - reads the reference, never generates pins.
argument-hint: "[check|fix] [path]"
---

# `oss-standards` - apply the house standard

Applies `reference/reference-oss-standards.md` to a repository. Two modes, both read that file as authority - no generated SHAs, no email.

```
  /oss-standards check [path]     audit current repo, report gaps
  /oss-standards fix [path]       audit + patch gaps, open follow-up if needed
  /oss-standards scaffold <name>  scaffold new repo from templates/default-project
  /oss-standards help             show this synopsis
  path defaults to . (cwd)
```

## Reference

Single absolute URL, the one line to update if the reference moves:

```
<OSS_STANDARD_URL> = https://github.com/carlosboeing/claude-code-resources/blob/main/reference/reference-oss-standards.md
```

## Platform tool mappings

| Action | Claude Code | Agy | Codex | Kimi | Grok | OpenCode |
|---|---|---|---|---|---|---|
| Read | Read | view_file | shell cat | Read | read_file | read |
| Write | Write | write_to_file | apply_patch | Write | write | write |
| Edit | Edit | replace_file_content | apply_patch | Edit | search_replace | edit |
| Bash | Bash | run_command | shell | Bash | run_terminal_command | bash |
| Search | Grep | grep_search | shell grep | Grep | grep | grep |

## Mode: check

1. Read `<OSS_STANDARD_URL>` via `Read` on the local clone `reference/reference-oss-standards.md` if available, else fetch the URL.
2. For `path` (repo root):
   - `grep -q gmail CODE_OF_CONDUCT.md SECURITY.md` -> fail if found
   - `test -f` each file in §1 table, report missing
   - `grep -q 3d3c42e5aac5ba805825da76410c181273ba90b1 .github/workflows/*.yml` and `8207627...` etc., report drift
   - `gh api repos/<owner>/<repo>/rulesets` or `branches/main/protection` -> `required` present
3. Render table: file | expected | found | status.

## Mode: fix

1. Run `check` first, keep gap table in context.
2. For each gap, patch in place:
   - Missing `SUPPORT.md` -> copy `templates/default-project/.github/ISSUE_TEMPLATE/*` pattern, fill `<OWNER>`/`<REPO>` from `gh repo view --json nameWithOwner`.
   - Missing health files -> copy from `templates/default-project/` (replace `<PROJECT_NAME>`).
   - SHA drift -> `Edit` with `replaceAll` to pinned SHAs from §2.
   - `gmail.com` found -> replace with `[@carlosboeing](https://github.com/carlosboeing)` + `security/advisories/new` per reference §5.
3. Do not touch `dependabot.yml` `npm` entry if repo has no `package.json` (check `test -f package.json`).
4. Branch protection: `gh api PUT repos/.../rulesets/<id>` or `PATCH .../protection/required_status_checks` to `["required"]` - require confirmation before mutating remote.
5. Summarise diff stat and CI impact, offer to `gh pr create`.

## Mode: scaffold

```
npx degit carlosboeing/claude-code-resources/templates/default-project <name>
# replace <PROJECT_NAME>, <OWNER>/<REPO> via sed, git init, first commit
```

Prefer template copy over generation - deterministic.

## Rules

- Never generate a SHA - read §2 table.
- Never write a personal email.
- Verify before claiming done: `! grep -q gmail` and `grep -q 3d3c42e`.
- Keep `CLAUDE.md` harness-neutral; do not add per-harness installer boilerplate.
