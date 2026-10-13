# IFF planar conversion and ByteRun2 retained state

`verify_iff_planar_reference.py` imports the unchanged zigimg source at
`d7b7ab0ba0899643831ef042bd73289510b39906`. It compares Source Debug with ordinary
V and Source ReleaseSafe with production V.

```sh
python3 zigimg/verify_iff_planar_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and a different empty directory. Runtime comparisons use
64-bit little-endian `aarch64-macos.14.0` by default. `--timeout` bounds commands;
`TMPDIR` and `VTMP` select compiler temporaries. Retained artifacts include
binaries, full imported source, commands, outputs, generated inputs, caller-buffer
snapshots, fixture/implementation/runner hashes and compiler/library provenance.

Planar conversion checks the BMHD arm before any destination mutation. PBM checks
the complete source slice before copying and rejects overlapping logical copy
spans, including identical nonempty views. Empty copies and adjacent spans return.
Other formats clear the destination first and continue reading borrowed source
bytes live, including when the source overlaps that destination. ILBM's horizontal
pitch-times-plane product retains its u16 overflow even on row zero; ByteRun2
vertical storage and the other format branches retain their existing traversal.
Both source and destination indices preserve exact Source diagnostics before V
narrows them to array indices. Set padding bits and incomplete eight-plane groups
retain Source's spill/bounds behavior instead of clipping to the image width.

ByteRun2 checks the BMHD arm, clears the caller buffer and processes plane records
in Source order. A declared command count below two retains its u16 overflow
after consuming that count. Commands are interpreted only after the complete command
block arrives. Each literal destination is checked before consuming its byte;
high-byte writes and their cursor advance survive low-byte failures. Repeated
words are read before destination checks. Zero-count commands, signed -128,
zero height, odd/zero pitch, plane boundaries, trailing data and command exhaustion
keep the source behavior. Shared stream/output backing retains clearing and
subsequent live input changes.

The corpus partitions returning/error cases and strict traps with a small model;
all compared outputs and failure states come from compiled, unchanged Source.
Every input and caller destination byte is initialized, including shared backing.
The complete source view, destination view, shared backing and reader cursor are
compared after returns and from panic observers. Private incomplete command
buffers, inactive/default palette storage, freed memory and undefined default
header fields are never observed. Empty pointer identities are excluded.

Both modes match **31,017 returning/error records**: 26,880 byte-pattern controls,
156 returning u8-plane controls, 1,800 distinct plane/row layouts, 81 planar
bounds/empty controls, 40 successful shared-backing controls, 1,530 signed-command
controls, 212 RLE prefixes, 36 command-count controls, 86 literal/repeat write-order
controls, 26 plane-boundary controls, 166 mixed command sequences and four RLE
shared-backing cases.

Return SHA-256: `74895e84f384182b4ddeb7f3ee1a6f615fca7b9319b129744bae26d114b2925b`.

**1,225 strict panic/state pairs** cover 1,194 exact bounds failures, thirteen
arithmetic failures, ten wrong-header-arm accesses and eight overlapping PBM
copy failures. They require the exact panic, unsuccessful exit, no stdout,
a complete matching snapshot and no core dump. Case names, exact messages and
caller state join SHA-256
`da83479790fc43626a5326117ebad8ea0defbafe86d853389c32fb1188bc0328`.

The later [pixel/chunk checkpoint](../iff_pixels/README.md) covers fixed-memory
chunk traversal and RGB/HAM conversion checks. Allocation failure, GC/lifetime, physical slice/record/sum
layout, readonly/narrow V typing, boxed header copies, extents beyond V array
limits, file streams, big-endian runtime and portable ABI remain boundaries.
Cross compilation establishes build coverage only.

Full Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
The runner requires Zig 0.15.2 and V 0.5.2 and verifies source/library/fixture/
implementation/runner pins before and after execution.
