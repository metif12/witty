# Public Unicode and width source comparison

Run from the repository root:

```sh
python3 vaxis/verify_unicode_gwidth_reference.py /Users/alex/code/3rd/vaxis /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig /Users/alex/.cache/v/v1-fallback/0.5.2/v
python3 vaxis/verify_unicode_gwidth_reference.py /Users/alex/code/3rd/vaxis /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig /Users/alex/.cache/v/v1-fallback/0.5.2/v --v-prod
```

The runner verifies the complete pinned Vaxis `src` tree and locked uucode
package with the shared `widgets_classic/source_build.py` helper. It copies
source files unchanged, generates the locked Unicode tables with the unchanged
dependency generator, and invokes public `unicode.Grapheme`,
`unicode.GraphemeIterator.init`, `unicode.graphemeIterator`, `gwidth.gwidth`, and
`vxfw.DrawContext` methods directly. Source Debug is the ordinary default;
`--v-prod` selects Source ReleaseSafe unless `--zig-mode` explicitly overrides it.

The deterministic corpus covers all 256 one-byte and 65,536 two-byte inputs,
representative valid cluster pairs, Unicode-plane boundaries, seeded longer
valid/malformed combinations, checked-width boundaries, and arbitrary borrowed
`Grapheme.bytes` spans including zero-length spans and spans inside UTF-8
sequences. Each returning record compares all three width methods, raw span
start/length/bytes, borrowed address identity, the two iterator factories,
framework iterator and width adapters, first-grapheme byte length, and repeated
exhaustion. Large records summarize spans after checking every borrowed address.
Long seeded malformed cases prefix each raw ZWJ-delimited piece, keeping the
inherited underflow in the separate trap checks. Another 160 records mutate
caller-backed bytes after iterator creation and after the first next call;
all three public factories must preserve prefetched codepoints while decoding
later bytes from the caller, and previously returned views must observe later
mutations. Empty mutation cases use V's empty string because `tos(nil, 0)` is
rejected by V's string adapter.

Isolated traps cover the inherited `ff cc 81` replacement-character start
underflow, u16 total overflows for ASCII and wide text, overflow when summing
individually valid no-ZWJ pieces, and checked usize addition/slice bounds in
`Grapheme.bytes`. Every trap must produce an actual anchored source/V panic
header in the expected category, no ordinary stdout, no `UNEXPECTED` line, and
a nonzero exit. Core dumps are disabled. A complete Grapheme constructor and
both required-field omission rejections are compiled separately; ordinary
compiler diagnostics are required, excluding compiler panic/crash/C failures.

The V first-length function is an adapter whose reference is the source's
first public iterator span. Source slices and V strings expose the same
borrowed bytes and address relationship in this native comparison; allocator,
OOM, GC lifetime and ABI contracts are not certified. Source iterator fields
are public; V keeps decoder state opaque, marks the type `@[noinit]`, and
requires `.init(text)` or `grapheme_iterator(text)` instead of reproducing
arbitrary source state literals. Framework iterators retain their V string
return shape and lazy literal construction. The scalar sample is not an
exhaustive comparison of every Unicode scalar or every cluster sequence.

Source Debug/V ordinary and Source ReleaseSafe/V production match 72,225
records, fourteen strict traps, one
complete constructor and two paired omission rejections, SHA-256
`f7555397b8c48374500b4558a166e5701f30ad7f2b35d056a4d5c56297913f4c`.
The runner also independently retains the original 72,065-record immutable
prefix hash `a0ef6a61b659d36d44e691ba5d0bb02afb6473b4059d038768e328512a2e98e9`.
The focused test file has six passing consumers.
