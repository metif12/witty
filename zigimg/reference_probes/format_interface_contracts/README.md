# Mutable codec callbacks and exact encoder-option failures

`verify_format_interface_contracts_reference.py` imports unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` and compares Source Debug with ordinary
V, then Source ReleaseSafe with production V:

```sh
python3 zigimg/verify_format_interface_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default native target is
64-bit little-endian `aarch64-macos.14.0`, linked with libc. `--timeout` bounds
commands; `TMPDIR` and `VTMP` select compiler temporaries. Retained artifacts
include the unchanged complete Source tree, fixtures, binaries, corpus, panic
snapshots, compiler consumers, commands and provenance.

FormatInterface's three required callback fields are mutable in mutable records.
Copied records retain independent callback choices. Complete construction and
three field replacements compile in both languages; three separate omissions
and three constant-record mutations reject in both compilers. Function addresses,
record layout and allocator arguments are not compared: V's GC API omits Source's
allocator parameter for read/write callbacks.

Both modes match **43,200 returning/error records**. Each of the three callback
fields selects one of three implementations. Eight replacement masks cover every
field subset. Four copy/mutation controls replace callbacks in the original or
copy and dispatch through either record. Five input lengths, five destination
capacities and two starting-position controls exercise successful callbacks,
EOF, explicit InvalidData, partial writes and writer exhaustion. Encoder-option
tags cover all 17 formats. Callback traces, boolean/image/error results, reader/
writer positions, initialized image fields and full input/output bytes are
compared. Each returning record uses three calls through a single chosen record;
the observed stream remains shared between those calls.

Return SHA-256: `64ea2c6c5dcf3d0539e780a5acf86c390c3a35cd0c321f61202bec27d59c69dd`.

**1,024 exact panic/state pairs** cover PNG and TGA against all 16 incorrect
encoder-option tags, four image profiles, four output capacities and two initial
writer-position controls. Profiles include invalid storage, initialized RGB24,
initialized grayscale8 and zero-height RGB24. Diagnostics name the accessed and
active union arms exactly. The snapshot observes width, height, pixel-format tag,
all active initialized pixel bytes, writer position and complete initialized
output. It confirms option-tag failure precedes image validation or output.
Each pair requires a failing exit, the exact diagnostic, no stdout, a nonempty
matching snapshot and no core dump. State SHA-256: `a5ec291c7761806756669c623761e922bef79b0349f448b0dd7f482f6a8c8c4e`.

The unchanged historical writer fixture also matches **49,344 returning/error
records** in both modes, retaining SHA-256
`578f0de4bdaac7c2b67f294de64a2694c069cbb2fde6d2c43ca68494c6ca94eb`.
That matrix covers all 17 actual codec factories, every returning option-tag
combination, eight storage profiles, three option variants and eight destination
capacities. The new returning matrix uses custom callback implementations to
measure record mutation independently of codec behavior. Neither fixture changes
Source visibility or implementation.

All 61 image and 58 Vaxis test files pass, together with production interface/
PNG/TGA/image-API tests, historical image-API/GIF/compression assertions in both
modes, native/Linux application checks, three Windows DLLs, both Windows interface
test executables and two Linux shared libraries. Cross builds establish build
coverage only.

Callback closures, arbitrary callback implementations, null/dangling function
pointers, function identity, allocation/OOM/deinit/lifetime, file-platform runtime,
physical layout and portable ABI remain boundaries. Encoder-option sum-type
payload copies retain the previously recorded V boxed-storage limitation. Native
u5 Format typing, V's wider enum carrier and pinned-source encoder compile
boundaries remain documented in the audit. No encoder algorithm is changed here.
The snapshots omit undefined/private storage, palettes and allocator internals.

Complete Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Before/after dependency/fixture/input/consumer/runner/implementation hashes and
compiler-version pins protect the proof. Development compiler attempts and the
panic-fixture formatting correction remain in the retained artifacts.
