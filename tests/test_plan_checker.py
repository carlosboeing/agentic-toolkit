#!/usr/bin/env python3
"""Tests for the advisory plan checker at skills/start-planning/scripts/check-plan.py.

Run with: python3 -m unittest discover -s tests -p 'test_plan_checker.py'
"""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CHECKER = REPO / "skills" / "start-planning" / "scripts" / "check-plan.py"
FIXTURES = REPO / "tests" / "fixtures" / "sdlc"


def run_check(fixture_name):
    return subprocess.run(
        [sys.executable, str(CHECKER), str(FIXTURES / fixture_name)],
        capture_output=True, text=True, cwd=str(REPO),
    )


class PlanCheckerTests(unittest.TestCase):
    def assert_finding(self, fixture_name, needle):
        result = run_check(fixture_name)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(needle, result.stdout)

    # Positive fixtures

    def test_substantial_plan_is_accepted(self):
        result = run_check("plan-substantial.md")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("0 finding", result.stdout)

    def test_compact_plan_is_accepted_without_shape_demands(self):
        result = run_check("plan-compact.md")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("0 finding", result.stdout)
        for forbidden in ("task count", "heading", "command in every task",
                          "failing test"):
            self.assertNotIn(forbidden, result.stdout)

    def test_self_dependency_reported_without_blocking(self):
        with tempfile.TemporaryDirectory() as tmp:
            plan = Path(tmp) / "plan.md"
            plan.write_text("---\ntype: plan\n---\n- T1: Check graph. Depends on: T1. Verification: test.\n")
            result = subprocess.run([sys.executable, str(CHECKER), str(plan)],
                                    capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn("dependency cycle: T1 -> T1", result.stdout)

    def test_cycle_in_a_disconnected_component_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            plan = Path(tmp) / "plan.md"
            plan.write_text("---\ntype: plan\n---\n"
                            "- T1: Check root. Depends on: none. Verification: test.\n"
                            "- T2: Check second. Depends on: T3. Verification: test.\n"
                            "- T3: Check third. Depends on: T2. Verification: test.\n")
            result = subprocess.run([sys.executable, str(CHECKER), str(plan)],
                                    capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn("dependency cycle: T2 -> T3 -> T2", result.stdout)

    def test_unrecognized_dependencies_are_not_treated_as_validated(self):
        with tempfile.TemporaryDirectory() as tmp:
            plan = Path(tmp) / "plan.md"
            plan.write_text("---\ntype: plan\n---\n"
                            "- T1: Check first. Depends on: previous stage. Verification: test.\n"
                            "- T2: Check second. Verification: test.\n"
                            "- T3: Check third. Depends on: T2 and external approval. Verification: test.\n")
            result = subprocess.run([sys.executable, str(CHECKER), str(plan)],
                                    capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn("unable to check: task T1 dependencies", result.stdout)
        self.assertIn("unable to check: task T2 dependencies", result.stdout)
        self.assertIn("unable to check: task T3 dependencies", result.stdout)

    def test_dependency_table_cycle_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            plan = Path(tmp) / "plan.md"
            plan.write_text("---\ntype: plan\n---\n"
                            "| Task | Objective | Depends on | Verification |\n"
                            "|---|---|---|---|\n"
                            "| T1 | first | T2 | test |\n"
                            "| T2 | second | T1 | test |\n")
            result = subprocess.run([sys.executable, str(CHECKER), str(plan)],
                                    capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn("dependency cycle: T1 -> T2 -> T1", result.stdout)

    def test_valid_dependency_table_has_no_graph_findings(self):
        with tempfile.TemporaryDirectory() as tmp:
            plan = Path(tmp) / "plan.md"
            plan.write_text("---\ntype: plan\n---\n"
                            "| Task | Objective | Depends on | Verification |\n"
                            "|---|---|---|---|\n"
                            "| T1 | Check self-dependencies when parsed | none | test |\n"
                            "| T2 | second | T1 | test |\n")
            result = subprocess.run([sys.executable, str(CHECKER), str(plan)],
                                    capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertNotIn("dependency cycle", result.stdout)
        self.assertNotIn("dependencies not recognized", result.stdout)
        self.assertNotIn("unresolved dependency", result.stdout)

    # One labeled omission per mechanical finding class

    def test_missing_frontmatter_reported(self):
        self.assert_finding("plan-missing-frontmatter.md", "missing frontmatter")

    def test_broken_design_link_reported(self):
        self.assert_finding("plan-broken-design-link.md", "broken design link")

    def test_duplicate_task_ids_reported(self):
        self.assert_finding("plan-duplicate-ids.md", "duplicate task ID")

    def test_unresolved_dependency_reported(self):
        self.assert_finding("plan-unresolved-dep.md", "unresolved dependency")

    def test_missing_verification_reported(self):
        self.assert_finding("plan-missing-verification.md", "no verification evidence")

    def test_missing_coverage_reported(self):
        self.assert_finding("plan-missing-coverage.md", "coverage")

    def test_unparseable_presentation_reports_unable_to_check(self):
        self.assert_finding("plan-unparseable.md", "unable to check")

    def test_heading_task_sections_recognized(self):
        result = run_check("plan-heading-tasks.md")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("0 finding", result.stdout)

    def test_bare_id_task_lines_recognized(self):
        result = run_check("plan-bare-id-tasks.md")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("0 finding", result.stdout)

    def test_lowercase_noise_is_not_a_requirement_id(self):
        result = run_check("plan-design-noise.md")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("0 finding", result.stdout)
        self.assertNotIn("i18n", result.stdout)

    def test_unparseable_tasks_downgrade_coverage_to_unable(self):
        result = run_check("plan-unparseable-nocover.md")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("unable to check: design coverage", result.stdout)
        self.assertNotIn("absent design coverage", result.stdout)

    def test_design_without_requirement_ids_reports_unable(self):
        result = run_check("plan-design-noids.md")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("unable to check: design requirement", result.stdout)
        self.assertNotIn("absent design coverage", result.stdout)

    def test_frontmatter_authors_are_not_requirement_ids(self):
        result = run_check("plan-prose-credit.md")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("AGENT3", result.stdout)
        self.assertNotIn("BOT7", result.stdout)

    def test_prose_mention_does_not_credit_coverage(self):
        result = run_check("plan-prose-credit.md")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("absent design coverage: no design requirement is mapped",
                      result.stdout)

    def test_requirement_id_in_dependency_phrase_is_not_unresolved(self):
        result = run_check("plan-dep-requirement.md")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("0 finding", result.stdout)

    def test_help_states_the_verification_heuristic(self):
        result = subprocess.run(
            [sys.executable, str(CHECKER), "--help"],
            capture_output=True, text=True, cwd=str(REPO),
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("keyword", result.stdout)
        self.assertIn("verif", result.stdout)

    # Output and exit semantics

    def test_findings_name_file_and_task_when_available(self):
        result = run_check("plan-unresolved-dep.md")
        self.assertIn("plan-unresolved-dep.md", result.stdout)
        self.assertIn("N1", result.stdout)

    def test_missing_file_is_an_error(self):
        result = subprocess.run(
            [sys.executable, str(CHECKER), str(FIXTURES / "nope.md")],
            capture_output=True, text=True, cwd=str(REPO),
        )
        self.assertNotEqual(result.returncode, 0)

    def test_no_arguments_is_an_error(self):
        result = subprocess.run(
            [sys.executable, str(CHECKER)],
            capture_output=True, text=True, cwd=str(REPO),
        )
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
