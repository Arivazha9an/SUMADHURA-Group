#!/usr/bin/env python3
"""Removes the interview-notes comment blocks from every file in the project.

Usage (from the project root):
    python3 scripts/strip_interview_notes.py --check   # list files, change nothing
    python3 scripts/strip_interview_notes.py           # remove the blocks

Each block starts with a line containing ">>> INTERVIEW NOTES START" and ends
with a line containing "<<< INTERVIEW NOTES END"; one blank line that follows
the block is removed with it. docs/INTERVIEW_NOTES.md is deleted too. This
script is not touched: delete it yourself before sharing.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
START = ">>>" + " INTERVIEW NOTES START"
END = "<<<" + " INTERVIEW NOTES END"
SKIP_DIRS = {".git", "build", ".dart_tool", ".idea", "android", "ios"}
SELF = Path(__file__).resolve()
EXTENSIONS = {".dart", ".yaml", ".yml", ".sh"}


def strip_text(text):
    lines = text.splitlines(keepends=True)
    out, i, removed = [], 0, 0
    while i < len(lines):
        if START in lines[i]:
            j = i
            while j < len(lines) and END not in lines[j]:
                j += 1
            if j == len(lines):
                raise ValueError("start marker without end marker")
            i = j + 1
            if i < len(lines) and lines[i].strip() == "":
                i += 1
            removed += 1
            continue
        out.append(lines[i])
        i += 1
    return "".join(out), removed


def main():
    check = "--check" in sys.argv
    touched = 0
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file() or path.resolve() == SELF:
            continue
        rel = path.relative_to(ROOT)
        if any(part in SKIP_DIRS for part in rel.parts):
            continue
        if path.suffix not in EXTENSIONS:
            continue
        text = path.read_text(encoding="utf-8")
        if START not in text:
            continue
        new_text, removed = strip_text(text)
        touched += 1
        print(("would strip " if check else "stripped ") + str(rel))
        if not check:
            path.write_text(new_text, encoding="utf-8")
    guide = ROOT / "docs" / "INTERVIEW_NOTES.md"
    if guide.exists():
        print(("would delete " if check else "deleted ") + "docs/INTERVIEW_NOTES.md")
        if not check:
            guide.unlink()
    print(f"{touched} file(s) {'to strip' if check else 'stripped'}.")
    if not check:
        print("Now delete scripts/strip_interview_notes.py itself before sharing.")


if __name__ == "__main__":
    main()
