# TIFF strip bounds and retained caller pixels

`verify_tiff_strips_reference.py` compares unchanged public `TIFF.readStrips`
and its row-size calculation at zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`:
Source Debug against ordinary V, and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_tiff_strips_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and a separate empty directory. The runtime target defaults
to `aarch64-macos.14.0`. Retained artifacts include unchanged Source copies,
fixtures, binaries, corpus, commands, diagnostics, failure snapshots and provenance.
Compiler temporaries/caches belong to the task; the Zig global cache is shared
only among this task's proof directories. Commands have a configurable timeout,
and intentional panics disable core dumps.

Explicit native-width bounds guards now retain Source's complete index/length
messages for row samples, strip arrays, caller pixels/palettes and RGB/RGBA source
channels. Missing strip arrays retain Source's exact null-unwrapping message.
RGB/RGBA direct assignments validate the destination before evaluating channel
arguments. Predictor branches retain the previous-color read before destination
validation. This fixes V's former source-channel-first failure when both source
and destination were too short. Guards remain active in production; conversion,
clipping, successful output, arithmetic and I/O order are unchanged.

| Returning observations | Count |
|---|---:|
| Complete strips, including unsupported storage dispatch | 2,484 |
| First-strip clipping into smaller caller storage | 600 |
| Initialized gaps between RGB/RGBA strips | 80 |
| Zero-byte strips | 30 |
| Unsupported row/compression and invalid memory seeks | 66 |
| **Total** | **3,260** |

Memory and file buffers of 4/8/16/64 bytes cover grayscale1/grayscale8/indexed8/
RGB24/RGBA32 and unsupported grayscale16 storage. Raw, LZW, PackBits, DEFLATE
and Pixar DEFLATE cover heights 1/3, row spans 1/2/8 and predictors 1/2/65535.
DEFLATE uses file buffers at least one native word long. Caller storage and all
palette backing are initialized; unwritten caller pixels/gaps remain defined.
Every private strip byte used for conversion is supplied by complete input.
Returning SHA-256:
`8a6553fe35a72b05568327affd1f3d47a6daf6eb21e77f5c2d424d2900a89b69`.

| Exact panic/state pairs | Count |
|---|---:|
| Missing arrays and null precedence | 25 |
| Strip arithmetic and byte-product overflow | 25 |
| Row sample bounds before strip indexing | 20 |
| Short count/offset arrays after earlier strips | 250 |
| Palette copying before pixel assignment | 25 |
| Empty/short pixel destinations after decoding | 150 |
| RGB/RGBA channel bounds and simultaneous short destinations | 140 |
| Partial last-strip channels after earlier writes | 20 |
| **Total** | **655** |

State SHA-256:
`30a332c0c8eae15fb682a521ebe56eab10b1cfbd13457d02008247b4d289833c`.
Each pair requires unsuccessful exit, no stdout/unexpected return, a sole Source
panic in the expected category, the identical full V message and equal nonempty
snapshots. Source bounds messages must contain complete numeric index/length
fields. The golden includes each actual Source message; no handwritten full
diagnostic replaces Source as the oracle. Backtraces/signals are excluded.

Snapshots retain position, buffered length, every initialized caller file-buffer
byte, pixel format/length and every caller pixel, active palette length and all
256 initialized backing entries. They also retain every bitmap scalar/rational,
optional strip arrays (including null/present-empty), fixed-storage active lengths
and all initialized backing entries. Grayscale1 serializes semantic values to
exclude narrow-field padding. Unused/undefined codec header/IFD fields and private
failed strip allocations are excluded. No Source bodies or private visibility
are modified.

The initial pre-fix proof matched 3,320 returning controls before rejecting the
custom null message. Separate compiled controls retain the destination/channel
ordering difference and matching caller snapshots. The final corpus replaces
nominal zero-bit unsupported rows with actual zero-byte strips. An intermediate
wide fixture destination exceeded its u32 input field before reaching the codec;
that error is retained separately from corrected completed proofs. A module
golden retains initialized RGB gaps across memory and file strips.

Both modes match the same returning/state hashes. All 61 image and 58 Vaxis test
files pass, with eighteen production/platform checks. Historical metadata's 86
records/fifteen trap pairs, arrays' 18,820 records/108 panic-state pairs, and the
decoder's 39,707 cases/seventeen trap pairs retain all hashes in both modes.

The runner verifies complete Source-tree SHA-256
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`, selected Zig
library SHA-256
`f7d294645f1474fc6c53ea214299928b8b3ae073e20103f97f650fdfb69185d1`, Zig 0.15.2,
V 0.5.2, and before/after implementation, fixture, runner, helper and corpus hashes.
Selected libraries include checked helpers, reader/writer/file operations,
HashMap, DEFLATE and integer powers. This is not a complete compiler-library pin.
The [historical decoder proof](../tiff_decode/README.md) separately covers CCITT,
decompressor failures and larger memory matrices.

Undefined short-strip bytes/unwritten codec-owned pixels, unused or undefined
codec header/IFD state, private failed allocations, arbitrary larger extents,
V's signed-int allocation limit, OOM/GC/lifetime, manually forged/invalid storage,
custom/nonseekable readers, physical/narrow/const representation, other-target
runtime and portable ABI remain boundaries. Cross builds establish compilation
only. Pinned TIFF encoding still emits no bytes.
