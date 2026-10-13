# Bit-stream endian contracts

Bit streams require `BigEndian` or `LittleEndian`, including direct aliases of
those marker types. The pinned Source type factories accept only the two values
of `std.builtin.Endian`. V previously accepted an unrelated marker in
`align_to_byte()` and `flush_bits()`; flushing silently followed the little-endian
path. A shared compile-time check now protects reads, writes, alignment and
flushes, including zero-bit operations. The compiler also checks bare reader and
writer construction by instantiating its alignment/flush methods.

`verify_endian_contracts_reference.py` imports the complete unchanged Source
implementation at its original visibility. Ordinary V compares with Source
Debug, and production V with Source ReleaseSafe, on `aarch64-macos.14.0`.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_endian_contracts_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/proof-directory
```

Both modes match **71,680 returning/error records**, SHA-256
`4151f02c6b6aca387075822982c0d3d48dac17eeeb1602a6c2014d07178ffb2c`.
The matrix covers all 256 buffered byte values, both endian markers and their
direct aliases. Its 16,384 alignment records cover every Source u4 count, repeated
alignment, independent copied metadata, shared stream identity and seeking
without consuming input. Its 55,296 flush records cover counts 0..8, capacities
0/1/2, repeated flushes, exact padding, successful/failed output, retained bits
and count, copied metadata and borrowed writer identity. Pointer identity is
observed as booleans rather than process-dependent addresses.

Twenty-four accepted operation pairs cover all six public operations with both
markers and direct aliases. Forty-two rejection pairs cover unrelated records,
record aliases, integer/boolean types, marker pointers, pointer aliases and named
fixed arrays. Two further pairs reject bare invalid reader/writer records.
Rejections require ordinary compiler errors with the expected diagnostic and
exclude compiler crashes, backend failures and link failures. No invalid marker
is executed after the change.

Six controls measure the pinned V compiler's second-alias-layer limitation:
Source accepts the corresponding endian choice while V rejects `NestedBig`.
Existing read/write branches already rejected such aliases; the new check
consistently rejects them in alignment and flushing as well. Arbitrary alias
chains, generic required-field enforcement, u4 field typing, physical layout,
underlying std.Io interfaces, allocation/lifetime, file-platform runtime and
portable ABI remain boundaries. This proof covers the represented public
operations and constructors, rather than every unused type declaration.

All 61 image and 58 Vaxis test files pass. Seventeen production/platform checks
pass, including production bit-stream/LZW tests, native/Linux application checks,
three Windows dependency libraries, two Linux shared libraries, Windows
bit-stream tests and Windows/Linux builds of the new fixture. Cross builds
establish compilation coverage.

Complete Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Compiler versions and before/after Source/library/implementation/runner/fixture/
input/consumer hashes protect the proof. The before-change invalid-marker binary,
consumer-development diagnostics and fixture revisions are retained.

Artifacts are retained at
`/Users/alex/.cache/witty-endian-contracts-20261013/verified-proofs.tar.gz`, with
checksum, per-file manifest and complete archive read-back verification.
