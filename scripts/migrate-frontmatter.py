#!/usr/bin/env python3
"""Preview or apply lifecycle date/type normalization without rewriting prose."""

import argparse
from dataclasses import dataclass
from datetime import date, datetime
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile


DIRECTORIES = (
    "0-brainstorms", "1-discovery", "1-research", "2-design", "2-requirements",
    "3-design", "3-plans", "4-plans", "4-reviews", "5-reviews", "6-retros", "adrs",
)
KEYS = {"date", "created", "updated", "type"}


class MigrationError(Exception):
    pass


def git(root, *arguments):
    result = subprocess.run(
        ["git", "-C", str(root), *arguments], text=True, capture_output=True,
    )
    if result.returncode:
        raise MigrationError(result.stderr.strip() or "Git command failed")
    return result.stdout.strip()


@dataclass
class Scalar:
    index: int
    key: str
    prefix: str
    value: str
    quote: str
    suffix: str
    newline: str

    def render(self, key=None, value=None):
        prefix = self.prefix if key is None else self.prefix.replace(self.key + ":", key + ":", 1)
        value = self.value if value is None else value
        return prefix + self.quote + value + self.quote + self.suffix + self.newline


def frontmatter(raw):
    try:
        lines = raw.decode("utf-8").splitlines(keepends=True)
    except UnicodeDecodeError as error:
        raise MigrationError("document is not UTF-8") from error
    if not lines or lines[0].rstrip("\r\n") != "---":
        raise MigrationError("frontmatter must start at byte zero")
    end = next((i for i in range(1, len(lines)) if lines[i].rstrip("\r\n") == "---"), None)
    if end is None:
        raise MigrationError("frontmatter has no closing fence")
    fields = {}
    for index in range(1, end):
        key = re.match(r"^[\"']?([A-Za-z_][\w-]*)[\"']?[ \t]*:", lines[index])
        if not key or key[1] not in KEYS:
            continue
        name = key[1]
        if not lines[index].startswith(name + ":"):
            raise MigrationError(f"unsupported {name} key syntax")
        if name in fields:
            raise MigrationError(f"duplicate {name} field")
        scalar = re.fullmatch(
            rf"({name}:[ \t]*)(?:\"([^\"\r\n]*)\"|'([^'\r\n]*)'|([^#\r\n]*?))"
            r"((?:[ \t]+#[^\r\n]*)?[ \t]*)(\r?\n)?", lines[index],
        )
        if not scalar:
            raise MigrationError(f"{name} needs a single-line scalar")
        quote = '"' if scalar[2] is not None else "'" if scalar[3] is not None else ""
        value = next(value for value in scalar.group(2, 3, 4) if value is not None)
        if not quote:
            value = value.strip()
        fields[name] = Scalar(index, name, scalar[1], value, quote, scalar[5], scalar[6] or "")
    return lines, fields


def calendar(value, field):
    try:
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
            raise ValueError
        return date.fromisoformat(value)
    except ValueError as error:
        raise MigrationError(f"{field} must be a valid YYYY-MM-DD date") from error


def documents(root):
    paths = {p for directory in DIRECTORIES for p in (root / directory).glob("*.md")}
    paths.update(root.glob("6-retros/lessons/*/*.md"))
    for path in sorted(paths):
        parts = path.relative_to(root).parts
        linked = any(root.joinpath(*parts[:index]).is_symlink() for index in range(1, len(parts) + 1))
        if linked or not path.resolve().is_relative_to(root):
            raise MigrationError(f"refusing linked document: {path.relative_to(root)}")
        yield path


def migrate_document(path, root, repository, revision, historical_paths, ignored):
    before = path.read_bytes()
    lines, fields = frontmatter(before)
    kind = fields.get("type")
    if not kind or not re.fullmatch(r"[a-z][a-z0-9-]*", kind.value):
        raise MigrationError("type needs a literal single-line name")
    legacy, created, updated = (fields.get(key) for key in ("date", "created", "updated"))
    if not legacy and not created:
        raise MigrationError("missing created or legacy date")
    original = created or legacy
    created_date = calendar(original.value, "created")
    if legacy and calendar(legacy.value, "date") != created_date:
        raise MigrationError("created conflicts with legacy date")
    if updated:
        updated_date = calendar(updated.value, "updated")
        updated_source = "existing"
    else:
        relative = path.relative_to(root).as_posix()
        historical_path = (root.relative_to(repository) / historical_paths.get(relative, relative)).as_posix()
        limit = [] if ignored else ["-1"]
        history = git(repository, "log", "--follow", *limit, "--format=%H%x09%aI", revision, "--", historical_path)
        prior = next((line.split("\t", 1) for line in history.splitlines() if line.split("\t", 1)[0] not in ignored), None)
        if not prior:
            raise MigrationError("no recorded Git update date; supply a known updated value")
        updated_source, timestamp = prior
        updated_date = datetime.fromisoformat(timestamp).date()
    if updated_date < created_date:
        raise MigrationError("updated precedes created")

    replacements = {}
    if legacy:
        if created:
            replacements[legacy.index] = legacy.suffix.lstrip() + legacy.newline if legacy.suffix.lstrip().startswith("#") else ""
        else:
            replacements[legacy.index] = legacy.render(key="created")
    if not updated:
        index = original.index
        newline = original.newline or "\n"
        replacements[index] = replacements.get(index, lines[index]) + f'updated: "{updated_date}"{newline}'
    if kind.value == "discovery":
        replacements[kind.index] = kind.render(value="research")
    after = "".join(replacements.get(index, line) for index, line in enumerate(lines)).encode("utf-8")
    return {
        "path": path, "before": before, "after": after,
        "created": created_date.isoformat(), "updated": updated_date.isoformat(),
        "updated_source": updated_source,
        "normalized_type": bool(kind and kind.value == "discovery"),
        "mode": stat.S_IMODE(path.stat().st_mode),
    }


def replace_file(path, content, mode):
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".frontmatter-", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(content)
        temporary.chmod(mode)
        os.replace(temporary, path)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True, help="Explicit working-memory root")
    parser.add_argument("--apply", action="store_true", help="Apply the previewed field changes")
    parser.add_argument("--source-revision", default="HEAD", help="Git revision before mechanical migration edits")
    parser.add_argument("--path-map", type=Path, help="JSON old-to-current paths relative to the working-memory root")
    parser.add_argument("--ignore-revision", action="append", default=[], help="Mechanical commit to omit from date lookup; repeatable")
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        if not root.is_dir():
            raise MigrationError("working-memory root is not a directory")
        repository = Path(git(root, "rev-parse", "--show-toplevel")).resolve()
        revision = git(repository, "rev-parse", "--verify", "--end-of-options", args.source_revision + "^{commit}")
        ignored = {git(repository, "rev-parse", "--verify", "--end-of-options", value + "^{commit}") for value in args.ignore_revision}
        historical_paths = {}
        if args.path_map:
            mapping = json.loads(args.path_map.read_text())
            if not isinstance(mapping, dict):
                raise MigrationError("path map must be an old-to-current JSON object")
            for old, current in mapping.items():
                if any(
                    not isinstance(value, str) or not value or Path(value).is_absolute()
                    or ".." in Path(value).parts or not Path(value).parts
                    for value in (old, current)
                ):
                    raise MigrationError("path-map entries must stay relative to the working-memory root")
                if current in historical_paths:
                    raise MigrationError(f"ambiguous historical path for {current}")
                historical_paths[current] = old
        changes = []
        errors = []
        for path in documents(root):
            try:
                change = migrate_document(path, root, repository, revision, historical_paths, ignored)
                if change["before"] != change["after"]:
                    changes.append(change)
            except (MigrationError, OSError) as error:
                errors.append({"path": path.relative_to(root).as_posix(), "error": str(error)})
        if errors:
            print(json.dumps({"applied": False, "errors": errors}, indent=2))
            return 1
        if args.apply and changes:
            relative_root = root.relative_to(repository).as_posix()
            if git(repository, "status", "--porcelain", "--", relative_root):
                raise MigrationError("commit or reconcile working-memory edits before applying")
            if any(change["path"].read_bytes() != change["before"] for change in changes):
                raise MigrationError("document changed during preview")
            written = []
            try:
                for change in changes:
                    if change["path"].is_symlink() or change["path"].read_bytes() != change["before"]:
                        raise MigrationError("document changed during application")
                    replace_file(change["path"], change["after"], change["mode"])
                    written.append(change)
            except (OSError, MigrationError):
                for change in reversed(written):
                    if change["path"].read_bytes() == change["after"]:
                        replace_file(change["path"], change["before"], change["mode"])
                raise
        print(json.dumps({
            "root": str(root), "source_revision": revision, "applied": args.apply,
            "ignored_revisions": sorted(ignored),
            "changed_count": len(changes),
            "changes": [{
                "path": change["path"].relative_to(root).as_posix(),
                "created": change["created"], "updated": change["updated"],
                "updated_source": change["updated_source"],
                "normalized_type": change["normalized_type"],
            } for change in changes],
        }, indent=2))
        return 0
    except (MigrationError, OSError, ValueError) as error:
        print(f"Frontmatter migration: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
