# Translation Audit: Top 100 Ghostty Zig Files by LOC

> Historical prioritization snapshot, not a completion certificate. Several
> rows and percentages predate later source audits and fixes. Labels such as
> “faithful” describe behavior sampled at the time; they do not establish
> file-by-file, function-by-function, representation, or ABI equivalence. See
> `AUDIT_FINDINGS.md` for current blockers to any 100% claim.

Generated from `/Users/alexander/code/3rd/ghostty/src` and `/Users/alexander/code/3rd/ghostty/pkg` (`.zig` files only). Target: `/Users/alexander/code/witty`.

The requirement is strict: **translated logic AND comments should match the original.** This pass is a genuine side-by-side review — each original file was read against its V candidate (not scored by identifier/heuristic overlap). Every row's numbers are backed by reading the actual code.

## Method

- Ranked original Ghostty `.zig` files by physical LOC; took the top 100.
- Mapped each original to its V translation using the module moves witty actually uses (snake_case paths, some merges — e.g. `Atlas.zig`+`Metrics.zig` → `font/font.v`, `box.zig` → `sprite/block.v`+`sprite/sprite.v`).
- For each pair, read the original and the V candidate, then judged:
  - **Logic fidelity** — fraction of the original's *non-test* types/functions/control-flow/behavior faithfully present in V.
  - **Comment fidelity** — fraction of original comment text present in V (see the caveat below about *where* it lives).
  - **TODO/stub markers** in V (`TODO`/`XTODO`/`stub`/"not implemented"/placeholder panics).
- Verdict bands: **faithful** (logic ≥85% & comments ≥85%), **partial-high** (65–84%), **partial** (45–64%), **low/stub** (<45%), **missing** (no V target).

> **Comment-placement caveat.** Most large V files preserve comment *text* by pasting the entire original comment stream — including all test-body comments — into one detached `--- Original Ghostty Comments Start/End ---` header block, rather than attaching each comment to the code it documents. Under a literal "comments must be the same" reading the text is present; under a "comments must be the same *and in place*" reading, many high comment scores are inflated by this device. Rows note when this applies.

## Summary

- Top-100 files audited: **100**
- **faithful: 20** · **partial-high: 24** · **partial: 18** · **low/stub: 15** · **missing: 23**
- Comment fidelity poor/absent (<70% or missing): **32**
- None of Ghostty's ~30k LOC of inline `test` blocks are translated in-place (a few modules moved tests to separate `*_test.v` files: binding, formatter, tmux, command).

### Headline findings

1. **The prior audit was badly stale.** V files have roughly doubled since it was written (`configpkg.v` 590 → 4528, `page_list.v` 2233 → 4586, `screen.v` 1579 → 3302). Size grew; fidelity did not grow proportionally.
2. **Fidelity tracks file *type*, not size.** Pure algorithm / lookup-table / parser files with no dependence on Zig's memory model or comptime reflection are translated near 1:1 and are genuinely faithful (`nerd_font_attributes`, `key_encode`, `keycodes`, `sgr`, `color`, `bitmap_allocator`, `selection`, `split_tree`, `tmux/control`+`layout`, OSC parsers, `graphics_command`, `os2`, `branch`, `symbols_for_legacy_computing`, `shell_integration`, `sliding_window`).
3. **The four giants are skeletons.** `PageList`/`Terminal`/`Screen`/`Config` (≈47k LOC, ~20% of all Ghostty LOC) are only 8–55% translated. Their hardest subsystems — reflow, wide-char/grapheme handling, style/hyperlink refcount migration, resize-with-reflow, and the entire Config option/parser surface — are stubbed with `XTODO`.
4. **Files that exist *because of* Zig's design are rewritten or stubbed.** The single-mmap offset-buffer page memory and comptime generics drive `hash_map`, `ref_counted_set`, `render`, `page`'s byte layout, and `Atlas`'s bin-packing; V replaces these with GC + plain arrays, so their raison-d'être logic is simplified or absent.
5. **The rendering & font-rasterization pipeline is currently non-functional.** GPU renderer (`generic`/Metal/OpenGL draw paths), FreeType/CoreText faces, `Atlas` packing, `Metrics.calc`, font discovery, and the sprite `Canvas` primitives are stubs awaiting real C bindings — so glyphs cannot actually be rasterized/placed yet.
6. **An entire platform layer is absent.** The GTK/Linux apprt (13 files), inspector/imgui widgets (5 files), tmux `viewer`, build system (`SharedDeps`, `Config`), crash `sentry_envelope`, `os/flatpak`, `ssh-cache/DiskCache`, `termio/Thread`, and `config/path` have no V translation. witty is macOS-focused, so GTK omission is expected, but it is 23% of the top-100 by file count.

## Manual Spot Checks (high-value)

- **`terminal/page_list.v`** — core (init/grow/pins/scroll/erase/iterators/clone) is faithful, but the **entire reflow engine is missing** and `resize_cols` is a stub that truncates/pads, silently corrupting wrapped content on column resize.
- **`terminal/terminal.v`** — simple paths faithful; `print` hardcodes width=1 and stubs grapheme/VS15-16/zero-width; insert/delete-lines and erase paths drop wide/spacer-boundary handling; `switchScreenMode` omits cursor copy for 47/1047/1049 (behaviorally wrong).
- **`configpkg/configpkg.v`** — only ~55 of ~189 config option fields exist; `load_file`/`finalize`/`parseCLI`/validation are empty stubs; doc-comments present but detached in a header dump.
- **`terminal/screen.v`** — pervasively stubbed (`clone`, `cursorCopy`, hyperlink/style refcount, `resize` reflow, `splitCellBoundary` no-op); several Zig functions absent entirely.
- **`surface.v`** — full callback surface present but bodies simplified; `perform_binding_action` implements ~24 of ~60+ arms; `mouse_report` writes stubs instead of encoding X10/SGR/urxvt bytes.
- **renderer (`renderer.v`, `image.v`, `cells.v`)** — data models faithful; `updateFrame`/`rebuildCells`/`drawFrame`/kitty image upload collapsed to placeholders; all cell-classification free functions absent.
- **font faces (`face.v`+`freetype.v`, `face_coretext.v`, `face_web_canvas.v`)** — bindings are explicit stub modules; `render_glyph`/`get_metrics` return empty; algorithms survive only as comments.
- **sprite `Canvas` (`sprite/sprite.v`)** — `draw_box`/`pixel`/`line`/`fill_path`/`write_atlas` are no-op `XTODO`s, so glyph files that *are* faithful (`branch`, `symbols_for_legacy_computing`) can't actually render.

## Top 100 Table

| # | Original | LOC | V candidate | V LOC | Logic | Comments | TODO | Verdict | Notes |
|---:|---|---:|---|---:|---:|---:|---:|---|---|
| 1 | `src/terminal/PageList.zig` | 14466 | `terminal/page_list.v` | 4586 | 55% | 80% | 4 | partial | Core/pins/scroll/iterators faithful; **entire reflow engine missing**, `resize_cols` stub corrupts wrapped content; comments dumped verbatim in header block |
| 2 | `src/terminal/Terminal.zig` | 12431 | `terminal/terminal.v` | 3816 | 55% | 90% | 21 | partial | `print` width=1 hardcode, grapheme/wide-char stubbed; insert/delete/erase drop spacer handling; screen-mode cursor copy missing |
| 3 | `src/config/Config.zig` | 10411 | `configpkg/configpkg.v` | 4528 | 8% | 60% | 5 | low/stub | ~55/189 option fields; no parser/finalize/validation; doc-comments present but detached |
| 4 | `src/terminal/Screen.zig` | 10352 | `terminal/screen.v` | 3302 | 30% | 55% | 15 | low/stub | clone/cursorCopy/hyperlink+style refcount/resize-reflow stubbed; several fns absent; ~1720 LOC is detached comment archive |
| 5 | `src/Surface.zig` | 6781 | `surface.v` | 4268 | 40% | 90% | 13 | partial | Full callback surface; ~24/60+ binding arms; mouse_report + search + clipboard stubbed; comments in header dump |
| 6 | `src/terminal/formatter.zig` | 5939 | `terminal/formatter.v` | 1836 | 80% | 90% | 8 | partial-high | Core format loop faithful; PinMap/PointMap omitted; `cell_style` lookup stubbed → styled output not reconstructed |
| 7 | `src/input/Binding.zig` | 4816 | `input/binding.v` | 3041 | 78% | 88% | 1 | partial-high | Parse/Trigger/Action/Set faithful; **chaining (`chain=`) unimplemented**; config-serialization (`format`/`cval`) dropped |
| 8 | `src/apprt/gtk/class/surface.zig` | 4025 | - | 0 | 0% | 0% | - | missing | GTK apprt not translated |
| 9 | `src/terminal/page.zig` | 3861 | `terminal/page.v` | 2336 | 78% | 96% | 0 | partial-high | Offset-free logic faithful; Zig's mmap/packed-struct byte layout intentionally replaced by V arrays + GC |
| 10 | `src/terminal/stream.zig` | 3389 | `terminal/stream.v` | 1920 | 82% | 93% | 10 | partial-high | Full CSI/ESC/OSC dispatch branch-for-branch; SIMD fast-path omitted (scalar loop); 9 TODOs are copied "TODO: test" notes |
| 11 | `src/renderer/generic.zig` | 3335 | `renderer/renderer.v` | 1956 | 35% | 90% | 12 | partial | Uniform helpers faithful; `updateFrame`/`rebuildCells`/`drawFrame`/swapchain collapsed to placeholders — core render path not translated |
| 12 | `src/apprt/gtk/class/application.zig` | 2836 | - | 0 | 0% | 0% | - | missing | GTK apprt not translated |
| 13 | `src/font/nerd_font_attributes.zig` | 2774 | `font/nerd_font_attributes.v` | 2737 | 100% | 98% | 0 | faithful | Lookup table 1:1 (276 constraint arms, 413 codepoint checks match) |
| 14 | `src/font/shaper/coretext.zig` | 2678 | `font/shaper/coretext.v` | 623 | 55% | 95% | 12 | partial | Non-test fns present but `shape()` CTRun loop is commented-out; no real CoreText bindings |
| 15 | `src/input/key_encode.zig` | 2399 | `input/key_encode.v` | 946 | 97% | 95% | 0 | faithful | All kitty/legacy encode paths ported faithfully; minor: `binding_hash` uses polynomial not Wyhash |
| 16 | `src/terminal/tmux/viewer.zig` | 2292 | - | 0 | 0% | 0% | - | missing | tmux viewer not translated |
| 17 | `src/datastruct/split_tree.zig` | 2273 | `datastruct/split_tree.v` | 1140 | 96% | 92% | 0 | faithful | All non-test decls incl. backtracking search + ASCII-diagram renderer match; GTK glue omitted |
| 18 | `src/apprt/embedded.zig` | 2207 | `apprt/embedded.v` | 1734 | 74% | 90% | 0 | partial-high | All 69 C-ABI exports 1:1; inspector is cimgui stub, split actions route to placeholder, workdir validation dropped |
| 19 | `src/font/shaper/harfbuzz.zig` | 2163 | `font/shaper/harfbuzz.v` | 358 | 82% | 95% | 6 | partial-high | `shape()` cluster/ligature loop + 26.6 rounding faithful; grid-lock/face resolution stubbed |
| 20 | `src/apprt/gtk/class/window.zig` | 2024 | - | 0 | 0% | 0% | - | missing | GTK apprt not translated |
| 21 | `src/cli/list_themes.zig` | 1741 | `cli/list_themes.v` | 633 | 45% | 60% | 9 | partial | CLI/iteration/luminance faithful; entire ~1100-line vaxis TUI (draw/preview/modals) stubbed |
| 22 | `src/termio/Exec.zig` | 1739 | `termio/exec.v` | 916 | 70% | 80% | 0 | partial-high | Subprocess/env setup faithful & richly commented; read thread doesn't forward to Termio; no process-exit watcher/termios timer |
| 23 | `src/terminal/search/sliding_window.zig` | 1676 | `search/sliding_window.v` | 657 | 90% | 88% | 0 | faithful | Full non-test search engine (next/highlight/prune/append) matches; inline page-encode vs PageFormatter |
| 24 | `src/cli/args.zig` | 1627 | `cli_args/cli_args.v` | 500 | 42% | 88% | 19 | partial | parse/iterators for string/bool/number happy path only; comptime-reflection machinery (tagged-union/struct/diags) all stubbed |
| 25 | `src/terminal/Selection.zig` | 1598 | `terminal/selection.v` | 414 | 90% | 95% | 0 | faithful | order/topLeft/contains/adjust faithful; tracked/untracked Bounds union dropped (plain pins) |
| 26 | `src/termio/stream_handler.zig` | 1551 | `termio/stream_handler.v` | 1495 | 80% | 90% | 1 | partial-high | Full vt dispatch + set_mode faithful; `colorOperation`+`kittyColorReport`+tmux viewer + apc kitty-graphics stubbed |
| 27 | `src/terminal/hash_map.zig` | 1540 | `terminal/hash_map.v` | 733 | 60% | 80% | 5 | partial | Open-addressing/probing/fingerprint faithful; the whole offset-buffer point of the fork is stubbed; hash differs (splitmix64) |
| 28 | `src/font/Collection.zig` | 1523 | `font/collection.v` | 1204 | 80% | 90% | 3 | partial-high | add/get_face/get_index/metrics faithful; `complete_styles` synthetic-style logic garbled/aliased |
| 29 | `src/terminal/search/screen.zig` | 1516 | `search/screen_search.v` | 767 | 45% | 95% | 9 | partial | Scaffolding + select_next/prev faithful; `reload_active` engine + feed/history stubbed |
| 30 | `src/terminal/render.zig` | 1464 | `terminal/render.v` | 458 | 30% | 70% | 13 | low/stub | Structs faithful; every behavioral method stubbed (`update` 600→100 lines "copy active rows") |
| 31 | `src/font/face/freetype.zig` | 1436 | `font/face.v` + `freetype/freetype.v` | 1210 + 517 | 40% | 88% | 52 | low/stub | `freetype.v` is an explicit stub module; init/render_glyph/get_metrics return empty; nothing loads |
| 32 | `src/font/sprite/draw/symbols_for_legacy_computing.zig` | 1413 | `sprite/symbols_for_legacy_computing.v` | 1076 | 96% | 90% | 2 | faithful | Every draw fn + 44-entry mosaic table + sextant formula match 1:1; 2 TODOs are original Zig TODOs |
| 33 | `src/terminal/kitty/graphics_storage.zig` | 1359 | `kitty/graphics_storage.v` | 862 | 80% | 88% | 2 | partial-high | add/delete/evict/rect faithful; `Placement.deinit` pin-untrack is a no-op stub; `rect` drops page-overflow |
| 34 | `src/terminal/kitty/graphics_unicode.zig` | 1347 | `kitty/graphics_unicode.v` | 833 | 82% | 90% | 1 | partial-high | renderPlacement float math + 297-entry diacritics table faithful; iterator on simplified cell model, styles stubbed |
| 35 | `src/terminal/kitty/graphics_command.zig` | 1325 | `kitty/graphics_command.v` | 1088 | 93% | 92% | 0 | faithful | Full APC parser + all sub-parsers (Transmission/Display/Animation/Delete) match; no stubs |
| 36 | `src/apprt/gtk/class/split_tree.zig` | 1241 | - | 0 | 0% | 0% | - | missing | GTK widget (distinct from `datastruct/split_tree`) not translated |
| 37 | `src/font/face/coretext.zig` | 1162 | `font/face_coretext.v` | 650 | 20% | 80% | 23 | low/stub | Nearly every method stubbed; algorithms survive only as pseudocode comments; no CoreText bindings |
| 38 | `src/terminal/osc/parsers/osc9.zig` | 1140 | `osc/osc9.v` | 329 | 90% | 90% | 0 | faithful | All ConEmu subcases + iTerm2 notification fallback with matching control flow |
| 39 | `src/terminal/style.zig` | 1072 | `terminal/style.v` | 394 | 65% | 85% | 2 | partial-high | bg/underline/eql faithful; `fg` bold-color branch left as XTODO (behavioral gap); `Set` stubbed; hash differs |
| 40 | `src/terminal/Parser.zig` | 1072 | `terminal/parser.v` | 873 | 70% | 75% | 1 | partial-high | State machine reimplemented as explicit handlers; **no C1 8-bit control handling**; colon-sep validation dropped |
| 41 | `src/terminal/sgr.zig` | 1070 | `terminal/sgr.v` | 402 | 92% | 90% | 0 | faithful | Near 1:1; every SGR code path + colon gating + direct-color match; `.unknown` drops slice tracking |
| 42 | `src/font/discovery.zig` | 1049 | `font/discovery.v` | 630 | 35% | 78% | 10 | low/stub | Descriptor/Score translated; both discovery backends hollow (stub bindings, empty results) |
| 43 | `src/terminal/bitmap_allocator.zig` | 1021 | `terminal/bitmap_allocator.v` | 319 | 90% | 95% | 0 | faithful | Line-by-line port (findFreeChunks large + small paths, release, layout); V arrays vs offset model |
| 44 | `src/termio/shell_integration.zig` | 1006 | `termio/shell_integration.v` | 346 | 90% | 95% | 0 | faithful | Every shell setup (bash/zsh/fish/nushell/xdg) faithful; comptime feature-sort hardcoded to same order |
| 45 | `src/terminal/stream_readonly.zig` | 990 | `terminal/stream_readonly.v` | 553 | 72% | 95% | 3 | partial-high | vt dispatch + setMode ~1:1; `semantic_prompt`/`color_operation`/`kitty_color_report` are XTODO no-ops |
| 46 | `src/terminal/osc/parsers/semantic_prompt.zig` | 964 | `osc/semantic_prompt.v` | 372 | 92% | 95% | 0 | faithful | All 8 actions (A/B/I/C/D/L/N/P) + option parsing faithful; a few doc examples trimmed |
| 47 | `src/renderer/image.zig` | 958 | `renderer/image.v` | 518 | 50% | 97% | 5 | partial | Data model faithful; `upload`/`kittyUpdate` GPU paths stubbed (no upload, placements cleared) |
| 48 | `src/font/sprite/draw/box.zig` | 929 | `sprite/block.v` (+`sprite/sprite.v`) | 387 | 8% | 55% | 0 | low/stub | `block.v` actually translates `block.zig`, not `box.zig`; box-drawing (2500-257F/linesChar/arc/dash) absent |
| 49 | `src/apprt/action.zig` | 918 | `apprt/action.v` | 488 | 70% | 92% | 0 | partial-high | All 63 action-key enum members in order + payload structs faithful; C-ABI `cval`/`format` machinery dropped, union flattened |
| 50 | `src/input/key_mods.zig` | 914 | `input/key_mods.v` | 431 | 80% | 90% | 0 | partial-high | RemapSet/Mask logic faithful; parseCLI/format/clone/equal omitted; `ctrl_or_super` hardcodes macOS |
| 51 | `src/terminal/search/Thread.zig` | 905 | `search/search_thread.v` | 341 | 8% | 90% | 10 | low/stub | Pure stub: all methods empty XTODO, structs are placeholder ints; enums only real content |
| 52 | `src/build/SharedDeps.zig` | 897 | - | 0 | 0% | 0% | - | missing | Build system not translated |
| 53 | `src/font/Atlas.zig` | 889 | `font/font.v` | 883 | 15% | 55% | 3 | low/stub | Bin-packing (Node/reserve/fit/merge/set) absent; `grow` zeroes buffer, losing data; no glyph can be placed |
| 54 | `src/input/key.zig` | 879 | `input/key.v` | 1134 | 88% | 90% | 0 | faithful | Full Key enum + codepoint/keypad/modifier logic faithful; adds binding helpers; `imguiKey` dropped |
| 55 | `src/datastruct/circ_buf.zig` | 866 | `search/circ_buf.v` | 352 | 40% | 70% | 0 | partial | Purpose-built rewrite (head/count), not a port of generic CircBuf; iterator/resize/full-model absent |
| 56 | `src/inspector/widgets/pagelist.zig` | 852 | - | 0 | 0% | 0% | - | missing | Inspector (imgui) not translated |
| 57 | `src/terminal/kitty/graphics_image.zig` | 835 | `kitty/graphics_image.v` | 386 | 55% | 78% | 1 | partial | Loading/complete/validation present; PNG decode stub, shared-memory unsupported, file safety checks simplified |
| 58 | `src/font/SharedGridSet.zig` | 834 | `font/shared_grid_set.v` | 633 | 65% | 75% | 9 | partial-high | ref/deref/key/descriptors faithful; discovery in `collection()` skipped (embedded faces only); no mutex |
| 59 | `src/font/Metrics.zig` | 816 | `font/font.v` | 883 | 25% | 60% | 3 | low/stub | `calc` is XTODO stub with invented wrong formulas; `apply` is a no-op; Key/ModifierSet/clamp absent |
| 60 | `src/inspector/widgets/termio.zig` | 811 | - | 0 | 0% | 0% | - | missing | Inspector (imgui) not translated |
| 61 | `src/apprt/gtk/class/command_palette.zig` | 790 | - | 0 | 0% | 0% | - | missing | GTK apprt not translated |
| 62 | `src/terminal/osc/parsers/color.zig` | 780 | `osc/color_parser.v` | 727 | 80% | 95% | 2 | partial-high | All 4 core routines faithful (+RGB parse added); dispatcher **discards parsed requests** (`_ = requests`) so not wired to Command |
| 63 | `src/termio/Termio.zig` | 769 | `termio/termio.v` | 439 | 20% | 55% | 8 | low/stub | init/deinit/queue/thread all explicit stubs; changeConfig/resize/sizeReport/processOutput absent; comments in header dump |
| 64 | `src/input/command.zig` | 737 | `input/command.v` | 98 | 25% | 85% | 1 | low/stub | Command struct + helpers faithful; the ~600-line `actionCommands` switch entirely absent (`command_defaults` empty) |
| 65 | `src/inspector/widgets/terminal.zig` | 726 | - | 0 | 0% | 0% | - | missing | Inspector (imgui) not translated |
| 66 | `src/terminal/tmux/control.zig` | 725 | `tmux/control.v` | 462 | 95% | 92% | 0 | faithful | All 13 notifications + parser state machine + regexes faithful; log.warn dropped (documented) |
| 67 | `src/renderer/Thread.zig` | 717 | `renderer/thread.v` | 450 | 60% | 96% | 1 | partial | drainMailbox/changeConfig/drawFrame faithful; entire xev event-loop (timers/callbacks/QoS) collapsed to sync placeholder |
| 68 | `src/Command.zig` | 717 | `command.v` | 448 | 68% | 90% | 4 | partial-high | POSIX fork/exec/wait path faithful incl. WIF* macros; Windows + cgroup + envp/execvpe omitted |
| 69 | `src/terminal/ref_counted_set.zig` | 714 | `terminal/ref_counted_set.v` | 587 | 78% | 88% | 6 | partial-high | Robin Hood core (add/lookup/delete/insert) faithful; concrete type not generic; custom FNV hash (XTODO), no offset addressing |
| 70 | `src/font/face.zig` | 707 | `font/face.v` | 1210 | 45% | 85% | 22 | partial | Type surface (DesiredSize/Variation/Constraint) faithful; **`Constraint.constrain()` scaling/align algorithm absent** |
| 71 | `src/terminal/osc.zig` | 697 | `osc/osc.v` | 532 | 85% | 92% | 0 | faithful | Full next()/end() state machine + all sub-parser dispatch faithful; allocating-writer/C-ABI machinery collapsed |
| 72 | `src/terminal/color.zig` | 685 | `terminal/color.v` | 573 | 93% | 92% | 0 | faithful | 256-palette gen, DynamicPalette/RGB, all parse forms (#rgb/rgb:/rgbi:/X11) match; extra TerminalColor scaffolding |
| 73 | `src/renderer/cell.zig` | 680 | `renderer/cells.v` | 497 | 45% | 95% | 0 | partial | All 10 cell-classification free fns absent (comments only); Contents rewritten w/o cursor-reserved lists; adds shader structs |
| 74 | `src/input/keycodes.zig` | 673 | `input/keycodes.v` | 536 | 95% | 98% | 5 | faithful | 243/243 entries match; macOS-specialized (native col pre-resolved); 5 TODOs are upstream Chromium notes |
| 75 | `src/terminal/tmux/layout.zig` | 638 | `tmux/layout.v` | 286 | 96% | 90% | 0 | faithful | Layout/Content/parse/parse_next/checksum faithful incl. rotate-right; arena note adapted to GC |
| 76 | `src/build/Config.zig` | 636 | `build_config.v` | 66 | 15% | 20% | 0 | low/stub | Tiny hand-picked subset (version/ReleaseChannel/Artifact/bundle_id); all init/options/fields absent |
| 77 | `src/apprt/gtk/class/global_shortcuts.zig` | 633 | - | 0 | 0% | 0% | - | missing | GTK apprt not translated |
| 78 | `src/font/sprite/draw/symbols_for_legacy_computing_supplement.zig` | 626 | `sprite/symbols_for_legacy_computing_supplement.v` | 713 | 62% | 95% | 9 | partial | Most draw fns match; **octant table fabricated** (not embedded octants.txt); circle pieces use lines not Bézier |
| 79 | `src/App.zig` | 613 | `app.v` | 597 | 72% | 95% | 17 | partial-high | Structural methods + mailbox faithful; SurfaceRef is placeholder → update_config + all keybinding paths stubbed |
| 80 | `src/crash/sentry_envelope.zig` | 597 | - | 0 | 0% | 0% | - | missing | Crash reporting not translated (`crash/crash.v` is 12-line stub) |
| 81 | `src/terminal/tmux/output.zig` | 590 | `tmux/output.v` | 332 | 78% | 85% | 0 | partial-high | Variable enum + parse/format faithful; Zig comptime FormatStruct/Type() replaced by runtime sum type (equivalent) |
| 82 | `src/font/opentype/os2.zig` | 583 | `opentype/opentype.v` | 1134 | 95% | 95% | 0 | faithful | Full version dispatch + correct BE offsets; FSSelection bitfield; superset file also implements SFNT/Head/Hhea/Post/SVG |
| 83 | `src/terminal/kitty/graphics_exec.zig` | 570 | `kitty/graphics_exec.v` | 466 | 50% | 82% | 11 | partial | Dispatch skeleton present but storage interaction stubbed (Screen lacks `kitty_images`); encode_error faithful |
| 84 | `src/font/CodepointResolver.zig` | 562 | `font/codepoint_resolver.v` | 434 | 80% | 92% | 8 | partial-high | 7-step get_index algorithm + descriptor cache faithful; only discovery interiors + UCD emoji lookup stubbed (ext deps) |
| 85 | `src/font/face/web_canvas.zig` | 561 | `font/face_web_canvas.v` | 512 | 20% | 88% | 18 | low/stub | All render/measure methods XTODO stubs; JS/canvas algorithms survive only as detailed pseudocode comments |
| 86 | `src/font/sprite/Face.zig` | 550 | `sprite/face.v` | 439 | 55% | 88% | 2 | partial | DrawFn/Range/get_draw_fn/has_codepoint faithful; comptime range auto-collection → manual if-chain; `render_glyph` write_atlas commented out |
| 87 | `src/cli/ssh-cache/DiskCache.zig` | 548 | - | 0 | 0% | 0% | - | missing | ssh-cache not translated |
| 88 | `src/apprt/gtk/class/imgui_widget.zig` | 541 | - | 0 | 0% | 0% | - | missing | GTK apprt not translated |
| 89 | `src/font/SharedGrid.zig` | 540 | `font/shared_grid.v` | 346 | 78% | 85% | 7 | partial-high | init/get_index/render/caches + emoji-constraint block faithful; locks are no-op XTODO; leans on stubbed render_glyph/Atlas |
| 90 | `src/inspector/widgets/key.zig` | 535 | - | 0 | 0% | 0% | - | missing | Inspector (imgui) not translated |
| 91 | `src/apprt/gtk/key.zig` | 535 | - | 0 | 0% | 0% | - | missing | GTK apprt not translated |
| 92 | `src/termio/Thread.zig` | 531 | - | 0 | 0% | 0% | - | missing | termio event-loop thread not translated |
| 93 | `src/apprt/gtk/winproto/x11.zig` | 527 | - | 0 | 0% | 0% | - | missing | GTK apprt not translated |
| 94 | `src/apprt/gtk/winproto/wayland.zig` | 524 | - | 0 | 0% | 0% | - | missing | GTK apprt not translated |
| 95 | `src/font/sprite/canvas.zig` | 512 | `sprite/sprite.v` | 640 | 30% | 50% | 16 | low/stub | Type scaffolding + Fraction faithful; **all rasterization primitives (draw_box/pixel/line/fill_path/write_atlas) are no-op stubs** |
| 96 | `src/os/flatpak.zig` | 507 | - | 0 | 0% | 0% | - | missing | Flatpak support not translated |
| 97 | `src/apprt/gtk/class/tab.zig` | 506 | - | 0 | 0% | 0% | - | missing | GTK apprt not translated |
| 98 | `src/font/sprite/draw/branch.zig` | 504 | `sprite/branch.v` | 774 | 90% | 95% | 0 | faithful | All 62 codepoints (F5D0-F60D) + branch_node/fading_line match; local `draw_arc` line-approximates box.zig's Bézier arc |
| 99 | `src/inspector/widgets/surface.zig` | 503 | - | 0 | 0% | 0% | - | missing | Inspector (imgui) not translated |
| 100 | `src/config/path.zig` | 496 | - | 0 | 3% | 5% | 2 | missing | `Path.expand`/tilde/XDG resolution not folded into configpkg; only an empty `preferred_default_file_path` stub |

## What's faithful (safe to rely on)

`nerd_font_attributes`, `key_encode`, `keycodes`, `key`, `sgr`, `color`, `bitmap_allocator`, `selection`, `split_tree`, `graphics_command`, `osc`, `osc9`, `semantic_prompt`, `os2`, `tmux/control`, `tmux/layout`, `symbols_for_legacy_computing`, `branch`, `sliding_window`, `shell_integration`. These are near 1:1 with verbatim comments and no meaningful logic gaps (tests excluded).

## Priority Follow-Up (in rough ROI order)

1. **PageList reflow + Terminal wide-char/grapheme.** These two gaps break core terminal correctness on resize and any non-ASCII/wide/emoji content. Highest impact per line. (`page_list.v` `resize_cols`; `terminal.v` `print`/insert/delete/erase spacer handling.)
2. **Font rasterization pipeline.** `freetype.v`/`face_coretext.v` bindings, `font/font.v` `Atlas` bin-packing + `Metrics.calc`, and `sprite/sprite.v` `Canvas` primitives are all stubbed — nothing renders until these exist. The faithful glyph files (`branch`, `symbols_*`) are blocked on `Canvas`.
3. **Config.** Only ~29% of option fields and none of the parser/validation exist; move the detached doc-comment dump onto real fields as they're added.
4. **Renderer core.** `renderer.v` `updateFrame`/`rebuildCells`/`drawFrame` and `image.v` kitty upload are placeholders; the GPU path is non-functional.
5. **Screen refcount/reflow semantics** (`clone`, `cursorCopy`, hyperlink/style migration, `resize`) — needed before PageList reflow can be trusted end-to-end.
6. **Wire up parsed results that are computed then discarded:** `osc/color_parser.v` drops its parsed `requests`; `formatter.v` `cell_style` returns defaults; `stream_readonly.v` color/semantic-prompt no-ops.
7. **Binding chaining** (`chain=`) and the `input/command.v` `actionCommands` table — currently unimplemented, blocking command-palette/keybind features.
8. **Comment placement.** The `--- Original Ghostty Comments ---` header-dump pattern satisfies "same text" but not "same place." As each file reaches logic parity, migrate its comment block onto the corresponding declarations.
9. **Platform breadth (lower priority for a macOS build):** the 23 missing files are GTK/Linux apprt, inspector/imgui widgets, tmux viewer, build system, crash envelope, flatpak, ssh-cache, termio/Thread, config/path. Create targets only as those subsystems are needed.
