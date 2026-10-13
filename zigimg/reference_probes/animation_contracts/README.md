# Required animation frames, duration bits and shared frame storage

`verify_animation_contracts_reference.py` imports unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` and compares Source Debug with ordinary
V, then Source ReleaseSafe with production V:

```sh
python3 zigimg/verify_animation_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The native target defaults to
64-bit little-endian `aarch64-macos.14.0`, linked with libc. `--timeout` bounds
commands; `TMPDIR` and `VTMP` select compiler temporaries. Retained artifacts include
the complete unchanged Source tree, fixtures, binaries, corpus, outputs, generated
compiler consumers, commands and provenance.

AnimationFrame requires both pixels and duration, matching Source's public record.
GIF explicitly initializes newly created frame durations to positive zero, as in
Source. Existing iterator/editor fixtures now spell both required fields. Animation,
ImageUnmanaged and initialized managed Image retain their Source defaults.

Both modes match **20,992 returning records**:

| Controls | Records |
|---|---:|
| Frame construction and default animation/image predicates | 2,304 |
| Frame scalar copies and shared pixel/palette writes | 2,304 |
| Whole pixel-storage replacement in copied frames | 2,304 |
| Animation copies sharing mutable frame elements | 2,304 |
| Independent copied frame-array lengths | 2,304 |
| Whole frame-array replacement | 2,304 |
| Unmanaged-to-managed views | 2,304 |
| Managed-to-unmanaged views | 2,304 |
| Every f32 exponent/sign over five mantissa controls | 2,560 |
| **Total** | **20,992** |

The main matrix covers all 24 pixel-storage tags, counts 0/1/3, eight duration
patterns, frame-array lengths 0 through 3 and five i32 loop-count controls including
both extrema. Snapshots compare duration bits, image dimensions and animation
predicates, pixel tags/counts, full initialized pixel/palette bytes, animation loop
counts, frame-array lengths and every active frame. The duration partition includes
signed zero, subnormals, infinities and quiet/signaling NaN payloads. Durations are
assigned and copied without floating arithmetic; no validation absent from Source
is introduced.

Return SHA-256: `3898e0c8d02443126eebf2be9b483dad48af2686e9bf58dd7673e105df52960f`.

Four paired compiler acceptance controls cover complete frames, the managed Source
frame alias, default animation/image records and mutable fields. Two independent
omission pairs reject missing pixels or duration. Three constant-record mutations
reject in both compilers. V uses the canonical module-level AnimationFrame type in
place of Source's managed/unmanaged type aliases and GC in place of allocator
arguments. Animation.frames remains a V array adapter for Source's std.ArrayList.

Five separate runtime controls measure the existing indexed PixelStorage boxed-copy
limit inside frame copies. Resizing an original frame's palette descriptor to one
also changes V's copied descriptor. Source's copied frame retains two entries for
indexed1 and three entries for the other indexed tags. Pixel counts remain three
in both records and languages. These differing observations are excluded from the
matching count and retained under SHA-256
`e1bb37fc2732a1f753c59c9cdf48b1ef10c51f30307001a5cb5bb55e56feb623`.
Whole pixel-storage replacement and ordinary backing-element writes match; implicit
sum-type payload metadata copies are not claimed to match.

Caller-owned frame arrays and every active pixel/palette byte are initialized.
Source arena cleanup releases allocations once after each case; copied frames,
animations and managed/unmanaged views are not independently deinitialized.
Inactive storage, frame/image record padding, empty pointer identity, allocator internals,
freed storage and post-deinit state are unobserved. ArrayList capacity/growth/API,
broader boxed payload descriptor mutation, allocation/OOM/GC/deinit/lifetime,
file-platform runtime, physical layout and portable ABI remain boundaries.

All 61 image and 58 Vaxis test files pass, with production GIF/PAM/image-API/
iterator/editor tests, unchanged historical GIF/image-API/compression assertions
in both modes, native/Linux application checks, three Windows DLLs, both Windows
image-API test executables and two Linux shared libraries. Cross builds establish
build coverage only.

Complete Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Before/after dependency/fixture/input/consumer/runner/implementation hashes and
compiler-version pins protect the comparison. Development compiler diagnostics
and the corrected mutable-record compiler fixture remain in retained artifacts.
