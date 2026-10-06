# Window output reference comparison

The runner hashes the entire pinned Vaxis source and locked uucode package,
copies them unchanged and uses the unchanged Unicode table generator. It calls
the public Window `fill`, `clear`, `print` and `printSegment` methods without
private wrappers or source visibility edits.

```sh
python3 vaxis/verify_window_output_reference.py \
  /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /tmp/witty-window-output-debug

python3 vaxis/verify_window_output_reference.py \
  /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --v-prod --workdir /tmp/witty-window-output-prod
```

Retained directories must be new. `--v-prod` selects V production and Source
ReleaseSafe; ordinary V uses Source Debug. Source target is native
`aarch64-macos.14.0` with Zig 0.15.2 and V 0.5.2 fallback. Source hashes and the
dependency graph come from `widgets_classic/source_build.py`.

Both ordinary/Debug and production/ReleaseSafe matrices pass 33,215 returning
records and fifteen isolated
trap pairs. Returning SHA-256, excluding the final newline:
`d97f410c29c874baeee7e5506ce5e55dd68bbdb2740061d1f7b2ea5a037d617b`.

Fill records cover contiguous and partial rows, zero sizes, signed i17 offsets,
short backing buffers, parent offsets, clipped and clear behavior, and large
usize products before buffer clamping. The source's contiguous path fills
`height` rows from the clamped start even with a negative vertical offset; the
translation retains that behavior. Fill ignores parent offsets as Source does.
Both i17 endpoint additions retain source short-circuit order before clipping.

Print records cover all three wraps and width methods, zero/small sizes, row
and column offsets, measurement-only calls, clipped screen coordinates, single
and split segments, ASCII, CR/LF/CRLF, tabs, controls, malformed UTF-8, combining
characters, flags and ZWJ emoji. Split valid UTF-8 records use codepoint boundaries;
the malformed unit splits use their endpoints. Arbitrary malformed byte-split
states are not exhaustively certified. Isolated probes include the inherited
malformed-byte Unicode underflow in every wrap mode, including `.none` with a
zero-width window: Source advances its iterator before checking column bounds.

Cell records include raw grapheme bytes, width, default/wrapped flags, indexed
foreground and bold style, hyperlink URI/params and pointer offsets into caller
text. A subsequent caller-buffer mutation checks all retained grapheme bytes.
Whitespace introduced by word wrap remains a literal space, while word bytes
retain their original views. This covers the formerly copied tokenizer and
grapheme slices without claiming every image/style/scale payload combination.

Trap subprocesses cover fill's i17 endpoints, initial/final grapheme row
increments, grapheme columns and wrapped-flag addition, word-width addition,
whitespace/deferred row increments, inherited Unicode underflows and u8 cell
width casts for 260-cell-wide no-ZWJ graphemes. The same giant grapheme returns
normally when measurement skips the cell constructor. Cast diagnostics differ:
Source reports `integer does not fit in destination type`, V reports `integer
cast truncated bits`; the runner checks each exact category. Other traps require
an anchored integer-overflow panic, nonzero exit, no ordinary stdout and no
`UNEXPECTED` marker. Core dumps are disabled; crashes or unrelated errors do not
count as matched traps.

Five focused consumers cover borrowed text, inherited negative-row filling,
usize products, clipping short circuits and saturating unwrapped measurement.
The source allocator versus V GC, slice readonly types, i17 backing-field
widths, native ABI and inputs beyond V's int-sized string/array lengths remain
representation boundaries. Arbitrary Window/PrintResult construction contracts,
Window scroll/mouse/border behavior and non-native runtime targets remain
outside this matrix. Subsequent comparisons cover record contracts in
`../window_contracts/README.md`, scroll/mouse in `../window_state/README.md`, and
child borders in `../window_border/README.md`; prior Surface/delegated-Window
verification is unchanged.
