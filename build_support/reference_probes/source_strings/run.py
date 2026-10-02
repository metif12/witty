#!/usr/bin/env python3
"""Compare original Swift StartSearch, KeyTable and hover string wrappers."""
import argparse
import json
import pathlib
import subprocess
import tempfile

p = argparse.ArgumentParser()
p.add_argument("ghostty", type=pathlib.Path)
p.add_argument("translated_output", type=pathlib.Path)
args = p.parse_args()
action = (args.ghostty / "macos/Sources/Ghostty/Ghostty.Action.swift").read_text()
start_search = action[action.index("    struct StartSearch {"):action.index("    enum PromptTitle {")]
key_start = action.index("    enum KeyTable {")
key_end = action.index("\n    }\n}", key_start) + len("\n    }")
app = (args.ghostty / "macos/Sources/Ghostty/Ghostty.App.swift").read_text()
hover_start = app.index("        private static func setMouseOverLink(")
hover_end = app.index("        private static func setInitialSize(", hover_start)
hover = app[hover_start:hover_end].replace("private static func", "static func", 1)
with tempfile.TemporaryDirectory(prefix="witty-string-source-") as tmp:
    fixture = pathlib.Path(tmp) / "SourceStrings.swift"
    fixture.write_text("import AppKit\nenum Ghostty {\nstatic let logger = LoggerFixture()\nenum Action {\n"
        + start_search + action[key_start:key_end] + "\n}\n}\nstruct SourceHoverAction {\n"
        + "static func surfaceView(from surface: Int) -> SurfaceViewFixture? { surfaceViewFixture }\n"
        + hover + "}\n")
    binary = pathlib.Path(tmp) / "source-strings"
    subprocess.run(["xcrun", "swiftc", "-swift-version", "5", str(fixture),
        str(pathlib.Path(__file__).with_name("main.swift")), "-o", str(binary)], check=True)
    actual = json.loads(subprocess.run([str(binary)], check=True, text=True, capture_output=True).stdout)
    expected = json.loads(args.translated_output.read_text())
    for records in (actual, expected):
        for record in records:
            for key in ("search", "hover", "c_strict"):
                record.setdefault(key, None)
    assert actual == expected, (actual, expected)
    print(f"{len(actual)} original Swift search/key-table/hover/C-string records matched (four projections each)")
