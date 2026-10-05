# Surface/SubSurface source comparison

```sh
python3 vaxis/verify_vxfw_surface_reference.py /Users/alex/code/3rd/vaxis /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig /Users/alex/.cache/v/v1-fallback/0.5.2/v
python3 vaxis/verify_vxfw_surface_reference.py /Users/alex/code/3rd/vaxis /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig /Users/alex/.cache/v/v1-fallback/0.5.2/v --v-prod
```

The runner hashes the complete pinned Vaxis source and locked uucode package,
copies them unchanged, and uses the dependency's unchanged table generator.
It directly exercises public Surface/SubSurface methods and the Window methods
those methods delegate to: child, writeCell, readCell, showCursor and
setCursorShape. Source Debug is the ordinary default; `--v-prod` chooses Source
ReleaseSafe unless `--zig-mode` overrides it. No source-private wrapper or
source edits are used.

Returning records cover zero/small/65,535-cell buffers, initialization/default
flags, writes and reads, early clipping, arbitrary source-valid signed
coordinates, borrowed trimmed buffers/child lists, cursor reset on trim,
strict constraint comparisons, three overlapping child surfaces, stable z-order
mutation, pre/post-render hit routing, focused cursor visibility/shape, and
delegated Window offsets/dimensions/parent clipping. Cell records include raw
grapheme bytes, width, default/wrapped flags, foreground color and bold style;
they do not exhaust every Cell style/image/link combination. Largest buffers
are summarized after checking every initial default flag.

Isolated subprocesses check u16 multiplication and addition separately,
source assertions, borrowed-slice bounds, i17 containment endpoints, child
max-size/absolute/parent arithmetic, cursor arithmetic before dimension checks,
and read/write offset arithmetic after dimension checks. Panic classification
requires an actual anchored source/V header in the expected category, nonzero
exit, no ordinary stdout and no `UNEXPECTED` line. Source `std.debug.assert`
uses `reached unreachable code`; the V guard explicitly uses `Assertion failed`.
These checked traps retain their differing diagnostic wording. Core dumps are
disabled. Source overflow behavior is preserved, including bounds that can
trap before a later clamp or clipping return.

GC arrays replace source allocator/arena arguments and allocation failures;
allocator/OOM/GC lifetime/ABI parity is not asserted. Source i17 fields use
wider V backing fields with checked operations. Direct arbitrary V state beyond
source field widths and every Window method (including fill/print), framework
widget body, or Surface-tree arrangement are not certified by this matrix.

Source Debug/V ordinary and Source ReleaseSafe/V production match 11,162
returning records and 28 strict traps,
SHA-256 `852eb3f3eae04a383dd8af7fc2055971d9fc1bd1f49760135457cc4d5c6bc265`.
All four focused consumer functions pass.
