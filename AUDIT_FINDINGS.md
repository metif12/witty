# Ongoing Source-Fidelity Audit

This is a working record of the function-by-function audit of Witty against the
pinned Ghostty source. It is not evidence of full coverage, and the repository
must not be described as a 100% translation while the remaining divergences
below exist. Earlier versions of this document overstated the completed review.

## Bugs found and FIXED this pass

| Area | Bug | Fix |
|---|---|---|
| terminal/modes | `ModePacked` was `u32` with `& 31` masking, but 40 modes exist → modes ≥32 (cursor_keys, mouse_alternate_scroll, alt_esc_prefix…) aliased onto modes 0-7. Also 4 wrong table defaults and a hardcoded `data:5` default. | `data` → `u64`, mask `& 63`; corrected `send_receive_mode`/`mouse_alternate_scroll`/`ignore_keypad_with_numlock`/`alt_esc_prefix` defaults; default now derived from the table via `build_default_modes()`. |
| terminal (screen/types/style) | SGR 58 underline color written into the **foreground** fields (no dedicated storage); `underline_color_rgb` read from fg. | Added `underline_r/g/b/palette` to `CellStyle`; `set_attribute` and `underline_color_rgb` use them; `eql`/`hash` include them. |
| terminal/terminal | `index()` didn't mark the new row `prompt_continuation` on a plain linefeed in prompt/**input** mode (logic was only in `print_wrap`, only for `.prompt`). | Added the `defer` marking for `semantic_content != .output` (prompt AND input). |
| terminal/stream, terminal/terminal | Ghostty's repeat, character-edit, line-edit, and scroll actions carry `usize`, but Witty collapsed them into the shared `u16` event field and then narrowed them to V's 32-bit `int` at both handlers. | Add a dedicated `usize` action count, route all eight actions through it, and restore `usize` terminal method contracts; bounded screen operations clamp before conversion to array indexes. |
| input/key | `w3c()` blindly did `- 32` on the char after `_`, corrupting digits (`digit_1` → "Digit\x11"). | Uppercase only `a-z`. |
| input/Link | Flattening the tagged `Highlight` union left `mods` storage on `.always`/`.hover`, and `equal()` compared that source-nonexistent payload. | Ignore `mods` for non-modifier tags and canonicalize it to empty when cloning; preserve payload comparison for `.always_mods`/`.hover_mods`. |
| input/function_keys | `make_kp_keys` returned only the unmodified keypad entry, dropping the 15 modifier combinations. | Generate all 16 (kpDefault ++ pcStyle), `mods_empty_is_any=false` on default. |
| input (Mods) | `Mods.translation()` fully inverted (unset/keep alt and left/right swapped); `int()`/`SideInfo` dropped caps/num-lock + side bits and had no `super` side. | Rewrote translation to match macos-option-as-alt; full packed `int()` round-trip preserving sides+locks. |
| input/keymap | Darwin and no-op keymaps were collapsed into one C wrapper, causing the non-macOS path to reject an empty output buffer and return the input modifiers (minus Ctrl) instead of a completely default translation. The Darwin path also looked up its Unicode layout per keypress and required spare room for a C terminator. | Restore platform-selected keymap files; make the no-op translation ignore every argument; retain Darwin's input-source and Unicode-layout pointers; return an explicit UTF-8 byte length from the Carbon shim. |
| apprt/ipc | The optional new-window argument slice was collapsed to an always-present V array, and all of Ghostty's target/action C ABI projections were omitted. | Preserve absent versus present-empty arguments through the CLI and GTK path; restore target/action tags, unions, C layouts, null-terminated argv allocation, and deinitialization. |
| apprt/structs | Compact `ClipboardRequestType`/`ColorScheme` and non-GTK `Clipboard` enums were widened to V's default 32-bit enum; the flattened clipboard request consequently had the wrong layout outside GTK. | Restore 8-bit compact backing, platform-select GTK's C-int clipboard backing, and assert the resulting request layout on GTK and non-GTK targets. |
| apprt/action | `MoveTab.amount` was fixed-width `i64` instead of source `isize`; present search totals/selections silently wrapped through the signed C projection; and the flattened key-sequence end arm leaked an ignored stale trigger instead of Ghostty's explicit default C trigger. | Carry `isize` through the queued action, range-check optional `usize` counts before reserving `-1` for absence, and canonicalize the C payload of an ended sequence. |
| apprt/none | The no-op runtime's IPC entry point returned plain `bool`, unlike Ghostty's fallible runtime contract and the other application runtimes. | Restore the `!bool` result contract while retaining the source's always-unhandled result. |
| apprt/surface mailbox | The flattened callback erased `BlockingQueue.Timeout`, so the stream handler's nominal instant probe actually performed a forever-blocking app-mailbox push while holding the renderer mutex; selection-scroll ticks also became blocking. | Carry the timeout and `u32` queue size through the surface callback, preserve instant/forever at every producer, and only retry the stream-handler write after releasing the renderer lock. |
| apprt/core bridge | Runtime-neutral preedit/text wrappers invented boolean results absent from `Surface.zig`, and the duplicated embedded size projection returned zero grid dimensions below one cell instead of using `GridSize`'s minimum-one contract. | Restore void error-union callback results and mirror the source floating-point, checked `u16`, minimum-one grid calculation. |
| apprt/runtime | The two-case source enum used default 32-bit V storage, while its source `default` method had been replaced by an unused string dispatcher plus a duplicate free function. | Use byte storage and expose one platform-selected `Runtime.default()` method, eliminating the source-external string API. |
| apprt/embedded text | The internal embedded text result narrowed Ghostty's `usize`/`uintptr_t` text length to V's 32-bit `int` before the public C projection. | Preserve `usize` from the dumped text through the embedded result and assert pointer-width storage with a value above `int` range. |
| apprt/embedded platform | Surface initialization replaced explicit zero/negative scale factors with `1`, accepted platform tags outside the source enum, and constructed Darwin-only platforms on other targets. | Preserve Ghostty's direct `f64` to `f32` scale conversion, reject unknown tags, and return `UnsupportedPlatform` outside Darwin. |
| apprt/embedded key event | The raw `unshifted_codepoint` conversion treated Ghostty's `u21` as a Unicode scalar and rejected values above `0x10FFFF`, although the source cast accepts every 21-bit value through `0x1FFFFF`. | Restore the actual `u21` numeric boundary and clamp only values that do not fit in 21 bits. |
| embedded C text | Successful text projections allocated only the payload bytes and returned a null pointer for empty text, violating Ghostty's sentinel-terminated result type. | Always allocate the trailing byte, preserve embedded NUL bytes via the separate length, and return a non-null sentinel for an empty successful result. |
| osc/color_parser | Hex channel scaling used `>>4`/`>>8` instead of `*255/4095` and `*255/65535`; float intensity rounded not truncated; named `green` = (0,128,0). | Correct scaling; truncate; `green` = (0,255,0). |
| osc/osc9 | OSC 9;12 emitted default `.fresh_line` instead of `.fresh_line_new_prompt`. | Set correct action. |
| osc/kitty_color | `kind_max` = 256 (should be 263 = maxInt(u8)+8); parsed items discarded. | Fixed max; attach items to Command. |
| osc parser | Every payload used an unbounded V array, allocator-required commands were accepted in bounded mode, `end` could not represent an absent terminator, and hyperlink parsing continued after an incomplete option. | Restored fixed/allocation writer selection, the 2,048-byte boundary and sentinel reservation, allocator gating, optional terminators, and source option termination. |
| synthetic/bytes, synthetic/osc | Mutable byte iteration converted an element address into an alphabet index; prompt and PWD generators failed to debit generated component lengths. | Index from the byte value and restore Ghostty's remaining-length accounting. |
| kitty/color, kitty/graphics_image | `kind_max` off-by-one; `Image.format` default `.rgba` (should `.rgb`); `transmit_time` set at init not in `complete()`. | All corrected. |
| configpkg | 9 wrong struct defaults. | `background` 0x282C34, `term` xterm-ghostty, `title_report`/`mouse_hide_while_typing`/`selection_clear_on_copy` false, `cursor_click_to_move`/`clipboard_trim_trailing_spaces` true, `font_thicken_strength` 255, `minimum_contrast` 1. |
| renderer/config | `DerivedConfig.init` hardcoded background/foreground (black/white), empty font_features, all-true font_styles, truncated faint_opacity. | Read `config.background/foreground/font_feature/font_style_* != 'false'`; `ceil()` faint_opacity. |
| renderer/thread | `ThreadDerivedConfig` ignored config (`custom_shader_animation` hardcoded). | Map from config. |
| renderer/metal_types | `MetalTextCell.bearings` were `i32`; ghostty CellText requires `i16` (32-byte GPU struct). | i16. |
| renderer/cell | Foreground rows omitted Ghostty's two cursor lists, so each backend reconstructed cursor ordering by hand; row capacities were discarded on clear/reset; the logical shader bearings were widened to `i32`. | Use the translated `ArrayListCollection`, allocate `rows + 2` lists with source capacities, retain capacities, assert row bounds, store block/other cursors in the first/last lists, flatten them directly, and use `i16` bearings. |
| renderer/size | `Size.grid()` could return zero rows/columns, grid units were widened to `u32`, and same-space coordinate conversion clamped out-of-bounds grid coordinates instead of returning them unchanged. Size definitions and handwritten wrappers also lived in `renderer.v`. | Restore the source `GridSize.init/update` minimum of one, `u16` cell-count units, the coordinate identity fast path, and the source method/file boundaries; remove the unused wrappers. |
| renderer/cursor | Cursor style was duplicated in `renderer.v`, the source `style()` decision was renamed, and preedit offsets/ranges were widened inconsistently. | Restore the cursor-owned `Style` enum and `style()` function, `usize` byte offsets/widths, and `u16` cell ranges. |
| renderer/image, overlay | Pending image length arithmetic ran in `u32`; Kitty pixel conversion was deferred from preparation to GPU upload; placement draw ranges were silently clamped; and overlay grid-to-pixel products used unchecked `int` arithmetic despite the source's checked casts. | Restore `usize` pending lengths, prepare Kitty images as RGBA before committing transmit time, trust the source placement-index invariants, validate overlay dimensions, and check every coordinate product. |
| renderer/row | `never_extend_bg` took no palette and read bg from the style for bg-color cells (color is on the cell); ignored palette backgrounds. | `resolve_bg` faithful to `Style.bg`; callers pass `state.colors.palette`. |
| renderer/renderer | `fg_rgb`/cursor color calls never passed `bold_color`. | (field wiring noted; passed where applicable) |
| renderer/thread | Thread startup forced the initially-false cursor blink flag to visible, and `sync_draw_timer()` immediately discarded an already-armed callback when animation became inactive. | Keep Ghostty's initial blink value and track desired draw activity separately from the armed completion so its final pending callback still fires. |
| renderer/module surface | Witty carried an unused `renderer.Color` type with no Ghostty source counterpart and renamed the source's empty `WebGL` declaration to an invented `WebGLAPI` dummy struct. | Remove the orphan color file and restore the exact empty `WebGL` type. |
| sprite/face | `render_glyph` hardcoded glyph `offset_x/offset_y` to 0. | Compute from canvas clip + padding (matches `Face.renderGlyph`). |
| termio/termio | `resize` sent renderer `.font_grid` (should `.resize`); cursor reset sent `.focus` (should `.reset_cursor_blink`). | Correct message kinds (+ wired the two MessageKind variants). |
| simd/stream | SIMD search/decode offsets and terminal bulk-stream lengths were narrowed to `u32`, creating artificial overflow boundaries that do not exist in Ghostty's `usize` contracts. | Restore `usize` through `simd.index_of`, VT/base64 decode results, and terminal stream consumption. |

## Focused behavior reviewed

The following areas have received focused source comparisons and regression
tests. This list does not certify their entire modules or their representation
and ABI boundaries as one-for-one translations.

terminal: color, csi, ansi, dcs, charsets, device_status, tabstops,
size, point, mouse_shape, sgr, selection, bitmap_allocator, ScreenSet,
RefCountedSet, hash_map, style, x11_color, formatter, stream parser boundaries
and readonly handler.
font: backend, Atlas, Metrics, codepoint_map,
embedded, shared_grid, codepoint_resolver (pure logic), collection,
discovery, face (Constraint math), shaper/feature/cache/noop/run,
nerd_font_attributes (276/276 constraint entries verified). osc: parser state
transitions and buffer boundaries, encoding, semantic_prompt, iterm2,
hyperlink, clipboard, change_window_*, report_pwd, rxvt, mouse_shape,
kitty_text_sizing. input: kitty (80/80),
keycodes (243/243), command, binding (83-tag order), key (logic), Link.
kitty: graphics_command, graphics_unicode, graphics execution/storage. renderer:
cell, cursor, size, row, Atlas, shader cell layouts. datastruct: CircBuf,
ArrayListCollection. ssh: cache Entry/DiskCache. tmux: control, layout, output.
termio: exec, shell_integration, stream_handler. simd: index_of, base64, vt.
root: quirks, build_config,
opentype (all 6 tables), cli_args, split_tree, command (POSIX). apprt: structs,
none, browser, action, ipc.

## Remaining known divergences (NOT yet fixed)

These are confirmed structural boundaries or larger refactors. The absence of
an item here does not mean its full module has been certified yet.

- **Architectural:** `Screen`/`Terminal` use the flat `Pages` model, not the
  faithful `PageList` linked-list (which is exercised only by its own tests +
  the PageList formatter). Both exist; they are parallel.
- **OSC representation:** Ghostty's tagged `Command` union, sentinel slices,
  allocator/writer objects, and nested parser types are represented by a flat
  V command struct and GC-backed arrays. Observable parser boundaries are now
  enforced, but this is not a one-for-one representation or ABI translation.
- **Stream dispatch representation:** Ghostty specializes `Stream(Handler)` and
  invokes typed, comptime-tagged callbacks synchronously as parsing progresses.
  Witty's shared parser stores flat `StreamEvent`/`ActionPayload` values for a
  later handler pass. The reviewed action values and read-only effects are
  close, but callback/error timing, allocation, and representation differ.
- **Generated feature wiring:** Ghostty's build synthesizes
  `kitty_graphics`/`tmux_control_mode` from the Oniguruma build option. Witty
  has a build-options carrier but does not yet generate or apply equivalent
  feature gating; APC handling is consequently unconditional and structurally
  embedded in `termio/stream_handler.v` rather than the source tagged state.
- **Allocator and memory representation:** `Page`, typed `Offset(T)` slices,
  allocator failure paths, and generic `RefCountedSet` storage are adapted to
  V GC arrays/specializations. Their reviewed observable behavior is close,
  but they are not literal layout, ownership, or failure-mode translations.
- **Render-state integration:** the production render path adapts the flat
  `Pages` screen rather than traversing Ghostty's active `PageList`; therefore
  PageList cross-node behavior is not exercised through the live renderer.
- **Overlay rasterizer:** Ghostty delegates paths, fill/stroke, clipping, and
  compositing to z2d. Witty has a handwritten RGBA rectangle rasterizer. The
  reviewed feature grouping, colors, premultiplication, and overflow boundaries
  are close, but this remains source-external rendering logic.
- **Shadertoy toolchain:** Witty invokes external `glslangValidator` and
  `spirv-cross` executables through temporary files, whereas Ghostty links the
  shader compiler/cross-compiler libraries. This has different availability,
  process, filesystem, and error contracts.
- **Valgrind runtime detection:** `renderer.Thread.cursorBlinkInterval` always
  returns 600 ms in Witty. Ghostty detects Valgrind at runtime and returns
  3,000 ms there; the available V toolchain exposes only a compile-time custom
  define, not an equivalent runtime primitive.
- **Source placement:** V module-cycle constraints keep the translated shaper
  run algorithm in `font/font.v` while `font/shaper/run.v` exposes aliases.
  This is behaviorally implemented but not a file-for-file layout match.
- **Runtime bridge representation:** Ghostty selects the concrete apprt types at
  compile time. Witty's merged V module boundary instead introduces
  `RuntimeApp`/`RuntimeSurface` aliases and a process-global table of opaque core
  callbacks. This bridge is source-external architecture, even where each
  callback delegates to the translated core implementation.
- **Native/platform coverage:** The complete FreeType/CoreText/web-canvas,
  discovery, Metal/OpenGL, shadertoy, regex,
  embedded-resource, locking, configuration, and platform application surfaces
  have not all been certified function-by-function against the pinned tree.
- **Comment style:** many large files use a verbatim "Original Ghostty Comments"
  header-dump block plus paraphrased inline comments, rather than each comment
  attached in place.

## Status

The focused tests and compile gates named in each audit session are expected to
pass at the recorded commit. A repository-wide build is not proof that every
Ghostty file and function has been translated, and no 100% claim is made.
