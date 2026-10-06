# Layout widget source comparison

`../../verify_layout_reference.py` compares the unchanged public Center,
Padding, Border, FlexColumn, FlexRow and SizedBox widget adapters. All six
compile and run on native macOS with the original source bodies; SizedBox is
called through its public widget adapter. No dependency helper is appended or
rewritten.

The complete original Vaxis `src` tree must have SHA256
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed` before copying.
`widgets_classic/source_build.py` also checks the locked uucode package SHA256
`2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380`
and runs its unchanged table generators. The widget file hashes are:

| Original file | SHA256 |
| --- | --- |
| Center.zig | `20166aa6060526ff2b98098043e0854a58c22077b1b66d331bc568433a238c70` |
| Padding.zig | `4114bcf3116e06261a1151fab49ed50bbfa09d56a4f441223b3822dee6822cc0` |
| SizedBox.zig | `4ee6bbb855b6fe286aa5b2f21911f82c026f61e1bf0799b00aa33e36629d4fc9` |
| Border.zig | `db200145775b46cc64d86a1d3cb15f2a376409bef307e97bbbe485173bffe7e4` |
| FlexColumn.zig | `fb49dca19dee2ab2d9f2713e1dd837b000c090a146cec3fe5bbb67a37d7aa04c` |
| FlexRow.zig | `6d6d8b075e78f530e234629fec5335018073391e01da8b62f51e4c29e7ef49f3` |

Run from the repository root:

```sh
python3 vaxis/verify_layout_reference.py /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v
python3 vaxis/verify_layout_reference.py /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v --v-prod
```

The default is Zig Debug/V ordinary; `--v-prod` selects Zig ReleaseSafe/V
production unless `--zig-mode` overrides it. The target is native
`aarch64-macos.14.0`, libc, Zig 0.15.2 and pinned V 0.5.2. The runner explicitly
sets `VEXE` to the selected V executable.

Both modes pass 27,963 returning records and 37 strict isolated trap pairs.
Returning records compare helper values, errors and callback constraints/order,
visible mutation of the parent and Flex items, recursive surface sizes/origins,
widget identity, cell-buffer lengths and FNV-1a checksums of grapheme bytes,
width/default/bold/reverse/foreground-index fields. Border tests also compare
borrowed label pointer counts and checksums before/after mutation within the
same live backing allocation. Cases cover bounded/unbounded dimensions, zero
and maximum values, all padding helpers, min/max conflicts, empty and variable
child slices, flex weights/remainders, all border label alignments, malformed
bytes, combining marks and ZWJ text under all three width methods where the
source returns.

Callbacks can change padding, border labels/style, later child sizes, current
and later Flex weights, or replace a Flex's child field during either pass.
Each source loop captures its initial slice. An explicit borrowed V header
local preserves that iteration lifetime when the field is replaced; live field
length checks inside distribution branches remain live. The first-pass size
cache preserves source value copies, and Column measures all items while Row
measures only zero-flex items. Column's checked remainder subtraction and Row's
saturating subtraction remain distinct. Child errors precede geometry checks
that occur after drawing. Padding may expand beyond a smaller parent bound,
and an empty Flex allocates its minimum size even if it exceeds the maximum.

Trap checks require an actual panic header with the expected category, nonzero
exit, no stdout and no actual `UNEXPECTED:` diagnostic. Backtrace excerpts do
not satisfy the check. Source assertions map to `Assertion failed`; the wide
grapheme-to-u8 cast checks the separate Source and V diagnostic categories.
Overflow, divide-by-zero, dimensions, sums, proportions, labels, empty-surface
products and errors before later geometry are verified under production too.

Source allocator parameters, arena lifetime and allocation failures are
represented by V-managed storage. The comparisons exercise child callback
allocator errors, rather than claiming allocator-failure or ABI parity. A
callback changing an initially positive FlexRow weight to zero before its
second-pass visit makes Source read an uninitialized size-cache slot. That
undefined branch is excluded from parity; the existing V cache remains zero
initialized. Retaining first-pass arena allocations after the source frees the
layout arena is also outside the defined comparison. All measured callback
cases use initialized cache slots and live borrowed inputs.

Four focused V consumer tests cover captured iteration in both passes, errors
before arithmetic, label borrowing/style mutation, and constraint quirks.
Returning-output SHA256 (joined records, without a final newline) in both modes:
`7530b735b2181ad9675dbf776110002b759a5fd3c60df25f2e794f553984c164`.
