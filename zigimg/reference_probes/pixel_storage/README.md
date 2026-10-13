# Indexed constructors and borrowed PixelStorage

`verify_pixel_storage_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary V,
and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_pixel_storage_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default runtime target
is `aarch64-macos.14.0`. `--timeout` bounds individual commands; `VTMP` can select
V compiler temporaries. The runner retains binaries, command output, panic
snapshots, constructor diagnostics, provenance and a machine-readable summary.

All five indexed records require `palette` and `indices`. Constructor and resize
capacity checks now survive production compilation. Resizing changes the active
slice length while retaining the original allocation. Raw storage still borrows
its input, rejects the seven unsupported tags, checks exact byte divisibility
before alignment, and checks alignment only for nonempty input. The four aligned
formats are grayscale16-alpha, RGB555, RGB565 and BGR555. RGB48, RGBA64 and float32
retain Source's align(1) byte views. Empty input at an odd address is accepted.

| Returning observations | Count |
|---|---:|
| Indexed constructors, opaque active palettes and initialized indices | 1,168 |
| Initialized palette shrink/regrow, direct record copies and shared slices | 25 |
| Borrowed raw storage, input mutation, pointer identity and valid slices | 2,192 |
| Unsupported raw-format controls | 1,008 |
| **Total** | **4,393** |

Returning SHA-256:
`8967f88d0296ceb0499e115b004ce6579c8fe87682fc6bd2b40b1f4f36a2823e`.

Constructors cover every active palette length for indexed1/2/4/8 and ten boundary
lengths for indexed16, with pixel counts 0, 1, 7 and 31. Indices are explicitly
initialized before observation. Only the active constructor palette is inspected;
resize cases start with a fully initialized allocation before shrinking/regrowing.
Direct indexed copies have independent descriptors and shared element storage.
The raw matrix covers all 24 tags, offsets 0..3, pixel counts 0..8 and four byte
patterns. Its 272 supported empty cases observe lengths and bytes, excluding
undefined pointers. Nonempty cases verify pointer identity and mutation through
the byte view; valid storage slices share the input and active palette.

Ninety-seven strict panic/state pairs cover 45 over-capacity constructors/direct
resizes/union resizes, all 44 nonzero stride remainders, and eight odd-address
alignment failures. Capacity values include the first invalid size, another
invalid size and maximum usize. Remainder cases use an odd address to verify
exact-division failure precedes alignment. Observers compare the unchanged active
palette length and initialized palette bytes, or untouched raw input. Initial
constructor failures have no created storage to observe. Failure-state SHA-256:
`bc8fdb7c1c467f766f59bd7490211ddb0666cf8e4426fa2b2077fa4a3a506849`.

Five complete constructors, ten omissions and five immutable resize attempts
check matching acceptance/rejection with specific error diagnostics. Separate
compile controls record three narrow-index literal differences, five constant
record slice-pointee differences, and the mutable V return type of
`as_const_bytes`. These differences remain outside the parity totals.

Five runtime controls also record boxed sum-type copies separately: after
copying a PixelStorage and resizing the original palette to one, Source's copy
keeps lengths 2/4/16/256/65536; V's copy shares the boxed record and sees one.
Direct indexed record copies retain independent lengths. Replacing a whole sum
variant remains distinct from mutating a boxed payload.

Source empty slice pointers are undefined: the Debug compiler's poison pattern
is an observation of the compiler, not a pointer contract. Neither empty typed
nor empty byte-view pointers enter the comparison. V retains its existing
float32 sentinel adaptation for conversion; nonempty alignment is checked before
creating a view. Inactive palettes, uninitialized indices/pixels, padding outside
this native ABI, freed storage, allocator/OOM/GC/lifetime and sizes beyond V's int
array carrier are excluded. Source's generic IndexedStorage factory, PaletteSize
members and direct indexed allocator/deinit API are not matching V interfaces.
Invalid PixelStorage.slice ranges also remain outside this valid-slice matrix.
Cross-target compilation does not establish cross-target runtime behavior.

Before and after execution the runner verifies full Source-tree SHA-256
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`, the selected
Zig library hash
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`, compiler
versions (Zig 0.15.2 and V 0.5.2), and fixture/runner/V implementation hashes.
Source visibility and implementation remain unchanged.
