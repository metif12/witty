# JPEG public records

`verify_jpeg_records_reference.py` compares public JPEG records with unchanged
zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`: Source Debug against ordinary
V, and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_jpeg_records_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. `--target` defaults to
`aarch64-macos.14.0`; a cross build alone does not verify runtime behavior.
`--timeout` bounds commands. `VTMP=/path/to/compiler-temporaries` can keep V's
generated compiler files on a volume with sufficient free space.

Component, frame header, JFIF header, quantization header and Huffman table fields
are public/mutable and require explicit initialization of the represented Source
fields. `JpegComponent.read` is public, sampling maxima return `usize`, and frame
header/Huffman table cleanup hooks are available. GC replaces explicit allocation
and reclamation; the hooks do not establish Source allocator or lifetime behavior.

Quantization tables now use a tagged sum type with one required fixed array:

```v
mut table := zigimg.JpegQuantizationTable(zigimg.JpegQuantization8{
    values: [64]u8{init: 1}
})
if mut table is zigimg.JpegQuantization8 {
    table.values[0] = 2
}
table = zigimg.JpegQuantization16{values: [64]u16{init: 257}}
```

`JpegQuantization8` and `JpegQuantization16` represent the Source `q8` and `q16`
arms. They replace the previous record containing a precision and both arrays.
The decoder checks the q8 arm during actual sample multiplication, after indexing
its destination. Empty q16 images still succeed. The existing decoder proof
continues to cover the exact inactive-arm failure in both modes.

| Returning observations | Count |
|---|---:|
| Public component reads, validation order, truncation and positions | 12,288 |
| Component/frame header mutation, scalar copies and shared slices | 3,072 |
| Both quantization arrays, each element and whole-table replacement | 768 |
| Quantization header fields, tags and whole-table replacement | 1,536 |
| JFIF header field mutation and scalar copies | 18 |
| Huffman inline-array copies, map value aliases and live reader borrowing | 64 |
| Empty header sampling maxima | 1 |
| **Total** | **17,747** |

Returning SHA-256:
`924be5dd9166431cce22672eead65ce550a96e1d48fc570078d35f145ca2323d`.

Seven complete constructors compile in both languages. Twenty-two represented
field omissions, seven mutations through immutable bindings, an empty table and
a constructor attempting both arms receive ordinary compiler rejections. The
runner checks the actual error lines and excludes signals, crashes and backend
or linker failures. Two additional compile controls exercise cleanup hooks.
The full returning programs compile and run, including direct field mutations.

Separate measured differences are excluded from the matching corpus:

- Eighteen payload-copy observations differ. V sum types share boxed payload
  storage on assignment; Source copies fixed quantization arrays by value. This
  includes a table inside a copied quantization header. Mutating an existing arm
  can therefore affect its copies in V. Replacing the whole table preserves the
  copied value, as verified in the matching corpus.
- Source accepts mutation through a const header's mutable component slice. V
  rejects that operation through an immutable header binding. One compile pair
  records this difference; mutable header copies retain shared component storage.
- Five construction pairs measure V byte carriers accepting values rejected by
  Source u4 sampling/header fields or u5 Huffman acceleration lengths. Returning
  observations stay within the Source field domains. The u32-packed Huffman map
  key and V map do not enforce Source key typing, order, capacity or layout.

The separate boxed output hashes are
`7ddf49db31a6257661b6d7046a12f24466f517b43e4846a896cb176e5d485936`
(Source) and
`22607c4ce6f4ad8ac93484824f0ecb3c5004ea4f0957dc823c05bfe570aebbca`
(V), in both modes.

The runner pins the full Source src tree, compiler versions and the selected
Zig memory/debug/reader/writer/file/map library files. It copies Source unchanged
and obtains its private component/key types through public field and return types;
it does not change visibility or substitute a source algorithm. Before/after
checks protect Source, compiler-library files, fixtures, the runner and every
top-level V image implementation file. Commands, generated constructor consumers,
raw results, diagnostics, provenance and summary metadata are retained.

The [decoder contract proof](../jpeg_contracts/README.md) retains all 15,805
returning observations and thirty panic/state pairs. The historical JPEG matrix
still matches 132 returning rows and its exact marker failure in both modes;
seven inputs reading undefined Source coefficient storage remain excluded.
All 55 image and 58 Vaxis test files pass. Native/Linux application checks, three
Windows dependency DLLs, two Linux shared libraries and the new Windows test
executable in ordinary/production modes build successfully. Cross builds use
`-gc none`; cross-target runtime is not certified.

This checkpoint does not certify the remaining public Frame/Scan/decoder record
APIs, allocator/OOM/GC/lifetime behavior, undefined Source storage, aggregate ABI,
const-pointer typing, arbitrary SIMD selection or wider V field values. Source
`quantization.Header.read` still fails under Zig 0.15.2 on its u8-to-u4 assignment;
the decoder uses its own compiling table parser. Generic `as` cast diagnostics
are language-specific; the decoder's explicit inactive-arm check preserves the
Source category. JPEG's pinned no-op writer is unchanged.
