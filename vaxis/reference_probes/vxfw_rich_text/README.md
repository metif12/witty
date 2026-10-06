# RichText reference comparison

`verify_rich_text_reference.py` compiles the unchanged pinned Vaxis source and
compares the public `RichText.draw` and type-erased `widget().draw` paths. It hashes
the complete source tree before copying it; no source wrappers, visibility changes,
or dependency-body edits are used. The common `widgets_classic/source_build.py`
graph also verifies locked uucode before generating its Unicode tables.

Pinned source tree SHA256:
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed`.
Locked uucode SHA256:
`2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380`.

Reproduce on the native macOS host from the repository root:

```sh
python3 vaxis/verify_rich_text_reference.py \
  /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /tmp/witty-rich-text-debug

python3 vaxis/verify_rich_text_reference.py \
  /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --v-prod --workdir /tmp/witty-rich-text-prod
```

Retained build directories must be new. `--v-prod` selects Zig ReleaseSafe and V
production; ordinary mode selects Zig Debug. The runner pins `VEXE`, uses native
`aarch64-macos.14.0`, disables core dumps, and records commands, inputs, outputs,
trap diagnostics, and compiler-boundary diagnostics. `--timeout` controls the
returning-run resource deadline. `--contracts-only --workdir EXISTING` repeats the
constructor and privacy checks using the retained, hash-verified source graph.

The final corpus has 22,366 returning records. It exhausts strings up to five bytes
over `a`, space, tab, and LF; exercises three width methods, three alignments, both
overflow modes, both wrapping modes, bounded/unbounded widths and heights,
minimum constraints, base styles, span styles and links, multiple spans, empty
spans, combining characters, emoji, controls, malformed UTF-8, and 65,535-cell
boundaries. Every cell is serialized with raw grapheme bytes, width, complete-style
identity, link bytes, default/wrapped/image state, and default scale. Widget/cursor/
children state and surface dimensions are compared too. Borrow cases mutate caller
text bytes and span styles after drawing, proving borrowed grapheme bytes and
copied style values.

The returning-record SHA256, excluding the final output newline, is
`82d672df1b109891fa701681f003009fc56e1d28acfc32cfe27c946502342b48`.
Both Debug/V ordinary and ReleaseSafe/V production pass with this hash and all
the separate checks below. The final returning runs took 2.46/4.08 seconds for
Source/V ordinary and 0.94/1.77 seconds for Source/V production on this host.
Separate gates check:

- Eleven strict trap pairs: parent-width assertion; two CR underflows; CR slice
  range; unbounded line-width overflow; clipped column overflow; row overflow;
  row overflow from a nonadvancing wide glyph; Surface area overflow; an oversized
  no-ZWJ grapheme's u8 cast; and malformed-byte/Extend Unicode underflow. Panic
  categories are checked individually; returning errors and `UNEXPECTED` lines
  on either output stream cannot count as checked traps.
- Seven paired required-field omissions: base Segment text, RichText text,
  RichWrappedLine width/cells, and iterator context/text/line.
- Four complete constructors: TextSpan, RichText, RichWrappedLine, and iterator.
  Line and iterator consumers prove borrowed cell arrays; iterator cursors accept
  native usize maximum values without truncation.
- Four Source-private/V-public method adaptations: Source `init`, `reset`,
  `nextHardBreak`, and `next` ordinarily reject external calls while the respective
  V `new`, `reset`, `next_hard_break`, and `next` consumers compile and run.
- Two measured constructor adaptations: omitted Source arena versus V GC ownership,
  and Source-required TextSpan text versus pinned V's alias-required limitation.
  Direct V `CellSegment{}` rejects; `TextSpan{}` still accepts an empty string because
  the compiler ignores the inherited required marker through that alias. The alias
  remains compatible with shared CellSegment input values.
- Eight Source-only allocator observations: failure indices 0 and 1 return
  `OutOfMemory`, and indices 2 through 7 return a 1×3 surface. V GC has no matching
  supplied-allocator failure interface.

The seven consumers in `vaxis/vxfw/rich_text_fidelity_test.v` also exercise iterator
reset and borrowed line state, tab expansion, CRLF grapheme handling, bounded
nonadvancing wide-glyph output, input-byte borrowing, ellipsis style/link behavior,
full base style, width-zero early return, and public usize payload fields.

Source behaviors retained deliberately:

- A CRLF inside one span is one grapheme, so the cell-based hard iterator does not
  recognize it as its separate `"\r"` or `"\n"` cases. A standalone CR can underflow
  or produce an invalid slice. These failures are isolated rather than repaired.
- A glyph wider than the bounded wrap width can produce an empty line without
  advancing the soft cursor. A bounded height yields empty rows; an unbounded
  height eventually overflows the u16 row count. The proof does not normalize this
  to clipping or silently advance the iterator.
- Hard-line widths saturate, while soft-line widths, drawing columns, rows, casts,
  and usize cursor arithmetic retain their checked source operations. Width-zero
  drawing returns the minimum-size empty surface before parsing or parent checks.
- Ellipsis retains the replaced cell's style and has an empty link. Remaining
  blank cells retain the complete base style.

V storage and API boundaries:

- The source allocator/arena is GC-owned in V. Drawing uses private heap shells for
  the iterator, Surface, and borrowed line headers; public payloads and borrowed
  array/string data remain unchanged. Generated production C otherwise recursively
  enumerated complete cell arrays for every `write_cell`, causing quadratic
  keepalive work. The borrowed V probe serializer similarly avoids recursive
  per-cell scans. After the storage adaptation, all sixteen large production cases
  return and match in 1.43 seconds on the measured host; the old value-storage
  producer timed out after 240 seconds at the first long clipped case.
- Source iterator methods, including deinit and its private helpers, are not public
  runtime APIs. Native behavioral comparison reaches their bodies only through
  public draw. The V iterator methods are convenience adapters; their additional
  direct-call tests are separately identified above. Deinit is covered by GC
  ownership rather than a Source-public method claim.
- Iterator indices use usize; V array/string lengths remain limited by the pinned
  compiler's int-sized carriers. Oversized/uninitialized or dangling source slices
  and allocator-memory corruption are excluded. Mutable V arrays represent the
  source's borrowed const cell views; the backing-storage borrowing is measured.
- The comparison is native macOS. Cross-platform compile/link gates do not establish
  equivalent allocator or Unicode runtime behavior on other hosts.
