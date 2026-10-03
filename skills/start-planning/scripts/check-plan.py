#!/usr/bin/env python3
"""Advisory plan checker.

Usage:
    python3 skills/start-planning/scripts/check-plan.py <plan.md>
    python3 skills/start-planning/scripts/check-plan.py --help

Reports mechanical omissions in a plan: missing frontmatter, a broken local
design link, duplicate task IDs, unresolved dependency IDs, a task without
verification evidence, and absent design coverage. It advises, it never
blocks: a report exits 0, and usage or file-read errors exit 2. A
presentation the checker cannot parse is reported as `unable to check` for
that field, never as missing. Verification evidence is a keyword heuristic
(verif, proof, prove, test, check, assert, command) over the task's text,
so a task phrased in other words may read as unverified. The checker
introduces no required Markdown
syntax.
"""

import re
import sys
from pathlib import Path

ID = r"(?:[Tt]ask[ \-]?\d{1,3}|[A-Z][A-Za-z]{0,4}-?\d{1,3})"
ID_TOKEN = re.compile(rf"\b{ID}\b")
TASK_HEAD = re.compile(
    rf"^\s*#{{1,4}}\s+(?:\*\*)?(?P<id>{ID})(?:\*\*)?\s*[:—–-]\s*(?P<body>.*)$"
)
TASK_BULLET = re.compile(
    rf"^\s*[-*]\s*(?:\[[ xX]\]\s*)?(?P<id>{ID})\s*[:—–-]\s+(?P<body>.*)$"
)
TASK_TABLE = re.compile(rf"^\|\s*(?P<id>{ID})\s*\|(?P<body>.*)$")
TASK_BARE = re.compile(rf"^(?P<id>{ID})\s*[:—–-]\s+(?P<body>.*)$")
DEP_PHRASE = re.compile(r"(?:depends\s+on|dependencies|dep)\s*[: ]\s*(?P<deps>[^.;|]*)", re.I)
VERIFICATION = re.compile(r"verif|proof|prove|test|check|assert|command", re.I)
LINK = re.compile(r"\[[^\]]*\]\((?P<target>[^)\s]+)\)")

USAGE = __doc__


def norm(token):
    return re.sub(r"[ \-]", "", token).upper()


def has_frontmatter(text):
    return text.startswith("---\n") and "\n---" in text[4:]


def strip_frontmatter(text):
    if text.startswith("---\n"):
        end = text.find("\n---", 4)
        if end != -1:
            return text[end + 4:]
    return text


def local_targets(line):
    for m in LINK.finditer(line):
        target = m.group("target")
        if re.match(r"^[a-z]+:", target) or target.startswith("#"):
            continue
        yield target.split("#", 1)[0]


def parse_tasks(lines, requirement_ids):
    blocks = {}
    display = {}
    order = []
    inline_seen = set()
    duplicates = []
    current = None
    mode = None

    for line in lines:
        head = TASK_HEAD.match(line)
        inline = TASK_BULLET.match(line) or TASK_TABLE.match(line) or TASK_BARE.match(line)
        if head:
            tid = head.group("id")
            nid = norm(tid)
            if nid in requirement_ids:
                continue
            if nid not in blocks:
                blocks[nid] = []
                display[nid] = tid
                order.append(nid)
            blocks[nid].append(head.group("body"))
            current, mode = nid, "section"
        elif inline:
            tid = inline.group("id")
            nid = norm(tid)
            if nid in requirement_ids:
                continue
            if nid in inline_seen:
                duplicates.append(tid)
            inline_seen.add(nid)
            if nid not in blocks:
                blocks[nid] = []
                display[nid] = tid
                order.append(nid)
            blocks[nid].append(inline.group("body"))
            current, mode = nid, "inline"
        elif current is not None:
            if not line.strip():
                if mode == "inline":
                    current = None
                continue
            if mode == "section":
                if re.match(r"^#{1,4}\s", line):
                    current = None
                else:
                    blocks[current].append(line.strip())
            elif re.match(r"^\s{2,}\S", line):
                blocks[current].append(line.strip())
            else:
                current = None

    return order, blocks, display, duplicates


def design_requirement_ids(text):
    ids = set()
    for line in strip_frontmatter(text).splitlines():
        if re.match(r"^\s*\|", line):
            cells = line.split("|")
            segment = cells[1] if len(cells) > 2 else line
        elif re.match(r"^\s*(?:[-*]|\d+\.)\s", line) or line.strip().startswith("**"):
            stripped = re.sub(r"^\s*(?:[-*]|\d+\.)\s*", "", line).lstrip("*").strip()
            segment = re.split(r"[:—–]", stripped, maxsplit=1)[0]
        else:
            continue
        ids.update(norm(t) for t in ID_TOKEN.findall(segment))
    return ids


MAPPING_ARROW = re.compile(r"->|→|=>")


def covered_requirement_ids(text, requirement_ids):
    covered = set()
    for line in strip_frontmatter(text).splitlines():
        cells = line.split("|")
        is_table_mapping = (
            line.lstrip().startswith("|") and len(cells) > 2
            and any(norm(t) in requirement_ids for t in ID_TOKEN.findall(cells[1]))
        )
        if is_table_mapping or MAPPING_ARROW.search(line):
            covered.update(norm(t) for t in ID_TOKEN.findall(line))
    return covered & requirement_ids


def check(path):
    findings = []
    try:
        text = path.read_text()
    except OSError as exc:
        raise SystemExit(f"{path}: cannot read: {exc}") from exc

    if not has_frontmatter(text):
        findings.append("missing frontmatter")

    design_text = None
    for line in text.splitlines():
        if "design" not in line.lower():
            continue
        for target in local_targets(line):
            candidate = path.parent / target
            if candidate.is_file():
                design_text = candidate.read_text()
            else:
                findings.append(f"broken design link: {target}")
        if design_text is not None:
            break

    requirement_ids = design_requirement_ids(design_text) if design_text is not None else set()
    order, blocks, display, duplicates = parse_tasks(
        strip_frontmatter(text).splitlines(), requirement_ids)
    for tid in duplicates:
        findings.append(f"duplicate task ID {tid}")

    known = set(blocks)
    if not order:
        findings.append("unable to check: task list not recognized")
    else:
        for nid in order:
            block = " ".join(blocks[nid])
            m = DEP_PHRASE.search(block)
            if m:
                for dep in ID_TOKEN.findall(m.group("deps")):
                    if norm(dep) not in known and norm(dep) not in requirement_ids:
                        findings.append(
                            f"task {display[nid]}: unresolved dependency {dep}")
            if not VERIFICATION.search(block):
                findings.append(f"task {display[nid]}: no verification evidence")

    if design_text is None:
        findings.append("unable to check: design coverage (no readable design link)")
    elif not order:
        findings.append("unable to check: design coverage (task presentation unparseable)")
    elif not requirement_ids:
        findings.append("unable to check: design requirements not recognized")
    else:
        covered = covered_requirement_ids(text, requirement_ids)
        if not covered:
            findings.append("absent design coverage: no design requirement is mapped")
        else:
            for rid in sorted(requirement_ids - covered):
                findings.append(f"absent design coverage: requirement {rid} not mapped")

    return findings


def main(argv):
    if len(argv) == 1 and argv[0] in {"-h", "--help", "help"}:
        print(USAGE)
        return 0
    if len(argv) != 1:
        print(USAGE, file=sys.stderr)
        return 2
    path = Path(argv[0])
    if not path.is_file():
        print(f"{path}: cannot read: no such file", file=sys.stderr)
        return 2
    findings = check(path)
    for finding in findings:
        print(f"{path}: {finding}")
    count = len(findings)
    print(f"{path}: {count} finding{'s' if count != 1 else ''}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except SystemExit:
        raise
    except OSError as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(2)
