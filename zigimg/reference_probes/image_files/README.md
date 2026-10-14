# Public image file and path encoding

`verify_image_files_reference.py` compiles unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`, using Zig 0.15.2 and V 0.5.2.
Debug is compared with ordinary V; ReleaseSafe with production V. Runtime is
native little-endian `aarch64-macos.14.0`, linked with libc.

```sh
python3 zigimg/verify_image_files_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` in a separate empty directory. `--timeout` bounds commands.
The runner retains Source, fixtures, binaries, inputs, command logs, raw output,
initialized failure snapshots and provenance; compiler temporaries use TMPDIR/VTMP.

The comparison found that PNG's invalid generated header produced V's generic
`Assertion failed`, where Source's `std.debug.assert` panics with
`reached unreachable code`. The explicit V guard now preserves the exact native
message and remains active in production. File/path wrappers and valid output
are unchanged.

**19,584 returning records / 39,168 encoder calls**, SHA-256
`ad1f0e53dca0a11ea96483157a8438c253b65ca3ecde6156fd4bda3c6fe5847e`,
cover every combination of:

- All seventeen Format/EncoderOptions arms, dispatched through the public API.
- Managed/unmanaged `write_to_file` and `write_to_file_path` (four routes).
- Eight initialized 4×2 profiles: grayscale8, RGB24, RGBA32, BGR24, BGRA32,
  RGBA64, indexed8 with four initialized palette entries, and invalid storage.
- Three option variants, including Netpbm text/binary, PAM comments, PNG
  interlacing, QOI colorspace and TGA compression/orientation/ID/author metadata.
- Caller buffer capacities 0/1/3/7/8/15/16/31/32/127/512/1024.

Each record seeds a file with 256 bytes of 165, opens a read/write descriptor and
seeks that descriptor to EOF. The image call uses positional offset zero. Calls
repeat twice without resetting the buffer or descriptor. Path calls truncate the
same inode before encoding, while the separately opened caller descriptor remains
live at EOF. Handle calls retain existing tails or extend the file. Each wrapper
constructs a fresh stream; repeated calls start encoding at zero again.

**768 individually classified returning controls**, SHA-256
`c2e3b0f27c5ceedd1d717adacd1c5b20e93772792838156dd47f73cec624e0a8`,
and **384 exact panic/state pairs**, SHA-256
`a9d18603fd04734b446831e29cdbeaaef434718b07b8f13b0d5367f4d8a9f3f3`,
cover PNG/TGA, RGB24/RGBA32/BGR24/BGRA32, all four routes, three option variants,
capacities 0/1/8/32, zero width, zero height and storage shortened to one pixel.
Source execution supplies each classification before V is checked. Returning
controls include 576 zero-extent and 192 short-storage cases. Failure controls
include 192 invalid PNG headers and 192 TGA short pixel/row accesses. Earlier
unsupported returns and raw whole-slice TGA output retain Source order.

Snapshots retain every caller buffer byte, the originating image's dimensions,
storage tag, pixel count, raw pixels and active initialized palette, borrowed
file descriptor position and actual disk bytes/extent. They are captured before
encoding and after each returning call, or at the exact failure. Panic pairs
require failed exits, no partial stdout, the sole exact native message and equal
nonempty snapshots. Source bodies and visibility are unchanged. Wrapper-private
stream position/pending length, codec state and private managed views are not
exposed; pointer identity, inactive backing and allocator effects are excluded.

The public wrapper adds no final flush. The pinned GIF/IFF/JPEG/RAS/SGI/TIFF/XBM
writers are no-ops, so handle calls preserve disk while path calls truncate it.
The pinned PNG writer flushes only its eight-byte signature; its chunk bodies
remain commented out. Unsupported PNG storage likewise leaves a path empty but
preserves a borrowed handle's existing contents. This proof certifies those exact
pinned behaviors and does not add encoder bodies.

Two consumer regressions use matrix inputs. Repeated RGB24 PNG calls with an
8-byte buffer retain `89 50 4e 47 0d 0a 1a 0a` in that buffer, leave the borrowed
descriptor at 256, and preserve a 256-byte handle file or an 8-byte path file.
Repeated GIF no-op and unsupported BGR24 PNG calls keep buffers/pixels unchanged,
with disk retaining 256 bytes for handle calls and becoming empty for path calls.
All four routes are exercised.

All 61 image and 58 Vaxis test files pass. Nineteen checks cover production image/
PNG tests, native/Linux application checks, Windows dependency libraries/unit/
fixture builds and Linux dependency/fixture builds. Cross builds establish
compilation only. Historical interface records, option failures and memory writer
hashes remain unchanged in both modes, including 49,344 historical writer records
and the native 6,528 image encoder cases (`e49e6984a209c47b`). Formatting, diff
and Python compilation checks pass.

Full Source SHA-256:
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected compiler-library SHA-256:
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
The runner also pins math.zig and simd.zig, compiler versions and before/after
implementation/fixture/runner/helper/input hashes. The original diagnostic
mismatch with equal retained state, a fixture exit-observer error, and a historical
run rejected by the implementation freeze check remain retained separately.
Final proof inputs are frozen. Evidence is independently replayed, archived and
every member read back on persistent storage before the task's RAM disk detaches.

Read/detect wrappers, custom/nonseekable streams, OS failures/short writes, file
creation permissions, path races/symlinks, allocator/OOM/GC/lifetime, larger extents,
other CPU vector selections, const/narrow/enum/boxed representations, physical
layouts, big-endian/32-bit runtime and portable ABI remain boundaries.
