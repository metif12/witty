# Window scroll and mouse reference comparison

The runner hashes and copies the complete pinned Vaxis source and locked uucode
graph unchanged, using `widgets_classic/source_build.py`. It calls public
`Window.scroll` and `Window.hasMouse`; no dependency bodies or visibilities are
changed. Native target is `aarch64-macos.14.0` with Zig 0.15.2 and V 0.5.2 fallback.

```sh
python3 vaxis/verify_window_state_reference.py /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v --workdir /tmp/witty-window-state-debug
python3 vaxis/verify_window_state_reference.py /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v --v-prod --workdir /tmp/witty-window-state-prod
```

Retained build directories must be new. Ordinary V uses Source Debug;
`--v-prod` selects V production and Source ReleaseSafe. Core dumps are disabled.

Both ordinary/Debug and production/ReleaseSafe comparisons pass 170,387
returning records and sixteen strict trap pairs. Output
SHA-256, joined without a final newline:
`a10c9f8d70ece1a016a387f25c12c11bf2840224afc3e2e8e839fcb0523985f9`.

Scroll covers zero and over-height counts, empty sizes, negative/positive offsets,
parent clipping state, short backing buffers, windows wider than the Screen where
nonoverlap copying is defined, high dimensions without large buffers, and four
valid 65,025–65,535-cell cases. Cell observations include raw grapheme bytes,
width, indexed foreground, bold, links, default/wrapped state, empty-image and
default-scale flags, and offsets into caller text. Subsequent caller-byte mutation
checks that copied cells retain borrowed grapheme storage. Cursor state is retained.

The source starts at the absolute clamped y offset but stops copying at the
window's height minus the scroll count. It does not normalize this range to the
window's origin. Copying and final clearing ignore parent clipping fields. A
count greater than height returns before geometry, copying or clearing. The
translation preserves all these behaviors. Copy indices and endpoints are u16,
even though the delegated Screen cell methods use usize. All destination/source
arithmetic precedes slice checks, followed by the copy and final child/clear.

Trap pairs cover destination/source multiplication, starts and ends, both short
slice checks, child/parent endpoint sums, clearing endpoint sums and mouse endpoint
sums. Nonempty equal and overlapping ranges trigger the inherited `@memcpy
arguments alias` panic, including zero-count scrolling that enters the copy loop.
Empty copies remain valid. Bounds diagnostics use anchored `index out of bounds`
headers; integer and alias traps have separate exact categories. Successful exits,
ordinary stdout, `UNEXPECTED` markers or unrelated crashes cannot count as traps.

Mouse cases check nullable input, all chosen button/type values, raw col/row and
pixel offsets, negative/zero/max geometry, ignored parent clipping and the four
source Boolean short circuits. Mouse modifiers are zero in this matrix. The
returned event retains its original coordinates and payload; no coordinate
normalization or Screen access occurs. Six focused V consumers separately cover
copy/clear quirks, borrowed storage, value snapshots and safe short circuits.

The V fixture stores its input-line table in a private heap holder and observes
each case in a separate function. Otherwise pinned V production enumerates the
entire input array during each output call, making the comparison quadratic in
the number of input records. This fixture storage adaptation does not change
Window behavior or output records. The product methods retain their public API.

Allocator/GC failures, arbitrary image/Style combinations, nonzero mouse
modifiers, pointer/aggregate ABI, source i17 fields represented by V int and
lengths beyond V's int-sized strings/arrays remain outside this proof. Wider V
initializers and Window construction contracts are measured separately in
`../window_contracts/README.md`. Cross builds establish compilation/link success,
not non-native runtime parity.
