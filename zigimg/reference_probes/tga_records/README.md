# TGA public records and checked mutation

`verify_tga_records_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` with its V translation: Source
Debug against ordinary V, and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_tga_records_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and a separate empty directory. `--target` defaults to
`aarch64-macos.14.0`; cross compilation alone does not verify runtime behavior.
`--timeout` bounds commands. `VTMP` can select the V compiler's temporary directory.

The packed image-type and descriptor records retain their byte carriers and
getters. Nine public mutators represent assignment to Source packed fields:

```v
mut flags := zigimg.TGAImageType{}
flags.set_indexed(true)
flags.set_truecolor(true)
flags.set_run_length(true)
flags.set_pad1(0)
mut descriptor := zigimg.TGADescriptor{}
descriptor.set_num_attributes_bit(8)
descriptor.set_right_to_left(false)
descriptor.set_top_to_bottom(true)
descriptor.set_pad(0)
```

`set_pad0` completes the image-type fields. Each setter preserves other bits.
The three u4/u2 setters reject out-of-domain byte arguments before changing the
record, including in production. `TgaEncoderOptions` fields are public/mutable,
including its nested metadata. The encoder uses the same flag setters.

| Returning observations | Count |
|---|---:|
| All image-type bytes, every field/value, getters and independent copies | 6,144 |
| All descriptor bytes, every field/value, getters and independent copies | 6,144 |
| Header validation across all image-type/depth bytes and four color-map flags | 262,144 |
| Record defaults, initialized header/extension/footer copies and option mutation | 21 |
| **Total** | **274,453** |

Returning SHA-256:
`1a09cac1be76dea9fab61a3a330b4f0c484f4f67e5bc08e1cfe0e2f1e719ad36`.

Twenty-four checked panic/state pairs cover nine invalid packed-field casts,
all seven overflowing pixel-byte values, palette-end overflow, palette capacity,
16/24-bit palette indices, an invalid 24-bit index at EOF, and competing failure
priorities. Snapshots compare the unchanged flag byte or stream position, header,
active initialized ID bytes and retained initialized extension. Byte arithmetic
precedes palette capacity; capacity precedes palette-end arithmetic. The 24-bit
palette destination is checked before consuming a byte, while the 16-bit path
reads its word before checking the index. Overflow/capacity guards stay active
in production, including the shared indexed-8 palette resize method. The
[indexed palette proof](../tga_palette/README.md) adds file buffering and exact
index/length diagnostics to both palette destination paths.

State SHA-256:
`dc9cb7be7b9c8d24f9cbf71550f8deba334d670042f07ab523795fd328586880`.

Twelve mutations through immutable bindings receive ordinary compiler rejections
in both languages. The runner checks actual error lines and excludes compiler
crashes, signals and backend/linker failures. Separate measured differences are
excluded from the matching corpus:

- Three Source literal assignments outside u4/u2 fields are rejected during
  compilation. V's byte-argument setters compile and reject those values at runtime.
  Packed field syntax and compile-time narrow typing remain language adaptations.
- Source's metadata arrays have logical lengths 40/40/40/80 and additional sentinel
  storage. V physical arrays have lengths 41/41/41/81. Strings replace sentinel
  option slices; their sentinel typing is not enforced by V.
- Source's image-ID option is a const slice. A compile pair measures Source rejecting
  mutation through that option while V accepts it. Both copies still borrow the same
  caller ID storage, as verified through mutation of the original mutable array.

The default-record row explicitly initializes the Source footer's undefined signature
to zero. All other copied footer signatures and metadata bytes are initialized.
The proof never observes undefined ID/pixel storage or freed allocations. Physical
record bytes are compared on the selected native target; this does not certify a
portable aggregate ABI, allocator/OOM/GC/lifetime behavior or arbitrary SIMD choices.

Full Source-tree, selected Zig-library and compiler-version pins protect the proof.
Before/after checks cover original/copied Source, fixtures, the runner and every
top-level V image implementation. Commands, generated compile consumers, raw output,
diagnostics, state, provenance and summaries are retained.

The historical 2,016 encoder and 1,120 decoder cases retain FNV hashes
`44cd8ebeb8f84afc` and `04232c58bcb7f905` in both modes. All 59 image and 58 Vaxis
test files pass; focused TGA/record/pixel-storage tests also pass in production.
Native/Linux application checks, three Windows dependency DLLs, the new Windows
test executable in both modes and two Linux shared libraries build successfully.
Cross builds use `-gc none`; cross-target runtime remains unverified.
