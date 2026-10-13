# QOI records, factories and parsed-header contracts

`verify_qoi_contracts_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary V,
and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_qoi_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The runtime target is native
64-bit little-endian `aarch64-macos.14.0`. `--timeout` bounds each command; `VTMP`
can select V compiler temporaries. Artifacts retain binaries, commands, outputs,
input/consumer hashes, panic snapshots, provenance and a JSON summary.

QoiColor's r/g/b and all four header fields are required, while color alpha defaults
to 255 and encoder colorspace defaults to srgb. Encoder options are mutable. The
factory accepts RGB24/RGBA32 values and transparent aliases, while pointers and
other types take Source's unreachable path. Pixel-format dispatch retains the
exhaustive-switch trap in production.

On little-endian targets, Source's big-endian `takeStruct` validates both enum
fields through `byteSwapAllFields`. Invalid format/colorspace bytes trap after
the complete ten-byte header is consumed and before replacing the codec's public
header. V now preserves this order. Failed/truncated magic and header reads keep
their distinct EndOfStream/InvalidData results and cursor behavior.

| Returning records | Count |
|---|---:|
| Color equality, RGB/RGBA conversions and factories | 36,864 |
| Transparent RGB24/RGBA32 alias factories | 1 |
| Default options, mutation and independent value copy | 1 |
| Native color/header sizes | 1 |
| Initialized header bytes, dimensions, format dispatch and independent copies | 100 |
| All-storage direct/image/interface writes | 21,600 |
| Supported encoder patterns, run boundaries and output capacities | 6,240 |
| Public decoding and detection corpus | 133,749 |
| Valid enum boundary controls | 4 |
| **Total** | **198,560** |

The first seven groups have SHA-256
`8f25ed18baa760e49e30af9e067589232b0b0c4e9a85ed20c0a91351015ace36`.
Other returning records have SHA-256
`defd0517da4d75e5e2c29738aef5727c6a952721b330828c13f865d909dccf0e`.

Color records sweep every red byte, six green/blue edges and four alpha values.
Writes compare status, cursor, the full initialized output and unchanged input
pixels. They cover all 24 valid storage tags, short/exact buffers, zero/inconsistent
dimensions, dimensions above u32 through usize maximum and non-QOI option fallback.
Source intentionally truncates image dimensions to u32. The writer emits the
entire pixel slice, direct writes emit their header before rejecting unsupported
storage, and image writes reject unsupported storage before output. All remain.

Supported encoder patterns cover initial black/transparent black, repeated colors,
index reuse/collisions, diff/luma edges, RGB/RGBA literal writes and lengths around
the 62-pixel run limit. Caller output bytes start at 165. Narrow indexed/grayscale
fields and packed padding are initialized with valid values; inactive palettes
are unobserved.

The decoder corpus includes 131,072 luma records covering all 64×256 operands,
both formats, two initialized color states and direct/image entry points; 512 diff
records, 256 initial-LUT index records, 1,488 run/extent records, 336 prefix reads,
16 trailing-marker controls, 12 wide zero-extent reads, eight wrong-magic reads,
21 detection controls and 28 incomplete invalid-header controls. Wrapping channels,
retained alpha, run overflow rejection and the unconsumed/unvalidated end marker
remain intact. Returning pixels are compared before and after mutation, with
nonempty allocations outside the input and unchanged input bytes. Empty pointer
identities are unobserved. Failed/freed private pixel allocations are excluded.

**677 strict panic/state pairs** comprise 254 invalid format-byte cases, 254
invalid colorspace-byte cases, 144 simultaneous enum failures including maximum
dimensions, 20 direct/image and initial-cursor failures, and five unsupported
factory types. Parsed-header snapshots compare the cursor, previous initialized
public header (direct reads only) and unchanged input bytes. Factory snapshots
compare actual initialized caller values/pointees. Exact panic text, nonzero exit,
no stdout, no unexpected return and no core dump are required. Names, exact panic
text and snapshots are locked into SHA-256
`22a915f9007f737de8becde6d090e21e29d5ecc3541a5f145b303c0754e642e2`.

Compile controls check two complete constructors, seven individual required-field
omissions, default codec acceptance, mutable options and const-option rejection.
Actual compiler error lines are required; crashes or unrelated errors do not
count as rejection. Generated consumer hashes are checked before completion.

Source's default QOI header is undefined. V uses an initialized placeholder so
the default codec remains constructible with required header fields; its contents
are outside the parity claim and are never compared. Direct invalid typed enum
values, big-endian runtime behavior, allocator/OOM/GC/lifetime, wider allocated
pixel counts, boxed storage copies, pointer/slice layout, const/narrow typing,
file streams and portable ABI remain boundaries. Cross builds do not establish
runtime parity. Source visibility and implementation are unchanged.

Full Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`. The runner
checks Zig 0.15.2/V 0.5.2, generated inputs/consumers and before/after fixture,
runner and implementation hashes. All native fixtures import unchanged Source.
