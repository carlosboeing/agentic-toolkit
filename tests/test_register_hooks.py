#!/usr/bin/env python3
"""Tests for scripts/register_hooks.py: every hook is registered once, a dry run writes
nothing, a second run changes nothing, and files it cannot parse are left alone.

Run with: python3 -m unittest tests/test_register_hooks.py
"""

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCRIPT = REPO / "scripts" / "register_hooks.py"

FAKE_MUSE = """#!/bin/sh
# Fake muse: logs each call and keeps an installed flag.
echo "$*" >> "$HOME/muse-calls.log"
if [ "$1 $2" = "plugins list" ]; then
  if [ -f "$HOME/muse-installed" ]; then echo '{"plugins": [{"record": {"id": "resume-session-warn"}}]}'; else echo '{"plugins": []}'; fi
fi
if [ "$1 $2" = "plugins install" ]; then touch "$HOME/muse-installed"; fi
exit 0
"""

FAKE_RTK = """#!/bin/sh
# Fake rtk: lists the hook processors RTK 1.1 has, and writes $FAKE_AWARENESS as the agent
# text of the Antigravity plugin that `rtk init -g --agent antigravity` installs.
if [ "$1 $2" = "hook --help" ]; then printf 'Commands:\\n  claude  x\\n  codex  x\\n  antigravity  x\\n  opencode  x\\n'; fi
if [ "$1 $2 $3 $4" = "init -g --agent antigravity" ]; then
  mkdir -p "$HOME/.gemini/config/plugins/rtk/rules"
  cat "$FAKE_AWARENESS" > "$HOME/.gemini/config/plugins/rtk/rules/AGENTS.md"
fi
exit 0
"""


class RegisterCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name).resolve()
        for folder in (".claude/hooks", ".codex", ".grok", ".gemini/antigravity-cli", ".local/share/muse", "bin"):
            (self.home / folder).mkdir(parents=True)
        muse = self.home / "bin" / "muse"
        muse.write_text(FAKE_MUSE)
        muse.chmod(0o755)
        self.hooks = self.home / ".claude" / "hooks"
        self.env = {"HOME": str(self.home), "PATH": f"{self.home / 'bin'}:/usr/bin:/bin"}

    def tearDown(self):
        self.tmp.cleanup()

    def register(self, *extra):
        done = subprocess.run([sys.executable, str(SCRIPT), "--repo", str(REPO), "--hook-dir", str(self.hooks), *extra],
                              env=self.env, capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stderr)
        return done.stdout

    def changes(self, out):
        return int(out.strip().splitlines()[-1].split("=")[1])

    def json(self, rel):
        return json.loads((self.home / rel).read_text())

    def state(self):
        # ~/Library is left out: Apple's Python 3.9 writes its own bytecode cache there.
        library = self.home / "Library"
        return {str(p): p.read_bytes() for p in self.home.rglob("*")
                if p.is_file() and p.name != "muse-calls.log" and library not in p.parents}

    def commands(self, data, event):
        return [h["command"] for g in data["hooks"][event] for h in g["hooks"]]


class RegisterTests(RegisterCase):
    def test_first_run_registers_every_hook(self):
        out = self.register()
        self.assertEqual(self.changes(out), 7, out)
        claude = self.json(".claude/settings.json")
        self.assertEqual(self.commands(claude, "UserPromptSubmit"), [f"sh {self.hooks}/resume-session-warn.sh"])
        self.assertEqual(self.commands(claude, "PostToolUse"), [
            f"bash {self.hooks}/validate-mermaid.sh",
            f"bash {self.hooks}/validate-frontmatter.sh",
        ])
        codex = self.json(".codex/hooks.json")
        self.assertEqual(self.commands(codex, "UserPromptSubmit"), [f"sh {self.hooks}/resume-session-warn.sh"])
        grok = self.json(".grok/hooks/resume-session-warn.json")
        self.assertEqual(self.commands(grok, "PreToolUse"), [f"sh {self.hooks}/resume-session-warn.sh grok"])
        agy = self.json(".gemini/config/hooks.json")
        self.assertEqual(agy["resume-session-warn"]["PreInvocation"][0]["command"],
                         f"sh {self.hooks}/resume-session-warn.sh antigravity")
        calls = (self.home / "muse-calls.log").read_text()
        self.assertIn("plugins install", calls)
        self.assertIn("plugins approve resume-session-warn", calls)
        stage = self.home / ".local/share/agentic-toolkit/muse-resume-session-warn"
        self.assertTrue((stage / "hooks/resume-session-warn.sh").is_file())
        self.assertIn("open /hooks in Codex", out)

    def test_second_run_changes_nothing(self):
        self.register()
        before = self.state()
        out = self.register()
        self.assertEqual(self.changes(out), 0, out)
        self.assertEqual(self.state(), before)
        self.assertNotIn("plugins install", (self.home / "muse-calls.log").read_text().split("plugins approve")[-1])

    def test_dry_run_writes_nothing(self):
        before = self.state()
        out = self.register("--dry-run")
        self.assertEqual(self.changes(out), 7, out)
        self.assertIn("WOULD ADD", out)
        self.assertEqual(self.state(), before)
        self.assertNotIn("install", (self.home / "muse-calls.log").read_text())

    def test_existing_entries_are_kept_and_backed_up_once(self):
        settings = self.home / ".claude" / "settings.json"
        original = {"model": "x", "hooks": {"PostToolUse": [{"matcher": "Write|Edit", "hooks": [
            {"type": "command", "command": "bash /elsewhere/validate-mermaid.sh"}]}]}}
        settings.write_text(json.dumps(original))
        self.register()
        data = self.json(".claude/settings.json")
        self.assertEqual(data["model"], "x")
        self.assertEqual(self.commands(data, "PostToolUse"), [
            "bash /elsewhere/validate-mermaid.sh",
            f"bash {self.hooks}/validate-frontmatter.sh",
        ])
        backup = settings.with_name("settings.json.agentic-toolkit.bak")
        self.assertEqual(json.loads(backup.read_text()), original)

    def test_unparseable_files_are_left_alone(self):
        settings = self.home / ".claude" / "settings.json"
        settings.write_text("{not json")
        agy = self.home / ".gemini" / "config" / "hooks.json"
        agy.parent.mkdir(parents=True)
        event_first = {"PreInvocation": [{"matcher": "*", "hooks": [{"name": "other", "type": "command", "command": "x"}]}]}
        agy.write_text(json.dumps(event_first))
        out = self.register()
        self.assertEqual(settings.read_text(), "{not json")
        self.assertEqual(json.loads(agy.read_text()), event_first)
        self.assertIn("does not parse", out)
        self.assertIn("a layout Antigravity cannot parse", out)

    def test_name_first_antigravity_file_is_merged(self):
        agy = self.home / ".gemini" / "config" / "hooks.json"
        agy.parent.mkdir(parents=True)
        agy.write_text(json.dumps({"other": {"PreToolUse": [{"type": "command", "command": "x"}]}}))
        self.register()
        self.assertEqual(sorted(json.loads(agy.read_text())), ["other", "resume-session-warn"])

    def test_missing_harnesses_are_skipped(self):
        for folder in (".codex", ".grok", ".gemini", ".local/share/muse"):
            shutil.rmtree(self.home / folder)
        out = self.register()
        self.assertEqual(self.changes(out), 3, out)
        for name in ("Codex CLI", "Grok Build", "Antigravity CLI", "Muse Code"):
            self.assertRegex(out, rf"{name}.*\[SKIPPED\]")

    def test_codex_trust_is_reported_until_recorded(self):
        out = self.register()
        self.assertIn("ACTION", out)
        (self.home / ".codex" / "config.toml").write_text(
            '[hooks.state."user:hooks.json:user_prompt_submit:0:0"]\ntrusted_hash = "sha256:x"\n')
        self.assertNotIn("ACTION", self.register())

    def test_rtk_is_skipped_when_absent(self):
        out = self.register()
        self.assertRegex(out, r"RTK.*\[SKIPPED\] rtk not on PATH")
        self.assertNotIn("PreToolUse", self.json(".codex/hooks.json")["hooks"])


class RtkTests(RegisterCase):
    def setUp(self):
        super().setUp()
        self.rtk = self.home / "bin" / "rtk"
        self.rtk.write_text(FAKE_RTK)
        self.rtk.chmod(0o755)
        self.env["FAKE_AWARENESS"] = str(REPO / "scripts" / "rtk-awareness.snapshot.md")
        (self.home / ".config" / "opencode").mkdir(parents=True)

    def test_codex_rtk_hook_is_registered(self):
        out = self.register()
        self.assertEqual(self.changes(out), 8, out)
        codex = self.json(".codex/hooks.json")
        self.assertEqual(codex["hooks"]["PreToolUse"], [
            {"matcher": "Bash", "hooks": [{"type": "command", "command": f"{self.rtk} hook codex", "timeout": 10}]}])
        self.assertNotIn("rtk", self.json(".gemini/config/hooks.json"))
        self.assertEqual(self.changes(self.register()), 0)

    def test_missing_rtk_plugins_are_reported(self):
        out = self.register()
        self.assertRegex(out, r"Antigravity CLI: RTK plugin.*\[ACTION\] run `rtk init -g --agent antigravity`")
        self.assertRegex(out, r"OpenCode: RTK plugin.*\[ACTION\] run `rtk init -g --opencode --hook-only`")
        (self.home / ".gemini/config/plugins/rtk").mkdir(parents=True)
        (self.home / ".gemini/config/plugins/rtk/hooks.json").write_text("{}")
        (self.home / ".config/opencode/plugins").mkdir(parents=True)
        (self.home / ".config/opencode/plugins/rtk.ts").write_text('run(["hook", "opencode"]) // rtk hook opencode')
        out = self.register()
        self.assertRegex(out, r"Antigravity CLI: RTK plugin.*\[OK\]")
        self.assertRegex(out, r"OpenCode: RTK plugin.*\[OK\]")

    def test_changed_rtk_instructions_are_reported(self):
        self.assertRegex(self.register(), r"RTK agent instructions.*\[OK\]")
        changed = self.home / "changed.md"
        changed.write_text("# Command output\n\nNew wording.\n")
        self.env["FAKE_AWARENESS"] = str(changed)
        self.assertRegex(self.register(), r"RTK agent instructions.*\[ACTION\]")
        self.assertFalse((self.home / ".gemini/config/plugins/rtk").exists())

    def test_existing_rtk_entries_are_kept(self):
        codex = self.home / ".codex" / "hooks.json"
        codex.write_text(json.dumps({"hooks": {"PreToolUse": [
            {"matcher": "Bash", "hooks": [{"type": "command", "command": "rtk hook codex"}]}]}}))
        self.register()
        self.assertEqual(self.commands(self.json(".codex/hooks.json"), "PreToolUse"), ["rtk hook codex"])

    def test_rtk_without_codex_processor_is_skipped(self):
        self.rtk.write_text("#!/bin/sh\nprintf 'Commands:\\n  claude  x\\n'\n")
        out = self.register()
        self.assertRegex(out, r"Codex CLI: rtk hook codex.*\[SKIPPED\]")
        self.assertNotIn("PreToolUse", self.json(".codex/hooks.json")["hooks"])

    def test_codex_trust_covers_the_rtk_hook(self):
        (self.home / ".codex" / "config.toml").write_text(
            '[hooks.state."user:hooks.json:user_prompt_submit:0:0"]\ntrusted_hash = "sha256:x"\n')
        self.assertIn("Codex CLI: hook trust", self.register())
        (self.home / ".codex" / "config.toml").write_text(
            '[hooks.state."user:hooks.json:user_prompt_submit:0:0"]\ntrusted_hash = "sha256:x"\n'
            '[hooks.state."user:hooks.json:pre_tool_use:0:0"]\ntrusted_hash = "sha256:y"\n')
        self.assertNotIn("Codex CLI: hook trust", self.register())


if __name__ == "__main__":
    unittest.main()
