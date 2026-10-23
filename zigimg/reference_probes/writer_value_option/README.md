# Optional Writer value dispatch

`WriteStream.print_value` accepts a leading `?` format for an optional, removes
one marker and formats the present payload with unchanged options and depth.
`any` forwards `any` to the payload. An absent value writes aligned `null` and
ignores precision without visiting the child. Arrays and records consume depth;
optional unwrapping does not. Each existing leaf/container write remains distinct.
Global `*` dispatch retains the optional pointer prefix (`*u32@28`), while `?*`
formats the present pointer (`u32@28`).

The native fixture calls the original public Zig 0.15.2 Writer.printValue body
without modifying Source or visibility. Present/absent i64, u64, bool, borrowed
bytes, enums and records with optional integer/byte fields, plus aliases, run as
scalars, dynamic slices and nested dynamic slices. Extrema, depth, propagated
leaf options and every capacity through 96 bytes cover partial writes and traps.
The portable fixture adds f32/f64, fixed arrays (including optional byte
elements), optional slices and pointers.

Five snapshots retain backing, position, pending/unused views and headers,
descriptor state, inputs/options, actual present scalar bytes and file/wire
contents through caller backing mutation and flush. Memory, positional/streaming
files, replaced pipes and closed descriptors are covered. Presence and leaf
bytes exclude optional padding and slice descriptors; shape names describe
construction and do not prove every copied value or nested descriptor layout.
An independent Python model predicts output, individual writes and retained state.

Debug/ordinary and ReleaseSafe/production each compare 18,735 returning records,
342 isolated returning controls and 90 exact panic/state pairs. There are 5,362
independently predicted WriteFailed states in the main corpus and 206 among the
returning controls. Traps enforce enum/base64 option restrictions only when
traversal reaches the present payload; earlier write failure, absence or depth
cutoff can prevent them. Each trap requires one exact diagnostic, empty stdout
and matching retained state, including production. Both modes retain these hashes:

| Observations | Count | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 18,735 | `bc7578b664806fff2ec769d8f63c59e78fc92d2bb82008443496958bfcfd581f` |
| Isolated returning controls | 342 | `529c4e62ee0e24ff778c70898820f68dce02774a3634304430016aed20178338` |
| Panic/state controls | 90 | `db0eb864899dc0e741a29b190391f7286521964d4081233de76d4bd6393fa5c4` |

Twenty-one external compiler pairs per mode cover eight accepted consumers,
three paired ordinary argument rejections and measured differences. Source
requires compile-time formats and validates child formats even for absent
values. V accepts runtime formats, rejects unsupported outer formats before
writer effects and validates child formats when present. Thus absent `?q` writes
`null` in V but is rejected by Source. Optional pointer `any` at depth zero
prints an address in Source and returns a pointer-format error in V. Broader
pointer payload recursion/coercions, optional void pointers, nested optional
representations, error unions, unsupported field carriers, custom invocation,
tuples and full Writer.print remain unported or unproven.

V 0.5.2 requires explicit indexed generic forwarding for mixed optional array
specializations. Fixed optional byte elements must precede the raw-byte trait
check, which otherwise strips their optional flag. An or-block unwraps each
runtime payload. Optional pointer formatting keeps the optional carrier in a
dedicated helper because forwarding an unwrapped generic pointer otherwise
takes its address. The observer uses
concrete optional array payloads: generic optional loop locals can otherwise
generate invalid C or copy from the wrong offset. Construction appends values
from a generic optional-returning helper; a generic optional array initializer
can cache the wrong payload type. These fixture workarounds observe actual
values without interpreting V's private optional layout.

Six public regressions, all 115 image test files and 21 production/application /
Windows/Linux commands pass. Portable consumers run natively in both modes and
compile for Windows in both modes and Linux. Cross builds establish compilation
only. Historical primitive, recursive slice, fixed-array, enum, record and
address comparisons retain their previous hashes in both modes. Vaxis source
is unchanged and dependencies build; its runtime tests are not rerun. Leaf
formatter helpers, IO and C are unchanged; Ryu tables retain all 1,336 limbs.

Whole Source and selected compiler libraries, Io/fmt/math/meta/enums/base64 /
float/path/encoder pins, versions, implementation, models/helpers, fixtures and
inputs are checked before and after. Runtime, fixtures and model bodies freeze
before final comparisons; only six EXPECTED assignments change from discovery.
Retained observations, controls, compiler outcomes, modes and provenance are
replayed independently. Large command output is compressed losslessly by a
separately pinned wrapper. Every archive member is read back before committing;
development evidence stays separate.

Evidence is pinned little-endian 64-bit macOS. Other runtime widths/platforms,
invalid descriptors, injected short devices, concurrent mutation, huge successful
output/storage, private allocation and lifetimes remain boundaries.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_writer_value_option_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session evidence: `/Volumes/codex-fullsuite-20261023/witty-writer-value-option-20261023/verified-proofs.tar.gz`,
with checksums, a per-file manifest and full member readback. Regenerable caches
are excluded.
