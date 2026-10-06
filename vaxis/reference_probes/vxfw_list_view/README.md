# ListView source comparison

`verify_vxfw_list_view_reference.py` hashes and copies the unchanged pinned
Vaxis `src` tree, builds its real public ListView methods through `main.zig`,
and supplies the locked uucode module graph and generated tables through
`widgets_classic/source_build.py`. The native fixture does not replace or
edit ListView. Source tree SHA256:
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed`.

Run from the repository root:

```sh
python3 vaxis/verify_vxfw_list_view_reference.py \
  /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v
```

`--v-prod` selects optimized V and native ReleaseSafe. `--zig-mode` can
explicitly select Debug or ReleaseSafe, and `--timeout` controls the returning
matrix deadline. The deliberate inherited loops always have a separate
one-second deadline.

The matrix contains 5,284 returning records covering `widget`, `handleEvent`,
`draw`, `nextItem`, `prevItem`, and `ensureScroll` with slice and builder
sources. It compares full public scroll/cursor/item-count state, event
consumption and redraw, command count, builder calls and cursor arguments,
child draw constraints and callback error ordering, and recursive returned
surface metadata, buffer lengths/default/indicator counts, cursors and origins. It includes builder
holes, empty sources, zero-height children, cursor wrappers, viewport edges,
out-of-view large u32 cursors, large valid i17 heights, and callbacks that
mutate ListView state before returning or failing.

The 20 strict isolated traps cover checked i17 scroll/draw arithmetic, u32
cursor/top arithmetic, unsigned empty-slice subtraction, cursor-wrapper u16
width and area, cursor bounds, and source assertions. Traps require a nonzero
exit with an anchored source/V panic header of the expected category, no
ordinary output, and no `UNEXPECTED` marker. Core dumps are disabled. The
constructor checks prove three complete constructors and four paired ordinary
omission rejections for Builder userdata/buildFn, ListView children, and the
Source slice payload (`ListSlice.widgets` in V).

Debug/ordinary V and ReleaseSafe/production V use the same returning record
SHA256:
`1c0060888edc4691761a3d3e2e5d9751c4a673b181457850c147cf9f104c9a9e`.
Five focused V consumer tests exercise incremental scrolling and cursor
navigation, error state ordering, builder backtracking, large cursor bounds,
and the managed-storage adaptation described below.

Source's missing-item backtracking saturates at zero and loops indefinitely
if a builder cannot supply item zero. Both `nextItem` and `prevItem` preserve
this behavior; their paired isolated timeout checks are separate from the
returning matrix.

At `src/vxfw/ListView.zig:447`, the inherited tall-child TODO calls
`child_list.deinit` and then appends to that same deinitialized ArrayList.
Its storage is undefined. The runner measures a reachable zero-height child
and zero-height viewport separately and does not claim parity for that
branch. Native Debug and ReleaseSafe produce `integer overflow` in the poisoned
ArrayList allocation path. V retains managed child storage and returns a one-child
surface; a focused consumer verifies that explicit GC adaptation.

Source allocators and allocation failure are represented by managed V
storage. Callback `OutOfMemory` is compared, but native allocation-failure
injection is not covered. Native array lengths are usize while V array
lengths use int; compared realizable arrays and states fit both. V stores
Source i17 scroll fields in i32, with explicit production checks at source
arithmetic boundaries; values outside the Source i17 representation are
outside this comparison. Private source structs/unions are flattened into
the existing V module naming convention.
