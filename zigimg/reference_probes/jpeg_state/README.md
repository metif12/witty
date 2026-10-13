# JPEG retained decoder state

`verify_jpeg_state_reference.py` compares public JPEG records across reads with
unchanged zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against
ordinary V, and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_jpeg_state_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default target is
`aarch64-macos.14.0`; `--timeout` bounds commands. `VTMP` can relocate V compiler
temporaries. Cross compilation alone does not verify runtime behavior.

JPEG.read can use a caller-provided retained Frame and pixel record. A stream
containing only SOI/EOI then finalizes that Frame. Source dequantizes and performs
IDCT before unwrapping the optional pixels. V now preserves Source's exact
`attempt to use null value` panic when that optional is absent, in both modes.
The proof also verifies earlier quantization/IDCT failures taking priority, and
the fully transformed coefficients retained when the null access traps.

| Returning rows | Count |
|---|---:|
| Stored-frame finalization, dimensions, coefficients and quantization controls | 720 |
| Recoverable errors with preexisting Frame/table/pixel state | 1,008 |
| Missing quantization and empty q16 frames | 30 |
| q8 installs and every truncation prefix | 1,716 |
| q16 installs/truncations | 540 |
| Huffman slot/class/symbol installs and every truncation prefix | 1,472 |
| Multi-table segments with a partial later table | 160 |
| Restart updates and later failures | 36 |
| Application/comment skipping and positions | 108 |
| Multiple read attempts with explicit caller pixel reset controls | 180 |
| Fresh decoder records and retained parsed-frame metadata | 168 |
| **Total** | **6,138** |

These rows contain **6,408 read attempts**. Memory streams and file streams with
16/31-byte buffers are exercised. Returning SHA-256:
`846e18ebd6cccfb3d5d01147a2b2bede3041669033b573d02cec62de14fb3b76`.

Snapshots include restart interval, Frame metadata, all initialized coefficients,
four tagged quantization slots, eight Huffman slots and optional pixel tag/length/
bytes. Quantization signatures encode q16 samples in little endian. Huffman
signatures include class, counts, acceleration arrays and sorted packed map keys/
values, avoiding claims about Source/V map iteration order or layout.

The comparisons verify that recoverable read errors clear pixels while preserving
the Frame and installed tables. A complete early table remains installed when a
later table is truncated. Quantization segment underflow occurs before installing
the completed new table; Huffman segment underflow occurs after its installation.
Duplicate-frame errors occur before reading the new header. Restart updates remain
visible after a later marker read fails. Reusing a record requires the caller to
restore pixels after an error when subsequent finalization reaches pixel access;
the decoder retains Source's state rather than resetting or rebuilding it.

Sixty exact panic/state pairs cover absent pixels after finalization, competing
earlier failures, wrong pixel arms, short pixel buffers, component-count unreachable,
unknown markers before/after segment skipping, quantization/Huffman installation
order and restart-length failures. Each pair checks consumed position and the
complete defined retained state in memory and buffered file modes. State SHA-256:
`5c752672755ff2581f89c69aa911b00cd30cb1eabfc8d532ebd1242f54c08060`.

All manually constructed Frame coefficient lanes and initial pixel bytes are
initialized. Fresh Source Frame allocations have undefined coefficients and
unused grayscale channels; their coefficient hash is printed as `?`. Fresh pixel
allocations likewise use `?` for byte observations. Fresh-frame returning inputs
either fail before coefficient access or use a complete baseline scan. No freed
pixel storage is inspected after recoverable-error cleanup. Panic cases use
initialized retained Frames/pixels and do not rely on undefined storage.

The runner pins the complete Source tree, compiler versions and selected Zig
memory/debug/reader/writer/file/map library files. It copies Source unchanged and
infers private component types from existing public fields. Before/after hashes
protect Source, compiler-library files, fixtures, runner and all top-level V image
implementation files. Raw commands/output/diagnostics, observer state, corpus,
provenance and summaries remain in the proof directory.

The existing decoder, header/table record, Frame, Scan and historical JPEG proofs
retain their previous hashes and exclusions in both modes. All 58 image and 58
Vaxis test files pass, as do focused ordinary/production state tests, native/Linux
application checks, three Windows dependency DLLs, the new Windows test executable
in both modes and two Linux shared libraries. Cross builds use `-gc none` and do
not establish cross-target runtime behavior.

Allocator/OOM/GC/lifetime and freed/undefined memory behavior, aggregate ABI,
const/narrow integer/key typing, map layout/order/capacity, boxed quantization
payload copies and arbitrary SIMD selection remain limitations. The inherited
quantization.Header.read compiler failure under Zig 0.15.2 and pinned no-op JPEG
writer are unchanged. Earlier representation measurements remain documented in
the [record](../jpeg_records/README.md), [Frame](../jpeg_frame/README.md) and
[Scan](../jpeg_scan/README.md) proofs.
