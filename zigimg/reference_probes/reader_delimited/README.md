# Nullable delimiter lines

`verify_reader_delimited_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` and Zig 0.15.2 with V 0.5.2.
Source's public `ReadStream.reader().takeDelimiter` returns an error union
containing an optional byte slice. V's `take_delimiter` returns
`!DelimiterResult`, whose public `line ?[]u8` field carries the optional slice.
The pinned V compiler rejects direct `!?[]u8` syntax; that rejection and the
working record representation are retained as separate compiler controls.

```v
result := reader.take_delimiter(`\n`)!
if line := result.line {
    println(line.bytestr()) // A present line can be empty.
} else {
    // End of input; this successful result has no line.
}
```

Found delimiters are consumed and omitted from the borrowed result. Consecutive
delimiters therefore yield successive present empty lines with advancing
positions. EndOfStream supplies a nonempty pending tail once; later EOF calls
return an absent line. ReadFailed and StreamTooLong remain errors. A full file
buffer without a delimiter reports StreamTooLong even when the file ends there.
The existing inclusive and exclusive methods are unchanged.

```sh
python3 zigimg/verify_reader_delimited_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. Pairs use Source Debug / V
ordinary and Source ReleaseSafe / V production. Native target defaults to
`aarch64-macos.14.0`. `--timeout` bounds commands. VEXE is pinned; each proof uses
owned temporary and compiler-cache directories.

| Returning comparison per mode | Records | Primary calls |
|---|---:|---:|
| Memory, positional files and streaming-initialized regular files | 15,288 | 61,152 |
| Original-file read-ahead followed by controlled pipe replacement | 9,764 | 29,292 |
| Additional returning position controls | 264 | 792 |
| Exact getPos overflow / retained-state pairs | 216 | Separate failed outcomes |

The first matrix includes the previous 12,480 reader/API/capacity/offset/delimiter
profiles plus 2,808 consecutive-delimiter and EOF-tail profiles. It covers file
capacities 0/1/2/4/8/32; arithmetic payload lengths 0/1/7/8/9/31/32/33/64; empty
input, newline-only input, adjacent newlines, leading/trailing newlines and
unterminated text; distinct zero/one/half-length/end offsets; present/absent
markers, all delimiter bytes and relative offsets -1/0/1. Each record performs
three takes and one relative seek. The two V caller forms use the owning stream
and its borrowed `reader()` adapter; both map to the same Source reader API.
Memory uses its full input and the capacity axis repeats those memory cases.
Complete initialized buffers, copied results, pending bytes, positions,
size/error outcomes and ordered ok/none/error statuses match. SHA-256:
`c515a79be9e86bda0a1e8c84455f8343f99c78128d3b356fc656a65c36ab326b`.

The replacement matrix retains 7,740 ordinary-transition, 756 failed-pending,
756 failed-consumed and 512 every-delimiter profiles. It compares two takes and
one relative seek per record, including preserved original bytes, sticky
failures, EOF/WouldBlock, optional reseeding, ownership and queued input.
SHA-256: `0bcfe7c177570bee75574d1160eaa4298e24e0cea0ff04c57163b3be74007441`.

Native classification separates 264 returning controls, SHA-256
`e953ff96c5268780593e0fe6c4cb318a897ad823e9ce45f3527aa234c80f9b4a`,
from 216 exact integer-overflow pairs, SHA-256
`87f6fa3b0a377a66c68d279ebaee77ae5448782e91bdfdbf94d73dae93f8a6c0`.
Those panics occur in a subsequent getPos query after ReadFailed. Observers omit
getPos and record the preceding status before opening their state files.
Failed exits, empty stdout, one exact diagnostic and matching nonempty
initialized state are required. Null and present-empty outcomes are separate
statuses; a saved result remains unchanged on a later null/error outcome.

The fixture wrapper reuses the separately hashed
[exclusive payload setup](../reader_exclusive/README.md) and
[delimiter replacement fixture](../reader_delimiter/README.md). Setup creates
unlinked O_EXCL/CLOEXEC initialized regular files, rewrites/truncates owned
payloads and resets their live offset before reader construction. Owned
nonblocking pipes support replacement, reseeding and EOF. No Source body,
visibility or reader syscall is changed or intercepted. Normalized descriptor
observations exclude raw identities and concurrent replacement races.

Separate compiled consumer records compare both directions of borrowing: a
caller backing-byte mutation changes the result, and a mutable result-byte
mutation changes the caller storage. Both caller forms, memory and positional
files, and all 256 delimiters produce 1,024 matching records / 1,024 calls per
mode. SHA-256:
`9bd964bc7e08795f686f3d2ffbf9c4a6ed34e552182536fe5ae514e81ecffeb9`.
V requires explicit `unsafe` when extracting a mutable alias from the
readonly optional field; its original compiler rejection is retained. For such
an alias, use `mut line := unsafe { result.line or { panic('Expected line') } }`.
Cloning instead produces an independent array. None/empty/read-error distinctions
and normal readonly extraction use ordinary V syntax. Source error-union/option
layout, type identity and V mutable-extraction rules remain adaptations.

Full Source, selected compiler libraries and versions, production implementation,
probes, both shared headers, direct imported helpers and corpus bytes are hashed
before/after comparison. Only golden assignments change after ordinary discovery.
Raw commands, binaries, output, diagnostics, panic state, provenance and summaries
are retained. Large stdout logs can be losslessly compressed in parent-side
logging, with raw-byte and compressed hashes verified on replay. Independent
replay checks outputs, native classifications, failure state and actual modes;
persistent archives are read back member by member.

Existing exclusive/inclusive delimiter and full stream hashes remain unchanged
in both modes. Unit regressions cover delimiter consumption, present empty
lines, a single EOF tail, repeated absent results, live borrowing and capacity
failures. Module tests and platform build checks pass; cross builds establish
compilation only.

Other devices, larger requests/offsets/buffers, arbitrary carrier construction,
copy and callback sequences, concurrent reuse, syscall counts, timing/signals,
injected errors, OOM/quotas, allocator lifetime, portable ABI, V representation
limits, Windows runtime, other CPU selections and big-endian/32-bit runtime remain
boundaries.
