"""Exercise frontmatter compatibility and migration through their CLIs."""

import os
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
HOOKS = [ROOT / "git-hooks/drift-guard/housekeep", ROOT / "scripts/githooks/housekeep"]
MIGRATOR = ROOT / "scripts/migrate-frontmatter.py"


class GitFixture(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.repo = Path(self.temporary.name)
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.invalid")
        self.git("commit", "-q", "--allow-empty", "-m", "Initial")

    def git(self, *arguments, env=None):
        return subprocess.run(
            ["git", "-C", str(self.repo), *arguments],
            text=True, capture_output=True, check=True, env=env,
        ).stdout.strip()

    def commit(self, message="Document", date=None):
        env = os.environ.copy()
        if date:
            env.update(GIT_AUTHOR_DATE=date, GIT_COMMITTER_DATE=date)
        self.git("add", "--all")
        self.git("commit", "-q", "-m", message, env=env)
        return self.git("rev-parse", "HEAD")


class HookDateTests(GitFixture):
    def check_dates(self, dates, expected, newline="\n", kind="design", status="draft"):
        document = self.repo / "docs/3-design/feature.md"
        document.parent.mkdir(parents=True, exist_ok=True)
        text = (
            '---\n' + dates + f'\ntitle: Feature\ntype: {kind}\nstatus: {status}\n'
            'authors: ["C"]\n---\nBody.\n'
        )
        document.write_bytes(text.replace("\n", newline).encode())
        self.commit()
        for hook in HOOKS:
            with self.subTest(hook=hook, dates=dates):
                result = subprocess.run(
                    [str(hook), "check", "--push", "HEAD~1", "HEAD"],
                    cwd=self.repo, text=True, capture_output=True,
                )
                self.assertEqual(result.returncode, expected, result.stderr)

    def test_canonical_fields_require_updated(self):
        self.check_dates('created: "2026-10-29"', 1)

    def test_crlf_frontmatter_is_supported(self):
        self.check_dates('created: 2026-10-29\nupdated: 2026-10-30', 0, "\r\n")

    def test_quoted_types_and_statuses_still_receive_date_checks(self):
        self.check_dates('created: 2026-10-29', 1, kind="'design' # category")
        self.check_dates(
            'created: 2026-10-29\nupdated: 2026-10-30', 1,
            kind="'design' # category", status="'mystery' # invalid",
        )
        self.check_dates(
            'created: 2026-10-29\nupdated: 2026-10-30', 0,
            kind="'design' # category", status="'draft' # awaiting review",
        )

    def test_canonical_dates_are_real_and_ordered(self):
        for dates, expected in [
            ('created: 2026-02-30\nupdated: 2026-10-30', 1),
            ('created: 2026-10-30\nupdated: 2026-10-29', 1),
            ('created: 2024-02-29\nupdated: 2026-10-30', 0),
            ("created: '2026-10-29' # original\nupdated: '2026-10-30'", 0),
            ('date: 2026-10-28\ncreated: 2026-10-29\nupdated: 2026-10-30', 1),
        ]:
            self.check_dates(dates, expected)

    def test_created_and_updated_replace_legacy_date(self):
        document = self.repo / "docs/3-design/feature.md"
        document.parent.mkdir(parents=True)
        document.write_text(
            '---\ncreated: "2026-10-29"\nupdated: "2026-10-30"\n'
            'title: Feature\ntype: design\nstatus: draft\nauthors: ["C"]\n---\nBody.\n'
        )
        self.commit()
        for hook in HOOKS:
            with self.subTest(hook=hook):
                result = subprocess.run(
                    [str(hook), "check", "--push", "HEAD~1", "HEAD"],
                    cwd=self.repo, text=True, capture_output=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)


class MigrationTests(GitFixture):
    def migrate(self, *arguments):
        return subprocess.run(
            [sys.executable, str(MIGRATOR), "--root", str(self.repo), *arguments],
            text=True, capture_output=True,
        )

    def test_preview_apply_and_repeat_preserve_unrelated_content(self):
        document = self.repo / "1-discovery/research.md"
        document.parent.mkdir()
        document.write_text(
            "---\ndate: '2024-01-10' # original document date\n"
            'title: Research\ntype: discovery # legacy name\nstatus: approved\n'
            'authors:\n  - "C"\nreviewed_by: ["human"]\n'
            'custom: "Keep this field"\n---\n'
            'Original prose.\n```yaml\ndate: keep this example\n```\n'
        )
        original = document.read_bytes()
        document.chmod(0o640)
        asset = document.parent / "assets/raw.md"
        asset.parent.mkdir()
        asset.write_text("Historical evidence without frontmatter.\n")
        self.commit(date="2024-02-13T12:00:00+00:00")

        result = self.migrate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["changed_count"], 1)
        self.assertEqual(document.read_bytes(), original)

        result = self.migrate("--apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        text = document.read_text()
        self.assertIn("created: '2024-01-10' # original document date", text)
        self.assertIn('updated: "2024-02-13"', text)
        self.assertIn("type: research # legacy name", text)
        self.assertIn('reviewed_by: ["human"]', text)
        self.assertIn('custom: "Keep this field"', text)
        self.assertEqual(text.split("---", 2)[2], original.decode().split("---", 2)[2])
        self.assertEqual(document.stat().st_mode & 0o777, 0o640)
        self.assertEqual(asset.read_text(), "Historical evidence without frontmatter.\n")
        migrated = document.read_bytes()
        result = self.migrate("--apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["changed_count"], 0)
        self.assertEqual(document.read_bytes(), migrated)

    def test_fixed_revision_and_path_map_recover_pre_rename_update(self):
        old = self.repo / "2-design/feature.md"
        old.parent.mkdir()
        old.write_text(
            '---\ndate: 2024-01-10\ntitle: Feature\ntype: design\n'
            'status: approved\nauthors: ["C"]\n---\nApproved behavior.\n'
        )
        revision = self.commit(date="2024-02-13T12:00:00+00:00")
        current = self.repo / "3-design/feature.md"
        current.parent.mkdir()
        old.rename(current)
        mapping = self.repo / "mapping.json"
        mapping.write_text(json.dumps({"2-design/feature.md": "3-design/feature.md"}))
        self.commit("Rename folders", date="2024-10-11T12:00:00+00:00")
        result = self.migrate(
            "--source-revision", revision, "--path-map", str(mapping), "--apply",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('updated: "2024-02-13"', current.read_text())
        self.assertNotIn("2024-10-11", current.read_text())

    def test_ignore_mechanical_commit_retains_later_content_updates(self):
        old = self.repo / "2-design"
        old.mkdir()
        for name in ("a.md", "b.md"):
            (old / name).write_text('---\ndate: 2024-01-10\ntype: design\n---\nBody.\n')
        self.commit(date="2024-02-13T12:00:00+00:00")
        current = self.repo / "3-design"
        old.rename(current)
        mechanical = self.commit("Move folders", date="2024-10-11T12:00:00+00:00")
        first = current / "a.md"
        first.write_text(first.read_text() + "New execution evidence.\n")
        self.commit("Record progress", date="2024-10-20T12:00:00+00:00")
        result = self.migrate("--ignore-revision", mechanical, "--apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('updated: "2024-10-20"', first.read_text())
        self.assertIn('updated: "2024-02-13"', (current / "b.md").read_text())

    def test_conflict_aborts_entire_batch(self):
        folder = self.repo / "3-design"
        folder.mkdir()
        first = folder / "a.md"
        first.write_text('---\ndate: 2024-01-10\ntype: design\n---\nFirst.\n')
        second = folder / "b.md"
        second.write_text(
            '---\ndate: 2024-01-10\ncreated: 2024-01-11\n'
            'updated: 2024-02-13\ntype: design\n---\nSecond.\n'
        )
        self.commit(date="2024-02-13T12:00:00+00:00")
        original = {p: p.read_bytes() for p in (first, second)}
        result = self.migrate("--apply")
        self.assertEqual(result.returncode, 1)
        self.assertIn("conflicts", result.stdout)
        self.assertEqual({p: p.read_bytes() for p in original}, original)

    def test_existing_dates_are_preserved(self):
        document = self.repo / "3-design/a.md"
        document.parent.mkdir()
        document.write_text(
            '---\ndate: 2024-01-10\ncreated: 2024-01-10\n'
            'updated: 2024-01-11\nlast_reviewed: 2024-01-15\ntype: design\n---\nBody.\n'
        )
        self.commit(date="2024-02-13T12:00:00+00:00")
        result = self.migrate("--apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("\ndate:", document.read_text())
        self.assertIn("updated: 2024-01-11", document.read_text())
        self.assertIn("last_reviewed: 2024-01-15", document.read_text())

    def test_dirty_documents_are_not_overwritten(self):
        document = self.repo / "3-design/a.md"
        document.parent.mkdir()
        document.write_text('---\ndate: 2024-01-10\ntype: design\n---\nBody.\n')
        self.commit(date="2024-02-13T12:00:00+00:00")
        document.write_text(document.read_text() + "Uncommitted work.\n")
        original = document.read_bytes()
        result = self.migrate("--apply")
        self.assertEqual(result.returncode, 1)
        self.assertIn("reconcile", result.stderr)
        self.assertEqual(document.read_bytes(), original)

    def test_missing_history_does_not_invent_an_update_date(self):
        document = self.repo / "3-design/a.md"
        document.parent.mkdir()
        document.write_text('---\ndate: 2024-01-10\ntype: design\n---\nBody.\n')
        original = document.read_bytes()
        result = self.migrate("--apply")
        self.assertEqual(result.returncode, 1)
        self.assertIn("no recorded Git update date", result.stdout)
        self.assertEqual(document.read_bytes(), original)

    def test_linked_lifecycle_directory_is_not_followed(self):
        archive = self.repo / "archive"
        archive.mkdir()
        document = archive / "original.md"
        document.write_text(
            '---\ndate: 2024-01-10\ncreated: 2024-01-10\nupdated: 2024-02-13\n'
            'type: design\n---\nHistorical evidence.\n'
        )
        (self.repo / "3-design").symlink_to(archive, target_is_directory=True)
        self.commit(date="2024-02-13T12:00:00+00:00")
        original = document.read_bytes()
        result = self.migrate("--apply")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(document.read_bytes(), original)

    def test_ambiguous_frontmatter_is_not_rewritten(self):
        document = self.repo / "3-design/a.md"
        document.parent.mkdir()
        for fields in [
            "date: 2024-01-10\ndate: 2024-01-11\nupdated: 2024-02-13\ntype: design",
            "date: 2024-01-10\nupdated: 2024-02-13\ntype: >\n  discovery",
            'created: 2024-01-10\nupdated: 2024-02-13\n"date": 2024-01-09\ntype: design',
            "date: ' 2024-01-10 '\nupdated: 2024-02-13\ntype: design",
            "date: 2024-01-10#not-a-comment\nupdated: 2024-02-13\ntype: design",
        ]:
            document.write_text('---\n' + fields + '\n---\nBody.\n')
            self.commit(date="2024-02-13T12:00:00+00:00")
            original = document.read_bytes()
            result = self.migrate("--apply")
            self.assertEqual(result.returncode, 1)
            self.assertEqual(document.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
