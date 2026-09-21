# Contributing to agentic-toolkit

Thank you for contributing to agentic-toolkit.

## Code of conduct

This project adheres to the Contributor Covenant [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Security disclosures

If you discover a security vulnerability, please do not open a public issue. Refer to [SECURITY.md](SECURITY.md) for private disclosure instructions.

## Contributor route (when `.workbench/` is absent)

If `.workbench/` is absent from your checkout, you are working as an outside contributor:

- Use GitHub Issues, pull requests, and public Architectural Decision Records under `docs/adrs/`.
- Do not create lifecycle directories (`docs/0-brainstorms/`, `docs/1-discovery/`, `docs/2-design/`, `docs/3-plans/`, `docs/4-reviews/`) under `docs/` or at the repository root.
- Do not create or nest a private workbench repository.
- Keep contributions focused on public artifacts: skills, hooks, rules, documentation, guides, references, templates, scripts, and tests.

### Contributor checks vs. maintainer syncing

- **Contributors**: Run the local test suites to verify changes before submitting a pull request:
  - `bash tests/test-githooks.sh`
  - `bash tests/test-sync-toolkit.sh`
  - `bash git-hooks/drift-guard/test-housekeep.sh`
  - `sh skills/schedule-resume/tests/run-tests.sh`
  - `python3 -m unittest discover -s tests -p 'test_relative_links.py'`
  - `python3 scripts/check-relative-links.py`
  - `shellcheck -S error` on modified shell scripts
- **Maintainers**: `scripts/sync-toolkit.sh` is an operator tool that syncs skills, hooks, and commands into the user's home configuration and neighboring repositories. Contributors should not run live syncing against their local environments.

## Workflow and branches

- Branch off `origin/main`:
  ```bash
  git fetch origin
  git checkout -b <branch-name> origin/main
  ```
- Keep changes surgical and focused on a single concern.
- Ensure all tests pass before submitting a pull request.
- Linear history: pull requests are squash-merged.

## Conventional Commits

Commits must follow the Conventional Commits specification:

`<type>(<scope>): <description>`

- Allowed types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`.
- Subject must be in imperative mood and 72 characters or fewer.
- Body explains the rationale (*why*, not *what*).
- Never use `#N` unless intentionally referencing a real GitHub issue.

## Pull requests

- Open a pull request against `main`.
- Follow the template in `.github/PULL_REQUEST_TEMPLATE.md`.
- All pull requests must pass the `required` status check in GitHub Actions CI.

## Continuous integration

Workflows in `.github/workflows/` are pinned to full commit SHAs with version comments. The `required` job is the stable aggregator gate. Do not replace a pinned SHA with a tag.
