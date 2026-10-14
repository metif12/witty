# Borrowed fixed byte arrays

`ReadStream.peek_array[A]()` and `take_array[A]()` translate pinned
Reader.peekArray/takeArray. A selects an inline or directly named fixed byte
array. The returned `ReaderArray[A]` record holds its borrowed pointer in `value`.
Peek leaves the logical position unchanged; take advances only after a complete
array is available. EOF/ReadFailed retain the fill's buffered progress without
consuming a short prefix. Memory EOF can precede a capacity trap; file capacity
traps stay active in production. Existing reader and C adapter bodies are unchanged.

```v
type HeaderBytes = [8]u8
mut header := reader.take_array[HeaderBytes]()!
first := (*header.value)[0]
unsafe { (*header.value)[1] = first }
```

The pointer aliases reader storage. Caller-buffer writes are visible through it,
and pointer writes update the original buffer. Tossing buffered input does not
invalidate it; subsequent fill/peek/take operations can overwrite/rebase storage.
Keep the reader and backing buffer alive. The V record is an adaptation of
Source's fallible pointer result: pinned V generates invalid C or incorrect
copy code for a direct `!&A` return. The record preserves the borrowed pointer.

Inline arrays and a directly named fixed array are supported, including arrays
whose byte element is an alias of u8. Chained array aliases hit pinned V's
one-level type reflection and are rejected. V cannot represent zero-length fixed
arrays; Source supports zero-length array reads without IO. Ten translated type
rejections and two Source acceptance/run controls per mode document these
boundaries separately from equivalent runtime cases. Other rejected V types
include dynamic arrays, scalars, strings, wider elements, pointer elements,
nested arrays, pointers to arrays and structs with a len field. The generic
shape value is initialized to derive its length/type; larger shapes and scratch
storage limits are outside the finite proof.

## Reproduce

```sh
python3 zigimg/verify_reader_array_reference.py "$SOURCE" "$ZIG" "$V" --workdir /path/to/empty/ordinary
python3 zigimg/verify_reader_array_reference.py "$SOURCE" "$ZIG" "$V" --v-prod --workdir /path/to/empty/production
```

Source is zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`, Zig 0.15.2 and
V 0.5.2. Ordinary pairs Debug with V ordinary; production pairs ReleaseSafe with
V `-prod`. Target defaults to `aarch64-macos.14.0`. VEXE and
V_C_ERROR_BUG_REPORT_DISABLED=1 are pinned and temporary paths/caches are owned.
Full unchanged Source tree SHA-256:
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected stdlib SHA-256:
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Versions, selected math/simd/path libraries, implementation, probes, shared
fixtures, directly imported helpers and inputs are checked before/after.
Source bodies, visibility and reader syscalls remain untouched.

## Returning and borrowed records

Both modes match **20,448 returning records / 61,344 array reads / 81,792
primary calls**. Three array reads and one relative seek run per record;
setup/priming/observations are separate. Groups contain 16,032 basic, 1,536
every-byte and 2,880 replacement profiles, with duplicate inputs retained once.
Output SHA-256 (joined lines without a trailing newline):
`4af50e662a770575ff766e3f9137b20ece1f8064feccb3c0a69581104f71de84`.

Six lengths 1/2/4/8/16/32 run as inline and directly named arrays; a two-byte
array uses an aliased byte element. Memory, positional and streaming files cover
lengths 0/1/7/8/9/31/32/33/64, start/EOF offsets, reader capacities from 1 through
33, complete/partial fills and relative seek -1/0/1. Every byte runs both APIs
through all reader kinds. Controlled descriptor replacement retains original
read-ahead through open/closed owned pipes, capacities 8/32, seed boundaries,
consumption 1/7 and priming/toss choices.

Snapshots compare complete reader storage, copied successful result bytes,
pending spans, logical positions, size/errors, owned references and untouched
wire bytes. Failed operations leave the previous copied result unchanged.
An independent nonreplacement model checks values, progress and EOF, tracking
physical streaming reads separately from logical/buffered rewind.

The additional **1,252 borrowed records / 2,504 primary calls** compare pointer
offsets into the original buffer, saved copies, caller-buffer XOR, pointer XOR,
positions and retained pointer bytes after toss. Returned pointers always lie
inside the supplied buffer and have the exact requested span. Both mutation
directions agree with Source. Borrowed output SHA-256:
`ed6c6c1edd1c60be14f9057f523ac3fb1c4453fa60c3cc1eb2b92a471bed5e20`.

Input fields are
`kind|api|capacity|start|array-type|payloadhex|replacement|consumed|seed|prime|delta`.
API 0 peeks and 1 takes. Types 0–5 are inline lengths 1/2/4/8/16/32, 6–11 are
their directly named equivalents, and 12 uses two aliased bytes. Seven returning
parts contain initial/primed state, three array reads, relative seek and wire
bytes. Snapshots use
`status|position:size-or-error:valid:refs|readerhex|copied-resulthex|pendinghex`.
Borrowed records have five phases: initial, borrow, caller mutation, pointer
mutation and toss; the last four append borrowed bytes and buffer offset.

## Controls and verification

The **120 controls** separate **40 returning records**, SHA-256
`0756cb0fb62009cfbae066f6cd123be94d8afaa53da082ff8acca7477fbcb698`,
from **80 exact panic/state pairs**, SHA-256
`9e6705adab9ebaa5651b59e38100d7ac7ff6983acc90265be3ef03763c6d323d`.
They cover undersized/empty reader buffers and checked getPos after a failed
priming transition. Native classification determines which cases return and
which trap. Both failed exits have empty stdout, one exact message and matching
initialized state. Observers omit getPos, capture bytes before opening state
files, and clean up only owned resources through Source FullPanic or V at_exit.

Sixteen compiled consumer records / 48 reads / 64 primary calls per mode assert
peek/take positions, named/element aliases, high bits, first/later short reads,
rewind, read-ahead, partial refill and sticky buffered success/failure. SHA-256:
`a80364ab584e75647c85ba2415bfb1774be9873b69354de2895f859c07d24ab2`.
Three public regressions accompany the proof. All 76 image test files pass in
four batches, with 17 production/application/Windows/Linux checks. Vaxis runtime
sources/tests are unchanged and were not rerun here; its dependency builds pass.
Historical buffered-reader and full-stream matrices keep their hashes in both modes.

## Evidence and scope

Development diagnostics retain pointer-index syntax mistakes, chained-alias
rejection, invalid C from inline generic array construction/pointer casts and
incorrect direct pointer-result copy code. The final API returns a record with
the pointer, uses a named shape local and tests real input mutation. Compile
boundary fixtures use named candidate types to avoid unrelated generic parser
errors for pointer elements. A preformat ordinary comparison passed; final
ordinary/production comparisons reran after formatting the Zig fixture, with
identical hashes. Original fixtures/scripts/outputs remain separate from passing
gates. Final bodies stay frozen; only expected assignments change after ordinary
discovery.

Fixtures copy/hash the exclusive-payload and descriptor-replacement helpers,
use initialized unlinked owned O_EXCL/CLOEXEC files with reset offsets and owned
nonblocking pipes/keepers. Parent-side lossless compression pins raw/compressed
logs. Independent replay checks values/progress, mutation/alias behavior, native
classifications, exact failure state, consumers, ownership, binaries, modes and
provenance. Evidence is persisted from an owned RAM workspace and every archive
member is read back before commit and release.

Arbitrary constructed/copied result records, pointer use after an invalidating
read, other callbacks/devices, larger arrays/buffers/offsets, concurrent reuse,
syscall counts, timing/signals, injected errors, OOM/quotas, allocator lifetime
and portable ABI remain boundaries. Runtime comparison uses little-endian
64-bit macOS; Windows/Linux and other CPU, big-endian and 32-bit runtime are
outside the proof. Cross builds establish compilation only.
