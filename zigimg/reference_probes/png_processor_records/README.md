# PNG processor record contracts

`verify_png_processor_records_reference.py` imports the unchanged PNG reader from
zigimg revision `d7b7ab0ba0899643831ef042bd73289510b39906`. It checks the entire
`src` tree before copying it and again after the proof. The pinned tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Zig 0.15.2 and the selected `std.mem`/`std.debug` sources are pinned too. The runner
retains compiler versions, exact commands/environment, fixture and implementation
hashes, and every build/consumer stdout and stderr in a supplied work directory.
It does not modify Source bodies or visibility. Source's private VTable and
transparency union types are inferred from their public record fields.

Run from the repository root with local paths:

```sh
python3 zigimg/verify_png_processor_records_reference.py SOURCE ZIG V --workdir /tmp/png-records-debug
python3 zigimg/verify_png_processor_records_reference.py SOURCE ZIG V --v-prod --workdir /tmp/png-records-production
```

Ordinary V is compared with Source Debug; `--v-prod` selects Source ReleaseSafe.
Both modes compare 199 returning records with SHA-256
`75975f75febf19e8a3a7085652494075707bef6323eba6455002c39998da2c32`.
These cover all eight callback-presence combinations, success and returned errors,
four byte values, mutations before error returns, copied record values, borrowed
stream/header/context/VTable references, palette and row byte views, default
callback returns, caller-owned VTable replacement, options-array borrowing,
`get()` refresh, and copied options whose callback contexts still address the
original owner's processor. Pointer identity is recorded as booleans, never as
process-dependent addresses.

The constructor proof checks 14 complete/default constructor pairs and the 22
represented required fields below. Nineteen paired omissions fail with ordinary
Source and V diagnostics. The three generic fields have markers, but pinned V
accepts their omission; these are measured compiler adaptations. The existing
`PngDefaultOptions` alias likewise accepts omission of `processor`, where Source
rejects it. Two paired immutable-variable mutation rejections and two measured
const-pointee adaptations are checked separately. Rejection checks require a
positive failed exit, an actual error line with the expected diagnostic, and no
compiler panic, backend failure or crash.

| V record | Source-required represented fields |
| --- | --- |
| `PngChunkProcessData` | `read_stream`, `chunk_id`, `chunk_length`, `current_format`, `header` |
| `PngPaletteProcessData` | `palette` |
| `PngRowProcessData` | `dest_row`, `src_format`, `dest_format`, `header` |
| `PngReaderProcessor` | `id`, `context`, `vtable` |
| `PngReaderProcessorVTable` | `chunk_processor`, `palette_processor`, `data_row_processor` (explicit `none` is valid) |
| `PngTrnsGray`, `PngTrnsRGB`, `PngTrnsIndexAlpha` | `value`, `color`, `data`, respectively |
| `PngCustomReaderOptions1[P]` | `processor` (generic marker limitation) |
| `PngCustomReaderOptions2[P,Q]` | `processor1`, `processor2` (generic marker limitation) |

Source's transparency union stores value payloads inline. V stores sum-type
payloads in boxes: directly changing a copied gray/RGB arm or an indexed arm's
slice header also changes the other copied record. `boxed.zig` and `boxed.v`
measure 12 such records separately; all 12 differ and are excluded from the 199
equivalence records. Their respective SHA-256 values are
`1ed0619962c4a745aa5c91bf340171ab52b454383daed56cf4c71ca11e407498` and
`e396b5a8aec0e3d4362120be0d7127180cb55f1eb939a398a1916565c04ec456`.
Whole-arm replacement outside a narrowed `match mut` preserves independent record
copies; mutating the indexed buffer's bytes remains borrowed on both sides. The
payload fields stay public mutable, as the Source fields are.

Allocator fields/arguments and `getWithTempAllocator` are represented by V GC
storage and allocator-free `get`; supplied allocator failure/lifetime behavior
is outside this adapter. The Source root `DefaultPngOptions` compile-time override
is represented by the fixed `PngDefaultOptions` alias. Source undefined PLTE
palette and custom option slot defaults become empty/zero managed V storage;
the matrix observes no Source undefined palette or pre-`get` slots. Defined
defaults (empty reader processor list, unset transparency, false flags) match.
V erased runtime callback signatures replace Source's typed, compile-time
callback generation. V accepts mutable access through the header and VTable
pointers; Source declares those pointees const. The runner demonstrates both
differences without counting them as equivalence. No native packed ABI or
arbitrary allocator compatibility is claimed.
