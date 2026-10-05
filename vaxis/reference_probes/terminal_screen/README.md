# Classic terminal screen source comparison

This compares `widgets/terminal/Screen.zig` through the unchanged local Vaxis
source with the flattened V APIs in `widget_terminal_screen.v`. It exercises the
screen independently of Terminal's Linux-only PTY initializer. It does not claim
verification of a running PTY or the private Terminal event loop.

The comparison checks the full source tree before copying it into an isolated
build directory:

- Vaxis `src` tree SHA256:
  `bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed`.
- Locked uucode commit: `5f05f8f83a75caea201f12cc8ea32a2d82ea9732`.
- Locked uucode package tree SHA256:
  `2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380`.

`../widgets_classic/source_build.py` reproduces the original uucode build
configuration and Unicode table graph. Original source files are not patched.
The runtime native target defaults to `aarch64-macos.14.0`; the source probe uses
the C allocator to avoid page-sized allocations for tiny fixture cell strings.

From the repository root:

```sh
python3 vaxis/verify_terminal_screen_reference.py \
  /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v --timeout 240

python3 vaxis/verify_terminal_screen_reference.py \
  /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --v-prod --zig-mode ReleaseSafe --timeout 600
```

The deterministic matrix has 6,414 returning records. It covers every public
Screen operation, all SGR byte values and selected parameter/subparameter forms,
scrolling regions, cursor values inside and outside regions, dirty copying,
cell copying and erasing, region/cursor queries, read-cell boundaries and screen
sizes through 65,535 cells. Records include dimensions, region, cursor and CSI
flags, plus cell text, style, URI, width, wrapped and dirty state. The output
SHA256 is:

`9700325e0d87d1893e34375f5d8951eb5eadd2c469734b9cce078c52f7e183a4`.

Both the ordinary V/native Debug comparison and the V production/native
ReleaseSafe comparison pass with this hash. Eight focused V consumers cover
printing, wrap metadata, deletion, dirty copying, self-copy, scrolling, read
boundaries and required-region literals.

Fourteen isolated cases require source traps for checked integer operations,
zero dimensions, buffer/assertion bounds, invalid underline enum values, CSI
numeric overflow and aliased nonempty `copyTo`. The native probe and V probe
must both terminate with the expected category in an actual native `panic:` or
`V panic:` diagnostic header. A matching source/backtrace literal alone cannot
pass; ordinary stdout and `UNEXPECTED` lines in either stream are rejected. Core
dumps are disabled.
The inherited `insertLine` loop with zero adjusted count and top row zero is
checked separately with a one-second deadline. A returning-matrix deadline
raises an error and never counts as a match. `--timeout` must be positive and
applies per returning batch, defaulting to 60 seconds or 180 with `--v-prod`.
Progress messages identify the regular batch and each large case. The V probe
borrows its Screen during serialization so optimized GC root tracking does not
scan the entire cell buffer for each formatting write.

Two complete constructor consumers and five paired ordinary compiler rejections
check the required fields: all four `ScrollingRegion` coordinates and
`Screen.scrolling_region`. Source allocator omission is not compared. Compiler
panics, compiler bugs, segmentation faults and generated C failures do not count
as ordinary rejections.

The source's existing behaviors are retained: `readCell` accepts `col == width`
and can read the next row; `deleteCharacters` indexes the first row regardless
of cursor row; `copyTo` clears source dirty flags before destination bounds/copy
and leaves destination URI, URI ID, wrapped and dirty fields unchanged;
`Cell.copyFrom` called with the same cell clears its strings before reading them.
The self-copy results were measured in both native Debug and ReleaseSafe builds.
The source scrollback TODO in `index` remains inherited.

## V representation

The public types are `TerminalScreen`, `TerminalScreenCell`,
`TerminalScreenCursor` and `TerminalScrollingRegion`. `Screen.init(allocator,w,h)`
is `TerminalScreen.new(w,h)!`; allocator arguments are omitted under V GC.
Methods use snake case, and `copy_from` borrows the source cell to retain actual
receiver/source alias behavior. For example:

```v
mut screen := vaxis.TerminalScreen.new(80, 24)!
screen.sgr(vaxis.TerminalCsi{params: '1;31'.bytes(), final: `m`})
screen.print('a', 1, true)!
```

Per-cell ArrayLists become GC-owned strings, so allocator failures and retained
capacities are outside the comparison. Default cursor URI and URI ID become
empty strings rather than Zig's undefined ArrayLists; native fixtures initialize
those fields before reading them. V `deinit` releases its buffer reference rather
than leaving freed source slices accessible. The V array-capacity limit is signed
`int` (2,147,483,647 cells), while the source allocation length is `usize`; the V
constructor checks that capacity before narrowing. The source's zero-dimension
and narrow counter traps remain explicit in production builds. The comparison
uses a 64-bit host for native `usize` state and boundary fixtures.
