# TGA buffered decoding and file vector reads

`verify_tga_decode_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` with V: Source Debug against ordinary
V and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_tga_decode_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. `--target` defaults to
`aarch64-macos.14.0`; cross compilation alone does not verify runtime behavior.
`--timeout` bounds commands and `VTMP` can select compiler temporaries.

The raw RLE path now uses the Source reader's available buffered bytes, rather
than its buffer capacity. A buffered prefix returns immediately. At exhaustion,
the file reader first switches from its unsupported send-file path to direct
reads without making progress; that transition survives later TGA reads on the
same stream. Subsequent reads can use a destination larger than the file buffer.
EOF after partial decompression advances source/state without committing that
stream call's newly written decompression bytes, preserving the pinned reader.

The shared POSIX file shim also preserves Zig 0.15.2's positional vector fallback.
On macOS, Zig reads only the first vector, even where the host offers `preadv`.
The translated shim previously read the destination and read-ahead buffer together.
The corrected branch also follows Source on Apple, Haiku and Serenity targets;
streaming vector reads and targets with native positional vector reads retain
their respective Source paths. Only native macOS runtime is certified here.

| Returning decoder rows | Count |
|---|---:|
| Raw/repeated/mixed packets, four pixel widths, row order and dimensions | 6,552 |
| Truncated headers, packets, values and trailing bytes | 12,264 |
| Two reads through the same codec and stream | 336 |
| Uncompressed controls | 224 |
| Header validation, pixel formats and zero-byte grayscale packets | 1,080 |
| Alpha extensions, retained metadata and retries | 120 |
| **Total** | **20,576** |

These rows contain **21,032 read attempts**. They cover memory and seekable files
with 26/31/64/128/512/4096-byte buffers; extension reads additionally use a
495-byte buffer. Buffer initialization is explicit. Successful grayscale8,
RGB555, BGR24 and BGRA32 pixel bytes, format tags, positions, headers, initialized
active ID bytes and retained extensions match. File buffering can change Source
read-ahead and error outcomes; each buffer configuration is compared independently.
Source RGB555's unused high padding bit is masked.

Decoder SHA-256:
`cacb26414a35edad54b8c5a41d39b951a5c50cb48ffc26a9544b5c14e381615c`.

Forty-eight additional positional vector-read observations compare returned byte
counts, destination bytes, logical positions and buffered lengths across four
capacities, six destination lengths and two consecutive reads. This directly
verifies the shim correction, including short reads and EOF. SHA-256:
`d9028cc6d0c1cb767a3739f9a4da6a994338cfcf11b752a6c3a6ad5a4a11fc2e`.

Fifteen strict panic/state pairs compare undersized footer/extension buffers and
pixel-byte overflow in memory and file streams. Header, active initialized ID,
retained extension and stream position match before failure. Source reader-capacity
assertions report unreachable code; V retains its explicit capacity panic.
State SHA-256:
`62c58cd4c95bfb8d3f1ac53c9d2ba87b8a67be00fd97ef637b5f6c17933079d2`.

The runner pins the full Source tree, compiler versions and the selected Zig
reader/writer/file/POSIX/memory/debug/map sources. Before/after hashes protect
original/copied Source, compiler-library files, fixtures, the runner and every
top-level V image implementation and C header. Commands, corpus, raw output,
diagnostics, state, provenance and summaries are retained. Source visibility
and algorithms are unchanged; the probes call public reader and TGA APIs.

The corpus observes pixel bytes only after successful decoding. ID storage is
initialized before reads, and fixture ID lengths stay within that initialized
prefix. Footer fixtures are initialized; extension sentinel bytes are zero.
Undefined or freed Source pixels and unused RGB555 padding are never certified.
Private RLE state, allocator/OOM/GC/lifetime, portable aggregate ABI, caller-built
custom file-reader modes, nonseekable sources and arbitrary SIMD choices remain
outside this matrix. Indexed palette file decoding has a
[separate proof](../tga_palette/README.md), including exact ordered bounds failures.

Existing stream, TGA record, PNG decoder/processor and JPEG retained-state proofs
retain their prior hashes in both modes. The historical TGA encoder/decoder
tests retain `44cd8ebeb8f84afc` (2,016 cases) and `04232c58bcb7f905` (1,120 cases).
All 60 image and 58 Vaxis test files pass. Focused TGA/file tests also pass in
production. Native/Linux application checks, three Windows dependency DLLs,
the new Windows test executable in both modes and two Linux shared libraries
build with cross builds using `-gc none`; cross-target runtime remains unverified.
