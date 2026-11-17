#!/usr/bin/env python3
"""Tests for scripts/mac-stay-awake.sh: `on` saves the original AC sleep timer once,
`off` restores it, and a failed or missing step changes nothing.

Run with: python3 -m unittest tests/test_mac_stay_awake.py
"""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCRIPT = REPO / "scripts" / "mac-stay-awake.sh"

FAKE_PMSET = """#!/bin/sh
# Fake pmset: keeps the AC sleep timer in $FAKE_DIR/ac-sleep and logs each set call.
dir="$FAKE_DIR"
if [ "$1 $2" = "-g custom" ]; then
  printf 'Battery Power:\\n displaysleep         2\\n sleep                1\\n'
  printf 'AC Power:\\n displaysleep         10\\n sleep                %s\\n' "$(cat "$dir/ac-sleep")"
elif [ "$1" = "-g" ]; then
  printf 'System-wide power settings:\\nCurrently in use:\\n sleep                %s (sleep prevented by caffeinate)\\n' "$(cat "$dir/ac-sleep")"
elif [ "$1 $2" = "-c sleep" ]; then
  echo "$*" >> "$dir/calls.log"
  echo "$3" > "$dir/ac-sleep"
fi
"""

FAKE_SUDO = """#!/bin/sh
# Fake sudo: fails when $FAKE_DIR/sudo-fails exists, otherwise runs the command.
[ -f "$FAKE_DIR/sudo-fails" ] && exit 1
exec "$@"
"""


class MacStayAwakeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        for name, body in (("pmset", FAKE_PMSET), ("sudo", FAKE_SUDO)):
            path = self.dir / name
            path.write_text(body)
            path.chmod(0o755)
        self.set_ac_sleep("1")
        self.state = self.dir / "state" / "mac-stay-awake.previous-ac-sleep"
        self.env = dict(
            os.environ,
            FAKE_DIR=str(self.dir),
            MAC_STAY_AWAKE_PMSET=str(self.dir / "pmset"),
            MAC_STAY_AWAKE_SUDO=str(self.dir / "sudo"),
            MAC_STAY_AWAKE_STATE_DIR=str(self.dir / "state"),
        )

    def tearDown(self):
        self.tmp.cleanup()

    def set_ac_sleep(self, value):
        (self.dir / "ac-sleep").write_text(value + "\n")

    def ac_sleep(self):
        return (self.dir / "ac-sleep").read_text().strip()

    def calls(self):
        log = self.dir / "calls.log"
        return log.read_text().splitlines() if log.exists() else []

    def run_script(self, *args):
        return subprocess.run(["bash", str(SCRIPT), *args], env=self.env, capture_output=True, text=True)

    def test_on_saves_original_and_disables_sleep(self):
        result = self.run_script("on")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.state.read_text().strip(), "1")
        self.assertEqual(self.calls(), ["-c sleep 0"])
        self.assertIn("lid", result.stdout)

    def test_second_on_keeps_first_saved_value(self):
        self.run_script("on")
        result = self.run_script("on")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.state.read_text().strip(), "1")
        self.assertEqual(self.calls(), ["-c sleep 0"])

    def test_off_restores_saved_value_and_deletes_it(self):
        self.run_script("on")
        result = self.run_script("off")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.ac_sleep(), "1")
        self.assertFalse(self.state.exists())

    def test_off_without_saved_value_changes_nothing(self):
        result = self.run_script("off")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.calls(), [])
        self.assertIn("No saved value", result.stderr)

    def test_failed_sudo_leaves_no_saved_value(self):
        (self.dir / "sudo-fails").touch()
        result = self.run_script("on")
        self.assertEqual(result.returncode, 1)
        self.assertFalse(self.state.exists())
        self.assertEqual(self.ac_sleep(), "1")

    def test_on_when_already_never_saves_nothing(self):
        self.set_ac_sleep("0")
        result = self.run_script("on")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.state.exists())
        self.assertEqual(self.calls(), [])

    def test_status_reports_values_and_saved_state(self):
        result = self.run_script("status")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("AC sleep:         1 min", result.stdout)
        self.assertIn("AC display sleep: 10 min", result.stdout)
        self.assertIn("Held awake by:    (sleep prevented by caffeinate)", result.stdout)
        self.assertIn("Saved value:      none", result.stdout)
        self.run_script("on")
        self.assertIn("Saved value:      1 min", self.run_script("status").stdout)

    def test_unknown_command_prints_usage(self):
        result = self.run_script("toggle")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Usage:", result.stderr)


if __name__ == "__main__":
    unittest.main()
