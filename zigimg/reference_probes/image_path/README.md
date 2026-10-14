# Public image path validation and open failures

`verify_image_path_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` using Zig 0.15.2 and V 0.5.2:
Debug/ordinary and ReleaseSafe/production, native little-endian
`aarch64-macos.14.0`, linked with libc. Permission cases require an unprivileged
POSIX user; the proof rejects privileged/non-POSIX execution.

```sh
python3 zigimg/verify_image_path_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` in another empty directory. `--timeout` bounds commands.
Evidence retains Source, fixtures/C helper, inputs, binaries, commands, raw output,
initialized failure snapshots and provenance. Compiler temporaries use TMPDIR/VTMP.

The original V path wrappers returned OS messages instead of Source error names.
More seriously, an embedded NUL could truncate the path passed to libc: a PNG
write replaced the prefix-named file with its signature, a reader decoded the
prefix-named file, and an invalid PNG header panicked after truncating that file.
Source's `toPosixPath` assertion rejected all these paths before any open or codec.
A long NUL-containing path also reached V's OS open error rather than that assert.
Original binaries, raw mismatches and initialized states remain retained.

All public managed/unmanaged read, detection and write path wrappers now share a
POSIX opener. It asserts that no NUL exists before checking PATH_MAX or opening,
returns `NameTooLong` for an oversized path and `FileNotFound` for an empty path,
and translates the saved V OS error code into pinned `std.posix.openatZ` names.
Interrupted opens retry. The opener still uses os.open/os.create and their existing
file ownership. Windows wrappers keep their existing open behavior. The NUL guard
is explicit and remains active in V production, matching Source ReleaseSafe.
Other Source optimization modes are outside this proof.

**12,160 returning records / 24,320 public calls** match in both modes, SHA-256
`36bd463ce8ce5ec452f0bea5e38b2860f818add39d93a90f480d9faf6cdf14b9`.

| Returning records | Count |
|---|---:|
| Open failure before encoder dispatch | 11,968 |
| Open/initial-seek failure before detection and reading | 192 |
| **Total** | **12,160** |

Writer cases cover all seventeen encoder arms, eight initialized 4×2 storage
profiles, capacities 0/1/8/32 and both APIs. The eleven path kinds are a missing
parent, a regular file used as a parent, a directory, a mode-000 file, a
non-searchable directory, a self-referencing symlink, a dangling symlink with a
missing parent, a 256-byte component, paths of length 1023/1024, and the empty path.
Every case repeats twice without resetting the caller buffer. Reader/detection
cases cover both APIs, both operations, all four capacities and those path kinds
plus a missing final component. The initialized on-disk sample is Farbfeld.

Observed errors are `FileNotFound`, `NotDir`, `IsDir`, `AccessDenied`, `SymLinkLoop`
and `NameTooLong`. Reading a directory opens successfully but its initial seek
returns `Unseekable`; the wrapper then closes that descriptor. Open failures
precede codec dispatch, unsupported storage, zero-capacity buffer checks and
mutation. All caller bytes, initialized images and retained disk bytes remain
unchanged, with no extra live descriptor after either returning call.

**264 returning controls**, SHA-256
`d55f7627c54b82fc41b7d0986561a18bd6458c5a56c48f5d58df1d6bb7a79e0b`,
cover invalid generated image widths through PNG/TGA, RGB24/BGR24/invalid storage,
capacities 0/8, both APIs and all eleven writer path failures. Source classifies
these returns: path opening fails before header validation or storage dispatch.

**224 exact panic/state pairs**, SHA-256
`681998441896c2156e3191f21f6eba9a40b8f7c06e5f4b58916833286c207117`,
cover four NUL placements: after an existing file, a single NUL, after a missing
parent and after 1024 bytes. Writers cover PNG/TGA, RGB24/BGR24/invalid storage,
capacities 0/8, both APIs and normal/zero widths; reader/detection controls cover
both operations, both APIs and capacities 0/8. The sole native panic is
`reached unreachable code`. Failed exits, no stdout and equal nonempty initialized
snapshots are required. In particular, NUL rejection precedes length rejection,
file truncation, codec/header validation and allocation.

The C fixture creates only owned paths, permissions and links. An already-open
read-only keeper lets observation inspect a mode-000 file without changing its
permissions or position. Snapshots compare keeper validity, the change in live
fixture descriptors 0–127 from the initialized baseline, permissions, full caller
buffer bytes, initialized image dimensions/storage/raw pixels/active palette and
all retained file bytes. Isolated fixture descriptors stay below 128. Panic
snapshots are taken before opening the observer state file. Source bodies and
visibility remain unchanged; C supplies setup/observation, not image/stream APIs.
Normal returns and observers restore permissions and remove only owned resources;
no case directories survive successful proof completion. Private streams/codecs,
identities, inactive storage and allocator effects remain unobserved.

A consumer regression pins all ten practical path failures through both APIs,
repeated reads/detection, invalid PNG headers and the pinned no-op GIF writer,
including buffer/image/disk preservation and descriptor cleanup. Eighty exact
compiled records / 160 calls match per mode. Module tests skip permission-only
cases under a privileged user; the native proof requires an unprivileged user.
All 61 image and 58 Vaxis test files pass, with ordinary/production focused tests
and nineteen application/platform/unit/fixture checks. Cross builds establish
compilation only; Windows runtime and Windows path-error parity are not claimed.

Historical public file writes retain 19,584 returning records, 768 returning
controls and 384 exact panic/state pairs in both modes. Historical FIFO paths
retain 6,960 returning records, 384 returning controls and 192 exact panic/state
pairs. All six historical hashes remain unchanged. Formatting, diff and Python
checks pass. Initial fixture shadow/link rejections and the V conditional-loop
return-check rejection are retained separately. The complex C setup helper is
compiled as its own native C translation unit and imported through declarations.

Full Source/library/DEFLATE/math/SIMD/fs.Dir/libc/version and before/after
implementation/fixture/runner/helper/input hashes protect final comparisons.
Ordinary observations supply fixed hashes for production and reproduction; only
those golden assignments change afterward. Persistent evidence is independently
replayed and archived with every member read back.

Signals/EINTR injection, unobserved errno branches, quota/OOM/disk exhaustion,
other permissions/ACLs/encodings/path lengths/normalization, races and exec/descriptor
inheritance flags, custom streams, reader closure/SIGPIPE, full-pipe backpressure,
larger images, other CPU/vector selections, const/narrow/enum/boxed representations,
physical layouts, big-endian/32-bit runtime and portable ABI remain boundaries.
This proof certifies only the stated native POSIX path behavior.
