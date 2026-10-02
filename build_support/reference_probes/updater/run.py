#!/usr/bin/env python3
"""Run the four unchanged pinned Swift updater files against translated output."""
import argparse
import json
import pathlib
import subprocess
import tempfile

p = argparse.ArgumentParser()
p.add_argument("ghostty", type=pathlib.Path)
p.add_argument("sparkle_framework", type=pathlib.Path)
p.add_argument("translated_output", type=pathlib.Path)
args = p.parse_args()
source = args.ghostty / "macos/Sources/Features/Update"
with tempfile.TemporaryDirectory(prefix="witty-updater-source-") as tmp:
    binary = pathlib.Path(tmp) / "updater-source"
    subprocess.run(["xcrun", "swiftc", "-swift-version", "5", "-F", str(args.sparkle_framework.parent),
                    "-framework", "Sparkle", "-Xlinker", "-rpath", "-Xlinker", str(args.sparkle_framework.parent),
                    *[str(source / f"{name}.swift") for name in ("UpdateController", "UpdateDriver", "UpdateViewModel", "UpdateDelegate")],
                    str(pathlib.Path(__file__).with_name("main.swift")), "-o", str(binary)], check=True)
    actual = json.loads(subprocess.run([str(binary)], check=True, text=True, capture_output=True).stdout)
    expected = json.loads(args.translated_output.read_text())
    # V's JSON encoder omits absent optional fields; both represent nil values.
    for record in expected:
        record.setdefault("icon", None)
        record.setdefault("badge", None)
    assert actual == expected, (actual, expected)
    print(f"{len(actual)} original Swift ViewModel states and controller install/cancel lifecycle matched")
