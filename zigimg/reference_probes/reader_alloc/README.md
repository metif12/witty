# Allocated byte and endian slice reads

`ReadStream.read_alloc(count)` returns an owned byte array.
`read_slice_endian_alloc[T, E](count, endian)` returns an owned native integer
array, converting its elements only after the complete read succeeds. Aliases
of the integer and endian marker types are supported. Both methods preserve
consumed reader progress on EndOfStream/ReadFailed and return no partial array.
Zero counts succeed without IO. Existing reader and C adapter bodies are unchanged.

The V mapping uses GC-managed arrays instead of Source's explicit allocator.
Source allocates uninitialized storage and frees an incomplete allocation through
errdefer. V initializes its array and leaves an incomplete allocation unreachable
for collection. Successful bytes and reader behavior are compared; allocator
selection, OutOfMemory errors, immediate free timing, allocation reuse and empty
pointer identity are outside this mapping. Counts whose byte span exceeds maximum
V int trap before allocation with Reader allocation exceeds V array length.
Source can represent larger spans; the finite corpus does not reach this bound.

## Reproduce

```sh
python3 zigimg/verify_reader_alloc_reference.py "$SOURCE" "$ZIG" "$V" --workdir /path/to/empty/ordinary
python3 zigimg/verify_reader_alloc_reference.py "$SOURCE" "$ZIG" "$V" --v-prod --workdir /path/to/empty/production
```

Source is zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`, with Zig 0.15.2
and V 0.5.2. Debug pairs with ordinary V; ReleaseSafe pairs with V production.
Target defaults to `aarch64-macos.14.0`. VEXE and
V_C_ERROR_BUG_REPORT_DISABLED=1 are pinned and temporary paths are owned.
Full unchanged Source tree SHA-256:
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected stdlib SHA-256:
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Versions, selected math/simd/path libraries, implementation, probes, shared
fixtures, directly imported helpers and inputs are checked before/after.
Source bodies, visibility and reader syscalls remain untouched.

## Records and ownership

Each mode matches **27,585 returning records / 82,755 allocated reads /
193,095 primary calls**: three reads, three caller consumptions and one relative
seek per record. Setup, priming and observations are separate. Groups contain
15,795 basic, 6,912 every-byte, 3,888 prefilled and 990 owned-mutation profiles;
duplicate input records are retained once. Output SHA-256 (joined lines without
a trailing newline):
`de092f84619d3966654e8beb1b7fcc7a06febb8f9f9cf8f21a3c0cbf64365b35`.

Twenty native/alias integer carriers, both byte orders and marker aliases run
through memory, positional files and streaming-initialized files. Basic lengths
0/1/7/8/17, capacities 0/1/8/32, starting offsets and zero/one/three-element
counts cover complete/partial reads and destinations larger than the reader
buffer. Every byte runs through byte allocation and u8/i8/u16/i16 in both orders
and all reader kinds. Prefills use open/closed owned pipes, retained original
read-ahead, seed/prime/toss choices and relative seek -1/0/1. Mutation profiles
retain the first nonempty result while later results are allocated and XOR the
current result's first byte after each observation.

Snapshots compare status, position, size/error, reader backing/pending bytes,
owned references, the latest successful array, the first retained nonempty array
and whether their nonempty pointers coincide. A successful later allocation
cannot alias the retained array. Caller mutation affects the retained array only
when it is the same result; it never changes reader storage. Failed reads leave
the last successful and retained arrays intact. Source failed allocations are
freed and never inspected. Intermediate successful allocations remain live for
the bounded fixture; allocator lifetime is outside the comparison.

An independent model checks every nonreplacement value via mathematical endian
conversion, progress and EOF, tracks physical streaming progress separately from
logical rewind, and checks allocation retention, alias/mutation effects and
zero-count no-IO behavior on all records.

Input fields are
`kind|warmup|capacity|start|consume-mode|payloadhex|replacement|consumed|seed|prime|delta|operation|type|endian|count`.
Operation 0 selects bytes, 1 typed elements, and 2/3 add caller mutation. Types
0–9 are u8/u16/u32/u64/i8/i16/i32/i64/usize/isize and 10–19 their V aliases.
Endian 0/1 selects big/little and 2/3 marker aliases. The ten output parts contain
initial/primed state, three read/consumption pairs, relative seek and wire bytes.
Snapshots use
`status|position:size-or-error:valid:refs|readerhex|activehex:heldhex:alias|pendinghex`.
Alias is `-` when either array is empty, avoiding empty-pointer comparisons.

## Controls, consumers and verification

The **264 controls** classify as **96 returning records**, SHA-256
`17278d55c05ea3acc324e9869abbbed9ee273db9883ae712bbac162dc265b822`,
and **168 exact integer-overflow panic/state pairs**, SHA-256
`8ebe110126543970be692cd35b4799b35bfb941dd29c64f4daf80a094400ef63`.
They exercise checked public getPos after priming, before allocation. Both exits
fail with empty stdout, one exact message and matching initialized retained
state. Observers omit getPos, capture bytes before opening state files, and
clean up only owned resources through Source FullPanic or V at_exit.

Twenty-one compiled consumer records / 63 reads / 147 primary calls per mode
assert bytes, signed/high-bit values, aliases, independent results, mutation,
first/later short reads, zero counts, read-ahead, zero buffers, larger arrays,
rewind, pipe EOF/ReadFailed and sticky pending success/failure. SHA-256:
`b7ae7e4eba0997a8b169a37c3dd25458ffb5e28df0e38fc69f3f3abd5b28f09c`.
Six paired compile rejections per mode cover floats/aliases, booleans, strings
and integer endian arguments/aliases. Three public regressions accompany the
proof. All 75 image test files pass in three batches, with 17 production,
application, Windows and Linux build checks. Vaxis runtime tests are unchanged
and were not rerun in this checkpoint; its dependency builds pass. Historical
endian-slice and full-stream matrices retain their hashes in both modes.

## Evidence and boundaries

The initial fixture's nested generic helper caused V to generate an endian-array
C result type for an integer-array call. The final fixture makes concrete calls
for every type/marker pair; public method bodies are unchanged. The failed build,
original probes/runner and diagnostics are retained separately. An initial
formatter invocation omitted pinned VEXE and was stopped; final formatting uses
the pinned environment. Final comparison bodies stay frozen; only expected
assignments change after ordinary discovery.

Fixtures copy/hash the exclusive-payload and descriptor-replacement helpers,
use initialized unlinked owned O_EXCL/CLOEXEC files with reset offsets and owned
nonblocking pipes/keepers. Parent-side lossless compression pins raw/compressed
logs. Independent replay checks records, classifications, exact retained failure
state, consumers, ownership, binaries, modes and provenance. Retained evidence
is persisted from an owned RAM workspace; every archive member is read back
before commit and release.

Native integer elements and aliases are supported. Source aggregate-field
swapping, arbitrary-width integers and endian-dependent support for other types
remain outside this mapping. V's nested generic caller code-generation limit
remains documented; the concrete API calls compile in both modes. Other callbacks,
input/output overlap, arbitrary constructor/copy sequences, other devices,
larger arrays/offsets, concurrent reuse, syscall counts, timing/signals, injected
errors, OOM/quotas, allocator lifetime and portable ABI remain boundaries.
Runtime comparison uses little-endian 64-bit macOS; Windows/Linux and other CPU,
big-endian and 32-bit runtime are outside the proof. Cross builds establish
compilation only.
