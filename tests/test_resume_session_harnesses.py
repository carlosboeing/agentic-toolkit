#!/usr/bin/env python3
"""Tests for the OpenCode, Antigravity CLI, Grok Build, and Muse Code readers, the hidden
current session, and the candidate titles.

Run with: python3 -m unittest discover -s tests -p 'test_resume_session_*.py'
"""

import json
import os
import re
import sys
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from resume_session_support import (  # noqa: E402
    STORY_REQUEST, TEST_COMMAND, Sandbox, antigravity_store, claude_records, claude_transcript, grok_store,
    muse_store, opencode_store)

IDS = {"opencode": "ses_fixture1", "antigravity": "aaaaaaaa-0000-4000-8000-000000000001",
       "grok": "01a00000-0000-7000-8000-000000000001", "muse": "01a00000-0000-7000-8000-0000000000aa"}
NAMES = {"opencode": "OpenCode", "antigravity": "Antigravity CLI", "grok": "Grok Build", "muse": "Muse Code"}
TASKS = {"opencode": "Fix test", "antigravity": "Fix test", "grok": "Fix test", "muse": "Fix test"}


def section(text, name):
    match = re.search(r"^## " + re.escape(name) + r"\n\n(.*?)(?=^## |\Z)", text, re.S | re.M)
    return match.group(1) if match else ""


class HarnessCase(unittest.TestCase):
    def setUp(self):
        self.sb = Sandbox()
        self.project = self.sb.repo(self.sb.root / "app", {"README.md": "# App\n", "docs/notes.md": "# Notes\n"})
        self.base = datetime.now(timezone.utc) - timedelta(hours=1)

    def tearDown(self):
        self.sb.close()

    def build(self, harness, **extra):
        store = {"opencode": opencode_store, "antigravity": antigravity_store, "grok": grok_store, "muse": muse_store}
        store[harness](self.sb, self.project, extra.pop("session_id", IDS[harness]), self.base, **extra)

    def build_all(self):
        for harness in IDS:
            self.build(harness)


class ReaderTests(HarnessCase):
    """B1: each reader turns the same story into the same summary sections."""

    def test_each_reader_gives_the_full_summary(self):
        self.build_all()
        for harness, session_id in IDS.items():
            with self.subTest(harness=harness):
                result = self.sb.reader("show", harness, session_id, "--cwd", str(self.project))
                self.assertEqual(result.returncode, 0, result.stderr)
                out = result.stdout
                self.assertIn(f"- Harness: {NAMES[harness]}", out)
                requests = section(out, "Requests")
                self.assertIn(STORY_REQUEST, requests)
                self.assertRegex(requests, r"(?m)^2\. .*approval")
                self.assertIn("`docs/notes.md`", section(out, "Files changed"))
                self.assertIn(TEST_COMMAND, section(out, "Tests"))
                self.assertRegex(section(out, "Tests"), r": (pass|fail): `")
                self.assertIn(TASKS[harness], section(out, "Task list"))
                self.assertIn("Implemented the fix; the test passes now.", section(out, "Last completion claim"))
                self.assertNotIn("HOSTILE", out)

    def test_unknown_records_are_counted(self):
        self.build_all()
        for harness, session_id in IDS.items():
            if harness == "muse":
                continue  # Muse has many payload types; only the ones read are known.
            with self.subTest(harness=harness):
                out = self.sb.reader("show", harness, session_id, "--cwd", str(self.project)).stdout
                self.assertRegex(section(out, "Reader warnings"), r"unknown type `(brand-new-type|BRAND_NEW_TYPE)`")

    def test_opencode_one_x_sessions_are_read(self):
        self.build("opencode", session_id="ses_legacy1", legacy=True)
        out = self.sb.reader("show", "opencode", "ses_legacy1", "--cwd", str(self.project)).stdout
        self.assertIn(STORY_REQUEST, section(out, "Requests"))
        self.assertIn("pass:", section(out, "Tests"))

    def test_ids_match_by_prefix(self):
        self.build_all()
        for harness, session_id in IDS.items():
            with self.subTest(harness=harness):
                result = self.sb.reader("show", harness, session_id[:12], "--cwd", str(self.project))
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_antigravity_compaction_and_declared_gaps(self):
        self.build("antigravity")
        out = self.sb.reader("show", "antigravity", IDS["antigravity"], "--cwd", str(self.project)).stdout
        self.assertIn("compacted 1 times", section(out, "Reader warnings"))
        self.assertIn("task.md", section(out, "Not recorded by this source"))

    def test_reader_opens_stores_read_only(self):
        self.build_all()
        # The stores only: Apple's Python 3.9 writes its own bytecode cache under ~/Library.
        stores = [self.sb.home / ".local", self.sb.home / ".grok", self.sb.home / ".gemini"]
        before = [self.sb.snapshot(p) for p in stores]
        for harness, session_id in IDS.items():
            self.sb.reader("show", harness, session_id, "--cwd", str(self.project))
        self.sb.reader("list", "--cwd", str(self.project))
        self.assertEqual([self.sb.snapshot(p) for p in stores], before)


class ListTests(HarnessCase):
    """B3 and B4: candidates, titles, the last request, and the hidden current session."""

    def listing(self, *extra, env=None):
        if env:
            self.sb.env.update(env)
        return self.sb.reader("list", "--cwd", str(self.project), *extra)

    def test_every_harness_is_listed_with_a_last_request(self):
        self.build_all()
        out = self.listing().stdout
        for harness, session_id in IDS.items():
            with self.subTest(harness=harness):
                self.assertRegex(out, rf"\. {NAMES[harness]} \| .+ \| {re.escape(session_id)}")
        self.assertEqual(out.count('Last request: "ok"'), 4)

    def test_placeholder_title_becomes_the_first_request(self):
        self.build("muse", title="New session")
        self.build("grok", title="")
        out = self.listing().stdout
        self.assertEqual(out.count(f"| {STORY_REQUEST} |"), 2)
        self.assertNotIn("New session", out)

    def test_subagent_and_empty_sessions_are_left_out(self):
        self.build("opencode", session_id="ses_child", parent="ses_parent")
        self.build("grok", session_id="01a00000-0000-7000-8000-00000000000c", kind="subagent")
        self.build("muse", session_id="01a00000-0000-7000-8000-0000000000cc", prompts=0)
        self.build("antigravity", session_id="cccccccc-0000-4000-8000-000000000001", parent="p")
        result = self.listing()
        self.assertEqual(result.returncode, 2, result.stdout)

    def test_json_carries_title_and_last_request(self):
        self.build("grok")
        entry = json.loads(self.listing("--json").stdout)[0]
        self.assertEqual(entry["harness"], "grok")
        self.assertEqual(entry["title"], "Flaky test fix")
        self.assertEqual(entry["last_request"], "ok")

    def test_current_session_is_hidden_for_each_harness(self):
        self.build_all()
        variables = {"muse": ("MUSE_SESSION_ID", IDS["muse"]),
                     "antigravity": ("ANTIGRAVITY_CONVERSATION_ID", IDS["antigravity"]),
                     "grok": ("GROK_SESSION_ID", IDS["grok"]),
                     "opencode": ("RESUME_SESSION_CURRENT", "opencode:" + IDS["opencode"])}
        for harness, (name, value) in variables.items():
            with self.subTest(harness=harness):
                env = dict(self.sb.env, **{name: value})
                out = self.sb.reader_env(env, "list", "--cwd", str(self.project)).stdout
                self.assertNotIn(f"| {IDS[harness]}", out)
                self.assertIn(f"Not listed: this session ({NAMES[harness]} {IDS[harness]})", out)
                self.assertEqual(len(re.findall(r"(?m)^\d+\. ", out)), 3)

    def test_claude_and_codex_variables_hide_their_sessions(self):
        session = "11111111-2222-3333-4444-555555555555"
        claude_transcript(self.sb, self.project, session, claude_records(self.project, self.base))
        env = dict(self.sb.env, CLAUDE_CODE_SESSION_ID=session)
        out = self.sb.reader_env(env, "list", "--cwd", str(self.project)).stdout
        self.assertIn(f"Not listed: this session (Claude Code {session})", out)

    def test_grok_session_open_in_an_ancestor_process_is_hidden(self):
        self.build("grok")
        active = [{"session_id": IDS["grok"], "pid": os.getpid(), "cwd": str(self.project)}]
        (self.sb.home / ".grok" / "active_sessions.json").write_text(json.dumps(active))
        out = self.listing().stdout
        self.assertIn(f"Not listed: this session (Grok Build {IDS['grok']})", out)
        shown = self.sb.reader("show", "grok", IDS["grok"], "--cwd", str(self.project)).stdout
        self.assertIn("WARNING: Grok lists this session as open", shown)

    def test_mark_names_the_resuming_harness(self):
        self.build("grok")
        env = dict(self.sb.env, MUSE_SESSION_ID="01a00000-0000-7000-8000-0000000000ff")
        result = self.sb.reader_env(env, "mark", "grok", IDS["grok"], "--cwd", str(self.project))
        self.assertEqual(result.returncode, 0, result.stderr)
        note = json.loads((self.sb.home / ".local" / "state" / "resume-session" / "resumed"
                           / f"grok-{IDS['grok']}.json").read_text())
        self.assertEqual(note["resumes"][0]["by_harness"], "Muse Code")
        self.assertEqual(note["resumes"][0]["by_session"], "01a00000-0000-7000-8000-0000000000ff")


if __name__ == "__main__":
    unittest.main()
