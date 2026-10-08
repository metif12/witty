# PNG headers and borrowed chunk names

`verify_png_header_reference.py` calls the unchanged public HeaderData, ColorType,
Chunk, ChunkHeader and loadHeader APIs at zigimg commit
`d7b7ab0ba0899643831ef042bd73289510b39906`. The complete `src` tree is pinned to
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b` and checked
before copying and after execution. Selected Zig reader/writer, CRC, debug and
memory sources are pinned separately. No dependency bodies or visibility change.

From the repository root, with Zig 0.15.2 and V 0.5.2:

```sh
python3 zigimg/verify_png_header_reference.py "$PNG_SOURCE" "$ZIG" "$V" \
  --workdir /tmp/witty-png-header-debug
python3 zigimg/verify_png_header_reference.py "$PNG_SOURCE" "$ZIG" "$V" \
  --v-prod --workdir /tmp/witty-png-header-safe
```

`PNG_SOURCE` is the recovered package directory containing `src`. Each workdir
must be absent or empty. The default target is `aarch64-macos.14.0`; override
`--target` for another native host. Ordinary V pairs with Source Debug; `--v-prod`
pairs with ReleaseSafe. A private Zig global cache avoids stale shared-cache
references. Exact commands, versions, modes, inputs, raw output/diagnostics,
panic state and fixture/runner provenance are retained.

Both modes compare 59,241 returning records, output SHA-256
`4c45f77f60ecc57f4c0a02c7c666d514eb3112b49bc35bd5d0cba65f2073db0d`.
They cover safe u8 depth/channel products, checked u32 multiplication/addition
neighbors, zero/extreme dimensions, all 24 represented pixel formats, palette
helpers, open compression/filter tags, 4,096 borrowed-name mutations, signature
and header truncation, every single header bit mutation, closed color/interlace
tag validation, CRC errors and file buffers of 13/16/17/31/33/64 bytes.

Eleven isolated failures require the exact panic category and an observer file
containing all seven initialized header fields. Their retained-state SHA-256 is
`64d5b333aa2818162757b169e3a17bc82bdcd5fbeaab6291577b4981b4875797`.
The six integer overflow cases preserve u8 pixel arithmetic and u32 line
arithmetic, including pixel overflow before multiplication by zero. The five
unsupported-depth cases preserve Source unreachable branches. A nonzero exit,
signal, diagnostic mention in a backtrace or an unexpected-return sentinel alone
cannot satisfy a failure check.

Source Chunk.init requires a sentinel-terminated four-byte array pointer. Three
wrong-length literals fail with ordinary Source type diagnostics; V's dynamic
string adapter instead has three explicit runtime guards in both modes. These
are separate compiler/adapter observations, not paired Source runtime failures.
Chunk IDs snapshot bytes while copied names continue to borrow caller storage.
ChunkHeader.name borrows the native-endian numeric type field. The loader retains
the pinned borrowed-IHDR CRC behavior: small file buffers can overwrite header
bytes before CRC validation and reject an otherwise valid PNG.

The tests establish defined runtime behavior on initialized storage. They do
not certify constructor field omissions, direct mutable Chunk fields, const
borrow enforcement, sentinel lifetime, pointer/allocator ownership, aggregate
ABI, arbitrary invalid enum construction, undefined Source storage or execution
on other targets. HeaderData/Chunk records still admit V defaults; Source's
non-exhaustive compression/filter enums remain unsafe V numeric adapters.
