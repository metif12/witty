# Public image read and detection routes

`verify_image_read_reference.py` compiles unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` using Zig 0.15.2 and V 0.5.2.
It compares Debug/ordinary and ReleaseSafe/production on native little-endian
`aarch64-macos.14.0`, linked with libc.

```sh
python3 zigimg/verify_image_read_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` in another empty directory. `--timeout` bounds commands;
compiler temporaries follow TMPDIR/VTMP. Source alone supplies classifications,
pixels, errors and failure state. Fixtures and implementation inputs are frozen;
ordinary observations supply the checked hashes for production and reproduction.

No production change was needed. **18,040 returning records / 36,080 public
calls** match, SHA-256
`2b0e3abd67907e90dee44af4969652acb1a99a2c8a302a2f1f1848467171eafd`.
Each record invokes its selected API twice without resetting the buffer.

| Returning records | Count |
|---|---:|
| Complete decoded images through all routes | 160 |
| Complete format detection through all routes | 416 |
| Detector prefixes | 8,428 |
| Decoder prefixes | 5,200 |
| Registry first-byte variations | 3,584 |
| Short-signature failure order | 252 |
| **Total** | **18,040** |

Routes are managed/unmanaged file handles, paths and memory (six public routes).
Each file is seeded with the exact input, and a separately opened read/write
borrowed descriptor starts at EOF. Positional readers start at zero; path calls
open and close their own descriptor. The borrowed descriptor remains live at EOF
and disk bytes remain unchanged. Memory cases include the same initialized
input/disk observation and an empty unrelated caller buffer.

Sixteen complete samples successfully detect and decode: BMP, Farbfeld, GIF,
IFF, JPEG, PAM, PBM, PCX, PGM, PNG, PPM, QOI, RAS, SGI, TGA and TIFF. Most decode
one pixel; JPEG is a frozen 8×8 baseline grayscale image with fully initialized
blocks. GIF includes a complete one-pixel frame, delay and Netscape loop extension.
Input constructors reuse hashed existing proof helpers; JPEG bytes are a literal
fixture and do not require Pillow during reproduction. PNG and TIFF compression
inputs use Python zlib only for fixture construction, not expected decoding.

Complete reads use capacities 1024/4096 plus memory controls. Complete detection
uses 26/32/64/128/512/1024. Prefix detection uses 26/32/128, and prefix decoding
uses 1024/4096. All 256 first-byte variations traverse the native ordered registry.
Short PAM/Netpbm/XBM-like signatures preserve earlier detector returns. In
particular, `P7\n` matches the direct PAM detector but the public registry returns
`EndOfStream` at an earlier detector's eight-byte request.

**2,182 individually classified returning controls**, SHA-256
`fe7af7f48f4e178f124528b064f1b332316945b360f44ee2d27ec85764e934ca`,
include 1,032 capacity cases, 1,100 GIF/TGA decoder prefixes and 50 indexed PCX
palette-order cases. **948 exact panic/state pairs**, SHA-256
`9c108992c26ef38c818f6b827b98f65668aa1aa704158e7bf6577cf3d4d2ea09`,
include 888 capacity cases, 40 GIF/TGA prefixes and 20 PCX palette-order cases.
Capacity controls use every terminating sample, both detection/decoding and all
four file/path routes, with capacities 0/1/2/7/8/11/12/18/25/26/32/127/128/510/512.
GIF/TGA prefixes execute individually, preserving early EOF and late assertions.
Indexed PCX controls cover header/body completion and the subtraction/seek of the
769-byte EOF palette region before later buffer checks.

Panic pairs require failed exits, no partial stdout, the exact sole native message
and equal nonempty initialized snapshots. Snapshots compare every caller buffer
byte, the original memory input, actual disk bytes and borrowed descriptor position.
Private wrapper cursors, cached stream state and codec internals are not exposed.
Successful complete samples also compare image dimensions, storage tag/count,
every decoded pixel byte, animation loop/frame counts and frame pixel bytes and
f32 duration bits. Prefix/control results expose only initialized public metadata;
pixel/frame bytes are omitted there. Palettes, inactive backing, padding, pointer
identity and allocator effects remain unobserved, avoiding undefined Source tails.

**40 bounded XBM loop pairs**, ready-state SHA-256
`0f2daf83f99d0dba7096f4d4c933da9d653415d5aa9345df7556964678174477`,
cover a single define line and a complete XBM sample, both public operations,
all six routes and file capacities 32/128. The native detector repeatedly peeks
its first `#define` line without consuming it; public XBM reads consequently never
reach the decoder. Both processes must emit equal initialized readiness, stay
active for 0.5 seconds with no other output/errors, and be killed by the runner.
They are not returning observations or a claimed successful XBM public decode.

Consumer regressions pin the three-byte PAM registry failure with the borrowed
descriptor at three and a 32-byte buffer retaining input plus untouched 165 bytes;
and repeated GIF loads retaining indexed1 pixel `01`, one frame, loop count seven,
duration bits 1052602532, descriptor position 62 and a 128-byte buffer retaining
all input plus 66 untouched bytes. Twelve exact compiled records / 24 calls match
in each mode, through all four file/path routes.

All 61 image and 58 Vaxis test files pass, with production image/file tests and
nineteen application/platform/unit/fixture checks. Historical public file-writer
hashes remain unchanged in both modes. Native historical image API assertions
retain 6,528 encoder cases (`e49e6984a209c47b`) and 589,824 memory detection cases
(`ac90c12c037cfaf4`) in both modes. Cross builds establish compilation only.
Formatting, diff and Python compilation checks pass.

The pinned V compiler emits outer cleanup before a propagated call in a test's
`match` expression. Its generated C and failed unit output are retained; named
assignments avoid that compiler defect. Source algorithms and visibility remain
unchanged. Full Source/library/DEFLATE/math/SIMD/fmt/version and before/after
implementation/fixture/runner/helper/input hashes protect evidence. An interrupted
RAM-backed run was discarded; final evidence uses persistent storage, independently
replayed and archived with every member read back.

Custom/nonseekable streams, OS failures/short reads, path races/symlinks, allocation/
OOM/GC/lifetime, larger dimensions or malformed successful pixel tails, other CPU
vector selections, const/narrow/enum/boxed representations, physical layouts,
big-endian/32-bit runtime and portable ABI remain boundaries. This proof certifies
the stated public routes and inputs, not every underlying decoder behavior.
