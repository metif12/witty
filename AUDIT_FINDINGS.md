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
| input/command | The 88 translated command-palette entries were already present, but defaults traversed a manually duplicated 83-tag list and `action_commands` used a catch-all, losing Ghostty's compile-time requirement to classify every new action. `Command.clone` also shared all owned strings because the translated `Action.clone` was absent. | Enumerate `ActionTag` through V type reflection, make the command switch exhaustive, assert every generated command's tag, and restore deep cloning for string and cursor-key action payloads plus command text. |
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
| apprt/GTK new-surface context | The GTK runtime declared a second `NewSurfaceContext` enum and threaded it through its window, tab, and surface classes even though Ghostty uses the shared `apprt.surface.NewSurfaceContext` contract directly. | Remove the GTK-local enum and use `apprt.NewSurfaceContext` throughout the runtime boundary. |
| apprt/embedded text | The internal embedded text result narrowed Ghostty's `usize`/`uintptr_t` text length to V's 32-bit `int` before the public C projection. | Preserve `usize` from the dumped text through the embedded result and assert pointer-width storage with a value above `int` range. |
| apprt/embedded platform | Surface initialization replaced explicit zero/negative scale factors with `1`, accepted platform tags outside the source enum, and constructed Darwin-only platforms on other targets. | Preserve Ghostty's direct `f64` to `f32` scale conversion, reject unknown tags, and return `UnsupportedPlatform` outside Darwin. |
| apprt/embedded key event | The raw `unshifted_codepoint` conversion treated Ghostty's `u21` as a Unicode scalar and rejected values above `0x10FFFF`, although the source cast accepts every 21-bit value through `0x1FFFFF`. | Restore the actual `u21` numeric boundary and clamp only values that do not fit in 21 bits. |
| apprt/embedded initial input | A present-but-empty surface `initial_input` was ignored, leaving configured startup input in place; Ghostty clears it and installs one empty raw input entry. | Branch on optional presence rather than string length, preserving empty-string override semantics. |
| core/surface scroll | The translated core callback narrowed Ghostty's `input.ScrollMods` parameter to a `precision` boolean, and both embedded and GTK adapters discarded the momentum field before dispatch. | Restore the full scroll-modifier contract at the core surface boundary and propagate it unchanged from embedded callers. |
| core/surface pressure | Mouse state duplicated the source input enums (`normal` was renamed `light`), compact pressure/momentum enums were widened to V's default integer, the bridge translated pressure values, and a deep press selected the word at the current cursor rather than Ghostty's retained original click pin. | Use byte-backed input pressure/momentum enums and the input button-state type directly, remove the bridge mapping, and select from the stored click pin. |
| core/surface size | The translated core callback split Ghostty's `apprt.SurfaceSize` parameter into independent width and height integers, forcing every runtime adapter to reconstruct a source-external call shape. | Restore the shared surface-size value through the core, embedded, and GTK callback path. |
| core/surface geometry | Core-local content-scale and cursor-position structs duplicated Ghostty's shared `apprt` contracts; the cursor duplicate also widened both source `f32` fields to `f64`, with adapter-side copying in both directions. | Use `apprt.ContentScale`, `apprt.SurfaceSize`, and `apprt.CursorPos` directly for runtime queries and callbacks; widen coordinates only where the source calculation accepts `f64`. |
| core/surface renderer size | `Surface` carried a second handwritten implementation of renderer screen/cell/grid/padding/aggregate sizes, including zero-cell grids and different balanced-padding math, then copied it into the translated renderer and termio types. | Store and forward `renderer.Size` directly, restoring its source `u16` minimum-one grid and balanced-padding behavior and removing the duplicate converter. |
| core/surface shared values | The core surface redefined `apprt.IMEPos` and copied it at the bridge, and exposed a redundant local `ColorScheme` alias instead of the source callback/query types. | Return `apprt.IMEPos` directly and accept `apprt.ColorScheme` directly, removing the extra projection layer. |
| core/surface derived config types | `DerivedConfig` redeclared six configuration enums and both input link enums, populated them with unsafe integer casts, and omitted the valid `link-previews=osc8` case from its duplicate type. | Retain the canonical `configpkg` and `input.Link` types directly, removing eight duplicate enums and every projection cast. |
| core/surface binding flags | The core surface copied `input.Binding.Flags` into a differently ordered duplicate struct; the embedded bridge duplicated it again and manually rebuilt the C bitmask. | Return and retain `input.Flags` directly across the opaque bridge and use its translated `cval()` projection at the C boundary. |
| core/terminal viewport scroll | Normalized mouse-scroll deltas used fixed `i64`/`u64`, then narrowed to V's 32-bit `int` through core, termio, and terminal; jump-to-prompt messages were narrowed the same way. | Restore source `isize`/`usize` storage across the complete message/API path and clamp only where the flat screen representation reaches its bounded array indexes. |
| core/surface coordinates | `pos_to_viewport` independently reimplemented padding removal, cell division, and clamping rather than using Ghostty's renderer coordinate conversion path. | Delegate directly to the translated `renderer.SizeCoordinate.convert(.grid, size)` and only project the resulting grid pair into the terminal coordinate. |
| core/surface mouse helpers | The live surface duplicated `terminal.Coordinate.eql` and the rectangle-selection modifier predicate, while `mouse_selection` added an invalid-cell guard absent from Ghostty. | Use the terminal coordinate method and the canonical translated `surface_mouse` helpers directly, and preserve the source function's preconditions. |
| root/surface_mouse | An unused second implementation in module `main` defined private substitute key, modifier, and mouse-event types; only its parallel test suite referenced it, while the live core used `core/surface_mouse.v`. | Remove the orphan implementation and move its transition coverage onto the live core helper using canonical input and terminal types. |
| renderer/background file type | The translated file-signature detector lived unused in module `main`, while the live renderer bypassed Ghostty's format policy and decoded any image accepted by stb directly from its path. | Move the detector into an importable module; make the renderer read bytes, use magic detection with extension fallback, reject unknown/unsupported formats, and decode only source-supported PNG/JPEG from those bytes. |
| root/math | An unused root `Mat` wrapper coexisted with a second renderer-local `ortho2d`, so production bypassed the translated `math.zig` module and the root representation did not match the shader matrix. | Replace both with one importable `mathutil` translation, represented as the shader-compatible fixed array, and call it from the live renderer. |
| root/fastmem | The root translation was disconnected and byte-only, while live translated call sites used handwritten element loops instead of Ghostty's generic memory helper. | Restore generic libc-backed move/copy/rotation functions in an importable module and use them from the live cache table, circular buffer, tabstops, and font atlas paths. |
| root/quirks | The translated helper was stranded in module `main`; both font backends omitted Ghostty's explicit `disableDefaultFontFeatures` initialization and happened to get the current result only from V's false zero value. | Move the helper into an importable, cycle-free generic module and call it from both live FreeType and CoreText face constructors. |
| root/tripwire | The failure-injection translation used untyped string points in a private instance exercised only by its own tests, so none of Ghostty's live error sites could be armed; Atlas initialization/growth had also been made infallible. | Restore a generic typed-point module with test-only checks; wire the tabstop allocation plus Atlas init/reserve/grow points into live paths, and restore the Atlas result contracts. |
| font/Atlas format | The three-value atlas format enum and its `depth()` result were widened from Ghostty's `u8` contracts to V's default 32-bit integer. | Restore byte-backed values `0..2` and a byte-sized depth result, retaining explicit widening only at consumers that require it. |
| font/Atlas counters | The atlas modification and resize counters were ordinary fixed-width `u64` fields even though the font producer and renderer consumer run on different threads; Ghostty uses atomic `usize` values and monotonic operations. Renderer frame snapshots were also fixed-width `u64`. | Store both counters as atomic `usize`, use V's atomic increments/loads at every live access, and retain `usize` in Metal and OpenGL frame snapshots. |
| compact internal enum contracts | Explicitly sub-byte Ghostty enums for font style/presentation, synthetic UTF-8 length, screen selection, mouse mode/format, packed cell metadata, underline style, and Kitty key events were translated as default-width 32-bit V enums. | Use byte-backed V enums (the narrowest supported representation) with every source raw value explicit. |
| renderer cell shader layout | Ghostty stores its exact 32-byte shader `CellText` in the renderer cell collection. Witty widened its atlas selector, stored the two shader bits as separate booleans in a reordered logical struct, then allocated and rebuilt every cell through two handwritten backend projection types each frame. | Restore the source field order, byte-backed atlas values, and packed flag byte in `CellText`; use that one verified 32-byte layout for both Metal and OpenGL and remove both backend conversion types/functions. |
| renderer cell-background shader type | Ghostty's background-cell shader value is exactly `[4]u8`; Witty introduced a named four-field RGBA struct with the same incidental layout. | Use the source array representation directly throughout cell storage, construction, and GPU buffer uploads. |
| renderer background-image shader layout | Both source backends store the same compact `BgImage` shader value with a four-bit position, two-bit fit, and repeat bit. Witty stored those as default-width enums plus a boolean and duplicated an identical projection type/function in each backend. | Store the packed source byte directly beside opacity, verify the resulting eight-byte shader layout, upload it unchanged, and remove both backend projections. |
| renderer image shader layout | The Metal and OpenGL translations declared separate, structurally identical image-vertex types even though the selected source shader package exposes one `Image` type to generic rendering code. | Use one verified 40-byte image shader value for buffer creation, pipeline stride, and both backend attribute declarations. |
| renderer OpenGL uniform flags | Ghostty packs the four OpenGL shader booleans into bits 0–3 of one `u32`; Witty projected them as four independent bytes. GLSL reads the field as one `uint`, so all flags except bit-zero `cursor_wide` were encoded at the wrong bit positions. | Give the OpenGL projection its source `u32` `padding_extend`/`bools` fields and explicitly pack the four source bits, while retaining Metal's intentionally different byte layout. |
| terminal CSI erase modes | `terminal.v` duplicated both byte-backed CSI erase enums as unrelated default-width enums with declaration-order values, making `Terminal.erase_line`/`erase_display` consume a different type and giving `scroll_complete` the wrong raw value. | Use the canonical `csi.v` `u8` enums directly at the terminal API boundary, retain their exact source values, and remove both duplicate definitions. |
| root/Command | The translated process launcher was stranded in module `main` and exercised only by parallel tests, while the live termio backend independently rebuilt argv/envp and repeated cgroup clone, fork, descriptor, cwd, rlimit, pre-exec, and exec logic. Its empty environment incorrectly meant inheritance; fd setup omitted Ghostty's platform contract; child errors exited inside `Command`; and stopped children were misclassified as signal 127. | Move `Command` into an importable module and delegate the live PTY launch to it; preserve optional environment/PID and `ExecFailedInChild` contracts; restore target-specific fd setup and correct wait-status classification. |
| global logging defaults | Stderr logging was hardcoded on even for Ghostty's `.none` application runtime, and unified logging recognized macOS alone instead of all Darwin targets. | Select the stderr default from the same target rule as `apprt.Runtime.default()` and enable unified logging on macOS and iOS. |
| CLI action help | Although the general help text told users to run `+<action> --help`, every translated action parser rejected `--help`/`-h`; `show-face` and `new-window` also swallowed parser errors that Ghostty explicitly propagates to its central action dispatcher. | Embed all 15 byte-for-byte generated action documentation entries, restore `ActionHelpRequested` propagation at each parser and at the two catching runners, and handle it centrally while retaining `new-window -e ... --help` as command input. |
| CLI action options | Simple actions independently hand-parsed flags, accepting source-invalid separated values (`--style Italic`, `--config-file path`), rejecting source-valid explicit booleans such as `--docs=false`, and rejecting repeated option assignments instead of applying them in order. The shared parser also could not address source identifiers translated with V's keyword suffix. | Route list-actions/colors/keybinds/fonts/themes, validate/edit/show-config, SSH-cache, crash-report, and boo option structs through the translated generic parser; retain argument-order help checks and map V's trailing keyword underscore back to the source CLI name. |
| CLI new-window parsing | The action manually recognized only `--class`, returned ad-hoc errors instead of source diagnostics, removed the action token before parsing (shifting CLI locations), and kept its command-tail state as a parser-visible field. | Route the action through the shared parser and translated `-e` hook, mark translated underscore fields as internal, filter diagnostics to the action-owned `class` field, and retain skipped action tokens in argv so diagnostic indexes match Ghostty. |
| CLI show-face config diagnostics | Config diagnostics were interpolated as V structs, exposing representation text instead of Ghostty's user-facing diagnostic format. | Render every retained config diagnostic through the translated `Diagnostic.format()` contract. |
| CLI version metadata | The version action was embedded in the C dispatcher, printed the compiler executable path as the V version, reported the artifact (`exe`) as the application runtime, and omitted the selected font and renderer backends. | Restore a dedicated CLI version module and report the actual V compiler version plus the translated runtime, font, renderer, build-mode, release-channel, and platform metadata. |
| CLI help action | General help was embedded inside the C API dispatcher and printed without parsing any action arguments, so `+help --unknown` silently succeeded unlike Ghostty's special one-field Options parser. | Move the action into `cli/help.v`, parse its ordinary `--help` field without the other actions' help-error hook, and retain the source-generated enum listing. |
| Input action help | The live `+list-actions --docs` implementation opened and reparsed `input/binding.v` from the developer checkout at runtime, used the shortened comments attached to V's flat tags, and omitted the generator's leading/inter-entry blank lines. | Embed all 83 full documentation entries generated from the pinned `Binding.zig` union, consume them in translated tag order without filesystem access, and restore the source buffering/spacing algorithm. |
| root/helpgen | The translated helper reparsed V source files at runtime, returned shortened tag comments rather than Ghostty's generated CLI/keybind documentation, and even treated Witty's extra `.none` sentinel as a documented CLI action. | Expose the embedded generated records for all three help groups, filter source-private Config fields, preserve documentation whitespace, and eliminate runtime checkout access. |
| embedded C text | Successful text projections allocated only the payload bytes and returned a null pointer for empty text, violating Ghostty's sentinel-terminated result type. | Always allocate the trailing byte, preserve embedded NUL bytes via the separate length, and return a non-null sentinel for an empty successful result. |
| osc/color_parser | Hex channel scaling used `>>4`/`>>8` instead of `*255/4095` and `*255/65535`; float intensity rounded not truncated; named `green` = (0,128,0). | Correct scaling; truncate; `green` = (0,255,0). |
| osc/osc9 | OSC 9;12 emitted default `.fresh_line` instead of `.fresh_line_new_prompt`. | Set correct action. |
| OSC semantic-prompt redraw state | Terminal flags and screen resize options stored a duplicate default-width `PromptRedraw` enum, forcing a conversion from Ghostty's canonical compact `osc.semantic_prompt.Redraw` value. | Give `osc.Redraw` its source values in byte storage, use it directly across terminal state and resize, and remove the duplicate enum/conversion. |
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
| font/renderer backends | Both translated backend enums used V's default 32-bit backing and renamed Ghostty's target-selecting `default` declaration to the source-external `default_backend`. | Restore compact byte storage and the translated `Backend.default_()` declaration for both font and renderer backends, with target-selection and feature-query coverage. |
| renderer/Metal API contracts | Metal's native constants were represented as sequential V enums plus handwritten conversion switches; the GPU-family bridge used `3003` for Apple3 and omitted Ghostty's Apple10 32,768-pixel limit. The shared renderer health enum also relied on implicit layout and values. | Give the exposed Metal and health enums their source ABI widths and numeric values, pass native values directly instead of remapping them, and restore the Apple10/Apple3 maximum-texture-size checks with the source constants. |
| sprite/face | `render_glyph` hardcoded glyph `offset_x/offset_y` to 0. | Compute from canvas clip + padding (matches `Face.renderGlyph`). |
| termio/termio | `resize` sent renderer `.font_grid` (should `.resize`); cursor reset sent `.focus` (should `.reset_cursor_blink`). | Correct message kinds (+ wired the two MessageKind variants). |
| termio derived config enums | The IO layer redeclared both `configpkg.ClipboardAccess` and `Config.OSCColorReportFormat`, converted into them case-by-case, and carried those parallel types through `StreamHandler`. | Store both canonical config values directly in derived IO state and the stream handler, removing the duplicate enums and conversions. |
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
- **Help generation pipeline:** Witty embeds pinned generated Config, CLI-
  action, and keybind-action records and exposes the correct data through its
  translated helper, but its build does not yet regenerate those artifacts by
  parsing the translated declarations as Ghostty's Zig build step does.
- **CLI TTY presentation:** `list-colors` and `list-keybinds` retain only their
  plain serialization in Witty. Ghostty selects large vaxis-based pretty
  renderers when stdout is a TTY and `--plain` is not set.
- **Diagnostic action parsing:** `show-face` preserves ordinary config
  arguments with a manual V parser rather than Ghostty's shared parser plus
  diagnostic filtering. Its main values and help boundary are covered, but
  action-owned parse diagnostic formatting/timing is not yet identical.
- **Version action metadata:** Witty now reports its real compiler version,
  application runtime, font engine, renderer, and GTK build/runtime features,
  but it does not link libxev and therefore reports that field as unavailable.
  Its build also does not yet generate commit metadata for the source TTY
  hyperlink.
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
