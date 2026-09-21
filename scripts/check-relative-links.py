#!/usr/bin/env python3
"""CLI entry point for relative link checking."""
import os
import sys

repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if repo_root not in sys.path:
    sys.path.insert(0, repo_root)

from scripts.check_relative_links import main

if __name__ == "__main__":
    sys.exit(main())
