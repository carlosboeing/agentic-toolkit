#!/usr/bin/env python3
"""Audit, apply and verify explicit repository hook rollouts without committing files."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

SOURCE = Path(__file__).resolve().parent.parent
BUNDLE = {name: f"git-hooks/drift-guard/{name}" for name in ("housekeep", "pre-push", "post-merge")}
PRIVACY = "git-hooks/private-workbench-guard/pre-commit"


def git(repo, *args, check=True):
    result = subprocess.run(["git", "-C", str(repo), *args], capture_output=True)
    if check and result.returncode:
        raise ValueError(result.stderr.decode(errors="replace").strip())
    return result


def digest(data):
    return hashlib.sha256(data).hexdigest()


def file_state(path):
    if path.is_symlink():
        return {"symlink": os.readlink(path)}
    if not path.exists():
        return None
    if not path.is_file():
        return {"error": "not a regular file"}
    return {"sha256": digest(path.read_bytes()), "executable": bool(path.stat().st_mode & 0o111)}


def source_state():
    paths = [*BUNDLE.values(), PRIVACY, "scripts/sync-toolkit.sh", "scripts/toolkit-rollout.py"]
    files = {name: file_state(SOURCE / name) for name in paths}
    return {"root": str(SOURCE), "revision": git(SOURCE, "rev-parse", "HEAD").stdout.decode().strip(),
            "working_tree_status": git(SOURCE, "status", "--porcelain=v1", "-z", "--untracked-files=all", "--", *paths).stdout.decode(),
            "files": files, "digest": digest(json.dumps(files, sort_keys=True).encode())}


def hooks_path(repo):
    return git(repo, "config", "--get", "core.hooksPath", check=False).stdout.decode().strip() or None


def linked_parent(repo, path):
    return any(p.is_symlink() for p in (repo / path).parents if p != repo and repo in p.parents)


def snapshot(repo, path):
    return {"file": file_state(repo / path),
            "status": git(repo, "status", "--porcelain=v1", "-z", "--untracked-files=all", "--", path).stdout.decode(),
            "tracked": git(repo, "ls-files", "--error-unmatch", "--", path, check=False).returncode == 0,
            "ignored": git(repo, "check-ignore", "-q", "--", path, check=False).returncode == 0}


def known_copy(source, data):
    """Recognize an older shipped copy; never treat an arbitrary custom hook as owned."""
    if data == (SOURCE / source).read_bytes():
        return True
    commits = git(SOURCE, "log", "--format=%H", "--", source).stdout.decode().splitlines()
    return any(git(SOURCE, "show", f"{rev}:{source}", check=False).stdout == data for rev in commits)


def inspect_repo(repo):
    head = git(repo, "rev-parse", "HEAD").stdout.decode().strip()
    row = {"path": str(repo), "baseline_head": head, "baseline_hooks_path": hooks_path(repo),
           "baseline_status": git(repo, "status", "--porcelain=v1", "-z", "--untracked-files=all").stdout.decode(),
           "files": [], "blockers": [], "installation": "pending", "committed": "pending", "publication": "pending", "smoke": {"status": "not-run"}}
    if row["baseline_hooks_path"] not in (None, "scripts/githooks"):
        row["blockers"].append("custom core.hooksPath must be reconciled before installation")
    bundle = dict(BUNDLE)
    if (repo / ".workbench").is_dir():
        bundle["pre-commit"] = PRIVACY
    for name, source in bundle.items():
        path = f"scripts/githooks/{name}"
        before = snapshot(repo, path)
        expected = file_state(SOURCE / source)
        if expected and "sha256" in expected:
            expected["executable"] = True
        item = {"path": path, "source": source, "expected": expected, "before": before,
                "change": "new" if before["file"] is None else "unchanged" if before["file"] == expected else "modified"}
        row["files"].append(item)
        if linked_parent(repo, path):
            row["blockers"].append(f"{path}: linked parent directory")
        if not expected or "sha256" not in expected:
            row["blockers"].append(f"{path}: canonical source is missing or unsupported")
            continue
        if before["file"] and "sha256" not in before["file"]:
            row["blockers"].append(f"{path}: linked or non-regular destination")
            continue
        if name == "pre-commit" and before["file"] and b"public-repo-plus-private-workbench" not in (repo / path).read_bytes():
            item["change"] = "preserved"
            item["expected"] = before["file"]
            continue
        if before["file"] and item["change"] != "unchanged":
            if before["status"]:
                row["blockers"].append(f"{path}: existing uncommitted destination changes")
            elif not known_copy(source, (repo / path).read_bytes()):
                row["blockers"].append(f"{path}: custom hook is not a known toolkit copy")
    return row


def write_report(path, report):
    path.parent.mkdir(parents=True, exist_ok=True)
    report["updated"] = datetime.now(timezone.utc).isoformat()
    handle, temporary = tempfile.mkstemp(prefix=".toolkit-rollout-", dir=path.parent)
    try:
        with os.fdopen(handle, "w") as stream:
            json.dump(report, stream, indent=2)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def load_report(path):
    report = json.loads(path.read_text())
    if report.get("schema") != 1 or report["source"]["root"] != str(SOURCE):
        raise ValueError("unsupported report or different source checkout; audit again")
    for row in report["repositories"]:
        repo = Path(row["path"])
        if Path(git(repo, "rev-parse", "--show-toplevel").stdout.decode().strip()).resolve() != repo:
            raise ValueError("target is no longer its recorded repository root")
        for item in row["files"]:
            name = Path(item["path"]).name
            if item["path"] != f"scripts/githooks/{name}" or item["source"] != {**BUNDLE, "pre-commit": PRIVACY}.get(name):
                raise ValueError("report contains an unsupported destination or source")
    return report


def verify_repo(row, publication=False):
    repo = Path(row["path"])
    row["verification_errors"] = []
    for item in row["files"]:
        item["current"] = snapshot(repo, item["path"])
        if linked_parent(repo, item["path"]):
            row["verification_errors"].append(f"{item['path']}: linked parent directory")
        if not item["expected"] or item["current"]["file"] != item["expected"]:
            row["verification_errors"].append(f"{item['path']}: expected content or permissions are absent")
    if hooks_path(repo) != "scripts/githooks":
        row["verification_errors"].append("core.hooksPath is not scripts/githooks")
    row["installation"] = "verified" if not row["verification_errors"] else "pending"
    if row["installation"] != "verified":
        row["smoke"] = {"status": "not-run"}
    row["committed"] = "verified"
    row["working_tree_status"] = git(repo, "status", "--porcelain=v1", "-z", "--untracked-files=all").stdout.decode()
    for item in row["files"]:
        if item["change"] == "preserved":
            continue
        if item["current"]["status"]:
            row["committed"] = "pending"
        blob = git(repo, "show", f"HEAD:{item['path']}", check=False)
        tree = git(repo, "ls-tree", "HEAD", "--", item["path"], check=False).stdout
        if not item["expected"] or blob.returncode or digest(blob.stdout) != item["expected"]["sha256"] or not tree.startswith(b"100755 "):
            row["committed"] = "pending"
    row["publication"] = "pending"
    row.pop("remote", None)
    row.pop("publication_reason", None)
    if publication and row["installation"] == "verified" and row["committed"] == "verified":
        branch = git(repo, "symbolic-ref", "--short", "HEAD", check=False).stdout.decode().strip()
        upstream = git(repo, "for-each-ref", "--format=%(upstream:remotename)%09%(upstream:remoteref)",
                       f"refs/heads/{branch}").stdout.decode().strip().split("\t")
        if len(upstream) != 2 or not all(upstream) or upstream[0] == ".":
            row["publication_reason"] = "no remote upstream; select the intended publication branch"
            return
        remote, ref = upstream
        result = git(repo, "ls-remote", "--exit-code", remote, ref, check=False)
        if result.returncode:
            row["publication_reason"] = "remote branch could not be verified"
            return
        remote_head = result.stdout.decode().split()[0]
        row["remote"] = {"name": remote, "ref": ref, "head": remote_head}
        for item in row["files"]:
            if item["change"] == "preserved":
                continue
            blob = git(repo, "show", f"{remote_head}:{item['path']}", check=False)
            tree = git(repo, "ls-tree", remote_head, "--", item["path"], check=False).stdout
            if not item["expected"] or blob.returncode or digest(blob.stdout) != item["expected"]["sha256"] or not tree.startswith(b"100755 "):
                row["publication_reason"] = f"{item['path']}: expected executable copy is not verified in remote history"
                return
        row["publication"] = "verified"
        row.pop("publication_reason", None)


def smoke_repo(row):
    """Exercise the installed validator without changing the selected repository."""
    row["smoke"] = {"status": "not-run"}
    if row["installation"] != "verified" or row["blockers"]:
        return
    validator = Path(row["path"]) / "scripts/githooks/housekeep"
    with tempfile.TemporaryDirectory(prefix="toolkit-smoke-") as temporary:
        repo = Path(temporary)
        git(repo, "init", "-q", "-b", "main")
        def commit():
            git(repo, "add", ".")
            git(repo, "-c", "core.hooksPath=/dev/null", "-c", "user.name=Toolkit smoke test",
                "-c", "user.email=smoke@example.invalid", "commit", "-qm", "fixture", "--allow-empty")
            return git(repo, "rev-parse", "HEAD").stdout.decode().strip()
        base = commit()
        doc = repo / "docs/3-design/validator-smoke.md"
        doc.parent.mkdir(parents=True)
        text = ('---\ncreated: "2000-01-01"\nupdated: "2000-01-01"\ntitle: "Validator smoke"\n'
                'type: design\nstatus: draft\nauthors: ["Toolkit smoke test"]\nscope: [smoke]\n')
        doc.write_text(text + '---\n\n# Valid fixture\n')
        valid_head = commit()
        valid = subprocess.run(["bash", str(validator), "check", "--push", base, valid_head],
                               cwd=repo, text=True, capture_output=True)
        doc.write_text(text + 'related:\n  - missing-smoke-target.md\n---\n\n# Invalid fixture\n')
        invalid_head = commit()
        invalid = subprocess.run(["bash", str(validator), "check", "--push", valid_head, invalid_head],
                                 cwd=repo, text=True, capture_output=True)
        row["smoke"] = {"status": "passed" if valid.returncode == 0 and invalid.returncode == 1
                        and "missing-smoke-target.md" in invalid.stdout + invalid.stderr else "failed",
                        "valid_exit": valid.returncode, "invalid_exit": invalid.returncode,
                        "valid_output": valid.stdout + valid.stderr, "invalid_output": invalid.stdout + invalid.stderr,
                        "scope": "Installed housekeep accepts valid metadata and rejects a broken relationship in a disposable repository. Custom hooks and harness events are not exercised."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("audit", "apply", "verify", "smoke"))
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("--repo", action="append", type=Path, default=[])
    parser.add_argument("--require", choices=("installed", "tested", "published"), default="installed")
    args = parser.parse_args()
    path = args.report.resolve()
    if args.operation == "audit":
        if not args.repo:
            parser.error("audit requires at least one explicit --repo")
        targets = []
        for target in args.repo:
            repo = Path(git(target, "rev-parse", "--show-toplevel").stdout.decode().strip()).resolve()
            if repo not in targets:
                targets.append(repo)
            sidecar = repo / ".workbench"
            if (sidecar / ".git").exists() and not sidecar.is_symlink() and sidecar not in targets:
                targets.append(sidecar)
        # A report must not itself change the target state it is meant to verify.
        for repo in targets:
            if path == repo or repo in path.parents:
                raise ValueError("put the report outside every selected target repository")
        if path.exists():
            raise ValueError("report already exists; verify/resume it or choose a new report path")
        report = {"schema": 1, "source": source_state(), "repositories": [inspect_repo(repo) for repo in targets]}
        write_report(path, report)
    else:
        if args.repo:
            parser.error("apply, verify and smoke use targets from the report")
        report = load_report(path)
        if args.operation == "apply" and source_state() != report["source"]:
            raise ValueError("source changed after preview; audit again")
        for row in report["repositories"]:
            if args.operation == "apply" and not row["blockers"]:
                repo = Path(row["path"])
                verify_repo(row)
                if row["installation"] != "verified":
                    for item in row["files"]:
                        current = snapshot(repo, item["path"])
                        if linked_parent(repo, item["path"]):
                            row["blockers"].append(f"{item['path']}: linked parent directory")
                        completed_copy = (current["file"] and item["expected"] and
                                          current["file"].get("sha256") == item["expected"].get("sha256"))
                        if current != item["before"] and not completed_copy:
                            row["blockers"].append(f"{item['path']}: destination changed after preview")
                    if hooks_path(repo) not in (row["baseline_hooks_path"], "scripts/githooks"):
                        row["blockers"].append("core.hooksPath changed after preview")
                    if git(repo, "rev-parse", "HEAD").stdout.decode().strip() != row["baseline_head"]:
                        row["blockers"].append("target HEAD changed after preview")
                    if not row["blockers"]:
                        row["installation"] = "applying"
                        write_report(path, report)
                        result = subprocess.run(["bash", str(SOURCE / "scripts/sync-toolkit.sh"), "--no-config",
                                                 "--no-sidecars", str(repo), "-y"], text=True, capture_output=True)
                        row["installer"] = {"exit_code": result.returncode, "stdout": result.stdout, "stderr": result.stderr}
                        if result.returncode:
                            row["blockers"].append("installer failed; inspect its recorded output")
            verify_repo(row, publication=args.require == "published")
            if args.operation == "smoke":
                smoke_repo(row)
            write_report(path, report)
    failed = False
    for row in report["repositories"]:
        required = row["publication"] if args.require == "published" else row["installation"]
        if args.require == "tested" or args.operation == "smoke":
            required = "verified" if row["installation"] == "verified" and row["smoke"]["status"] == "passed" else "pending"
        blocked = bool(row["blockers"])
        print(f"{row['path']}: installed={row['installation']} tested={row['smoke']['status']} committed={row['committed']} publication={row['publication']} blockers={len(row['blockers'])}")
        failed |= blocked or (args.operation != "audit" and required != "verified")
    print(f"Report: {path}")
    return 1 if failed else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(f"toolkit-rollout: {error}", file=sys.stderr)
        sys.exit(2)
