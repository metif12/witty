# IFF file chunk traversal, palette state and ByteRun2 output

`verify_iff_streams_reference.py` compiles unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Debug against ordinary V and
ReleaseSafe against production V, with Zig 0.15.2 and V 0.5.2.

```sh
python3 zigimg/verify_iff_streams_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and a separate empty directory. The default runtime target
is native little-endian `aarch64-macos.14.0`, linked with libc. `--timeout` bounds
commands; compiler temporaries follow `TMPDIR`/`VTMP`. Evidence retains unchanged
Source, fixtures, inputs, binaries, commands, raw output and provenance.

The existing IFF and shared stream implementation matches this new comparison
without production-code changes. File capacities are 20/21/32/64/128/512 for
public/body reading, with smaller capacities checked separately. Detectors use
12/20/32/128, direct CMAP uses 3/4/8/20/32/128, and CAMG uses 4/8/20/128. Memory
controls accompany each group. File descriptors start at EOF independently of
the positional reader cursor. Initial discard is also compared at offset three.

| Returning records | Count |
|---|---:|
| Fully defined ILBM/PBM/ACBM raw, PackBits and ByteRun2 decoding | 15,120 |
| Header/palette/body prefixes and retries, excluding file discard loops | 22,728 |
| Every first detector byte, static/interface detection and peek/take | 5,120 |
| Detector partial magic, format tags and initial discard | 160 |
| Direct palette prefixes, remainders and retries | 1,638 |
| Direct viewport prefixes and retries | 90 |
| Direct pixel-body decoding | 126 |
| **Total** | **44,982** |

These records contain **89,928 calls**, with SHA-256
`22ab2116317663553204d1ed60cf4c4c289f354f871b3e08308b848262ede051`.
Most records call the same stream/codec twice. Complete direct file ByteRun2 bodies
make one call because a second call would enter Source's overlong discard loop.

Shapes cover widths 1/3/16/17, heights 1/2, one/four/eight/24 planes, three byte
patterns, all three accepted format tags and compression tags, and direct/static/
interface reading. PBM uses eight/24 planes so its copied chunky prefix fits.
Planar padding bits are clear. Full compressed bodies initialize every observed
pixel; partial PackBits success with unwritten private planes is unobserved.
Caller palette backing is initialized completely before its active view shortens.
Default static/interface codec state is excluded; decoded palettes are initialized
through complete CMAP input before observation. Successful pixels/palettes are
compared before/after mutation, including independence from input/codec storage.

**3,844 returning controls**, SHA-256
`c317076d4a2abcbe3d15d80c17312c2c23369817337bf97af1ee9145aa9a5f48`,
include 3,640 unknown-chunk length/actual-size/dispatch/offset cases, eight small-header
controls, six palette boundaries and 190 direct ByteRun2 output controls. Chunk
traversal retains the pinned `seekBy` workaround: when an offset leaves the buffered
range, seeking uses the physical file position after clearing the buffer. FORM
length, CAMG length, CMAP remainders, odd chunk padding and raw body length retain
the pinned behavior. File/memory status and cursor differences are compared with
their respective compiled Source results.

| Exact panic/state pairs | Count |
|---|---:|
| Undersized magic/BMHD buffers | 41 |
| Parsed mask/compression enums | 36 |
| Zero pitch before body or format processing | 189 |
| Empty/oversized palettes and undersized CMAP buffers | 36 |
| Direct ByteRun2 source/destination and buffer bounds | 146 |
| ByteRun2 command-size arithmetic or short integer buffers | 15 |
| **Total** | **463** |

Failure SHA-256:
`f4c04686c03679405c437dca8df0000d07116b6260d2d13bee36b178d354c1b9`.
Each pair requires failed exits, no stdout, the exact sole native message and equal
nonempty snapshots. Snapshots compare position, buffered length, every initialized
caller buffer/output byte, public direct header/scalar/palette state, unchanged
input and disk. Private/default codec state, failed/freed buffers, inactive palette
backing and pointer identities are excluded.

File ByteRun2 retains Source's zero-progress `discardAll` loop when fewer than
eight bytes remain for its next VDAT header. **2,304 such public prefix cases** are
excluded from returning records. **Twenty bounded loop pairs** cover public direct/
static/interface paths and direct body/ByteRun2 helpers with empty/seven-byte input,
using file buffers 20/128. Each executable must publish a matching initialized entry
snapshot, emit no stdout/stderr and remain running through a 0.5-second timeout.
Entry SHA-256:
`894536978d1560d94b90e3ce5360d6c6a08415fa050b71807aa8174ee84ffad3`.
These checks certify observed nontermination over that interval and entry state;
they do not observe post-discard state. The initial unpartitioned batch timeout,
isolated native controls and stopped longer attempt remain retained separately.

Consumer regressions preserve a 20-byte buffer containing BODY header/earlier plane
bytes after a successful 16-byte unknown-chunk skip, plus a three-byte direct
ByteRun2 reader leaving output `12 00` and caller buffer `12 03 ff` at position 12
on EOF. Separate compiled comparisons check their stream inputs in both modes.
Historical IFF pixel/chunk/failure hashes and unchanged native assertions remain
unchanged. No Source algorithm or visibility is modified.

Full Source SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`;
selected compiler-library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`;
math.zig SHA-256 is
`65645001357d5f78cbf646485e009a048b828680bb1b47fb3de0fd8617d91af1`.
Versions and before/after Source/library/implementation/fixture/runner/helper/input
hashes protect final comparisons. The existing
[pixel/chunk proof](../iff_pixels/README.md) covers additional memory RGB/HAM paths.

Custom/nonseekable streams, operating-system failures, allocator/OOM/GC/lifetime,
const/narrow/boxed representation, physical layouts, wider extents, big-endian/
32-bit runtime and portable ABI remain boundaries. Cross builds prove compilation
coverage only. Successful unwritten Source private storage is not certified.
