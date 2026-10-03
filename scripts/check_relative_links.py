#!/usr/bin/env python3
"""
scripts/check-relative-links.py — verify relative links in public tracked Markdown.

CLI:
  python3 scripts/check-relative-links.py [--root REPO_ROOT] [files...]

Exits:
  0 if all relative links resolve to existing local files/directories.
  1 if any relative link is broken, reporting file:line: target.
"""

import argparse
import os
import re
import sys
import urllib.parse
import subprocess

# Directories excluded from the public relative-link scan
EXCLUDED_PREFIXES = (
    "docs/0-brainstorms/",
    "docs/1-discovery/",
    "docs/2-design/",
    "docs/3-plans/",
    "docs/4-reviews/",
    "docs/notes/",
    "docs/guides/",
    "tools/",
    "tests/fixtures/",
    ".workbench/",
)

# Explicit narrow template placeholder targets
EXPLICIT_TEMPLATE_PLACEHOLDERS = {
    "docs/architecture.md",
}

# Regexes
FENCE_RE = re.compile(r"^(?:```|~~~)")
INLINE_CODE_RE = re.compile(r"`+[^`]+`+")
HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
INLINE_LINK_RE = re.compile(r"\[(?:[^\]]*)\]\(([^)]+)\)")
REF_DEF_RE = re.compile(r"^\[([^\]]+)\]:\s*(\S+)")
HTML_HREF_RE = re.compile(r'<a\s+[^>]*href=["\']([^"\']+)["\']', re.IGNORECASE)
HTML_SRC_RE = re.compile(r'<img\s+[^>]*src=["\']([^"\']+)["\']', re.IGNORECASE)

EXTERNAL_SCHEMES = ("http://", "https://", "mailto:", "ftp://", "file://", "data:", "javascript:")


def is_external_or_anchor(target: str) -> bool:
    """Returns True if the target is external or a local fragment-only anchor."""
    clean = target.strip()
    if clean.startswith("#"):
        return True
    lower = clean.lower()
    for scheme in EXTERNAL_SCHEMES:
        if lower.startswith(scheme):
            return True
    return False


def is_template_placeholder(target: str, source_file: str) -> bool:
    """Check narrow template placeholder exceptions."""
    # Placeholders like <CANONICAL_CONVENTIONS_URL> or <OWNER>/<REPO>
    if "<" in target and ">" in target:
        return True
    if target in ("...", "url"):
        return True
    # Narrow template-only architecture.md placeholder
    if source_file.startswith("templates/") and target in EXPLICIT_TEMPLATE_PLACEHOLDERS:
        return True
    return False


def clean_target(raw_target: str) -> str:
    """Strip optional Markdown titles, fragments, queries, and decode URL escapes."""
    # If link is [text](path "title"), take first token
    parts = raw_target.strip().split()
    target = parts[0] if parts else ""
    # Strip fragment and query
    target = target.split("#")[0].split("?")[0]
    return urllib.parse.unquote(target)


def extract_links_from_content(content: str, source_file: str):
    """
    Extracts local relative links from Markdown content.
    Returns list of (line_number, raw_target, cleaned_target).
    """
    lines = content.splitlines()
    in_fence = False
    in_comment = False
    links = []

    for lno, line in enumerate(lines, 1):
        stripped = line.strip()

        # Handle fenced code blocks
        if FENCE_RE.match(stripped):
            in_fence = not in_fence
            continue
        if in_fence:
            continue

        # Handle multi-line HTML comments
        if "<!--" in line and "-->" not in line:
            in_comment = True
            continue
        if in_comment:
            if "-->" in line:
                in_comment = False
            continue

        # Strip inline HTML comments
        line_clean = HTML_COMMENT_RE.sub("", line)

        # Strip inline code spans so examples in backticks are not parsed as real links
        line_clean = INLINE_CODE_RE.sub("", line_clean)

        raw_targets = []

        # 1. Reference definitions: [id]: target
        ref_match = REF_DEF_RE.match(line_clean.strip())
        if ref_match:
            raw_targets.append(ref_match.group(2))

        # 2. Inline links: [text](target)
        for m in INLINE_LINK_RE.finditer(line_clean):
            raw_targets.append(m.group(1))

        # 3. HTML href: <a href="target">
        for m in HTML_HREF_RE.finditer(line_clean):
            raw_targets.append(m.group(1))

        # 4. HTML src: <img src="target">
        for m in HTML_SRC_RE.finditer(line_clean):
            raw_targets.append(m.group(1))

        for raw_target in raw_targets:
            raw_target = raw_target.strip()
            if not raw_target:
                continue
            if is_external_or_anchor(raw_target):
                continue
            if is_template_placeholder(raw_target, source_file):
                continue
            cleaned = clean_target(raw_target)
            if not cleaned:
                continue
            links.append((lno, raw_target, cleaned))

    return links


def check_file_links(file_path: str, repo_root: str):
    """
    Checks all relative links in file_path.
    Returns list of failure messages: "file:line: raw_target -> resolved"
    """
    full_path = os.path.join(repo_root, file_path) if not os.path.isabs(file_path) else file_path
    if not os.path.exists(full_path):
        return [f"{file_path}: file does not exist"]

    with open(full_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    failures = []
    file_dir = os.path.dirname(full_path)
    links = extract_links_from_content(content, file_path)

    for lno, raw_target, cleaned in links:
        if cleaned.startswith("/"):
            # Root-relative
            resolved = os.path.normpath(os.path.join(repo_root, cleaned.lstrip("/")))
        else:
            resolved = os.path.normpath(os.path.join(file_dir, cleaned))

        if not os.path.exists(resolved):
            failures.append(f"{file_path}:{lno}: {raw_target} -> {resolved}")

    return failures


def get_public_tracked_md_files(repo_root: str):
    """Enumerates tracked Markdown files excluding lifecycle directories and tools/."""
    try:
        cmd = ["git", "-C", repo_root, "ls-files"]
        out = subprocess.check_output(cmd, text=True)
        tracked = out.splitlines()
    except Exception as e:
        # Fallback to filesystem walk
        tracked = []
        for root, dirs, files in os.walk(repo_root):
            for f in files:
                rel = os.path.relpath(os.path.join(root, f), repo_root)
                tracked.append(rel)

    public_files = []
    for f in tracked:
        if not f.endswith(".md"):
            continue
        norm_f = f.replace("\\", "/")
        if any(norm_f.startswith(p) for p in EXCLUDED_PREFIXES):
            continue
        public_files.append(norm_f)

    return sorted(public_files)


def main():
    parser = argparse.ArgumentParser(description="Check relative links in public tracked Markdown files.")
    parser.add_argument("--root", default=".", help="Repository root path")
    parser.add_argument("files", nargs="*", help="Optional specific files to check")
    args = parser.parse_args()

    repo_root = os.path.abspath(args.root)

    if args.files:
        files_to_check = args.files
    else:
        files_to_check = get_public_tracked_md_files(repo_root)

    all_failures = []
    for f in files_to_check:
        failures = check_file_links(f, repo_root)
        if failures:
            all_failures.extend(failures)

    if all_failures:
        print(f"FAILED: Found {len(all_failures)} unresolved relative links:")
        for fail in all_failures:
            print(f"  {fail}")
        sys.exit(1)
    else:
        print(f"OK: Checked relative links across {len(files_to_check)} public Markdown files; 0 unresolved.")
        sys.exit(0)


if __name__ == "__main__":
    main()
