# Window-based widget comparison

The three implementations translate the runnable public APIs in local vaxis
`src/widgets/alignment.zig`, `Scrollbar.zig`, and `ScrollView.zig`. They use the
existing retained `Window` and `Screen` and are separate from `vxfw.ScrollView`
and `vxfw.ScrollBars`.

The source's nested declarations follow this repository's flattened naming:

| Zig API | V API |
| --- | --- |
| `widgets.alignment.center/topLeft/topRight/bottomLeft/bottomRight` | `alignment_center/top_left/top_right/bottom_left/bottom_right` |
| `widgets.Scrollbar` | `Scrollbar` |
| `widgets.ScrollView` | `ScrollView` |
| `ScrollView.Scroll` | `ScrollViewScroll` |
| `ScrollView.VerticalScrollbar` | `ScrollViewVerticalScrollbar` |
| `ScrollView.BoundingBox` | `ScrollViewBoundingBox` |
| Anonymous content size in `draw` | `ScrollViewContentSize` |

Call `draw` before content writes so the scroll offsets are restricted to the
content size. The default vertical scrollbar has one column of content padding:

```v
mut view := vaxis.ScrollView{}
view.input(key)
view.draw(win, vaxis.ScrollViewContentSize{cols: 80, rows: 200})
view.write_cell(win, content_col, content_row, cell)
```

The comparison checks all five alignment results, both axes of saturated input,
explicit restriction, every bounding-box predicate, scrollbar rounding and
clipping, background/custom-glyph styles, reserved content padding, translated
writes, and all retained screen cells. Cells include the grapheme, width, every
style component, default/wrapped flags, and hyperlink values. The corpus includes
zero-sized windows and 64-bit `usize` boundaries. V serializes `usize` through
`u64.str()` to avoid the pinned compiler's signed interpolation of large values.

The unchanged source has one inherited unsupported API: `ScrollView.readCell`
returns bare `return;` from a `?Cell` function at source line 125, so calling it
fails to compile with Zig 0.15.2. V leaves that method unavailable; the probe
checks both compilation rejections and reads content through `Window.read_cell`
after writes. The source is never patched for verification.

The source tree is pinned by SHA256
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed`
using sorted relative paths, NUL separators, and file bytes. This records the
local extracted source; it does not establish its Git revision. The native probe
imports a byte-for-byte copy of that tree. It does not exercise the unrelated
source legacy writer adapters or image/unicode dependencies.

Source checked multiplication and coordinate casts are explicit V panic checks,
retained with `-prod`. Saturating operations keep their source order, including
single-column padding when a scrollbar glyph is wider than one column. Existing
Window coordinate and allocation adaptations apply.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 vaxis/verify_widgets_reference.py /path/to/local/vaxis /path/to/zig /path/to/v
```

The probe executes on a 64-bit host and defaults to the native macOS ARM64 target.
