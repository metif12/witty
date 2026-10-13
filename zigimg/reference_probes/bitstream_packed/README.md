# Packed RGB bit-stream contracts

The public bit-stream APIs now accept `Rgb332`, `Rgb555`, `Rgb565`, `Bgr555`,
and their aliases. They reinterpret the logical packed word as in pinned Source.
RGB555/BGR555 use a 15-bit working value: reads truncate at each packed shift/OR,
and writes ignore the wider V raw carrier's padding bit. Shift 15 retains
`shift amount is greater than the type size`; larger shift arguments retain
`integer does not fit in destination type`. Checks remain active in production.

`verify_bitstream_packed_reference.py` uses the shared
[bit-stream fixtures](../bitstream_contracts/README.md). Packed dispatch and
raw-word observation are added alongside existing native scalar and boolean
specializations. The Source implementation and visibility remain unchanged.
Ordinary V compares with Source Debug, and production V with Source ReleaseSafe,
on `aarch64-macos.14.0`.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_bitstream_packed_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/proof-directory
```

Every logical packed value is read and written: 256 RGB332 values, 32,768 values
for each 555 type, and 65,536 RGB565 values. The dense domain alternates endian
order by value. Separate boundary, continuation and seeded random matrices
instantiate all four types, their aliases, both endian orders and endian aliases.
They cover all read APIs, copied bit buffers, borrowed streams, caller input
mutation, partial EOF, buffering, oversized requests, capacities, output padding,
continuation and repeated flushes. Wider V raw words in writer fixtures map to
Source's explicit truncation to the packed integer; the 555 padding bit is never
observed as Source payload.

The model only partitions returning cases and failures. Compiled unchanged
Source supplies every compared result and snapshot. Failure snapshots retain
action index, stream positions, bit buffer/count, initialized output-count
argument, complete current input and output initialized to `0xa5`. Each strict
pair requires the exact diagnostic, an unsuccessful exit, no stdout, identical
nonempty snapshots and no core dump. Forty-eight accepted consumer pairs cover
all four types and aliases with both endian markers and a marker alias.

Both corresponding modes match **273,066 returning/error records** and **567
exact failure/state pairs**. Return SHA-256 is
`d39aa4c766ca640e07beda5a21f1ea596762ea6761fd085d1951eba159eafd98`; state SHA-256 is
`4f357b8f6c9d5c4f42e145368dbf10de2ec446c0ed0f44ff9f55b1d585d8c6f5`.

| Returning observations | Count |
| --- | ---: |
| Every packed word, read and written | 262,656 |
| Read boundaries and aliases | 4,240 |
| Buffered reads | 924 |
| Writer boundaries | 786 |
| Continuation and borrowed input | 256 |
| Writer copies | 108 |
| Seeded random reads and writes | 4,096 |

Strict failures comprise 511 checked casts, 36 mask-index failures, and 20 shifts
that fit the u4 argument but exceed the u15 working type. The same operation and
working width share a strict failure representative across equivalent type/alias
specializations; returning specializations remain independently instantiated.

The native-scalar comparison retains 136,889 returning records and 1,064 exact
failure/state pairs in both modes. The boolean comparison retains 22,849 returning
records and 1,049 exact failure/state pairs in both modes. Their previous return
and state hashes remain unchanged. All 61 image and 58 Vaxis test files pass.
Twenty-three production/platform checks pass, including production bit-stream,
compression and decoder tests, native/Linux application checks, three Windows
dependency libraries, two Linux shared libraries, and Windows/Linux builds of
the extended fixture. Cross builds establish compilation coverage.

Two historical production V builds exceeded their 180-second compile limit.
Their attempts are retained; both comparisons passed after increasing only the
command timeout to 600 seconds. Compiler options and implementation stayed fixed.

Complete Source SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Compiler versions and before/after Source/library/implementation/runner/shared
model/fixture/input/consumer hashes protect the retained comparison. Arbitrary
packed caller types, other non-native integer widths, undefined native padding,
physical layout, arbitrary endian types, generic required-field enforcement,
u4 field typing, underlying std.Io interfaces, allocation/lifetime,
file-platform runtime and portable ABI remain boundaries.

Artifacts are retained at
`/Users/alex/.cache/witty-bitstream-packed-20261013/verified-proofs.tar.gz`, with
checksum, per-file manifest and complete read-back verification.
