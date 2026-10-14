# BMP positional file streams, pending headers and retained buffers

`verify_bmp_streams_reference.py` compiles unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`: Debug against ordinary V and
ReleaseSafe against production V. Compilers are Zig 0.15.2 and V 0.5.2.

```sh
python3 zigimg/verify_bmp_streams_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. The default runtime target
is `aarch64-macos.14.0`, linked with libc. `--timeout` bounds commands; compiler
temporaries follow `TMPDIR`/`VTMP`. Artifacts retain unchanged Source, fixtures,
inputs, binaries, raw output, commands and provenance.

Both modes match **28,826 returning/error records / 57,652 calls**:

| Returning records | Count |
|---|---:|
| Complete V4/V5 BGR/BGRA images and zero/odd extents | 3,456 |
| Every prefix of retained header/pixel examples, initial discard and retries | 13,248 |
| Unknown info-header sizes | 216 |
| Magic/header/storage validation before dimension arithmetic | 144 |
| Direct negative dimensions with private pixel bytes excluded | 32 |
| Every detector first byte | 2,048 |
| Detector partial magic, EOF and initial discard | 64 |
| Direct/static/interface file encoding, ignored metadata/options and pending buffers | 8,820 |
| Signed/zero direct writer dimensions and maximal fitting image width | 714 |
| Unsupported image storage before size arithmetic | 84 |
| **Total** | **28,826** |

Returning SHA-256:
`e66348bd94ed11482b88a9abc8ad371e80ff29b60487793ba2aee6f68abfadc4`.

Readers use memory and file buffers matching the 40/108/124-byte info-header
size, 128 and 256. Smaller capacities are checked separately. Writers use bounded
1024-byte memory and file buffers 0, 1, 3, 4, 8, 13, 14, 40, 108, 122, 124,
128 and 256; offsets are 0/7. Every record makes two calls on the same stream.
Descriptors begin at EOF independently of positional cursors. Writer files start
with 256 initialized bytes; the codec does not truncate them. Successful codec
writes flush; recoverable errors retain pending bytes. The fixture then flushes
explicitly, allowing both boundaries to be compared.

**188 exact panic/state pairs** cover thirteen undersized file-header/detector
buffers, 21 info-header buffers, eighteen read arithmetic failures, four image
dimension casts, 48 short pixel arrays, 24 direct minimum-height failures and
sixty image-size/dimension failures. Each pair requires failed exits, no stdout,
the exact sole message from compiled Source and equal nonempty snapshots.
State SHA-256:
`4226d2b1d73e7da2d286f02ed7be91e64cfaede2dbd6b3652327d8a8c76b5b78`.

Snapshots compare logical position, buffered/pending length, all initialized
caller buffer bytes, unchanged input, actual disk contents, initialized direct
file/info headers, and caller writer image/pixels. Successful reads compare
complete pixels before/after mutation. Direct negative reads expose only storage
length and public metadata; unwritten pixel bytes are excluded. Static/interface
private codec state, failed/freed allocations, undefined default Source headers,
pointer identities and inactive capacity are unobserved. Source algorithms and
visibility are unchanged.

Consumer regressions preserve three native-observed file boundaries. An unsupported
direct grayscale writer with a 256-byte buffer leaves 122 header bytes pending at
position 129 and disk bytes unchanged until caller flush. A 128-byte BGR writer
retains its whole 125-byte file plus three unchanged buffer bytes. A BGRA writer
retains its 124-byte V5 header and four-byte pixel after separately flushing the
file header. Both successfully round-trip from offset seven through a 124-byte
reader: BGR returns at position 132 with 121 bytes buffered, BGRA at position 149
with 107. Separate Source/V controls compare those exact writer/readback inputs
in both modes. The existing codec implementation needs no changes.

Full Source tree SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`;
selected compiler-library SHA-256 is
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Versions and before/after Source/library/implementation/fixture/runner/helper/input
hashes protect final comparisons. Historical BMP returning, decoder/control and
failure-state hashes and unchanged native assertions remain unchanged.

Custom/nonseekable readers, pipes, operating-system I/O failures, allocator/OOM/
GC/lifetime, const/narrow/boxed representation, physical layouts, wider allocated
extents, big-endian/32-bit runtime and portable ABI remain boundaries. Cross
builds establish compilation coverage only. The existing
[BMP contract proof](../bmp_contracts/README.md) covers broader memory/scalar cases.
