---
title: OSS repository house standard
type: reference
scope: [oss-governance, ci-cd, community-health, harness-parity]
last_reviewed: 2026-09-02
authors:
  - "Carlos Boeing"
  - "muse-spark-1.2 (opencode)"
related:
  - guides/guide-project-structure-and-conventions.md
  - guides/guide-cross-harness-project-instructions.md
  - templates/default-project/
  - reference/reference-build-and-release-standards.md
---

# OSS repository house standard

> This is the maintainer's house standard for `carlosboeing/*` repositories. To use it elsewhere, replace the owner, contacts and pinned versions with your own.

Checklist for any `carlosboeing/*` public repository. Derived from `copydesk` `2b9a29d`, `penmark` `a643c07`, `quotacap` `de7d220`, `crossrev` `953a64d` (2026-09-02). One source, not per-repo folklore.

## How to use

- **New repo**: `npx degit carlosboeing/agentic-toolkit/templates/default-project-oss <name>` - already contains this checklist's files.
- **Existing repo**: `skill oss-standards` or read this file and run `check` -> `fix`. CI fails if checklist is not met (see `required` gate).

No personal email anywhere. Contact is `https://github.com/carlosboeing` + private advisory `https://github.com/<owner>/<repo>/security/advisories/new`.

## 1. Community health files (must exist at repo root)

| File | Must contain | Example source after 2026-09-02 |
|---|---|---|
| `CODEOWNERS` | `* @carlosboeing` + comment | `copydesk/.github/CODEOWNERS:1` |
| `CODE_OF_CONDUCT.md` | Covenant v2.1, enforcement via private advisory or `@carlosboeing`, **no `gmail.com`** | `penmark/CODE_OF_CONDUCT.md:39` (fixed) |
| `SECURITY.md` | Supported table (`0.5.x Yes`), reporting via `Security -> Report a vulnerability` + `@carlosboeing` fallback, no email | `crossrev/SECURITY.md:12` |
| `SUPPORT.md` | Issue tracker link, bug/feature forms, no secrets -> `SECURITY.md` | `copydesk/SUPPORT.md:1` |
| `CONTRIBUTING.md` | Conventional Commits, branch off `origin/main`, mentions `required` gate | `penmark/CONTRIBUTING.md:85` |
| `THIRD_PARTY_NOTICES.md` | If bundled deps exist, list packages + full license texts; if none, state `none` | `quotacap/THIRD_PARTY_NOTICES.md:1` |
| `.github/ISSUE_TEMPLATE/bug_report.yml` | Structured form, required fields | `penmark/.github/ISSUE_TEMPLATE/bug_report.yml:1` |
| `.github/ISSUE_TEMPLATE/feature_request.yml` | Structured form | `copydesk/.github/ISSUE_TEMPLATE/feature_request.yml:1` |
| `.github/ISSUE_TEMPLATE/config.yml` | `blank_issues_enabled: false` + `Security vulnerability` -> `security/advisories/new`, `Support` -> `SUPPORT.md` | `copydesk/.github/ISSUE_TEMPLATE/config.yml:1` |
| `.github/PULL_REQUEST_TEMPLATE.md` | Summary, Changes, Verification, Governance Checklist | `penmark/.github/PULL_REQUEST_TEMPLATE.md:22` |
| `LICENSE` | MIT | - |

## 2. Workflows - pinned, least-privilege, stable gate

| Rule | Value | Verified |
|---|---|---|
| `actions/checkout` | `3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1` | `gh api repos/actions/checkout/git/refs/tags/v7.0.1` |
| `actions/setup-node` | `820762786026740c76f36085b0efc47a31fe5020 # v7.0.0` | `v7.0.0` |
| `actions/setup-python` | `5fda3b95a4ea91299a34e894583c3862153e4b97 # v7.0.0` | `v7.0.0` |
| `actions/upload-artifact` | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1` | `v7.0.1` |
| `oven-sh/setup-bun` | `0c5077e51419868618aeaa5fe8019c62421857d6 # v2.2.0` | `v2.2.0` |
| Other pins | Keep `# vX.Y.Z` comment beside SHA | - |

Workflow hygiene:

- Top-level `permissions: contents: read`, per-job least privilege, `concurrency` group `ci-${{ github.ref }}` `cancel-in-progress: true` on CI, `concurrency: release-${{ github.ref }}` `cancel-in-progress: false` on release.
- `timeout-minutes` on every job.
- One aggregator job named `required` with `if: always()` and `needs.*.result` checks (`skipped` allowed only for `changelog` on push to `main` where `crossrev` `changelog` is PR-only). This is the only `required_status_checks` entry.

## 3. Dependabot

| Ecosystem | When |
|---|---|
| `github-actions` `/` weekly | Always |
| `npm` `/` weekly | If `package.json` exists (exact-pinned, `npm i -E` per `penmark`) |

Example: `penmark/.github/dependabot.yml:1` (groups `minor-and-patch`, ignores `@types/vscode`).

## 4. Branch protection (ruleset)

| Rule | Value |
|---|---|
| `deletion` | block |
| `non_fast_forward` | block |
| `required_linear_history` | enabled |
| `pull_request` | `required_approving_review_count: 0`, `require_code_owner_review: false`, `required_review_thread_resolution: false` |
| `required_status_checks` | `["required"]` `strict: true` |

Classic branch protection `required_status_checks` `["required"]` is equivalent. Do not require granular jobs.

## 5. Contact - no email

- `SECURITY.md` and `CODE_OF_CONDUCT.md` must not contain `gmail.com` or personal email. Verification: `! grep -q gmail CODE_OF_CONDUCT.md SECURITY.md`.
- Private reports: `https://github.com/<owner>/<repo>/security/advisories/new` or `https://github.com/carlosboeing`.

## 6. How to verify

```bash
test -f SUPPORT.md && ! grep -q gmail CODE_OF_CONDUCT.md SECURITY.md && grep -q 3d3c42e .github/workflows/*.yml && grep -q required .github/workflows/*.yml
gh api repos/<owner>/<repo>/rulesets --jq '.[].rules[] | select(.type=="required_status_checks")'
```

Reference implementation: `copydesk@2b9a29d` (Python), `penmark@a643c07` (Node VSIX) after 2026-09-02.
