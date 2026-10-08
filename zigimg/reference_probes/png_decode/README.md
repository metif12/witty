# PNG decoder and processor comparison

```sh
python3 zigimg/verify_png_decode_reference.py \
  /tmp/witty-png-audit-20261008/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /tmp/witty-png-zig-20261008/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /tmp/png-decode-debug
```

Add `--v-prod` for V production and native Zig ReleaseSafe. `--zig-mode`
permits an explicit override. The default native target is
`aarch64-macos.14.0` with libc. `--timeout` limits each returning corpus run;
`--bounds-only` builds and checks the isolated panics and inherited loop.
`--zig-cache PATH` permits a reusable task-specific global compiler cache.
`--workdir PATH` retains the unchanged copied source, fixture inputs, binaries,
exact build/run argv and V environment, full stdout/stderr, source/fixture/
implementation/compiler-dependency hashes and result metadata. The directory
must be empty or absent; omitting it removes temporary artifacts on completion.

The unchanged dependency is zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906`, complete `src` SHA256
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
The selected Zig 0.15.2 flate/reader/writer files are pinned together to
`e8898fcced291d899efc9ebacf42762954ac5a1e088283cee0f1f261a498cab5`,
the formatter files to
`9ad2e71bc2e950a01e29eec9d20a6e9674097602774399a5451839a23c4b278b`,
and `mem.zig` plus `debug.zig` to
`d8e33d24ad79f9e3cf7694a9914bcf8023d5125b15f1b51930fab0e91114e65e`.
Original and copied dependency trees, these compiler dependencies, fixtures,
runner and owned reader/processor files are checked before and after execution.
Fixtures call unchanged public methods; no dependency body or visibility is
changed and no private-source wrappers are added.

The historical corpus retains **60,760 returning decoder cases** and SHA256
`96ee46b18345684842d8ae9cd64290f7c5e9b86228458a83386a602bbd646e9c`.
It covers all 15 accepted color/depth combinations, five PNG filters,
noninterlaced and Adam7 images, three zlib strategies, IDAT splits and CRCs,
malformed chunks, truncation, metadata, palette/transparency ordering,
callback positions/errors and large buffered reads. File transports use
16/17/31/33/4096-byte buffers, including inherited borrowed-IHDR CRC behavior.
Native decoding defines error/status, stream position, dimensions, defined
pixel/active-palette bytes, tRNS/PLTE flags, diagnostic bytes and callback traces.

A separate extension compares **64,395 returning public processor cases**,
SHA256 `09ac13edac49df9819661dccd6625541d1e4590d0e3935e4738bf01bb447d6af`.
It exercises concrete tRNS/PLTE row methods and erased callback adapters,
all ordinary pixel-format tags, accepted/bypassed destination formats,
short/empty/padded rows, grayscale16's inherited byte-index comparison,
palette rows and alpha updates, header/format/chunk-length combinations,
already-processed state, source errors/stream positions and null callback
defaults. Consumer-owned row and palette bytes are explicitly initialized.
Successful transparency union fields are observed by tag and scalar value or
slice length. After a returned chunk error, the union is excluded: a failed
source `try` assignment can leave payload bytes undefined. Unread allocated
alpha tails are never hashed. Defined flags, positions and initialized
consumer rows/palettes remain compared on those error paths.

**26 strict panic pairs** retain the eight historical decoder failures and
add public callback reachability of both 16-bit spreading exact-division checks,
direct palette/row bounds and partial-prefix writes, processor exact division,
unsupported source-format/union arms, processed-tRNS skip overflow and
direct `loadWithHeader` zero-dimension division. Every failure requires a
nonzero exit, empty ordinary stdout, an actual anchored panic header with
the expected category and no emitted `UNEXPECTED` line. Quoted source or
backtrace text cannot satisfy or invalidate those checks. Core dumps are
disabled. Each pair also compares defined state at the panic; the aggregate
state SHA256 is
`f2c3d51b1acd37f3f435e2ac9399ae936ce897ff59a34426164bebba2ac8be35`.
Native fixtures install `std.debug.FullPanic`, snapshot state to a separate
file, then call the ordinary default panic handler. V uses an `at_exit`
observer after its ordinary panic path. Decoder state observations include
positions, processor flags, callback hashes and initialized palettes, never
unwritten image pixels. Direct processor snapshots additionally include
initialized row/palette bytes and fields. Panic ABI and exact diagnostic
wording beyond the categories are excluded.

The four-byte RGB24-to-grayscale-alpha row preserves the source's inherited
zero-increment loop. Source and V must independently time out after one
second with no output/diagnostics; this is reported separately from panics.
Repeated 16-bit tRNS stride assertions, Adam7's byte-sized row overflow and
the grayscale16 byte-index behavior are likewise retained, rather than fixed.
Four focused consumer tests complement seven existing decoder tests; both
ordinary and production builds exercise those consumers.

GC replaces supplied allocators and reclamation. Allocator failures, undefined
source palette state before initialization, undefined union/pixel/alpha tails,
giant allocations beyond V's signed-int array/string representation, pointer
ABI, allocator-backed lifetime after reclamation and WebAssembly-only arithmetic
are excluded. Callback signatures use V's explicit erased-context/vtable adapter
in place of Zig's generated typed-pointer functions. Optional fields and generic
factory syntax have their existing V representations; this bounded proof does
not establish every public record constructor contract or full PNG/DEFLATE/IO
parity. Header, diagnostic, filtering and chunk-writing contracts have separate
comparisons.
