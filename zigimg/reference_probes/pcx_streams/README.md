# PCX file encoding, retained buffers and short pixel storage

`verify_pcx_streams_reference.py` compiles unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Debug against ordinary V and
ReleaseSafe against production V, using Zig 0.15.2 and V 0.5.2.

```sh
python3 zigimg/verify_pcx_streams_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default runtime target
is `aarch64-macos.14.0`, linked with libc. `--timeout` bounds commands; compiler
temporaries follow `TMPDIR`/`VTMP`. Evidence retains Source, fixtures, inputs,
binaries, raw output, commands and provenance.

The indexed1/indexed4/RGB24 writer now preserves exact Source index/length panic
messages before narrowing its pixel index. The odd indexed8 writer checks
the complete row slice before feeding the RLE encoder. These checks remain active
in production and preserve emitted headers, earlier encoded bytes and pending
file buffers. Successful encoding and the even indexed8 whole-slice path retain
their previous behavior.

| Returning records | Count |
|---|---:|
| Direct/static/interface buffered encoding | 29,640 |
| Active palette lengths and alpha ignored during encoding | 648 |
| Even indexed8 whole-slice lengths and run patterns | 1,350 |
| Unsupported dimensions/storage before output | 252 |
| Direct rejection or ignored vertical coordinates | 36 |
| **Total** | **31,926** |

These records contain **63,852 calls**, with SHA-256
`5aa80bb7a8cba801fa567fd16de6e7e424757fd3e077975c430a1fedb1311e5d`.

Memory capacities are 0/1/127/128/129/160/256/1024; file capacities are
0/1/2/3/8/16/63/127/128/129/256/1024. Writers cover indexed1/4/8, RGB24 and
unsupported grayscale8, widths 1/2/3/7/8/15/16/17/31/32/63/64/65, heights 1/2,
and four pixel patterns. Palette controls request 0/1/2/4/16/256 active entries,
clamped to the storage capacity. Even indexed8 lengths 0..129 selected around
16-byte vector and 63-byte run boundaries use six patterns; actual slice length
is independent of the declared 2×1 image. Its fast encoder retains Source's run
accumulation across distinct blocks. Direct metadata and interface encoder options
are deliberately unrelated to storage, as Source ignores them.

Each returning record calls the same writer twice, then explicitly flushes.
Offsets are 0/7 where the memory capacity permits seeking. File descriptors start
at EOF independently of positional cursors; files begin with 1,024 initialized
bytes and retain that extent or grow as required. Snapshots compare position,
pending length, every caller buffer byte, direct header bytes, caller image
dimensions/pixels/palettes and actual disk contents. Private/default static codec
state, allocator effects and pointer identities are excluded.

| Exact panic/state pairs | Count |
|---|---:|
| Short indexed/RGB storage or odd indexed8 row slices | 249 |
| Zero dimensions before format rejection | 180 |
| Odd stride overflow before header output | 24 |
| Direct coordinate arithmetic after header output | 70 |
| **Total** | **523** |

Failure SHA-256:
`b7fc8e58519d7344a17c309b60ac76bcf633a69687386446dd732ce0ed338a87`.
Each pair requires failed exits, no stdout, the exact sole message from compiled
Source and equal nonempty snapshots. An additional **67 returning controls**
cover bounded-memory write failure preceding later bounds/coordinate faults and
even indexed8 short slices. Their SHA-256 is
`7478420d1dbafe2e6bf577d14a9404151236ece9a3c1808d7bcf8ee90e572e29`.

The consumer regression writes a 32-byte indexed slice through a 128-byte file
buffer at offset seven. Source encodes two distinct sixteen-byte blocks as one
32-byte run of the second value, returns at 150 with no pending bytes, and retains
the fifteen encoded body/palette bytes followed by 113 earlier header bytes in
the caller buffer. A separate compiled comparison checks that exact input in both
modes. The pre-fix comparison matched every returning record before the first
short indexed1 diagnostic mismatch; its raw evidence remains retained.

Full Source SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`;
selected compiler-library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Versions and before/after Source/library/implementation/fixture/runner/helper/input
hashes protect final comparisons. Historical PCX contract, decoder and failure
hashes and unchanged native assertions remain unchanged.

Custom/nonseekable streams, pipes, operating-system I/O failures, allocator/OOM/
GC/lifetime, narrow/const/enum/boxed representation, physical layout, wider
allocated extents, other CPU vector configurations, big-endian/32-bit runtime
and portable ABI remain boundaries. Cross builds establish compilation coverage
only. Existing [memory contracts](../pcx_contracts/README.md) and
[buffered decoder comparisons](../pcx_decode/README.md) cover their own scopes.
