# Text public drawing and iterator payloads

`verify_vxfw_text_reference.py` compares unchanged locked Vaxis public
`Text.draw` and `Text.widget().draw` with the translation. It hashes the complete
Source `src` tree before copying it. The shared `widgets_classic/source_build.py`
also verifies and builds the locked uucode graph and generated tables, without
modifying Source files.

Run from the repository root:

```sh
python3 vaxis/verify_vxfw_text_reference.py /Users/alex/code/3rd/vaxis /path/to/zig /path/to/v
python3 vaxis/verify_vxfw_text_reference.py /Users/alex/code/3rd/vaxis /path/to/zig /path/to/v --v-prod
```

The ordinary run uses Source Debug; `--v-prod` uses V production and Source
ReleaseSafe. `--zig-mode` selects either checked Source mode explicitly.
`--timeout` bounds the returning matrix and must be positive. Deliberate traps
use a separate positive `--trap-timeout` (default 60 seconds), disable core
dumps, require an actual panic header with the
expected category, and reject ordinary stdout, successful exits, and
`UNEXPECTED` markers.

The draw matrix covers all three width methods, wrapped and unwrapped text,
all alignments, ellipsis and clipping, parent and longest-line width bases,
finite and unbounded constraints, minimum dimensions, CR/LF/CRLF, leading and
trailing whitespace, tabs, controls, malformed UTF-8, combining characters,
wide glyphs and ZWJ sequences. Every cell includes its bytes, width, style,
input-relative borrowed address and default metadata. Mutable backing bytes
are changed after drawing to prove that retained cell graphemes borrow caller
storage. Zero maximum width returns before decoding or allocating, including
otherwise trapping input and dimensions.

Isolated traps cover the parent-width assertion, checked surface area and row
counters, Unicode total width, inherited leading-tab subtraction underflow,
tab index casting and addition, and malformed Unicode consumption. The
nonwrapped container-width truncation remains intentional. An oversized
cluster can repeatedly produce empty wrapped lines without advancing; bounded
public drawing preserves this behavior, and a focused V adapter consumer
checks its repeated state.

Source publicly exports `Text.LineIterator`, `Text.SoftwrapIterator`, and its
`Line` payload, but `LineIterator.next`, `SoftwrapIterator.init`, and
`SoftwrapIterator.next` are private. The runner proves ordinary private-access
rejections and the existing public V adapter calls; it never modifies Source
or invokes those methods through a wrapper. Their behavior is compared through
public drawing. Three complete constructor pairs and five paired required-field
omission rejections cover `LineIterator.buf`, `SoftwrapIterator.ctx/hard_iter`,
and `WrappedLine.width/bytes`. Indices retain Source `usize`; V string lengths
remain bounded by `int` storage and are checked before conversion for borrowed
views. Direct invalid V adapter state has no native public-method counterpart.

Source allocation errors have no deterministic counterpart in GC-managed V
surfaces. Allocator fields, memory layout, and allocation failure parity remain
representation boundaries. Source's unused private `SoftwrapIterator.consumeCR`
and `consumeLF` reference a nonexistent `buf` field; they are neither invoked
by public drawing nor translated into speculative public APIs.

The drawing implementation keeps its local Surface on the heap, preserving
the common initializer and returned Surface value. Pinned V production otherwise
recursively scans the complete local cell array on every method call, turning
large drawing into quadratic work. The V probe likewise takes a borrowed
Surface pointer while serializing; it does not alter cells or record contents.
The matrix includes a valid 65,535-cell draw to check this boundary.

Both Source Debug/V ordinary and Source ReleaseSafe/V production pass 7,562
returning records, 15 strict trap pairs, three complete constructor pairs,
five paired omission rejections, and three private Source/public V method
boundaries. SHA-256 of the joined records (without a trailing newline):
`d6f81838ac48054b14f76b3f3d607c13ca1e3153f1fb9959902596d47f0facac`.
The complete returning matrix, including the 65,535-cell draw, takes 0.68/1.74
seconds for Source/V ordinary and 0.34/0.60 seconds for Source/V production
on the measured ARM64 host. Timing is observational, not a pass threshold.
