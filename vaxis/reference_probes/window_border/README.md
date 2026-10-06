# Window child borders

`../../verify_window_border_reference.py` calls the unchanged pinned public
`Window.child` method. The complete original Vaxis source tree must have SHA256
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed` before copying;
`src/Window.zig` has SHA256
`30b1e1359c4c590fe0efccbf873eda9109afd84f781572ab49dfe3a0e7da9c3a`.
The shared `widgets_classic/source_build.py` checks the locked uucode package and
builds its unchanged Unicode table generators. No dependency source body,
visibility or private method is modified.
The locked package SHA256 is
`2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380`.

Run from the repository root:

```sh
python3 vaxis/verify_window_border_reference.py /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v --workdir /tmp/witty-window-border-debug
python3 vaxis/verify_window_border_reference.py /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v --v-prod \
  --workdir /tmp/witty-window-border-prod
```

Retained directories must be new. Ordinary mode selects Source Debug; `--v-prod`
selects Source ReleaseSafe and V production unless `--zig-mode` overrides it.
The native target is `aarch64-macos.14.0` with libc, Zig 0.15.2 and pinned V 0.5.2.
The runner sets `VEXE`, disables core dumps, bounds returning and trap runs,
and retains commands, corpus, outputs, diagnostics and failure-state files.

Both Source Debug/V ordinary and Source ReleaseSafe/V production pass 19,963
returning records, sixteen strict trap pairs and sixteen separately observed
failure-state pairs with matching hashes. The corpus covers every named border
location and all sixteen custom location combinations, rounded and square built-ins,
custom ASCII and raw glyphs, empty and maximum dimensions, optional child sizes,
absolute/parent/child clipping offsets and short backing buffers where all
writes remain defined. Large dimensions include 65,535-loop boundaries with
empty or screen-clipped output. Custom strings include empty bytes, controls,
malformed UTF-8, combining marks and multi-cell text: Source takes each supplied
glyph as one cell wide without decoding it, and V preserves that behavior.

Records compare the returned width/height, all four offsets and screen identity,
plus an FNV-1a hash of every backing cell before and after caller glyph-byte
mutation. The hash includes raw grapheme bytes, width, complete equality against
the four fixture styles, hyperlink bytes, default/wrapped flags, image presence,
scale fields and pointer identity for nonempty custom glyphs. Images are absent
in these fixtures; this does not certify placement payloads or native layout.
Changing the options style after drawing also retains the cells' copied style.
Empty glyph addresses are excluded from pointer comparisons; the V fixture
supplies a live sentinel byte for its zero-length string carrier.

Sixteen isolated checked-failure pairs cover initial child dimension/absolute/
parent arithmetic, each border edge's absolute coordinates, the final interior
offsets, empty and short backing buffers, and large Screen indices beyond signed
int range. Actual panic headers must start with the expected category, the
process must fail without stdout, and actual `UNEXPECTED` lines are rejected.
Source assertion failures report `reached unreachable code`; translated checks
report `Assertion failed`. Integer arithmetic failures require `integer overflow`.

Failure-state observations are a separate fixture extension. The native root
consumer supplies `std.debug.FullPanic`: it writes the current screen hash to a
file and then delegates to unchanged `std.debug.defaultPanic`. The V consumer
registers an `at_exit` callback to write the same hash when its ordinary panic
path exits. These observers do not resume execution, suppress diagnostics or
change any original Source statement. All sixteen failure-state files must
match in addition to strict panic checks. This observes partial writes without
claiming parity of the language panic runtimes, stack traces or exit handling.
In particular, a short second row proves that the complete top edge is drawn
before the bottom edge fails, and a short later row proves that left writes
precede right writes. The previous interleaved V loops fail these state checks.

Source edges run in top, bottom, left, right order, followed by top-left,
top-right, bottom-left and bottom-right corners. Degenerate dimensions may
cause corners to replace the same cell; bottom-right is the final write when
all locations coincide. Last-row/column selection and interior dimensions use
saturating subtraction. A bordered zero-size child can still move its returned
origin by one, including a checked i17 failure at the maximum absolute offset.
The no-border arm returns before that interior adjustment. Custom glyph strings
remain borrowed from live caller storage, while cell style and other metadata
are copied into a fresh default cell value.

Five focused consumers in `vaxis/window_border_fidelity_test.v` cover borrowing
and forced width, degenerate corner order and metadata defaults, negative parent
clipping with an interior write, saturated/max-loop dimensions, and empty
location geometry. Constructor contracts are checked by their separate probe.
Allocator/GC ownership, readonly byte slices, wider i17 backing fields, lengths
beyond V's int-sized carriers, arbitrary dangling/uninitialized slices and
non-native runtimes remain representation boundaries. Window scroll/mouse,
general Screen allocation and panic-runtime behavior are outside this proof.

Returning-record SHA256 (joined records without a trailing newline):
`816665627ba1720864c64e93842e7270044f2019add2d181f3ff53f40e5d158f`.
Fixture failure-state SHA256 (ordered `label|hash` records without a trailing
newline): `98f463b314e182b3d60ac994303f0fe3900b05b7f5cbeef79f571d4da03181ed`.
