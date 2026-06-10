#!/usr/bin/env python3
r"""Resolve easy-query type names to fully qualified class names.

Usage:
    python scripts/search_symbols.py EasyWhereCondition WhereConditionProvider
    python scripts/search_symbols.py --root D:\develop\SOURCE_CODE\easy-query EasyWhereCondition
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path


PACKAGE_RE = re.compile(r"^\s*package\s+([A-Za-z_][\w.]+)\s*;?\s*$", re.MULTILINE)
JAVA_DECL_RE = re.compile(
    r"^\s*(?:public\s+)?(?:abstract\s+|final\s+|sealed\s+)?"
    r"(?P<kind>@interface|class|interface|enum|record)\s+"
    r"(?P<name>[A-Za-z_]\w*)\b",
    re.MULTILINE,
)
KOTLIN_DECL_RE = re.compile(
    r"^\s*(?:public\s+|internal\s+|private\s+|protected\s+)?"
    r"(?:(?:data|sealed|value|annotation|enum)\s+)*"
    r"(?P<kind>class|interface|object)\s+"
    r"(?P<name>[A-Za-z_]\w*)\b",
    re.MULTILINE,
)
MAIN_HINTS = (f"{os.sep}src{os.sep}main{os.sep}", f"/src/main/")
TEST_HINTS = (f"{os.sep}src{os.sep}test{os.sep}", f"/src/test/")
DEFAULT_ROOTS = [
    Path(r"D:\develop\SOURCE_CODE\easy-query"),
]


@dataclass(frozen=True)
class SymbolEntry:
    symbol: str
    kind: str
    package: str
    path: Path

    @property
    def fqcn(self) -> str:
        return f"{self.package}.{self.symbol}"

    @property
    def import_line(self) -> str:
        return f"import {self.fqcn};"


def normalize_roots(cli_roots: list[str]) -> list[Path]:
    roots: list[Path] = []
    seen: set[str] = set()

    env_roots = os.environ.get("EASY_QUERY_SOURCE_ROOTS", "")
    candidates = [Path(root) for root in cli_roots if root]
    candidates.extend(Path(root) for root in env_roots.split(os.pathsep) if root)
    candidates.extend(DEFAULT_ROOTS)

    for candidate in candidates:
        try:
            resolved = candidate.resolve()
        except OSError:
            continue
        key = str(resolved).lower()
        if key in seen:
            continue
        seen.add(key)
        if resolved.exists():
            roots.append(resolved)
    return roots


def iter_source_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for pattern in ("**/*.java", "**/*.kt"):
        files.extend(root.glob(pattern))
    return sorted(path for path in files if path.is_file())


def read_text(path: Path) -> str | None:
    for encoding in ("utf-8", "utf-8-sig", "gbk"):
        try:
            return path.read_text(encoding=encoding)
        except UnicodeDecodeError:
            continue
        except OSError:
            return None
    try:
        return path.read_text()
    except OSError:
        return None


def parse_package(text: str) -> str | None:
    match = PACKAGE_RE.search(text)
    if match:
        return match.group(1)
    return None


def parse_symbols(path: Path, text: str, package: str) -> list[SymbolEntry]:
    if path.suffix == ".kt":
        pattern = KOTLIN_DECL_RE
    else:
        pattern = JAVA_DECL_RE

    entries: list[SymbolEntry] = []
    for match in pattern.finditer(text):
        kind = match.group("kind")
        symbol = match.group("name")
        entries.append(SymbolEntry(symbol=symbol, kind=kind, package=package, path=path))
    return entries


def build_index(roots: list[Path]) -> dict[str, list[SymbolEntry]]:
    index: dict[str, list[SymbolEntry]] = {}
    for root in roots:
        for path in iter_source_files(root):
            text = read_text(path)
            if not text:
                continue
            package = parse_package(text)
            if not package or not package.startswith("com.easy.query"):
                continue
            for entry in parse_symbols(path, text, package):
                index.setdefault(entry.symbol, []).append(entry)
    return index


def entry_priority(entry: SymbolEntry) -> tuple[int, str]:
    path_text = str(entry.path).replace("\\", "/").lower()
    if any(hint.replace("\\", "/").lower() in path_text for hint in MAIN_HINTS):
        bucket = 0
    elif any(hint.replace("\\", "/").lower() in path_text for hint in TEST_HINTS):
        bucket = 1
    else:
        bucket = 2
    return (bucket, path_text)


def find_entries(index: dict[str, list[SymbolEntry]], term: str) -> tuple[str, list[SymbolEntry]]:
    if term in index:
        return ("exact", sorted(index[term], key=entry_priority))

    lower = term.lower()
    matches = [
        entry
        for symbol, entries in index.items()
        if lower in symbol.lower()
        for entry in entries
    ]
    return ("fuzzy", sorted(matches, key=lambda entry: (entry.symbol.lower(), entry_priority(entry))))


def print_matches(term: str, mode: str, matches: list[SymbolEntry]) -> None:
    print(f"[{term}]")
    if not matches:
        print("not found")
        return

    if mode == "fuzzy":
        print("mode: fuzzy")

    for entry in matches:
        print(f"{entry.symbol} | {entry.kind} | {entry.fqcn}")
        print(entry.import_line)
        print(f"path: {entry.path}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Resolve easy-query symbols to packages.")
    parser.add_argument("symbols", nargs="+", help="Type names such as EasyWhereCondition")
    parser.add_argument(
        "--root",
        action="append",
        default=[],
        help="Add a source root. Repeatable. Defaults to EASY_QUERY_SOURCE_ROOTS and common local paths.",
    )
    args = parser.parse_args()

    roots = normalize_roots(args.root)
    if not roots:
        print("no readable easy-query source roots found", file=sys.stderr)
        print("set EASY_QUERY_SOURCE_ROOTS or pass --root", file=sys.stderr)
        return 2

    index = build_index(roots)
    if not index:
        print("no com.easy.query symbols found under the configured roots", file=sys.stderr)
        return 3

    for i, term in enumerate(args.symbols):
        if i:
            print()
        mode, matches = find_entries(index, term)
        print_matches(term, mode, matches)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
