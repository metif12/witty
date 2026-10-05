#!/usr/bin/env python3
"""Compare live clipboard consumers with unchanged pinned Swift method bodies."""
import argparse
import json
import pathlib
import subprocess
import tempfile

p = argparse.ArgumentParser()
p.add_argument("ghostty", type=pathlib.Path)
p.add_argument("translated_output", type=pathlib.Path)
args = p.parse_args()
revision = subprocess.check_output(["git", "-C", str(args.ghostty), "rev-parse", "HEAD"], text=True).strip()
assert revision == "6c0e02d1138d5376e4ac2f5e311b225494514a97", revision
sources = args.ghostty / "macos/Sources"
for relative in ["Helpers/Extensions/NSPasteboard+Extension.swift", "Ghostty/Package.swift",
        "Ghostty/Ghostty.App.swift", "Ghostty/Ghostty.Shell.swift",
        "Features/Terminal/BaseTerminalController.swift"]:
    pinned = subprocess.check_output(["git", "-C", str(args.ghostty), "show",
        revision + ":macos/Sources/" + relative])
    assert (sources / relative).read_bytes() == pinned, f"modified source: {relative}"


def block(text, marker):
    start = text.index(marker)
    opening = text.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (text[end] == "{") - (text[end] == "}")
        end += 1
    return text[start:end]


pasteboard = (sources / "Helpers/Extensions/NSPasteboard+Extension.swift").read_text()
package = (sources / "Ghostty/Package.swift").read_text()
app = (sources / "Ghostty/Ghostty.App.swift").read_text()
# The file also declares empty non-macOS callback stubs above this section.
app = app[app.index("        // MARK: Ghostty Callbacks (macOS)"):]
controller = (sources / "Features/Terminal/BaseTerminalController.swift").read_text()
with tempfile.TemporaryDirectory(prefix="witty-clipboard-source-") as tmp:
    fixture = pathlib.Path(tmp) / "ClipboardSource.swift"
    fixture.write_text("import AppKit\nimport UniformTypeIdentifiers\n"
        + "typealias ghostty_surface_t = Int\n"
        + "typealias ghostty_clipboard_e = Int\n"
        + "typealias ghostty_clipboard_request_e = Int\n"
        + "let GHOSTTY_CLIPBOARD_REQUEST_PASTE = 0; let GHOSTTY_CLIPBOARD_REQUEST_OSC_52_READ = 1; let GHOSTTY_CLIPBOARD_REQUEST_OSC_52_WRITE = 2\n"
        + "struct ghostty_clipboard_content_s { var mime: UnsafePointer<CChar>?; var data: UnsafePointer<CChar>? }\n"
        + "enum Ghostty {\n"
        + "class SurfaceView { var surface: ghostty_surface_t? = 1 }\n"
        + "enum ClipboardRequest { case paste, osc_52_read, osc_52_write(NSPasteboard?)\n"
        + block(package, "        static func from(request: ghostty_clipboard_request_e)") + "\n}\n"
        + block(package, "    struct ClipboardContent {") + "\n}\n"
        + (sources / "Ghostty/Ghostty.Shell.swift").read_text()
        + "extension NSPasteboard.PasteboardType {\n"
        + block(pasteboard, "    init?(mimeType:") + "\n}\n"
        + "extension NSPasteboard {\n"
        + block(pasteboard, "    func getOpinionatedStringContents()") + "\n"
        + "static func ghostty(_ location: Int) -> NSPasteboard? { location == 1 ? fixtureBoard : nil }\n}\n"
        + "extension Notification.Name { static let confirmClipboard = Notification.Name(\"FixtureConfirmClipboard\") }\n"
        + "extension Notification { static let confirmClipboard = Notification.Name.confirmClipboard; static let ConfirmClipboardStrKey = \"text\"; static let ConfirmClipboardStateKey = \"state\"; static let ConfirmClipboardRequestKey = \"request\" }\n"
        + "enum FixtureApp { static func surfaceUserdata(from: UnsafeMutableRawPointer?) -> Ghostty.SurfaceView { Ghostty.SurfaceView() }\n"
        + "\n".join(block(app, marker) for marker in (
            "        static func readClipboard(", "        static func confirmReadClipboard(",
            "        static func completeClipboardRequest(", "        static func writeClipboard("))
        + "\n}\n"
        + "extension Ghostty { typealias App = FixtureApp }\n"
        + "enum ClipboardConfirmationView { enum Action { case cancel, confirm } }\n"
        + "struct FixtureConfirmation { var window: NSWindow? = nil; var contents: String; var surface: Int = 1; var state: UnsafeMutableRawPointer? = nil }\n"
        + "class FixtureController { var clipboardConfirmation: FixtureConfirmation?; var window: NSWindow?\n"
        + block(controller, "    func clipboardConfirmationComplete(") + "\n}\n")
    binary = pathlib.Path(tmp) / "clipboard-source"
    subprocess.run(["xcrun", "swiftc", "-swift-version", "5", str(fixture),
        str(pathlib.Path(__file__).with_name("main.swift")), "-o", str(binary)], check=True)
    result = subprocess.run([str(binary)], text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr)
    actual = json.loads(result.stdout)
    expected = json.loads(args.translated_output.read_text())
    assert actual == expected, (actual, expected)
    print(f"{len(actual)} unchanged Swift clipboard helper/callback/controller records matched")
