#!/usr/bin/env python3
"""Compare native config projections with unchanged Ghostty Swift getters."""
import argparse
import json
import pathlib
import subprocess
import tempfile

p = argparse.ArgumentParser()
p.add_argument("ghostty", type=pathlib.Path)
p.add_argument("translated_output", type=pathlib.Path)
args = p.parse_args()
source = (args.ghostty / "macos/Sources/Ghostty/Ghostty.Config.swift").read_text()
command_source = (args.ghostty / "macos/Sources/Ghostty/Ghostty.Command.swift").read_text()
command_extension = command_source[command_source.index("extension Ghostty {"):]
getters = []
for name, following in (("title", "windowSaveState"),
                        ("windowTitleFontFamily", "macosWindowButtons")):
    start = source.index(f"        var {name}:")
    end = source.index(f"        var {following}:", start)
    getters.append(source[start:end])

with tempfile.TemporaryDirectory(prefix="witty-config-string-source-") as tmp:
    fixture = pathlib.Path(tmp) / "ConfigStrings.swift"
    fixture.write_text("import AppKit\nenum Ghostty {\nfinal class Config {\n"
        + "let config: OpaquePointer? = OpaquePointer(bitPattern: 1)\n"
        + "\n".join(getters) + "\n}\n}\n"
        + "struct ghostty_command_s {\n"
        + "let title: UnsafePointer<Int8>\nlet description: UnsafePointer<Int8>\n"
        + "let action: UnsafePointer<Int8>\nlet action_key: UnsafePointer<Int8>\n}\n"
        + command_extension
        + "var currentString: UnsafePointer<Int8>? = nil\n"
        + "func ghostty_config_get(_ config: OpaquePointer, "
        + "_ output: UnsafeMutablePointer<UnsafePointer<Int8>?>, _ key: String, "
        + "_ length: UInt) -> Bool { output.pointee = currentString; return true }\n")
    binary = pathlib.Path(tmp) / "config-strings"
    subprocess.run(["xcrun", "swiftc", "-swift-version", "5", str(fixture),
        str(pathlib.Path(__file__).with_name("main.swift")), "-o", str(binary)], check=True)
    actual = json.loads(subprocess.run([str(binary)], check=True,
        text=True, capture_output=True).stdout)
    expected = json.loads(args.translated_output.read_text())
    for records in (actual, expected):
        for record in records:
            for key in ("title", "family", "command_title", "command_description"):
                record.setdefault(key, None)
    assert actual == expected, (actual, expected)
    print(f"{len(actual)} original Swift config-string records matched "
          "(two getters and command title/description)")
