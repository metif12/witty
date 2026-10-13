# PCX checked arithmetic and public codec state

`verify_pcx_contracts_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary V,
and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_pcx_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default runtime target
is `aarch64-macos.14.0`. `--timeout` bounds individual commands; `VTMP` can select
V compiler temporaries. Artifacts retain binaries, every command and output,
panic snapshots, provenance and a JSON summary.

Coordinate subtraction/addition, scanline multiplication, end-relative VGA
palette subtraction, zero image dimensions and odd-stride rounding now use
explicit integer-overflow guards in both V modes. Source computes inclusive
dimensions in u16: a span of 65,535 returns normally, while 65,536 traps.
Oversized image dimensions return Unsupported before zero-dimension subtraction;
zero dimensions trap before pixel-format rejection. Direct writing rejects
unsupported pixels before emitting the header, but writes the header before
checking coordinates. An even-width indexed8 write encodes the whole pixel slice
without evaluating height, including a reversed vertical coordinate range.

| Returning observations | Count |
|---|---:|
| Width/height with zero lower coordinates or maximum upper coordinates | 131,070 |
| Native 128-byte header defaults and independent fixed-array record copies | 1 |
| Public image/direct codec writers, initialized pixels and bounded memory output | 4,480 |
| Memory decoder results and recoverable failures | 207 |
| Oversized/unsupported/write-first/even-width failure-order controls | 8 |
| **Total** | **135,766** |

The first three groups have SHA-256
`01a3c968e6dd94bc6b72e306cece9a095d71b27001f6fa88eb4ce6c991c82379`.
Decoder/control records have SHA-256
`1ad4b52c6f7c2ecae9ba806bb86019a7182171bce87d3768f94d7cd9111a8633`.

The writer matrix covers indexed1/4/8, RGB24 and unsupported grayscale8, widths
1/2/3/8/17/32/65, heights 1/2, four byte patterns and eight output capacities
0/1/127/128/129/160/256/1024. Every visible output byte starts at 165 and is compared
along with status and cursor, including partial writes. Source narrow indexed
carriers are respected, and active palettes have at most four initialized entries.
Direct writers deliberately receive unusual header metadata, including a
nonexhaustive palette-information value of 65,535. The public codec writes those
fields without applying the reader's header validation.

Decoder inputs cover 192 fully defined successes across indexed1/4/8 and planar
RGB24, widths 1..4, heights 1/2, three patterns and both compression flags. Source
uses RLE even when the flag is none; fixtures include ignored zero-length markers
and escaped high bytes. Successful records compare the retained 128-byte header,
cursor, complete pixel bytes and active palettes. Fifteen recoverable failures
cover truncated headers/body, invalid/unsupported headers before coordinate
arithmetic, an unfinished RLE run and misplaced VGA palette markers. Failed reads
compare the retained public header and cursor, excluding private temporary pixels.

| Strict integer-overflow panic/state pairs | Count |
|---|---:|
| Reversed and full-span width/height | 8 |
| Reversed/full-span coordinates after a read header | 5 |
| u16 scanline multiplication | 3 |
| VGA end offset below 769 | 5 |
| Zero image dimensions before format rejection | 10 |
| Odd stride overflowing u16 before header output | 2 |
| Direct coordinate failure after header output | 8 |
| **Total** | **41** |

Failure-state SHA-256:
`622bc7a90a0f6de57f8e1cf369fdde0fde8aa892685ed79841b91feeb0cc949d`.

Strict checks require the integer-overflow diagnostic prefix, unsuccessful exit,
no unexpected return and no core dump. Panic observers compare public header bytes
and reader cursors, or writer cursors and initialized output buffers. Scanline
failure follows header/format/dimension validation and allocation; palette-offset
failure follows decoding and precedes seeking. Private allocated pixels/palettes,
allocator effects and freed storage are excluded from failure snapshots.

The runner imports only public codec/storage/stream interfaces from unchanged
Source files. V's `reserved0` adapts Source's `_reserved0`, and GC-backed factories
replace explicit allocator parameters. Source's nonexhaustive palette enum uses
an explicit unsafe V enum carrier in the fixture. Compression fixtures use only
the two valid Source enum values. Wider V indexed1/4 values have no matching Source
u1/u4 value and remain outside the proof; their existing carrier assertions are
not Source arithmetic traps.

This is a bounded memory-stream proof. Larger planar inputs, dummy-byte paths and
Source pixels left unwritten by its decoder are not claimed by this matrix.
File streams, allocator/OOM/GC/lifetime, enum/narrow/const typing, wider allocated
extents, arbitrary targets and portable ABI remain boundaries. Cross-target builds
do not establish runtime parity. The historical native PCX harness also passes
unchanged in Debug and ReleaseSafe; existing V PCX tests cover its defined fixtures.

The runner verifies full Source-tree SHA-256
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`, selected Zig
library SHA-256
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`, compiler
versions (Zig 0.15.2 and V 0.5.2), and before/after fixture, runner and implementation
hashes. Source visibility and implementation are unchanged.
