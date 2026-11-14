# browser-profile

Lets an agent work inside one of your signed-in Chrome profiles when you ask in ordinary words, for example "using my work Chrome profile, export the mailbox list from the admin console". You do not name an MCP server or an automation framework. The agent loads the skill when a request names a Chrome profile or needs a site you are signed in to.

## How it works

- **Connection:** the [Playwright extension](https://github.com/microsoft/playwright/blob/main/packages/extension/README.md), driven by the Playwright CLI (`@playwright/cli`). The extension connects an agent to your running Chrome, in the profile where the extension is installed.
- **Confirmation:** each connection opens a page in that profile and waits for you to click **Allow**. No token is stored, so an agent cannot connect without that click.
- **Profile choice:** a file on your machine maps a short name such as `work` to a Chrome profile directory. The helper refuses a profile that has no entry.
- **Helper:** `scripts/browser-profile.sh` resolves the name, checks that the extension is installed in that profile, connects, and confirms that the session reached your Chrome and not a new empty browser.
- **Notification:** when the helper starts waiting, it raises a desktop notification that names the profile, so the request for your click does not depend on the agent's message. It uses `osascript` on macOS and `notify-send` on Linux.
- **Page output:** snapshots hold content from signed-in sites. The helper sends them to a private folder per session under `~/.local/state/agentic-toolkit/browser-profile/` and deletes it on close. A folder left by a session that was never closed is removed after a day.

Several agent sessions can use one profile at the same time. Each session sees only its own tabs.

## What it protects and what it does not

| It does | It does not |
|---|---|
| Require your Allow click for every new connection | Limit which sites a session visits after you approve |
| Refuse a profile that has no alias or no extension | Hide the profile's cookies. An approved session can read every cookie in that profile |
| Remove inherited settings that would redirect the connection or skip the click | Stop an agent with shell access from ignoring the skill's rules |
| Cancel a connection nobody approved within the wait | Close the leftover connect page after a cancelled wait |
| Keep page snapshots out of the project folder | Stop an agent from copying page content elsewhere |

Two consequences follow. Install the extension only in profiles that hold the accounts an agent needs, and keep it out of personal profiles. The rules for an approved session, such as asking before an email is sent or a DNS record changes, are instructions the agent follows and not a technical barrier.

The extension's connect page also warns that an approved client may be able to reconnect later without the dialog. To end that, rotate the token on the extension's Manage clients page and restart Chrome.

## Requirements

- Google Chrome with the [Playwright Extension](https://chromewebstore.google.com/detail/playwright-extension/mmlmfjhmonkocbjadbfplnigmagldckm) in each profile you want to use.
- Playwright CLI 0.1.24 or later: `npm install -g @playwright/cli@latest`.
- Bash, on macOS or Linux.

## Setup

Create `~/.config/agentic-toolkit/browser-profiles.conf`:

```text
# alias = Chrome profile directory | label
work = Profile 3 | Example Pty admin consoles
```

The profile directory is the last part of "Profile Path" at `chrome://version`. The label is free text that the agent shows you before it connects.

Check the result:

```bash
bash skills/browser-profile/scripts/browser-profile.sh check
```

Each alias should report `ready`, and no `fix:` line should appear.

You can also ask the agent to do the setup with you, for example "set up my work Chrome profile for browser-profile". The skill tells it to find every gap, explain each one, and take you through them one at a time. It asks before it installs the CLI or adds an alias, and it cannot install the extension for you.

## Commands

```text
browser-profile.sh list
browser-profile.sh open <alias> [session]
browser-profile.sh close <session> [--close-tabs]

browser-profile.sh check [alias]
browser-profile.sh profiles
browser-profile.sh install-extension <alias>
```

The last three are for setup. `check` reports every requirement and prints a `fix:` line under each gap. `profiles` lists the Chrome profiles on the machine by directory and Chrome's display name, never by account address. `install-extension` opens the extension's Chrome Web Store page in the aliased profile, where you click "Add to Chrome".

| Variable | Default | Purpose |
|---|---|---|
| `BROWSER_PROFILE_CONF` | `~/.config/agentic-toolkit/browser-profiles.conf` | Alias file |
| `BROWSER_PROFILE_CLI` | `playwright-cli` | Playwright CLI command |
| `BROWSER_PROFILE_WAIT` | `100` | Seconds to wait for the Allow click |
| `BROWSER_PROFILE_IDLE_MS` | `1800000` | Detach after this long without a command |
| `BROWSER_PROFILE_CHROME_DIR` | Per platform | Chrome user data directory |
| `BROWSER_PROFILE_NOTIFY` | `1` | `0` switches the desktop notification off |

## Harness notes

| Harness | Status |
|---|---|
| Claude Code | Works. Claude Code sets `PLAYWRIGHT_MCP_ISOLATED` for its commands, which would silently replace the profile with an empty browser. The helper removes it |
| Codex | Works outside the sandbox. The workspace sandbox blocks the Playwright CLI from writing its session files, and the helper then fails with `EPERM` and leaves nothing behind |
| Others | Not tested. The helper needs only a shell |

## Tests

```bash
python3 -m unittest tests.test_browser_profile
```

The tests replace the Playwright CLI with a recording stub, so no browser starts.

## Install

See [Install one skill](../README.md#install-one-skill) in the skills catalog, or run `scripts/sync-toolkit.sh --harness` to sync every skill.
