import json
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/migrate-lifecycle.py"


class MigrationCLI(unittest.TestCase):
    def test_scaffold_only_supports_private_root_and_refuses_ignored_or_linked_targets(self):
        for scenario in ["private-root", "ignored-folder", "linked-parent", "ignored-placeholder"]:
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                repo = root / "project"
                repo.mkdir()
                def git(*args):
                    return subprocess.check_output(["git", "-C", str(repo), *args])
                git("init", "-q")
                git("config", "user.name", "Fixture")
                git("config", "user.email", "fixture@example.invalid")
                (repo / "README.md").write_text("Keep existing content.\n")
                if scenario == "ignored-folder":
                    (repo / ".gitignore").write_text("2-requirements/\n")
                elif scenario == "linked-parent":
                    (repo / ".gitignore").write_text("2-requirements\n")
                    (repo / "2-requirements").symlink_to(root, target_is_directory=True)
                elif scenario == "ignored-placeholder":
                    (repo / ".gitignore").write_text("2-requirements/.gitkeep\n")
                    (repo / "2-requirements").mkdir()
                    (repo / "2-requirements/.gitkeep").write_text("Do not overwrite.\n")
                git("add", ".")
                git("-c", "core.hooksPath=/dev/null", "commit", "-qm", "fixture")
                manifest = root / "manifest.json"
                manifest.write_text(json.dumps({"projects": [{
                    "repo": str(repo), "revision": git("rev-parse", "HEAD").decode().strip(), "memory": "."
                }]}))
                result = subprocess.run(["python3", str(SCRIPT), "--manifest", str(manifest), "--apply"], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0 if scenario == "private-root" else 1, result.stdout + result.stderr)
                if scenario == "private-root":
                    for folder in ["0-brainstorms", "1-research", "2-requirements", "3-design", "4-plans", "5-reviews", "6-retros"]:
                        self.assertEqual((repo / folder / ".gitkeep").read_bytes(), b"")
                else:
                    self.assertEqual(git("status", "--porcelain"), b"")
                    self.assertFalse((repo / "0-brainstorms").exists())
                self.assertEqual((repo / "README.md").read_text(), "Keep existing content.\n")
                if scenario == "ignored-placeholder":
                    self.assertEqual((repo / "2-requirements/.gitkeep").read_text(), "Do not overwrite.\n")

    def test_preview_apply_and_repeat_preserve_history_and_asset(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repo = root / "project"
            repo.mkdir()
            def git(*args):
                return subprocess.check_output(["git", "-C", str(repo), *args])
            git("init", "-q")
            git("config", "user.name", "Fixture")
            git("config", "user.email", "fixture@example.invalid")
            docs = repo / "docs/2-design"
            docs.mkdir(parents=True)
            original = b'---\ndate: "2026-01-01"\ntitle: Example\ntype: design\nstatus: approved\nauthors: [Human]\nreviewed_by: [human]\n---\nKeep the decision.\n'
            (docs / "example.md").write_bytes(original)
            asset = bytes(range(256))
            (docs / "asset.bin").write_bytes(asset)
            (repo / "README.md").write_text("See docs/2-design/example.md\n")
            git("add", ".")
            git("-c", "core.hooksPath=/dev/null", "commit", "-qm", "fixture")
            revision = git("rev-parse", "HEAD").decode().strip()
            manifest = root / "manifest.json"
            manifest.write_text(json.dumps({"projects": [{
                "repo": str(repo), "revision": revision, "memory": "docs",
                "moves": {"docs/2-design/example.md": "docs/3-design/example.md", "docs/2-design/asset.bin": "docs/3-design/asset.bin"},
                "edits": [{"path": "README.md", "old": "docs/2-design/example.md", "new": "docs/3-design/example.md", "count": 1}]
            }]}))
            def run(*args):
                result = subprocess.run(["python3", str(SCRIPT), "--manifest", str(manifest), *args], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
                return json.loads(result.stdout)["projects"][0]
            preview = run()
            self.assertEqual(preview["state"], "previewed")
            self.assertEqual((docs / "example.md").read_bytes(), original)
            self.assertEqual(git("status", "--porcelain"), b"")
            applied = run("--apply")
            self.assertEqual(applied["state"], "applied")
            migrated = repo / "docs/3-design/example.md"
            self.assertIn(b'created: "2026-01-01"', migrated.read_bytes())
            self.assertIn(b'reviewed_by: [human]', migrated.read_bytes())
            self.assertTrue(migrated.read_bytes().endswith(b'Keep the decision.\n'))
            self.assertEqual((repo / "docs/3-design/asset.bin").read_bytes(), asset)
            self.assertEqual((repo / "README.md").read_text(), "See docs/3-design/example.md\n")
            for folder in ["0-brainstorms", "1-research", "2-requirements", "4-plans", "5-reviews", "6-retros"]:
                self.assertEqual((repo / "docs" / folder / ".gitkeep").read_bytes(), b"")
            self.assertFalse((repo / "docs/3-design/.gitkeep").exists())
            self.assertEqual(run("--apply")["state"], "already-applied")
            git("-c", "core.hooksPath=/dev/null", "commit", "-qm", "migration")
            self.assertEqual(run("--apply")["state"], "already-applied")

    def test_blocked_project_does_not_stop_batch_and_unsafe_edits_are_refused(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            entries = []
            for name in ["dirty", "provenance", "typo", "valid"]:
                repo = root / name
                repo.mkdir()
                def git(*args):
                    return subprocess.check_output(["git", "-C", str(repo), *args])
                git("init", "-q")
                git("config", "user.name", "Fixture")
                git("config", "user.email", "fixture@example.invalid")
                (repo / "record.md").write_text('---\ntitle: Example\ntype: design\nstatus: approved\nreviewed_by: [human]\n---\nBody.\n')
                git("add", ".")
                git("-c", "core.hooksPath=/dev/null", "commit", "-qm", "fixture")
                entry = {"repo": str(repo), "revision": git("rev-parse", "HEAD").decode().strip(), "moves": {"record.md": "moved.md"}}
                if name == "dirty":
                    (repo / "uncommitted.txt").write_text("keep me")
                if name == "provenance":
                    entry["edits"] = [{"path": "record.md", "old": "status: approved", "new": "status: shipped", "count": 1}]
                if name == "typo":
                    entry["move"] = {"record.md": "wrong.md"}
                entries.append(entry)
            manifest = root / "batch.json"
            manifest.write_text(json.dumps({"projects": entries}))
            result = subprocess.run(["python3", str(SCRIPT), "--manifest", str(manifest), "--apply"], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1, result.stderr)
            states = [entry["state"] for entry in json.loads(result.stdout)["projects"]]
            self.assertEqual(states, ["blocked", "blocked", "blocked", "applied"])
            self.assertTrue((root / "valid/moved.md").exists())
            for name in ["dirty", "provenance", "typo"]:
                self.assertTrue((root / name / "record.md").exists())
            self.assertEqual((root / "dirty/uncommitted.txt").read_text(), "keep me")

    def test_unrepaired_link_blocks_without_changing_the_project(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repo = root / "project"
            repo.mkdir()
            def git(*args):
                return subprocess.check_output(["git", "-C", str(repo), *args])
            git("init", "-q")
            git("config", "user.name", "Fixture")
            git("config", "user.email", "fixture@example.invalid")
            (repo / "README.md").write_text("[Design](old.md)\n[Already missing](missing.md)\n")
            (repo / "old.md").write_text("Keep content.\n")
            git("add", ".")
            git("-c", "core.hooksPath=/dev/null", "commit", "-qm", "fixture")
            manifest = root / "manifest.json"
            entry = {"repo": str(repo), "revision": git("rev-parse", "HEAD").decode().strip(), "moves": {"old.md": "new.md"}}
            manifest.write_text(json.dumps({"projects": [entry]}))
            result = subprocess.run(["python3", str(SCRIPT), "--manifest", str(manifest), "--apply"], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertEqual(json.loads(result.stdout)["projects"][0]["state"], "blocked")
            self.assertTrue((repo / "old.md").exists())
            self.assertEqual(git("status", "--porcelain"), b"")
            entry["edits"] = [{"path": "README.md", "old": "old.md", "new": "new.md", "count": 1}]
            manifest.write_text(json.dumps({"projects": [entry]}))
            result = subprocess.run(["python3", str(SCRIPT), "--manifest", str(manifest), "--apply"], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue((repo / "new.md").exists())

    def test_collisions_unsafe_paths_and_changed_sources_leave_files_intact(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repo = root / "project"
            repo.mkdir()
            def git(*args):
                return subprocess.check_output(["git", "-C", str(repo), *args])
            git("init", "-q")
            git("config", "user.name", "Fixture")
            git("config", "user.email", "fixture@example.invalid")
            (repo / "old.md").write_text("Original.\n")
            (repo / "occupied.md").write_text("Keep.\n")
            (repo / ".gitignore").write_text("ignored.md\nnested/\nlinked\n")
            git("add", ".")
            git("-c", "core.hooksPath=/dev/null", "commit", "-qm", "fixture")
            revision = git("rev-parse", "HEAD").decode().strip()
            (repo / "ignored.md").write_text("Ignored but important.\n")
            manifest = root / "manifest.json"
            (repo / "nested/.git").mkdir(parents=True)
            (repo / "linked").symlink_to(root, target_is_directory=True)
            for target in ["occupied.md", "ignored.md", "../escape.md", ".git/config", "nested/new.md", "linked/new.md"]:
                with self.subTest(target=target):
                    manifest.write_text(json.dumps({"projects": [{"repo": str(repo), "revision": revision, "moves": {"old.md": target}}]}))
                    result = subprocess.run(["python3", str(SCRIPT), "--manifest", str(manifest), "--apply"], capture_output=True, text=True)
                    self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                    self.assertEqual(git("status", "--porcelain"), b"")
                    self.assertEqual((repo / "old.md").read_text(), "Original.\n")
            (repo / "occupied.md").write_text("Later legitimate edit.\n")
            git("add", ".")
            git("-c", "core.hooksPath=/dev/null", "commit", "-qm", "later")
            manifest.write_text(json.dumps({"projects": [{"repo": str(repo), "revision": revision, "moves": {"old.md": "new.md"}}]}))
            result = subprocess.run(["python3", str(SCRIPT), "--manifest", str(manifest), "--apply"], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertEqual((repo / "occupied.md").read_text(), "Later legitimate edit.\n")
            self.assertEqual((repo / "ignored.md").read_text(), "Ignored but important.\n")
            self.assertFalse((root / "escape.md").exists())


if __name__ == "__main__":
    unittest.main()
