# Checked pixel views and live iterators

`verify_pixel_views_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary V,
and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_pixel_views_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default runtime target
is `aarch64-macos.14.0`. `--timeout` bounds individual commands; `VTMP` can select
V compiler temporaries. Artifacts retain binaries, every command and output,
panic snapshots, constructor diagnostics, provenance and a JSON summary.

`PixelStorage.slice` now checks reversed ranges before the end bound, using the
original usize values before conversion to V's int indices. Its invalid variant
ignores both bounds, as in Source. Successful slices retain shared elements and
indexed palettes. The iterator checks its captured end before accessing storage,
then checks the live data length before narrowing its cursor, and checks the
indexed palette bound before converting a color. Failures leave the cursor
unchanged. Successful calls increment it once. Invalid storage with a manually
extended end yields opaque black; even its final representable usize cursor is
preserved. Iterator initialization borrows the storage address and captures only
its initial length, so later changes to its variant or elements remain visible.

| Returning observations | Count |
|---|---:|
| Slice ranges, shared byte mutation, palette/pixel identity and color bits | 15,840 |
| Independent copied cursors borrowing the same storage | 864 |
| All initial/replacement variants with captured lengths and live pointers | 1,152 |
| Exhaustion before data access, including wide public cursors | 144 |
| Invalid storage ignoring ordinary and wide slice bounds | 25 |
| Default iterator exhaustion and final wide invalid cursor | 3 |
| **Total** | **18,028** |

Returning SHA-256:
`3fc36e2d20b78dd224bb160ad63b2c89a4c60203be140cab6bdb8d8173690f99`.

The slice matrix covers all 24 tags, pixel counts 0..8, four initialized byte
patterns and every ordered range through each requested count. Narrow grayscale
and packed RGB555/BGR555 carriers are initialized within Source's bit widths.
Indexed cases initialize their full pixel bytes and active palettes, using valid
indices. Mutation through a view is observed in the original, then restored.
Raw float32 data includes signed zero, finite out-of-range values, infinities,
quiet/signaling NaN payloads; iterator output is compared as exact native bytes.
Borrow identities use integer addresses because V reference equality can compare
pointed-to values instead, including NaNs. Undefined empty allocation/byte-view
pointers are excluded; empty slices of a nonempty allocation retain a defined
borrowed pointer. Live replacement tests keep the storage address and captured
end while replacing every initial variant with every other variant.

| Strict panic/state pairs | Count |
|---|---:|
| Reversed/end bounds for all 23 data variants and lengths 0/1/4 | 621 |
| Data indices at/beyond lengths and beyond the int carrier | 345 |
| Replacement with shorter live storage | 46 |
| Indexed palette lookup after active palette shrink | 27 |
| **Total** | **1,039** |

Failure-state SHA-256:
`e486145175e57fc2962952fea09e5292f443be38d460a45c5b0ccf8475dae528`.

Slice controls include simultaneously reversed and excessive ends, values above
2^31/2^32, and maximum usize. Iterator controls include those wide indices and
maximum usize minus one, with a larger captured end. Strict panic checks verify
the complete Source index/length or start/end diagnostic prefix. Observers compare
the live variant, pixel count, initialized pixel/palette bytes and iterator cursor/
end. No failed conversion advances the cursor. Replacement observers inspect only
the new allocation, excluding freed storage. Defaults with an undefined Source
pointer are used only on exhausted paths that do not access that field.

Two compile acceptance pairs check default initialization and borrowing immutable
storage through `init`. Four rejection pairs check immutable `next` and public
field mutations. A separate constructor pair records Source's const-pointer field:
a direct Source record can borrow immutable storage, while V's mutable-reference
field rejects that initializer. The public V `init` adapter supports the borrowed
readonly use case. V const-pointer typing remains a representation boundary.

The earlier indexed/raw proof retains its hashes and separate boxed sum-type copy
limits. Generic type factories, PaletteSize members, direct indexed allocator/
deinit interfaces, const/narrow carriers, sizes beyond V's array carrier,
allocator/OOM/GC/lifetime and portable ABI remain boundaries. Source visibility and
implementation are unchanged. Cross-target compilation does not establish runtime
parity on those targets.

Before and after execution the runner verifies full Source-tree SHA-256
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`, the selected
Zig library hash
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`, compiler
versions (Zig 0.15.2 and V 0.5.2), and fixture/runner/V implementation hashes.
