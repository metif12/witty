# Classic View, LineNumbers, and TextView comparison

These implementations retain the runnable public APIs in the unchanged local
vaxis `src/widgets/View.zig`, `LineNumbers.zig`, and `TextView.zig`, plus CodeView's
runnable default configuration and input handling. Nested names follow this
repository's flattened convention:

| Zig declaration | V declaration |
| --- | --- |
| `View.Config`, `DrawOptions`, `RenderConfig` | `ViewConfig`, `ViewDrawOptions`, `ViewRenderConfig` |
| `View.RenderConfig.Extent` | `ViewExtentFit` / `ViewExtentMax{value: ...}` |
| `TextView.Buffer` | `TextViewBuffer` |
| `TextView.Buffer.Content`, `Style` | `TextViewBufferContent`, `TextViewBufferStyle` |
| Buffer's grapheme records | `TextViewGrapheme{len: ..., offset: ...}` |
| `TextView.BufferWriter` | `TextViewBufferWriter` |
| `CodeView.DrawOptions`, `Buffer` | `CodeViewDrawOptions`, `CodeViewBuffer` |

All public View methods are translated, including direct drawing, bounded
`to_win`, retained cells, clear/fill, width calculation, and both print methods.
View drawing copies directly into the backing screen; it retains checked i17
row arithmetic, negative-coordinate casts, slice bounds, and overlapping
`@memcpy` traps. It does not apply Window's write clipping. Clearing marks every
cell `default_ = true`. The allocator argument is replaced by the existing
GC-backed Screen allocation convention.

LineNumbers preserves the exclusive `num_lines` endpoint, saturation and
checked ascending ranges, reversed digit extraction, highlight fill order, and
the source's zero-digit result for values at or above 100,000,000. TextView
preserves byte-indexed style lookup, style deduplication, scrolling and clipping,
zero-width cells, and the source's newline-row count. V uses `map[u64]usize` for
byte offsets because the pinned compiler does not support `usize` map keys.
The comparison runs natively with 64-bit `usize`; 32-bit `usize` values also fit
these keys.
The borrowed writer adapters retain their original buffer pointer; allocator
and standard GenericWriter context wrappers are folded into that adapter.

Four source public method paths cannot compile unchanged with Zig 0.15.2, and
remain unavailable in V:

- TextView `Buffer.append`, `Buffer.update`, and `BufferWriter.write` reach line
  88, where an `error!u3` UTF-8 sequence length cannot be coerced in a `usize`
  subtraction. Adapter construction itself is runnable and translated.
- CodeView `draw` passes `pad_left: usize` to `ChildOptions.width: ?u16` at line
  42; disabling line numbers at runtime does not avoid this compilation error.

The probe checks each source and V compilation rejection. TextView drawing is
compared using populated content/grapheme records and source public styling
methods, without patching append or inventing a replacement segmentation path.
Buffer deinitialization uses the existing GC adaptation; `clear` resets its
state. Source `clearStyle` destroys its unmanaged collections without resetting
them, so source reuse afterward is undefined. V empties its GC collections; the
comparison does not claim fidelity for undefined source reuse after destruction.

The returning matrix compares drawn cells, every style component, hyperlinks,
image IDs and packed scale fields, View render origins, all width/print modes,
LineNumbers digit boundaries, TextView buffer/style state, Unicode clusters and
scroll input, and borrowed adapter pointers. Isolated traps cover checked i17
source/destination products, negative destinations, copy bounds, overlapping
arrays (including shifted slices), zero-sized bounded rendering, range/order
checks, digit-power overflow, invalid buffer metadata, and oversized cell width.
The same checks run with `--v-prod`; explicit source arithmetic/bounds guards
survive optimization.

Both ordinary and production V builds match 18,307 returning cases, 17
checked traps and four ordinary compiler rejections, SHA-256
`8f1e7d605790217fc5d8426f487cced18a5998d945da9ec50b92ed57c8b6750e`.

The original vaxis src hash is
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed`.
The exact locked uucode commit is `5f05f8f83a75caea201f12cc8ea32a2d82ea9732`,
with Zig package hash
`uucode-0.1.0-ZZjBPj96QADXyt5sqwBJUnhaDYs_qBeeKijZvlRa0eqM` and complete
extracted tree SHA256
`2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380`.
Both SHA-256 tree digests use sorted relative paths, NUL separators, and
unchanged file bytes.
The utility `source_build.py` copies the dependency and executes its unchanged
table generator with vaxis' locked field configuration. The direct module graph
matches dependency `build.zig` and avoids Zig's native build runner selecting a
macOS version newer than its bundled libSystem stub.

Run on a 64-bit host from the repository root:

```sh
python3 vaxis/verify_widgets_classic_reference.py /path/to/vaxis /path/to/zig /path/to/v
```

Use `--uucode /path/to/extracted/locked/package` if it is not in the default Zig
cache, and `--v-prod` to check optimized V. The target defaults to native macOS
ARM64 version 14.0, consistently with the other source comparisons.

The Scrollbar, View/config, TextInput/buffer, TextView content/style/grapheme/
writer, ScrollView content-size/bounding-box and vxfw TextField inputs retain
their required fields. Run
`python3 vaxis/verify_widget_contracts_reference.py /path/to/vaxis /path/to/zig /path/to/v`
to check twelve complete constructors and twenty-three paired omission errors
against the unchanged source. The runner rejects compiler crashes and generated-C
failures. Flattened V sum-type payload wrappers remain representation adapters.

The private source Grapheme type is inferred from the public TextView buffer's
`grapheme.get(0)` return type; its original declaration remains unchanged. Source
View, TextInput buffer and TextView writer allocators are always supplied in the
fixtures and excluded from omission comparisons because V manages their storage.
TextView writer checks require the borrowed buffer explicitly without calling the
source writer methods that already fail compilation on Zig 0.15.2.
