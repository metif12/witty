# TextInput source comparison

`verify_text_input_reference.py` hashes and copies the unchanged local vaxis `src`
(digest `bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed`),
then uses `widgets_classic/source_build.py` to verify and generate the exact locked
uucode dependency (`5f05f8f83a75caea201f12cc8ea32a2d82ea9732`; full package
`2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380`). The source
widget and dependency files are unchanged. Direct module wiring selects macOS 14
because Zig 0.15.2's native build runner selects a newer macOS target than its
bundled libSystem stub supports.

```
python3 vaxis/verify_text_input_reference.py /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v
```

Use `--v-prod` for the optimized V comparison. Both modes compare the same 14,346
returning cases (SHA256
`4003872debd68d8f2886119b492cc0d14ac1c5692a049662b043074cb67aaaf0`): repeated
per-grapheme insertion, growth across the 512-byte gap
boundary, valid and oversized left movement/growth, right movement, raw buffer
bytes, key bindings/modifiers, all three width methods, styles, cursor state,
clipping, zero-width/zero-height drawing, malformed-byte editing/drawing, and
returning counts 65,534/65,535. Twenty-two isolated traps check right movement
past the suffix, checked allocation/cursor/end/gap arithmetic, large public
cursor values, zero-count left movement, invalid-cursor check ordering,
and the source iterator's
underflow on malformed UTF-8 followed by a combining mark in insertion, cursor,
deletion, count, and width operations. They also retain the count overflow at
65,536 ASCII graphemes and display-width overflow at 32,768 wide characters.
Deliberate native traps disable core dumps and reject `UNEXPECTED` results.

The caller-buffer extension adds 96 cases and two traps. The full Debug matrix
now matches 14,442 records and 24 traps, SHA256
`d334fced0a688b98041dc3d197722ecfb4fb54dca8b1c6baf20b4e11cbc51b9b`,
with the original 14,346-record prefix unchanged. `--slice-only` compares the
extension alone; it also passes with `--v-prod`, SHA256
`4ea3a4ac46f14ef27d6583ab094004525b0af9e5a0e2356d91cfc1c738a5e149`.
These cases compare the borrowed prefix, unchanged trailing bytes, raw byte
content, gap movement and pointer identity. The traps retain insufficient
caller storage and aliasing `@memcpy` arguments. Seven focused consumers pass.

The V call shapes use `TextInput.new()` and `TextInputBuffer.new()` with GC-owned
arrays in place of allocator arguments. `update(Key)` represents the source's
single-case key-press event union. `draw_in_window[_with_style]` is the Window
adapter; `draw[_with_style]` returns cell commands. The source-public
`draw_offset`, `prev_cursor_col`, `prev_cursor_idx`, and `scroll_offset` are now
`pub mut`, retaining their u16 widths. `slice_to_cursor()` remains the copied-
string convenience adapter; `slice_to_cursor_into(mut bytes)` exposes the source
caller-buffer behavior and returns a borrowed prefix. Keep caller storage alive
while using it. Allocation failures, source slice
lifetimes, and capacities beyond V's int-sized arrays are outside this comparison.

This checkpoint corrects insertion, cursor/deletion/count/width/draw iteration,
checked buffer growth, slice boundaries, insertion, both gap movements and
both gap growth methods, with saturated left cursor movement, and zero-width
Window drawing order. Its private byte decoder and
width helper preserve the locked source for malformed UTF-8 without changing
the module's global grapheme/width APIs. TextInput retains checked source u16
count/width/column/index overflow in both ordinary and optimized V builds.
`width_to_cursor()` returns int as a V representation adaptation; its accepted
values and checked overflow remain those of the source u16 result.
