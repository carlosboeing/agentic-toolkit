"""Exercise rollout through its CLI, installed files and local Git remotes."""

import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parent.parent
SCRIPT = SOURCE / "scripts" / "toolkit-rollout.py"


class RolloutTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.repo = self.root / "project with spaces"
        self.report = self.root / "rollout.json"
        self.env = {**os.environ, "HOME": str(self.root / "home"),
                    "SYNC_TOOLKIT_NO_CONFIG": "1", "GIT_CONFIG_NOSYSTEM": "1",
                    "GIT_CONFIG_GLOBAL": os.devnull}
        self.git("init", "-q", "-b", "main", str(self.repo), cwd=self.root)
        self.git("config", "user.name", "Test Operator")
        self.git("config", "user.email", "test@example.invalid")
        self.git("-c", "core.hooksPath=/dev/null", "commit", "-qm", "initial", "--allow-empty")

    def git(self, *args, cwd=None):
        return subprocess.check_output(["git", "-C", str(cwd or self.repo), *args],
                                       env=self.env, stderr=subprocess.PIPE).decode().strip()

    def cli(self, *args, expected=0, script=SCRIPT):
        result = subprocess.run([sys.executable, str(script), *args], env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def audit(self, *extra, expected=0):
        return self.cli("audit", "--repo", str(self.repo), "--report", str(self.report), *extra, expected=expected)

    def data(self):
        return json.loads(self.report.read_text())

    def test_new_hooks_remain_pending_publication_after_installation(self):
        before = self.git("status", "--porcelain", "--untracked-files=all")
        self.audit()
        self.assertEqual(self.git("status", "--porcelain", "--untracked-files=all"), before)
        files = self.data()["repositories"][0]["files"]
        self.assertEqual({f["path"] for f in files}, {
            "scripts/githooks/housekeep", "scripts/githooks/pre-push", "scripts/githooks/post-merge"})
        self.assertTrue(all(f["change"] == "new" for f in files))
        self.cli("apply", "--report", str(self.report))
        repo = self.data()["repositories"][0]
        self.assertEqual(repo["installation"], "verified")
        self.assertEqual(repo["publication"], "pending")
        for item in files:
            installed = self.repo / item["path"]
            self.assertEqual(installed.read_bytes(), (SOURCE / item["source"]).read_bytes())
            self.assertTrue(os.access(installed, os.X_OK))
        self.cli("verify", "--report", str(self.report), "--require", "published", expected=1)

    def test_publication_requires_committed_files_and_live_remote_contents(self):
        self.audit()
        self.cli("apply", "--report", str(self.report))
        self.assertEqual(self.data()["repositories"][0]["committed"], "pending")
        self.git("add", "scripts/githooks")
        self.git("-c", "core.hooksPath=/dev/null", "commit", "-qm", "install hooks")
        self.cli("verify", "--report", str(self.report), "--require", "published", expected=1)

        self.assertEqual(self.data()["repositories"][0]["committed"], "verified")
        remote = self.root / "remote.git"
        self.git("init", "--bare", "-q", str(remote), cwd=self.root)
        self.git("remote", "add", "origin", str(remote))
        self.git("-c", "core.hooksPath=/dev/null", "push", "-qu", "origin", "main")
        self.cli("verify", "--report", str(self.report), "--require", "published")
        self.assertEqual(self.data()["repositories"][0]["publication"], "verified")
        # Staged deletions must remain visible even if the working copy is restored.
        self.git("rm", "--cached", "scripts/githooks/pre-push")
        self.cli("verify", "--report", str(self.report), "--require", "published", expected=1)
        self.git("add", "scripts/githooks/pre-push")
        # A fresh remote query must notice a rewind, even when cached origin/main is stale.
        self.git("--git-dir", str(remote), "update-ref", "refs/heads/main", self.git("rev-parse", "HEAD~1"), cwd=self.root)
        self.cli("verify", "--report", str(self.report), "--require", "published", expected=1)

    def test_missing_installer_source_cannot_report_success(self):
        checkout = self.root / "incomplete toolkit"
        (checkout / "scripts").mkdir(parents=True)
        shutil.copy2(SOURCE / "scripts/sync-toolkit.sh", checkout / "scripts/sync-toolkit.sh")
        result = subprocess.run(["bash", str(checkout / "scripts/sync-toolkit.sh"),
                                 "--no-config", str(self.repo), "-y"], env=self.env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("SOURCE MISSING", result.stdout)
        self.assertFalse((self.repo / "scripts/githooks").exists())
        configured = subprocess.run(["git", "-C", str(self.repo), "config", "--get", "core.hooksPath"],
                                    env=self.env, capture_output=True)
        self.assertEqual(configured.returncode, 1)

    def test_existing_registration_report_is_rejected_before_installation(self):
        self.report.write_text("keep existing evidence\n")
        result = subprocess.run(["bash", str(SOURCE / "scripts/sync-toolkit.sh"), "--harness", "--no-config",
                                 "--registration-report", str(self.report), "-y"],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertEqual(self.report.read_text(), "keep existing evidence\n")
        self.assertFalse((Path(self.env["HOME"]) / ".claude").exists())

    def test_harness_preview_includes_wrapper_for_a_not_yet_installed_skill(self):
        home = Path(self.env["HOME"])
        (home / ".config/opencode").mkdir(parents=True)
        result = subprocess.run(["bash", str(SOURCE / "scripts/sync-toolkit.sh"), "--harness", "--no-config",
                                 "--dry-run", "-y"], env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(str(home / ".config/opencode/command/sync-toolkit.md"), result.stdout)
        self.assertFalse((home / ".config/opencode/command").exists())
        self.assertFalse((home / ".claude").exists())

    def test_interrupted_copy_before_chmod_can_resume(self):
        self.audit()
        hook = self.repo / "scripts/githooks/housekeep"
        hook.parent.mkdir(parents=True)
        hook.write_bytes((SOURCE / "git-hooks/drift-guard/housekeep").read_bytes())
        hook.chmod(0o644)
        self.cli("apply", "--report", str(self.report))
        self.assertTrue(os.access(hook, os.X_OK))

    def test_changed_destination_is_preserved_and_blocks_its_target(self):
        self.audit()
        hook = self.repo / "scripts/githooks/pre-push"
        hook.parent.mkdir(parents=True)
        hook.write_text("#!/bin/sh\necho custom\n")
        self.cli("apply", "--report", str(self.report), expected=1)
        self.assertEqual(hook.read_text(), "#!/bin/sh\necho custom\n")
        self.assertFalse((hook.parent / "housekeep").exists())

    def test_parent_link_added_after_audit_cannot_redirect_installation(self):
        self.audit()
        outside = self.root / "outside"
        outside.mkdir()
        (self.repo / "scripts").symlink_to(outside, target_is_directory=True)
        self.cli("apply", "--report", str(self.report), expected=1)
        self.assertEqual(list(outside.iterdir()), [])

    def test_unrelated_work_is_preserved_and_repeat_apply_is_a_noop(self):
        (self.repo / "application.txt").write_text("unfinished application work\n")
        before = self.git("status", "--porcelain", "--untracked-files=all")
        self.audit()
        self.cli("apply", "--report", str(self.report))
        times = {p.name: p.stat().st_mtime_ns for p in (self.repo / "scripts/githooks").iterdir()}
        self.cli("apply", "--report", str(self.report))
        self.assertEqual(times, {p.name: p.stat().st_mtime_ns for p in (self.repo / "scripts/githooks").iterdir()})
        self.assertEqual((self.repo / "application.txt").read_text(), "unfinished application work\n")
        self.assertEqual(self.data()["repositories"][0]["baseline_status"].replace("\u0000", "\n").strip(), before)

    def test_private_companion_is_a_separate_target_and_custom_privacy_hook_is_kept(self):
        private = self.repo / ".workbench"
        self.git("init", "-q", "-b", "main", str(private))
        self.git("-C", str(private), "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                 "-c", "core.hooksPath=/dev/null", "commit", "-qm", "initial", "--allow-empty")
        hook = self.repo / "scripts/githooks/pre-commit"
        hook.parent.mkdir(parents=True)
        hook.write_text("#!/bin/sh\necho project privacy rules\n")
        hook.chmod(0o755)
        self.audit()
        self.assertEqual(len(self.data()["repositories"]), 2)
        self.cli("apply", "--report", str(self.report))
        self.assertEqual(hook.read_text(), "#!/bin/sh\necho project privacy rules\n")
        self.assertTrue((private / "scripts/githooks/pre-push").exists())
        self.assertFalse((private / "scripts/githooks/pre-commit").exists())

    def test_custom_hook_path_blocks_only_that_repository(self):
        private = self.repo / ".workbench"
        self.git("init", "-q", "-b", "main", str(private))
        self.git("-C", str(private), "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                 "-c", "core.hooksPath=/dev/null", "commit", "-qm", "initial", "--allow-empty")
        self.git("-C", str(private), "config", "core.hooksPath", "custom-hooks")
        self.audit(expected=1)
        self.cli("apply", "--report", str(self.report), expected=1)
        self.assertTrue((self.repo / "scripts/githooks/housekeep").exists())
        self.assertFalse((private / "scripts/githooks").exists())
        self.assertEqual(self.git("-C", str(private), "config", "core.hooksPath"), "custom-hooks")

    def test_source_changes_require_a_new_preview(self):
        checkout = self.root / "toolkit"
        shutil.copytree(SOURCE / "git-hooks", checkout / "git-hooks")
        (checkout / "scripts").mkdir()
        for name in ("sync-toolkit.sh", "toolkit-rollout.py"):
            shutil.copy2(SOURCE / "scripts" / name, checkout / "scripts" / name)
        self.git("init", "-q", "-b", "main", str(checkout), cwd=self.root)
        self.git("-C", str(checkout), "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                 "-c", "core.hooksPath=/dev/null", "commit", "-qm", "initial", "--allow-empty")
        script = checkout / "scripts/toolkit-rollout.py"
        self.cli("audit", "--repo", str(self.repo), "--report", str(self.report), script=script)
        hook = checkout / "git-hooks/drift-guard/housekeep"
        hook.write_text(hook.read_text() + "\n# new source change\n")
        self.cli("apply", "--report", str(self.report), expected=2, script=script)
        self.assertFalse((self.repo / "scripts/githooks").exists())

    def test_installed_validator_is_exercised_in_an_isolated_smoke_repository(self):
        self.audit()
        self.cli("apply", "--report", str(self.report))
        self.cli("verify", "--report", str(self.report), "--require", "tested", expected=1)
        before = self.git("status", "--porcelain", "--untracked-files=all")
        self.cli("smoke", "--report", str(self.report))
        result = self.data()["repositories"][0]["smoke"]
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["valid_exit"], 0)
        self.assertEqual(result["invalid_exit"], 1)
        self.assertEqual(self.git("status", "--porcelain", "--untracked-files=all"), before)
        self.cli("verify", "--report", str(self.report), "--require", "tested")



if __name__ == "__main__":
    unittest.main()
