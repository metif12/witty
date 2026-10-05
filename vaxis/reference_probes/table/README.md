# Table reference comparison

From the repository root, run:

```sh
python3 vaxis/verify_table_reference.py /path/to/vaxis /path/to/zig /path/to/v
python3 vaxis/verify_table_reference.py /path/to/vaxis /path/to/zig /path/to/v --v-prod --zig-mode ReleaseSafe
```

The runner verifies the entire unchanged vaxis `src` tree against SHA256
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed` and
verifies the locked uucode package through the shared classic-widget build
helper. It copies both sources and builds uucode's unchanged table generator.
The explicit macOS 14 target avoids Zig 0.15.2's host macOS 26 libc boundary;
`--target` and `--uucode` can select another compatible native setup.

The 7,058 returning records compare context defaults, four width styles,
collection acceptance, complete screen cells and context state, callback errors,
and callback mutations. The renderer matrix covers column selection, custom and
field headers, alignment, borders, selection/active colors, scrolling, clipping,
truncation, and preexisting active offsets. Numeric records include direct and
optional aliases, zero, negative zero, infinities, NaN, subnormal and fractional
values, finite extrema, signed extrema, and unsigned extrema. String, mutable
byte-slice, and enum aliases are distinguished, including optional enum dots and
missing-value markers. The output SHA256 is
`a9aa2c68decee1101f62bfc02cd52ccbfceed8142377c1919c9a60c194c91a82`.

Fourteen isolated trap modes preserve checked width/cast/padding/index/counter
operations in V production builds. Unexpected domain errors and returning paths
are rejected explicitly. Four paired compile probes require ordinary compiler
errors, rejecting compiler crashes and generated-C failures. Source slices hit
the obsolete `Pointer.Size.Slice` spelling. Direct and optional string slices
hit the unchanged source formatter's unsupported slice element type. Required
context colors must be supplied in both languages. Zig 0.15.2's actual
`std.ArrayList` type name fails the source's legacy substring detector and
returns `UnsupportedTableDataType`; the runnable collection is
`std.MultiArrayList` with an allocator.

`TableMultiArrayList[T]` presents V rows and clones them before drawing, matching
the source's allocated row snapshot. The allocation flag preserves allocator
presence; GC replaces allocation errors, arena lifetime, and explicit frees.
V `string` represents source `[]const u8`; V `[]u8` represents mutable byte
slices formatted with `{any}`. Unrelated custom `{any}` composites use V's
native `.str()` representation, including V type and field spelling; the matrix
does not claim matching Zig formatting for arbitrary structs, unions, pointers,
or other custom data. The source default `active_ctx = &{}` becomes a heap empty
struct to preserve a non-null pointer rather than its zero-size storage identity.

The source's `.all` renderer visits every field once for each outer field index,
producing repeated N-by-N columns; V preserves this behavior. A `.by_idx` subset
combined with field-name headers leaves source header slots undefined. V rejects
those uninitialized slots defensively; this is a language adaptation, excluded
from the parity matrix and checked source trap set. Subset cases use initialized
custom headers instead.
