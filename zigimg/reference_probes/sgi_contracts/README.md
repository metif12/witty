# SGI checked RLE and retained decoding state

`verify_sgi_contracts_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary V,
and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_sgi_contracts_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default runtime target
is `aarch64-macos.14.0`, with 64-bit usize arithmetic. `--timeout` bounds each
command; `VTMP` can select V compiler temporaries. Artifacts retain binaries,
commands, outputs, input hashes, panic snapshots, provenance and a JSON summary.

SGI's RLE table allocation evaluates height × channels × 2 × 4 in u16. Its largest
fitting row count is 8,191, producing 65,528 table bytes; 8,192 rows trap before
allocation or reading. V now checks that boundary in both modes, along with the
u16 channel-size product and absolute-offset subtraction.

RLE byte accesses retain Source index/length diagnostics before narrowing usize
indices. Literal assignments check destination bounds before reading each source
byte. A repeated word reads both source bytes before any destination assignment;
each destination byte is then checked separately. This preserves both simultaneous
fault ordering and partial output. Source uses two-byte words for every channel
width other than one, ignores the high command byte, does not clip runs to image
width, and consumes all compressed input before decoding its absolute row tables.

| Returning observations | Count |
|---|---:|
| Defined native header layout/bytes | 1 |
| Width/height accessors, including maximum u16 fields | 25 |
| Format dispatch over every valid dimension/pixel-format tag | 360 |
| RLE packet and truncation/capacity controls | 96 |
| RLE offset/declared-size controls | 30 |
| RLE row/channel placement, zero extents and trailing input | 90 |
| Short table reads retaining initialized output | 8 |
| Largest fitting table arithmetic controls | 2 |
| Uncompressed public decoding | 96 |
| Fully defined RLE public decoding | 72 |
| Truncated public headers/bodies | 11 |
| Unsupported format preceding channel-size arithmetic | 3 |
| Maximum fitting channel-size product with zero extents | 1 |
| **Total** | **795** |

The first three groups have SHA-256
`5d61def8690c6c1546c829ce329e011797d9aa47f8a68f66cd20eedd89eae9cd`.
The remaining returning records have SHA-256
`4cc111e3180b24ed9a7eb7601251324feb34c4ecde170b703759e0ced25ea41c`.

The direct decoder matrix uses channel-width values 0/1/2/3/255, literal/repeated
counts 0..2, every packet prefix and output capacities 0..4. Additional cases use
multiple rows/channels, reversed packet storage, early terminators, zero-length
literal commands, offsets below/above data start and offsets at 2^31/u32 maximum.
Every visible destination byte starts at 165. Public reads cover grayscale8,
RGB24/RGBA32 and RGB48/RGBA64, widths 0..3 and heights 0..2. All observed pixels
are fully written; malformed successful RLE reads with unwritten private data are
excluded. All fixture enum values are valid Source tags.

| Strict panic/state pairs | Count |
|---|---:|
| Packet source/destination bounds, including simultaneous failures | 549 |
| Absolute offsets and compressed-data bounds | 75 |
| u16 table arithmetic before input consumption | 4 |
| u16 channel-size multiplication after public header parsing | 2 |
| Zero-channel public byte/word reads | 6 |
| **Total** | **636** |

Failure-state SHA-256:
`3e8a57024951a8948a64b350aaa3859a88338ece93378485fa104b4dfc0e0dd9`.

The runner classifies actual Source returns and only its integer-overflow or full
index/length panic diagnostics, then requires the identical V behavior. Locked
return/trap counts and hashes include each case name, exact panic text and retained
state. Strict checks require unsuccessful exit, no unexpected output and no core
dump. Snapshots compare the reader cursor, fully initialized 510-byte header,
four active inline palette entries and initialized caller output. Private table/
data buffers, failed pixel allocations and freed storage are excluded.

Source's RGB48/RGBA64 reader reinterprets a byte slice descriptor as a word slice
without halving its length. V now retains the logical word index/length diagnostic
before decoding defined word bytes. Actual word reads beyond the physical byte
allocation remain undefined Source behavior and are excluded. The unusual RGBA64
alpha byte index/endian swap and grayscale8 selection for two-byte channels remain.

The Source header type is inferred through the public SGI header field without
changing visibility. Default Source headers and inactive inline palette storage
are undefined and unobserved. Allocator/OOM/GC/lifetime, pointer/slice layout,
file streams, invalid enum tags, wider allocated extents and portable ABI remain
boundaries. No empty pointer identities are compared. Cross-target compilation
does not establish runtime parity. The unchanged historical native SGI harness
also passes Debug and ReleaseSafe.

Full Source-tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected Zig
library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`. The runner
checks Zig 0.15.2/V 0.5.2, generated inputs and before/after fixture, runner and
implementation hashes. Source visibility and implementation are unchanged.
