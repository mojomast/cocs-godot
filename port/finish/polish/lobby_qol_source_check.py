#!/usr/bin/env python3
"""Engine-free source check for the lobby QoL slice.

Godot/native execution belongs to the exclusive native owner (MOTION-UI-NATIVE-
20261003-K); this script never starts Godot, a server, an import or a renderer.

It uses the real `gdtoolkit` GDScript parser when available (the parent asked
for gdparse, not just a structural regex), falling back to a structural scan
only if the parser is missing. It also asserts the QoL contract symbols the
pending native fixture depends on.

Run with the parser on PYTHONPATH, e.g.:
    PYTHONPATH=/tmp/opencode/gdtlib python3 port/finish/polish/lobby_qol_source_check.py --require-parser
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
FILES = [
    "godot/social/room_browser.gd",
    "godot/ui/lobby_choice.gd",
    "godot/ui/lobby_menu.gd",
    "godot/ui/match_setup.gd",
    "godot/tests/protocol/lobby_qol.gd",
]

CONTRACTS = {
    "godot/social/room_browser.gd": ["func filter_active", "func clear_filters(", "clear_filters_button", "func apply_selection_mark("],
    "godot/ui/lobby_choice.gd": ["var update_count", "var _disabled", "func refresh("],
    "godot/ui/lobby_menu.gd": ["func map_entry(", "func offered_modes(", "func launchable(", "func catalog_error_text(", "func catalog_signature(", "func rebuild_map_choices(", "func sync_map_choices(", "func apply_choice_enablement(", "room_editable_writes"],
    "godot/ui/match_setup.gd": ["func map_entry(", "func offered_modes(", "static func valid_modes(", "func catalog_signature(", "func rebuild_map_choices(", "func sync_catalog(", "func _process("],
    "godot/tests/protocol/lobby_qol.gd": ["PORT_LOBBY_QOL_OK", "update_count", "clear_filters", "new-arena", "valid_modes"],
}

try:  # real parser, preferred
    from gdtoolkit.parser import parser as gd_parser
except Exception:  # pragma: no cover - optional dependency
    gd_parser = None


def strip_code(text: str) -> list[tuple[int, str]]:
    out: list[tuple[int, str]] = []
    i, n, line = 0, len(text), 1
    buf: list[str] = []

    def flush() -> None:
        out.append((line, "".join(buf)))
        buf.clear()

    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        nxt2 = text[i + 2] if i + 2 < n else ""
        if ch == "\n":
            flush()
            line += 1
            i += 1
        elif ch == "#":
            while i < n and text[i] != "\n":
                i += 1
        elif ch in "'\"" and nxt == ch and nxt2 == ch:
            end = text.find(ch * 3, i + 3)
            i = (end + 3) if end != -1 else n
            buf.append(" ")
        elif ch in "'\"":
            quote, i = ch, i + 1
            while i < n and text[i] != "\n":
                if text[i] == "\\":
                    i += 2
                    continue
                if text[i] == quote:
                    i += 1
                    break
                i += 1
            buf.append(" ")
        else:
            buf.append(ch)
            i += 1
    flush()
    return out


def structural(path: Path) -> list[str]:
    problems: list[str] = []
    text = path.read_text(encoding="utf-8")
    raw_lines = text.split("\n")
    pairs = {")": "(", "]": "[", "}": "{"}
    stack: list[tuple[str, int]] = []
    funcs: dict[str, int] = {}
    indent_style: str | None = None
    for line_no, code in strip_code(text):
        raw = raw_lines[line_no - 1] if line_no - 1 < len(raw_lines) else code
        indent = raw[: len(raw) - len(raw.lstrip(" \t"))]
        if indent:
            if " " in indent and "\t" in indent:
                problems.append(f"{path}:{line_no}: mixed tab/space indentation")
            if indent_style is None:
                indent_style = "\t" if "\t" in indent else " "
            elif indent_style == "\t" and "\t" not in indent:
                problems.append(f"{path}:{line_no}: space indent in tab file")
        for ch in code:
            if ch in "([{":
                stack.append((ch, line_no))
            elif ch in ")]}":
                if not stack:
                    problems.append(f"{path}:{line_no}: unmatched '{ch}'")
                elif stack[-1][0] != pairs[ch]:
                    problems.append(f"{path}:{line_no}: '{ch}' closes '{stack[-1][0]}' from line {stack[-1][1]}")
                    stack.pop()
                else:
                    stack.pop()
        match = re.match(r"(?:static )?func ([A-Za-z_][A-Za-z0-9_]*)\s*\(", code.strip())
        if match:
            name = match.group(1)
            if name in funcs:
                problems.append(f"{path}:{line_no}: duplicate func {name} (first line {funcs[name]})")
            funcs[name] = line_no
    if stack:
        opener, opened = stack[-1]
        problems.append(f"{path}: unclosed '{opener}' opened at line {opened}")
    return problems


def main(argv: list[str]) -> int:
    require_parser = "--require-parser" in argv
    files = [a for a in argv[1:] if not a.startswith("--")] or FILES
    text_by_path = {name: (ROOT / name).read_text(encoding="utf-8") for name in files}
    problems: list[str] = []
    for name in files:
        path = ROOT / name
        parsed = False
        if gd_parser is not None:
            try:
                gd_parser.parse(text_by_path[name])
                parsed = True
            except Exception as error:  # parser errors carry line/context
                problems.append(f"{name}: GDSCRIPT_PARSE_FAIL {type(error).__name__}: {error}")
        problems.extend(structural(path))
        missing = [token for token in CONTRACTS.get(name, []) if token not in text_by_path[name]]
        problems.extend(f"{name}: missing contract token {token!r}" for token in missing)
        status = "ok   " + ("parser" if parsed else "structural-only")
        print(f"{status} {name}")
    if require_parser and gd_parser is None:
        print("LOBBY_QOL_SOURCE_FAIL reason=gdtoolkit-parser-unavailable")
        return 2
    if problems:
        print("\n".join(problems))
        print(f"LOBBY_QOL_SOURCE_FAIL problems={len(problems)} parser={'gdtoolkit' if gd_parser else 'unavailable'}")
        return 1
    print(f"LOBBY_QOL_SOURCE_OK files={len(files)} problems=0 parser={'gdtoolkit' if gd_parser else 'structural-fallback'} native_execution_pending=true")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
