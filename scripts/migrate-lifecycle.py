#!/usr/bin/env python3
"""Rehearse or apply explicit lifecycle mappings, serially, without model calls."""

import argparse
import json
import posixpath
import re
from pathlib import Path
import subprocess
import tempfile

from check_relative_links import extract_links_from_content

FRONTMATTER = Path(__file__).with_name("migrate-frontmatter.py")
LIFECYCLE_FOLDERS = ("0-brainstorms", "1-research", "2-requirements", "3-design",
                     "4-plans", "5-reviews", "6-retros")


def command(repo, *args, input=None):
    result = subprocess.run(["git", "-C", str(repo), *args], input=input, capture_output=True)
    if result.returncode:
        raise ValueError(result.stderr.decode(errors="replace").strip())
    return result.stdout


def path_at(repo, value):
    if not isinstance(value, str) or not value or Path(value).is_absolute():
        raise ValueError("paths must be nonempty and repository-relative")
    parts = Path(value).parts
    if ".." in parts or ".git" in parts:
        raise ValueError("path escapes repository or names Git internals")
    for index in range(1, len(parts) + 1):
        parent = repo.joinpath(*parts[:index])
        if parent.is_symlink():
            raise ValueError("linked paths are unsupported: " + value)
        if parent != repo and (parent / ".git").exists():
            raise ValueError("path crosses a nested repository: " + value)
    return repo / value


def broken_links(repo, tracked, reverse=None):
    reverse = reverse or {}
    failures = set()
    directories = {str(Path(name).parent) for name in tracked}
    for name in tracked:
        directories.update(str(parent) for parent in Path(name).parents)
        if not name.endswith(".md") or (repo / name).is_symlink():
            continue
        content = (repo / name).read_text(errors="replace")
        for _, raw, clean in extract_links_from_content(content, name):
            target = posixpath.normpath(clean.lstrip("/") if clean.startswith("/") else str(Path(name).parent / clean))
            if target not in tracked and target not in directories:
                failures.add((reverse.get(name, name), raw))
    return failures


def build(repo, entry, temporary):
    revision = command(repo, "rev-parse", "--verify", "--end-of-options", entry["revision"] + "^{commit}").decode().strip()
    clone = temporary / "candidate"
    result = subprocess.run([
        "git", "clone", "--quiet", "--no-hardlinks", "--no-checkout",
        "--config", "core.hooksPath=/dev/null", "--config", "core.autocrlf=false",
        "--", str(repo), str(clone),
    ], capture_output=True)
    if result.returncode:
        raise ValueError(result.stderr.decode(errors="replace"))
    command(clone, "checkout", "--quiet", "--detach", revision)
    tracked = set(command(clone, "ls-files", "-z").decode().split("\0")) - {""}
    before_links = broken_links(clone, tracked)
    memory = entry.get("memory")
    if memory is not None:
        selected = path_at(clone, memory)
        if not selected.is_dir():
            raise ValueError("working-memory root is absent")
        args = ["python3", str(FRONTMATTER), "--root", str(selected), "--source-revision", revision, "--apply"]
        for ignored in entry.get("ignore_revisions", []):
            args.extend(["--ignore-revision", ignored])
        result = subprocess.run(args, capture_output=True, text=True)
        if result.returncode:
            raise ValueError(result.stderr or result.stdout)
        metadata = json.loads(result.stdout)
    else:
        metadata = {"changed_count": 0}
    for edit in entry.get("edits", []):
        if edit["path"] not in tracked:
            raise ValueError("edit is not a tracked file")
        path = path_at(clone, edit["path"])
        old, new, count = edit["old"], edit["new"], edit["count"]
        if not isinstance(old, str) or not old or not isinstance(new, str) or type(count) is not int or count < 1:
            raise ValueError("edits need nonempty old text, new text and a positive exact count")
        raw = path.read_bytes()
        if raw.count(old.encode()) != count:
            raise ValueError("replacement count differs: " + edit["path"])
        replacement = raw.replace(old.encode(), new.encode())
        if raw.startswith((b"---\n", b"---\r\n")):
            before = raw.replace(b"\r\n", b"\n").split(b"\n---\n", 1)
            after = replacement.replace(b"\r\n", b"\n").split(b"\n---\n", 1)
            if len(before) != 2 or len(after) != 2:
                raise ValueError("cannot alter frontmatter fences")
            relationship = rb"(?m)^(?:related|supersedes|superseded_by|supersedes_brainstorm):[^\n]*\n(?:[ \t]+[^\n]*\n)*"
            if re.sub(relationship, b"", before[0] + b"\n") != re.sub(relationship, b"", after[0] + b"\n"):
                raise ValueError("edits must preserve frontmatter except relationship references")
        path.write_bytes(replacement)
    moves = entry.get("moves", {})
    if not isinstance(moves, dict) or len(set(moves.values())) != len(moves):
        raise ValueError("moves must map distinct files to distinct destinations")
    pending = []
    for source, target in moves.items():
        if source not in tracked:
            raise ValueError("move source is not a tracked file: " + source)
        src, dst = path_at(clone, source), path_at(clone, target)
        if not src.is_file() or source == target:
            raise ValueError("moves require different regular-file paths")
        if dst.exists() and target not in moves:
            raise ValueError("destination exists: " + target)
        pending.append((src, dst, src.read_bytes(), src.stat().st_mode))
    for src, _, _, _ in pending:
        src.unlink()
    for _, dst, raw, mode in pending:
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_bytes(raw)
        dst.chmod(mode)
    if memory is not None:
        for folder in LIFECYCLE_FOLDERS:
            directory = path_at(clone, str(Path(memory) / folder))
            directory.mkdir(parents=True, exist_ok=True)
            if not any(directory.iterdir()):
                (directory / ".gitkeep").touch()
    command(clone, "add", "-A")
    if memory is not None:
        for folder in LIFECYCLE_FOLDERS:
            if not command(clone, "ls-files", "--", str(Path(memory) / folder)).strip():
                raise ValueError("lifecycle folder is ignored or has no tracked content: " + folder)
    final_files = set(command(clone, "ls-files", "-z").decode().split("\0")) - {""}
    new_failures = broken_links(clone, final_files, {target: source for source, target in moves.items()}) - before_links
    if new_failures:
        raise ValueError("new broken Markdown references: " + repr(sorted(new_failures)))
    tree = command(clone, "write-tree").decode().strip()
    patch = command(clone, "diff", "--cached", "--binary", "--full-index", revision)
    changed = command(clone, "diff", "--cached", "--name-status", "--find-renames", revision).decode()
    additions = command(clone, "diff", "--cached", "--diff-filter=A", "--name-only", "-z", revision).decode().split("\0")
    return revision, tree, patch, changed, metadata["changed_count"], [name for name in additions if name]


def migrate(entry, manifest_parent, apply):
    allowed = {"repo", "revision", "memory", "moves", "edits", "ignore_revisions"}
    if not isinstance(entry, dict) or set(entry) - allowed:
        raise ValueError("unsupported project fields")
    if not isinstance(entry.get("revision"), str) or not re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", entry["revision"]):
        raise ValueError("revision must name a fixed Git commit")
    for edit in entry.get("edits", []):
        if set(edit) != {"path", "old", "new", "count"}:
            raise ValueError("edits require exactly path, old, new and count")
    repo_path = Path(entry["repo"])
    repo = (manifest_parent / repo_path).resolve() if not repo_path.is_absolute() else repo_path.resolve()
    if command(repo, "rev-parse", "--show-toplevel").decode().strip() != str(repo):
        raise ValueError("repo must name the repository root")
    with tempfile.TemporaryDirectory(prefix="lifecycle-migration-") as directory:
        revision, tree, patch, changed, count, additions = build(repo, entry, Path(directory))
        result = {"repo": str(repo), "source_revision": revision, "target_tree": tree,
                  "metadata_changes": count, "changes": changed, "patch": patch.decode()}
        head = command(repo, "rev-parse", "HEAD").decode().strip()
        head_tree = command(repo, "rev-parse", "HEAD^{tree}").decode().strip()
        status = command(repo, "status", "--porcelain")
        if head_tree == tree and not status:
            return dict(result, state="already-applied")
        if head == revision and command(repo, "write-tree").decode().strip() == tree and not command(repo, "diff", "--name-only"):
            if not command(repo, "ls-files", "--others", "--exclude-standard"):
                return dict(result, state="already-applied")
        if head != revision or status:
            raise ValueError("source revision changed or repository has uncommitted files")
        # Check live path collisions, including ignored files and linked parents.
        for name in list(entry.get("moves", {})) + [edit["path"] for edit in entry.get("edits", [])]:
            path_at(repo, name)
        for target in set(entry.get("moves", {}).values()) | set(additions):
            dst = path_at(repo, target)
            if dst.exists() and target not in entry.get("moves", {}):
                raise ValueError("live destination exists, possibly ignored: " + target)
        if not apply:
            return dict(result, state="previewed")
        if not patch:
            return dict(result, state="already-applied")
        command(repo, "apply", "--check", "--index", "--binary", "-", input=patch)
        if command(repo, "rev-parse", "HEAD").decode().strip() != revision or command(repo, "status", "--porcelain"):
            raise ValueError("repository changed after preview")
        command(repo, "apply", "--index", "--binary", "-", input=patch)
        if command(repo, "write-tree").decode().strip() != tree or command(repo, "diff", "--name-only"):
            raise ValueError("applied tree differs; preserve state and reconcile before retry")
        return dict(result, state="applied")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--apply", action="store_true", help="Apply and stage the rehearsed changes; no commits or installation")
    args = parser.parse_args()
    try:
        data = json.loads(args.manifest.read_text())
        if not isinstance(data, dict) or set(data) != {"projects"}:
            raise ValueError("manifest requires exactly a projects list")
        entries = data["projects"]
        if not isinstance(entries, list) or not entries:
            raise ValueError("projects must be a nonempty explicit list")
        results = []
        seen = set()
        for entry in entries:
            try:
                repo = (args.manifest.resolve().parent / entry["repo"]).resolve()
                if repo in seen:
                    raise ValueError("duplicate repository in batch")
                seen.add(repo)
                results.append(migrate(entry, args.manifest.resolve().parent, args.apply))
            except (OSError, ValueError, KeyError, TypeError) as error:
                results.append({"repo": entry.get("repo") if isinstance(entry, dict) else None,
                                "state": "blocked", "reason": str(error)})
        print(json.dumps({"projects": results}, indent=2))
        return int(any(item["state"] == "blocked" for item in results))
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(2, str(error) + "\n")


if __name__ == "__main__":
    raise SystemExit(main())
