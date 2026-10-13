# Checked image editing and retained mutation state

`verify_image_editor_contracts_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary V,
and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_image_editor_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default runtime target
is `aarch64-macos.14.0`, with 64-bit usize arithmetic. `--timeout` bounds ordinary
commands. Three non-advancing flip cases use separate one-second subprocess
timeouts. `VTMP` can select V compiler temporaries. Artifacts retain binaries,
commands, outputs, panic snapshots, provenance and a JSON summary.

Zero-height row-size and flip operations now preserve Source's division-by-zero
diagnostic in both V modes. Flip still divides the total byte length by height,
without consulting width or requiring whole pixel rows. A five-byte buffer at
height two swaps its two-byte outer rows and keeps the middle byte. If later rows
overlap, Source's checked memcpy traps before copying them; V now preserves that
trap after any earlier completed swaps. Nonempty input with a zero byte row size
still loops without advancing, as in the pinned Source.

Crop checks byte multiplication/addition in Source order and validates ranges
using the original usize offsets before narrowing them to V indices. Palette
copying precedes the zero-dimension early return. Invalid storage has an indexed
format tag but no palette, so cropping it preserves Source's null-unwrapping trap,
including an empty crop. Clamping and pixel-count overflow still precede that trap.

| Returning observations | Count |
|---|---:|
| Box defaults and independent record copies | 1 |
| Box clamping over small dimensions, origins and requested sizes | 8,100 |
| Row sizes through both image APIs, including maximum usize heights | 3,120 |
| Returning flips through direct/unmanaged/managed APIs, then a second flip | 13,122 |
| Crops through all three APIs, ownership and subsequent byte/palette mutation | 17,664 |
| Wide empty crops and wide clamp controls | 27 |
| **Total** | **42,034** |

Main-output SHA-256:
`6e4fbba5bf6989991bc3265f8853403464eea19843ed7056094ece7414d1faa3`.
Control SHA-256:
`9ad6adc71fc4b52ef25731150dbd38ec3571611a5e1a673f54874026c9661c91`.

Row/flip cases cover all 24 storage variants, counts 0..9, three flip byte
patterns and heights 1..8 on returning flip paths. Row-size cases use heights
1..12 and maximum usize. A fixture filter selects returning flip lengths without
modifying Source; comparisons use the actual public operations and output bytes.
Crop cases cover all 23 data variants, dimensions 0..3, eight boxes, two patterns
and all three entry points. Results retain independent pixel/palette storage and
discard animation. Mutation records observe both the changed crop and unchanged
source, and compare pointer independence only for defined nonempty allocations.

Every input pixel byte and active palette entry is initialized. Narrow Source
carriers are respected, RGB555/BGR555 input padding starts zero, and float data is
compared as bytes without color conversion. Active palettes have at most four
entries. Inputs have two initialized animation frames: the first shares the main
pixels and the second has independent RGBA32 data. Snapshots cover dimensions,
format/count, pixel/palette bytes, loop count, frame durations and frame pixels.
Flips change the shared first frame; independent frame data and palette bytes stay
intact. A second returning flip restores the original pixel bytes.

| Strict panic/state pairs | Count |
|---|---:|
| Zero-height flips across all formats, empty/nonempty inputs and three APIs | 144 |
| Zero-height row sizes through both image APIs | 96 |
| Crop source bounds after a privately copied first row | 69 |
| Crop source bounds at offsets above 2^31/2^32 | 138 |
| Overlapping flip rows after earlier completed swaps | 24 |
| Crop offset products and start/end sums overflowing usize | 15 |
| Crop pixel-count multiplication before allocation/palette access | 9 |
| Invalid-storage palette unwrap, including empty crops | 9 |
| Direct clamp overflow/underflow | 5 |
| The same clamp failures before cropping through all three APIs | 15 |
| **Total** | **524** |

Failure-state SHA-256:
`913682a5a4bf69433ecdf609cf1e39b27a194d7c61291f0b2cb2bc7b3cf243cd`.

Strict checks require the complete expected panic prefix, unsuccessful exit,
no unexpected return and no core dump. Observers compare the initialized public
input image, active palettes, shared/independent frames and unchanged caller box.
Crop failures exclude the private allocated destination and its partial writes;
flip failures compare completed public mutations. Separate timeouts establish the
three inherited zero-row loops without counting them as returning or panic cases.

The runner imports only public interfaces from unchanged Source files. Allocator/
OOM/GC/lifetime, private temporary/destination state, undefined empty pointers,
uninitialized/freed storage, boxed sum-type copy behavior, narrow/const typing,
allocated extents beyond V's array carrier and portable ABI remain boundaries.
No empty pointer identities are observed. Cross-target compilation does not
establish runtime parity. The unchanged historical image-API harness passes
Debug and ReleaseSafe, retaining its encoder and detection hashes.

Full Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`. The runner
checks Zig 0.15.2/V 0.5.2 and before/after fixture, runner and implementation hashes.
Source visibility and implementation are unchanged.
