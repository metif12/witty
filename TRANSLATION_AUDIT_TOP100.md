# Translation Audit: Top 100 Ghostty Zig Files by LOC

Generated from `/Users/alexander/code/3rd/ghostty/src` and `/Users/alexander/code/3rd/ghostty/pkg`, considering `.zig` files only. The target repository is `/Users/alexander/code/witty`.

The user requirement for this audit is strict: translated logic and comments should match the original. The scores below are therefore conservative. A file with working V code can still fail this audit if comments were rewritten/omitted or if the translation only preserves part of the API surface.

## Method

- Ranked original Ghostty `.zig` files by physical LOC and selected the top 100.
- Mapped each original file to the most likely V translation path using known module moves and snake_case path conversion.
- Estimated logic coverage from identifier overlap, top-level declaration overlap, V/original LOC ratio, and TODO/stub markers.
- Estimated comment fidelity from exact normalized comment-line overlap. This intentionally penalizes paraphrased comments because the requirement says comments must be the same.
- This is a triage audit, not a proof of semantic equivalence. Rows marked `partial-high` still need manual side-by-side review before being considered complete.

## Summary

- Top 100 original files audited: 100
- Missing V translation candidate: 28
- Existing but low/stub translation: 55
- Existing partial translation: 17
- Comment fidelity poor or missing: 70

High-level finding: the repository has meaningful translations for many terminal/font/input modules, but strict parity is not met for most top-LOC files. The largest gaps are GTK/apprt, config, termio, renderer integration, inspector, tmux, build, and comment preservation.

## Manual Spot Checks

- `src/terminal/PageList.zig`: Large V file exists, but audit finds API/identifier drift and reflow code still has TODO markers; comments are largely rewritten/omitted.
- `src/terminal/Terminal.zig`: Large V file exists and core state-machine shape is present, but comments are not preserved and there are simplifications in screen clearing/reflow paths.
- `src/config/Config.zig`: V configpkg is far smaller; many config options, docs, validation rules, and parser details are absent.
- `src/terminal/Screen.zig`: V screen has substantial behavior, but comment parity is poor and several semantics should be checked against Ghostty before treating it as faithful.
- `src/Surface.zig`: V surface is much smaller and contains explicit stubs for runtime integration; not a faithful translation.
- `src/renderer/generic.zig`: V renderer currently keeps many TODO/stub rendering paths; logic is not fully translated.
- `src/apprt/gtk/class/surface.zig`: GTK class/runtime code has no matching V implementation.
- `src/font/shaper/coretext.zig`: CoreText shaping exists in V but should be manually audited; comment/API parity is low.
- `src/renderer/OpenGL.zig`: OpenGL wrapper and resource types are now present; runtime presentation/context integration still needs platform validation.

## Top 100 Table

| # | Original | LOC | V candidate | V LOC | Logic | Comments | Verdict | Notes |
|---:|---|---:|---|---:|---:|---:|---|---|
| 1 | `src/terminal/PageList.zig` | 14466 | `terminal/page_list.v` | 2233 | 15% | 0% | low/stub | 1 TODO/stub markers; much smaller than original; comments not preserved; top-level API diverges |
| 2 | `src/terminal/Terminal.zig` | 12431 | `terminal/terminal.v` | 2307 | 25% | 27% | low/stub | 10 TODO/stub markers; much smaller than original; comments not preserved; top-level API diverges |
| 3 | `src/config/Config.zig` | 10411 | `configpkg/configpkg.v` | 590 | 10% | 0% | low/stub | 4 TODO/stub markers; much smaller than original; comments not preserved; top-level API diverges |
| 4 | `src/terminal/Screen.zig` | 10352 | `terminal/screen.v` | 1579 | 22% | 0% | low/stub | 20 TODO/stub markers; much smaller than original; comments not preserved; top-level API diverges |
| 5 | `src/Surface.zig` | 6781 | `surface.v` | 2835 | 28% | 1% | low/stub | 12 TODO/stub markers; comments not preserved; top-level API diverges |
| 6 | `src/terminal/formatter.zig` | 5939 | `terminal/formatter.v` | 1160 | 19% | 27% | low/stub | 7 TODO/stub markers; much smaller than original; comments not preserved; top-level API diverges |
| 7 | `src/input/Binding.zig` | 4816 | `input/binding.v` | 2001 | 34% | 8% | low/stub | comments not preserved; top-level API diverges |
| 8 | `src/apprt/gtk/class/surface.zig` | 4025 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 9 | `src/terminal/page.zig` | 3861 | `terminal/page.v` | 1531 | 20% | 20% | low/stub | comments not preserved; top-level API diverges |
| 10 | `src/terminal/stream.zig` | 3389 | `terminal/stream.v` | 1604 | 38% | 21% | partial | 1 TODO/stub markers; comments not preserved; top-level API diverges |
| 11 | `src/renderer/generic.zig` | 3335 | `renderer/renderer.v` | 1210 | 25% | 23% | low/stub | 19 TODO/stub markers; comments not preserved; top-level API diverges |
| 12 | `src/apprt/gtk/class/application.zig` | 2836 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 13 | `src/font/nerd_font_attributes.zig` | 2774 | `font/nerd_font_attributes.v` | 2738 | 74% | 80% | partial-high | top-level API diverges |
| 14 | `src/font/shaper/coretext.zig` | 2678 | `font/shaper/coretext.v` | 624 | 19% | 43% | low/stub | 12 TODO/stub markers; much smaller than original; top-level API diverges |
| 15 | `src/input/key_encode.zig` | 2399 | `input/key_encode.v` | 947 | 36% | 37% | low/stub | top-level API diverges |
| 16 | `src/terminal/tmux/viewer.zig` | 2292 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 17 | `src/datastruct/split_tree.zig` | 2273 | `datastruct/split_tree.v` | 1141 | 36% | 46% | low/stub | top-level API diverges |
| 18 | `src/apprt/embedded.zig` | 2207 | `apprt/embedded.v` | 1735 | 47% | 37% | partial | 1 TODO/stub markers; top-level API diverges |
| 19 | `src/font/shaper/harfbuzz.zig` | 2163 | `font/shaper/harfbuzz.v` | 359 | 18% | 46% | low/stub | 7 TODO/stub markers; much smaller than original; top-level API diverges |
| 20 | `src/apprt/gtk/class/window.zig` | 2024 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 21 | `src/cli/list_themes.zig` | 1741 | `cli/list_themes.v` | 634 | 31% | 97% | low/stub | 9 TODO/stub markers; top-level API diverges |
| 22 | `src/termio/Exec.zig` | 1739 | `termio/exec.v` | 917 | 29% | 38% | low/stub | top-level API diverges |
| 23 | `src/terminal/search/sliding_window.zig` | 1676 | `search/sliding_window.v` | 658 | 34% | 45% | low/stub | top-level API diverges |
| 24 | `src/cli/args.zig` | 1627 | `cli_args/cli_args.v` | 501 | 18% | 44% | low/stub | 21 TODO/stub markers; much smaller than original; top-level API diverges |
| 25 | `src/terminal/Selection.zig` | 1598 | `terminal/selection.v` | 415 | 35% | 47% | low/stub | much smaller than original; top-level API diverges |
| 26 | `src/termio/stream_handler.zig` | 1551 | `termio/stream_handler.v` | 1496 | 49% | 60% | partial | 1 TODO/stub markers; top-level API diverges |
| 27 | `src/terminal/hash_map.zig` | 1540 | `terminal/hash_map.v` | 562 | 21% | 0% | low/stub | 3 TODO/stub markers; comments not preserved; top-level API diverges |
| 28 | `src/font/Collection.zig` | 1523 | `font/collection.v` | 869 | 29% | 18% | low/stub | 3 TODO/stub markers; comments not preserved; top-level API diverges |
| 29 | `src/terminal/search/screen.zig` | 1516 | `search/screen_search.v` | 470 | 27% | 26% | low/stub | 9 TODO/stub markers; much smaller than original; comments not preserved; top-level API diverges |
| 30 | `src/terminal/render.zig` | 1464 | `terminal/render.v` | 459 | 20% | 41% | low/stub | 4 TODO/stub markers; much smaller than original; top-level API diverges |
| 31 | `src/font/face/freetype.zig` | 1436 | `font/face.v`, `freetype/freetype.v` | 1248 | 36% | 21% | low/stub | 55 TODO/stub markers; comments not preserved; top-level API diverges |
| 32 | `src/font/sprite/draw/symbols_for_legacy_computing.zig` | 1413 | `sprite/symbols_for_legacy_computing.v` | 1077 | 55% | 84% | partial | 2 TODO/stub markers; top-level API diverges |
| 33 | `src/terminal/kitty/graphics_storage.zig` | 1359 | `kitty/graphics_storage.v` | 863 | 42% | 66% | partial | 2 TODO/stub markers; top-level API diverges |
| 34 | `src/terminal/kitty/graphics_unicode.zig` | 1347 | `kitty/graphics_unicode.v` | 834 | 62% | 69% | partial | 10 TODO/stub markers; top-level API diverges |
| 35 | `src/terminal/kitty/graphics_command.zig` | 1325 | `kitty/graphics_command.v` | 1089 | 57% | 60% | partial | top-level API diverges |
| 36 | `src/apprt/gtk/class/split_tree.zig` | 1241 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 37 | `src/font/face/coretext.zig` | 1162 | `font/face_coretext.v` | 651 | 15% | 40% | low/stub | 26 TODO/stub markers; top-level API diverges |
| 38 | `src/terminal/osc/parsers/osc9.zig` | 1140 | `osc/osc9.v` | 330 | 33% | 89% | low/stub | much smaller than original; top-level API diverges |
| 39 | `src/terminal/style.zig` | 1072 | `terminal/style.v` | 295 | 19% | 26% | low/stub | 4 TODO/stub markers; much smaller than original; comments not preserved; top-level API diverges |
| 40 | `src/terminal/Parser.zig` | 1072 | `terminal/parser.v` | 781 | 29% | 0% | low/stub | 1 TODO/stub markers; comments not preserved; top-level API diverges |
| 41 | `src/terminal/sgr.zig` | 1070 | `terminal/sgr.v` | 294 | 28% | 22% | low/stub | much smaller than original; comments not preserved; top-level API diverges |
| 42 | `src/font/discovery.zig` | 1049 | `font/discovery.v` | 422 | 20% | 31% | low/stub | 10 TODO/stub markers; comments not preserved; top-level API diverges |
| 43 | `src/terminal/bitmap_allocator.zig` | 1021 | `terminal/bitmap_allocator.v` | 320 | 25% | 50% | low/stub | much smaller than original; top-level API diverges |
| 44 | `src/termio/shell_integration.zig` | 1006 | `termio/shell_integration.v` | 347 | 20% | 72% | low/stub | 2 TODO/stub markers; much smaller than original; top-level API diverges |
| 45 | `src/terminal/stream_readonly.zig` | 990 | `terminal/stream_readonly.v` | 459 | 44% | 18% | partial | 3 TODO/stub markers; comments not preserved; top-level API diverges |
| 46 | `src/terminal/osc/parsers/semantic_prompt.zig` | 964 | `osc/semantic_prompt.v` | 373 | 40% | 44% | partial | top-level API diverges |
| 47 | `src/renderer/image.zig` | 958 | `renderer/image.v` | 315 | 20% | 32% | low/stub | 5 TODO/stub markers; much smaller than original; comments not preserved; top-level API diverges |
| 48 | `src/font/sprite/draw/box.zig` | 929 | `sprite/block.v`, `sprite/common.v` | 216 | 9% | 1% | low/stub | much smaller than original; comments not preserved; top-level API diverges |
| 49 | `src/apprt/action.zig` | 918 | `apprt/action.v` | 489 | 53% | 35% | partial | top-level API diverges |
| 50 | `src/input/key_mods.zig` | 914 | `input/key_mods.v` | 311 | 23% | 6% | low/stub | much smaller than original; comments not preserved; top-level API diverges |
| 51 | `src/terminal/search/Thread.zig` | 905 | `search/search_thread.v` | 135 | 7% | 20% | low/stub | 12 TODO/stub markers; much smaller than original; comments not preserved; top-level API diverges |
| 52 | `src/build/SharedDeps.zig` | 897 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 53 | `src/font/Atlas.zig` | 889 | `font/font.v` | 489 | 15% | 0% | low/stub | 6 TODO/stub markers; comments not preserved; top-level API diverges |
| 54 | `src/input/key.zig` | 879 | `input/key.v` | 986 | 46% | 14% | partial | comments not preserved; top-level API diverges |
| 55 | `src/datastruct/circ_buf.zig` | 866 | `search/circ_buf.v` | 225 | 13% | 0% | low/stub | much smaller than original; comments not preserved; top-level API diverges |
| 56 | `src/inspector/widgets/pagelist.zig` | 852 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 57 | `src/terminal/kitty/graphics_image.zig` | 835 | `kitty/graphics_image.v` | 282 | 23% | 13% | low/stub | 3 TODO/stub markers; much smaller than original; comments not preserved; top-level API diverges |
| 58 | `src/font/SharedGridSet.zig` | 834 | `font/shared_grid_set.v` | 634 | 39% | 62% | partial | 9 TODO/stub markers; top-level API diverges |
| 59 | `src/font/Metrics.zig` | 816 | `font/font.v` | 489 | 23% | 0% | low/stub | 6 TODO/stub markers; comments not preserved; top-level API diverges |
| 60 | `src/inspector/widgets/termio.zig` | 811 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 61 | `src/apprt/gtk/class/command_palette.zig` | 790 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 62 | `src/terminal/osc/parsers/color.zig` | 780 | `osc/color_parser.v` | 629 | 38% | 16% | low/stub | 1 TODO/stub markers; comments not preserved; top-level API diverges |
| 63 | `src/termio/Termio.zig` | 769 | `termio/termio.v` | 268 | 17% | 0% | low/stub | 7 TODO/stub markers; much smaller than original; comments not preserved; top-level API diverges |
| 64 | `src/input/command.zig` | 737 | `input/command.v`, `command.v` | 366 | 14% | 9% | low/stub | 5 TODO/stub markers; comments not preserved; top-level API diverges |
| 65 | `src/inspector/widgets/terminal.zig` | 726 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 66 | `src/terminal/tmux/control.zig` | 725 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 67 | `src/renderer/Thread.zig` | 717 | `renderer/thread.v` | 271 | 19% | 16% | low/stub | 1 TODO/stub markers; comments not preserved; top-level API diverges |
| 68 | `src/Command.zig` | 717 | `command.v` | 322 | 15% | 27% | low/stub | 4 TODO/stub markers; comments not preserved; top-level API diverges |
| 69 | `src/terminal/ref_counted_set.zig` | 714 | `terminal/ref_counted_set.v` | 588 | 37% | 55% | low/stub | 5 TODO/stub markers; top-level API diverges |
| 70 | `src/font/face.zig` | 707 | `font/face.v` | 730 | 23% | 0% | low/stub | 22 TODO/stub markers; comments not preserved; top-level API diverges |
| 71 | `src/terminal/osc.zig` | 697 | `osc/osc.v` | 400 | 38% | 13% | partial | comments not preserved; top-level API diverges |
| 72 | `src/terminal/color.zig` | 685 | `terminal/color.v` | 574 | 53% | 51% | partial | top-level API diverges |
| 73 | `src/renderer/cell.zig` | 680 | `renderer/cells.v` | 338 | 23% | 0% | low/stub | comments not preserved; top-level API diverges |
| 74 | `src/input/keycodes.zig` | 673 | `input/keycodes.v` | 304 | 26% | 5% | low/stub | comments not preserved; top-level API diverges |
| 75 | `src/terminal/tmux/layout.zig` | 638 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 76 | `src/build/Config.zig` | 636 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 77 | `src/apprt/gtk/class/global_shortcuts.zig` | 633 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 78 | `src/font/sprite/draw/symbols_for_legacy_computing_supplement.zig` | 626 | `sprite/symbols_for_legacy_computing_supplement.v` | 562 | 51% | 8% | partial | 8 TODO/stub markers; comments not preserved; top-level API diverges |
| 79 | `src/App.zig` | 613 | `app.v` | 409 | 30% | 30% | low/stub | 22 TODO/stub markers; comments not preserved; top-level API diverges |
| 80 | `src/crash/sentry_envelope.zig` | 597 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 81 | `src/terminal/tmux/output.zig` | 590 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 82 | `src/font/opentype/os2.zig` | 583 | `opentype/opentype.v` | 1135 | 30% | 74% | low/stub | top-level API diverges |
| 83 | `src/terminal/kitty/graphics_exec.zig` | 570 | `kitty/graphics_exec.v` | 373 | 34% | 21% | low/stub | 19 TODO/stub markers; comments not preserved; top-level API diverges |
| 84 | `src/font/CodepointResolver.zig` | 562 | `font/codepoint_resolver.v` | 435 | 32% | 66% | low/stub | 10 TODO/stub markers; top-level API diverges |
| 85 | `src/font/face/web_canvas.zig` | 561 | `font/face_web_canvas.v` | 513 | 24% | 50% | low/stub | 21 TODO/stub markers; top-level API diverges |
| 86 | `src/font/sprite/Face.zig` | 550 | `sprite/face.v` | 333 | 16% | 22% | low/stub | 2 TODO/stub markers; comments not preserved; top-level API diverges |
| 87 | `src/cli/ssh-cache/DiskCache.zig` | 548 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 88 | `src/apprt/gtk/class/imgui_widget.zig` | 541 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 89 | `src/font/SharedGrid.zig` | 540 | `font/shared_grid.v` | 347 | 34% | 73% | low/stub | 7 TODO/stub markers; top-level API diverges |
| 90 | `src/inspector/widgets/key.zig` | 535 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 91 | `src/apprt/gtk/key.zig` | 535 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 92 | `src/termio/Thread.zig` | 531 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 93 | `src/apprt/gtk/winproto/x11.zig` | 527 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 94 | `src/apprt/gtk/winproto/wayland.zig` | 524 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 95 | `src/font/sprite/canvas.zig` | 512 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 96 | `src/os/flatpak.zig` | 507 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 97 | `src/apprt/gtk/class/tab.zig` | 506 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 98 | `src/font/sprite/draw/branch.zig` | 504 | `sprite/branch.v` | 667 | 65% | 29% | partial-high | comments not preserved; top-level API diverges |
| 99 | `src/inspector/widgets/surface.zig` | 503 | - | 0 | 0% | 0% | missing | no V translation candidate found |
| 100 | `src/config/path.zig` | 496 | - | 0 | 0% | 0% | missing | no V translation candidate found |

## Priority Follow-Up

1. Restore comment parity for files that are otherwise structurally translated. Start with `terminal/page_list.v`, `terminal/terminal.v`, `terminal/screen.v`, `terminal/formatter.v`, and `input/binding.v`.
2. Complete missing high-LOC modules before polishing low-value small files: GTK/apprt classes, `config/Config.zig`, termio, tmux, inspector widgets, and build resources.
3. Treat renderer files as high risk: `renderer/renderer.v`, `renderer/image.v`, and OpenGL/Metal integration contain explicit TODO/stub markers and need side-by-side translation from Ghostty before behavior can be trusted.
4. For every top-100 file, add a source-path comment or metadata marker so future audits can map originals to translations unambiguously.
