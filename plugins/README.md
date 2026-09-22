# Plugins

Plugin bundles and the tools that install them across harnesses. A plugin carries its own skills, hooks and commands, so keep each bundle whole here rather than splitting it into `skills/` or `hooks/`.

## Catalog

| Entry | Purpose |
|---|---|
| [`install-superpowers.sh`](install-superpowers.sh) | Installs, upgrades and reports the version of [Superpowers](https://github.com/obra/superpowers) in every supported harness |

## `install-superpowers.sh`

Each harness installs its own copy of Superpowers, and the copies drift apart without any error. One machine ended up with six copies across three versions.

The script uses each harness's official install command, always pointing at the public upstream repository, and compares each installed version with the latest upstream release. Nothing is installed from a local checkout.

```
./plugins/install-superpowers.sh            # report the version per harness
./plugins/install-superpowers.sh install    # install or upgrade where a CLI exists
```

### What each harness supports

| Harness | Install path | Version source |
|---|---|---|
| Claude Code | `claude plugin marketplace update` | `installPath` from `installed_plugins.json`, else the marketplace cache |
| Codex | `codex plugin marketplace add obra/superpowers` and `codex plugin add` | cache slot manifest |
| Antigravity | `agy plugin install <repo url>` | `~/.gemini/config/plugins/superpowers` |
| OpenCode | `plugin` array entry in `opencode.json`, checked rather than written | the declaration, plus the managed package under `~/.cache/opencode` |
| Cursor | No plugin CLI. The script prints the manual step | cache slot manifest |
| Kimi Code | TUI only, `/plugins install`. The script prints the manual step | `~/.kimi-code/plugins/managed` |
| Grok | Nothing to install. It reads Claude Code's plugin tree | not probed |

Two harnesses cannot be automated. The script names the exact manual step for each rather than skipping them quietly.

OpenCode is a third case, and it counts against the exit status. The script will not rewrite a config file the user maintains, so it reports the line to add. Because it can see whether the declaration is there, an OpenCode without one fails `install` rather than passing it with a note.

### Drift has a direction

A harness ahead of the latest upstream tag is a different problem from one behind it. The report distinguishes `ahead`, `behind`, `current`, and `absent`, because the fix differs.

Two version schemes need care. Claude Code installs through `obra/superpowers-marketplace`, a separate repository that versions independently. Its cache directory is named for the marketplace version, while the package inside carries the plugin's own. Only the package number compares with an upstream tag, so that is what the report reads.

### Why not links to a local clone

An earlier script linked a local Superpowers clone into each harness's plugin cache. Harness commands overwrote those links, and the script reported no versions, so broken installs went unnoticed. Every harness now installs from upstream releases instead.

### Two traps this script exists to avoid

A marketplace can be registered against a local path rather than upstream. Upgrading it then returns that path's version forever, and the report shows a harness as current when it is not. The Codex path checks the marketplace root, not its name, and re-adds from upstream when the root is wrong.

A harness can hold two copies at different versions. Antigravity carries one under `config/plugins`, written by `agy plugin install`, and can carry a stale Gemini CLI import under `extensions`. The report names the second when it disagrees.

### A version on disk is not an install

Two harnesses can show a version for something that does not work, and both are checked rather than trusted.

Antigravity keeps `package.json` after a part-way `agy plugin install`, with no skills beside it. OpenCode's package cache survives removing the `plugin` declaration that populated it. In each case the probe requires the thing the install exists to deliver. That is the skills directory for Antigravity, and the declaration for OpenCode.
