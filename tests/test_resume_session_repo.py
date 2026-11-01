#!/usr/bin/env python3
"""Tests for the repository side of the resume-session reader: live state, document
discovery, ranking, extraction, and the profile.

Run with: python3 -m unittest discover -s tests -p 'test_resume_session_*.py'
"""

import re
import sys
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from resume_session_support import READER, Sandbox, load_reader, ranked_paths  # noqa: E402

# A time after every fixture commit. Git cannot parse far-future years such as 2999 and
# then matches every commit, so use tomorrow.
FUTURE = (datetime.now(timezone.utc) + timedelta(days=1)).isoformat(timespec="seconds")
SCRIPTS = sorted(READER.parent.glob("*.py"))

GENERIC_PLAN = """# Rollout plan

## Scope

Ship the cache warmer. Exclusions: eviction.

## Steps

- [x] Write the warmer
- [ ] Add the metrics endpoint
  with a counter per run
- [ ] Document the flags
"""

AGENTS = "# Agents\n\nThe active plan is [the rollout plan](docs/plans/rollout.md).\nSee also [a gone file](docs/plans/missing.md).\n"

SDLC_PLAN = """---
created: 2026-10-01
updated: "2026-10-05"
title: "Fixture plan"
type: plan
status: approved
related:
  - 3-design/fixture-design.md
---

# Fixture plan

## Source, authority, and delivery boundary

Approved for T1 and T2 only.

### T1: first step

Depends on: none.

- [x] Complete T1: first step. Code commit: `{sha}`.

### T2: second step

Depends on: T1.

- [ ] Complete T2: second step.

### T3: third step

Depends on: T2.

- [ ] Complete T3: third step.

## Checkpoint, 2026-10-04

T1 committed.

## Checkpoint, 2026-10-05

T2 started.
"""

SDLC_DESIGN = """---
created: 2026-09-30
updated: "2026-09-30"
title: "Fixture design"
type: design
status: approved
reviewed_by:
  - fixture-reviewer
---

# Fixture design
"""

BODY_YAML = """# Notes on metadata

An example of frontmatter, shown in the body:

```yaml
---
date: 2020-01-01
status: approved
---
```

---
status: shipped
---
"""


class GenericProjectTests(unittest.TestCase):
    """A10, first part: a project that follows no documentation method."""

    def setUp(self):
        self.sb = Sandbox()
        self.project = self.sb.repo(self.sb.root / "app", {
            "AGENTS.md": AGENTS,
            "docs/plans/rollout.md": GENERIC_PLAN,
            "src/main.py": "print('hi')\n",
        })

    def tearDown(self):
        self.sb.close()

    def test_declared_plan_without_frontmatter_is_found_with_its_open_item(self):
        result = self.sb.reader("show", "--repo-only", "--cwd", str(self.project), "--since", FUTURE)
        self.assertEqual(result.returncode, 0, result.stderr)
        out = result.stdout
        self.assertEqual(ranked_paths(out)[0], "docs/plans/rollout.md")
        self.assertIn("declared in AGENTS.md", out)
        self.assertIn("> ## Steps", out)
        self.assertIn("> - [ ] Add the metrics endpoint", out)
        self.assertIn("did not apply", out)
        self.assertIn("Declared path not found: `docs/plans/missing.md` (in AGENTS.md)", out)

    def test_uncommitted_document_outranks_declared_ones(self):
        self.sb.write(self.project, {"docs/notes.md": "# Notes\n\n- [ ] Ask about limits\n"})
        result = self.sb.reader("show", "--repo-only", "--cwd", str(self.project), "--since", FUTURE)
        paths = ranked_paths(result.stdout)
        self.assertEqual(paths[0], "docs/notes.md")
        self.assertIn("docs/plans/rollout.md", paths)
        self.assertIn("changed, not by this session", result.stdout)

    def test_unstaged_change_to_a_tracked_document_is_found(self):
        # Only the Git layer can find this document, and its status row starts with a
        # space: " M docs/aside.md".
        self.sb.write(self.project, {"docs/aside.md": "# Aside\n"})
        self.sb.commit(self.project, "aside")
        (self.project / "docs" / "aside.md").write_text("# Aside\n\n- [ ] Follow up\n")
        result = self.sb.reader("show", "--repo-only", "--cwd", str(self.project), "--since", FUTURE,
                                "--profile", "none")
        out = result.stdout
        self.assertEqual(ranked_paths(out)[0], "docs/aside.md", out)
        self.assertIn("; uncommitted changes", out.split("### 1.", 1)[1])

    def test_all_lists_every_document(self):
        self.sb.write(self.project, {f"notes/n{i}.md": f"# Note {i}\n" for i in range(7)})
        result = self.sb.reader("show", "--repo-only", "--cwd", str(self.project), "--since", FUTURE,
                                "--section", "Project documents", "--all")
        paths = ranked_paths(result.stdout)
        self.assertEqual(len(paths), 8, result.stdout)
        self.assertNotIn("more documents", result.stdout)
        capped = self.sb.reader("show", "--repo-only", "--cwd", str(self.project), "--since", FUTURE).stdout
        self.assertEqual(len(ranked_paths(capped)), 5)
        self.assertIn("3 more documents", capped)

    def test_every_timestamp_carries_a_utc_offset(self):
        result = self.sb.reader("show", "--repo-only", "--cwd", str(self.project))
        stamps = re.findall(r"\d{4}-\d{2}-\d{2} \d{2}:\d{2}(?: [+-]\d{2}:\d{2})?", result.stdout)
        self.assertTrue(stamps)
        for stamp in stamps:
            self.assertRegex(stamp, r" [+-]\d{2}:\d{2}$")

    def test_show_writes_nothing(self):
        # The project and the state directory; HOME also holds the interpreter's own caches.
        state = self.sb.home / ".local" / "state"
        before = (self.sb.snapshot(self.project), self.sb.snapshot(state))
        self.sb.reader("show", "--repo-only", "--cwd", str(self.project), "--all")
        self.assertEqual(before, (self.sb.snapshot(self.project), self.sb.snapshot(state)))

    def test_unknown_section_exits_2(self):
        result = self.sb.reader("show", "--repo-only", "--cwd", str(self.project), "--section", "Nope")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Sections:", result.stderr)


class NestedWorkingMemoryTests(unittest.TestCase):
    """A11 and the profile: a root repository with a nested ignored repository that
    holds lifecycle folders."""

    def setUp(self):
        self.sb = Sandbox()
        root = self.sb.root / "toolkit"
        self.root = self.sb.repo(root, {
            ".gitignore": "wm/\n",
            "CLAUDE.md": "# Brief\n\n## Project Map\n\n- **Working memory**: `wm/` - a nested private repository\n",
            "README.md": "# Toolkit\n",
        })
        self.wm = self.sb.repo(root / "wm", {"3-design/fixture-design.md": SDLC_DESIGN})
        sha = self.sb.git(self.wm, "rev-parse", "HEAD")
        self.sb.write(self.wm, {"4-plans/fixture-plan.md": SDLC_PLAN.replace("{sha}", sha[:7])})
        self.sb.commit(self.wm, "plan")

    def tearDown(self):
        self.sb.close()

    def show(self, *extra):
        result = self.sb.reader("show", "--repo-only", "--cwd", str(self.root), "--all", *extra)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def test_live_state_covers_root_and_nested_repository(self):
        out = self.show()
        self.assertIn("### .\n", out)
        self.assertIn("### wm\n", out)
        self.assertIn("- Locations: ., wm", out)

    def test_profile_applies_and_ranks_the_plan_first(self):
        out = self.show()
        self.assertIn("`agentic-sdlc` applied", out)
        self.assertIn("Project Map `Working memory` field in CLAUDE.md", out)
        self.assertEqual(ranked_paths(out)[0], "wm/4-plans/fixture-plan.md")
        self.assertIn("> ## Source, authority, and delivery boundary", out)
        self.assertIn("First open task by the profile rule: T2; its dependencies T1 are ticked", out)
        self.assertIn("> ## Checkpoint, 2026-10-05", out)
        self.assertNotIn("> ## Checkpoint, 2026-10-04", out)
        self.assertIn("`3-design/fixture-design.md`: status approved, reviewed_by fixture-reviewer", out)
        self.assertRegex(out, r"`[0-9a-f]{7}`: reachable from `main` in wm")

    def test_generic_run_keeps_every_candidate_of_the_profile_run(self):
        with_profile = set(ranked_paths(self.show()))
        generic_out = self.show("--profile", "none")
        self.assertIn("Profile: none", generic_out)
        generic = set(ranked_paths(generic_out))
        self.assertTrue(generic)
        self.assertLessEqual(generic, with_profile)

    def test_profile_keeps_a_generic_lesson_and_orders_it_last(self):
        lesson = "---\ntitle: \"A lesson\"\ntype: lesson\nstatus: draft\n---\n\n# A lesson\n"
        self.sb.write(self.root, {"docs/lesson.md": lesson})
        with_profile = ranked_paths(self.show())
        generic = ranked_paths(self.show("--profile", "none"))
        self.assertIn("docs/lesson.md", generic)
        self.assertIn("docs/lesson.md", with_profile)
        self.assertEqual(with_profile[0], "wm/4-plans/fixture-plan.md")
        self.assertEqual(with_profile[-1], "docs/lesson.md")

    def test_ticked_item_with_unknown_commit_is_a_mismatch(self):
        text = (self.wm / "4-plans/fixture-plan.md").read_text()
        text = re.sub(r"Code commit: `[0-9a-f]{7}`", "Code commit: `abc1234`", text)
        self.sb.write(self.wm, {"4-plans/fixture-plan.md": text})
        out = self.show()
        self.assertIn("`abc1234`: not found", out)
        self.assertIn("ticks an item with commit `abc1234`, which no location holds", out)

    def test_ticked_task_without_commit_is_flagged(self):
        text = (self.wm / "4-plans/fixture-plan.md").read_text()
        text = re.sub(r" Code commit: `[0-9a-f]{7}`\.", "", text)
        self.sb.write(self.wm, {"4-plans/fixture-plan.md": text})
        self.assertIn("Ticked with no commit reference: T1", self.show())

    def test_folder_name_alone_does_not_apply_the_profile(self):
        for path in (self.wm / "3-design/fixture-design.md", self.wm / "4-plans/fixture-plan.md"):
            path.write_text(path.read_text().replace("type: ", "kind: "))
        out = self.show()
        self.assertIn("did not apply", out)
        self.assertIn("no document in them has a profile type", out)


class FrontmatterTests(unittest.TestCase):
    """A13: YAML in the document body is never read as metadata."""

    @classmethod
    def setUpClass(cls):
        cls.reader = load_reader()

    def test_body_yaml_is_not_frontmatter(self):
        raw, fields, error = self.reader.read_frontmatter(BODY_YAML)
        self.assertIsNone(raw)
        self.assertIsNone(fields)
        self.assertIsNone(error)

    def test_only_the_byte_zero_block_is_read(self):
        text = "---\ntitle: \"Real\"\nstatus: draft\n---\n\n" + BODY_YAML
        raw, fields, _ = self.reader.read_frontmatter(text)
        self.assertEqual(fields["status"], "draft")
        self.assertNotIn("shipped", raw)
        self.assertNotIn("2020-01-01", raw)

    def test_unclosed_frontmatter_is_reported(self):
        _, fields, error = self.reader.read_frontmatter("---\ntitle: x\n\nbody\n")
        self.assertIsNone(fields)
        self.assertEqual(error, "frontmatter has no closing fence")

    def test_block_and_inline_lists(self):
        _, fields, _ = self.reader.read_frontmatter(
            "---\nscope: [a, b]\nrelated:\n  - x.md\n  - \"y.md\"\n---\n")
        self.assertEqual(fields["scope"], ["a", "b"])
        self.assertEqual(fields["related"], ["x.md", "y.md"])

    def test_headings_and_checkboxes_inside_fences_are_ignored(self):
        headings, checks = self.reader.markdown_structure("# A\n```\n# B\n- [ ] no\n```\n- [ ] yes\n")
        self.assertEqual([h[2] for h in headings], ["A"])
        self.assertEqual([c[2] for c in checks], ["yes"])


class InvariantTests(unittest.TestCase):
    """The reader holds no SDLC vocabulary and never uses modification times."""

    def test_reader_code_holds_no_profile_vocabulary(self):
        import json
        from resume_session_support import PROFILE
        profile = json.loads(PROFILE.read_text())
        words = set(profile["lifecycle_folders"]["value"] + profile["lifecycle_folders"]["legacy"])
        words |= {"brainstorm", "retro", "lesson", "adr", "discovery"}
        # "shipped" is also one of the design's completion-claim keywords, which are plain
        # English and not a status rule.
        words |= set(profile["statuses"]["value"]) - {"open", "draft", "resolved", "shipped"}
        words.add(profile["working_memory"]["project_map_field"])
        for script in SCRIPTS:
            code = script.read_text()
            for word in sorted(words):
                self.assertIsNone(re.search(rf"(?<![\w-]){re.escape(word)}(?![\w-])", code, re.I),
                                  f"{word} in {script.name}")

    def test_reader_never_reads_modification_times(self):
        for script in SCRIPTS:
            self.assertNotRegex(script.read_text(), r"\b(?:st_mtime\w*|getmtime|mtime)\b")

    def test_reader_imports_only_the_standard_library(self):
        allowed = {"argparse", "functools", "json", "os", "re", "shutil", "subprocess", "sys", "datetime",
                   "pathlib", "transcripts"}
        for script in SCRIPTS:
            imports = re.findall(r"^(?:from|import) ([\w.]+)", script.read_text(), re.M)
            self.assertLessEqual(set(i.split(".")[0] for i in imports), allowed, script.name)


if __name__ == "__main__":
    unittest.main()
