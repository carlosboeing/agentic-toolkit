# Contributing to <PROJECT_NAME>

Thank you for contributing.

## Code of conduct

This project adheres to the Contributor Covenant [Code of Conduct](CODE_OF_CONDUCT.md).

## Security disclosures

If you discover a security vulnerability, please do not open a public issue. Refer to [SECURITY.md](SECURITY.md).

## Workflow and branches

- Branch off `origin/main`.
- Keep changes surgical and focused on a single concern.
- Ensure all tests and typechecks pass before submitting a pull request.

## Conventional Commits

`<type>(<scope>): <description>` - types `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`. Subject at most 72 chars, imperative mood. Body explains why.

## Pull requests

- Open a pull request against `main`.
- Follow the template in `.github/PULL_REQUEST_TEMPLATE.md`.
- All pull requests must pass the `required` CI check.
- Linear history (squash-merge).

## Continuous integration

Workflows are pinned to full commit SHAs with version comments. The `required` job is the stable aggregate. Do not replace a SHA with a tag.
