# Native bit-stream contracts and exact failure state

`verify_bitstream_contracts_reference.py` imports unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`. It compares Source Debug with ordinary
V and Source ReleaseSafe with production V:

```sh
python3 zigimg/verify_bitstream_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default native target is
64-bit little-endian `aarch64-macos.14.0`, linked with libc. `--timeout` bounds
commands; `TMPDIR` and `VTMP` select compiler temporaries. Retained artifacts
include the unchanged complete Source tree, fixtures, binaries, generated inputs,
outputs, compiler consumers, commands and provenance.

The represented stream pointers carry required markers and all translated callers
initialize them explicitly. The pinned V compiler accepts omission in these
generic records, including real endian aliases; these four controls are measured
adaptations, not constructor-enforcement claims. Two further controls show V
accepting count 16 where Source's u4 count rejects it. Complete reader and writer
constructors pass both compilers.

The native scalar operations now retain exact Source cast, arithmetic and mask
bounds diagnostics. Reader failures preserve byte consumption, buffered fields
and the caller's untouched out_bits slot. Writer count subtraction, scalar
shifts, byte shifts and flush failures preserve Source order. The checked count
addition guards before assigning the u4 result, after updating bits. Its overflow
is unreachable through the compared public native-width operations; this proof
does not manufacture a private addBits observation.

Both modes match **136,889 returning/error records**:

| Returning records | Count |
|---|---:|
| All byte values over buffered short reads and three read APIs | 61,440 |
| All byte values over buffered writes, capacities and flushes | 61,440 |
| Native/alias reader widths and partial/oversized EOF | 6,132 |
| Native/alias writer widths and short output | 3,576 |
| Returning public reader-count controls | 168 |
| Returning public writer-count controls | 99 |
| Returning flush/retry controls | 50 |
| Alignment over every representable count | 32 |
| Reader continuation, copy, seek and caller mutation | 1,152 |
| Writer continuation, copy, seek and retry | 1,104 |
| Signed/integer/float bit reinterpretation | 1,120 |
| Initial stream cursors | 576 |
| **Total** | **136,889** |

Return SHA-256: `bf6c23faab2083f34c10fb5dbfc8c5422e967f13cb0d31f3c7e505d516c18108`.

**1,064 exact panic/state pairs** cover 415 narrowing casts, 520 arithmetic
failures and 129 mask-index bounds. Diagnostics, case names and complete snapshots
join SHA-256 `211259eb01a70a32820bfdd8b016c1c9056e97102ab9dda787acc2b130627a66`.
Every strict pair requires the exact diagnostic, an unsuccessful exit, no stdout,
a nonempty identical snapshot and no core dump. Snapshots include action index,
both stream cursors, bit-stream bits/count, the initialized out_bits slot,
complete current input and output storage initialized to 0xa5.

Returning cases instantiate u8/u16/u32/u64, i8/i16/int/i64, usize/isize, f32/f64
and twelve real V aliases, with native and aliased endian markers. Patterns include
negative integers, signed zero, infinities and quiet/signaling NaN bits. Counts
cover Source's entire u4 domain; read/write requests include native-width
boundaries and 65,535. Identical strict operations use one unsigned-carrier
representative per width/endian, because Source computes all same-width scalar
operations through that carrier. Returning specializations remain independent.
The Python model only partitions cases; unchanged compiled Source supplies every
compared record and failure snapshot.

Copies preserve independent bits/count and a shared live stream pointer. Seeking
does not align buffered bits. Caller input is mutated before re-reading through
the borrowed stream. Partial readBits updates out_bits on successful EOF;
readBitsNoEof reports EndOfStream after consuming available input. Failed scalar
shifts occur at their Source byte/writer boundary, and repeated flushes preserve
their padding mutation. Only initialized public state is observed; private copied
scratch, empty pointer identities and allocator state are excluded.

The existing 37,133 stream records and historical compression assertions retain
their results in both modes. LZW's 22,016 returning and 3,772 exact failure/state
pairs retain both hashes. TIFF/PNG regression hashes remain unchanged. Native
module tests and platform build checks pass; cross builds provide build coverage.

The [boolean extension](../bitstream_bool/README.md) separately covers bool and
its V aliases, including checked one-bit results.

Source's non-native scalar widths, packed values, u4 field typing, required
marker enforcement, underlying std.Io interfaces, allocation/GC/lifetime/OOM,
file-platform runtime, physical layout and portable ABI remain boundaries.
Source visibility and implementation are unchanged. Complete Source-tree SHA-256
is `ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Version and before/after dependency/fixture/input/consumer/runner/implementation
hashes protect the retained proof.
