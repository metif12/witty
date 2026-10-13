# Public indexed storage factory

`IndexedStorage[T]` supplies the public generic record, full/default and explicit
palette constructors, capacity lookup, palette resizing and cleanup. All five
named indexed records also expose `palette_size()` and `deinit()`.

V represents Source's compile-time `PaletteSize` member with a static function.
Resize is a static call so the pinned V compiler can construct generic records
without eagerly instantiating unsupported capacity arithmetic:

```v
mut storage := zigimg.IndexedStorage.init_palette_size[u8](7, 16)
zigimg.IndexedStorage.resize_palette[u8](mut storage, 8)
capacity := zigimg.IndexedStorage.palette_size[u8]() // 256
storage.deinit()
```

The constructors allocate the full palette and expose the requested active
length, initialized to opaque black. Resizing changes the slice descriptor and
retains the original allocation. Copied records have independent slice lengths
and shared palette/index elements. Cleanup uses V's GC ownership and leaves
descriptors unchanged; allocator selection, reclamation, OOM and lifetime are
runtime adaptations.

`verify_indexed_generic_reference.py` imports complete unchanged Source at its
original visibility. Source Debug/ordinary V and Source ReleaseSafe/production
V both match **2,384 returning records**, SHA-256
`c0b156d0c049b331e851d03790c796d6e7f10fbb5dcc4ca699928c6ebac6a554`.
Bool, unsigned/signed 8/16-bit integers and three aliases cover active lengths
from zero to capacity, empty/nonempty indices, default/full construction,
initial opaque palettes, full explicitly initialized backing storage,
shrink/regrow, shared element mutation, independent copied lengths, by-value
returns and whole-record replacement. Observations retain every initialized
index and an FNV-1a hash of every active palette byte; both observer library
implementations are pinned. Uninitialized indices and inactive palette bytes
are never observed.

Five named records compare capacity, construction and cleanup calls. Three
additional records compare the 2^32 capacities of u32/i32/f32. Thirty-two exact
capacity failure pairs compare constructor/resize failures and retained active
palette state, including maximum usize inputs. Failure-state SHA-256 is
`de4f2c99de990d467f02db399ebdc050189e8b85575dcbd0cc59dcb3040a53fd`.
Eight constructor/cleanup compiler pairs and eight immutable-resize rejection
pairs pass. Three direct u64/i64/f64 record pairs pass; their 2^64 capacities
cannot be returned in the native usize/V u64 capacity APIs, and three paired
compiler controls retain that boundary.

V ignores required markers on generic records: sixteen Source field-omission
rejections remain V acceptance. Two Source built-ins alias the u8/u16 factory
specializations, while V retains distinct named records for constructor checks
and PixelStorage union tags. Those identity differences are measured separately.
Source sub-byte index types retain the existing named V byte carriers; the
generic factory does not introduce physical u1/u2/u4 index types.

The V capacity API covers bool and native scalar types up to 32 bits. Source
can define capacities for further generic types and as larger compile-time
integers; those capacity forms remain unrepresented. u32/i32/f32 constructors
would require a full 2^32-entry native palette even when its active length is
zero. They exceed V's signed array-length carrier. Four V-only controls verify
explicit palette/pixel-count length failures before allocation. No matching
Source allocation or OOM behavior is claimed.

The fixture initializes its local with an explicit generic record type before
assigning a constructor result. Without that type, V 0.5.2 generates locals
using the last instantiated index type; retained previews contain the C errors.
Ordinary and production native builds plus Windows/Linux compilation cover the
represented call pattern.

The existing 4,393-record named/raw-storage proof retains its returning and
97 strict failure-state hashes in both modes. All 61 image and 58 Vaxis test
files pass. Twenty-three production/platform checks cover six pixel/editor/
model/PCX tests, native/Linux application checks, three Windows DLLs, four
Windows matrix executables, two Linux shared libraries and the new generic
fixture's Windows ordinary/production and Linux builds. Cross builds establish
compilation coverage.

Complete Source SHA-256 is
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`; selected
library SHA-256 is `ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Compiler versions and before/after implementation/runner/fixture/input/consumer/
observer hashes protect the proof. Empty pointer identity, undefined/freed
storage, packed/native slice layout, boxed union copies, wider array extents,
allocation/lifetime and unrepresented types/callers remain boundaries.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_indexed_generic_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v --workdir /path/to/empty/workdir
```

Session artifacts are retained at
`/Users/alex/.cache/witty-indexed-generic-20261013/verified-proofs.tar.gz`, with
checksum, per-file manifest and complete read-back verification. Development
previews and the platform script's incorrect test-filename failure are retained.
Completed platform checks were preserved and remaining checks resumed using
the existing model test. Regenerable task-owned caches and temporary files are
excluded. Earlier completed checkpoint archives were checksum-verified before
their task-owned caches were pruned to recover disk space.
