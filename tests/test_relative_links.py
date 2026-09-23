#!/usr/bin/env python3
"""
tests/test_relative_links.py — unit tests for scripts/check-relative-links.py.
"""

import os
import shutil
import tempfile
import unittest

from scripts.check_relative_links import (
    check_file_links,
    clean_target,
    extract_links_from_content,
    get_public_tracked_md_files,
    is_external_or_anchor,
    is_template_placeholder,
)

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class TestFixtureExclusion(unittest.TestCase):
    def test_negative_fixtures_are_excluded_from_public_link_scan(self):
        files = get_public_tracked_md_files(REPO_ROOT)
        self.assertFalse([f for f in files if f.startswith("tests/fixtures/")])


class TestRelativeLinks(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_valid_relative_link(self):
        # Create target and source
        target_path = os.path.join(self.tmpdir, "target.md")
        with open(target_path, "w") as f:
            f.write("# Target\n")

        source_path = os.path.join(self.tmpdir, "source.md")
        with open(source_path, "w") as f:
            f.write("See [valid link](target.md) for info.\n")

        failures = check_file_links("source.md", self.tmpdir)
        self.assertEqual(failures, [], "Valid relative link should succeed")

    def test_missing_target(self):
        source_path = os.path.join(self.tmpdir, "source.md")
        with open(source_path, "w") as f:
            f.write("Line 1\nSee [broken link](missing.md)\n")

        failures = check_file_links("source.md", self.tmpdir)
        self.assertEqual(len(failures), 1)
        self.assertIn("source.md:2: missing.md", failures[0])

    def test_encoded_spaces(self):
        target_path = os.path.join(self.tmpdir, "target with space.md")
        with open(target_path, "w") as f:
            f.write("# Target with Space\n")

        source_path = os.path.join(self.tmpdir, "source.md")
        with open(source_path, "w") as f:
            f.write("See [encoded link](target%20with%20space.md)\n")

        failures = check_file_links("source.md", self.tmpdir)
        self.assertEqual(failures, [], "Encoded space %20 should resolve properly")

    def test_reference_definitions(self):
        target_path = os.path.join(self.tmpdir, "ref_target.md")
        with open(target_path, "w") as f:
            f.write("# Ref Target\n")

        source_path = os.path.join(self.tmpdir, "source.md")
        with open(source_path, "w") as f:
            f.write("See [link][ref1]\n\n[ref1]: ref_target.md\n")

        failures = check_file_links("source.md", self.tmpdir)
        self.assertEqual(failures, [], "Reference definition target should resolve")

    def test_html_links(self):
        target_path = os.path.join(self.tmpdir, "html_target.md")
        with open(target_path, "w") as f:
            f.write("# HTML Target\n")

        source_path = os.path.join(self.tmpdir, "source.md")
        with open(source_path, "w") as f:
            f.write('<a href="html_target.md">Click here</a>\n')

        failures = check_file_links("source.md", self.tmpdir)
        self.assertEqual(failures, [], "HTML href target should resolve")

    def test_fenced_code_examples(self):
        source_path = os.path.join(self.tmpdir, "source.md")
        with open(source_path, "w") as f:
            f.write("```markdown\n[example](nonexistent_example.md)\n```\n")

        failures = check_file_links("source.md", self.tmpdir)
        self.assertEqual(failures, [], "Fenced code blocks should be skipped")

    def test_deliberate_template_placeholders(self):
        # 1. Placeholders with angle brackets
        content = "Visit [issues](https://github.com/<OWNER>/<REPO>/issues) or see [<OWNER>](<OWNER>).\n"
        links = extract_links_from_content(content, "templates/default-project-oss/SUPPORT.md")
        self.assertEqual(links, [], "Angle bracket placeholders should be excluded")

        # 2. Narrow docs/architecture.md in templates/
        content_tpl = "> See [docs/architecture.md](docs/architecture.md).\n"
        links_tpl = extract_links_from_content(content_tpl, "templates/default-project/README.md")
        self.assertEqual(links_tpl, [], "docs/architecture.md in templates/ should be exempt")

        # 3. docs/architecture.md OUTSIDE templates/ is NOT exempt
        links_outside = extract_links_from_content(content_tpl, "guides/some-guide.md")
        self.assertEqual(len(links_outside), 1, "docs/architecture.md outside templates/ must be checked")

    def test_deliberately_missing_real_target_fails(self):
        source_path = os.path.join(self.tmpdir, "broken.md")
        with open(source_path, "w") as f:
            f.write("Broken link to [nonexistent file](definitely_missing_file_123.md)\n")

        failures = check_file_links("broken.md", self.tmpdir)
        self.assertTrue(len(failures) > 0, "Deliberately missing real target must fail")
        self.assertIn("definitely_missing_file_123.md", failures[0])


if __name__ == "__main__":
    unittest.main()
