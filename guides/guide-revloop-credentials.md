---
title: Which revloop credentials do I need?
type: guide
scope: [revloop, github-actions, credentials, github-apps, deploy-keys, ci-cd]
authors:
  - "Carlos Boeing"
  - "claude-opus-5 (claude-code)"
  - "gpt-5.6-codex (codex)"
last_reviewed: 2026-08-11
related:
  - ../docs/2-design/2026-08-10-cross-model-pr-review-loop-design.md
---

# Which revloop credentials do I need?

Local revloop uses logins you already have. Automated revloop uses GitHub Actions secrets. Start with the table below, then use the credential map to see what each value contains and where it lives.

## Start with how you run revloop

The credential model depends on where the revloop command runs:

- **Local CLI or harness skill**: no Actions secrets. revloop uses your `gh` login and the selected harness's login
- **GitHub-hosted Actions runner**: three secrets are always required, plus the credentials for the configured harnesses
- **Self-hosted Actions runner**: the same three automation secrets are required, but harnesses use their existing logins on the runner

A self-hosted runner is still automated mode. It removes copied harness logins, not the GitHub credentials used by the workflows.

## Find your exact secret set

Each row below is a complete set. Secrets in one row are not alternatives.

| Configuration | Required GitHub Actions secrets |
|---|---|
| Local CLI or skill-invoked run | None |
| GitHub-hosted, Claude subscription on both legs | `APP_ID`, `APP_PRIVATE_KEY`, `REVLOOP_SOURCE_KEY`, `CLAUDE_CODE_OAUTH_TOKEN` |
| GitHub-hosted, one Claude subscription leg and one Codex subscription leg | `APP_ID`, `APP_PRIVATE_KEY`, `REVLOOP_SOURCE_KEY`, `CLAUDE_CODE_OAUTH_TOKEN`, `REVLOOP_CODEX_AUTH`, `REVLOOP_REFRESH_APP_ID`, `REVLOOP_REFRESH_APP_PRIVATE_KEY` |
| GitHub-hosted, Codex subscription on both legs | `APP_ID`, `APP_PRIVATE_KEY`, `REVLOOP_SOURCE_KEY`, `REVLOOP_CODEX_AUTH`, `REVLOOP_REFRESH_APP_ID`, `REVLOOP_REFRESH_APP_PRIVATE_KEY` |
| Self-hosted, both legs use harness logins already on the runner | `APP_ID`, `APP_PRIVATE_KEY`, `REVLOOP_SOURCE_KEY` |

Two legs using the same harness share one harness credential. Any GitHub-hosted Codex leg adds the Codex secret and both refresher App secrets.

Run `revloop init --dry-run` for the exact list derived from your current configuration. It prints the plan without changing anything.

## Know what each secret contains

This table covers every secret the resolver can request:

| Secret | Value | Stored where | Needed when |
|---|---|---|---|
| `APP_ID` | Numeric ID of the loop App | Organisation secret when available, otherwise a repository secret | Every automated setup |
| `APP_PRIVATE_KEY` | Loop App RSA private key in PEM format | Same Actions scope as `APP_ID` | Every automated setup |
| `REVLOOP_SOURCE_KEY` | Private half of the read-only SSH deploy key for the revloop source repository | Organisation or repository secret available to the consuming repository | Every automated setup |
| `CLAUDE_CODE_OAUTH_TOKEN` | Claude subscription token from `claude setup-token` | Organisation or repository secret | A GitHub-hosted leg uses Claude by subscription |
| `REVLOOP_CODEX_AUTH` | Complete Codex `auth.json`, including access and refresh tokens | Repository secret only | A GitHub-hosted leg uses Codex by subscription |
| `REVLOOP_REFRESH_APP_ID` | Numeric ID of the refresher App | Repository secret only | A GitHub-hosted leg uses Codex by subscription |
| `REVLOOP_REFRESH_APP_PRIVATE_KEY` | Refresher App RSA private key in PEM format | Repository secret only | A GitHub-hosted leg uses Codex by subscription |
| Endpoint `token_env`, such as `KIMI_API_KEY` | Static token accepted by that endpoint | Shell environment locally, Actions secret in CI | A leg names that endpoint |

`revloop auth login` also stores each App's PEM and metadata under `~/.config/revloop/apps/`. revloop uses those local files for setup, status checks and key rotation. CI receives copies through the Actions secrets above.

## Understand the three secrets every automated setup needs

Every generated workflow needs a GitHub identity and access to revloop's source.

### The loop App writes to GitHub

`APP_ID` and `APP_PRIVATE_KEY` identify the loop App. Each job exchanges them for a one-hour installation token, uses that token as `GH_TOKEN`, then revokes it.

The loop App has three repository permissions:

| Permission | Purpose |
|---|---|
| `contents: write` | Push fixes |
| `pull_requests: write` | Comment, reply and resolve threads |
| `issues: write` | Apply pull request labels and file issues |

revloop does not use the default `GITHUB_TOKEN` for writes that advance the loop. GitHub does not trigger another workflow from those writes, so the loop would stop after one leg. Read-only workflow operations may still use the default token.

### The source deploy key fetches revloop

The workflows fetch revloop from its private source repository. Neither the loop App token nor the consuming repository's default token is assumed to reach that repository.

The deploy key has two halves:

| Half | Location |
|---|---|
| Public | The revloop source repository's **Deploy keys** page, marked read-only |
| Private | The consuming repository or organisation's `REVLOOP_SOURCE_KEY` Actions secret |

The consuming repository's **Deploy keys** page should therefore be empty unless it has unrelated keys. `revloop init` reports a missing source key and prints the commands to create it.

## Add a harness credential on GitHub-hosted runners

GitHub-hosted runners are disposable. Each run restores the selected harness credential from a secret.

| Route | Secret | Access-token lifetime | Result |
|---|---|---:|---|
| Claude subscription | `CLAUDE_CODE_OAUTH_TOKEN` | 365 days | Supported directly |
| Codex subscription | `REVLOOP_CODEX_AUTH` | 864,000 seconds, or 10 days | Supported with the refresher App |
| Antigravity subscription | None supported | About 1 hour | Use a self-hosted runner |
| Named endpoint | The variable named by `token_env` | Vendor-dependent | Requires a static token |

revloop has adapters for Claude, Codex and Antigravity. Kimi is reached through the Claude adapter as a named endpoint. Kimi's installed OAuth credential lasts 900 seconds, so it cannot serve as a static hosted secret.

Local and self-hosted runs use each harness's normal login. For example, Codex reads `~/.codex/auth.json` on those machines.

## Understand why Codex needs a second App

Codex refresh tokens rotate. A refresh can invalidate the copy another job holds, so review and address jobs never update the stored credential.

The refresher workflow is the only writer. It exchanges the refresher App ID and private key for a short-lived token with `secrets: write`. That workflow does not read pull request code, diffs or comments.

Keep both Codex-specific credentials at repository scope:

- `REVLOOP_CODEX_AUTH` cannot be shared across repositories because GitHub concurrency groups are repository-scoped
- `REVLOOP_REFRESH_APP_PRIVATE_KEY` must not be exposed to every workflow through an organisation secret

Each repository needs its own `codex login` seed. A review or address job restores a temporary copy, runs Codex, then deletes the copy.

## Know what the skills can access

Calling revloop through a harness skill does not change its credential model. The orchestrator still owns GitHub access.

The `pr-review` and `pr-address` skills receive the diff and other context from the orchestrator. They receive no GitHub token and make no GitHub call. The adapters also remove `GH_TOKEN`, `GITHUB_TOKEN` and `GH_ENTERPRISE_TOKEN` before starting the model-facing process.

## Set up the credentials

Use this order:

1. Run `revloop auth login` to create and install the loop App
2. Run `revloop init --dry-run` to see the exact files, labels and secrets required by the current pairing
3. Run `revloop init` to write the workflows and set values revloop already holds
4. Supply any values still reported as missing

The remaining values depend on the pairing:

- **Source deploy key**: create the key pair, register its public half on the source repository, then set `REVLOOP_SOURCE_KEY`
- **Claude**: interactive `revloop init` can run `claude setup-token` and store the result without printing it
- **Codex**: run `codex login`, then seed `REVLOOP_CODEX_AUTH` from `~/.codex/auth.json`
- **Endpoint**: set the variable named by its `token_env`

Run `revloop init --dry-run` again after changing a runner, harness or endpoint. The required set changes with the pairing.

> [!WARNING]
> `revloop init` detects endpoint secret names, but the generated review and address workflows do not yet map arbitrary endpoint secrets into the leg environment. Automated endpoint use needs a manual workflow `env` mapping. Local endpoint use only needs the variable in your shell.
