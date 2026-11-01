#!/usr/bin/env python3
"""Tests for resume notes, `mark`, and the warning hook (A3 unit part, A9).

Run with: python3 -m unittest discover -s tests -p 'test_resume_session_*.py'
"""

import json
import shutil
import stat
import statistics
import subprocess
import sys
import time
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from resume_session_support import REPO, Sandbox, claude_records, claude_transcript  # noqa: E402

HOOK = REPO / "hooks" / "resume-session-warn" / "resume-session-warn.sh"
SESSION = "11111111-2222-3333-4444-555555555555"


class NoteTests(unittest.TestCase):
    def setUp(self):
        self.sb = Sandbox()
        self.project = self.sb.repo(self.sb.root / "app", {"README.md": "# App\n"})
        base = datetime.now(timezone.utc) - timedelta(hours=1)
        claude_transcript(self.sb, self.project, SESSION, claude_records(self.project, base))
        self.notes = self.sb.home / ".local" / "state" / "resume-session" / "resumed"

    def tearDown(self):
        self.sb.close()

    def mark(self, *extra, env=None):
        if env:
            self.sb.env.update(env)
        return self.sb.reader("mark", "claude", SESSION, "--cwd", str(self.project), *extra)

    def note(self):
        return json.loads((self.notes / f"claude-{SESSION}.json").read_text())

    def test_mark_writes_a_private_note(self):
        result = self.mark(env={"CLAUDECODE": "1", "CLAUDE_CODE_SESSION_ID": "new-session"})
        self.assertEqual(result.returncode, 0, result.stderr)
        path = self.notes / f"claude-{SESSION}.json"
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.notes.stat().st_mode), 0o700)
        note = self.note()
        self.assertEqual(note["session_id"], SESSION)
        self.assertEqual(note["project_root"], str(self.project))
        self.assertIn(str(self.project), note["locations"])
        resume = note["resumes"][0]
        self.assertEqual(resume["by_harness"], "Claude Code")
        self.assertEqual(resume["by_session"], "new-session")
        self.assertRegex(resume["time_local"], r" [+-]\d{2}:\d{2}$")

    def test_by_session_option_wins(self):
        self.mark("--by-session", "given", env={"CLAUDECODE": "1", "CLAUDE_CODE_SESSION_ID": "env"})
        self.assertEqual(self.note()["resumes"][0]["by_session"], "given")

    def test_codex_and_unknown_resumers(self):
        self.mark(env={"CODEX_THREAD_ID": "thread-1"})
        self.assertEqual(self.note()["resumes"][0]["by_harness"], "Codex")
        self.sb.env.pop("CODEX_THREAD_ID")
        self.mark()
        self.assertEqual(self.note()["resumes"][1]["by_harness"], "another harness")

    def test_second_mark_keeps_the_first(self):
        self.mark("--by-session", "one")
        self.mark("--by-session", "two")
        self.assertEqual([r["by_session"] for r in self.note()["resumes"]], ["one", "two"])

    def test_list_and_show_report_the_resume(self):
        self.mark(env={"CLAUDECODE": "1"})
        listed = self.sb.reader("list", "--cwd", str(self.project)).stdout
        self.assertIn("already resumed in Claude Code at", listed)
        shown = self.sb.reader("show", "claude", SESSION, "--cwd", str(self.project)).stdout
        self.assertIn("WARNING: Already resumed in Claude Code at", shown)
        self.assertIn("Continue only if the user confirms.", shown)

    def test_report_only_commands_write_no_note(self):
        self.sb.reader("list", "--cwd", str(self.project))
        self.sb.reader("show", "claude", SESSION, "--cwd", str(self.project))
        self.sb.reader("show", "--repo-only", "--cwd", str(self.project))
        self.assertFalse(self.notes.exists())

    def test_notes_older_than_30_days_are_pruned(self):
        self.notes.mkdir(parents=True)
        old = (datetime.now(timezone.utc) - timedelta(days=31)).isoformat()
        recent = (datetime.now(timezone.utc) - timedelta(days=29)).isoformat()
        (self.notes / "codex-old.json").write_text(json.dumps({"resumes": [{"time_utc": old}]}))
        (self.notes / "codex-recent.json").write_text(json.dumps({"resumes": [{"time_utc": recent}]}))
        self.mark()
        self.assertFalse((self.notes / "codex-old.json").exists())
        self.assertTrue((self.notes / "codex-recent.json").exists())

    def test_unwritable_note_directory_is_reported(self):
        state = self.sb.home / ".local" / "state"
        state.mkdir(parents=True)
        (state / "resume-session").write_text("a file where the folder should be")
        result = self.mark()
        self.assertEqual(result.returncode, 1)
        self.assertIn("The work can continue; the old session gets no warning.", result.stderr)

    def test_unsafe_session_id_is_refused(self):
        result = self.sb.reader("mark", "claude", "../escape", "--cwd", str(self.project))
        self.assertEqual(result.returncode, 1)
        self.assertFalse(self.notes.exists())


@unittest.skipIf(shutil.which("jq") is None, "jq is not installed")
class HookTests(unittest.TestCase):
    def setUp(self):
        self.sb = Sandbox()
        self.notes = self.sb.home / ".local" / "state" / "resume-session" / "resumed"
        self.notes.mkdir(parents=True)

    def tearDown(self):
        self.sb.close()

    def run_hook(self, payload, env=None):
        environment = dict(self.sb.env, **(env or {}))
        return subprocess.run(["/bin/sh", str(HOOK)], input=payload, env=environment,
                              capture_output=True, text=True)

    def write_note(self, harness):
        note = {"harness": harness, "session_id": SESSION, "project_root": "/home/dev/app",
                "resumes": [{"time_utc": "2026-10-31T00:47:00+00:00", "time_local": "2026-10-31 10:47 +10:00",
                             "by_harness": "Codex", "by_session": None}]}
        (self.notes / f"{harness}-{SESSION}.json").write_text(json.dumps(note))

    def test_note_gives_one_factual_line(self):
        for harness in ("claude", "codex"):
            for path in self.notes.glob("*.json"):
                path.unlink()
            self.write_note(harness)
            result = self.run_hook(json.dumps({"session_id": SESSION, "prompt": "hi"}))
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout.strip(),
                             "This session was resumed in Codex at 2026-10-31 10:47 +10:00 for the project at "
                             "/home/dev/app. Work done here can conflict with that session. "
                             "Ask the user to confirm before changing any file in this session.")

    def test_silent_and_zero_in_every_other_case(self):
        self.write_note("claude")
        cases = [
            (json.dumps({"session_id": "no-note-for-this-one"}), None),
            ("not json at all", None),
            (json.dumps({"prompt": "no id"}), None),
            (json.dumps({"session_id": "../../etc/passwd"}), None),
            (json.dumps({"session_id": SESSION}), {"PATH": "/nonexistent"}),
        ]
        for payload, env in cases:
            result = self.run_hook(payload, env)
            self.assertEqual((result.returncode, result.stdout), (0, ""), payload)

    def test_a9_hook_adds_under_50_ms_without_a_note(self):
        payload = json.dumps({"session_id": SESSION})
        timings = []
        for _ in range(20):
            start = time.perf_counter()
            self.run_hook(payload)
            timings.append((time.perf_counter() - start) * 1000)
        self.assertLess(statistics.median(timings), 50, timings)


if __name__ == "__main__":
    unittest.main()
