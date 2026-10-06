# Public Vaxis session comparison

Run from the repository root:

```sh
python3 vaxis/verify_session_reference.py /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v
python3 vaxis/verify_session_reference.py /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v --v-prod
```

The native fixture calls the unchanged public `Vaxis.setTerminalWorkingDirectory`,
`translateMouse`, `render`, and `prettyPrint` methods. Source bodies and visibility
are not changed. `--v-prod` pairs V production with native ReleaseSafe; ordinary
V uses native Debug. The native target defaults to `aarch64-macos.14.0` with libc.
`--timeout` is a positive build/run deadline, default 180 seconds.

The runner verifies the complete pinned `src` tree SHA256
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed` and the locked
uucode package SHA256
`2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380` before compiling.
It uses `widgets_classic/source_build.py` to copy the exact dependency and generate
its original tables. After all checks it verifies that both original and copied
trees and all executable fixture/runner files remain unchanged.

Both modes compare 16,088 returning records:

| Public method | Records | Covered behavior |
| --- | ---: | --- |
| Working-directory report | 2,383 | All 256 raw path bytes; every non-NUL hostname byte; absent and empty host; IPv6 brackets; percent, reserved characters, UTF-8 and invalid bytes; embedded path NUL; long paths; invalid absolute paths |
| Pixel-mouse translation | 4,619 | Zero geometry early return; zero cell-pixel geometry; all 12 button values, four event types and eight modifier masks; u16 geometry and coordinates; retained nonpixel offsets |
| Render | 4,671 | Three frames per record; refresh, cached equality, skipped/default cells, wrapping, style/color/link deltas, images, scaled and explicit widths, all nine mouse shapes and seven cursor shapes, hidden/visible and primary/alternate cursors |
| Pretty-print | 4,415 | Three frames per record; default and wide-cell skips; primary cursor motion and wrapping; styles, links and images; `NotInPrimaryScreen`; retained skipped flags |

Render and pretty-print records compare emitted bytes and retained state after
each frame. The state includes refresh, session cursor, retained dimensions and
cursor/mouse shape, width method and SGR mode, and a digest of every retained
cell's character, URI, URI ID, style, default/skip flags and packed scale. The
third frame changes the first cell's text, width, bold style, scale and image.
Returning boundaries include 65,535 cells in both methods and 65,536 cells in
render; pretty-print intentionally retains the Source u16 counter limit.

Twelve isolated pairs require an actual anchored panic header of the expected
category, a nonzero exit, empty stdout, and no unexpected-return marker. They
cover pixel-offset assertions in source order, front-buffer size and retained
buffer size assertions, alternate cursor row/column overflow, pretty-print's
u16 index overflow, renderer column overflow, unknown scaled width, u8 scaled
footprint overflow, scaled footprint bounds and zero scale denominator. Native
`FullPanic` and V `at_exit` fixture hooks additionally compare public retained
state at every panic. The hooks observe state and delegate to the normal panic;
they do not change Source methods. Core dumps are disabled for deliberate traps.

Expected output SHA256 is
`23bf5bd5b3a2cd33d463591ab4fea0fa798b2427f8bb0502d6b14ab9ef18eb1d`.
The ordered twelve-panic state SHA256 is
`bdd32c1eb11f17c697dfae72d1cb5ce0c0cfffe8edcb0147572fec3adcde4780`.

`--build-dir /tmp/fresh-directory` retains exact command argv and working
directories, the complete selected child environment, build/run/trap stdout and
stderr, panic state files, corpus, copied sources and generated tables, binaries,
and mode/hash/result metadata. The directory must not exist. Build children use
only recorded PATH, HOME, TMPDIR, SDKROOT, deployment target and locale variables
when present, plus the pinned VEXE and disabled C-error bug reporting. Unrelated
environment variables are not inherited or retained. The fixture controls
HOSTNAME for each URI case; environment values cannot contain NUL. Native URI
coverage is POSIX; the Windows branch uses the explicit Source localhost host
and is covered by compilation and the focused V consumer, not native execution.

The V adapter returns a managed string where Source writes through an arbitrary
`std.Io.Writer`. This proof uses successful `Writer.Allocating` operations, and
does not establish failing-writer, supplied-allocator failure, partial-output,
flush or caller-buffer lifetime parity. A Source writer error can execute loop
defers and return after only part of the output/state changes; V builds its
complete output and state before a caller writes the result. Existing color
setter and color-scheme subscription flags likewise commit after successful
Source flush, while the V sequence APIs commit during construction. Those
methods are outside this four-method matrix.

The V fixture heap-owns the session value to avoid the pinned compiler's
recursive GC keepalive cost for large value aggregates. It constructs options
and the initial value separately before the heap spread because a spread of a
direct generic function call has a pinned V C-codegen defect. V's existing
byte-backed MouseModifiers carrier has private constructors; the fixture uses a
typed byte view for its three bits and then passes it through public methods.
Style changes use a replacement V value because the Source fields are mutable
and V's public Style fields are read-only. These fixture adaptations do not add
public wrappers or modify library behavior. Native usize indexing is preserved
within V arrays' int-sized length/storage limit; this proof runs on 64-bit ARM.
