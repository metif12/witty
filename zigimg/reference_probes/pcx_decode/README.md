# PCX buffered decoding and padded RGB bounds

`verify_pcx_decode_reference.py` compares unchanged pinned zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary V,
and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_pcx_decode_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and a separate empty directory. The default runtime target
is `aarch64-macos.14.0`. Each command has a configurable timeout. Artifacts retain
source copies, binaries, corpus, all commands/output, public panic snapshots,
provenance and a summary. Compiler temporary/cache directories belong to the proof.

The planar RGB assignments now explicitly preserve Source's complete
`index out of bounds: index N, len L` diagnostic in both V modes. A nonzero dummy
byte can address the next row or, on the last row, the end of allocated storage.
The guard follows RLE byte decoding and applies only to the three component
assignments. Zero-byte skipping and EOF-before-destination failure order remain.
Successful decoding and the existing arithmetic guards are unchanged.

| Returning records | Count |
|---|---:|
| Indexed1/4/8 shapes and row padding | 11,664 |
| RGB planes with or without a zero dummy byte | 1,944 |
| RLE runs across rows/padding and unfinished runs | 3,456 |
| Defined byte prefixes and retries | 4,218 |
| Header rejection before reversed-coordinate arithmetic | 36 |
| End-relative VGA palette seeking | 108 |
| RGB EOF before an invalid padding destination | 54 |
| **Total** | **21,480** |

These records contain **25,896 read attempts**. Output SHA-256 in both modes:
`c5140357c6cdcd568260ef8f8def66a7b596de669070d3e98f2e8f2046d346cb`.

Each input runs with memory and file-buffer capacities 128/129/131/257/1024.
Indexed shapes cover widths 1/2/3/7/8/9/16/17/31/32/63/64, heights 1/2/3,
three byte patterns, both compression tags, and minimum/+1/+4 strides. Source
always decodes RLE, regardless of the compression flag. Indexed palettes compare
all 2/16/256 RGBA entries. Planar shapes cover widths 1/2/3/4/7/8/9/16/17,
heights 1/2/3 and strides width/width+1. Their active component bytes are nonzero
and dummy bytes zero, so Source writes every observed output component.

Run cases cross row and discard boundaries, include count 63 and escaped high
bytes, and distinguish complete from unfinished runs. Prefixes exercise header,
body, run-value and palette-seek failures plus repeated calls on retained state.
An indexed8 body decoded in a stream shorter than 769 bytes traps before palette
seeking; those inputs run separately below. End-relative seeking covers valid and
invalid markers and positions before, within or after the decoded body. No
handwritten expected decoder output substitutes for actual compiled Source.

| Exact panic/state pairs | Count |
|---|---:|
| Last-row nonzero padding for each RGB component | 192 |
| VGA end-offset underflow after fully decoding pixels | 12 |
| **Total** | **204** |

Failure-state SHA-256:
`fbcc36d2d1b2bfd331bdde3f4280c1055fa9bea02ee9aa6b9ac2fc13f5214f7d`.

RGB failures cover widths 1/3/4/7, heights 1/2, all three components, a raw and an
escaped nonzero byte, and memory/file capacities 128/257/1024. Underflows use
stream sizes 135/256/768 with the same capacities. Strict checks require the exact
sole panic message, unsuccessful exit, no stdout/unexpected return and disabled
core dumps. All returned and failed records compare the complete initialized
128-byte public header, logical stream position, buffered length and every byte
of the caller's buffer initialized to 165. Successful reads additionally compare
all pixel and palette bytes. Private failed/freed pixels, palettes and RLE state
are excluded from observers.

The existing 135,766 returning and 41 arithmetic panic/state observations retain
all previous hashes in both modes. A module regression compares file-buffered VGA
seeking and padded RGB rows with memory decoding. All 61 image and 58 Vaxis test
files pass, with 17 production/platform checks. Cross-target compilation does not
establish runtime parity. The initial prefix fixture included an arithmetic trap
in the returning batch; that failed attempt is retained separately. The corrected
pre-fix batch matched every return before its first exact padding diagnostic
mismatch. Its public failure snapshot matched. Completed proofs use frozen inputs,
fixtures and implementation.

The runner verifies full Source-tree SHA-256
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`, selected Zig
library SHA-256
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`, Zig 0.15.2,
V 0.5.2, and before/after fixture, runner, helper, implementation and corpus hashes.
Source visibility and bodies remain unchanged. V's `reserved0` adapts Source's
`_reserved0`; GC replaces explicit allocator parameters.

Undefined/unwritten Source pixel storage, private failed allocations, buffers below
the 128-byte header requirement, streaming/nonseekable/custom readers, arbitrary
larger planar/stride/extents, allocator/OOM/GC/lifetime, enum/narrow/const typing,
physical layout and portable ABI remain outside this bounded proof. Its RGB shapes
do not cover zeros in active components on Source's dummy-byte path, where Source
can leave fields unwritten. The earlier
[PCX contract proof](../pcx_contracts/README.md) separately covers dimensions,
encoders, memory writes and their arithmetic/error precedence.
