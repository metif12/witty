This proof compares public TIFF record constructors with zigimg revision
`d7b7ab0ba0899643831ef042bd73289510b39906`, using unchanged source bodies.
The runner verifies the entire `src` tree before copying it and verifies both
trees again afterward. Its source SHA256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
The HashMap/integer-power compiler sources have the same selected-file pin as
the [metadata bounds proof](../tiff_metadata_bounds/README.md).

Run from the repository root:

```sh
VEXE=/Users/alex/.cache/v/v1-fallback/0.5.2/v \
V_C_ERROR_BUG_REPORT_DISABLED=1 \
python3 zigimg/verify_tiff_records_reference.py \
  /tmp/witty-zigimg-audit/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /tmp/witty-tiff-records-debug
```

Add `--v-prod` for V production and native `ReleaseSafe`. An explicit
`--zig-mode` overrides the default. The default target is
`aarch64-macos.14.0` with libc. Supplied `--workdir` must not exist or must be
empty; it retains copied source, fixtures, binaries, exact command arguments,
compiler/runtime diagnostics and provenance/results JSON. Without this option,
temporary artifacts are removed.

One batched executable demonstrates six successful record constructors:
`Header`, `PackedTag`, `TagField`, `IFD`, `BitmapDescriptor` and `TIFF`.
The 343 returning records cover packed record sizes, zero/one/high-bit/maximum scalar values,
mutable fields, scalar copies, inline SHORT projections in both endian modes,
every defined bitmap default, IFD defaults/init, shared stream positions and
existing map entries, borrowed optional strip arrays, and copied fixed-storage
views before and after rebinding them with `resize`. Only initialized active
storage cells are read. The returning SHA256 is
`e58e21e70207affb3ec52c115ad2cd73af652ce6f14d81ae0385e9f8bf4dea26`.

Independent compiler consumers require ordinary diagnostics for eleven paired
field omissions: two Header fields, four PackedTag fields, three TagField
fields, and IFD's `tags_map`/`read_stream`. A const Header mutation also has an
ordinary rejection in both languages. Compiler crashes, panics and C backend
failures cannot satisfy rejection checks. Successful runtime consumers are
built once per mode; individual rejection/adapter consumers use native
`-fno-emit-bin` and V `-check`.

The following boundaries are measured separately and are excluded from the
paired constructor/runtime claims:

- Pinned V aliases ignore the original record's required markers. All eleven
  alias omissions are rejected by the original Zig type alias and accepted by
  the corresponding V alias. Direct V record constructors enforce the markers.
- Source IFD's non-null mutable `*ReadStream` rejects an address-zero pointer and
  a pointer to a const stream. Explicit unsafe nil and an immutable stream
  reference are accepted by V. This is a constructor capability difference;
  dereferencing nil or mutating immutable storage is outside the runtime corpus.
- Source IFD additionally requires an allocator. The separate allocator omission
  is rejected by Source and the complete represented V constructor is accepted.
  GC replaces allocation/reclamation, with no full allocator or ownership parity.
- Every BitmapDescriptor field has a Source default. Its FixedStorage backing
  arrays are undefined while the default active slices are empty. V zeroes the
  backing arrays; those inactive values are not observed.
- Source TIFF defaults endian, Header, IFD and BitmapDescriptor to `undefined`.
  Its empty constructor compiles, but no default values are read. The consumer
  replaces every field before using it. V preserves its existing zero/default
  state, including explicit zero Header and nil-stream/empty-map IFD defaults.
  The focused test labels that state as a V representation adaptation.
- The shared-map observer only replaces an existing entry, with no growth or
  duplicate deinitialization. Stream/array borrows stay live and allocations stay
  fixed. Map allocator lifetime, dangling copies, deinit ownership and arbitrary
  whole-aggregate byte comparisons are outside this proof.

The declaration/caller changes are also checked by the existing unchanged-source
[metadata](../tiff_metadata_bounds/README.md) and
[decoder](../tiff_decode/README.md) proofs; their returning hashes remain pinned
independently of this record corpus.
