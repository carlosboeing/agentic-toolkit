#!/usr/bin/env python3
"""Disposable fixture harness for start-implementation controller trials.

Usage:
    python3 tests/sdlc-controller-fixture.py cases
    python3 tests/sdlc-controller-fixture.py setup <case>
    python3 tests/sdlc-controller-fixture.py state <case>
    python3 tests/sdlc-controller-fixture.py assert <case>

``setup`` creates disposable repositories for one case under the fixture
root (env ``SDLC_FIXTURE_ROOT``, default ``<system temp>/sdlc-controller-fixture``)
and prints their paths. A controller session then runs the case from those
paths. ``assert`` checks the resulting state against the case's declared
expectations and exits nonzero on any mismatch. ``state`` prints the
measured values for the trial record.

Every case declares its expected marker count, task ticks, code SHA
reachability, and merge state. Effects are simulated with marker files in
the code repository; this script never performs a real external effect and
never touches a real remote.

Tick convention: a task box is checked as ``- [x] <id>: ...`` and the line
records the code commit after the word ``commit``, e.g.
``- [x] W1: ... - commit 1a2b3c4``.
"""

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

SHA_IN_TICK = re.compile(r"\bcommit ([0-9a-f]{7,40})\b")
ALIASES = {
    "interrupted-effect": "interrupted",
    "squash-merge-record": "squash-merge",
}


# --- helpers ---------------------------------------------------------------

def sh(cwd, *args):
    return subprocess.run(
        ["git", "-c", "user.name=Fixture", "-c", "user.email=f@example.com", *args],
        cwd=str(cwd), check=True, capture_output=True, text=True,
    ).stdout.strip()


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def init_repo(path, initial_files):
    path.mkdir(parents=True, exist_ok=True)
    sh(path, "init", "-q", "-b", "main")
    for rel, text in initial_files.items():
        write(path / rel, text)
    sh(path, "add", "-A")
    sh(path, "commit", "-qm", "fixture init")
    return sh(path, "rev-parse", "HEAD")


def marker_files(code):
    effects = code / "effects"
    return sorted(effects.glob("*.marker")) if effects.exists() else []


def plan_lines(plan):
    ticks = {}
    for line in (plan / "PLAN.md").read_text().splitlines():
        m = re.match(r"^- \[( |x)\] ([A-Za-z0-9]+):", line)
        if m:
            ticks[m.group(2)] = (m.group(1) == "x", line)
    return ticks


def measured(case_dir):
    code, plan = case_dir / "code", case_dir / "plan"
    out = {
        "markers": len(marker_files(code)),
        "ticks": {},
        "reachable": 0,
        "merge": "none",
    }
    if (plan / "PLAN.md").exists():
        for tid, (checked, line) in sorted(plan_lines(plan).items()):
            out["ticks"][tid] = checked
            if checked:
                m = SHA_IN_TICK.search(line)
                sha = m.group(1) if m else ""
                resolves = bool(sha) and subprocess.run(
                    ["git", "cat-file", "-e", f"{sha}^{{commit}}"],
                    cwd=str(code), capture_output=True,
                ).returncode == 0
                # The recorded SHA must carry the task's own change, so a
                # tick pointing at an unrelated (or empty) commit cannot pass.
                carries_change = resolves and subprocess.run(
                    ["git", "grep", "-q", f"task-{tid}", sha],
                    cwd=str(code), capture_output=True,
                ).returncode == 0
                if carries_change:
                    out["reachable"] += 1
    delivery = plan / "delivery.md"
    if delivery.exists() and "merge-sha:" in delivery.read_text():
        out["merge"] = "merged-simulated"
    return out


# --- plan text -------------------------------------------------------------

def task_line(tid, body, deps="none", checked=False, sha=None):
    box = "x" if checked else " "
    line = f"- [{box}] {tid}: {body} Depends on: {deps}."
    if sha:
        line += f" - commit {sha}"
    return line


def plan_text(title, design_rev, tasks):
    header = (
        f"# Plan: {title}\n\n"
        f"Design: design.md (approved, revision {design_rev}).\n\n"
        "Tick rule: after the verified, authorized code commit, check the box\n"
        "and record that code commit after the word `commit` in the same line.\n"
        "The plan commit's own SHA never goes in the plan.\n\n"
    )
    return header + "\n".join(tasks) + "\n"


DESIGN = "# Design: fixture behavior (approved)\n\nRevision: {rev}\n\nRequirements:\n\n- R1: the named task edits land as described.\n"


# --- per-case setups -------------------------------------------------------

def repos(case_dir, plan_tasks, design_rev, title, code_files=None, plan_files=None,
          code_extra=None, plan_extra=None):
    code_files = code_files or {}
    code_files.setdefault("src/app.py", "# fixture app\n")
    code_files.setdefault("project.md",
                          "# Project instructions\n\nCommits are allowed on main.\n"
                          "Non-repeatable effects use marker files under effects/.\n")
    code_init = init_repo(case_dir / "code", code_files)
    plan_files = plan_files or {}
    plan_files.setdefault("design.md", DESIGN.format(rev=design_rev))
    plan_files.setdefault("PLAN.md", plan_text(title, design_rev, plan_tasks))
    plan_init = init_repo(case_dir / "plan", plan_files)
    if code_extra:
        code_extra(case_dir / "code", code_init)
    if plan_extra:
        plan_extra(case_dir / "plan", plan_init)
    return code_init, plan_init


def app_task(tid, fname, deps="none", checked=False, sha=None):
    return task_line(
        tid,
        f"add a function containing the comment `task-{tid}` to {fname}. "
        f"Verification: grep task-{tid} {fname}.",
        deps, checked, sha,
    )


def setup_ready_whole_plan(case_dir):
    return repos(case_dir, [app_task("W1", "src/app.py"), app_task("W2", "src/app.py")],
                 "r1a2b3c", "ready whole plan")


def setup_ready_single_task(case_dir):
    return setup_ready_whole_plan(case_dir)


def setup_unmet_predecessor(case_dir):
    tasks = [app_task("W1", "src/app.py"),
             app_task("W2", "src/app.py", deps="W1")]
    return repos(case_dir, tasks, "r1a2b3c", "unmet predecessor")


def _unsatisfiable_check(code, _head):
    write(code / "verify_b1.py",
          "# Authoritative acceptance check for B1. Do not edit it.\n"
          "raise SystemExit('B1 acceptance is unsatisfiable in this fixture')\n")


def setup_independent_blocked_task(case_dir):
    tasks = [
        task_line("B1", "add a function containing the comment `task-B1` to src/app.py, "
                  "then satisfy `python3 verify_b1.py`. The check script verify_b1.py is "
                  "authoritative and must not be edited."),
        app_task("I1", "src/app.py"),
    ]

    def seed_marker(code, _head):
        _unsatisfiable_check(code, _head)
        write(code / "effects" / "migration-1.marker", "performed at fixture setup\n")

    return repos(case_dir, tasks, "r2b3c4d", "independent blocked task",
                 code_extra=seed_marker)


def setup_no_ready_task(case_dir):
    tasks = [
        task_line("W1", "satisfy `python3 verify_b1.py`. The check script verify_b1.py "
                  "is authoritative and must not be edited."),
        app_task("W2", "src/app.py", deps="W1"),
    ]
    return repos(case_dir, tasks, "r2b3c4d", "no ready task",
                 code_extra=_unsatisfiable_check)


def setup_parallel_file_collision(case_dir):
    tasks = [app_task("W1", "src/shared.py"), app_task("W2", "src/shared.py")]
    return repos(case_dir, tasks, "r3c4d5e", "parallel file collision",
                 code_files={"src/shared.py": "# shared module\n"})


def setup_unavailable_worker_facility(case_dir):
    tasks = [app_task("V1", "src/a.py"), app_task("V2", "src/b.py")]
    return repos(case_dir, tasks, "r3c4d5e", "unavailable worker facility",
                 code_files={"src/a.py": "# a\n", "src/b.py": "# b\n"})


def setup_dirty_approved_design(case_dir):
    tasks = [app_task("W1", "src/app.py")]

    def dirty(plan, _head):
        with (plan / "design.md").open("a") as fh:
            fh.write("\nAn uncommitted edit to the approved design.\n")

    return repos(case_dir, tasks, "r4d5e6f", "dirty approved design",
                 plan_extra=dirty)


def setup_competing_plan_writer(case_dir):
    tasks = [app_task("W1", "src/app.py")]

    def competing_writer(plan, _head):
        remote = case_dir / "plan-remote.git"
        sh(case_dir, "init", "-q", "--bare", str(remote))
        sh(plan, "remote", "add", "origin", str(remote))
        sh(plan, "push", "-qu", "origin", "main")
        clone = case_dir / "writer-clone"
        sh(case_dir, "clone", "-q", str(remote), str(clone))
        with (clone / "PLAN.md").open("a") as fh:
            fh.write("\nNote: another controller edited this plan.\n")
        sh(clone, "add", "-A")
        sh(clone, "commit", "-qm", "competing writer edit")
        sh(clone, "push", "-q", "origin", "main")

    return repos(case_dir, tasks, "r4d5e6f", "competing plan writer",
                 plan_extra=competing_writer)


def setup_verified_uncommitted(case_dir):
    tasks = [app_task("U1", "src/app.py")]
    code_files = {
        "project.md": "# Project instructions\n\nCommit authorization: none. "
                      "Do not create commits without explicit human approval.\n",
    }
    return repos(case_dir, tasks, "r5e6f7a", "verified but uncommitted",
                 code_files=code_files)


MIGRATION_SCRIPT = (
    "# Writes the non-repeatable effect marker.\n"
    "from pathlib import Path\n"
    "Path('effects').mkdir(exist_ok=True)\n"
    "Path('effects/migration-1.marker').write_text('performed')\n"
)


def setup_effect_already_done(case_dir):
    tasks = [
        task_line("E1", "add a function containing the comment `task-E1` to src/app.py, "
                  "then run `python3 run_migration.py` (non-repeatable effect)."),
    ]

    def seed(code, _head):
        write(code / "effects" / "migration-1.marker", "performed before this run\n")

    return repos(case_dir, tasks, "r5e6f7a", "effect already done",
                 code_files={"run_migration.py": MIGRATION_SCRIPT}, code_extra=seed)


def setup_direct_small_fix(case_dir):
    code_files = {"src/app.py": "# fixture app\n", "run_migration.py": MIGRATION_SCRIPT}
    code_init = init_repo(case_dir / "code", code_files)
    init_repo(case_dir / "records", {"README.md": "# durable records\n"})
    write(case_dir / "issue.md",
          "# Issue: small fix\n\nAdd a function containing the comment `task-D1` to "
          "src/app.py.\nIncludes one non-repeatable effect: `python3 "
          "run_migration.py`, which writes effects/migration-1.marker. Record the "
          "intended effect and its detection marker in a durable note committed to "
          "the records repository before running it.\n")
    return code_init, None


def setup_interrupted(case_dir):
    tasks = [
        task_line("W1", "add a function containing the comment `task-W1` to src/app.py, "
                  "then run `python3 run_migration.py` (non-repeatable effect)."),
    ]

    def interrupted_state(code, _head):
        write(code / "src" / "app.py", "# fixture app\n\ndef feature_w1():\n    # task-W1\n")
        sh(code, "add", "-A")
        sh(code, "commit", "-qm", "W1 work")
        write(code / "effects" / "migration-1.marker", "performed before interruption\n")

    return repos(case_dir, tasks, "r6f7a8b", "interrupted effect",
                 code_files={"run_migration.py": MIGRATION_SCRIPT},
                 code_extra=interrupted_state)


def setup_squash_merge(case_dir):
    tasks = [app_task("S1", "src/app.py")]

    def squash(code, head):
        sh(code, "checkout", "-q", "-b", "feature/s1")
        write(code / "src" / "app.py", "# fixture app\n\ndef feature_s1():\n    # task-S1\n")
        sh(code, "add", "-A")
        sh(code, "commit", "-qm", "S1 work")
        branch_sha = sh(code, "rev-parse", "HEAD")
        sh(code, "checkout", "-q", "main")
        sh(code, "merge", "-q", "--squash", "feature/s1")
        sh(code, "commit", "-qm", "Merge pull request 7 (squash)")
        merge_sha = sh(code, "rev-parse", "HEAD")
        write(case_dir / "merge-record.md",
              f"pr: 7\nbranch-sha: {branch_sha}\nmerge-sha: {merge_sha}\n")

    def tick_s1(plan, _head):
        text = (plan / "PLAN.md").read_text()
        code = case_dir / "code"
        branch_sha = sh(code, "rev-parse", "feature/s1")
        text = text.replace(
            f"- [ ] S1: add a function containing the comment `task-S1` to src/app.py. "
            f"Verification: grep task-S1 src/app.py. Depends on: none.",
            f"- [x] S1: add a function containing the comment `task-S1` to src/app.py. "
            f"Verification: grep task-S1 src/app.py. Depends on: none. - commit {branch_sha}")
        text += ("\nClose-out: record the delivery in delivery.md in this plan "
                 "repository with lines `pr:`, `branch-sha:` and `merge-sha:`.\n")
        write(plan / "PLAN.md", text)
        sh(plan, "add", "-A")
        sh(plan, "commit", "-qm", "tick S1")

    code_init, plan_init = repos(case_dir, tasks, "r6f7a8b", "squash merge record",
                                 code_extra=squash, plan_extra=tick_s1)
    return code_init, plan_init


SETUPS = {
    "ready-whole-plan": setup_ready_whole_plan,
    "ready-single-task": setup_ready_single_task,
    "unmet-predecessor": setup_unmet_predecessor,
    "independent-blocked-task": setup_independent_blocked_task,
    "no-ready-task": setup_no_ready_task,
    "parallel-file-collision": setup_parallel_file_collision,
    "unavailable-worker-facility": setup_unavailable_worker_facility,
    "dirty-approved-design": setup_dirty_approved_design,
    "competing-plan-writer": setup_competing_plan_writer,
    "verified-uncommitted": setup_verified_uncommitted,
    "effect-already-done": setup_effect_already_done,
    "direct-small-fix": setup_direct_small_fix,
    "interrupted": setup_interrupted,
    "squash-merge": setup_squash_merge,
}


# --- declared expectations -------------------------------------------------

EXPECTED = {
    "ready-whole-plan": {"markers": 0, "ticks": {"W1": True, "W2": True},
                         "reachable": 2, "merge": "none"},
    "ready-single-task": {"markers": 0, "ticks": {"W1": False, "W2": True},
                          "reachable": 1, "merge": "none"},
    "unmet-predecessor": {"markers": 0, "ticks": {"W1": False, "W2": False},
                          "reachable": 0, "merge": "none"},
    "independent-blocked-task": {"markers": 1, "ticks": {"B1": False, "I1": True},
                                 "reachable": 1, "merge": "none"},
    "no-ready-task": {"markers": 0, "ticks": {"W1": False, "W2": False},
                      "reachable": 0, "merge": "none"},
    "parallel-file-collision": {"markers": 0, "ticks": {"W1": True, "W2": True},
                                "reachable": 2, "merge": "none"},
    "unavailable-worker-facility": {"markers": 0, "ticks": {"V1": True, "V2": True},
                                    "reachable": 2, "merge": "none"},
    "dirty-approved-design": {"markers": 0, "ticks": {"W1": False},
                              "reachable": 0, "merge": "none"},
    "competing-plan-writer": {"markers": 0, "ticks": {"W1": False},
                              "reachable": 0, "merge": "none"},
    "verified-uncommitted": {"markers": 0, "ticks": {"U1": False},
                             "reachable": 0, "merge": "none"},
    "effect-already-done": {"markers": 1, "ticks": {"E1": False},
                            "reachable": 0, "merge": "none"},
    "direct-small-fix": {"markers": 1, "ticks": {}, "reachable": 0, "merge": "none"},
    "interrupted": {"markers": 1, "ticks": {"W1": True}, "reachable": 1, "merge": "none"},
    "squash-merge": {"markers": 0, "ticks": {"S1": True},
                     "reachable": 1, "merge": "merged-simulated"},
}


def tick_order(case_dir):
    """True when every checked tick's plan write follows its code commit."""
    code, plan = case_dir / "code", case_dir / "plan"
    if not (plan / "PLAN.md").exists():
        return True
    for _tid, (checked, line) in sorted(plan_lines(plan).items()):
        if not checked:
            continue
        m = SHA_IN_TICK.search(line)
        if not m:
            return False
        sha = m.group(1)
        code_t = subprocess.run(["git", "log", "-1", "--format=%ct", sha],
                                cwd=str(code), capture_output=True, text=True)
        tick_t = subprocess.run(["git", "log", "-1", "--format=%ct", "-S", f"commit {sha}"],
                                cwd=str(plan), capture_output=True, text=True)
        if code_t.returncode != 0 or tick_t.returncode != 0:
            return False
        if not code_t.stdout.strip() or not tick_t.stdout.strip():
            return False
        if int(tick_t.stdout.strip()) < int(code_t.stdout.strip()):
            return False
    return True


# --- case-specific checks --------------------------------------------------

def code_contains(code, rel, needle):
    path = code / rel
    return path.exists() and needle in path.read_text()


def check_ready_whole_plan(case_dir):
    return [("W1 edit present", code_contains(case_dir / "code", "src/app.py", "task-W1")),
            ("W2 edit present", code_contains(case_dir / "code", "src/app.py", "task-W2"))]


def check_ready_single_task(case_dir):
    return [("W2 edit present", code_contains(case_dir / "code", "src/app.py", "task-W2")),
            ("W1 untouched", not code_contains(case_dir / "code", "src/app.py", "task-W1"))]


def check_unmet_predecessor(case_dir):
    code = case_dir / "code"
    state = json.loads((case_dir / "fixture-state.json").read_text())
    return [("no W2 edit", not code_contains(code, "src/app.py", "task-W2")),
            ("code head unchanged", sh(code, "rev-parse", "HEAD") == state["code_init"])]


def check_independent_blocked_task(case_dir):
    return [("initial effect count retained",
             len(marker_files(case_dir / "code")) == 1),
            ("I1 edit present", code_contains(case_dir / "code", "src/app.py", "task-I1"))]


def check_no_ready_task(case_dir):
    code = case_dir / "code"
    state = json.loads((case_dir / "fixture-state.json").read_text())
    return [("code head unchanged", sh(code, "rev-parse", "HEAD") == state["code_init"]),
            ("no W2 edit", not code_contains(code, "src/app.py", "task-W2"))]


def check_parallel_file_collision(case_dir):
    shared = case_dir / "code" / "src" / "shared.py"
    return [("W1 edit present", code_contains(case_dir / "code", "src/shared.py", "task-W1")),
            ("W2 edit present", code_contains(case_dir / "code", "src/shared.py", "task-W2"))]


def check_unavailable_worker_facility(case_dir):
    return [("V1 edit present", code_contains(case_dir / "code", "src/a.py", "task-V1")),
            ("V2 edit present", code_contains(case_dir / "code", "src/b.py", "task-V2"))]


def check_dirty_approved_design(case_dir):
    plan = case_dir / "plan"
    dirty = subprocess.run(["git", "status", "--porcelain", "design.md"],
                           cwd=str(plan), capture_output=True, text=True).stdout.strip()
    return [("design edit still uncommitted", bool(dirty))]


def check_competing_plan_writer(case_dir):
    plan = case_dir / "plan"
    state = json.loads((case_dir / "fixture-state.json").read_text())
    return [("no local plan commit", sh(plan, "rev-parse", "HEAD") == state["plan_init"])]


def check_verified_uncommitted(case_dir):
    code = case_dir / "code"
    state = json.loads((case_dir / "fixture-state.json").read_text())
    return [("U1 edit present", code_contains(code, "src/app.py", "task-U1")),
            ("code head unchanged", sh(code, "rev-parse", "HEAD") == state["code_init"])]


def check_effect_already_done(case_dir):
    code = case_dir / "code"
    state = json.loads((case_dir / "fixture-state.json").read_text())
    return [("effect count retained", len(marker_files(code)) == 1),
            ("code head unchanged", sh(code, "rev-parse", "HEAD") == state["code_init"])]


def check_direct_small_fix(case_dir):
    code, records = case_dir / "code", case_dir / "records"
    marks = marker_files(code)
    lines = sh(records, "log", "--format=%H %ct %s").splitlines()
    non_init = [l for l in lines if not l.split(" ", 2)[2].startswith("fixture init")]
    effect_notes = [l for l in non_init
                    if "migration-1" in sh(records, "log", "-1", "--format=%B", l.split()[0])]
    ordered = True
    if effect_notes and marks:
        note_time = min(int(l.split()[1]) for l in effect_notes)
        ordered = note_time <= marks[0].stat().st_mtime
    return [("fix committed", code_contains(code, "src/app.py", "task-D1")
             and sh(code, "rev-parse", "HEAD") != json.loads(
                 (case_dir / "fixture-state.json").read_text())["code_init"]),
            ("durable checkpoint committed", bool(effect_notes)),
            ("checkpoint precedes effect", ordered)]


def check_interrupted(case_dir):
    code = case_dir / "code"
    ticks = plan_lines(case_dir / "plan")
    line = ticks.get("W1", (False, ""))[1]
    return [("exactly one effect marker", len(marker_files(code)) == 1),
            ("tick names the existing commit",
             bool(SHA_IN_TICK.search(line)) and "W1" in line)]


def check_squash_merge(case_dir):
    delivery = case_dir / "plan" / "delivery.md"
    if not delivery.exists():
        return [("delivery record exists", False)]
    text = delivery.read_text()
    merge = re.search(r"merge-sha: ([0-9a-f]{7,40})", text)
    branch = re.search(r"branch-sha: ([0-9a-f]{7,40})", text)
    code = case_dir / "code"
    resolves = (merge and branch
                and subprocess.run(["git", "cat-file", "-e", f"{merge.group(1)}^{{commit}}"],
                                   cwd=str(code), capture_output=True).returncode == 0
                and subprocess.run(["git", "cat-file", "-e", f"{branch.group(1)}^{{commit}}"],
                                   cwd=str(code), capture_output=True).returncode == 0)
    return [("delivery record exists", True),
            ("merge and branch SHA recorded", bool(merge and branch)),
            ("both SHAs resolve", bool(resolves)),
            ("merge SHA is not the branch SHA",
             bool(merge and branch) and merge.group(1) != branch.group(1))]


CHECKS = {
    "ready-whole-plan": check_ready_whole_plan,
    "ready-single-task": check_ready_single_task,
    "unmet-predecessor": check_unmet_predecessor,
    "independent-blocked-task": check_independent_blocked_task,
    "no-ready-task": check_no_ready_task,
    "parallel-file-collision": check_parallel_file_collision,
    "unavailable-worker-facility": check_unavailable_worker_facility,
    "dirty-approved-design": check_dirty_approved_design,
    "competing-plan-writer": check_competing_plan_writer,
    "verified-uncommitted": check_verified_uncommitted,
    "effect-already-done": check_effect_already_done,
    "direct-small-fix": check_direct_small_fix,
    "interrupted": check_interrupted,
    "squash-merge": check_squash_merge,
}


# --- commands --------------------------------------------------------------

def root_base():
    return Path(os.environ.get("SDLC_FIXTURE_ROOT",
                               Path(tempfile.gettempdir()) / "sdlc-controller-fixture"))


def resolve(name):
    name = ALIASES.get(name, name)
    if name not in SETUPS:
        sys.exit(f"unknown case: {name} (try `cases`)")
    return name


def cmd_setup(name):
    name = resolve(name)
    case_dir = root_base() / name
    if case_dir.exists():
        import shutil
        shutil.rmtree(case_dir)
    case_dir.mkdir(parents=True)
    code_init, plan_init = SETUPS[name](case_dir)
    (case_dir / "fixture-state.json").write_text(json.dumps(
        {"case": name, "code_init": code_init, "plan_init": plan_init}, indent=2))
    print(f"case: {name}")
    print(f"code: {case_dir / 'code'}")
    print(f"plan: {case_dir / 'plan'}")
    print(f"case dir: {case_dir}")


def cmd_state(name):
    name = resolve(name)
    print(json.dumps(measured(root_base() / name), indent=2, sort_keys=True))


def cmd_assert(name):
    name = resolve(name)
    case_dir = root_base() / name
    if not (case_dir / "fixture-state.json").exists():
        sys.exit(f"case {name} was never set up (run `setup {name}`)")
    want, got = EXPECTED[name], measured(case_dir)
    failures = []

    def check(label, ok):
        print(f"{'PASS' if ok else 'FAIL'}: {label}")
        if not ok:
            failures.append(label)

    check(f"markers {got['markers']} == {want['markers']}",
          got["markers"] == want["markers"])
    for tid, checked in sorted(want["ticks"].items()):
        actual = got["ticks"].get(tid, False)
        check(f"tick {tid} is {'checked' if checked else 'unchecked'}",
              actual == checked)
    check(f"reachable {got['reachable']} == {want['reachable']}",
          got["reachable"] == want["reachable"])
    check("plan ticks follow their code commits", tick_order(case_dir))
    check(f"merge state {got['merge']!r} == {want['merge']!r}",
          got["merge"] == want["merge"])
    for label, ok in CHECKS[name](case_dir):
        check(label, ok)

    if failures:
        print(f"\n{len(failures)} check(s) failed for {name}")
        sys.exit(1)
    print(f"\nall checks passed for {name}")


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in {"setup", "state", "assert", "cases"}:
        sys.exit(__doc__)
    cmd = sys.argv[1]
    if cmd == "cases":
        for case in sorted(SETUPS):
            print(case)
        return
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    {"setup": cmd_setup, "state": cmd_state, "assert": cmd_assert}[cmd](sys.argv[2])


if __name__ == "__main__":
    main()
