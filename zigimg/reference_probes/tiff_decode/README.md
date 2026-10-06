# TIFF decoder comparison

```sh
python3 zigimg/verify_tiff_decode_reference.py \
  /tmp/witty-zigimg-audit/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /tmp/tiff-decode-debug
```

Add `--v-prod` to pair V production optimization with Zig ReleaseSafe;
`--zig-mode` permits an explicit override. The default target is native
`aarch64-macos.14.0` with libc. `--timeout` limits each complete corpus run;
`--bounds-only` builds and checks the isolated failures without the returning
corpus. Supplying `--workdir PATH` retains copied source, fixtures, input,
binaries, exact commands and V environment, full build/runtime diagnostics,
provenance and final results. The directory must not exist or must be empty.
Omitting this option removes temporary artifacts after the run.

The full unchanged source tree is pinned to zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`, SHA256
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
The Zig 0.15.2 flate, decompressor, token, Huffman encoder, reader and writer
files are additionally pinned together to SHA256
`e8898fcced291d899efc9ebacf42762954ac5a1e088283cee0f1f261a498cab5`.
Original source and its copy are checked before and after execution. The
fixtures call public methods and contain no private-source wrappers or edits
to dependency bodies.

Both modes retain the historical 39,707 returning cases and output SHA256
`22c929806d09ca615c320574abc8bb2be684f3d5596ba940f220164977fd6698`.
The native decoder defines pixel/palette data, errors, stream positions,
header/scalar metadata and prefilled destination state. Coverage includes
stored/fixed/dynamic zlib blocks, mutations and truncations, destination sizes,
trailing bytes and large buffered reads; LZW and CCITT helpers; all accepted
TIFF storage/compression paths; both byte orders, multiple/short last strips,
oversized rows-per-strip, predictors, invalid seeks and unvalidated versions.

Seventeen strict failure pairs retain the fifteen historical cases and add
zero PackBits compressed length and an invalid CCITT padding cast. They cover
strip arithmetic, absent/short arrays, pixel and RGB/palette/PackBits bounds,
CCITT run underflow, image-pixel overflow and the inherited fixed-match window
rebase trap. Palette cells read before the palette-destination trap are
explicitly initialized in both consumers. A failure requires nonzero exit,
empty stdout, no `UNEXPECTED` marker anywhere and the expected category in an
actual panic header. Returned errors and incidental source/backtrace text
cannot pass. Explicit V null/array diagnostic mappings preserve existing host
messages without asserting panic ABI or byte-for-byte diagnostic parity.

Undefined allocator tails/unwritten pixels, giant allocations beyond V's
signed-int array representation, allocator failures/reclamation, ABI, complete
general-purpose flate behavior and logger formatting are excluded. These
bounded comparisons do not establish full image-library or file-buffering
parity. TIFF public metadata has a separate
[values and bounds proof](../tiff_metadata_bounds/README.md).
