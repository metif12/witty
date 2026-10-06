This proof calls the public `Cell.Color.rgbFromUint`, `rgbFromSpec`, `Color.eql`
and `Style.eql` APIs in the pinned `src/Cell.zig`. External consumers construct,
mutate and copy public Style records. The spec cases also call public
`Parser.parse` with OSC 10 input to verify the shared parsing helper. No source
method body or visibility is changed.

Run from the repository root:

```sh
python3 vaxis/verify_style_color_reference.py \
  /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /tmp/witty-style-color-debug
```

Add `--v-prod` and use a fresh work directory to compare Zig ReleaseSafe with V
production. `--timeout` sets the returning producer deadline. The runner sets
`VEXE`, disables core dumps, and retains exact compiler arguments, copied source,
generated locked uucode tables, fixture hashes, build diagnostics, case inputs,
returning streams, trap streams, compiler rejection diagnostics and measured
representation observations. The common module graph is provided by
`../widgets_classic/source_build.py`.

The source tree SHA256 is
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed`;
the locked uucode tree SHA256 is
`2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380`.
Original and copied dependency trees are checked after the comparisons, and
metadata records fixture digests, target and build modes.

Both Debug/ordinary and ReleaseSafe/production match **175,302 returning
records**, **four strict range-trap pairs** and **two direct payload-omission
rejection pairs**. Four compiler/API differences, two boxed-copy observations
and one layout observation are recorded separately. The returning SHA256,
over source records joined by a newline without a trailing newline, is
`8b7ea385d053e6b5fc140b221d6b87c7d026464bff628b613e31d49c8c61dc9c`.

Returning cases cover every channel value in `rgbFromUint`, all 256 palette
indices, bidirectional cross-tag and sampled RGB equality, all seven boolean
Style flags and all six underline styles, mutation and independent field
replacement after a Style copy, valid type aliases, and copied RGB input arrays.
Each of the 3,072 Style states tests equality with itself and its copied value,
then eleven independently changed fields, so flag/color/underline distinctions
are checked separately from the serialized state.
Spec cases cover each byte at every position in a valid spec, missing and extra
components, raw NUL/invalid UTF-8 bytes, invalid hexadecimal suffixes, ignored
high channel bytes, extra colon/slash components and mixed malformed lengths.
Source checks all three channel lengths before parsing any hexadecimal suffix;
for example `rgb:00ZZ/bad/cccc` returns `InvalidColorSpec`. The same ordering
now applies to the shared OSC color parser. The established Parser proof was
rerun in both modes without modifying its corpus: its 79,299 records and 19
strict trap pairs retain SHA256
`526ddb882d3040c927af9264ffe7ce70cfe5e33fa269ef9f224a6b3b0d2e0502`.

Source `rgbFromUint` takes `u24`. The V API uses a `u32` carrier and explicitly
traps above `0xffffff`, including under `-prod`. The paired traps compare the
source caller's checked runtime `u32` to `u24` cast with this V guard; the source
method cannot itself receive an out-of-range `u24`. Values `0x1000000`,
`0x1000001`, `0x80000000` and `0xffffffff` require a nonzero exit, empty stdout
and `integer does not fit in destination type` on the complete native
`thread N panic:` or V `V panic:` header. Actual line-start `UNEXPECTED`
markers are rejected. Ordinary compiler rejections exclude crashes, compiler
bug diagnostics and generated-C/backend failures.

The measured API and representation limits are:

- Source rejects an out-of-range integer literal and an implicit `u32` argument
  at compile time. V accepts the wider carrier and applies the runtime guard
  to representable `u32` inputs. The pinned V compiler can warn and narrow
  literals outside `u32` before the function's guard executes. The certified
  range checks require explicit, representable typed inputs; oversized literal
  coercion is a compiler capability limit, not a Source-parity claim.
- Source rejects omitted index/RGB payloads. The direct V payload records now
  require these fields, while the pinned V compiler still accepts an empty
  alias of `ColorRgb` because it drops inherited required markers.
- Source permits direct mutable union payload access and retains independent
  by-value Color payload copies. V Color payload fields remain read-only.
  Replacing a Style color field preserves copy independence, but explicit
  unsafe mutation of a boxed RGB payload changes both V copies. The separate
  observation records this for Color and for a Style containing Color; it is
  not a safe-mutation parity claim.
- On the tested ARM64 macOS target, Color size/alignment is 4/1 in Source and
  16/8 in V; Style is 20/1 in Source and 56/8 in V. Underline names and enum
  ordinals map to V's `double_` spelling and `u8` enum carrier. Native union,
  packed-bit, enum and record layout parity is excluded.

The proof covers explicitly initialized, valid tags and payloads. Source
undefined bytes, invalid unsafe union tags, allocator failure/ownership and
arbitrary alias/compiler lowering are outside the returning comparison. The
V fixture serializes a parsed fixed RGB array directly instead of constructing
an inline record from an event's array field, avoiding a pinned V generated-C
failure; this is fixture serialization and does not alter either implementation.
