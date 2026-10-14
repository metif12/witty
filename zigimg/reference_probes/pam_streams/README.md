# PAM file buffers and output retained before flush

`verify_pam_streams_reference.py` compares the unchanged public PAM methods in
zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`. Source Debug is paired with
ordinary V, and Source ReleaseSafe with production V.

```sh
python3 zigimg/verify_pam_streams_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. Native execution uses
`aarch64-macos.14.0`, Zig 0.15.2 and V 0.5.2. Each work directory retains copied
unchanged Source, fixtures, binaries, commands, outputs, input/provenance hashes,
panic snapshots and a JSON summary. Compiler caches are task-owned; the runner
pins VEXE and suppresses automatic C-error reports.

The previous V header writer combined comments and numeric fields into larger
writes. Source's `Writer.print` emits each literal and argument separately. The
combined writes changed the borrowed caller buffer and pending output, including
bytes already visible on disk before flush or a later pixel failure. The V header
writer now preserves Source's write boundaries.

For example, a zero-sized monochrome frame with an eight-byte file buffer ends at
position 67 with `\nENDHDR\n` still pending. Source has written 59 bytes to disk;
the previous V implementation had already written all 67. After flush, both
produce the same complete header. A grayscale frame with comments and a 16-byte
buffer also preserves the initialized inactive buffer bytes after its nine-byte
pending tail. The module regression checks both cases against native observations.

| Returning records | Count |
|---|---:|
| Complete rasters across tuple types and sample widths | 210 |
| Every header/raster prefix, followed by a retry | 14,007 |
| Long comments, blank lines and duplicate numeric fields | 630 |
| Component validation and scaling | 336 |
| Compatible/incompatible sequences and trailing bytes | 420 |
| Repeated detection without consuming bytes | 42 |
| Parser errors and exact tuple-rest matching | 672 |
| Reads after discarding an input prefix | 21 |
| Buffered encoding, repeated writes and final flush | 22,620 |
| **Total** | **38,958** |

These records make **77,958 read/write/detection calls**. Both modes retain
SHA-256 `fbbcf91a8bf9670108461609b06039bbd00bb41481d4f24b58e85c7e5354c671`.
Reads cover memory and positional files with 3/4/8/16/64/129-byte buffers, direct
sequence/single-image methods and the format interface. Header lines longer than
the file buffer remain valid. Writes cover every storage tag, zero/nonzero
extents, three comment profiles, PAM/BMP options, offsets 0/7 and buffers
0/1/2/3/4/8/16/32/64/128. `writeFrame` retains pending output; `writeImage` and
the interface flush it. File descriptors start at EOF to verify the stream's
independent positional cursor.

**90 exact panic/state pairs** cover twelve undersized reader buffers, 36 wrong
option arms, thirty short pixel arrays, six omitted grayscale2 writer arms and
six decoder dimension overflows. Each pair requires a failing exit, no stdout,
the sole exact message from compiled Source and identical nonempty snapshots.
Case names, messages and states retain SHA-256
`2aad431028fa6420aca4f1515b665731c4fdadfeac9364c799e2ad72ef671ca7`.

Snapshots compare logical position, buffered/pending length, every initialized
caller buffer byte, unchanged input and actual on-disk contents. Writer failures
also retain caller image metadata and initialized pixels. Successful decodes
compare complete pixels and animation metadata; grayscale1 is serialized by its
semantic value to exclude narrow-field padding. Failed/freed decoder storage,
private Header/TupleType and pointer identities are unobserved. Source visibility
and implementation remain unchanged.

The original [PAM contracts](../pam_contracts/README.md) remain a separate memory,
option, animation, mutation and compiler-contract proof. Its three existing hashes
remain unchanged in both modes after the header-write fix.

Custom/nonseekable readers, streaming pipes, descriptor failures, short native
writes, allocator/OOM/GC/lifetime, arbitrary larger allocations, const/narrow/
boxed representation, private helpers, physical records and portable ABI remain
boundaries. Cross builds do not establish cross-target runtime parity.

Full Source-tree SHA-256:
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected Zig-library SHA-256:
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Before/after source, library, implementation, fixture, runner, helper and corpus
hashes protect the evidence.
