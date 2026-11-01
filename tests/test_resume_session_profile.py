#!/usr/bin/env python3
"""Contract test for the resume-session SDLC profile.

The profile re-states rules from their sources instead of importing another skill. This
test fails when a re-stated rule drifts: the task patterns against
skills/start-planning/scripts/check-plan.py, and the types, statuses, lifecycle folders,
and date fields against guide sections 2.5 and 5.4.

Run with: python3 -m unittest discover -s tests -p 'test_resume_session_profile.py'
"""

import copy
import importlib.util
import json
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from resume_session_support import PROFILE, REPO, load_reader  # noqa: E402

CHECKER = REPO / "skills" / "start-planning" / "scripts" / "check-plan.py"
GUIDE = REPO / "guides" / "guide-project-structure-and-conventions.md"
FIXTURES = REPO / "tests" / "fixtures" / "sdlc"


def load_checker():
    spec = importlib.util.spec_from_file_location("check_plan", CHECKER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def checker_tasks(checker, text):
    """Task IDs and dependencies as check-plan.py parses them."""
    order, blocks, _, _ = checker.parse_tasks(checker.strip_frontmatter(text).splitlines(), set())
    known = set(order)
    tasks = []
    for nid in order:
        deps = []
        for match in checker.DEP_PHRASE.finditer("\n".join(blocks[nid])):
            for token in checker.ID_TOKEN.findall(match.group("deps")):
                key = checker.norm(token)
                if key in known and key not in deps:
                    deps.append(key)
        tasks.append((nid, deps))
    return tasks


def guide_vocabulary():
    text = GUIDE.read_text()
    types = re.search(r"^type: \w+\s+# (.+)$", text, re.M).group(1)
    statuses = re.search(r"^status: \w+\s+# (.+)$", text, re.M).group(1)
    schema_a = re.search(r"^\*\*Schema A[^\n]*$", text, re.M).group(0)
    legacy = re.search(r"^Existing projects may still use [^\n]*$", text, re.M).group(0)
    core = re.search(r"^- \*\*Core field names[^\n]*$", text, re.M).group(0)
    return {
        "types": [t.strip() for t in types.split("|")],
        "statuses": [s.strip() for s in statuses.split("|")],
        "folders": re.findall(r"`(\d-[a-z-]+)/`", schema_a),
        "legacy_folders": re.findall(r"`(\d-[a-z-]+)/`", legacy),
        "legacy_types": re.findall(r"[Ll]egacy `type: (\w+)`", text),
        "core": core,
    }


def differences(data, checker, reader):
    """Every way the profile data differs from its sources."""
    found = []
    patterns = data["task_patterns"]
    task_id = patterns["id"]
    pairs = [
        ("id", checker.ID, re.compile(task_id)),
        ("task_head", checker.TASK_HEAD.pattern, None),
        ("task_bullet", checker.TASK_BULLET.pattern, None),
        ("task_table", checker.TASK_TABLE.pattern, None),
        ("task_bare", checker.TASK_BARE.pattern, None),
        ("dep_phrase", checker.DEP_PHRASE.pattern, None),
    ]
    for key, source, _ in pairs:
        restated = task_id if key == "id" else patterns[key].replace("{ID}", task_id)
        if restated != source:
            found.append(f"task pattern {key} differs from check-plan.py")
    profile = reader.Profile(data)
    for plan in sorted(FIXTURES.glob("plan-*.md")):
        text = plan.read_text()
        ours = [(nid, deps) for nid, _, deps in reader.parse_plan_tasks(text, profile)]
        if ours != checker_tasks(checker, text):
            found.append(f"tasks parsed from {plan.name} differ from check-plan.py")
    guide = guide_vocabulary()
    if data["types"]["value"] != guide["types"]:
        found.append("types differ from guide section 5.4")
    if data["types"]["legacy"] != guide["legacy_types"]:
        found.append("legacy types differ from guide section 5.4")
    if data["statuses"]["value"] != guide["statuses"]:
        found.append("statuses differ from guide section 5.4")
    if not set(data["statuses"]["still_open"]) <= set(guide["statuses"]):
        found.append("still-open statuses are not all guide statuses")
    if data["lifecycle_folders"]["value"] != guide["folders"]:
        found.append("lifecycle folders differ from guide section 5.4 Schema A")
    if data["lifecycle_folders"]["legacy"] != guide["legacy_folders"]:
        found.append("legacy lifecycle folders differ from guide section 2.5")
    for name in data["date_fields"]["value"]:
        if f"`{name}`" not in guide["core"]:
            found.append(f"date field {name} is not in guide section 5.4 core fields")
    ranked = {t for group in data["types"]["rank"] for t in group}
    if not ranked <= set(guide["types"]) | set(guide["legacy_types"]):
        found.append("type rank names a type the guide does not define")
    return found


class ProfileContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.checker = load_checker()
        cls.reader = load_reader()
        cls.data = json.loads(PROFILE.read_text())

    def test_shipped_profile_matches_its_sources(self):
        self.assertEqual(differences(self.data, self.checker, self.reader), [])

    def test_fixture_plans_yield_tasks(self):
        profile = self.reader.Profile(self.data)
        parsed = [self.reader.parse_plan_tasks(p.read_text(), profile) for p in FIXTURES.glob("plan-*.md")]
        self.assertTrue(any(parsed))

    def test_every_value_names_its_source(self):
        for key, value in self.data.items():
            if isinstance(value, dict):
                self.assertTrue(value.get("source"), key)

    def mutated(self, change):
        data = copy.deepcopy(self.data)
        change(data)
        return differences(data, self.checker, self.reader)

    def test_a_changed_task_pattern_fails(self):
        def change(data):
            data["task_patterns"]["dep_phrase"] = data["task_patterns"]["dep_phrase"].replace("depends", "needs")
        found = self.mutated(change)
        self.assertIn("task pattern dep_phrase differs from check-plan.py", found)
        self.assertTrue(any(f.startswith("tasks parsed from") for f in found))

    def test_a_changed_status_fails(self):
        found = self.mutated(lambda data: data["statuses"]["value"].__setitem__(0, "pending"))
        self.assertIn("statuses differ from guide section 5.4", found)

    def test_a_changed_type_fails(self):
        found = self.mutated(lambda data: data["types"]["value"].remove("lesson"))
        self.assertIn("types differ from guide section 5.4", found)

    def test_a_changed_folder_fails(self):
        found = self.mutated(lambda data: data["lifecycle_folders"]["value"].__setitem__(4, "4-plan"))
        self.assertIn("lifecycle folders differ from guide section 5.4 Schema A", found)

    def test_a_changed_date_field_fails(self):
        found = self.mutated(lambda data: data["date_fields"]["value"].__setitem__(0, "modified"))
        self.assertIn("date field modified is not in guide section 5.4 core fields", found)


if __name__ == "__main__":
    unittest.main()
