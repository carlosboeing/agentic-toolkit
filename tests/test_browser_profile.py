"""Tests for skills/browser-profile/scripts/browser-profile.sh.

The Playwright CLI is replaced by a recording stub, so no browser starts.
"""

import os
import stat
import subprocess
import tempfile
import textwrap
import time
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT = REPO_ROOT / "skills" / "browser-profile" / "scripts" / "browser-profile.sh"
EXTENSION_ID = "mmlmfjhmonkocbjadbfplnigmagldckm"

STUB_CLI = textwrap.dedent(
    """\
    #!/usr/bin/env bash
    # Recording stand-in for playwright-cli.
    log="$STUB_DIR/calls.log"
    case "${1:-}" in
      --version)
        echo "${STUB_VERSION:-0.1.24}"
        exit 0
        ;;
      attach)
        printf 'attach %s\\n' "$*" >>"$log"
        env | grep '^PLAYWRIGHT_MCP_' | sort >"$STUB_DIR/attach.env"
        for arg in "$@"; do
          case "$arg" in --session=*) printf '%s' "${arg#--session=}" >"$STUB_DIR/session" ;; esac
        done
        case "${STUB_ATTACH:-ok}" in
          ok) exit 0 ;;
          fail) echo "attach exploded" >&2; exit 1 ;;
          hang) sleep 30; exit 0 ;;
        esac
        ;;
      list)
        session="$(cat "$STUB_DIR/session" 2>/dev/null || true)"
        echo "### Browsers"
        echo "- other:"
        echo "  - status: open"
        echo "  - browser-type: chrome (attached)"
        echo "- ${session}:"
        echo "  - status: open"
        if [ "${STUB_LIST:-attached}" = "attached" ]; then
          echo "  - browser-type: chrome (attached)"
        else
          echo "  - browser-type: chrome"
          echo "  - user-data-dir: <in-memory>"
        fi
        exit 0
        ;;
      -s=*)
        printf 'session %s\\n' "$*" >>"$log"
        if [ "${2:-}" = "tab-list" ]; then
          echo "### Result"
          echo "- 0: (current) [One](https://example.com/)"
          echo "- 1: [Two](https://example.org/)"
        fi
        exit 0
        ;;
    esac
    exit 0
    """
)


class BrowserProfileTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.stub_dir = self.tmp / "stub"
        self.stub_dir.mkdir()
        self.cli = self.tmp / "playwright-cli"
        self.cli.write_text(STUB_CLI)
        self.cli.chmod(self.cli.stat().st_mode | stat.S_IXUSR)

        # Stand-ins for the desktop notifiers, so no real notification fires.
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        for name in ("osascript", "notify-send"):
            notifier = self.bin / name
            notifier.write_text('#!/usr/bin/env bash\nprintf \'%s\\n\' "$*" >>"$STUB_DIR/notify.log"\n')
            notifier.chmod(notifier.stat().st_mode | stat.S_IXUSR)
        # Stand-ins for the commands that open a page in Chrome.
        for name in ("open", "google-chrome"):
            opener = self.bin / name
            opener.write_text('#!/usr/bin/env bash\nprintf \'%s\\n\' "$*" >>"$STUB_DIR/chrome-open.log"\n')
            opener.chmod(opener.stat().st_mode | stat.S_IXUSR)

        self.chrome = self.tmp / "chrome"
        (self.chrome / "Profile 3" / "Extensions" / EXTENSION_ID).mkdir(parents=True)
        (self.chrome / "Profile 5").mkdir(parents=True)
        for name in ("Profile 3", "Profile 5"):
            (self.chrome / name / "Preferences").write_text("{}")
        (self.chrome / "Local State").write_text(
            '{"profile": {"info_cache": {'
            '"Profile 3": {"name": "Work Co", "user_name": "person@example.com"},'
            '"Profile 5": {"name": "Side Project", "user_name": "other@example.com"}}}}'
        )

        self.conf = self.tmp / "browser-profiles.conf"
        self.conf.write_text(
            "# alias = profile directory | label\n"
            "work = Profile 3 | Example Pty admin\n"
            "bare=Profile 3\n"
            "noext = Profile 5 | no extension here\n"
            "gone = Profile 9\n"
            "evil = ../Default\n"
        )

    def tearDown(self):
        self._tmp.cleanup()

    def run_script(self, *args, **env_overrides):
        env = {
            "PATH": f"{self.bin}{os.pathsep}{os.environ['PATH']}",
            "HOME": str(self.tmp),
            "BROWSER_PROFILE_CONF": str(self.conf),
            "BROWSER_PROFILE_CLI": str(self.cli),
            "BROWSER_PROFILE_CHROME_DIR": str(self.chrome),
            "BROWSER_PROFILE_WAIT": "5",
            "STUB_DIR": str(self.stub_dir),
        }
        env.update(env_overrides)
        return subprocess.run(
            ["bash", str(SCRIPT), *args],
            env=env,
            capture_output=True,
            text=True,
            timeout=60,
        )

    def calls(self):
        log = self.stub_dir / "calls.log"
        return log.read_text() if log.exists() else ""

    def attach_env(self):
        return (self.stub_dir / "attach.env").read_text()

    def output_root(self):
        return self.tmp / ".local" / "state" / "agentic-toolkit" / "browser-profile"

    # --- open: the path that works -------------------------------------

    def test_open_attaches_through_the_extension_to_the_aliased_profile(self):
        result = self.run_script("open", "work")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--extension=chrome", self.calls())
        self.assertIn("PLAYWRIGHT_MCP_PROFILE_DIR_NAME=Profile 3", self.attach_env())

    def test_open_prints_the_session_name_it_attached(self):
        result = self.run_script("open", "work")
        session = (self.stub_dir / "session").read_text()
        self.assertRegex(session, r"^work-[0-9a-f]{4}$")
        self.assertIn(f"session: {session}", result.stdout)

    def test_open_accepts_an_explicit_session_name(self):
        result = self.run_script("open", "work", "migration-1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--session=migration-1", self.calls())

    def test_open_accepts_an_alias_without_a_label(self):
        result = self.run_script("open", "bare")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PLAYWRIGHT_MCP_PROFILE_DIR_NAME=Profile 3", self.attach_env())

    def test_open_names_the_profile_and_label_before_waiting(self):
        result = self.run_script("open", "work")
        self.assertIn("work", result.stderr)
        self.assertIn("Profile 3", result.stderr)
        self.assertIn("Example Pty admin", result.stderr)

    # --- open: inherited settings that would redirect the connection ----

    def test_open_drops_the_isolated_setting_that_overrides_the_extension(self):
        result = self.run_script("open", "work", PLAYWRIGHT_MCP_ISOLATED="true")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("PLAYWRIGHT_MCP_ISOLATED", self.attach_env())

    def test_open_drops_a_stored_extension_token_so_the_allow_click_is_required(self):
        result = self.run_script("open", "work", PLAYWRIGHT_MCP_EXTENSION_TOKEN="secret")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("PLAYWRIGHT_MCP_EXTENSION_TOKEN", self.attach_env())
        self.assertNotIn("secret", self.attach_env())

    def test_open_drops_every_other_inherited_playwright_setting(self):
        self.run_script(
            "open",
            "work",
            PLAYWRIGHT_MCP_CDP_ENDPOINT="http://127.0.0.1:9222",
            PLAYWRIGHT_MCP_PROFILE_DIR_NAME="Default",
        )
        names = sorted(line.split("=", 1)[0] for line in self.attach_env().splitlines())
        self.assertEqual(names, ["PLAYWRIGHT_MCP_OUTPUT_DIR", "PLAYWRIGHT_MCP_PROFILE_DIR_NAME"])
        self.assertIn("PLAYWRIGHT_MCP_PROFILE_DIR_NAME=Profile 3", self.attach_env())

    # --- open: page output stays out of the project ---------------------

    def test_open_sends_page_output_to_a_private_folder_for_the_session(self):
        result = self.run_script("open", "work", "s1")
        out_dir = self.output_root() / "s1"
        self.assertIn(f"PLAYWRIGHT_MCP_OUTPUT_DIR={out_dir}", self.attach_env())
        self.assertTrue(out_dir.is_dir())
        self.assertEqual(stat.S_IMODE(out_dir.stat().st_mode), 0o700)
        self.assertIn(f"output:  {out_dir}", result.stdout)

    def test_close_deletes_the_session_output_folder(self):
        self.run_script("open", "work", "s1")
        (self.output_root() / "s1" / "page.yml").write_text("private page content")
        self.run_script("close", "s1")
        self.assertFalse((self.output_root() / "s1").exists())

    def test_a_failed_open_leaves_no_output_folder(self):
        self.run_script("open", "work", "s1", STUB_ATTACH="fail")
        self.assertFalse((self.output_root() / "s1").exists())
        self.run_script("open", "work", "s2", STUB_LIST="isolated")
        self.assertFalse((self.output_root() / "s2").exists())
        self.run_script("open", "work", "s3", STUB_ATTACH="hang", BROWSER_PROFILE_WAIT="1")
        self.assertFalse((self.output_root() / "s3").exists())

    # --- open: the user is told to click ---------------------------------

    def test_open_raises_a_desktop_notification_naming_the_profile(self):
        self.run_script("open", "work")
        notified = (self.stub_dir / "notify.log").read_text()
        self.assertIn("Allow", notified)
        self.assertIn("work", notified)
        self.assertIn("Example Pty admin", notified)

    def test_open_stays_silent_when_notifications_are_switched_off(self):
        self.run_script("open", "work", BROWSER_PROFILE_NOTIFY="0")
        self.assertFalse((self.stub_dir / "notify.log").exists())

    def test_a_refused_open_raises_no_notification(self):
        self.run_script("open", "noext")
        self.assertFalse((self.stub_dir / "notify.log").exists())

    # --- open: refusals --------------------------------------------------

    def test_open_refuses_an_alias_that_is_not_in_the_file(self):
        result = self.run_script("open", "personal")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("personal", result.stderr)
        self.assertEqual(self.calls(), "")

    def test_open_refuses_a_raw_profile_directory_name(self):
        result = self.run_script("open", "Profile 3")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), "")

    def test_open_refuses_when_the_alias_file_is_missing(self):
        result = self.run_script("open", "work", BROWSER_PROFILE_CONF=str(self.tmp / "absent.conf"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("absent.conf", result.stderr)
        self.assertEqual(self.calls(), "")

    def test_open_refuses_a_profile_without_the_extension(self):
        result = self.run_script("open", "noext")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("extension", result.stderr.lower())
        self.assertEqual(self.calls(), "")

    def test_open_refuses_a_profile_directory_that_does_not_exist(self):
        result = self.run_script("open", "gone")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), "")

    def test_open_refuses_a_profile_directory_with_path_separators(self):
        result = self.run_script("open", "evil")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), "")

    def test_open_refuses_a_cli_older_than_the_tested_version(self):
        result = self.run_script("open", "work", STUB_VERSION="0.1.17")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("0.1.24", result.stderr)
        self.assertNotIn("attach", self.calls())

    def test_open_refuses_an_unsafe_session_name(self):
        result = self.run_script("open", "work", "bad name;rm")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), "")

    # --- open: failures after the attach started ---------------------------

    def test_open_fails_when_the_session_is_not_an_extension_session(self):
        result = self.run_script("open", "work", STUB_LIST="isolated")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("extension", result.stderr.lower())
        self.assertNotIn("session:", result.stdout)
        session = (self.stub_dir / "session").read_text()
        self.assertIn(f"session -s={session} close", self.calls())

    def test_open_gives_up_when_nobody_clicks_allow(self):
        result = self.run_script("open", "work", STUB_ATTACH="hang", BROWSER_PROFILE_WAIT="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Allow", result.stderr)
        self.assertNotIn("session:", result.stdout)

    def test_open_reports_the_cli_error_when_attach_fails(self):
        result = self.run_script("open", "work", STUB_ATTACH="fail")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("attach exploded", result.stderr)

    # --- close -----------------------------------------------------------

    def test_close_detaches_and_leaves_tabs_open(self):
        result = self.run_script("close", "work-1a2b")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("session -s=work-1a2b detach", self.calls())
        self.assertNotIn("tab-close", self.calls())

    def test_close_with_close_tabs_closes_each_tab_then_detaches(self):
        result = self.run_script("close", "work-1a2b", "--close-tabs")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        self.assertEqual(calls.count("tab-close"), 2)
        self.assertLess(calls.rindex("tab-close"), calls.index("detach"))

    def test_close_refuses_an_unsafe_session_name(self):
        result = self.run_script("close", "x; rm -rf /")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), "")

    # --- list ------------------------------------------------------------

    def test_list_shows_each_alias_with_its_readiness(self):
        result = self.run_script("list")
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = {line.split()[0]: line for line in result.stdout.splitlines() if line.strip()}
        self.assertIn("ready", lines["work"])
        self.assertIn("Example Pty admin", lines["work"])
        self.assertIn("extension not installed", lines["noext"])
        self.assertIn("profile not found", lines["gone"])

    def test_list_never_starts_the_cli(self):
        self.run_script("list")
        self.assertEqual(self.calls(), "")

    # --- check: guided setup ---------------------------------------------

    def clean_conf(self):
        conf = self.tmp / "clean.conf"
        conf.write_text("work = Profile 3 | Example Pty admin\n")
        return str(conf)

    def test_check_passes_when_every_requirement_is_met(self):
        result = self.run_script("check", BROWSER_PROFILE_CONF=self.clean_conf())
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("fix:", result.stdout)
        self.assertIn("0.1.24", result.stdout)
        self.assertIn("ready", result.stdout)

    def test_check_gives_the_install_command_for_an_old_cli(self):
        result = self.run_script("check", BROWSER_PROFILE_CONF=self.clean_conf(), STUB_VERSION="0.1.17")
        self.assertEqual(result.returncode, 1)
        self.assertIn("fix: npm install -g @playwright/cli@latest", result.stdout)

    def test_check_gives_the_install_command_for_a_missing_cli(self):
        result = self.run_script(
            "check", BROWSER_PROFILE_CONF=self.clean_conf(), BROWSER_PROFILE_CLI=str(self.tmp / "no-such-cli")
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("fix: npm install -g @playwright/cli@latest", result.stdout)

    def test_check_explains_how_to_create_a_missing_alias_file(self):
        absent = self.tmp / "absent.conf"
        result = self.run_script("check", BROWSER_PROFILE_CONF=str(absent))
        self.assertEqual(result.returncode, 1)
        self.assertIn(str(absent), result.stdout)
        self.assertIn("profiles", result.stdout)
        self.assertIn("<alias> = <Chrome profile directory> | <label>", result.stdout)

    def test_check_points_to_install_extension_for_a_profile_without_it(self):
        result = self.run_script("check", "noext")
        self.assertEqual(result.returncode, 1)
        self.assertIn("install-extension noext", result.stdout)

    def test_check_of_one_alias_ignores_problems_in_other_aliases(self):
        result = self.run_script("check", "work")
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_check_reports_an_alias_that_does_not_exist(self):
        result = self.run_script("check", "personal")
        self.assertEqual(result.returncode, 1)
        self.assertIn("personal", result.stdout)
        self.assertIn("profiles", result.stdout)

    def test_check_never_connects(self):
        self.run_script("check")
        self.assertEqual(self.calls(), "")

    # --- profiles: what the user can choose from --------------------------

    def test_profiles_lists_each_chrome_profile_with_name_extension_and_alias(self):
        result = self.run_script("profiles")
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = {line.split("\t")[0]: line for line in result.stdout.splitlines() if line.strip()}
        self.assertIn("Work Co", lines["Profile 3"])
        self.assertIn("extension installed", lines["Profile 3"])
        self.assertIn("work", lines["Profile 3"])
        self.assertIn("Side Project", lines["Profile 5"])
        self.assertIn("extension not installed", lines["Profile 5"])
        self.assertIn("noext", lines["Profile 5"])

    def test_profiles_never_prints_account_addresses(self):
        result = self.run_script("profiles")
        self.assertNotIn("@example.com", result.stdout)

    def test_profiles_works_without_an_alias_file(self):
        result = self.run_script("profiles", BROWSER_PROFILE_CONF=str(self.tmp / "absent.conf"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Profile 3", result.stdout)

    # --- install-extension -------------------------------------------------

    def opened(self, expect_call=False):
        log = self.stub_dir / "chrome-open.log"
        deadline = time.monotonic() + (2 if expect_call else 0)
        while not log.exists() and time.monotonic() < deadline:
            time.sleep(0.05)  # the Linux opener runs in the background
        return log.read_text() if log.exists() else ""

    def test_install_extension_opens_the_store_page_in_the_aliased_profile(self):
        result = self.run_script("install-extension", "noext")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--profile-directory=Profile 5", self.opened(expect_call=True))
        self.assertIn(f"chromewebstore.google.com/detail/playwright-extension/{EXTENSION_ID}", self.opened())
        self.assertIn("Add to Chrome", result.stdout)

    def test_install_extension_does_nothing_when_it_is_already_installed(self):
        result = self.run_script("install-extension", "work")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.opened(), "")
        self.assertIn("already installed", result.stdout)

    def test_install_extension_refuses_a_name_that_is_not_an_alias(self):
        result = self.run_script("install-extension", "Profile 5")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.opened(), "")

    def test_install_extension_refuses_a_profile_that_does_not_exist(self):
        result = self.run_script("install-extension", "gone")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.opened(), "")

    # --- usage -----------------------------------------------------------

    def test_unknown_command_prints_usage_and_fails(self):
        result = self.run_script("launch")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Usage", result.stderr)


if __name__ == "__main__":
    unittest.main()
