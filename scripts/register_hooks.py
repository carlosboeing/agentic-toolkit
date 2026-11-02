#!/usr/bin/env python3
"""Register the toolkit's hooks in each harness's own settings, for sync-toolkit.sh.

Usage: register_hooks.py --repo DIR --hook-dir DIR [--dry-run]

The hook scripts are already copied to --hook-dir (normally ~/.claude/hooks). This script
adds the entries that make each harness run them:

  Claude Code   ~/.claude/settings.json: resume-session-warn (UserPromptSubmit) and
                validate-mermaid (PostToolUse)
  Codex CLI     ~/.codex/hooks.json: resume-session-warn (UserPromptSubmit) and
                `rtk hook codex` (PreToolUse)
  Grok Build    ~/.grok/hooks/resume-session-warn.json (PreToolUse)
  Antigravity   ~/.gemini/config/hooks.json: resume-session-warn (PreInvocation) and
                `rtk hook antigravity` (PreToolUse)
  Muse Code     a local plugin, installed and approved with the muse CLI

The RTK entries rewrite shell commands to their `rtk` form. They are added only when `rtk`
is on PATH and its `rtk hook --help` lists that processor (RTK 0.50 and later for Codex).

Rules: an entry whose command already names the script is left as it is, so a second run
changes nothing. A settings file is copied to <file>.agentic-toolkit.bak once, before its
first change. A file that does not parse is reported and left alone. Codex hook trust is
never written; it is reported until Codex records it. A harness that is not installed is
skipped. The last output line is `changes=<n>`.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

WARN = "resume-session-warn.sh"
MERMAID = "validate-mermaid.sh"
ANTIGRAVITY_EVENTS = {"SessionStart", "PreInvocation", "PostInvocation", "PreToolUse", "PostToolUse", "Stop"}


class Run:
    def __init__(self, dry_run):
        self.dry_run = dry_run
        self.changes = 0
        self.backed_up = set()

    def say(self, label, state, detail=""):
        print(f"  • {label:<44} [{state}]" + (f" {detail}" if detail else ""))

    def change(self, label, detail=""):
        self.changes += 1
        self.say(label, "WOULD ADD" if self.dry_run else "ADDED", detail)

    def write(self, path, text):
        if self.dry_run:
            return
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists() and path not in self.backed_up:
            backup = path.with_name(path.name + ".agentic-toolkit.bak")
            if not backup.exists():
                shutil.copy2(path, backup)
            self.backed_up.add(path)
        handle, temporary = tempfile.mkstemp(dir=str(path.parent), prefix=f".{path.name}.")
        with os.fdopen(handle, "w") as out:
            out.write(text)
        if path.exists():
            shutil.copymode(path, temporary)
        os.replace(temporary, path)


def load(path, run, label):
    """The parsed JSON object, {} for a missing file, or None after reporting a bad file."""
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text() or "{}")
    except ValueError as exc:
        run.say(label, "SKIPPED", f"{path} does not parse ({exc.msg}); not changed")
        return None
    if not isinstance(data, dict):
        run.say(label, "SKIPPED", f"{path} is not a JSON object; not changed")
        return None
    return data


def dump(data):
    return json.dumps(data, indent=2) + "\n"


def names_script(command, script):
    return isinstance(command, str) and script in command


def claude_style(path, entries, run, label):
    """Merge entries into a Claude Code or Codex `hooks` map: event, then matcher groups."""
    data = load(path, run, label)
    if data is None:
        return
    hooks = data.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        run.say(label, "SKIPPED", f"`hooks` in {path} is not an object; not changed")
        return
    added = False
    for event, matcher, hook, script in entries:
        groups = hooks.setdefault(event, [])
        present = any(names_script(h.get("command"), script)
                      for g in groups if isinstance(g, dict) for h in g.get("hooks") or [] if isinstance(h, dict))
        name = f"{label}: {script.split('.')[0]}"
        if present:
            run.say(name, "OK")
            continue
        group = {"matcher": matcher, "hooks": [hook]} if matcher else {"hooks": [hook]}
        groups.append(group)
        run.change(name, f"({event})")
        added = True
    if added:
        run.write(path, dump(data))


def codex_trusted(home, events):
    """True when Codex has recorded trust for a user hook on each event, such as user_prompt_submit."""
    try:
        text = (home / ".codex" / "config.toml").read_text()
    except OSError:
        return False
    keys = [k for k in re.findall(r'^\[hooks\.state\."([^"]+)"\]', text, re.M) if "@" not in k.split(":", 1)[0]]
    return all(any(f":{event}:" in k for k in keys) for event in events)


def rtk_processors():
    """The rtk path and the hook processors its `rtk hook --help` lists, or (None, set())."""
    rtk = shutil.which("rtk")
    if not rtk:
        return None, set()
    done = subprocess.run([rtk, "hook", "--help"], capture_output=True, text=True)
    return rtk, set(re.findall(r"^\s+([a-z]+)\s", done.stdout, re.M))


def antigravity(home, run, name, spec, detail):
    label = f"Antigravity CLI: {name}"
    if not (home / ".gemini" / "antigravity-cli").is_dir():
        run.say(label, "SKIPPED", "Antigravity CLI not installed")
        return
    path = home / ".gemini" / "config" / "hooks.json"
    data = load(path, run, label)
    if data is None:
        return
    first = [k for k, v in data.items() if k in ANTIGRAVITY_EVENTS and isinstance(v, list)]
    if first:
        # Antigravity CLI 1.4.12 reads hook names at the top level. Event names there make the
        # whole file fail to parse, so no hook in it loads. The entries belong to another tool.
        run.say(label, "SKIPPED", f"{path} lists events ({', '.join(first)}) at the top level, a layout "
                                  "Antigravity cannot parse, so none of its hooks load. Not changed; "
                                  "convert those entries to `{\"<name>\": {\"<event>\": [...]}}` first")
        return
    if name in data:
        run.say(label, "OK")
        return
    data[name] = spec
    run.change(label, detail)
    run.write(path, dump(data))


def grok(home, hook_dir, run):
    label = "Grok Build: resume-session-warn"
    if not (home / ".grok").is_dir():
        run.say(label, "SKIPPED", "Grok Build not installed")
        return
    path = home / ".grok" / "hooks" / "resume-session-warn.json"
    text = dump({"hooks": {"PreToolUse": [{"matcher": "*", "hooks": [
        {"type": "command", "command": f"sh {hook_dir / WARN} grok", "timeout": 5}]}]}})
    if path.exists() and path.read_text() == text:
        run.say(label, "OK")
        return
    run.change(label, "(PreToolUse)")
    run.write(path, text)


def muse(home, repo, run):
    label = "Muse Code: resume-session-warn plugin"
    data_home = Path(os.environ.get("XDG_DATA_HOME") or home / ".local" / "share")
    muse_bin = shutil.which("muse")
    if not muse_bin or not (data_home / "muse").is_dir():
        run.say(label, "SKIPPED", "Muse Code not installed")
        return
    stage = data_home / "agentic-toolkit" / "muse-resume-session-warn"
    template = repo / "hooks" / "resume-session-warn" / "muse-plugin"
    wanted = {".muse-plugin/plugin.json": (template / ".muse-plugin" / "plugin.json").read_text(),
              f"hooks/{WARN}": (repo / "hooks" / "resume-session-warn" / WARN).read_text()}
    staged = all((stage / rel).is_file() and (stage / rel).read_text() == text for rel, text in wanted.items())
    listed = subprocess.run([muse_bin, "plugins", "list", "--json"], capture_output=True, text=True)
    try:
        # Muse 1.4.14 lists each plugin as {"record": {"id": ...}, "plugin": {...}}.
        installed = any((p.get("record") or {}).get("id") == "resume-session-warn"
                        for p in json.loads(listed.stdout or "{}").get("plugins", []) if isinstance(p, dict))
    except ValueError:
        installed = False
    if staged and installed:
        run.say(label, "OK")
        return
    run.change(label, "(UserPromptSubmit)")
    if run.dry_run:
        return
    for rel, text in wanted.items():
        (stage / rel).parent.mkdir(parents=True, exist_ok=True)
        (stage / rel).write_text(text)
    action = ["update", "resume-session-warn"] if installed else ["install", str(stage), "--scope", "user"]
    for args in (action, ["approve", "resume-session-warn"]):
        done = subprocess.run([muse_bin, "plugins", *args], capture_output=True, text=True)
        if done.returncode != 0:
            run.say(label, "FAILED", f"`muse plugins {' '.join(args)}`: {(done.stderr or done.stdout).strip()[:200]}")
            return


def main(argv=None):
    parser = argparse.ArgumentParser(description="Register the toolkit's hooks in each harness.")
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--hook-dir", required=True, type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    home = Path.home()
    run = Run(args.dry_run)
    warn, mermaid = args.hook_dir / WARN, args.hook_dir / MERMAID
    rtk, processors = rtk_processors()
    if not rtk:
        run.say("RTK rewrite hooks", "SKIPPED", "rtk not on PATH")

    if (home / ".claude").is_dir():
        claude_style(home / ".claude" / "settings.json", [
            ("UserPromptSubmit", None, {"type": "command", "command": f"sh {warn}", "timeout": 5}, WARN),
            ("PostToolUse", "Write|Edit", {"type": "command", "command": f"bash {mermaid}", "timeout": 90,
                                           "statusMessage": "Validating Mermaid blocks"}, MERMAID),
        ], run, "Claude Code")
    else:
        run.say("Claude Code", "SKIPPED", "~/.claude not present")

    if (home / ".codex").is_dir():
        entries = [("UserPromptSubmit", None, {"type": "command", "command": f"sh {warn}", "timeout": 5}, WARN)]
        events = ["user_prompt_submit"]
        if "codex" in processors:
            entries.append(("PreToolUse", "Bash", {"type": "command", "command": f"{rtk} hook codex", "timeout": 10},
                            "rtk hook codex"))
            events.append("pre_tool_use")
        elif rtk:
            run.say("Codex CLI: rtk hook codex", "SKIPPED", "this rtk has no Codex processor; upgrade to 0.50 or later")
        claude_style(home / ".codex" / "hooks.json", entries, run, "Codex CLI")
        if not codex_trusted(home, events):
            run.say("Codex CLI: hook trust", "ACTION", "open /hooks in Codex once and trust the hooks from "
                                                       "~/.codex/hooks.json; Codex skips an untrusted hook")
    else:
        run.say("Codex CLI", "SKIPPED", "~/.codex not present")

    grok(home, args.hook_dir, run)
    antigravity(home, run, "resume-session-warn", {"PreInvocation": [
        {"type": "command", "command": f"sh {warn} antigravity", "timeout": 5}]}, "(PreInvocation)")
    if "antigravity" in processors:
        antigravity(home, run, "rtk", {"PreToolUse": [{"matcher": "run_command", "hooks": [
            {"type": "command", "command": f"{rtk} hook antigravity", "timeout": 10}]}]}, "(PreToolUse)")
    muse(home, args.repo, run)
    print(f"changes={run.changes}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
