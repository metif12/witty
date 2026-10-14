# GIF loop-count metadata and exact slice bounds

`verify_gif_loop_count_reference.py` compiles unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Debug against ordinary V and
ReleaseSafe against production V. Compilers are Zig 0.15.2 and V 0.5.2.

```sh
python3 zigimg/verify_gif_loop_count_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default runtime target
is `aarch64-macos.14.0`, linked with libc. `--timeout` bounds commands. Artifacts
retain unchanged Source, fixtures, binaries, inputs, output, commands and
provenance; `TMPDIR`/`VTMP` select compiler temporaries.

Source `loopCount` first slices application data at byte one, then loads two
little-endian bytes through `std.mem.readPackedInt`. V previously indexed bytes
one and two directly and emitted its generic array error. Explicit checks now
retain the sole Source diagnostic in both modes:

| Data length | Exact Source/V panic |
|---|---|
| 0 | `start index 1 is larger than end index 0` |
| 1 | `index out of bounds: index 2, len 0` |
| 2 | `index out of bounds: index 2, len 1` |

Valid counts are unchanged. Identifier/code matching is exact and case sensitive.
Only `NETSCAPE`/`2.0` and `ANIMEXTS`/`1.0` are recognized. The first matching
record wins, including an infinite count or malformed data; later recognized
records do not override it. Unrecognized short data is ignored. Byte zero and
bytes after the count remain unchecked and ignored. Zero maps to the infinite
animation constant; other counts are returned without subtracting one.

Both modes match **160,902 returning records / 171,072 calls**:

| Returning records | Count |
|---|---:|
| All 65,536 counts for both recognized identifier/code pairs | 131,072 |
| Every first data byte, count mutations and copied metadata | 6,144 |
| Every byte at each identifier/code position with varied data lengths | 22,462 |
| Extra ignored data lengths 0..64 | 390 |
| Empty lists, ordered recognized/unrecognized records and first-match precedence | 198 |
| Mutations of earlier/later records in ordered lists | 636 |
| **Total** | **160,902** |

Returning SHA-256:
`ec13251605eb891bad0b2608663649fda9d7c1a20f64368775d96d491bda17e4`.

**112 strict panic/state pairs** cover both recognized identities, seven short
data patterns, four unrecognized-prefix contexts and optional later valid
records. Both processes must fail with no stdout, the exact sole message from
compiled Source and equal nonempty snapshots. State SHA-256:
`97ff010dee4bb92007e127ad83d3a3e846eb4628271bbf17ae96f60986d04c56`.

Snapshots compare every initialized application identifier, authentication byte
and data byte, plus the ordered list length. Mutation checks exercise the ignored
first byte and both count bytes. Copied metadata has independent fixed identifier/
authentication arrays and a shared mutable data slice; loopCount observes the
live slice changes. No default undefined Source header or inactive fixed storage
is inspected. The fixture uses only public GIF APIs and fields.

Full Source tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`;
selected compiler-library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`;
additional fmt.zig SHA-256 is
`667eac6285e472b5516ebebf8a6e69959a171be4fb97cac1e56419ffec20d500`.
Compiler versions and before/after Source/library/implementation/fixture/runner/
helper/input hashes protect final comparisons. Historical GIF record/state hashes
and unchanged decoder/renderer assertions pass in both modes.

Decoder/file-stream state space, allocator/OOM/GC/lifetime, const/narrow/boxed
representation, physical layouts, wider extents, big-endian/32-bit runtime and
portable ABI remain boundaries. Cross builds establish compilation coverage only.
