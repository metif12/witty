This runner checks the public methods and defined record values of
`src/pixel_format.zig` at zigimg commit
`d7b7ab0ba0899643831ef042bd73289510b39906`. The unchanged complete `src` tree
must match SHA256
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`
before copying and after execution. No source statements, declarations,
visibility, or private helpers are changed. PixelFormat's runtime methods
have no standard-library dependency; compiler versions and exact fixture,
runner, and source hashes are recorded.

Run from the repository root with the package directory, Zig 0.15.2 executable,
and pinned V 0.5.2 executable:

```sh
python3 zigimg/verify_pixel_format_reference.py "$PIXEL_SOURCE" "$ZIG" "$V" \
  --workdir /tmp/witty-pixel-format-debug
python3 zigimg/verify_pixel_format_reference.py "$PIXEL_SOURCE" "$ZIG" "$V" \
  --v-prod --workdir /tmp/witty-pixel-format-safe
```

`PIXEL_SOURCE` contains the locked `src` directory. A supplied workdir must be
absent or empty; it retains copied sources, fixture/provenance hashes, exact
commands, versions, inputs, binaries, stdout, stderr, and result metadata.
Without `--workdir`, temporary artifacts are removed. The default target is
`aarch64-macos.14.0`, linked with libc. Ordinary V pairs with Zig Debug;
`--v-prod` pairs with ReleaseSafe unless `--zig-mode` overrides it. Native
builds use a private Zig cache beneath the workdir.

Both modes compare 197,777 returning observations, SHA256
`9eeaca0cd04514798359ff079b7f9d7f80fd838a8b53bde663154f317a87d349`:

- All 24 named PixelFormat values, including the named `invalid` member:
  `info`, every classification method, pixel stride, channel count,
  supported bits-per-channel calls, and valid numeric/packed round trips.
- Every low 16-bit PixelFormatInfo pattern with padding 0, 32768, and 65535,
  plus 96 full-width bit/edge observations. Copies retain their value while
  a live pointer to the same backing word changes the original projections.
- Default-zero info fields, public Source field mutation, equivalent V raw
  mutation, copy independence, and observed native size/alignment of 4/4.
- 1,024 constant field combinations passed through the actual public
  `toPixelFormatValue` function in unchanged Source. The fixture raises its
  own compile-time evaluation quota for this bounded constant table.
- Numeric variant projections for the 24 named formats.

Source PixelFormat is a closed enum. Arbitrary packed info words are never
promoted to PixelFormat values or treated as valid enum constructors. The
raw-info observations are defined because PixelFormatInfo's variant is a
non-exhaustive four-bit enum; all backing bit patterns are valid info values.
For every named PixelFormat, stride arithmetic fits the Source's u8 domain.
RGB332 keeps its special one-byte stride despite its encoded channel/bits
product. Named `invalid` remains indexed, with stride zero and channel count
one. Float32 is four-channel with stride sixteen, while `isRgba` remains
limited to the two standard integer RGBA formats.

Two isolated strict panic pairs call `bitsPerChannel` with the valid RGB332
and RGB565 enum members. Both reach Source's unreachable branch, and V now
preserves `reached unreachable code` in production. The verifier requires
nonzero exit, no ordinary stdout or `UNEXPECTED` marker, and that category
on an actual anchored panic-message line. Returned values/errors, unrelated
crashes, or category words appearing only in backtrace text do not pass.
These methods have no mutable state to compare at the panic.

The public record and compile-time surfaces remain explicit adaptations:

- Source PixelFormatInfo has mutable named fields `bits_per_channel:u8`,
  `channel_count:u4`, `variant:PixelFormatVariant`, and `padding:u16`, all with
  zero defaults. V has one mutable `raw:u32` field and read-only projection
  methods. Four ordinary V field-literal rejections and Source's rejection
  of a fictitious `raw` field record this different constructor shape.
- Source rejects an 8-bit field value of 256, a channel count of 16, variant
  values 16 and 255, and padding 65536 with ordinary width/enum diagnostics.
  Together with the `raw` field and runtime-packing probes, there are seven
  Source-only compiler rejections. These are separated from runtime parity.
- Source `toPixelFormatValue` requires a compile-time PixelFormatInfo argument.
  A real runtime Source argument fails ordinarily. The V numeric carrier
  helper accepts a runtime word; its acceptance is measured separately.
- V PixelFormatVariant uses a byte enum and an unsafe numeric adapter for
  unnamed values. The info projection always masks to four bits, but direct
  V variant values 16 and 255 can exist. Two V-only numeric observations
  retain that width boundary; they have no valid four-bit Source counterpart.
  Source `.float` is spelled `.float_` in V.

The source packed layout and V raw carrier agree numerically in this native
proof. Size/alignment observations do not certify packed field-address types,
const enforcement, complete constructor syntax, cross-language ABI,
reflection/formatting of unnamed variants, aliases, other target execution,
or arbitrary invalid closed-enum carriers. GC/allocator or full image-storage
ownership claims are outside this scalar proof.

`zigimg/pixel_format_fidelity_test.v` supplies three focused consumers for
all variant projections, raw-pointer borrowing/copy independence, and the
named stride/classification quirks. It runs with the pinned V executable in
ordinary and `-prod` mode; the historical PNG matrices are checked separately.
