#!/usr/bin/env python3
"""Compare original Swift URL action and NSWorkspace extension with native V."""
import argparse
import json
import pathlib
import subprocess
import tempfile

p = argparse.ArgumentParser()
p.add_argument("ghostty", type=pathlib.Path)
p.add_argument("translated_output", type=pathlib.Path)
args = p.parse_args()
source = args.ghostty / "macos/Sources/Ghostty/Ghostty.App.swift"
text = source.read_text()
start = text.index("        private static func openURL(")
end = text.index("        private static func undo(", start)
body = text[start:end].replace("private static func", "static func", 1)
# Substitute only the workspace receiver; Foundation parsing/configuration and
# the unchanged extension's UTType/LaunchServices lookups stay native.
body = body.replace("NSWorkspace.shared", "URLProbeWorkspace.shared")
with tempfile.TemporaryDirectory(prefix="witty-url-source-") as tmp:
    fixture = pathlib.Path(tmp) / "SourceURLAction.swift"
    fixture.write_text("import AppKit\nstruct SourceURLAction {\n" + body + "}\n")
    binary = pathlib.Path(tmp) / "open-url-source"
    subprocess.run(["xcrun", "swiftc", "-swift-version", "5",
                    str(args.ghostty / "macos/Sources/Helpers/Extensions/NSWorkspace+Extension.swift"),
                    str(fixture), str(pathlib.Path(__file__).with_name("main.swift")),
                    "-o", str(binary)], check=True)
    actual = json.loads(subprocess.run([str(binary)], check=True, text=True, capture_output=True).stdout)
    expected = json.loads(args.translated_output.read_text())
    assert actual == expected, (actual, expected)
    print(f"{len(actual)} original Swift URL/UTType/default-editor routes matched; native opens recorded only")
