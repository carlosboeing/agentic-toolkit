# oss-standards

A shortcut for [`repo-standards`](../repo-standards/) in open-source mode. It forwards every call to `repo-standards` with `oss` visibility. New automation should call `repo-standards` directly.

## Usage

| Command | Same as |
|---|---|
| `/oss-standards check [path]` | `/repo-standards check oss [path]` |
| `/oss-standards fix [path]` | `/repo-standards fix oss [path]` |

To create a new repository, use `/repo-standards scaffold <name> oss`.

## Install

Install `repo-standards` as well, because this skill forwards to it. See [Install one skill](../README.md#install-one-skill) in the skills catalog, or run `scripts/sync-toolkit.sh --harness` to sync every skill.
