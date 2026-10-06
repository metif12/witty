# TIFF metadata values and checked failures

Run the provenance-checked proof from the repository root:

```sh
python3 zigimg/verify_tiff_metadata_bounds_reference.py \
  /tmp/witty-zigimg-audit/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /tmp/tiff-metadata-debug
```

Add `--v-prod` for V production optimization paired with Zig ReleaseSafe.
`--zig-mode` can override the native mode explicitly. The default native target
is `aarch64-macos.14.0`, linked with libc. The supplied `--workdir` directory
must not exist or must be empty; it retains the unchanged dependency copy,
consumer fixtures, binaries, exact commands and V environment, every
stdout/stderr stream, provenance and results.
Without this option, the temporary directory is removed after the run.

The runner checks the full pinned zigimg `src` tree before and after execution:
SHA256 `ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
It also checks the unchanged Zig 0.15.2 `hash_map.zig`, `math.zig`,
`math/pow.zig` and `math/powi.zig` bodies together against SHA256
`5fd6e9e31ace4bf2e70d2c01b131764cccfadef6f2ba9b287e072894826a3026`.
The consumer calls public APIs directly; no dependency bodies or private
access wrappers are changed.

Both modes compare 86 returning records, SHA256
`c22c2516d50b6861d84f15605a3904f2a4fc935e45c8b3583ca0ead0c76f1346`.
These cover both byte orders, inline count-one words for fourteen tag types,
empty arrays, SHORT/LONG arrays of several lengths, scalar projections and
rational reads with all zero-through-eight-byte input lengths. Returned values,
errors and stream positions come from the native source. Every byte read by a
successful array/rational result is initialized; undefined short-read tails
are excluded.

Fifteen isolated failure pairs cover invalid tag/compression/resolution enums,
fixed capacities, missing sample/alpha entries, row indexing, tag-byte overflow,
parallel-loop length mismatch and palette power/capacity/input bounds. The two
additional public HashMap capacity cases use `ensureTotalCapacity` and fail
before allocation: `0xffffffff` overflows the destination cast, and
`0x80000000` overflows the power-of-two ceiling. The source's thirteen earlier
metadata cases remain in this set.

A failure requires a nonzero exit, empty stdout, no `UNEXPECTED` marker anywhere
in either stream, and the expected category in an actual panic header. Ordinary
errors and incidental backtrace text cannot satisfy a case; a later panic with
the same category is not distinguished by this classifier alone. Existing V
enum, FixedStorage and array diagnostics have explicit mappings
to the source categories; this proves the checked boundary rather than exact
diagnostic text, backtrace, signal or cleanup equivalence. `verify.py` is a
strict auxiliary checker for already-built binaries and does not establish
their provenance.

The full general-purpose HashMap API, allocator ownership/reclamation, allocation
failure injection, ABI/layout and undefined storage remain outside this proof.
GC owns V allocations, and V arrays use signed-int lengths: large source
allocation domains that exceed this representation are separate explicit
guards. Generic codec debug rendering and logger policy are host-language
adaptations. Complete strip/image decoding has its own
[decoder proof](../tiff_decode/README.md).
