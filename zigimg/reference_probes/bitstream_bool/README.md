# Boolean bit-stream contracts

The pinned public `BitReader` and `BitWriter` support `bool` through a one-bit
integer bitcast. V now accepts `bool` and its aliases in all three read APIs,
tuple reads, and writes. Source computes sub-byte values in an eight-bit unsigned
carrier, so read/write shift behavior remains the existing byte behavior. Reads
check conversion to a one-bit result after consuming input and updating buffered
bits. A result above one traps with `integer does not fit in destination type`;
this check remains active in production.

`verify_bitstream_bool_reference.py` uses the shared
[bit-stream fixtures](../bitstream_contracts/README.md), with boolean dispatch
added beside their existing native scalar specializations. The imported Source
implementation and visibility are unchanged. Ordinary V compares with Source
Debug, and production V with Source ReleaseSafe, on `aarch64-macos.14.0`.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_bitstream_bool_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/proof-directory
```

Returning cases cover every input byte, all three read APIs and tuple/copy reads,
zero/one-bit requests, buffered bits, EOF, padding, capacities, oversized writes,
repeated flushes, continuation, independent copied bit buffers, borrowed streams,
caller input mutation, and native/aliased boolean and endian types. Failure cases
cover oversized reads, one-bit result conversion, shift checks, buffered reads,
short writes and flush retries. The Python model only partitions cases; compiled
unchanged Source provides every compared result and snapshot.

Snapshots retain action index, reader/writer positions, bits/count, the initialized
output-count argument, complete current input, and output initialized to `0xa5`.
Each failure pair requires the exact diagnostic, an unsuccessful exit, no stdout,
identical nonempty snapshots and no core dump. Twelve accepted consumer pairs
exercise booleans and aliases with big/little endian markers and a marker alias.

Both modes match **22,849 returning/error records** and **1,049 exact failure/state
pairs**. Return SHA-256 is
`8621064b96eb5c32c47a381bfb9d81c9807d3bbb670bc296a66d9da69468d838`; failure/state
SHA-256 is
`96601684c22c4529d17c5181d5a2796a3c118b97778b8f4032302a31f7287413`.

| Returning observations | Count |
| --- | ---: |
| Every input byte and zero/one-bit read APIs | 16,384 |
| Buffered booleans and EOF | 440 |
| Oversized read and shift controls | 224 |
| Buffered narrow-result controls | 153 |
| Boolean writes, padding and capacities | 5,376 |
| Reader continuation and copies | 128 |
| Writer continuation and copies | 144 |

Every strict failure has the checked cast diagnostic. The model uses Source's
eight-bit working carrier and checks one-bit conversion at the final read return;
the proof observes the actual native failure rather than substituting model
state. Duplicate failure specializations share an identical operation and working
carrier; all returning boolean/endian alias specializations remain instantiated.

The existing native-scalar matrix retains **136,889 returning/error records** and
**1,064 exact failure/state pairs** in both modes, with its previous return hash
`bf6c23faab2083f34c10fb5dbfc8c5422e967f13cb0d31f3c7e505d516c18108` and state hash
`211259eb01a70a32820bfdd8b016c1c9056e97102ab9dda787acc2b130627a66`.
All 61 image and 58 Vaxis test files pass. Twenty-three production/platform checks
pass, including production bit-stream/LZW/CCITT/TIFF/PNG-reader/image-API tests,
native/Linux application checks, three Windows dependency libraries, two Linux
shared libraries, and Windows/Linux builds of the extended fixture. Cross builds
establish compilation coverage.

Full Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Compiler versions and before/after Source/library/implementation/runner/shared
model/fixture/input/consumer hashes protect the retained proof. Boolean physical
layout, packed caller-defined values, non-native integer widths, arbitrary endian
types, generic required-field enforcement, u4 field typing, underlying std.Io
interfaces, allocation/lifetime, file-platform runtime and portable ABI remain
boundaries.

Artifacts are retained at
`/Users/alex/.cache/witty-bitstream-bool-20261013/verified-proofs.tar.gz`, with a
checksum, per-file manifest and complete archive read-back verification.
