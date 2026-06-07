#!/usr/bin/env python3
"""Search bundled easy-query skill references.

Usage:
    python scripts/search_references.py selectAutoInclude NavigateFlat
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


def main() -> int:
    terms = sys.argv[1:]
    if not terms:
        print("usage: search_references.py <term> [term...]")
        return 2

    root = Path(__file__).resolve().parents[1]
    refs = root / "references"
    patterns = [re.compile(re.escape(term), re.IGNORECASE) for term in terms]

    for path in sorted(refs.glob("*.md")):
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except UnicodeDecodeError:
            lines = path.read_text().splitlines()

        for lineno, line in enumerate(lines, 1):
            if any(pattern.search(line) for pattern in patterns):
                rel = path.relative_to(root).as_posix()
                print(f"{rel}:{lineno}: {line}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
