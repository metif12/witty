# POSIX image terminal paths and streaming fallback

`verify_image_tty_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`, Zig 0.15.2 and V 0.5.2 on native
little-endian `aarch64-macos.14.0`, linked with libc. Source Debug/V ordinary and
Source ReleaseSafe/V production both execute the complete comparison.

```sh
python3 zigimg/verify_image_tty_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` in another empty directory. Commands default to a 600-second
limit. Evidence retains complete Source, fixtures/C helpers, inputs, binaries,
commands, raw records, panic snapshots, isolated mutation module and provenance.
Compiler temporaries use owned TMPDIR/VTMP directories.

Actual Darwin pseudo-terminal pread/pwrite returns ENXIO. Source maps NXIO, SPIPE
and OVERFLOW to Unseekable and falls back to streaming. V previously fell back
only on ESPIPE, returning WriteFailed for a valid BMP path write and ReadFailed
for direct slice/buffered reads. Original binaries, raw mismatches and the old
production header remain retained. All three POSIX positional IO shims now use
the pinned Unseekable classification (ESPIPE/ENXIO/EOVERFLOW). Existing fallback,
nonzero-position and error behavior remains intact; EINVAL is still outside this
classification. EOVERFLOW alignment is based on the pinned source, with no actual
EOVERFLOW runtime injection in this proof. Windows IO remains unchanged.

**853 returning records / 1,693 calls** match in both modes, SHA-256
`40d7262b0449afa7959e672e0defc768b9595731d55de42dd441ac36c9fe8ca5`.

| Returning group | Records | Calls |
|---|---:|---:|
| Public terminal writers | 816 | 1,632 |
| Public terminal detection/readers | 24 | 48 |
| Direct slice readers | 9 | 9 |
| Direct buffered take | 4 | 4 |
| **Total** | **853** | **1,693** |

Writers cover seventeen encoder arms, eight initialized 4×2 storage profiles
(gray8, RGB24, RGBA32, BGR24, BGRA32, RGBA64, indexed8 with four active palette
entries, and invalid), default options, capacities 0/8/32 and both managed APIs.
Public reads/detection cover both APIs/capacities and empty/eight-byte PNG-signature
input. Public calls repeat twice on the same owned terminal with retained caller
buffers. Direct reads request 0/1/7 bytes; buffered take requests 1/7 with capacities
8/32. Seeded input fits every request, so no reader waits for missing bytes.

Public reader opens use O_NOCTTY and never acquire a controlling terminal. Their
initial seek returns Unseekable before detection/decoding, preserving caller
buffers and queued input. Public writer opens acquire the owned terminal before
codec dispatch, even for unsupported/no-op encoders. Closing their temporary
file does not release the controlling terminal while the keeper remains open;
the second call retains that ownership. Normal snapshots have one slave reference
(the keeper). Direct streams use the keeper without acquiring a controlling
terminal, and actual ENXIO fallback preserves native output, logical positions,
read-ahead, pending bytes and initialized buffer tails. No-op encoder and PNG
signature-only boundaries stay pinned; this does not add complete encoders.

**12 returning controls**, SHA-256
`63d9ebf8c8fd649b7b5e01762b386b24e84c4dee24b2ad4f111dc41987fde49f`,
and **22 exact panic/state pairs**, SHA-256
`05b5e362cc894a4db7146b09e2fa335cb27d80ee5399e5d176208c155c4216de`,
cover zero-width PNG and one-pixel TGA storage. Source classifies all cases:
twelve PNG Unsupported returns, six PNG header panics and sixteen TGA storage
panics. Each failed pair requires failed exits, no stdout, one exact native
panic and equal nonempty initialized states. The public file remains open when
panic observers run, giving two slave references and the acquired controlling
terminal. Observers record ownership before teardown, without unwinding production
path descriptors.

Four actual libc open/close/ENXIO calibration records per binary, SHA-256
`2cbdabd5f026297bde9cc44955d1780d728107a3107587945ed2c81b20313c3a`,
check read/write opens with and without O_NOCTTY, ownership after close and actual
positional errors. Six deliberately altered V records / twelve public calls,
SHA-256 `750d69c6f91b50c1678d39c69d66971c22d47d5f3f91a1e28cfd523f41b7fb91`,
compile an isolated production module copy with exactly its NOCTTY condition
reversed. Readers acquire the terminal and writers do not; other outcomes and
bytes are preserved. These controls demonstrate that the real open flag branch
is exercised and remain separate from Source parity counts. All other copied
production files and v.mod are checked unchanged.

Rows contain nine fields:
`operation|formatOrReadCount|profile|variant|capacity|managed|shape|attempts|seedHex`.
Operations are public write/detect/decode (0–2), direct slice read (3), or buffered
take (4). Shape 0 is valid, 1/2 sets width/height to zero, and 3 retains one stored
pixel. Only default variant 0 and the stated shapes enter final matrices.
Snapshots are
`ctty:session:refs:outputDrain:inputDrain|bufferHex|width:height:pixelFormat:pixelCount:rawHex|paletteHex-or-dash|cumulativeOutputHex|cumulativeInputHex|directOutputHex|logical:pendingHex`.
The session bit requires both session and process-group leadership. Initial drain
markers are -3; observed empty nonblocking queues are -1. Raw descriptor, session,
process-group and device identities, private stream cursors, inactive storage and
allocator effects are excluded.

Each row/calibration/control runs in a separate subprocess. C creates a private
session with no inherited controlling terminal, an owned pseudo-terminal pair,
an O_NOCTTY keeper, and raw termios attributes to prevent echo/newline/signal
processing. It ignores/restores SIGHUP only in that owned process. `/dev/tty`
observations use O_NOCTTY and verify foreground-group ownership; observer handles
close before counting slave references among descriptors 0–127. C only sets up,
seeds, calibrates and observes owned resources; actual image opens, stream IO and
closes are neither intercepted nor replaced. Source bodies/visibility are unchanged.
No user terminal or external process group is detached or changed.

Cleanup closes only owned keeper/master handles and restores the handler. Darwin
session leaders reject TIOCNOTTY with EINVAL; the initial teardown failure is
retained. Reopening `/dev/tty` after master destruction can block, so corrected
fixtures never do that and process exit releases session state. An owned diagnostic
process that tested this invalid teardown was terminated; no unrelated process was
touched. Earlier calibration/smoke fixtures remain separate from final evidence.

One isolated consumer test file pins direct ENXIO fallback, retained buffered
read-ahead, unconsumed public reader failures, PNG signatures, no-op GIF writes
and controlling-session ownership. Ten exact compiled consumer records / eighteen
calls match per mode. All 62 image and 58 Vaxis test files pass, together with
22 focused production/application/Linux/Windows library/unit/fixture checks.
Windows stubs and Linux builds establish compilation only. Historical FIFO
6,960 returning/384 control/192 panic-state observations retain all three hashes
in both modes. The full stream suite retains its 37,133-record hash
`d5d4aadd97fafef40388dd894267e0b09d6db36b902c2f4356d4fb287eab8eeb`,
including the 36,962-record baseline hash
`f1aa0b894555ca0ee8864ce10e7605112cc2ccfeaa1ae6b21a07e3573cbc99dc`
and 171 streaming records hash
`37175ccb3eb0e9b5b36005a5c2443f6f59b1ee2cbd7de2fd1336c2761a8bcfab`.
Its seventeen historical trap pairs and four compile-rejection pairs also pass;
those older checks retain their original diagnostic scope, separate from exact
terminal panic/state assertions. Actual Source modes are verified for every build.

Formatting, diff and Python checks pass. Complete Source/selected standard
library/DEFLATE/math/SIMD/fs.Dir/libc/version and before/after implementation,
fixture, runner, helper and input hashes protect comparisons. Ordinary discovery
supplies fixed production goldens; only golden assignments change afterward.
Independent replay checks raw records, exact native classifications, original
ENXIO mismatches, deliberate NOCTTY reversal and provenance. Persistent archives
are read back member by member. An incorrect RGB24 numeric tag in the auxiliary
consumer checker remains retained; the corrected checker uses the pinned 0x308
value, with no production/fixture change.

Other terminal disciplines/devices, user-session interactions, nonzero stream
offsets, injected EOVERFLOW/other IO errors, interrupted read/write/close, signal
restoration beyond the stated fixture, backpressure/timing/cancellation, durability,
resource exhaustion, other options/capacities/images, Windows runtime, other CPU/
vector selections, const/narrow/enum/boxed representations, physical layouts,
big-endian/32-bit runtime and portable ABI remain boundaries. This checkpoint
certifies the stated isolated native terminal behavior, not completion of every
translation contract.
