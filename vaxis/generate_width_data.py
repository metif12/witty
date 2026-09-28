#!/usr/bin/env python3
"""Generate the width properties used by pinned vaxis gwidth.zig.

Input is the UCD directory in uucode commit
5f05f8f83a75caea201f12cc8ea32a2d82ea9732 (vaxis' locked dependency).
The output contains merged inclusive ranges for East Asian W/F, general
category Mn/Me, and Emoji_Presentation. Each range and count is a little
endian u32. The fourth group stores GraphemeBreak=Control for vaxis' own
grapheme iterator. Unicode data is distributed under the Unicode License.
"""

from pathlib import Path
import struct
import sys


MAX_CP = 0x110000


def codepoint_range(text: str) -> range:
    parts = text.strip().split("..")
    start = int(parts[0], 16)
    end = int(parts[-1], 16)
    return range(start, end + 1)


def ranges_from_flags(flags: bytearray) -> list[tuple[int, int]]:
    result = []
    start = None
    for cp, flagged in enumerate(flags):
        if flagged and start is None:
            start = cp
        elif not flagged and start is not None:
            result.append((start, cp - 1))
            start = None
    if start is not None:
        result.append((start, MAX_CP - 1))
    return result


def generate(ucd: Path) -> bytes:
    wide = bytearray(MAX_CP)
    marks = bytearray(MAX_CP)
    emoji_presentation = bytearray(MAX_CP)
    grapheme_control = bytearray(MAX_CP)

    # Match uucode's parseEastAsianWidth: @missing rules are installed first,
    # and explicit entries replace them.
    eaw_lines = (ucd / "extracted/DerivedEastAsianWidth.txt").read_text().splitlines()
    for missing in (True, False):
        for line in eaw_lines:
            stripped = line.strip()
            is_missing = stripped.startswith("# @missing:")
            if is_missing != missing:
                continue
            if is_missing:
                fields = stripped[len("# @missing:") :].split(";")
                value = fields[1].strip()
                if value == "Neutral":
                    continue
                assert value == "Wide", value
            else:
                fields = stripped.split("#", 1)[0].split(";")
                if len(fields) < 2:
                    continue
                value = fields[1].strip()
            flag = int(value in ("W", "F", "Wide"))
            for cp in codepoint_range(fields[0]):
                wide[cp] = flag

    # UnicodeData uses First/Last pairs for ranges. uucode copies the First
    # category through the Last codepoint.
    range_start = None
    range_category = None
    for line in (ucd / "UnicodeData.txt").read_text().splitlines():
        fields = line.split(";")
        cp = int(fields[0], 16)
        name, category = fields[1:3]
        if name.endswith(", First>"):
            range_start, range_category = cp, category
        elif name.endswith(", Last>"):
            assert range_start is not None
            for part in range(range_start, cp + 1):
                marks[part] = int(range_category in ("Mn", "Me"))
            range_start = None
        else:
            marks[cp] = int(category in ("Mn", "Me"))
    assert range_start is None

    for line in (ucd / "emoji/emoji-data.txt").read_text().splitlines():
        fields = line.split("#", 1)[0].split(";")
        if len(fields) < 2 or fields[1].strip() != "Emoji_Presentation":
            continue
        for cp in codepoint_range(fields[0]):
            emoji_presentation[cp] = 1

    for line in (ucd / "auxiliary/GraphemeBreakProperty.txt").read_text().splitlines():
        fields = line.split("#", 1)[0].split(";")
        if len(fields) < 2 or fields[1].strip() != "Control":
            continue
        for cp in codepoint_range(fields[0]):
            grapheme_control[cp] = 1

    groups = [ranges_from_flags(flags) for flags in (wide, marks, emoji_presentation, grapheme_control)]
    output = bytearray(struct.pack("<IIII", *(len(group) for group in groups)))
    for group in groups:
        for start, end in group:
            output += struct.pack("<II", start, end)
    return bytes(output)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: generate_width_data.py <uucode/ucd> <output.bin>")
    Path(sys.argv[2]).write_bytes(generate(Path(sys.argv[1])))
