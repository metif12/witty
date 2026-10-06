# Ghostty → V source-fidelity audit

Audit date: **2026-10-02**. Initial audited snapshot result: **the requested fidelity criterion was not met**. That snapshot contained upstream branches with no translation, replacement algorithms, disconnected translated implementations, and observable behavior differences. The findings and inventories below retain that historical evidence; the fix resolution ledger records the subsequent source translations, separate commits, executed checks, and remaining validation limits. Neither the original audit nor the finding fixes certify complete repository equivalence.

Four agents worked in parallel on terminal/protocol/input/data structures; runtime/configuration/subprocess/CLI/OS; renderer/font/sprite/inspector; and supporting/build/dependency code. They read current originals and V counterparts, traced relevant live callers, and used targeted native reference probes. A separate cross-review corrected claims about inherited unsupported macOS actions, native dependency linking, and compiler/module-path failures before publication.

## Reference and working-tree identity

| Item | Audited identity |
| --- | --- |
| Ghostty | `/Users/alex/code/3rd/ghostty`, clean commit `6c0e02d1138d5376e4ac2f5e311b225494514a97` |
| Witty | `/Users/alex/code/witty`, HEAD `96ca76ac4233f9b607524e41c813782181f82d5f`, with the existing working-tree changes below |
| V used for authoritative module/integration checks | `/Users/alex/.cache/v/v1-fallback/0.5.2/v`, reports `V 0.5.2`; `VEXE` explicitly set to that executable |
| Native Zig reference probes | Zig 0.15.2, `/private/tmp/witty-zig-reference/zig-aarch64-macos-0.15.2/zig`, target `aarch64-macos.14.0`, linked with `-lc` |
| Locked zigimg | `d7b7ab0ba0899643831ef042bd73289510b39906`, as pinned by the local vaxis reference |
| Other supporting references | Local `/Users/alex/code/3rd/libxev` and `/Users/alex/code/3rd/vaxis` extracted sources; cached z2d 0.10.0; Zig 0.15.2 standard library |

At audit start, `.DS_Store`, `zigimg/io.v`, and `zigimg/tiff_deflate.v` were modified; `zigimg/png_reader.v` and `zigimg/reference_probes/png_decode/` were untracked. They were preserved and included when examining current behavior. In particular, the current PNG decoder is implemented and passed the differential matrix below: the older audit's blanket claim that it is missing is stale. Existing `AUDIT_FINDINGS.md` entries were background context, not proof for this report.

The locked zigimg `src` tree was verified against the repository's pinned tree digest, `ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b` (sorted relative paths plus NUL separators and file bytes). `unicode/tables.bin` SHA-256 is `c66888cff0007450992232712af32fa216455db60987abaa9dec00f681fb3eed`, matching its recorded digest. Table regeneration was not performed. The libxev/vaxis directories are extracted trees without Git metadata; their exact Git revision was not independently established, so dependency conclusions refer to those local references.

Source locations written as `src/...` refer to the Ghostty root. V locations refer to the Witty root. Supporting-library locations are explicitly prefixed with their library. Links with absolute source locations are usable in this workspace. Line numbers identify the audited working tree and may move after changes.

## Coverage and interpretation

“Big” means **at least 500 physical lines**, including tests, whitespace, and comments. Every one of the 99 big primary Zig originals received a direct targeted comparison or a documented no-counterpart determination. All 456 primary Zig originals have explicit inventory entries. A targeted review covers the stated branch families; it does not mean every branch of a 10,000-line module was proven equivalent.

| Parallel slice | Primary Zig files | Physical lines | Big originals |
| --- | ---: | ---: | ---: |
| Terminal/protocols/input/data structures | 112 | 103,071 | 40 |
| Runtime/configuration/subprocess/CLI/OS | 145 | 64,913 | 26 |
| Renderer/fonts/sprites/inspector | 96 | 44,576 | 30 |
| Supporting/build/root glue | 103 | 12,763 | 3 |
| **Total** | **456** | **225,323** | **99** |

The big originals account for **172,486 physical lines**. The inventory additionally covers **111 non-Zig sources/resources** from the runtime and renderer slices, including all three additional large Python/Metal sources (two Python files and the built-in Metal shader). Byte comparison of resources is distinguished from executable-logic review. A separate appendix inventories **36 large supporting-library originals**; most of those dependency bodies received inventory-level review only. They are not included in the 99-primary-source review claim.

Review levels used in the inventory:

- **branch-reviewed**: complete executable branch comparison within the stated file scope.
- **targeted**: direct source/counterpart comparison of selected implemented branch families and their callers.
- **inventory-only**: counterpart mapping and omission/stub scan; behavior remains unverified.
- **no-counterpart**: a source implementation/API has no direct executable counterpart; manual specializations or generated data, where present, are explained in the findings.

Primary review-level counts: **branch-reviewed: 11**, **inventory-only: 207**, **no-counterpart: 30**, **targeted: 208**. Primary status counts: **divergence-confirmed: 46**, **gap-confirmed: 52**, **no-discrepancy-observed: 147**, **unverified: 211**. These are inventory categories, not estimates of translation completion.

**`no-discrepancy-observed` is scoped to the examined paths. It is not an approval or a whole-file fidelity certificate.** `gap-confirmed` records omitted source behavior; `divergence-confirmed` records a replacement or changed contract; `unverified` identifies remaining uncertainty. Namespace relocation, consolidation, generated data, or V syntax alone is not evidence of a rewrite. Conversely, a same-named file or passing counterpart-only test is not proof that the original algorithm is live or faithfully translated.

Source placeholders and GC-only cleanup were checked against the original before classification. A no-op inherited from Ghostty is faithful to that original limitation. An empty body that discards an implemented enabled-feature branch is a gap. Explicit safety improvements, different libraries, subprocess replacements, and defensive checks are still divergences under the user’s strict preservation requirement, even when independently reasonable changes. No production fixes were made during the initial audit.

The native follow-up directly targeted **all 13 large Swift originals (16,338 physical lines)** and the **1,160-line public embedding header**. Two additional large stb headers (**10,621 lines**) are byte-identical reused source. Together with the three Python/Metal originals already in the additional-source inventory, this accounts for **19 large non-Zig/native/public-header originals** outside the 99-primary-Zig set: **118 large originals** in the selected core/native/API source scope. Targeted native comparisons establish the recorded gaps; they do not certify all Swift branches or all external dependency source.

## Findings index

The report contains **63 source-backed finding entries**. Some entries group related missing branches; this count is not a count of unique bugs or affected files. High/Medium/Low indicate scope and impact within the audited implementation, not a security score. The terminal slice uses classifications rather than severity labels.

| Slice | Entries | Main confirmed issues |
| --- | ---: | --- |
| Terminal/input/protocols | T01–T14 (14) | Kitty reader/decompression/temp-file contracts; invalid UTF-8; search startup; C codepoint/enum/buffer contracts; OSC 9; Windows keys; Page/allocator/generic boundaries; tmux grammar |
| Runtime/configuration/OS | R01–R09 (9) | Windows ConPTY; nullable config C API; notification errors; SSH cache; GTK palette/shortcut/model/CSS/native-class changes; locale canonicalization |
| Renderer/fonts/inspector | RF-01, RF-02, RF-04–RF-12 (11) | Disconnected backend selection; omitted grid lock; feature parsing; custom shaders; glass alpha; eager row shaping; inspector/public/invariant behavior |
| Supporting/build/dependencies | S01–S16 (16) | SIMD/Base64; alignment; Sentry; build/install/package and metadata; macOS host/startup; synthetic streams/RNG; image/JPEG loading; Huffman replacement; libxev targets; vaxis image APIs; generic ABI; built-in Metal compilation |
| Native macOS controllers | SH01–SH06 (6) | Splits, Quick Terminal, undo/restoration, configured windows/titlebars/fullscreen, termination/reopen |
| Native macOS bridge/views | SB-01–SB-06 (6) | IME/key responders, accessibility/Services/drop, action consumers/overlays, display IDs, menu shortcuts, reload targets |
| Public embedding header | PH01 (1) | Linux/FreeBSD embedding argv source |

RF-03 was withdrawn during cross-review because its initial evidence depended on a different V compiler and incorrect module-path precedence. The authoritative pinned font/inspector tests pass. It is not counted as a confirmed defect.


## Terminal, protocols, input, and data structures

This section compares the current Ghostty source at `6c0e02d` with the current V implementation. The scope contains 112 original Zig files, 103,071 physical lines, and 40 files with at least 500 physical lines. Physical counts include tests and comments. Every one of those 40 large files received direct comparison of executable branches with its split or consolidated V counterpart. Eight files received complete executable branch review; 62 received targeted review; 42 smaller files received counterpart inventory and stub/missing-text scanning only. The inventories below retain each mapping and review level; this section describes the examined branch families.

The result does **not** establish complete logic parity. The confirmed discrepancies below disprove parity. “No discrepancy observed” in the inventory means only that the examined branches yielded none. In particular, the remainder of terminal control operations, PageList resize/reflow paths, Screen mutation paths, generic data structure failure paths, complete keycode/diacritic table enumeration, all build/OS combinations, and the 42 inventory-only files remain unverified. Production files were not edited by this reviewer.

### Confirmed findings

**T01 — Kitty file transmission accepts a truncated prefix where the source rejects the stream. Classification: behavior drift / algorithm replacement.**

- Original: [`src/terminal/kitty/graphics_image.zig:269`](/Users/alex/code/3rd/ghostty/src/terminal/kitty/graphics_image.zig:269) constructs a reader and calls `appendRemaining(..., .limited(size))`. A reached limit produces `StreamTooLong`, mapped to `InvalidData`; seek/read failures also become `InvalidData`.
- V: [`terminal/kitty_graphics_image.v:432`](/Users/alex/code/witty/terminal/kitty_graphics_image.v:432) calls `f.read_bytes_at(size, start)` and accepts the returned bytes. This reads a prefix and does not preserve the source error path.
- Reproduction with an owned four-byte file containing `1234`, `S=3`, RGB `1×1`: actual unchanged Ghostty `LoadingImage.init` returns `InvalidData`; V initialization reads `123`, and V completion succeeds. The native standard-library probe also confirms that a three-byte stream with limit three is rejected by the source operation. This changes file/query/transmission acceptance at the explicit and maximum size boundaries.

**T02 — Kitty zlib decompression loses its bound during expansion. Classification: algorithm replacement / resource-bound drift.**

- Original: [`src/terminal/kitty/graphics_image.zig:403`](/Users/alex/code/3rd/ghostty/src/terminal/kitty/graphics_image.zig:403) uses Zig's streaming flate decoder with a 32 KiB window and `appendRemaining(..., .limited(max_size))`. Failure, including a reached 400 MiB limit, returns `DecompressionFailed`.
- V: [`terminal/kitty_graphics_image.v:518`](/Users/alex/code/witty/terminal/kitty_graphics_image.v:518) calls `compress.zlib.decompress(self.data)` to materialize the whole result, then checks `decompressed.len > max_image_size`.
- Consequence: the 400 MiB check no longer bounds intermediate decompression allocation. Exact-limit output is accepted by V's `>` check but rejected by the source reader. The replacement also uses V's zlib implementation instead of translating the source's decoder path. The large allocation case was not executed; bounded-reader behavior was independently verified with a small native probe.

**T03 — Kitty temporary-file directory selection is replaced with a different policy. Classification: behavior drift / algorithm replacement.**

- Original: [`src/terminal/kitty/graphics_image.zig:281`](/Users/alex/code/3rd/ghostty/src/terminal/kitty/graphics_image.zig:281) permits `/tmp`, `/dev/shm`, and the selected temporary directory and its realpath. [`src/os/file.zig:59`](/Users/alex/code/3rd/ghostty/src/os/file.zig:59) selects `TMPDIR`, then `TMP`, then `/tmp` on POSIX.
- V: [`terminal/kitty_graphics_image.v:553`](/Users/alex/code/witty/terminal/kitty_graphics_image.v:553) always adds `/var/tmp`, adds `TMPDIR` when nonempty, and never reads `TMP`.
- Consequence: V accepts `/var/tmp` files the source rejects for other selected temporary directories, and rejects a custom `TMP` directory accepted by the source. This matters because successful temporary-file policy validation enables deletion after processing: original [`graphics_image.zig:225`](/Users/alex/code/3rd/ghostty/src/terminal/kitty/graphics_image.zig:225), V [`kitty_graphics_image.v:403`](/Users/alex/code/witty/terminal/kitty_graphics_image.v:403). This is directly verified from executable branches; no external temporary files were deleted to demonstrate it.

**T04 — Key encoding omits strict UTF-8 rejection. Classification: missing translation / behavior drift.**

- Original: [`src/input/key_encode.zig:199`](/Users/alex/code/3rd/ghostty/src/input/key_encode.zig:199) validates printable Kitty text with `Utf8View.init` and falls back to the key sequence on invalid UTF-8. Alternate-key extraction at [`key_encode.zig:245`](/Users/alex/code/3rd/ghostty/src/input/key_encode.zig:245), legacy CSI-u at [`key_encode.zig:476`](/Users/alex/code/3rd/ghostty/src/input/key_encode.zig:476), and associated text at [`key_encode.zig:1023`](/Users/alex/code/3rd/ghostty/src/input/key_encode.zig:1023) also explicitly reject invalid UTF-8.
- V: [`input/key_encode.v:171`](/Users/alex/code/witty/input/key_encode.v:171), [`key_encode.v:210`](/Users/alex/code/witty/input/key_encode.v:210), [`key_encode.v:405`](/Users/alex/code/witty/input/key_encode.v:405), and [`key_encode.v:867`](/Users/alex/code/witty/input/key_encode.v:867) use permissive `string.runes()` without the source validation branches.
- Actual differential probe: key `key_a`, unshifted `97`, text byte `FF`. Original `encode` produces `ESC[97u` for Kitty flags `1`, `9`, `13`, and `25`. V emits raw `FF` for flags `1`; with flags `25`, V emits `ESC[97;;65533u`, inventing associated replacement-character text. Flags `9` and `13` match in this particular fixture. Existing passing tests do not cover this input.

**T05 — Search startup returns on a nonfatal QoS error. Classification: behavior drift.**

- Original: [`src/terminal/search/Thread.zig:146`](/Users/alex/code/3rd/ghostty/src/terminal/search/Thread.zig:146) logs a failed macOS utility QoS request and continues to register async handlers, drain the mailbox, and run the search loop.
- V: [`search/search_thread.v:492`](/Users/alex/code/witty/search/search_thread.v:492) logs the error and returns.
- Consequence: a QoS failure prevents all search startup. The return also occurs before the quit-event defer at [`search_thread.v:511`](/Users/alex/code/witty/search/search_thread.v:511), so callers can miss that notification. Verified statically; the OS failure was not injected.

**T06 — The C key-event codepoint setter does not reproduce `u21` truncation. Classification: behavior drift / representation boundary.**

- Original: [`src/terminal/c/key_event.zig:114`](/Users/alex/code/3rd/ghostty/src/terminal/c/key_event.zig:114) uses `@truncate(codepoint)` into the `u21` event field.
- V: [`terminal_c/terminal_c.v:165`](/Users/alex/code/witty/terminal_c/terminal_c.v:165) stores all 32 bits in the V event field. [`lib_vt_c.v:128`](/Users/alex/code/witty/lib_vt_c.v:128) delegates without masking.
- Actual differential probe with `0x200001`: original getter returns `1`; V returns `2097153`. Downstream binding hashing and Kitty encoding therefore can receive a different codepoint.

**T07 — C enum safety checks are untranslated. Classification: missing translation.**

- Original: [`src/terminal/c/key_event.zig:39`](/Users/alex/code/3rd/ghostty/src/terminal/c/key_event.zig:39) and [`key_event.zig:56`](/Users/alex/code/3rd/ghostty/src/terminal/c/key_event.zig:56) validate action/key enum values in runtime-safety builds and leave the event unchanged on invalid input. [`src/terminal/c/key_encode.zig:107`](/Users/alex/code/3rd/ghostty/src/terminal/c/key_encode.zig:107) does the same for `OptionAsAlt`.
- V: [`terminal_c/terminal_c.v:117`](/Users/alex/code/witty/terminal_c/terminal_c.v:117), [`terminal_c.v:125`](/Users/alex/code/witty/terminal_c/terminal_c.v:125), and [`terminal_c.v:259`](/Users/alex/code/witty/terminal_c/terminal_c.v:259) assign unchecked enum bits; raw exports likewise provide no equivalent checks.
- Actual Debug source probe passes action `99` and key `999999` through their ABI-sized enum representations: source logs warnings and retains defaults `press=1` and `unidentified=0`; V stores `99` and `999999`. The source checks are conditional on runtime safety, so this finding is qualified to those source builds.

**T08 — C encoding changes the short-buffer write contract. Classification: behavior drift / algorithm replacement.**

- Original: [`src/terminal/c/key_encode.zig:125`](/Users/alex/code/3rd/ghostty/src/terminal/c/key_encode.zig:125) encodes directly into the caller's fixed writer. A full buffer can contain the emitted prefix before `WriteFailed`; a discard writer then computes required size.
- V: [`terminal_c/terminal_c.v:270`](/Users/alex/code/witty/terminal_c/terminal_c.v:270) builds the whole string, checks its size, and returns before touching a short buffer.
- Actual differential probe for Up arrow and a two-byte `7E7E` buffer: both return `out_of_memory`, required size `3`; original buffer becomes `1B5B`, V remains `7E7E`. This is an observable C API difference even though the reported result and required size match.

**T09 — OSC 9 converts a present invalid progress value to zero. Classification: behavior drift.**

- Original: [`src/terminal/osc/parsers/osc9.zig:160`](/Users/alex/code/3rd/ghostty/src/terminal/osc/parsers/osc9.zig:160) initially defaults set-state progress to zero, but the present-value parse at [`osc9.zig:193`](/Users/alex/code/3rd/ghostty/src/terminal/osc/parsers/osc9.zig:193) explicitly assigns null on parse failure.
- V: [`osc/osc9.v:192`](/Users/alex/code/witty/osc/osc9.v:192) leaves an invalid parsed value absent, then [`osc9.v:207`](/Users/alex/code/witty/osc/osc9.v:207) restores zero for every absent set-state result.
- Inputs `9;4;1;` and `9;4;1;bad` therefore have absent progress in the original and zero in V. The V probe prints `Option(0)` for both; the absent-value source branch is directly reviewed. Plain `9;4;1` defaults to zero in both. The source's existing tests cover default and valid progress values, leaving this distinction uncovered.

**T10 — The Windows native keycode column is untranslated. Classification: missing translation.**

- Original: [`src/input/keycodes.zig:11`](/Users/alex/code/3rd/ghostty/src/input/keycodes.zig:11) selects raw column 4 for macOS/iOS, 3 for Windows, and 2 for Linux/FreeBSD.
- V: [`input/keycodes.v:654`](/Users/alex/code/witty/input/keycodes.v:654) selects XKB only for Linux/FreeBSD and the Mac table for every other target. Its exported table at [`keycodes.v:261`](/Users/alex/code/witty/input/keycodes.v:261) is Mac-specific; no Windows-column counterpart appears in the implementation.
- Consequence: the source component's Windows keycode behavior is not preserved. This is a confirmed absent platform branch, not a claim that the full original application supports Windows. No Windows build/run was performed.

**T11 — Page storage/pooling is a replacement, with caller-backed APIs absent. Classification: representation/runtime boundary / missing translation.**

- Original: [`src/terminal/page.zig:95`](/Users/alex/code/3rd/ghostty/src/terminal/page.zig:95) stores rows, cells, allocators, maps, and sets in one relocatable aligned mapping. [`page.zig:167`](/Users/alex/code/3rd/ghostty/src/terminal/page.zig:167) creates it with mmap; `initBuf` at [`page.zig:191`](/Users/alex/code/3rd/ghostty/src/terminal/page.zig:191) and `cloneBuf` at [`page.zig:596`](/Users/alex/code/3rd/ghostty/src/terminal/page.zig:596) operate on caller-supplied backing memory. PageList [`src/terminal/PageList.zig:73`](/Users/alex/code/3rd/ghostty/src/terminal/PageList.zig:73) provides node/page/pin pools, and [`PageList.zig:3400`](/Users/alex/code/3rd/ghostty/src/terminal/PageList.zig:3400) returns allocations to them.
- V: [`terminal/page.v:1301`](/Users/alex/code/witty/terminal/page.v:1301) uses separately owned row/cell arrays and maps; [`page.v:1346`](/Users/alex/code/witty/terminal/page.v:1346) allocates those objects. There is no executable `init_buf` or `clone_buf`. PageList [`terminal/page_list.v:3749`](/Users/alex/code/witty/terminal/page_list.v:3749) directly allocates a node/page, and [`page_list.v:3764`](/Users/alex/code/witty/terminal/page_list.v:3764) clears it. Numerical layout/backing-size accounting remains, but it does not describe actual contiguous storage.
- Consequence: source caller-backed/relocation/pooling APIs and memory behavior are not translated. Ordinary terminal results can still match; this is a concrete failure of the requested strict source-logic criterion and requires an explicit decision about permissible V runtime adaptations, rather than treating GC cleanup as an accidental stub.

**T12 — Source generic offset-map/refcounted-set contracts are narrowed to concrete implementations. Classification: missing translation / representation boundary.**

- Original: [`src/terminal/hash_map.zig:63`](/Users/alex/code/3rd/ghostty/src/terminal/hash_map.zig:63) supports arbitrary key/value types and hashing/equality context over offset-backed storage. [`src/terminal/ref_counted_set.zig:51`](/Users/alex/code/3rd/ghostty/src/terminal/ref_counted_set.zig:51) accepts item/ID/refcount/context types and optional deletion callbacks.
- V: [`terminal/hash_map.v:328`](/Users/alex/code/witty/terminal/hash_map.v:328) retains a heap map pointer and [`hash_map.v:475`](/Users/alex/code/witty/terminal/hash_map.v:475) uses `u64` keys and values. [`terminal/ref_counted_set.v:78`](/Users/alex/code/witty/terminal/ref_counted_set.v:78) stores only `CellStyle` with `u16` IDs/refcounts; hyperlinks have a separate specialization. Live Page grapheme/hyperlink maps at [`terminal/page.v:1331`](/Users/alex/code/witty/terminal/page.v:1331) use V maps instead of the original offset-map implementation.
- Consequence: generic/custom-context, callback, and relocatable-buffer behavior cannot be exercised through source-equivalent APIs. Some algorithms and current concrete consumers are present and tested; their existence does not establish translation of the original generic implementation.

**T13 — OSC payload allocations ignore the supplied allocator and its failure fallback. Classification: missing translation / representation boundary.**

- Original: [`src/terminal/c/osc.zig:15`](/Users/alex/code/3rd/ghostty/src/terminal/c/osc.zig:15) uses the selected C allocator for both parser creation and parser initialization. [`src/terminal/osc.zig:439`](/Users/alex/code/3rd/ghostty/src/terminal/osc.zig:439) attempts allocating-writer capacity 2048 through that allocator and falls back to the fixed writer on failure. Writer-growth failures invalidate parsing.
- V: [`terminal_c/terminal_c.v:302`](/Users/alex/code/witty/terminal_c/terminal_c.v:302) preserves the custom allocator for the parser object but initializes `osc.Parser` with a sentinel pointer. [`osc/osc.v:522`](/Users/alex/code/witty/osc/osc.v:522) retains only a boolean allocator-present flag. [`osc.v:579`](/Users/alex/code/witty/osc/osc.v:579) selects allocating mode without allocation/failure logic, and [`osc.v:872`](/Users/alex/code/witty/osc/osc.v:872) grows a GC-managed array.
- Consequence: allocator limits and failures supplied by an embedding caller cannot govern OSC payload/result allocations as they do in the original. The allocation-free fixed-buffer capability flag remains, but custom allocator behavior does not. This was verified statically; a failing custom-allocator runtime fixture was not run.

**T14 — Tmux notification matching is replaced and narrows one capture grammar. Classification: algorithm replacement / behavior drift.**

- Original: [`src/terminal/tmux/control.zig:247`](/Users/alex/code/3rd/ghostty/src/terminal/tmux/control.zig:247) uses UTF-8 Oniguruma and the layout-change expression `^%layout-change @([0-9]+) (.+) (.+) (.*)$`.
- V: [`tmux/control.v:376`](/Users/alex/code/witty/tmux/control.v:376) uses V's `regex` engine and `^%layout-change @(\d+) (\S+) (\S+) (.*)$`.
- Consequence: source matching logic is not translated, and layout fields cannot contain whitespace under the V grammar. For `%layout-change @1 a b c d`, the source expression's greedy captures are layout `a b`, visible layout `c`, flags `d`; V captures layout `a`, visible layout `b`, flags `c d`. This fixture is outside ordinary valid layout strings, but directly demonstrates a parser difference. No native Oniguruma execution was performed for this finding; expression semantics and executable capture use were reviewed.

### Faithful source no-ops and adaptations not counted as accidental stubs

Ghostty itself intentionally supplies [`src/input/KeymapNoop.zig:18`](/Users/alex/code/3rd/ghostty/src/input/KeymapNoop.zig:18) with empty deinit/reload and an empty translation outside macOS. [`input/keymap_default.c.v:21`](/Users/alex/code/witty/input/keymap_default.c.v:21) preserves this behavior. Empty methods here are a **faithful source stub**, not an omitted keymap translation. Original parser branches that ignore unknown CSI/DCS operations and source unsupported C conversions were likewise not classified as missing translation solely from empty bodies or comments. V GC cleanup was distinguished from missing functional branches, while concrete lost allocator, contiguous-memory, and public generic contracts are documented above.

### Verification

All V tests below explicitly set `VEXE=/Users/alex/.cache/v/v1-fallback/0.5.2/v` and invoke that same executable. This environment assignment matters because the test runner otherwise selected the unrelated active V checkout. Earlier runs through that other compiler had compilation errors; the pinned results supersede those as verification evidence.

| Command (following the pinned `VEXE` assignment) | Result |
| --- | --- |
| `/Users/alex/.cache/v/v1-fallback/0.5.2/v test terminal` | 42/42 pass; 641,340 ms wall time, including 559,001 ms for PageList |
| `/Users/alex/.cache/v/v1-fallback/0.5.2/v test input` | 11/11 pass; 45,620 ms |
| `/Users/alex/.cache/v/v1-fallback/0.5.2/v test datastruct` | 12/12 pass; 11,366 ms |
| `/Users/alex/.cache/v/v1-fallback/0.5.2/v test osc` | 14/14 pass; 17,911 ms |
| `/Users/alex/.cache/v/v1-fallback/0.5.2/v test search` | 7/7 pass; 206,183 ms |

Native differential probes use Zig 0.15.2, with `/private/tmp/witty-zig-reference/zig-aarch64-macos-0.15.2/zig run -target aarch64-macos.14.0 -lc <probe.zig>`. The actual-source probes import unchanged production files through an audit-directory symlink to Ghostty. `terminal_c_source_probe.zig`, `terminal_key_source_probe.zig`, and `terminal_file_source_probe.zig` confirm T06/T07/T08, T04, and T01 respectively. `terminal_reader_writer_probe.zig` verifies the exact standard-library limit/write operations. Initial native attempts without the explicit macOS target failed system linking; the explicit-target runs succeeded.

V probes use `VEXE=<pinned> <pinned> -path '/Users/alex/code/witty|@vlib|@vmodules' run <probe.v>`. `terminal_codepoint_probe.v`, `terminal_utf8_probe.v`, `terminal_file_probe.v`, and `terminal_osc_probe.v` confirm the V behaviors in T01/T04/T06/T07/T08/T09. Native/V probe files and captured outputs are in `/tmp/witty-ultra-audit/`. Owned file fixtures were removed after their probes. These focused results establish the stated differences; passing unit tests are not a complete differential proof for the translated terminal.


## Runtime, subprocess, configuration, CLI, and operating system sources

This slice compares current executable code with Ghostty commit `6c0e02d`. It covers 176 original files, including all 26 originals of at least 500 physical lines in the assigned scope. The inventories below record every source, its concrete consolidated/split counterparts, physical line count, review level, and result. All 26 large files received direct targeted source/counterpart review; none is marked inventory-only. Targeted review means the paths and branches described below were examined, not that every branch or native ABI is certified equivalent.

### R01 — High — The Windows PTY and terminal I/O path is untranslated

**Classification:** missing translation of an implemented platform branch.

Ghostty selects a distinct Windows PTY implementation with HANDLE descriptors, input/output pipe pairs, a pseudo-console, and a process-wide pipe-name counter (`src/pty.zig:254–421`). Its terminal backend selects the Windows reader (`src/termio/Exec.zig:138–142`), calls `ReadFile`, distinguishes `OPERATION_ABORTED`, and checks the quit pipe with `PeekNamedPipe` (`:1344–1386`). Shutdown calls `CancelIoEx` before joining the blocking reader (`:216–224`). Subprocess creation supplies the pseudo-console and omits POSIX standard descriptors and pre-exec handling (`:1011–1015`); it returns the Windows input/output handles (`:1052–1056`).

Witty has a single POSIX `Pty` with `int` master/slave descriptors and unconditional `openpty` (`pty/pty.v:94–116`). The reader is always `thread_main_posix` (`termio/exec.v:217`, implementation `:1136–1249`). Shutdown writes a POSIX quit pipe and joins without Windows cancellation (`:267–284`). Subprocess creation always uses `p.slave` and the POSIX pre-exec callback (`:896–907`) and returns `p.master` for both streams (`:931–934`). There is no corresponding ConPTY implementation or reader/cancellation branch.

`command/command.v:630` does contain Windows command creation, so this is not a claim that every Windows command primitive is absent. The missing PTY and terminal backend wiring prevents that primitive from reproducing Ghostty's Windows terminal execution. Translate the source Windows PTY, descriptor types, reader, cancellation, and subprocess pseudo-console branch together. Native Windows execution was not available for validation.

### R02 — Medium — C configuration lookup changes the nullable-string contract

**Classification:** behavior drift at a C API boundary; reproduced.

Ghostty treats `?[:0]const u8` specially: it writes a nullable C string pointer, including `null`, and returns success (`src/config/c_get.zig:28–33`, `:102`). Only other optional types with no value return false (`:55–59`). The exported `ghostty_config_get` delegates to this projection (`src/config/CApi.zig:94–105`).

Witty's special `class` branch returns false before writing when the field is unset (`configpkg/c_api.v:93–95`); its generic `?string` branch likewise returns false without updating the output pointer (`:106–112`). A caller cannot distinguish a supported nullable field from an unsupported key and may retain a stale pointer. With output initialized to `0x1234`, a direct pinned-V probe printed `success=false output=4660` for unset `class`, `title`, and `window-title-font-family`. Source behavior for each is success with a null pointer. Restore the source special case for nullable C strings while preserving false for unset optional scalar/enum values.

The source `Key` enum explicitly excludes fields beginning with `_` (`src/config/key.zig:12–15`); Witty filtering `_xdg-terminal-exec` is therefore faithful and is not an omission.

### R03 — Medium — A failed command-finished notification now aborts mailbox processing

**Classification:** behavior drift in an error boundary; reproduced.

When a command finishes, Ghostty clears its timer, reports `.command_finished`, and catches a runtime notification failure to log a warning (`src/Surface.zig:1118–1135`). Witty clears the timer and propagates the same runtime failure with `!` (`core/surface.v:2563–2574`). `surface_message` propagates it (`core/app.v:798–802`) and the mailbox drain propagates again (`:509–510`), ending that tick's drain early.

A direct probe using a runtime callback that returns `error('notification callback failed')` printed `stop-command propagated: notification callback failed`. This notification is best effort in the original; failure in the port interrupts processing of later queued work. Translate the source catch-and-warn behavior. The probe establishes the V error path; the original catch boundary was verified directly from source.

### R04 — Medium — SSH cache persistence replaces the source atomic-write algorithm

**Classification:** algorithm replacement and filesystem behavior drift.

Ghostty opens/creates the cache with mode `0600` at creation (`src/cli/ssh-cache/DiskCache.zig:79–94`). Its writer opens the existing cache directory and uses `dir.atomicFile` with mode `0600`, a write buffer, cleanup, and `finish` (`:209–234`).

Witty creates a file with `os.create` and only then calls `chmod` (`cli/ssh_cache.v:156–166`). The writer invents a fixed `${cache.path}.tmp-${os.getpid()}` filename, builds the complete output string, uses `os.write_file`, applies `chmod` after creation, and renames (`:190–210`). The unique/exclusive temporary-file and creation-time permission behavior of the source atomic-file API is lost. Same-process writes share one temporary pathname; preexisting files at that pathname are reused/truncated by the generic write. Until `chmod`, creation permissions depend on the process umask rather than the requested source mode.

There is also a bounded-read change: Ghostty reads through a 512 KiB limited reader (`src/cli/ssh-cache/DiskCache.zig:277–281`); Witty checks file size and then performs an unbounded whole-file read (`cli/ssh_cache.v:174–177`). A file that grows between the check and read can exceed the source bound. Restore the source atomic-file and bounded-read contracts rather than treating a later rename and pre-read stat as equivalent. Existing SSH cache tests were run, but no concurrent-write/race test was performed.

### R05 — Medium — The GTK command palette replaces the native source model, filtering, and trigger signal

**Classification:** algorithm replacement and representation/runtime boundary.

Ghostty's blueprint creates `Gtk.ListView`, `Gtk.SingleSelection`, incremental `Gtk.FilterListModel`, a `Gtk.AnyFilter` containing two `Gtk.StringFilter` instances bound to search text, and a `Gio.ListStore` of `GhosttyCommand` objects (`src/apprt/gtk/ui/1.5/command-palette.blp:30–54`). Regular action activation emits the palette's registered `trigger` signal (`src/apprt/gtk/class/command_palette.zig:358–363`).

Witty instantiates an ordinary `AdwDialog` and a `GtkListBox` (`apprt/gtk/command_palette_linux.v:379`, `:400–408`). It stores V command arrays, removes and reconstructs all native rows on each search change, and explicitly selects the first resulting row (`:716–767`). Its own lowercase/substring loop substitutes for the source native filter model (`:827–846`). `emit_trigger` directly invokes the owning window (`:707–713`); it does not register/emit the original palette signal. These are executable replacements, not just a different syntax for the source algorithms. Native list/filter lifecycle, class identity, signal consumers, and any semantics supplied by the GTK string filters require preservation or explicit acceptance as a separate change. This audit does not claim every search input visibly differs.

The search placeholder independently loses translation: the source uses `_("Execute a command…")` (`src/apprt/gtk/ui/1.5/command-palette.blp:17`), whereas Witty passes a fixed English C string (`apprt/gtk/command_palette_linux.v:395`). Restore that gettext path even if the UI representation changes.

### R06 — Medium — GTK global shortcut IDs no longer have source map replacement semantics

**Classification:** behavior drift from a container replacement; source-backed counterexample.

Ghostty stores translated shortcut IDs in `StringArrayHashMapUnmanaged` and calls `put`, replacing any existing action for the same translated ID (`src/apprt/gtk/class/global_shortcuts.zig:68`, `:201–205`). Its portal payload iterates the resulting unique map (`:252–274`) and activation uses `map.get` (`:558`). Witty appends every result to a V array (`apprt/gtk/global_shortcuts_linux.v:434`), sends every array element (`:553`), and chooses the first matching ID (`:880–886`).

Different original triggers can serialize to the same portal ID: physical `key_a` and Unicode `a` both use the GDK name `a` with equal modifiers (`src/apprt/gtk/key.zig:60–77`, physical mapping `:393`; V `apprt/gtk/key_linux.v:394–409`, mapping `:176`). The source map retains one action (the later `put`), while the V array retains duplicate IDs and activation selects the first. This changes both portal registration data and action selection. Preserve the source replacement rule on the translated ID. Linux GTK/portal runtime execution was not available for a live probe.

### R07 — Medium — Locale canonicalization and gettext loading use replacement logic

**Classification:** algorithm replacement and omitted feature-selection branch.

Ghostty's `canonicalizeLocale` first preserves input unchanged when i18n is disabled (`src/os/i18n.zig:92–97`). When enabled it applies the exact three-part Chinese locale fix (`:127–146`) and otherwise calls the bundled libintl/gnulib `_libintl_locale_name_canonicalize` implementation (`:105–121`). Its gettext operations are selected by `build_config.i18n` and linked external functions (`:28–66`, `:165–172`).

Witty uses a newly written split/replace routine, including its own two-part Chinese handling, and never calls or translates the source libintl canonicalizer (`internal_os/i18n.v:170–186`). It dynamically searches a list of libintl/libc names and symbols (`:200–239`), silently returning from initialization when discovery fails (`:72`, `:116`). There is no corresponding disabled-i18n canonicalization branch: for example that original configuration preserves `zh-Hans`, while the V routine produces `zh_CN` regardless of feature configuration.

The probe's common inputs (`zh-Hans`, `zh-Hant`, `de-DE`, and `en_US.UTF-8`) are consistent with the enabled Darwin source tests (`src/os/i18n.zig:174–193`); they do not establish equivalence to the complete gnulib routine. Translate/call the same canonicalizer and preserve the source feature choice. Runtime `static_locale` validation replacing Zig comptime validation is a language boundary, not an untranslated production parser.

### R08 — Medium — GTK stylesheet variants and part of the resource pipeline are missing

**Classification:** missing translation of resources/build logic.

Ghostty registers its versioned blueprint resources and all four stylesheets (`src/apprt/gtk/build/gresource.zig:35–65`). The blueprint build validates the compiler/version, invokes it, and emits UI resources (`src/apprt/gtk/build/blueprint.zig:39–159`); class templates resolve those resources. Witty has no direct counterpart for either helper. Several small widget files embed expanded XML, while larger widgets construct trees programmatically. An embedded template can be an acceptable representation of a translated blueprint, but it does not by itself translate the original version/resource-selection build behavior.

The concrete missing resource behavior is the dark and high-contrast CSS: source `src/apprt/gtk/css/style-dark.css:1–8` sets transparent background and a dark separator; `style-hc.css:1–3` and `style-hc-dark.css:1–3` also set transparent background. Witty only embeds the regular stylesheet (`apprt/gtk/application_linux.v:174`) and prepends it in `application_runtime_css` (`:1024–1028`). No variant files or corresponding rules were found. In the source, Adwaita loads the variants using the application resource base path (`src/apprt/gtk/class/application.zig:368–371`, `src/apprt/gtk/css/style.css:1–5`). This changes variant styling, especially the separator for the older GTK branch. Translate the missing styles and version/resource selection; do not count comments claiming blueprint translation as executable evidence.

### R09 — Medium — The GTK ImGui base widget drops its source native class and virtual methods

**Classification:** representation/runtime boundary with omitted native contract; not a stub.

Ghostty defines a `GhosttyImguiWidget` GObject subclass of `AdwBin` (`src/apprt/gtk/class/imgui_widget.zig:24–34`) and native `setup`/`render` virtual methods (`:40–49`); its inspector widget extends that type. Witty creates an ordinary `AdwBin`, directly attaches the GLArea, and stores V setup/render callbacks (`apprt/gtk/imgui_widget_linux.v:38–57`). Native class registration and the source virtual-method contract are absent. Its substantial render, input, scaling, and tick logic is implemented, so describing this whole file as a stub would be false. However, a caller inspecting/extending the native source class cannot get the source class identity or override contract. Retain a registered translated native class and its virtual dispatch or document/approve this as a separate runtime change. No GTK native type/override probe was possible on the macOS host.

### Faithful source stubs and adaptations that were checked

- `RepeatableLink.parseCLI` returns `error.NotImplemented` in Ghostty (`src/config/Config.zig:8091–8100`); Witty returns `error('not implemented')` (`configpkg/configpkg.v:5918–5927`). This is an inherited source stub, not a new missing translator implementation.
- The none runtime's false IPC response and empty Surface, and the browser runtime's empty App/Window, are already present in `src/apprt/none.zig:1–19` and `src/apprt/browser.zig:1–4`. Their V counterparts preserve those source placeholders.
- Windows termios polling is itself explicitly unreachable/TODO in Ghostty (`src/termio/Exec.zig:325–330`); Witty's corresponding arm (`termio/exec.v:348–350`) is faithful. It does not explain away R01's implemented Windows PTY and reader.
- The OSC special/dynamic color branches described as unimplemented in Ghostty's stream handler (`src/termio/stream_handler.zig:1243–1247`, `:1307–1311`, `:1331`, `:1354`, `:1361`) have the same incomplete handling in `termio/stream_handler.v:1454`, `:1473`, `:1490`, `:1521`, `:1546`, `:1566`, `:1601`. These are inherited omissions.
- GTK's optional-action fallback already rejects the listed secure-input/visibility/inspector/undo/etc. actions (`src/apprt/gtk/class/application.zig:743–759`; `apprt/gtk/application_linux.v:2203–2205`). X11 quick-terminal unsupported behavior and Wayland's empty resize/add-subprocess-environment implementations also exist in the source.
- Arena freeing and some empty `deinit` functions are GC/language adaptations. They were not classified as stubs merely for being empty. General Zig reflection to explicit V/C GObject registration was inspected separately from whether the registered properties/signals and native contracts remain present.

### Direct coverage of originals of at least 500 lines

| Original | Lines | Main counterpart(s) | Targeted review and limits |
|---|---:|---|---|
| `src/App.zig` | 613 | `core/app.v` | Surface lookup, mailbox dispatch, app lifecycle/key entry points; R03 consequence traced. |
| `src/Command.zig` | 717 | `command/command.v` | POSIX descriptor/cwd/pre-exec/fork/exec/wait and Windows CreateProcess branch; Windows not executed. |
| `src/Surface.zig` | 6781 | `core/surface.v` | Derived config/init, message dispatch, keys/mouse, command timing/error boundary; R03. |
| `src/apprt/action.zig` | 918 | `apprt/action.v`, `apprt/c_api.v` | Action tags, payload types, enum/native projections; full external ABI remains unverified. |
| `src/apprt/embedded.zig` | 2207 | `apprt/embedded.v`, `apprt/c_api.v`, `core/embedded_bridge.v` | Callback routing, key translation, config/title updates, scale/resize, clipboard, inspector and C selection helpers; iOS/native ABI not executed. |
| `src/apprt/gtk/class/application.zig` | 2836 | `apprt/gtk/application_linux.v` | Registration/lifecycle, config/CSS/action routing, accelerator helpers and optional source omissions; GTK not executed. |
| `src/apprt/gtk/class/command_palette.zig` | 790 | `apprt/gtk/command_palette_linux.v` | Command payload/property/sorting/filter/model/action path; R05. |
| `src/apprt/gtk/class/global_shortcuts.zig` | 633 | `apprt/gtk/global_shortcuts_linux.v` | Refresh/map, session payload/subscription/response and activation; R06. |
| `src/apprt/gtk/class/imgui_widget.zig` | 541 | `apprt/gtk/imgui_widget_linux.v` | Native type boundary, GL context/realize/render/frame/input callbacks; R09. |
| `src/apprt/gtk/class/split_tree.zig` | 1241 | `apprt/gtk/split_tree_class_linux.v` | Tree get/set, resize/goto, equalize/zoom, close confirmation, signal connection, rebuild and paned ratio path. |
| `src/apprt/gtk/class/surface.zig` | 4025 | `apprt/gtk/surface_class_linux.v` | Native registration/properties, surface init/config/key/mouse callbacks, lifecycle/actions and rebuilt layout boundary. |
| `src/apprt/gtk/class/tab.zig` | 506 | `apprt/gtk/tab_linux.v` | Native properties, close modes, bell/attention, navigation and computed-title precedence/prefixes. |
| `src/apprt/gtk/class/window.zig` | 2024 | `apprt/gtk/window_linux.v` | Native properties/lifecycle, tab/surface selection, actions and programmatic layout boundary. |
| `src/apprt/gtk/key.zig` | 535 | `apprt/gtk/key_linux.v` | Modifier/physical/unicode mapping and shortcut/label formatting; media TODO inherited. |
| `src/apprt/gtk/winproto/wayland.zig` | 524 | `apprt/gtk/winproto_wayland_linux.v`, `wayland_shims.h` | Registry/init and quick-terminal configure/sync; native compositor not executed. |
| `src/apprt/gtk/winproto/x11.zig` | 527 | `apprt/gtk/winproto_x11_linux.v`, `x11_shims.h` | Init/event/modifier and surface protocol paths; native X11 not executed. |
| `src/cli/args.zig` | 1627 | `cli_args/cli_args.v` | Reflection/struct/union parser paths, argument iterators and error routing; allocator differences treated separately. |
| `src/cli/list_themes.zig` | 1741 | `cli/list_themes.v`, `list_themes_window.v`, `list_themes_preview_window.v` | Listing/location priority, preview filter/update and split window modules; live TUI not executed. |
| `src/cli/ssh-cache/DiskCache.zig` | 548 | `cli/ssh_cache.v` | Entry collection, locking, expiry, persistence, bounds; R04. |
| `src/config/Config.zig` | 10411 | `configpkg/configpkg.v` | Root field inventory, defaults/finalization/load/replay helpers and parsers, inherited Link stub; 203 root fields mapped after internal/escaped names accounted for. |
| `src/os/flatpak.zig` | 507 | `internal_os/flatpak.v`, `flatpak_linux.c.v` | Host spawn, state transitions, wait/wait-xev/signal; live host D-Bus not executed. |
| `src/termio/Exec.zig` | 1739 | `termio/exec.v` | Spawn/reader/shutdown/termios/writes, POSIX correspondence and missing Windows branch; R01. |
| `src/termio/Termio.zig` | 769 | `termio/termio.v` | Init/config/resize/stream/backend/output paths in consolidated module. |
| `src/termio/Thread.zig` | 531 | `termio/termio.v` | Thread lifecycle, callback/async/timer and mailbox paths consolidated. |
| `src/termio/shell_integration.zig` | 1006 | `termio/shell_integration.v` | Setup/detection/env/argument handling for bash, fish, zsh, elvish and nushell; original includes many test lines. |
| `src/termio/stream_handler.zig` | 1551 | `termio/stream_handler.v` | Handler dispatch, fallible paths, OSC/source stubs and terminal callbacks; terminal algorithms reviewed by separate audit slice. |

### Verification and remaining uncertainty

The repository's default `/Users/alex/code/v/v` failed a first termio test attempt during compile/type checking, including config enum-match errors; no termio runtime test ran from that attempt. Per the verified project toolchain, tests/probes were rerun with `VEXE=/Users/alex/.cache/v/v1-fallback/0.5.2/v` and that explicit compiler path:

- `.../v -gc boehm test termio`: **4/4 test files passed** (`termio_tests.log`).
- `.../v -gc boehm test configpkg`: **3/3 test files passed** (`configpkg_tests.log`).
- `.../v -gc boehm -path '/Users/alex/code/witty|@vlib|@vmodules' run /tmp/witty-ultra-audit/config_probe.v`: succeeded and reproduced R02 (`config_probe.log`).
- The same pinned run of `surface_probe.v`: succeeded and reproduced R03; its locale outputs agree with the common enabled-Darwin source test cases (`surface_probe.log`).
- `.../v -gc boehm test cli/ssh_cache_test.v`: **1/1 test file passed** (`ssh_cache_tests.log`).

These tests cover V behavior, not differential equivalence of entire modules. The macOS host cannot validate Linux GTK/Wayland/X11/portal/Flatpak runtime branches, Windows ConPTY, iOS, or browser Wasm integration. Generic reflection/GC adaptations, all platform ABIs, and every branch in the two very large Config/Surface sources remain outside full branch-by-branch certification. Smaller inventory-only entries are mapped, not verified. `os/wasm/log.zig` and `os/wasm/target.zig` have no identified direct counterparts and remain explicitly unverified; do not interpret their inventory records as a reviewed successful translation. Documentation and fixture inventory entries are not executable omissions.

No production source files were modified by this audit slice. The confirmed gaps, drift, and replacements mean the requested strict source-fidelity condition is not satisfied.


## Renderer, fonts, sprites, OpenType, and inspector audit

Reference: `/Users/alex/code/3rd/ghostty`, commit `6c0e02d11`. Port: `/Users/alex/code/witty`, current working tree. This pass inspected the original implementation and the current V implementation directly; earlier audit statements were not treated as evidence. Production files were not edited.

The source-fidelity requirement is **not met** in this scope. The most serious issues are disconnected font backend translations, removal of the shared font-grid lock during HarfBuzz shaping, and replacement of linked custom-shader compilers with external executable workflows. Some source algorithms are implemented through replacement workflows even where ordinary outputs may agree.

### RF-01 — High: backend selection is declared but not applied to production fonts

**Classification:** missing translation / backend replacement.

Ghostty `src/font/backend.zig:33-46` selects CoreText by default on Darwin. `src/font/face.zig:12-24` selects the face implementation from the backend, and `src/font/shape.zig:20-35` selects HarfBuzz, CoreText, no-shape, or WebCanvas shaping accordingly. Native CoreText shaping and rasterization are therefore the normal macOS implementation.

V `font/backend.v:40-50` reports corresponding backend values, but `font/face.v:977-999` defines the production `Face` concretely with a FreeType face and HarfBuzz font. `Face.init_file` and `Face.init_mem` always initialize those (`font/face.v:1002-1040`); the extra CoreText object is auxiliary and optional. Deferred CoreText faces explicitly become FreeType faces (`font/face.v:875-876`). `renderer/renderer.v:906`, `renderer/renderer_darwin.c.v:16`, and `renderer/renderer_linux.c.v:13` use the separate always-HarfBuzz `font.Shaper` from `font/font.v:1383-1497`.

The translated `font/shaper/coretext_darwin.c.v`, `harfbuzz.v`, `noop.v`, and `web_canvas.v` are not the production selector's implementations. Their initialization references are their own tests/exports; the renderer never selects them. Native `CoreTextFace.render_glyph` also exists separately from production `Face.render_glyph`. Consequently, translating these files does not restore Ghostty's default macOS font behavior or its alternate-backend configuration. Normal macOS output, native metrics/rasterization, no-shape behavior, and browser backend behavior cannot be certified from their presence.

### RF-02 — High: HarfBuzz shaping omits Ghostty's grid lock

**Classification:** behavior drift; shared-state synchronization omitted.

Ghostty `src/font/shaper/harfbuzz.zig:135-148` takes an exclusive `run.grid.lock` before collection lookup and holds it during native shaping. The comment explicitly identifies face lookup and FreeType's lack of thread safety as the reason. V's live shaper performs `collection.get_face` without that lock (`font/font.v:1444-1451`), then locks only the individual face's `ft_mutex`. The translated `HbShaper` has the same omission (`font/shaper/harfbuzz.v:156-169`) and uses its remembered iterator grid rather than `run.grid`.

V's collection can load/replace a deferred entry in `font/collection.v:930-975`; grid lookup and rasterization use `SharedGrid.lock` (`font/shared_grid.v:203-240`, `312-366`). `SharedGridSet.ref` returns the same grid to matching references (`font/shared_grid_set.v:85-105`). A face mutex acquired after collection lookup does not protect collection/discovery/cache mutation against another surface. The upstream synchronization guarantee is missing. This finding is from direct lock/call-path inspection; a race stress test was not executed.

### RF-04 — Medium: the live shaper substitutes HarfBuzz's parser for Ghostty's feature parser

**Classification:** algorithm replacement / behavior drift.

Ghostty `src/font/shaper/harfbuzz.zig:64-86` uses `FeatureList.appendFromString`, whose parser accepts comma-separated features and intentionally tolerant unambiguous syntax (`src/font/shaper/feature.zig:27-175`, `241-254`). The separate translated `HbShaper` uses the corresponding V `FeatureList`; the renderer's live `font.Shaper` does not. `font/font.v:1398-1406` calls `harfbuzz.Feature.from_string` once for each complete configuration string and silently skips failures.

A native probe of the same linked HarfBuzz library (`/opt/homebrew/lib/libharfbuzz.dylib`) returned false for both `-liga,+dlig` and `kern==1`, and true for `-liga` / `+dlig` separately. Ghostty's comma-consuming parser reads the former as two settings and its `.space` state allows repeated `=` before the integer. Thus accepted Ghostty configuration can be silently ignored by the live port. This is independent of whether the translated parser's own tests pass.

### RF-05 — High: custom-shader compilation is a replacement subprocess workflow

**Classification:** algorithm replacement / runtime boundary / untranslated error contract.

Ghostty `src/renderer/shadertoy.zig:152-210` calls linked glslang shader/program APIs, captures the shader/program info/debug logs (`:213-234`), and calls linked SPIRV-Cross with a context/error callback and compiler options (`:238-342`). V `renderer/shadertoy.v:78-177` instead writes temporary files, finds executables on PATH, spawns `glslangValidator` and `spirv-cross`, polls/drains their output, and reads their output files. V's `SpirvLog` is only a data/deinit type and is not populated by shader/program failures. Ghostty also initializes linked glslang during process setup (`src/global.zig:166–167`); V setup proceeds directly from locale to Oniguruma (`global_state/global_state.v:338–351`), consistent with the replaced subprocess path.

The Vulkan 1.2, GLSL 430, and Metal decoration-binding intent is retained in command arguments; the implementation and dependency contract are nevertheless replaced. `command -v glslangValidator spirv-cross` returned exit 1 with neither executable on the audit machine's PATH. The corresponding V lookup explicitly errors when absent (`renderer/shadertoy.v:145-148`), so configured custom shaders cannot use this workflow here. The source ships linked dependencies instead of requiring those executables. This is separate from any audit of built-in Metal shader packaging.

The source's bounded `readToEndAlloc(..., 4 MiB)` (`src/renderer/shadertoy.zig:91-98`) also becomes an unbounded `os.read_file` followed by a length check (`renderer/shadertoy.v:56-60`); the nominal limit is preserved after reading, not while reading.

### RF-06 — Medium: macOS glass background-alpha branch is missing

**Classification:** missing translation / visible behavior drift.

Ghostty `src/renderer/generic.zig:1351-1368` first derives the background alpha from opacity, then forces alpha to zero on macOS for `macos-glass-regular` and `macos-glass-clear`, because the glass effect handles the background. V `renderer/renderer.v:1254-1261` always uses `background_opacity_alpha` without the glass branch. `background_blur` is retained in `renderer/config.v:93`, `:180`, so the configuration field's existence does not restore the rendering behavior. A nonzero terminal-background alpha is drawn over the material where Ghostty removes it. Native visual confirmation was not performed; the separately validated font and inspector tests do not render this material.

### RF-07 — Medium: row rendering replaces the source's lazy shaping algorithm

**Classification:** algorithm replacement; ordinary-pixel equivalence unproven.

Ghostty `src/renderer/generic.zig:2608-2720` keeps a current run and shaper-cell position and explicitly catches them up after a preedit range. It shapes runs lazily as cells are emitted (`:2924-3011`), skips invisible foreground cells before this work (`:2870-2877`), and asserts monotonic glyph positions. V `renderer/renderer.v:2174-2219` eagerly shapes every run, stores glyphs in a freshly allocated per-cell array of arrays, and later skips preedit/invisible cells (`:2240-2253`, `:2302-2305`). It does not translate the run catch-up or monotonic-position checks.

This can preserve normal raster output, but changes allocation, lookup/shaping/cache side effects, and when shaping failures interrupt row construction. A run covered by preedit can now be shaped and cached before any emission decision. The user required original logic rather than a newly organized rendering algorithm; pixel tests alone would not establish that requirement.

### RF-08 — Medium: live PageList inspector omits source diagnostics and bypasses translated page widgets

**Classification:** missing translation / disconnected counterpart / UI behavior drift.

Ghostty `src/inspector/widgets/pagelist.zig:284-343` displays five tracked-pin columns: index, raw pin coordinates, screen context, dirty state, and classification with distinct `active top`, `viewport top`, `garbage`, `viewport pin`, and `tracked` branches. V `inspector/pagelist.v:373-405` replaces this with three columns and only `live`/`garbage`; raw coordinates, dirty status, and special pin-state branches are absent.

Ghostty's page list invokes `widgets.page.treeNode` and `widgets.page.inspector` (`src/inspector/widgets/pagelist.zig:70-79`). V has faithful-looking translated entry points in `inspector/page.v:18-52`, including the dirty-page indicator, but the live page list builds a different string label and calls its own duplicated `draw_page_inspector` (`inspector/pagelist.v:279-287`, `435-443`). The source dirty-page header branch (`src/inspector/widgets/page.zig:79-81`) is therefore not reached by that UI, despite being implemented in an unused counterpart (`inspector/page.v:48-50`).

### RF-09 — Low: inspector public detail renderer and debug demo-window logic are absent

**Classification:** missing translation; public/debug surface only.

Ghostty key `Event.render` draws a detailed two-column event view, triggered bindings, UTF-8/PTY read-only input fields, and their helper rendering (`src/inspector/widgets/key.zig:74-229`). V `KeyEvent` has initialization, formatting, and deinitialization (`inspector/inspector.v:29-107`), but no corresponding detail renderer or input-field helpers. The source stream currently does not call `Event.render`, so this is an untranslated public widget, not evidence that a currently displayed source popup disappears.

Ghostty's surface widget has `show_demo_window` and calls `ImGui_ShowDemoWindow` in Debug (`src/inspector/widgets/surface.zig:28`, `:37`, `:134-140`). V's inspector render (`inspector/inspector.v:245-282`) has no corresponding state or call. This removes an explicit upstream debug UI behavior.

### RF-10 — Low: optional constraint representation changes accepted inputs

**Classification:** representation boundary / behavior drift.

Ghostty constraint `max_xy_ratio` is `?f64` (`src/font/face.zig:172`), and its scale-factor branch runs for any non-null value (`:401-405`). V changes it to plain `f64`, declares zero as no limit (`font/font.v:1270-1272`), and only applies it when greater than zero (`font/face.v:1988-1994`). An explicitly supplied source ratio of zero collapses positive width; the same V value disables the limit. Negative non-null values also follow different branches. The retained Nerd Font table supplies positive ratios, so this is a public representation discrepancy, not a demonstrated normal icon-rendering failure.

Related narrow-width fields (`?u2` / `u2`) become zero-sentinel `u32` fields (`font/font.v:1235-1244`) and a `u8` maximum (`:1274`). Ordinary source call sites supply widths 1/2; the type-level input constraints are not retained.

### RF-11 — Low: source invariant failure behavior is replaced by recovery or new cases

**Classification:** behavior drift / defensive algorithm additions.

* Ghostty atlas dumping panics for unsupported formats (`src/font/Atlas.zig:392-398`); V returns a recoverable error for BGRA (`font/font.v:1203-1208`).
* Ghostty sprite rendering checks unsupported codepoints and traps in runtime-safety builds (`src/font/sprite/Face.zig:181-185`), then has a blank fallback in builds without those checks. V always returns an empty `RenderedGlyph` (`sprite/face.v:411-414`). This is a safety-build difference; its non-safety fallback is source-backed.
* Ghostty's FreeType bitmap transfer asserts positive dimensions and positive dense pitch (`src/font/face/freetype.zig:747-756`). V adds empty/null success, non-dense recoverable errors, and a negative-pitch vertical-flip algorithm (`font/face.v:1538-1566`). These are additional behaviors, not a literal translation of those source assumptions. No negative-pitch failing font fixture was found/executed.

### RF-12 — Low: inspector formatting and filter/metadata code use replacement representations

**Classification:** representation/runtime boundary; diagnostic behavior differs.

Ghostty's key table uses fixed 128-byte UTF-8 and 256-byte PTY/binding writers and stops formatting at capacity (`src/inspector/widgets/key.zig:404-459`). V's `utf8_table_codepoints`, `pty_text`, and binding join produce dynamically allocated unbounded strings (`inspector/inspector.v:89-107`, `:490-507`, `:662-672`). Long input displays and allocation behavior differ even where the short formatting agrees.

Ghostty encodes OSC metadata through type/field reflection (`src/inspector/widgets/termio.zig:566-708`); struct values become type names (`:680-683`). V replaces this with an explicit manual command switch (`inspector/termio.v:254-323`); for example, color `requests` and Kitty color `list` metadata become lengths (`:274-281`) where the corresponding upstream values are struct lists and are formatted as type names. It also replaces `ImGuiTextFilter` with a V parser (`inspector/termio.v:371-394`). Common comma/negative/ASCII matching branches were compared with `cimgui/vendor/imgui/imgui.cpp:3051-3105`; whitespace trimming is broader through V `trim_space` than ImGui's blank-character trimming. These are diagnostic/runtime substitutions, not unimplemented parser callbacks. `VTHandler.vt`, `vt_print`, and `deinit` empty bodies are source-backed interface no-ops (`src/inspector/widgets/termio.zig:740-750`).

### Source limitations and faithful adaptations not counted as new port stubs

* `renderer/webgl.v:4` is an empty type, but Ghostty `src/renderer/WebGL.zig:1-2` itself has only a namespace declaration. This is a **faithful source stub**, not evidence of a newly omitted renderer implementation.
* The missing double-diagonal symbols U+1CC1F/U+1CC20 are already documented as unimplemented in Ghostty `src/font/sprite/draw/symbols_for_legacy_computing_supplement.zig:247-251`; corresponding V TODOs are inherited. Existing covered sprite ranges have implemented drawing logic.
* HarfBuzz/noop `end_frame` and noop/CoreText `finalize` no-ops are present in the original; they are not newly inserted placeholders. GC-only deallocation adaptations were not treated as missing logic merely because Zig calls `alloc.free`.
* WebCanvas's native-C unsupported functions (`font/face_web_canvas.c.v:3-17`) are platform guards beside real JS Canvas primitives (`font/face_web_canvas.js.v`); they are not evidence of a missing JS drawing body. Browser execution remains unverified and production backend selection is covered by RF-01. The pinned Ghostty WebCanvas code itself refers to `.rgba` (`src/font/face/web_canvas.zig:202`) while the current source atlas enum is `.bgra` (`src/font/Atlas.zig:54-59`); V's channel-converting BGRA implementation changes that stale source path rather than proving it was directly executable upstream.
* All 10 built-in GLSL files, ShaderToy prefix, and `shaders.metal` are byte-identical to the pinned source. Three upstream ShaderToy test fixtures have no retained same-path counterpart. This does not mean built-in shaders are missing.
* `src/font/nerd_font_codegen.py` (577 lines) and `nerd_font_codepoint_tables.py` (10,449 lines) have no retained generator-workflow counterpart. The latter is input data for the former, not executable renderer code. The generated V constraint lookup is retained and was independently compared below; regenerating it from the original workflow is not provided by those retained files alone.

### Verification and scope limits

The renderer entries in the inventories below include every owned file: 176 records, consisting of 96 primary Zig files, 17 Python/GLSL/Metal source files, and 63 resources. Resource byte comparisons establish retained bytes, not semantic review. All 33 original source files with at least 500 physical lines received direct targeted comparisons or an explicit no-counterpart determination. Smaller files were mapped and scanned for omission/stub candidates; inventory-only records remain unverified. This is a source audit with targeted branch comparisons, **not a proof that every unflagged function or platform is behaviorally identical**. Source tests/comments inflate the physical sizes of several font files substantially.

Large-source comparison focus:

| Original source group | Direct review focus / V counterpart |
| --- | --- |
| `renderer/generic.zig`, `Thread.zig`, `cell.zig`, `image.zig` | Frame updates/critical state, row/cursor/colors/decorations, event timers/mailbox callbacks, cell reset/resize/layer ordering, image lifecycle/conversion/placements/z sorting; `renderer/renderer*.v`, `thread.v`, `cells.v`, `image*.v` |
| `renderer/shaders/shaders.metal` | Full byte comparison against `renderer/shaders.metal` |
| `font/face.zig`, `face/freetype.zig`, `face/coretext.zig`, `face/web_canvas.zig` | Backend wiring, constraints/scaling/alignment, initialization/size/variations/metrics, rasterization and bitmap transfer; `font/face*.v`, `font/font.v`, native/JS primitives |
| `font/Collection.zig`, `SharedGrid.zig`, `SharedGridSet.zig`, `CodepointResolver.zig`, `discovery.zig` | Lazy face ownership/loading, styled/fallback search, grid locks/caches/atlas retry, config keys/refcounts/fallback-face construction, fontconfig/CoreText descriptor matching/scoring and fallback; corresponding `font/*.v` |
| `font/Atlas.zig`, `Metrics.zig`, `opentype/os2.zig` | Skyline reserve/fit/merge/grow/copy; baseline/decorations/modifier clamping; OS/2 version-dependent size and field parsing; `font/font.v`, `opentype/opentype.v` |
| `font/shaper/coretext.zig`, `harfbuzz.zig` | Initialization/features/run hooks, cluster/advance positioning, cached font attribute dictionaries, deferred releases, face lookup/locking; translated shaper files plus the renderer's actual separate shaper |
| `font/sprite/Face.zig`, `canvas.zig`, `draw/box.zig`, `draw/branch.zig`, both large legacy-computing files | Source range dispatch and draw-function coverage, path coordinates/fill/stroke/clipping/inner stroke, tables and geometric branches; `sprite/*.v`, source-pinned z2d 0.10.0 dependency primitives, exact-pixel atlas fixtures |
| `font/nerd_font_attributes.zig` and its two Python generators/input tables | Constraint-arm/range/field equivalence, generation workflow correspondence and lack of retained tools |
| All five large inspector widget files | Tables, navigation/filter/recording actions, typed metadata, detailed key widget, demo/docking paths, tracked-pin classification and actual page-widget caller wiring |

Completed focused checks:

* Built then executed `sprite/face_test.v`, `sprite/z2d_fill_test.v`, `sprite/z2d_stroke_test.v`, and `opentype/opentype_test.v` using `/Users/alex/code/v/v` (`V 0.5.2 0dc6a69`): exit 0. Direct compilation used `-path '@vlib|@vmodules|/Users/alex/code/witty'`, followed by execution of the generated binary. Initial sprite binaries were moved into `/tmp/witty-ultra-audit`; no production artifacts remain from this pass.
* The sprite test's **36 golden-atlas digests** were checked independently against decoded red/grayscale pixels from the actual pinned Ghostty PNGs: 36 matches, zero mismatches. The V rendering test then matched all 36 cases. This provides exact-pixel evidence for those codepoint batches/metrics, not every possible width, metric, special sprite, or clipping option.
* `/tmp/witty-ultra-audit/renderer-nerd-probe.py` parsed the actual original/V lookup arms and compared constraint fields over all source-covered codepoints plus every boundary neighbor: 276 source arms, 276 V arms, 10,458 checked codepoints, zero mismatches.
* A native HarfBuzz feature-string probe confirmed RF-04's rejection/acceptance examples.
* An isolated V `fastmem.copy` slice probe showed the Atlas destination slice does modify its original backing array: `[0, 99, 88, 0]`. Compiler notices about implicit slice clones were **not** promoted into a false Atlas-copy defect.
* Root independently compiled and executed `font/shaper_runtime_test.v` and `inspector/inspector_test.v` with the pinned `/Users/alex/.cache/v/v1-fallback/0.5.2/v`, `VEXE` pointing to that executable, and repository-first `-path '/Users/alex/code/witty|@vlib|@vmodules'`: both completed with exit 0. Authoritative logs are `/tmp/witty-ultra-audit/pinned-font-local-first.log` and `pinned-inspector-local-first.log`. These focused tests do not certify GPU frame rendering, browser/wasm behavior, Linux OpenGL execution, or concurrent shared-grid lookup/shaping.

Earlier direct font/inspector compilation attempts used `/Users/alex/code/v/v` and a standard-library-first module path. They produced enum-reflection typing errors and shadowed the local `macos` module; those compiler/path-dependent errors are **not reported as production failures**. The pinned repository-first runs above supersede those attempts. The earlier raw logs remain in `renderer-font-compile.log` and `renderer-inspector-compile.log` for reproducibility.

The cached z2d dependency was located at `/Users/alex/.cache/witty-src/z2d-0.10.0`, matching Ghostty's pinned v0.10.0 reference (`build.zig.zon:22-25`). Selected path-state, fill coverage, source-over alpha arithmetic, stroke, and inner-stroke branches were compared to that source. The existing V primitives were not labeled invented merely because their implementation moved out of a dependency; full z2d API equivalence beyond Ghostty's retained call surface was not established.


## Supporting sources, build logic, and dependencies

### S01 — High — Native SIMD paths were omitted; scalar Base64 is a different algorithm

**Classification:** untranslated build-selected logic and algorithm replacement, with demonstrated behavior drift.

Ghostty enables SIMD by default outside Wasm (`src/build/Config.zig:172–182`), then dispatches to its C++ implementation from `src/simd/base64.zig:9–38`, `index_of.zig:10–18`, `codepoint_width.zig:9–13`, and `vt.zig:29–43`. Witty's corresponding `simd/*.v` functions unconditionally use scalar implementations. They implement a reduced source configuration, rather than translating both branches of the native default configuration. Choosing a valid upstream fallback does not cover the omitted branch.

Even in the disabled-SIMD configuration, `src/simd/base64_scalar.zig:88–113` builds lookup tables and validates whole four/sixteen-character groups before writing overlapping four/sixteen-byte words. `simd/base64_scalar.v:46–72` replaces those operations with a byte-at-a-time accumulator. This changes caller-owned output on error. With six destination bytes initialized to `a5`:

| Input | Unchanged upstream scalar implementation | Current V implementation |
|---|---|---|
| `AAA!AAAA` | `Base64Invalid`, buffer `a5a5a5a5a5a5` | `Base64Invalid`, buffer `0000a5a5a5a5` |
| `AAAA!AAA` | `Base64Invalid`, buffer `00000000a5a5` | `Base64Invalid`, buffer `000000a5a5a5` |

This is an actual decoder replacement, not simply a spelling or language representation change. Restore the source lookup-table construction, block decoding, scalar tail, and source-selected optimized entry points.

### S02 — Medium — Base64 padding trimming silently removes upstream checked traps and a warning

**Classification:** behavior drift.

`src/simd/base64.zig:61–65` indexes `input[input.len - i - 1]` without an empty/all-padding guard. In a checked Zig build, `""`, `"="`, and `"===="` trap. `simd/base64.v:8–15` adds an `end > 0` condition; `max_len` and `decode` return empty success for these inputs. Native reference subprocesses aborted with integer overflow for all three inputs; V returned empty success. This may be a desirable independent bug fix, but it violates the requested preservation of upstream logic and must be separated from translation work. `maxLenScalar` also warns on size-calculation failure at original lines 19–24; V line 22 silently returns zero.

### S03 — High — Default allocator ignores requested alignment

**Classification:** behavior drift and runtime boundary.

`src/lib/allocator.zig:23–39` selects `std.heap.c_allocator` when libc is linked; its raw allocation contract retains the requested alignment. `lib_allocator/allocator.v:102–104` discards the alignment argument and always calls `malloc`. Its `c_remap` also ignores alignment and narrows `usize` lengths to `int` (`:114–118`). The callback interface exists, but the fallback allocator does not implement its source contract.

A native comparison allocated 24 bytes with alignment byte `12` (4096-byte alignment). Unchanged Ghostty returned `ptr % 4096 == 0`; the current V default allocator returned `4032`. The specific V remainder is allocator-dependent; any nonzero remainder demonstrates the failure. Translate the aligned C allocator operations and retain pointer-width size handling. Do not treat correct callback forwarding as verification of this fallback.

### S04 — High — Crash capture retains only the disabled Sentry path

**Classification:** untranslated enabled-feature logic; conditional source stub, not an unconditional faithful stub.

`crash/crash.v:52–58` declares empty `initialize` and `shutdown` functions. Upstream `src/crash/sentry.zig:50–79` returns early only when Sentry is disabled or the target is Windows, otherwise starts an initialization thread. Its `initThread` (`:81–155`), `beforeSend` (`:172–244`), shutdown/join boundary (`:157–170`), and SDK transport (`:246–307`) configure native capture and enrich reports with thread/surface metadata. `src/build/Config.zig:158–168` enables Sentry by default on macOS/iOS.

The V envelope parser, report directory, and local persistence helper are substantial translations; they do not connect a crash-producing SDK. No enabled path calls the persistence helper. The current lifecycle is faithful only to a selected disabled build. Translate the enabled branch or explicitly keep this as an unresolved source feature gap.

### S05 — High — Most build/install/package orchestration has no translated counterpart

**Classification:** untranslated logic.

The largest supporting originals, `src/build/SharedDeps.zig` (897 physical lines) and `src/build/Config.zig` (636), define dependency resolution/retargeting, build-selected backends/features, generated options, and artifact setup. Witty's `build/` contains documentation generators and GTK capability detection; `buildcfg/buildcfg.v` supplies a smaller flag subset, including custom compile defines for Flatpak/Snap/Oniguruma choices. Native dependency linkage does exist in V `#flag`/`#pkgconfig` declarations. What is absent is the integrated source-equivalent `SharedDeps` orchestration: dependency retargeting, entry-point switching, and configuration across multiple output artifacts. The missing source symbol names alone were not used to infer that all dependency linking is absent.

This also leaves `GhosttyExe`, `GhosttyLib`, `GhosttyLibVt`, `GhosttyResources`, `GhosttyDocs`, `GhosttyI18n`, `GhosttyDist`, `GhosttyXcodebuild`, `GhosttyXCFramework`, `GhosttyWebdata`, `UnicodeTables`, `HelpStrings`, and the libtool/lipo/XCFramework steps without source-equivalent orchestration. For concrete behavior, `src/build/GhosttyResources.zig:80–153` runs `tic`, preserves terminfo symlinks, installs shell integration/themes, and emits/install completions; `GhosttyI18n.zig:24–48` compiles and installs locale catalogs. Having the data generators does not execute those build/install steps. `main_build_data.v:1–10,64–77` explicitly reduces the original standalone generator CLI (`src/main_build_data.zig:30–51`) to functions exercised by tests.

The inventory distinguishes missing orchestration from implemented documentation generation and pre-generated data. A different compiler/build system is reasonable, but a complete translation still needs equivalent decisions, dependencies, error propagation, installation, and packaging operations.

### S06 — Medium — Build metadata is frozen; artifact detection is absent

**Classification:** behavior drift and untranslated logic.

`src/build/GitVersion.zig:19–81` derives branch, short hash, tag, and dirty state. `build_meta/build_meta.v:7–13` stores fixed strings for the pinned Ghostty commit. This is useful provenance data, but is not an implementation of GitVersion detection. `src/build_config.zig:79–96` detects executable/library/Wasm artifacts; `build_config.v:41–44` always reports `.exe`, including when compiling a library. The source's ReleaseSafe runtime-safety selection (`src/build_config.zig:98–105`) also has no distinct counterpart in the V `debug`-only selection (`build_config.v:61–76`). Preserve the supported output-mode contract and separate reference identity from generated build identity.

### S07 — High — macOS application host is a replacement with missing action implementations

**Classification:** algorithm/application replacement and untranslated logic.

`main_darwin.v:10–12` documents a new standalone AppKit host around the embedded API. Upstream's macOS application spans 145 Swift files under `macos/`; the V host is a new implementation rather than a file-for-file translation. This audit directly checked representative action wiring and establishes the specific omissions below; the remaining Swift application source is not exhaustively reviewed.

For example, `macos/Sources/Ghostty/Ghostty.App.swift:486–487,826–847` dispatches `new_split`, retains inherited split configuration, and posts a split-creation notification. V's `runtime_action` (`main_darwin.v:276–378`) has no `new_split` arm and returns false. The V host acknowledges `.config_change` and `.cell_size` with unconditional success (`:372–374`) without their implemented operations. The original cell-size handler updates the view on the main thread (`Ghostty.App.swift:1694–1714`), and `configChange` applies the new configuration (`:1996–2042`). The same V arm reports success for `.size_limit` and `.quit_timer`; the original explicitly rejects those known-but-unimplemented actions (`:639–649`). Those two cases are false-success return drift, not omitted implemented host operations. Numeric `goto_tab` is also unsupported: V only handles previous/next (`main_darwin.v:338–349`). The translated shared core cannot make these missing host actions work. Translate the native application behavior rather than counting the custom host as source parity.

### S08 — Medium — Executable startup changes failure exit behavior and skips initial quit timer

**Classification:** behavior drift.

`src/main_ghostty.zig:31–54` prints specific invalid-action/multiple-action diagnostics and exits with status 1. Both `main_linux.v:16–20` and `main_darwin.v:380–384` print a generic message and return normally, yielding successful process termination. The Linux create/init/run failure paths similarly return after printing, while original `main() !...` propagates failures. `main_linux.v:39–41` explicitly skips `startQuitTimer`, unlike `src/main_ghostty.zig:105–108`. A comment stating that an adapter lacks the method is evidence of the missing adapter branch, not evidence the source branch was false. Preserve failure status/diagnostics and expose the source timer lifecycle at the runtime boundary.

### S09 — Medium — Synthetic generator enforces an invented maximum-output rejection

**Classification:** behavior drift; native probe verified.

`src/synthetic/Osc.zig:90–94` passes the requested limit to the generator, but its ConEmu branch (`:247–261`) intentionally does not check that limit and writes to the supplied writer. `synthetic/osc.v:50–62` allocates the whole payload and rejects it when it exceeds `max_len - 3`, adding behavior independent of the actual writer capacity.

Force `conemu_progress` to be the sole valid kind, set `max_len = 3`, and give the Zig source a 64-byte fixed writer. With upstream seed 0, it succeeds and writes ten bytes (`1b5d393b3b323b393207`). V returns `WriteFailed`. The finding does not depend on matching RNG streams: every source ConEmu payload in this setup exceeds the nominal limit but fits the writer. Preserve the writer contract and source write/error order rather than inventing a global bound.

### S10 — Medium — Synthetic random selection and streaming were replaced

**Classification:** algorithm replacement and runtime/API boundary.

`src/synthetic/cli.zig:84–95` initializes Zig `DefaultPrng` (Xoshiro256); V `synthetic/cli.v:199–207` uses V's default PRNG (WyRand). `src/synthetic/Bytes.zig:84–100` uses `intRangeAtMostBiased`, then generates/writes in eight-byte chunks. `synthetic/bytes.v:79–107` generates one owned array and substitutes `u64n`, skipping the random operation for equal endpoints. The selected primitive and RNG-consumption order therefore differ even if a future adapter supplies matching random engines. UTF-8/OSC weighted-index helpers also add their own validation and omit the source floating-point endpoint clamp (`std/Random.zig:386–414`; `synthetic/utf8.v:64–83`).

The owned-array `Generator` API (`synthetic/generator.v:3–8`) cannot preserve source writer failure timing/partial output, and introduces V array-capacity errors into the source `error{WriteFailed}` contract. Treat this as an explicit translation boundary and restore source streaming/random algorithms for strict fidelity.

### S11 — High — Image loading, file streams, and JPEG decoding remain untranslated

**Classification:** untranslated dependency logic.

The locked zigimg source is `d7b7ab0ba0899643831ef042bd73289510b39906`, referenced by upstream vaxis's `build.zig.zon:7–10`. Direct comparison used its unchanged extracted source at `/private/tmp/witty-zigimg-pinned/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906`.

Original `src/ImageUnmanaged.zig:142–178,357–394` implements file/path detection, file/path/memory loading, reader selection, seek reset, and codec interface dispatch. Both V image types offer construction/raw editing, memory detection, and fixed-memory writing (`zigimg/image.v`, `image_managed.v`, `image_detection.v`, `image_encoder.v`), but have no `from_memory`, `from_file`, `from_file_path`, `internal_read`, or file writing/detection counterparts. `zigimg/io.v:3–5` explicitly implements only memory streams, whereas original `src/io.zig` retains file and memory variants.

The original JPEG reader has a real frame/table/scan implementation and `readImage` (`src/formats/jpeg.zig:34–178,196–216`) plus supporting JPEG modules. V only implements signature detection (`zigimg/image_detection.v:45–49`) and empty encoder options. Renderer Wuffs JPEG decoding is a different library path and does not translate the missing zigimg reader.

The untracked `zigimg/png_reader.v` was present at audit start and now contains actual IDAT/Adam7 logic. This audit does **not** repeat the older report's claim that PNG decoding is wholly absent. A native differential run used the unchanged locked reader and the current V reader on 7,200 generated cases. Both exited successfully and produced 7,200 matching result lines: all 15 supported color/depth pairs, widths 1/3/8, heights 1/3, noninterlaced/Adam7, all five row filters, two consecutive IDAT chunks, and eight harness option/API modes. No discrepancy was observed in those cases. Invalid/changing streams, all metadata combinations, allocation failure, and large-dimension branches remain unverified; the existing 28-file repository suite has no dedicated new decoder test. PNG loader availability also does not restore the absent generic image-loading registry.

### S12 — Medium — Huffman lookup strategy is explicitly replaced

**Classification:** algorithm replacement, with no additional output bug asserted.

The Zig 0.15.2 decompressor used by the locked TIFF/PNG dependency retains a small Huffman lookup plus linked-symbol fallback (`lib/std/compress/flate/Decompress.zig:702–764,801–817`). `zigimg/tiff_deflate.v:40–88` builds a full `1 << max_bits` table; lines 61–62 explicitly say it replaces the source lookup/fallback. This changes the construction, allocation, and lookup algorithms even where decoded bytes agree. Existing differential tests cannot establish the user's stronger requirement that the algorithm itself was translated. This file was already modified in the working tree when auditing began; the finding is about that current file, not attribution to this audit.

### S13 — High — libxev's Windows/WASI backends are named but absent

**Classification:** untranslated dependency/platform logic.

The local libxev reference exports IOCP and WasiPoll implementations (`libxev/src/main.zig:76–80`), implemented by `backend/iocp.zig` (2376 lines) and `backend/wasi_poll.zig` (1648 lines). `xev/backend.v:22–25,39–42` selects those enum values for Windows/WASI, but Witty has no corresponding backend files/loop implementation. `xev/thread_pool.v:1201,1247` explicitly stops compilation outside the translated macOS/Linux futex branches. Advertising source backend tags is not implementation coverage. Linux/macOS backend files are substantial; this finding concerns the omitted selectable targets, not a claim that all of libxev is a stub. Large native backends/watcher details remain dependency audit follow-up items.

### S14 — Medium — vaxis decoded-image loading/transmission is absent

**Classification:** untranslated dependency logic.

Upstream vaxis `src/Vaxis.zig:983–1031` converts/encodes a decoded zigimg image, emits Base64, and implements path/memory `loadImage` with cleanup. `vaxis/image.v:121–182` implements only path transmission and already-encoded transmission. There is no decoded-image `transmit_image`, `load_image`, or equivalent source `Image.Source` path/memory value. Existing screen/image placement and protocol sequences are substantial translations, but do not provide this source API; implementing generic zigimg loaders is a prerequisite.

### S15 — Medium — Generic ABI construction utilities lack source-equivalent factories

**Classification:** untranslated API/generic logic; application call-site parity remains separate.

`src/lib/enum.zig:21–65` constructs C/native enums with preserved holes, `src/lib/struct.zig:4–31` constructs extern layouts, and `src/lib/union.zig:22–140` generates padded C unions, converts nested `cval` values, checks padding size, and resolves `Value(tag)`. There are no V factories implementing these generic operations. Witty manually specializes C-facing types in `apprt/action.v`, `terminal_c/terminal_c.v`, and root ABI bridges. Some fixed call sites may be correct; that does not translate the public generic utilities or guarantee that changing a source enum/layout updates every manual specialization. Do not classify spelling/namespace changes alone as a bug; the missing generic behavior is the issue.

### S16 — Medium — Built-in Metal shaders compile at runtime instead of through the translated build

**Classification:** build/runtime algorithm replacement.

`src/build/MetallibStep.zig:24–84` runs the Metal compiler and archive tool during the build. `src/renderer/metal/shaders.zig:334–352` loads the resulting embedded `ghostty_metallib` with `newLibraryWithData:error:`. V `renderer/metal_types_darwin.c.v:943–946` instead compiles embedded source through `metal_new_library_source` when initializing the renderer. Upstream also compiles user-supplied custom shader source dynamically; that separate path does not justify changing built-in shader compilation. Startup now pays this compilation cost, built-in shader errors are startup failures, and the platform/minimum-version build selection is absent. This is a confirmed divergence even if the resulting shader functions produce matching pixels.

### Source-equivalent empty bodies and reviewed correspondences

Empty bodies are not automatically untranslated. The locked zigimg JPEG writer (`src/formats/jpeg.zig:219–224`), various other writers, and PNG writer/commented chunk bodies already do no useful output upstream. Witty should preserve those source limitations and document them, not invent codecs to fill them. Likewise upstream `src/quirks.zig:15–22` returns false from `disableDefaultFontFeatures`; the V constant behavior is faithful. Lifecycle methods whose only source work releases GC-managed storage are representation adaptations, not by themselves evidence of missing executable logic. Enabled Sentry is different because its source body performs external SDK/thread operations.

The Unicode property/grapheme model follows the pinned table structure and state packing (`src/unicode/props.zig`, `grapheme.zig` versus `unicode/properties.v`, `grapheme.v`); reviewed entry points and tests did not expose a new discrepancy. Data provenance is recorded in the V files, but this audit did not regenerate all property tables and does not independently certify every binary entry. The supporting tests include meaningful table/transition and documentation-output checks. Exact C vendoring, such as stb/Wuffs, is valid source reuse; it is not from-scratch logic merely because the wrapper is written in V.

### Root validation

All commands ran in `/Users/alex/code/witty` with `VEXE` set to the explicitly invoked `/Users/alex/.cache/v/v1-fallback/0.5.2/v`.

- `v test simd unicode synthetic benchmark crash lib_allocator build mathutil file_type terminfo`: **20 test files passed**.
- `v test zigimg`: **28 test files passed**, including the converter matrix; compilation included the pre-existing untracked PNG reader.
- PNG native differential: **7,200/7,200 result lines matched**, both processes exited 0; generated valid inputs cover the matrix described in S11. Comparison includes status, format/dimensions, stream position, pixel/palette hashes, and callback/header information.
- `v -check .`: **passed** with existing compiler notices. This is a type/checker gate, not an application runtime or cross-platform test.
- Native Base64 comparison: unchanged `base64.zig` and `base64_scalar.zig`, compiled with `simd=false`; only build options/assert dependencies were supplied in the harness. Confirmed both malformed-buffer outputs and three checked traps.
- Native allocator comparison: directly imported unchanged `src/lib/allocator.zig`, linked libc, compared the same length/alignment request against V.
- Native OSC comparison: unchanged `Osc.zig`, `Bytes.zig`, `Generator.zig`, and `os/string_encoding.zig`; supplied an empty module only for an unused upstream test import. Confirmed the accepted oversized ConEmu request versus V's rejection.

The native Zig executable was `/private/tmp/witty-zig-reference/zig-aarch64-macos-0.15.2/zig`, target `aarch64-macos.14.0`, linked with `-lc`. Probe source and raw logs were retained under `/tmp/witty-ultra-audit` for this session; decisive inputs/results are included above so the report is not dependent on those temporary logs surviving. No production source was changed.


## Additional large macOS Swift host sources

Seven additional original Swift files (8,064 physical lines) were directly compared with the executable standalone Darwin host. All seven received targeted review of implemented branches; none is certified as an exhaustive branch-by-branch translation. The relevant V host is [main_darwin.v](/Users/alex/code/witty/main_darwin.v:15) together with [macos/appkit_darwin.c.v](/Users/alex/code/witty/macos/appkit_darwin.c.v:853). The latter dynamically registers Objective-C classes and creates ordinary `NSWindow` instances. There is no `main_darwin_native.m` in this checkout. Foundation/CoreText bindings and embedded action definitions are partial supporting mappings, rather than translations of these Swift controllers.

### SH01 — macOS split management is missing from the standalone runtime

**Classification: missing translation; host implementation replacement.**

Original [BaseTerminalController.swift:228](/Users/alex/code/3rd/ghostty/macos/Sources/Features/Terminal/BaseTerminalController.swift:228) creates a surface, inserts it into the current immutable tree, moves focus, and registers undo through `replaceSurfaceTree`. [SplitTree.swift:130](/Users/alex/code/3rd/ghostty/macos/Sources/Features/Splits/SplitTree.swift:130) implements insertion/removal/replacement; [SplitTree.swift:175](/Users/alex/code/3rd/ghostty/macos/Sources/Features/Splits/SplitTree.swift:175) selects previous/next and spatial focus targets; [SplitTree.swift:231](/Users/alex/code/3rd/ghostty/macos/Sources/Features/Splits/SplitTree.swift:231) equalizes leaf-weighted ratios; [SplitTree.swift:250](/Users/alex/code/3rd/ghostty/macos/Sources/Features/Splits/SplitTree.swift:250) searches the nearest suitable ancestor and resizes in pixel space, clamps ratios to 0.1–0.9, and clears zoom.

V [main_darwin.v:15](/Users/alex/code/witty/main_darwin.v:15) stores a flat list of single-view surface states, and [appkit_darwin.c.v:1570](/Users/alex/code/witty/macos/appkit_darwin.c.v:1570) installs one terminal view as each window's content. `new_split`, `goto_split`, `resize_split`, `equalize_splits`, and `toggle_split_zoom` exist in [apprt/action.v:44](/Users/alex/code/witty/apprt/action.v:44), but the complete standalone action switch [main_darwin.v:276](/Users/alex/code/witty/main_darwin.v:276) has no handling for them and returns false at line 377. [datastruct/split_tree.v:31](/Users/alex/code/witty/datastruct/split_tree.v:31) translates the separate Zig split tree, and Linux GTK has its own widgets; neither is connected to this Darwin host. This is not evidence that the generic helper's ordinary operations are wrong. It is a confirmed missing macOS view-tree/controller translation: split keybindings cannot create, focus, resize, equalize, or zoom native splits through this runtime.

### SH02 — Quick Terminal controller behavior is untranslated

**Classification: missing translation.**

Original [QuickTerminalController.swift:326](/Users/alex/code/3rd/ghostty/macos/Sources/Features/QuickTerminal/QuickTerminalController.swift:326) tracks visibility and the previously active application/Space, restores a saved surface tree or starts a terminal with `GHOSTTY_QUICK_TERMINAL=1`, and animates it onto the configured screen. [QuickTerminalController.swift:163](/Users/alex/code/3rd/ghostty/macos/Sources/Features/QuickTerminal/QuickTerminalController.swift:163) handles resigning focus, modal-sheet exceptions, dock restoration, and configured auto-hide/Space behavior. [QuickTerminalController.swift:541](/Users/alex/code/3rd/ghostty/macos/Sources/Features/QuickTerminal/QuickTerminalController.swift:541) saves screen state, restores the previous application, and hides with the configured animation.

V defines `toggle_quick_terminal` at [apprt/action.v:56](/Users/alex/code/witty/apprt/action.v:56), but [main_darwin.v:276](/Users/alex/code/witty/main_darwin.v:276) falls through to false for it. The window factories [appkit_darwin.c.v:1560](/Users/alex/code/witty/macos/appkit_darwin.c.v:1560) and [appkit_darwin.c.v:1926](/Users/alex/code/witty/macos/appkit_darwin.c.v:1926) create ordinary windows/tabs and have no corresponding Quick Terminal state/controller. The original drop-down terminal lifecycle and its configured behavior are therefore unavailable in the standalone Darwin application.

### SH03 — close undo and application/window/split restoration are missing

**Classification: missing translation.**

Original [TerminalController.swift:637](/Users/alex/code/3rd/ghostty/macos/Sources/Features/Terminal/TerminalController.swift:637) registers an expiring undo that restores a closed tab and its redo. [TerminalController.swift:760](/Users/alex/code/3rd/ghostty/macos/Sources/Features/Terminal/TerminalController.swift:760) handles a whole tab group and captures restoration order/focus. [BaseTerminalController.swift:460](/Users/alex/code/3rd/ghostty/macos/Sources/Features/Terminal/BaseTerminalController.swift:460) records old trees for split undo/redo. Original window creation [TerminalController.swift:1016](/Users/alex/code/3rd/ghostty/macos/Sources/Features/Terminal/TerminalController.swift:1016) assigns `isRestorable`, a restoration class, and an identifier; [TerminalController.swift:1182](/Users/alex/code/3rd/ghostty/macos/Sources/Features/Terminal/TerminalController.swift:1182) encodes terminal state. Application-level secure restoration [AppDelegate.swift:1026](/Users/alex/code/3rd/ghostty/macos/Sources/App/macOS/AppDelegate.swift:1026) respects `window-save-state` and stores/restores Quick Terminal state. [SplitTree.swift:354](/Users/alex/code/3rd/ghostty/macos/Sources/Features/Splits/SplitTree.swift:354) validates a serialization version and reconstructs zoom by its path into the decoded tree.

V [main_darwin.v:127](/Users/alex/code/witty/main_darwin.v:127) frees the surface immediately and closes the native tab, without retaining a restoration/undo snapshot. Its runtime switch has no `undo`/`redo` implementation, despite definitions [apprt/action.v:140](/Users/alex/code/witty/apprt/action.v:140). The native delegate method registrations [appkit_darwin.c.v:864](/Users/alex/code/witty/macos/appkit_darwin.c.v:864) contain no application/window encoding or restoration selectors; [appkit_darwin.c.v:1371](/Users/alex/code/witty/macos/appkit_darwin.c.v:1371) assigns no restoration class/state. The generic Zig-derived split tree has no equivalent of the Swift versioned `Codable` representation. Closed sessions cannot be recovered through the source's undo behavior, and the original persisted window/tree/focus restoration contract is absent.

### SH04 — configured native window and Ventura titlebar behavior is replaced by fixed defaults

**Classification: missing translation; host implementation replacement.**

Original [TerminalWindow.swift:114](</Users/alex/code/3rd/ghostty/macos/Sources/Features/Terminal/Window Styles/TerminalWindow.swift:114>) removes `.titled` when decorations are disabled, applies configured initial coordinates, and hides the window buttons when requested. [TerminalWindow.swift:433](</Users/alex/code/3rd/ghostty/macos/Sources/Features/Terminal/Window Styles/TerminalWindow.swift:433>) applies configured appearance/shadow and handles opacity/blur with a native-fullscreen exception; [TerminalWindow.swift:480](</Users/alex/code/3rd/ghostty/macos/Sources/Features/Terminal/Window Styles/TerminalWindow.swift:480>) derives the titlebar background from the focused surface bordering the top or the top-left surface. [TitlebarTabsVenturaTerminalWindow.swift:144](</Users/alex/code/3rd/ghostty/macos/Sources/Features/Terminal/Window Styles/TitlebarTabsVenturaTerminalWindow.swift:144>) updates theme/titlebar color, and [TitlebarTabsVenturaTerminalWindow.swift:404](</Users/alex/code/3rd/ghostty/macos/Sources/Features/Terminal/Window Styles/TitlebarTabsVenturaTerminalWindow.swift:404>) relocates the tab accessory into the toolbar with button/drag-handle layout and overflow/separator adjustments.

V [appkit_darwin.c.v:1562](/Users/alex/code/witty/macos/appkit_darwin.c.v:1562) fixes the initial frame at `(100,100)` and always creates titled/closable/miniaturizable/resizable `NSWindow`s; tab creation repeats the fixed style at [appkit_darwin.c.v:1950](/Users/alex/code/witty/macos/appkit_darwin.c.v:1950). [appkit_darwin.c.v:1371](/Users/alex/code/witty/macos/appkit_darwin.c.v:1371) applies fixed minimum size/tab identity/fullscreen behavior and explicitly disables titlebar transparency. The host receives `.config_change` and `.cell_size` at [main_darwin.v:372](/Users/alex/code/witty/main_darwin.v:372) and returns true without updating the window. There is no equivalent Ventura titlebar class or appearance-sync path in this host. Core renderer opacity and native blur helper availability do not implement the omitted controller/window behavior. These configured window features are untranslated, even when terminal rendering itself works.

### SH05 — fullscreen mode dispatch loses source behavior

**Classification: behavior drift; missing translation.**

Original [BaseTerminalController.swift:1007](/Users/alex/code/3rd/ghostty/macos/Sources/Features/Terminal/BaseTerminalController.swift:1007) derives a fullscreen style from the requested mode, detects style changes, exits the old style when needed, then enters/exits the selected style. V [main_darwin.v:333](/Users/alex/code/witty/main_darwin.v:333) discards the action data and calls [appkit_darwin.c.v:1757](/Users/alex/code/witty/macos/appkit_darwin.c.v:1757), which always sends AppKit `toggleFullScreen:`. Requests for different source fullscreen styles therefore collapse into the same native operation; the source's mode-change transition logic is missing.

### SH06 — application termination and reopen guards differ

**Classification: behavior drift; missing translation.**

Original [AppDelegate.swift:353](/Users/alex/code/3rd/ghostty/macos/Sources/App/macOS/AppDelegate.swift:353) bypasses quit confirmation when installing an update, when all windows are invisible, and for shutdown/restart/logout Apple Events before consulting the core's confirmation flag. V [main_darwin.v:198](/Users/alex/code/witty/main_darwin.v:198) consults only the core flag and then displays confirmation. The source's lifecycle-specific quit decisions are omitted.

Original [AppDelegate.swift:426](/Users/alex/code/3rd/ghostty/macos/Sources/App/macOS/AppDelegate.swift:426) returns true for visible windows, in-progress terminal controllers, or an application that has not become active; it creates a new terminal only after those guards. V [appkit_darwin.c.v:1247](/Users/alex/code/witty/macos/appkit_darwin.c.v:1247) returns false when windows are visible; otherwise [main_darwin.v:206](/Users/alex/code/witty/main_darwin.v:206) immediately creates a window, with no controller-initialization/activation guards. Both the delegate return value and guarded reopen behavior diverge. These conclusions are source-backed; AppKit lifecycle events were not replayed in an interactive GUI test.

### Coverage and limits for this additional scope

All seven originals are mapped in the native inventory below as `targeted` / `gap-confirmed`. Reviewed branches cover AppDelegate quit/reopen/restoration; TerminalController close/undo/window restoration; BaseTerminalController split insertion/focus/tree undo/fullscreen; TerminalWindow initial configuration/appearance; Ventura tab/titlebar appearance and layout; Quick Terminal focus/animation/restoration; and Swift SplitTree insertion/removal/focus/equalization/pixel resize/versioned coding. The standalone Darwin action switch and Objective-C delegate/window setup were inspected in full for dispatch/mapping omissions.

Remaining unverified areas include updater behavior, complete secure-input/notification/menu handling, every window event branch, split drag-and-drop, complete spatial candidate ordering, and live AppKit rendering/layout/Space transitions. No additional GUI test or production edit was made for this late scope extension. Prior terminal/data-structure tests do not establish fidelity of the Swift host.


## Native Swift bridge follow-up: six large source files

Reference: Ghostty `6c0e02d11`; current V working tree. The six assigned Swift files received direct targeted source/port comparisons. Their source-relative paths, physical line counts, counterpart mappings, and reviewed branch families are recorded in the native inventory below. The V counterpart is a replacement standalone AppKit host distributed across `main_darwin.v`, `macos/appkit_darwin.c.v`, C message bridges, and the embedded API; there is no file-for-file Swift class translation.

### SB-01 — High: AppKit composition and key-equivalent handling are not translated

**Classification:** missing translation / runtime input boundary.

Ghostty `macos/Sources/Ghostty/Surface View/SurfaceView_AppKit.swift:1029-1148` preserves original event identity when translated modifiers agree, calls `interpretKeyEvents`, accumulates committed `insertText`, detects keyboard-layout changes, syncs preedit, and sets `composing` for marked/cancelled compositions. Its `NSTextInputClient` implementation (`:1758-1985`) implements marked text, selection/substrings, candidate-window rectangles, committed text, command dispatch, and `ghostty_surface_preedit` synchronization.

V registers an `NSView` subclass with ordinary key/mouse methods (`macos/appkit_darwin.c.v:812-851`), but no text-input-client protocol or these methods. Its `keyDown:` immediately calls `dispatch_key` (`:954-960`); the live callback directly reads event characters and always sets `composing: false` (`main_darwin.v:497-521`). The embedded preedit API exists (`apprt/embedded.v:1673-1681`) but this host does not call it. Therefore ordinary key forwarding does not translate the source's dead-key/IME composition, preedit display/cancellation, candidate positioning, or dictation paths.

The source also implements `performKeyEquivalent` with binding flags, focused-state checks, menu precedence, control-return/control-slash handling, and command-event redispatch (`SurfaceView_AppKit.swift:1184-1303`), plus a local monitor forwarding Command-key releases that AppKit does not normally send (`:666-678`). The V subclass registers neither `performKeyEquivalent:` nor that event monitor. This is additional omitted responder logic, not a discrepancy in the retained low-level modifier bit conversion.

### SB-02 — High: terminal accessibility, Services, and drag/drop interfaces are absent

**Classification:** missing native translation.

Ghostty `SurfaceView_AppKit.swift:1991-2086` implements the Services requestor, validates supported send/return pasteboard types and required selection, writes selection, and inserts received text. `:2090-2146` accepts string/URL/file-URL drops, escapes URLs and individual paths, joins multiple paths, and inserts text. `:2154-2246` exposes a text-area accessibility element, cached terminal contents, selected text/range, character/line/range access, and attributed text with the terminal font.

The current V view's registration list (`macos/appkit_darwin.c.v:812-851`) ends with ordinary copy/paste/select-all/new-tab/close-tab handlers. It has no Services protocol or selectors, drag registration/drop selectors, or terminal accessibility methods; searches of `main_darwin.v` and `macos/` found no implementations of these families. Clipboard functions and embedded selection/QuickLook APIs do not make these native consumers available. Assistive technologies cannot receive the source's terminal-specific text interface through this host, and Services and drop insertion are untranslated. Native accessibility/drag interaction was not executed.

### SB-03 — High: most native action consumers and surface overlays are missing

**Classification:** missing translation / disconnected runtime wiring.

Ghostty's full action switch (`macos/Sources/Ghostty/Ghostty.App.swift:464-647`) dispatches implemented native actions. The standalone V switch (`main_darwin.v:276-377`) handles a limited subset and returns false through its default branch for the families below. Corresponding enum/data types in `apprt/action.v` do not supply the missing host consumers.

Concrete directly compared families include:

* Search lifecycle/count/selection callbacks update native `SearchState` (`Ghostty.App.swift:1874-1970`); source view editing debounces short needles for 300 ms (`SurfaceView_AppKit.swift:73-103`), and the search overlay provides editing, focus, navigation, selected/total counts, close, and draggable positioning (`SurfaceView.swift:399-521`). V has no native search overlay/state or these action branches.
* Key-sequence/table state, progress reports, renderer health, readonly, and bell callbacks (`Ghostty.App.swift:1029-1076`, `:1738-1844`) drive the corresponding source overlays (`SurfaceView.swift:106-140`, `:191-208`, `:755-1167`). V has no such surface state/view hierarchy. Source progress also expires after 15 seconds (`SurfaceView_AppKit.swift:49-62`), and readonly's badge provides a disable action. The retained terminal/core mechanisms are separate from the missing native presentation.
* Mouse shape/visibility/link callbacks (`Ghostty.App.swift:1577-1650`) update the source cursor and hovered-URL state. They reach V's default false branch; there is no `NSCursor` implementation in `macos/` and no native hovered-link overlay.
* Secure-input callbacks update app or scoped surface state (`Ghostty.App.swift:1447-1479`; `SurfaceView_AppKit.swift:155-168`, `:434-436`); desktop notifications request authorization and dispatch to the surface (`Ghostty.App.swift:1356-1390`), which schedules/removes/focuses notifications (`SurfaceView_AppKit.swift:1626-1678`). Both native families are absent. The source notification/category definitions in `macos/Sources/Ghostty/Package.swift:15-19`, `:389-498` have no equivalent consumer chain in the V host.

Other directly observed unsupported native actions include command palette, floating windows, title prompts, working-directory notifications, move-tab, goto-window, maximize/visibility/quick-terminal, inspector presentation/rendering, reset-window-size, undo/redo, scrollbar updates, and close-other/right tabs. For the last case the V host explicitly rejects any `CloseTabMode` other than `.this` (`main_darwin.v:291-296`), while source `Ghostty.App.swift:890-909` emits distinct other/right close requests.

New-split/config-change/cell-size/goto-tab gaps already covered by root S07 are not counted again here. `SIZE_LIMIT` and `QUIT_TIMER` no-ops are inherited source limitations and were excluded.

### SB-04 — Medium: native screen changes do not update the renderer display ID

**Classification:** missing translation / native renderer wiring.

Ghostty registers `NSWindow.didChangeScreenNotification` (`SurfaceView_AppKit.swift:356-361`) and, for the matching window, calls `ghostty_surface_set_display_id` with its screen's display ID before refreshing backing properties (`:747-763`). Its comment identifies correct CVDisplayLink/vsync refresh rate as the purpose.

The V host observes only frame changes for its view (`macos/appkit_darwin.c.v:1461-1465`) and handles backing changes by invoking its resize callback (`:934-937`; `main_darwin.v:453-461`). It never calls the available `apprt.ghostty_surface_set_display_id` (`apprt/embedded.v:1901-1904`). Scale updates are implemented, but the source screen/display-link update is not. Multi-display refresh-rate behavior remains unverified.

### SB-05 — Medium: configuration-derived native menu shortcut logic is replaced by fixed shortcuts

**Classification:** missing translation / native configuration behavior drift.

Ghostty `Ghostty.Config.swift:114-120` obtains the configured trigger for an action; `Ghostty.Input.swift:19-46`, `:84-100` handles physical-functional keys, Unicode triggers, catch-all rejection, and modifier conversion into native shortcuts. The actual menu synchronization consumer clears a missing shortcut or applies its key/modifiers (`macos/Sources/App/macOS/AppDelegate.swift:669-680`).

V's live `install_menu_bar` (`macos/appkit_darwin.c.v:1403-1458`) takes no configuration and installs fixed `q`, `t`, `w`, `c`, `v`, `a`, and previous/next-tab equivalents. Neither it nor the native reload path synchronizes these from the configured triggers. Rebinding or unbinding these actions cannot produce the source's menu equivalents/clearing behavior; SB-01 also removes the source's binding-aware responder precedence. Core keybinding parsing is retained and is not claimed missing.

### SB-06 — Medium: a surface-targeted config reload becomes an app-wide reload

**Classification:** behavior drift / action target omitted.

Ghostty `Ghostty.App.swift:139-177` distinguishes app reload via `ghostty_app_update_config` from surface reload via `ghostty_surface_update_config`. The runtime dispatcher preserves the target (`:1972-1993`), so a surface-only reload does not replace the app's configuration or update other surfaces.

V's `.reload_config` branch ignores the already resolved surface target and always calls `reload_runtime_config(app, soft)` (`main_darwin.v:367-370`); that helper always invokes `ghostty_app_update_config` (`:259-272`). Both soft and hard surface requests therefore use the app-wide path. This is distinct from the already reported ignored `.config_change` callback.

### Coverage and checks

The six source counts are 813 (`Ghostty.Config.swift`), 1,314 (`Ghostty.Input.swift`), 501 (`Package.swift`), 2,291 (`SurfaceView_AppKit.swift`), 1,262 (`SurfaceView.swift`), and 2,093 (`Ghostty.App.swift`). Every file is marked `targeted`, not whole-file certified. The native inventory below identifies compared families. Wrapper lifetimes, enum/bitfield representation changes, and Swift namespace removal were not automatically counted as omissions.

Retained behavior observed directly includes app tick/wakeup and focus/keyboard-layout callbacks, surface inheritance/options and native view/userdata handles, ordinary press/repeat/release forwarding, sided modifier conversion, mouse-button mapping, precise-scroll 2x scaling and momentum packing, pressure/focus/resize/backing-scale forwarding, ordinary copy/paste/select-all, window/tab creation, native fullscreen invocation, and title dispatch onto the main thread. Presence of these does not prove equivalence of the surrounding native UI.

The pinned `/Users/alex/.cache/v/v1-fallback/0.5.2/v` (`V 0.5.2`), with `VEXE` set to itself and repository-first `-path '/Users/alex/code/witty|@vlib|@vmodules'`, directly ran `macos/appkit_darwin_test.v` and returned exit 0. That compiler automatically executes/removes the direct test binary. Its five existing tests cover GPU constants, modifier-key press/release including sided keys, ABI modifier bits, and scroll momentum; they do not exercise a GUI, IME, native accessibility, missing action consumers, or multi-display movement. Log: `/tmp/witty-ultra-audit/swift-appkit-compile.log`.

A subsequent diagnostic-only `-stats` invocation selected the local `benchmark` module instead of V's test-support module and failed on test-runner helper symbols. This harness/module-name issue is not a production failure and does not supersede the successful ordinary direct run. No production source edits or native GUI experiments were performed.


## Large public embedding header

`include/ghostty.h` is 1,160 physical lines and was reviewed directly against the current V C-facing wrappers and their implementation projections. This is an additional original outside the 456-file `src/**/*.zig` inventory. The header itself contains declarations rather than executable algorithms; its first seven lines identify the current macOS embedding consumer and direct readers to the source implementations for behavior.

| Original contract group | V counterparts examined | Review result / limit |
|---|---|---|
| Opaque handles, platform/clipboard/input enums, packed modifier bits, key events and triggers (`include/ghostty.h:28–357`) | `embedded_c.v`, `apprt/embedded.v`, `apprt/c_api.v`, `input/input.v`, `input/key.v`, `config_c.v` | Targeted field, ordinal and conversion review. The external platform union is passed as one pointer by `SurfaceConfigC`, then projected into the internal V platform representation; the larger internal `PlatformC` is not itself the exported C struct. |
| Build info, diagnostics, owned strings, text/point/selection data (`:358–415`) | `main_c.v`, `config_c.v`, `embedded_c.v`, `apprt/embedded.v` | Targeted pointer/length/ownership review, including the native copy/free bridge for exported text. Header point tag `SURFACE` has ordinal 3; original implementation and V call that same ordinal `history`, so that name difference is inherited from the original and is not a new V discrepancy. |
| Environment, commands, surface options/size, configuration projections (`:416–511`) | `embedded_c.v`, `apprt/embedded.v`, `configpkg/c_api.v`, `config_c.v` | Targeted conversion review. Existing R02 covers the confirmed nullable configuration getter drift; exported-name presence does not correct it. |
| Action targets, action enums/payloads and runtime callbacks (`:512–983`) | `apprt/action.v`, `apprt/c_api.v`, `apprt/embedded.v`, `embedded_c.v`, `embedded_c_darwin.v` | Targeted tag/payload/callback review. The 24-byte V action payload storage and copying helper are explicit specializations, not evidence that the source generic ABI factories were translated (see S15). No additional action-field discrepancy was confirmed here. |
| IPC type projections (`:984–1012`) | `apprt/ipc.v` | Targeted enum, nullable argv list and union projection review; the header declares types here, without adding a published IPC function. |
| Global/config/application/surface/inspector/macOS/benchmark functions (`:1017–1154`) | `main_c.v`, `config_c.v`, `embedded_c.v`, `embedded_c_darwin.v`, `apprt/embedded.v`, `core/embedded_bridge.v`, `benchmark/benchmark.v` | All 88 published function names have V export wrappers: 5 in `main_c.v`, 13 in `config_c.v`, 64 in `embedded_c.v`, and 6 in `embedded_c_darwin.v`. This is textual export coverage, not proof that a built library exports the symbols or that every calling convention/layout is compatible. |

`lib_vt_c.v` was checked to distinguish the separate `ghostty/vt` public API: its key-event/encoder/OSC/SGR export wrappers do not substitute for the embedding functions declared by `include/ghostty.h`.

### PH01 — Medium — Supplied embedding argv is discarded by configuration loading on Linux/FreeBSD

**Classification:** behavior drift at the public API boundary; confirmed by source inspection, not a native embedding probe.

The header publishes `ghostty_init(uintptr_t, char**)` and `ghostty_config_load_cli_args(ghostty_config_t)` (`include/ghostty.h:1017,1026`). Original initialization stores the caller's argument vector in `std.os.argv` (`src/main_c.zig:108–112`). On Linux/FreeBSD, `Config.loadCliArgs` checks and handles that vector (`src/config/Config.zig:3925–3962`), then parses the process iterator (`:3998–4001`; `src/cli/args.zig:1366–1371`). The original non-macOS iterator is `std.process.ArgIterator` (`src/os/args.zig:18–21`). Therefore, an embedder supplying `['host', '--font-size=17']` establishes the arguments consumed by the original configuration API on those platforms.

V's C export copies the supplied argv and calls its helper (`main_c.v:220–228`), which stores the arguments in `GlobalState.cli_args` (`main_c.v:124–130`; `global_state/global_state.v:265–273`). However, `ghostty_config_load_cli_args` then reads `os.args[1..]` (`config_c.v:69–71`) instead of that stored vector. A host vector differing from the executable's actual arguments consequently supplies different configuration options. Preserve the source platform-specific argument source when loading configuration.

This finding is restricted to Linux/FreeBSD. The original macOS configuration iterator deliberately uses `NSProcessInfo.arguments`, not `std.os.argv` (`src/os/args.zig:10–30,41–44`), and macOS is the header's current embedding consumer. It would overstate the evidence to describe this as a demonstrated failure of the current macOS host.

**Verification and remaining limits:** a script compared all published `ghostty_*` prototypes with current `@[export: 'ghostty_*']` declarations and found no missing function names. The struct/enum/function groups above were directly targeted; no new native C consumer, foreign calling-convention test, callback lifetime test, or cross-target ABI build was run. Existing V layout assertions in `main_c_test.v:251–255` and `apprt/c_api_test.v:8–11` were inspected, but only assert selected V-side sizes. Arbitrary callback lifetimes, every struct offset, every action variant, Darwin/iOS calling behavior, and a shipped public-header installation remain unverified. Absence of further findings in this targeted pass is not a parity certification.

## Consolidated validation and limits

| Check | Result | What it establishes |
| --- | --- | --- |
| Pinned V terminal/input/datastruct/OSC/search suites | 42 + 11 + 12 + 14 + 7 = **86 test files passed** | Existing checks for those modules; native probes still expose uncovered discrepancies |
| Pinned V termio/configpkg/SSH cache checks | 4 + 3 + 1 = **8 test files passed** | Existing runtime/config/cache checks |
| Pinned V supporting modules | **20 test files passed** | SIMD, Unicode, synthetic, benchmark, crash, allocator, build, math, file type, terminfo |
| Pinned V zigimg suite | **28 test files passed** | Existing image/conversion/encoder checks; distinct from the new decoder differential |
| Pinned repository-first font/inspector integration and AppKit helper checks | **3 test files passed**, process exits 0 | Live font-shaper runtime, inspector, and native modifier/scroll helper tests compile and execute |
| Sprite face/fill/stroke and OpenType checks using V `0.5.2 0dc6a69` | **4 test files passed**, process exits 0 | Focused sprite and OpenType behavior under that compiler |
| Native/V valid-PNG differential | **7,200 result lines matched**, both exits 0 | Matrix of valid decoding/header/API option cases described in S11 |
| Golden sprite fixture provenance | **36/36 digests match original decoded atlas pixels**; rendering checks pass | Exact covered sprite batches/metrics |
| Nerd Font constraint-arm comparison | **10,458 codepoints**, 276 original and 276 V arms, zero mismatches | Compared fields for covered points and every boundary neighbor |
| `v -check .` using pinned V | **Passed** with existing notices | Native application checker gate; does not run the app/GPU |
| Native/V targeted terminal/support probes | **Differences reproduced** as recorded above | Specific original-vs-port contracts; tests passing elsewhere do not remove these findings |

The pinned module and integration checks total **145 successful test-file executions**; four additional focused sprite/OpenType executions passed under the other V checkout. No complete native Ghostty build, release packaging, live GUI/GPU visual comparison, allocation-failure sweep, race stress run, browser/Wasm run, Windows run, or Linux GTK/OpenGL run was completed. A full live GUI/native ABI certificate cannot be inferred from checker/unit success.

Reproduction of authoritative V checks (from the Witty root):

```sh
export VEXE=/Users/alex/.cache/v/v1-fallback/0.5.2/v
"$VEXE" test terminal input datastruct osc search
"$VEXE" test termio configpkg cli/ssh_cache_test.v
"$VEXE" test simd unicode synthetic benchmark crash lib_allocator build mathutil file_type terminfo
"$VEXE" test zigimg
"$VEXE" -path "$PWD|@vlib|@vmodules" font/shaper_runtime_test.v
"$VEXE" -path "$PWD|@vlib|@vmodules" inspector/inspector_test.v
"$VEXE" -path "$PWD|@vlib|@vmodules" macos/appkit_darwin_test.v
"$VEXE" -check .
```

The repository must precede `@vlib` for standalone font/inspector probes: otherwise V resolves its standard `macos` module instead of the translated local module. Supplying a `|`-containing `-path` through this compiler’s `v test` wrapper also produced a shell-quoting failure; the direct `_test.v` invocations above avoid that wrapper problem. Earlier default-compiler/path failures were superseded and are not reported as production fidelity defects.

Native probes compiled unchanged originals with the explicit Zig target and libc options given above. Temporary harness substitutions were limited to build options/assert imports or unused test imports, as described in each section. PNG used an unchanged copy of the locked zigimg `src` tree with the pre-existing `zigimg/reference_probes/png_decode/reference.zig` harness. The matrix generator formed valid CRC-checked PNGs, applied source-supported bit packing and Paeth/Sub/Up/Average/None filters, split compressed data into two IDAT chunks, and supplied noninterlaced/Adam7 inputs. All 7,200 requested cases produced output on both sides before comparing result lines. The decisive inputs and outputs are included in findings so conclusions do not require temporary logs to survive. Raw session probes/logs and generator script were retained at `/tmp/witty-ultra-audit`; they are not committed production changes.

Remaining fidelity work is substantial: all inventory-only primary files, all unexamined branches in targeted large files, most large dependency bodies, source-selected native backends, all external ABI/layout/ownership contracts, generated-data regeneration, the unexamined branches of the 13 large Swift host files, and the remaining 132 smaller Swift host sources. The absence of a listed finding is not evidence of parity in those areas.

## Primary original-to-V inventory: all 99 big Zig sources

Mappings may be one-to-many or many-to-one. A named counterpart does not certify equivalence. Physical line counts are from the current pinned originals.

| Original (relative to Ghostty `src/` unless prefixed) | Lines | V counterpart(s) | Review | Status |
| --- | ---: | --- | --- | --- |
| `terminal/PageList.zig` | 14466 | `terminal/page_list.v` | targeted | gap-confirmed |
| `terminal/Terminal.zig` | 12431 | `terminal/terminal.v` | targeted | no-discrepancy-observed |
| `config/Config.zig` | 10411 | `configpkg/configpkg.v`<br>`configpkg/config_help.txt` | targeted | no-discrepancy-observed |
| `terminal/Screen.zig` | 10352 | `terminal/screen.v` | targeted | no-discrepancy-observed |
| `Surface.zig` | 6781 | `core/surface.v` | targeted | divergence-confirmed |
| `terminal/formatter.zig` | 5939 | `terminal/formatter.v` | targeted | no-discrepancy-observed |
| `input/Binding.zig` | 4816 | `input/binding.v`<br>`input/source_hash.v`<br>`input/case_folding_data.v` | targeted | no-discrepancy-observed |
| `apprt/gtk/class/surface.zig` | 4025 | `apprt/gtk/surface_class_linux.v` | targeted | no-discrepancy-observed |
| `terminal/page.zig` | 3861 | `terminal/page.v` | targeted | gap-confirmed |
| `terminal/stream.zig` | 3389 | `terminal/stream.v` | targeted | no-discrepancy-observed |
| `renderer/generic.zig` | 3335 | `renderer/renderer.v`<br>`renderer/config.v`<br>`renderer/renderer_darwin.c.v`<br>`renderer/renderer_linux.c.v`<br>`renderer/metal_types_darwin.c.v`<br>`renderer/opengl_types_linux.c.v` | targeted | divergence-confirmed |
| `apprt/gtk/class/application.zig` | 2836 | `apprt/gtk/application_linux.v` | targeted | gap-confirmed |
| `font/nerd_font_attributes.zig` | 2774 | `font/nerd_font_attributes.v` | targeted | no-discrepancy-observed |
| `font/shaper/coretext.zig` | 2678 | `font/shaper/coretext_darwin.c.v` | targeted | gap-confirmed |
| `input/key_encode.zig` | 2399 | `input/key_encode.v` | targeted | divergence-confirmed |
| `terminal/tmux/viewer.zig` | 2292 | `terminal/tmux_viewer.v` | targeted | no-discrepancy-observed |
| `datastruct/split_tree.zig` | 2273 | `datastruct/split_tree.v` | targeted | no-discrepancy-observed |
| `apprt/embedded.zig` | 2207 | `apprt/embedded.v`<br>`apprt/c_api.v`<br>`core/embedded_bridge.v`<br>`main_c.v` | targeted | no-discrepancy-observed |
| `font/shaper/harfbuzz.zig` | 2163 | `font/shaper/harfbuzz.v`<br>`font/font.v` | targeted | divergence-confirmed |
| `apprt/gtk/class/window.zig` | 2024 | `apprt/gtk/window_linux.v` | targeted | no-discrepancy-observed |
| `cli/list_themes.zig` | 1741 | `cli/list_themes.v`<br>`cli/list_themes_window.v`<br>`cli/list_themes_preview_window.v` | targeted | no-discrepancy-observed |
| `termio/Exec.zig` | 1739 | `termio/exec.v` | targeted | gap-confirmed |
| `terminal/search/sliding_window.zig` | 1676 | `search/sliding_window.v`<br>`search/circ_buf.v` | targeted | no-discrepancy-observed |
| `cli/args.zig` | 1627 | `cli_args/cli_args.v`<br>`cli_args/process_args_darwin.c.v`<br>`cli_args/process_args_default.c.v` | targeted | no-discrepancy-observed |
| `terminal/Selection.zig` | 1598 | `terminal/selection.v` | targeted | no-discrepancy-observed |
| `termio/stream_handler.zig` | 1551 | `termio/stream_handler.v` | targeted | no-discrepancy-observed |
| `terminal/hash_map.zig` | 1540 | `terminal/hash_map.v` | targeted | gap-confirmed |
| `font/Collection.zig` | 1523 | `font/collection.v` | targeted | no-discrepancy-observed |
| `terminal/search/screen.zig` | 1516 | `search/screen_search.v` | targeted | no-discrepancy-observed |
| `terminal/render.zig` | 1464 | `terminal/render.v` | targeted | no-discrepancy-observed |
| `font/face/freetype.zig` | 1436 | `font/face.v` | targeted | divergence-confirmed |
| `font/sprite/draw/symbols_for_legacy_computing.zig` | 1413 | `sprite/symbols_for_legacy_computing.v` | targeted | no-discrepancy-observed |
| `terminal/kitty/graphics_storage.zig` | 1359 | `terminal/kitty_graphics_storage.v` | targeted | no-discrepancy-observed |
| `terminal/kitty/graphics_unicode.zig` | 1347 | `terminal/kitty_graphics_unicode.v` | targeted | no-discrepancy-observed |
| `terminal/kitty/graphics_command.zig` | 1325 | `terminal/kitty_graphics_command.v` | targeted | no-discrepancy-observed |
| `apprt/gtk/class/split_tree.zig` | 1241 | `apprt/gtk/split_tree_class_linux.v` | targeted | no-discrepancy-observed |
| `font/face/coretext.zig` | 1162 | `font/face_coretext.v`<br>`macos/core_shims.h`<br>`macos/core_shims_darwin.c.v` | targeted | gap-confirmed |
| `terminal/osc/parsers/osc9.zig` | 1140 | `osc/osc9.v` | targeted | divergence-confirmed |
| `terminal/Parser.zig` | 1072 | `terminal/parser.v` | branch-reviewed | no-discrepancy-observed |
| `terminal/style.zig` | 1072 | `terminal/style.v` | targeted | no-discrepancy-observed |
| `terminal/sgr.zig` | 1070 | `terminal/sgr.v` | targeted | no-discrepancy-observed |
| `font/discovery.zig` | 1049 | `font/discovery.v`<br>`font/discovery_coretext_darwin.c.v`<br>`font/discovery_backend_darwin.c.v`<br>`font/discovery_backend_linux.c.v`<br>`font/discovery_backend_freebsd.c.v` | targeted | no-discrepancy-observed |
| `terminal/bitmap_allocator.zig` | 1021 | `terminal/bitmap_allocator.v` | branch-reviewed | no-discrepancy-observed |
| `termio/shell_integration.zig` | 1006 | `termio/shell_integration.v` | targeted | no-discrepancy-observed |
| `terminal/stream_readonly.zig` | 990 | `terminal/stream_readonly.v` | targeted | no-discrepancy-observed |
| `terminal/osc/parsers/semantic_prompt.zig` | 964 | `osc/semantic_prompt.v` | targeted | no-discrepancy-observed |
| `renderer/image.zig` | 958 | `renderer/image.v`<br>`renderer/image_darwin.c.v`<br>`renderer/image_linux.c.v` | targeted | no-discrepancy-observed |
| `font/sprite/draw/box.zig` | 929 | `sprite/block.v` | targeted | no-discrepancy-observed |
| `apprt/action.zig` | 918 | `apprt/action.v` | targeted | no-discrepancy-observed |
| `input/key_mods.zig` | 914 | `input/key_mods.v` | targeted | no-discrepancy-observed |
| `terminal/search/Thread.zig` | 905 | `search/search_thread.v` | targeted | divergence-confirmed |
| `build/SharedDeps.zig` | 897 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `font/Atlas.zig` | 889 | `font/font.v`<br>`font/atlas_wasm.v` | targeted | divergence-confirmed |
| `input/key.zig` | 879 | `input/input.v`<br>`input/key.v` | targeted | no-discrepancy-observed |
| `datastruct/circ_buf.zig` | 866 | `datastruct/circ_buf.v` | targeted | no-discrepancy-observed |
| `inspector/widgets/pagelist.zig` | 852 | `inspector/pagelist.v` | targeted | gap-confirmed |
| `terminal/kitty/graphics_image.zig` | 835 | `terminal/kitty_graphics_image.v` | targeted | divergence-confirmed |
| `font/SharedGridSet.zig` | 834 | `font/shared_grid_set.v` | targeted | no-discrepancy-observed |
| `font/Metrics.zig` | 816 | `font/font.v`<br>`font/face.v`<br>`font/shared_grid_set.v` | targeted | no-discrepancy-observed |
| `inspector/widgets/termio.zig` | 811 | `inspector/termio.v` | targeted | divergence-confirmed |
| `apprt/gtk/class/command_palette.zig` | 790 | `apprt/gtk/command_palette_linux.v` | targeted | divergence-confirmed |
| `terminal/osc/parsers/color.zig` | 780 | `osc/color_parser.v` | targeted | no-discrepancy-observed |
| `termio/Termio.zig` | 769 | `termio/termio.v` | targeted | no-discrepancy-observed |
| `input/command.zig` | 737 | `input/command.v` | targeted | no-discrepancy-observed |
| `inspector/widgets/terminal.zig` | 726 | `inspector/terminal.v` | targeted | no-discrepancy-observed |
| `terminal/tmux/control.zig` | 725 | `tmux/control.v` | targeted | divergence-confirmed |
| `Command.zig` | 717 | `command/command.v` | targeted | no-discrepancy-observed |
| `renderer/Thread.zig` | 717 | `renderer/thread.v` | targeted | no-discrepancy-observed |
| `terminal/ref_counted_set.zig` | 714 | `terminal/ref_counted_set.v` | targeted | gap-confirmed |
| `font/face.zig` | 707 | `font/face.v`<br>`font/font.v` | targeted | gap-confirmed |
| `terminal/osc.zig` | 697 | `osc/osc.v` | targeted | gap-confirmed |
| `terminal/color.zig` | 685 | `terminal/color.v` | targeted | no-discrepancy-observed |
| `renderer/cell.zig` | 680 | `renderer/cells.v` | targeted | no-discrepancy-observed |
| `input/keycodes.zig` | 673 | `input/keycodes.v` | targeted | gap-confirmed |
| `terminal/tmux/layout.zig` | 638 | `tmux/layout.v` | branch-reviewed | no-discrepancy-observed |
| `build/Config.zig` | 636 | `buildcfg/buildcfg.v`<br>`build_config.v` | targeted | gap-confirmed |
| `apprt/gtk/class/global_shortcuts.zig` | 633 | `apprt/gtk/global_shortcuts_linux.v` | targeted | divergence-confirmed |
| `font/sprite/draw/symbols_for_legacy_computing_supplement.zig` | 626 | `sprite/symbols_for_legacy_computing_supplement.v` | targeted | no-discrepancy-observed |
| `App.zig` | 613 | `core/app.v` | targeted | no-discrepancy-observed |
| `crash/sentry_envelope.zig` | 597 | `crash/envelope.v` | targeted | no-discrepancy-observed |
| `terminal/tmux/output.zig` | 590 | `tmux/output.v` | targeted | no-discrepancy-observed |
| `font/opentype/os2.zig` | 583 | `opentype/opentype.v` | targeted | no-discrepancy-observed |
| `terminal/kitty/graphics_exec.zig` | 570 | `terminal/kitty_graphics_exec.v` | targeted | no-discrepancy-observed |
| `font/CodepointResolver.zig` | 562 | `font/codepoint_resolver.v` | targeted | no-discrepancy-observed |
| `font/face/web_canvas.zig` | 561 | `font/face_web_canvas.v`<br>`font/face_web_canvas.js.v`<br>`font/face_web_canvas.c.v` | targeted | gap-confirmed |
| `font/sprite/Face.zig` | 550 | `sprite/face.v`<br>`font/codepoint_resolver.v`<br>`sprite/face_test.v` | targeted | divergence-confirmed |
| `cli/ssh-cache/DiskCache.zig` | 548 | `cli/ssh_cache.v` | targeted | divergence-confirmed |
| `apprt/gtk/class/imgui_widget.zig` | 541 | `apprt/gtk/imgui_widget_linux.v` | targeted | divergence-confirmed |
| `font/SharedGrid.zig` | 540 | `font/shared_grid.v` | targeted | no-discrepancy-observed |
| `apprt/gtk/key.zig` | 535 | `apprt/gtk/key_linux.v` | targeted | no-discrepancy-observed |
| `inspector/widgets/key.zig` | 535 | `inspector/inspector.v` | targeted | gap-confirmed |
| `termio/Thread.zig` | 531 | `termio/termio.v` | targeted | no-discrepancy-observed |
| `apprt/gtk/winproto/x11.zig` | 527 | `apprt/gtk/winproto_x11_linux.v`<br>`apprt/gtk/x11_shims.h` | targeted | no-discrepancy-observed |
| `apprt/gtk/winproto/wayland.zig` | 524 | `apprt/gtk/winproto_wayland_linux.v`<br>`apprt/gtk/wayland_shims.h` | targeted | no-discrepancy-observed |
| `font/sprite/canvas.zig` | 512 | `sprite/sprite.v`<br>`sprite/z2d_fill.v`<br>`sprite/z2d_stroke.v` | targeted | no-discrepancy-observed |
| `os/flatpak.zig` | 507 | `internal_os/flatpak.v`<br>`internal_os/flatpak_linux.c.v` | targeted | no-discrepancy-observed |
| `apprt/gtk/class/tab.zig` | 506 | `apprt/gtk/tab_linux.v` | targeted | no-discrepancy-observed |
| `font/sprite/draw/branch.zig` | 504 | `sprite/branch.v` | targeted | no-discrepancy-observed |
| `inspector/widgets/surface.zig` | 503 | `inspector/inspector.v`<br>`cimgui/ext.cpp` | targeted | gap-confirmed |

## Large native/API/reused-source inventory: 16 additional originals

Paths in this table are relative to the Ghostty repository root. The 13 Swift files and public header received direct targeted review; the two stb files were compared byte-for-byte. Partial helpers/custom-host mappings are not claims that the corresponding Swift controller is fully translated. The other three large non-Zig originals (Python/Python/Metal) appear in the additional-source inventory.

| Original (relative to the Ghostty root) | Lines | V counterpart(s) | Review | Status |
| --- | ---: | --- | --- | --- |
| `src/stb/stb_image.h` | 7987 | `stb/stb_image.h` | targeted | no-discrepancy-observed |
| `src/stb/stb_image_resize.h` | 2634 | `stb/stb_image_resize.h` | targeted | no-discrepancy-observed |
| `macos/Sources/Ghostty/Surface View/SurfaceView_AppKit.swift` | 2291 | `main_darwin.v`<br>`macos/appkit_darwin.c.v`<br>`macos/appkit_bridge.h`<br>`embedded_c_darwin.v`<br>`apprt/embedded.v` | targeted | gap-confirmed |
| `macos/Sources/Ghostty/Ghostty.App.swift` | 2093 | `main_darwin.v`<br>`main_c.v`<br>`apprt/embedded.v`<br>`apprt/runtime.v`<br>`macos/appkit_darwin.c.v` | targeted | gap-confirmed |
| `macos/Sources/Features/Terminal/TerminalController.swift` | 1633 | `main_darwin.v`<br>`macos/appkit_darwin.c.v` | targeted | gap-confirmed |
| `macos/Sources/Features/Terminal/BaseTerminalController.swift` | 1464 | `main_darwin.v`<br>`macos/appkit_darwin.c.v`<br>`apprt/embedded.v` | targeted | gap-confirmed |
| `macos/Sources/Features/Splits/SplitTree.swift` | 1362 | `datastruct/split_tree.v`<br>`main_darwin.v` | targeted | gap-confirmed |
| `macos/Sources/App/macOS/AppDelegate.swift` | 1343 | `main_darwin.v`<br>`macos/appkit_darwin.c.v` | targeted | gap-confirmed |
| `macos/Sources/Ghostty/Ghostty.Input.swift` | 1314 | `input/input.v`<br>`input/key.v`<br>`input/keycodes.v`<br>`apprt/embedded.v`<br>`main_darwin.v`<br>`macos/appkit_darwin.c.v` | targeted | gap-confirmed |
| `macos/Sources/Ghostty/Surface View/SurfaceView.swift` | 1262 | `main_darwin.v`<br>`macos/appkit_darwin.c.v`<br>`apprt/embedded.v`<br>`apprt/structs.v` | targeted | gap-confirmed |
| `include/ghostty.h` | 1160 | `main_c.v`<br>`config_c.v`<br>`embedded_c.v`<br>`embedded_c_darwin.v`<br>`apprt/action.v`<br>`apprt/c_api.v`<br>`apprt/embedded.v`<br>`apprt/ipc.v`<br>`core/embedded_bridge.v`<br>`configpkg/c_api.v`<br>`input/input.v`<br>`input/key.v`<br>`benchmark/benchmark.v` | targeted | divergence-confirmed |
| `macos/Sources/Ghostty/Ghostty.Config.swift` | 813 | `main_c.v`<br>`main_darwin.v`<br>`macos/appkit_darwin.c.v` | targeted | gap-confirmed |
| `macos/Sources/Features/QuickTerminal/QuickTerminalController.swift` | 783 | `main_darwin.v`<br>`macos/appkit_darwin.c.v`<br>`apprt/action.v` | targeted | gap-confirmed |
| `macos/Sources/Features/Terminal/Window Styles/TerminalWindow.swift` | 763 | `main_darwin.v`<br>`macos/appkit_darwin.c.v` | targeted | gap-confirmed |
| `macos/Sources/Features/Terminal/Window Styles/TitlebarTabsVenturaTerminalWindow.swift` | 716 | `macos/appkit_darwin.c.v` | targeted | gap-confirmed |
| `macos/Sources/Ghostty/Package.swift` | 501 | `apprt/action.v`<br>`apprt/embedded.v`<br>`main_c.v`<br>`main_darwin.v`<br>`macos/appkit_darwin.c.v` | targeted | gap-confirmed |

<details>
<summary>Per-file native review focus and source reuse identity</summary>

- `include/ghostty.h`: Major public declaration groups and their implementation projections, as described in PH01.
- `macos/Sources/App/macOS/AppDelegate.swift`: Quit/reopen branches and application secure restoration compared with native delegate registrations and callbacks
- `macos/Sources/Features/QuickTerminal/QuickTerminalController.swift`: Visibility/activation/Space tracking, focus-loss auto-hide, startup tree restoration and animation; dispatch unsupported
- `macos/Sources/Features/Splits/SplitTree.swift`: Insertion/removal/replacement, focus traversal/spatial branch, equalization, pixel resize, versioned encoding; generic Zig counterpart only partially related and disconnected from Darwin host
- `macos/Sources/Features/Terminal/BaseTerminalController.swift`: Split insertion/focus/tree undo, action notification handlers, mode-specific fullscreen transition
- `macos/Sources/Features/Terminal/TerminalController.swift`: Close-tab/window undo, grouped close state, native window restoration registration and state encoding
- `macos/Sources/Features/Terminal/Window Styles/TerminalWindow.swift`: Initial window configuration, appearance/opacity/blur and preferred surface background selection
- `macos/Sources/Features/Terminal/Window Styles/TitlebarTabsVenturaTerminalWindow.swift`: Theme/titlebar tab updates and tab accessory/toolbar relocation branches; no equivalent native subclass
- `macos/Sources/Ghostty/Ghostty.App.swift`: Compared app lifetime/callback installation/focus/keyboard/tick, app vs surface reload, clipboard request/write/confirm flows, full action switch against standalone runtime_action and representative helper branches for tabs/close/fullscreen/native state/notifications/search/progress. Missing native families confirmed (SB-03); surface-only reload becomes app-wide (SB-06). Source non-macOS callbacks and SIZE_LIMIT/QUIT_TIMER were not newly flagged.
- `macos/Sources/Ghostty/Ghostty.Config.swift`: Load/default/CLI/recursive/finalize/clone/lifetime and typed get accessors inspected; menu-trigger conversion and window/native configuration projections compared to actual standalone host. Missing config-derived menu synchronization (SB-05); source native configuration application also belongs to existing S07. No full config-field equivalence certification.
- `macos/Sources/Ghostty/Ghostty.Input.swift`: Compared forward/reverse modifier conversion, sided flags, binding flags/key event fields, action/mouse mappings, scroll packing/momentum, physical-key switch samples and AppEnum metadata. Modifiers/mouse/scroll branches agree in targeted checks; native menu-trigger helper is omitted (SB-05). AppIntents metadata has no nativehost counterpart. Not a full 194-key table proof.
- `macos/Sources/Ghostty/Package.swift`: Read build-info/launch-source/allocated-string helpers; float/secure/split/clipboard enum conversions; icon/window enums; all notification definitions. Generic CAPI/action data representations retained in V, but desktop-notification/category and several native event consumers are absent (SB-03). Swift namespace/deinit differences alone not defects.
- `macos/Sources/Ghostty/Surface View/SurfaceView.swift`: Compared wrapper overlay/order/focus observations, resize hide/timer/placement, search editing/debounce/navigation/focus/counts, SurfaceConfiguration/C lifetime/env fields, key-state pill, progress/readonly/bell/highlight surfaces, focus-backoff/environment/SearchState. SurfaceOptions representation is retained; native overlay/search logic absent (SB-03).
- `macos/Sources/Ghostty/Surface View/SurfaceView_AppKit.swift`: Compared surface state/init/deinit/focus/size/cursor, title timers/user titles, source notification consumers, screen changes, tracking/mouse/scroll/pressure, keydown/up/flags/keyequivalents, QuickLook/actions, notifications/Codable, NSTextInputClient, Services, drag/drop/accessibility and cache helper. Missing composition/responder/interfaces/native action consumers and display wiring confirmed (SB-01..04). No native GUI behavior certification.
- `src/stb/stb_image.h`: Full byte comparison, reused upstream source; SHA-256 `7fb1521970dc268639ed95ab9808ef3b47aa0800fd2d0e9250b1b90be03ee75b` (same on both sides)
- `src/stb/stb_image_resize.h`: Full byte comparison, reused upstream source; SHA-256 `6a0e75adbabb48df9031c2e39ccd97437bb226fe31e7d4a01c7bf70a18d32ec6` (same on both sides)

</details>

## Primary original-to-V inventory: remaining 357 Zig sources

Smaller source mappings are retained so files with no direct counterpart and inventory-only uncertainty remain visible.

<details>
<summary>All remaining primary Zig mappings and review status</summary>

| Original (relative to Ghostty `src/` unless prefixed) | Lines | V counterpart(s) | Review | Status |
| --- | ---: | --- | --- | --- |
| `config/path.zig` | 496 | `configpkg/configpkg.v` | inventory-only | unverified |
| `apprt/gtk/class/search_overlay.zig` | 493 | `apprt/gtk/search_overlay_linux.v` | inventory-only | unverified |
| `font/DeferredFace.zig` | 463 | `font/face.v`<br>`font/face_coretext.v`<br>`font/face_web_canvas.v` | inventory-only | unverified |
| `renderer/OpenGL.zig` | 461 | `renderer/opengl_linux.c.v`<br>`renderer/platform_linux.c.v` | targeted | no-discrepancy-observed |
| `renderer/Metal.zig` | 458 | `renderer/metal_darwin.c.v`<br>`macos/appkit_darwin.c.v`<br>`macos/appkit_bridge.h` | targeted | no-discrepancy-observed |
| `renderer/metal/shaders.zig` | 454 | `renderer/metal_types_darwin.c.v`<br>`macos/appkit_bridge.h` | targeted | divergence-confirmed |
| `renderer/metal/api.zig` | 452 | `renderer/metal_darwin.c.v`<br>`macos/appkit_bridge.h` | inventory-only | unverified |
| `build/GhosttyResources.zig` | 442 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `terminal/search/pagelist.zig` | 441 | `search/pagelist_search.v` | inventory-only | unverified |
| `cli/list_keybinds.zig` | 435 | `cli/actions.v`<br>`cli/list_pretty.v` | inventory-only | unverified |
| `terminal/osc/parsers/iterm2.zig` | 435 | `osc/iterm2_parser.v` | inventory-only | unverified |
| `datastruct/comparison.zig` | 430 | `datastruct/comparison/comparison.v` | inventory-only | unverified |
| `terminal/dcs.zig` | 430 | `terminal/dcs.v` | targeted | no-discrepancy-observed |
| `inspector/widgets/page.zig` | 428 | `inspector/page.v` | targeted | no-discrepancy-observed |
| `cli/CommaSplitter.zig` | 424 | `comma_splitter/comma_splitter.v` | inventory-only | unverified |
| `renderer/shadertoy.zig` | 424 | `renderer/shadertoy.v` | targeted | divergence-confirmed |
| `pty.zig` | 422 | `pty/pty.v`<br>`pty/pty_shims.h` | targeted | gap-confirmed |
| `renderer/Overlay.zig` | 415 | `renderer/overlay.v` | inventory-only | unverified |
| `font/shaper/run.zig` | 409 | `font/font.v`<br>`font/shaper/run.v` | targeted | no-discrepancy-observed |
| `inspector/widgets/screen.zig` | 400 | `inspector/screen.v` | inventory-only | unverified |
| `renderer/size.zig` | 397 | `renderer/size.v` | inventory-only | unverified |
| `terminfo/ghostty.zig` | 397 | `terminfo/ghostty.v`<br>`terminfo/terminfo.v` | targeted | no-discrepancy-observed |
| `font/sprite/draw/powerline.zig` | 394 | `sprite/powerline.v` | targeted | no-discrepancy-observed |
| `terminal/parse_table.zig` | 388 | `terminal/parse_table.v` | inventory-only | unverified |
| `terminal/search/viewport.zig` | 384 | `search/viewport_search.v` | inventory-only | unverified |
| `renderer/opengl/shaders.zig` | 376 | `renderer/opengl_types_linux.c.v`<br>`renderer/opengl_linux.c.v` | inventory-only | unverified |
| `font/sprite/draw/common.zig` | 374 | `sprite/common.v` | targeted | no-discrepancy-observed |
| `font/sprite/draw/special.zig` | 372 | `sprite/special.v` | targeted | no-discrepancy-observed |
| `apprt/gtk/class.zig` | 367 | `apprt/gtk/gobject_c_linux.v`<br>`apprt/gtk/gobject_shims.h` | targeted | no-discrepancy-observed |
| `synthetic/Osc.zig` | 366 | `synthetic/osc.v` | targeted | divergence-confirmed |
| `font/shaper/feature.zig` | 354 | `font/shaper/feature.v` | targeted | no-discrepancy-observed |
| `apprt/gtk/class/clipboard_confirmation_dialog.zig` | 352 | `apprt/gtk/clipboard_confirmation_dialog_linux.v` | inventory-only | unverified |
| `datastruct/lru.zig` | 349 | `datastruct/lru/lru.v` | inventory-only | unverified |
| `apprt/gtk/class/key_state_overlay.zig` | 342 | `apprt/gtk/key_state_overlay_linux.v` | inventory-only | unverified |
| `apprt/gtk/class/resize_overlay.zig` | 338 | `apprt/gtk/resize_overlay_linux.v` | inventory-only | unverified |
| `surface_mouse.zig` | 336 | `core/surface_mouse.v` | branch-reviewed | no-discrepancy-observed |
| `config/formatter.zig` | 333 | `configpkg/formatter.v` | inventory-only | unverified |
| `extra/bash.zig` | 329 | `extra/vim.v`<br>`extra/completions.v`<br>`extra/sublime.v` | inventory-only | unverified |
| `renderer/link.zig` | 322 | `renderer/link.v` | inventory-only | unverified |
| `config/url.zig` | 321 | `configpkg/url.v` | inventory-only | unverified |
| `config/command.zig` | 320 | `configpkg/configpkg.v`<br>`input/command.v` | inventory-only | unverified |
| `crash/sentry.zig` | 317 | `crash/crash.v` | targeted | divergence-confirmed |
| `font/opentype/sfnt.zig` | 312 | `opentype/opentype.v` | inventory-only | unverified |
| `input/function_keys.zig` | 312 | `input/function_keys.v` | inventory-only | unverified |
| `os/xdg.zig` | 308 | `internal_os/xdg.v` | inventory-only | unverified |
| `font/shaper/web_canvas.zig` | 305 | `font/shaper/web_canvas.v` | targeted | gap-confirmed |
| `cli/ghostty.zig` | 302 | `main_c.v`<br>`global_state/global_state.v` | inventory-only | unverified |
| `input/KeymapDarwin.zig` | 289 | `input/keymap_darwin.c.v`<br>`input/keymap_shims.h` | targeted | no-discrepancy-observed |
| `tripwire.zig` | 288 | `tripwire/tripwire.v` | inventory-only | unverified |
| `terminal/c/key_encode.zig` | 287 | `terminal_c/terminal_c.v`<br>`lib_vt_c.v` | targeted | divergence-confirmed |
| `os/string_encoding.zig` | 280 | `internal_os/string_encoding.v` | inventory-only | unverified |
| `apprt/gtk/build/gresource.zig` | 279 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `cli/action.zig` | 277 | `cli/action_help.v` | inventory-only | unverified |
| `config/theme.zig` | 277 | `themepkg/themepkg.v` | targeted | no-discrepancy-observed |
| `terminal/StringMap.zig` | 277 | `terminal/string_map.v` | branch-reviewed | no-discrepancy-observed |
| `terminal/Tabstops.zig` | 271 | `terminal/tabstops.v` | inventory-only | unverified |
| `terminal/c/key_event.zig` | 268 | `terminal_c/terminal_c.v`<br>`lib_vt_c.v` | targeted | divergence-confirmed |
| `apprt/gtk/class/surface_child_exited.zig` | 264 | `apprt/gtk/surface_child_exited_linux.v` | inventory-only | unverified |
| `lib/allocator.zig` | 264 | `lib_allocator/allocator.v` | targeted | divergence-confirmed |
| `terminal/modes.zig` | 261 | `terminal/modes.v` | inventory-only | unverified |
| `terminal/osc/parsers/kitty_text_sizing.zig` | 257 | `osc/kitty_text_sizing.v` | inventory-only | unverified |
| `config/io.zig` | 254 | `configpkg/configpkg.v` | inventory-only | unverified |
| `os/cgroup.zig` | 254 | `internal_os/cgroup.v`<br>`internal_os/cgroup_linux.c.v`<br>`internal_os/cgroup_darwin.c.v` | inventory-only | unverified |
| `datastruct/blocking_queue.zig` | 248 | `datastruct/blocking_queue.v` | inventory-only | unverified |
| `apprt/gtk/class/inspector_widget.zig` | 245 | `apprt/gtk/inspector_window_linux.v` | inventory-only | unverified |
| `terminfo/Source.zig` | 243 | `terminfo/ghostty.v`<br>`terminfo/terminfo.v` | targeted | no-discrepancy-observed |
| `config/c_get.zig` | 240 | `configpkg/c_api.v` | targeted | divergence-confirmed |
| `terminal/hyperlink.zig` | 240 | `terminal/hyperlink.v` | inventory-only | unverified |
| `cli/show_face.zig` | 239 | `cli/show_face.v` | inventory-only | unverified |
| `cli/boo.zig` | 236 | `cli/boo.v` | inventory-only | unverified |
| `global.zig` | 235 | `global_state/global_state.v` | targeted | divergence-confirmed |
| `extra/zsh.zig` | 231 | `extra/vim.v`<br>`extra/completions.v`<br>`extra/sublime.v` | inventory-only | unverified |
| `renderer/metal/RenderPass.zig` | 229 | `renderer/metal_types_darwin.c.v`<br>`macos/appkit_bridge.h` | targeted | no-discrepancy-observed |
| `cli/ssh_cache.zig` | 228 | `cli/ssh_cache.v` | inventory-only | unverified |
| `inspector/widgets.zig` | 227 | `inspector/terminal.v`<br>`inspector/inspector.v` | inventory-only | unverified |
| `terminal/size.zig` | 227 | `terminal/size.v` | inventory-only | unverified |
| `os/locale.zig` | 218 | `internal_os/locale.v`<br>`internal_os/locale_darwin.c.v` | targeted | no-discrepancy-observed |
| `apprt/gtk/class/inspector_window.zig` | 217 | `apprt/gtk/inspector_window_linux.v` | inventory-only | unverified |
| `main_ghostty.zig` | 213 | `main_darwin.v`<br>`main_linux.v`<br>`global_state/global_state.v` | targeted | divergence-confirmed |
| `terminal/highlight.zig` | 213 | `highlight/highlight.v` | branch-reviewed | no-discrepancy-observed |
| `terminal/osc/parsers/kitty_color.zig` | 212 | `osc/kitty_color.v` | inventory-only | unverified |
| `apprt/gtk/cgroup.zig` | 210 | `apprt/gtk/cgroup_linux.v` | inventory-only | unverified |
| `cli/list_colors.zig` | 209 | `cli/actions.v`<br>`cli/list_pretty.v` | inventory-only | unverified |
| `apprt/gtk/class/surface_scrolled_window.zig` | 208 | `apprt/gtk/surface_scrolled_window_linux.v` | inventory-only | unverified |
| `apprt/gtk/class/close_confirmation_dialog.zig` | 204 | `apprt/gtk/close_confirmation_dialog_linux.v` | inventory-only | unverified |
| `os/uri.zig` | 204 | `internal_os/uri.v` | inventory-only | unverified |
| `renderer/metal/Pipeline.zig` | 204 | `renderer/metal_types_darwin.c.v`<br>`macos/appkit_bridge.h` | inventory-only | unverified |
| `extra/fish.zig` | 202 | `extra/vim.v`<br>`extra/completions.v`<br>`extra/sublime.v` | inventory-only | unverified |
| `renderer/metal/Texture.zig` | 202 | `renderer/metal_types_darwin.c.v`<br>`macos/appkit_bridge.h` | inventory-only | unverified |
| `benchmark/CodepointWidth.zig` | 201 | `benchmark/benchmark.v` | targeted | no-discrepancy-observed |
| `build/GhosttyXcodebuild.zig` | 201 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `apprt/gtk/ext/actions.zig` | 198 | `apprt/gtk/ext_actions_linux.v` | inventory-only | unverified |
| `config/RepeatableStringMap.zig` | 198 | `configpkg/configpkg.v` | inventory-only | unverified |
| `font/sprite/draw/geometric_shapes.zig` | 198 | `sprite/geometric_shapes.v` | targeted | no-discrepancy-observed |
| `os/systemd.zig` | 198 | `internal_os/systemd.v`<br>`internal_os/systemd_linux.c.v` | inventory-only | unverified |
| `apprt/surface.zig` | 197 | `apprt/surface.v` | inventory-only | unverified |
| `cli/diagnostics.zig` | 197 | `diagnostics/diagnostics.v` | inventory-only | unverified |
| `main_c.zig` | 197 | `main_c.v` | targeted | divergence-confirmed |
| `apprt/gtk/ipc/DBus.zig` | 196 | `apprt/gtk/ipc_dbus_linux.v` | inventory-only | unverified |
| `benchmark/ScreenClone.zig` | 196 | `benchmark/benchmark.v` | targeted | no-discrepancy-observed |
| `os/shell.zig` | 196 | `internal_os/internal_os.v` | inventory-only | unverified |
| `simd/vt.zig` | 196 | `simd/vt.v` | targeted | divergence-confirmed |
| `os/i18n.zig` | 193 | `internal_os/i18n.v` | targeted | divergence-confirmed |
| `os/cf_release_thread.zig` | 191 | `internal_os/cf_release_thread_darwin.c.v` | inventory-only | unverified |
| `build/GhosttyDist.zig` | 190 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `helpgen.zig` | 190 | `helpgen.v`<br>`input/helpgen.v` | inventory-only | unverified |
| `lib_vt.zig` | 190 | `lib_vt.v`<br>`lib_vt_c.v`<br>`terminal_c/terminal_c.v` | inventory-only | unverified |
| `apprt/gtk/class/surface_title_dialog.zig` | 189 | `apprt/gtk/surface_title_dialog_linux.v` | inventory-only | unverified |
| `unicode/lut.zig` | 188 | `unicode/lut.v` | targeted | no-discrepancy-observed |
| `terminal/apc.zig` | 186 | `terminal/apc.v` | inventory-only | unverified |
| `renderer/metal/buffer.zig` | 185 | `renderer/metal_types_darwin.c.v`<br>`macos/appkit_bridge.h` | targeted | no-discrepancy-observed |
| `apprt/ipc.zig` | 183 | `apprt/ipc.v` | inventory-only | unverified |
| `renderer/metal/IOSurfaceLayer.zig` | 183 | `renderer/metal_types_darwin.c.v`<br>`macos/appkit_bridge.h` | inventory-only | unverified |
| `datastruct/cache_table.zig` | 181 | `datastruct/cache_table.v` | targeted | no-discrepancy-observed |
| `datastruct/intrusive_linked_list.zig` | 181 | `datastruct/intrusive_linked_list.v` | inventory-only | unverified |
| `os/homedir.zig` | 181 | `internal_os/internal_os.v`<br>`internal_os/home_darwin.c.v` | inventory-only | unverified |
| `unicode/grapheme.zig` | 180 | `unicode/grapheme.v` | targeted | no-discrepancy-observed |
| `cli/new_window.zig` | 179 | `cli/new_window.v` | inventory-only | unverified |
| `font/opentype/head.zig` | 179 | `opentype/opentype.v` | inventory-only | unverified |
| `terminal/c/sgr.zig` | 179 | `terminal_c/terminal_c.v`<br>`lib_vt_c.v` | targeted | no-discrepancy-observed |
| `os/env.zig` | 178 | `internal_os/internal_os.v` | inventory-only | unverified |
| `font/sprite/draw/block.zig` | 177 | `sprite/block.v` | targeted | no-discrepancy-observed |
| `os/macos.zig` | 177 | `internal_os/macos_darwin.c.v` | inventory-only | unverified |
| `apprt/gtk/class/config.zig` | 175 | `apprt/gtk/config_class_linux.v` | inventory-only | unverified |
| `terminal/search/active.zig` | 175 | `search/active_search.v` | inventory-only | unverified |
| `apprt/gtk/build/blueprint.zig` | 174 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `benchmark/Benchmark.zig` | 173 | `benchmark/benchmark_core.v`<br>`benchmark/signpost_darwin.c.v`<br>`benchmark/signpost_default.c.v` | targeted | no-discrepancy-observed |
| `lib/union.zig` | 171 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `terminal/kitty/key.zig` | 169 | `terminal/types.v` | inventory-only | unverified |
| `cli/edit_config.zig` | 168 | `cli/actions.v` | inventory-only | unverified |
| `build/GhosttyI18n.zig` | 166 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `config/file_load.zig` | 166 | `configpkg/configpkg.v` | inventory-only | unverified |
| `cli/list_fonts.zig` | 165 | `cli/actions.v` | inventory-only | unverified |
| `renderer/opengl/Pipeline.zig` | 164 | `renderer/opengl_types_linux.c.v`<br>`renderer/opengl_linux.c.v` | inventory-only | unverified |
| `terminal/osc/parsers/hyperlink.zig` | 164 | `osc/hyperlink_parser.v` | inventory-only | unverified |
| `benchmark/TerminalStream.zig` | 162 | `benchmark/benchmark.v` | targeted | no-discrepancy-observed |
| `apprt/gtk/class/config_errors_dialog.zig` | 161 | `apprt/gtk/config_errors_dialog_linux.v` | inventory-only | unverified |
| `os/desktop.zig` | 160 | `internal_os/platform.v` | inventory-only | unverified |
| `os/passwd.zig` | 157 | `internal_os/internal_os.v` | inventory-only | unverified |
| `apprt/gtk/winproto.zig` | 155 | `apprt/gtk/winproto_linux.v` | inventory-only | unverified |
| `build/GhosttyLib.zig` | 155 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `cli/ssh-cache/Entry.zig` | 154 | `cli/ssh_cache.v` | targeted | no-discrepancy-observed |
| `renderer/cursor.zig` | 154 | `renderer/cursor.v` | inventory-only | unverified |
| `benchmark/GraphemeBreak.zig` | 152 | `benchmark/benchmark.v` | targeted | no-discrepancy-observed |
| `benchmark/IsSymbol.zig` | 151 | `benchmark/benchmark.v` | targeted | no-discrepancy-observed |
| `os/mach.zig` | 150 | `internal_os/mach.v`<br>`internal_os/mach_memory.h` | inventory-only | unverified |
| `font/sprite/draw/braille.zig` | 148 | `sprite/braille.v` | targeted | no-discrepancy-observed |
| `simd/base64_scalar.zig` | 147 | `simd/base64_scalar.v` | targeted | divergence-confirmed |
| `config/CApi.zig` | 146 | `config_c.v`<br>`configpkg/c_api.v` | targeted | divergence-confirmed |
| `input/paste.zig` | 145 | `input/paste.v` | targeted | no-discrepancy-observed |
| `renderer/opengl/RenderPass.zig` | 144 | `renderer/opengl_types_linux.c.v`<br>`renderer/opengl_linux.c.v` | inventory-only | unverified |
| `font/shaper/noop.zig` | 143 | `font/shaper/noop.v` | targeted | gap-confirmed |
| `terminal/UTF8Decoder.zig` | 142 | `terminal/utf8decoder.v` | branch-reviewed | no-discrepancy-observed |
| `apprt/gtk/gtk_version.zig` | 140 | `apprt/gtk/version_linux.v` | inventory-only | unverified |
| `os/resourcesdir.zig` | 139 | `internal_os/resources_dir.v` | inventory-only | unverified |
| `terminal/c/osc.zig` | 139 | `terminal_c/terminal_c.v`<br>`lib_vt_c.v` | targeted | gap-confirmed |
| `build/webgen/main_config.zig` | 134 | `build/docs.v` | inventory-only | unverified |
| `input/kitty.zig` | 134 | `input/kitty.v` | inventory-only | unverified |
| `terminal/mouse_shape.zig` | 133 | `terminal/mouse_shape.v` | inventory-only | unverified |
| `inspector/Inspector.zig` | 131 | `inspector/inspector.v` | inventory-only | unverified |
| `renderer/metal/Frame.zig` | 131 | `renderer/metal_types_darwin.c.v`<br>`macos/appkit_bridge.h` | inventory-only | unverified |
| `os/args.zig` | 130 | `internal_os/internal_os.v`<br>`internal_os/args_default.c.v`<br>`internal_os/args_macos.c.v` | inventory-only | unverified |
| `os/windows.zig` | 128 | `internal_os/windows.v` | inventory-only | unverified |
| `build/GhosttyExe.zig` | 126 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `renderer/opengl/buffer.zig` | 126 | `renderer/opengl_types_linux.c.v`<br>`renderer/opengl_linux.c.v` | inventory-only | unverified |
| `font/CodepointMap.zig` | 125 | `font/codepoint_map.v` | inventory-only | unverified |
| `inspector/widgets/style.zig` | 125 | `inspector/screen.v` | inventory-only | unverified |
| `build/GhosttyDocs.zig` | 124 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `datastruct/message_data.zig` | 124 | `datastruct/message_data.v` | inventory-only | unverified |
| `inspector/widgets/renderer.zig` | 123 | `inspector/inspector.v` | inventory-only | unverified |
| `renderer/State.zig` | 123 | `renderer/state.v` | inventory-only | unverified |
| `apprt/gtk/adw_version.zig` | 122 | `apprt/gtk/version_linux.v` | inventory-only | unverified |
| `os/hostname.zig` | 122 | `internal_os/hostname.v` | inventory-only | unverified |
| `build/GhosttyWebdata.zig` | 119 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `synthetic/Bytes.zig` | 119 | `synthetic/bytes.v` | targeted | divergence-confirmed |
| `terminal/osc/parsers/change_window_title.zig` | 119 | `osc/change_window_title.v` | inventory-only | unverified |
| `termio/backend.zig` | 119 | `termio/termio.v` | inventory-only | unverified |
| `benchmark/OscParser.zig` | 118 | `benchmark/benchmark.v` | targeted | no-discrepancy-observed |
| `extra/vim.zig` | 118 | `extra/vim.v`<br>`extra/completions.v`<br>`extra/sublime.v` | inventory-only | unverified |
| `terminal/ansi.zig` | 118 | `terminal/ansi.v` | inventory-only | unverified |
| `build/GhosttyLibVt.zig` | 117 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `build/mdgen/mdgen.zig` | 117 | `build/docs.v` | inventory-only | unverified |
| `font/opentype/hhea.zig` | 116 | `opentype/opentype.v` | inventory-only | unverified |
| `synthetic/cli.zig` | 115 | `synthetic/cli.v` | targeted | divergence-confirmed |
| `terminal/charsets.zig` | 115 | `terminal/charsets.v` | inventory-only | unverified |
| `font/opentype/svg.zig` | 114 | `opentype/opentype.v` | inventory-only | unverified |
| `termio/message.zig` | 113 | `termio/termio.v` | inventory-only | unverified |
| `input/helpgen_actions.zig` | 112 | `input/helpgen.v`<br>`input/keybind_action_help.txt` | inventory-only | unverified |
| `apprt/gtk/ext/slice.zig` | 111 | `apprt/gtk/ext_slice_linux.v` | inventory-only | unverified |
| `renderer/message.zig` | 111 | `renderer/message.v` | inventory-only | unverified |
| `apprt/structs.zig` | 110 | `apprt/structs.v` | inventory-only | unverified |
| `font/backend.zig` | 110 | `font/backend.v` | targeted | no-discrepancy-observed |
| `benchmark/TerminalParser.zig` | 108 | `benchmark/benchmark.v` | targeted | no-discrepancy-observed |
| `renderer/metal/Target.zig` | 108 | `renderer/metal_types_darwin.c.v`<br>`macos/appkit_bridge.h` | inventory-only | unverified |
| `synthetic/Utf8.zig` | 108 | `synthetic/utf8.v` | targeted | divergence-confirmed |
| `font/shaper/Cache.zig` | 106 | `font/shaper/cache.v`<br>`font/font.v` | inventory-only | unverified |
| `terminal/ScreenSet.zig` | 106 | `terminal/screen_set.v` | inventory-only | unverified |
| `terminal/osc/parsers/clipboard_operation.zig` | 106 | `osc/clipboard_parser.v` | inventory-only | unverified |
| `termio/mailbox.zig` | 106 | `termio/termio.v` | inventory-only | unverified |
| `build_config.zig` | 105 | `build_config.v`<br>`buildcfg/buildcfg.v`<br>`build_meta/build_meta.v` | targeted | divergence-confirmed |
| `build/GhosttyXCFramework.zig` | 104 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `config/edit.zig` | 104 | `configpkg/edit.c.v` | inventory-only | unverified |
| `input/mouse.zig` | 104 | `input/input.v` | inventory-only | unverified |
| `renderer/opengl/Texture.zig` | 104 | `renderer/opengl_types_linux.c.v`<br>`renderer/opengl_linux.c.v` | inventory-only | unverified |
| `apprt/gtk/Surface.zig` | 103 | `apprt/gtk/surface_linux.v` | inventory-only | unverified |
| `build/uucode_config.zig` | 102 | `unicode/properties.v` | targeted | gap-confirmed |
| `file_type.zig` | 102 | `file_type/file_type.v` | targeted | no-discrepancy-observed |
| `apprt/gtk/gsettings.zig` | 101 | `apprt/gtk/gsettings_linux.v` | inventory-only | unverified |
| `font/shape.zig` | 101 | `font/font.v`<br>`font/shaper/run.v` | targeted | gap-confirmed |
| `benchmark/cli.zig` | 100 | `benchmark/benchmark.v` | targeted | no-discrepancy-observed |
| `apprt/gtk/App.zig` | 99 | `apprt/gtk/app_linux.v` | inventory-only | unverified |
| `datastruct/segmented_pool.zig` | 95 | `datastruct/segmented_pool.v` | targeted | no-discrepancy-observed |
| `os/TempDir.zig` | 95 | `internal_os/internal_os.v` | inventory-only | unverified |
| `config/conditional.zig` | 94 | `configpkg/configpkg.v` | inventory-only | unverified |
| `cli/crash_report.zig` | 93 | `cli/crash_report.v` | inventory-only | unverified |
| `lib/enum.zig` | 93 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `build/UnicodeTables.zig` | 92 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `apprt/gtk/class/dialog.zig` | 91 | `apprt/gtk/dialog_linux.v` | inventory-only | unverified |
| `os/path.zig` | 89 | `internal_os/internal_os.v` | inventory-only | unverified |
| `simd/base64.zig` | 87 | `simd/base64.v` | targeted | divergence-confirmed |
| `cli/show_config.zig` | 86 | `cli/actions.v` | inventory-only | unverified |
| `build/GhosttyZig.zig` | 85 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `os/open.zig` | 85 | `internal_os/internal_os.v` | inventory-only | unverified |
| `build/MetallibStep.zig` | 84 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `build/GitVersion.zig` | 83 | `build_meta/build_meta.v` | targeted | divergence-confirmed |
| `unicode/props_uucode.zig` | 83 | `unicode/properties.v` | targeted | no-discrepancy-observed |
| `font/main.zig` | 82 | `font/font.v` | inventory-only | unverified |
| `font/opentype/post.zig` | 82 | `opentype/opentype.v` | inventory-only | unverified |
| `synthetic/cli/Osc.zig` | 82 | `synthetic/osc.v` | targeted | divergence-confirmed |
| `terminal/main.zig` | 82 | `terminal/main_exports.v`<br>`terminal/types.v`<br>`terminal/terminal.v` | targeted | no-discrepancy-observed |
| `terminal/point.zig` | 82 | `terminal/point.v` | inventory-only | unverified |
| `os/main.zig` | 81 | `internal_os/internal_os.v`<br>`internal_os/platform.v` | inventory-only | unverified |
| `input/Link.zig` | 79 | `input/input.v` | targeted | no-discrepancy-observed |
| `os/file.zig` | 79 | `internal_os/internal_os.v` | inventory-only | unverified |
| `cli/help.zig` | 78 | `cli/help.v` | inventory-only | unverified |
| `cli/validate_config.zig` | 78 | `cli/actions.v` | inventory-only | unverified |
| `fastmem.zig` | 78 | `fastmem/fastmem.v` | branch-reviewed | no-discrepancy-observed |
| `build/XCFrameworkStep.zig` | 77 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `terminal/kitty/color.zig` | 77 | `osc/kitty_color.v` | targeted | no-discrepancy-observed |
| `cli/version.zig` | 76 | `cli/version.v` | inventory-only | unverified |
| `apprt/gtk/winproto/noop.zig` | 75 | `apprt/gtk/winproto_noop_linux.v` | inventory-only | unverified |
| `build/GhosttyFrameData.zig` | 75 | `renderer/renderer.v` | no-counterpart | gap-confirmed |
| `renderer/opengl/Frame.zig` | 71 | `renderer/opengl_types_linux.c.v`<br>`renderer/opengl_linux.c.v` | inventory-only | unverified |
| `apprt/gtk/ext.zig` | 70 | `apprt/gtk/ext_linux.v` | inventory-only | unverified |
| `synthetic/cli/Ascii.zig` | 68 | `synthetic/cli.v` | targeted | divergence-confirmed |
| `unicode/symbols_uucode.zig` | 68 | `unicode/properties.v` | targeted | no-discrepancy-observed |
| `config/string.zig` | 67 | `configpkg/configpkg.v` | inventory-only | unverified |
| `terminal/device_status.zig` | 67 | `terminal/device_status.v` | inventory-only | unverified |
| `crash/dir.zig` | 66 | `crash/crash.v` | targeted | no-discrepancy-observed |
| `terminal/c/main.zig` | 65 | `terminal_c/terminal_c.v`<br>`lib_vt_c.v` | targeted | no-discrepancy-observed |
| `renderer/metal/Sampler.zig` | 64 | `renderer/metal_types_darwin.c.v`<br>`macos/appkit_bridge.h` | inventory-only | unverified |
| `font/library.zig` | 63 | `font/face.v` | targeted | gap-confirmed |
| `renderer/row.zig` | 63 | `renderer/row.v` | inventory-only | unverified |
| `terminal/x11_color.zig` | 63 | `terminal/x11_color.v`<br>`x11rgb/x11rgb.v` | inventory-only | unverified |
| `apprt/gtk/ipc/new_window.zig` | 62 | `apprt/gtk/ipc_new_window_linux.v` | inventory-only | unverified |
| `renderer.zig` | 61 | `renderer/renderer.v`<br>`renderer/backend.v`<br>`renderer/options.v` | inventory-only | unverified |
| `renderer/opengl/Target.zig` | 60 | `renderer/opengl_types_linux.c.v`<br>`renderer/opengl_linux.c.v` | inventory-only | unverified |
| `apprt.zig` | 59 | `apprt/apprt.v`<br>`apprt/runtime.v`<br>`apprt/resources_dir.v` | inventory-only | unverified |
| `lib/allocator/convenience.zig` | 59 | `lib_allocator/convenience.v` | targeted | no-discrepancy-observed |
| `terminal/osc/parsers/rxvt_extension.zig` | 59 | `osc/rxvt_extension.v` | inventory-only | unverified |
| `input/keyboard.zig` | 58 | `input/input.v` | targeted | no-discrepancy-observed |
| `synthetic/cli/Utf8.zig` | 58 | `synthetic/utf8.v` | targeted | divergence-confirmed |
| `terminal/build_options.zig` | 58 | `terminal/build_options.v` | targeted | no-discrepancy-observed |
| `config/key.zig` | 57 | `configpkg/key.v` | inventory-only | unverified |
| `quirks.zig` | 57 | `quirks/quirks.v` | targeted | no-discrepancy-observed |
| `terminal/csi.zig` | 57 | `terminal/csi.v` | inventory-only | unverified |
| `build/HelpStrings.zig` | 56 | `helpgen.v`<br>`input/helpgen.v` | targeted | gap-confirmed |
| `os/i18n_locales.zig` | 56 | `internal_os/i18n.v` | inventory-only | unverified |
| `build/GhosttyBench.zig` | 55 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `font/embedded.zig` | 55 | `font/embedded.v` | inventory-only | unverified |
| `config/Wasm.zig` | 54 | `config_wasm32.v` | targeted | no-discrepancy-observed |
| `build/webgen/main_commands.zig` | 53 | `build/docs.v` | inventory-only | unverified |
| `config.zig` | 53 | `configpkg/configpkg.v` | inventory-only | unverified |
| `simd/codepoint_width.zig` | 52 | `simd/codepoint_width.v` | targeted | divergence-confirmed |
| `cli/list_actions.zig` | 51 | `cli/actions.v` | inventory-only | unverified |
| `main_build_data.zig` | 51 | `main_build_data.v` | targeted | divergence-confirmed |
| `apprt/gtk/class/debug_warning.zig` | 50 | `apprt/gtk/debug_warning_linux.v` | inventory-only | unverified |
| `extra/sublime.zig` | 50 | `extra/vim.v`<br>`extra/completions.v`<br>`extra/sublime.v` | inventory-only | unverified |
| `terminal/osc/parsers/report_pwd.zig` | 48 | `osc/report_pwd.v` | inventory-only | unverified |
| `input.zig` | 46 | `input/input.v`<br>`input/key.v`<br>`input/binding.v`<br>`input/keymap_darwin.c.v`<br>`input/keymap_default.c.v` | targeted | no-discrepancy-observed |
| `unicode/props.zig` | 46 | `unicode/properties.v` | targeted | no-discrepancy-observed |
| `font/sprite.zig` | 45 | `sprite/face.v` | inventory-only | unverified |
| `os/wasm/log.zig` | 45 | ∅ (see scoped finding/limitations) | no-counterpart | unverified |
| `renderer/opengl/Sampler.zig` | 45 | `renderer/opengl_types_linux.c.v`<br>`renderer/opengl_linux.c.v` | inventory-only | unverified |
| `apprt/gtk/weak_ref.zig` | 44 | `apprt/gtk/weak_ref_linux.v` | inventory-only | unverified |
| `build/LibtoolStep.zig` | 44 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `config/ClipboardCodepointMap.zig` | 44 | `configpkg/configpkg.v` | inventory-only | unverified |
| `datastruct/array_list_collection.zig` | 44 | `datastruct/array_list_collection.v` | inventory-only | unverified |
| `build/LipoStep.zig` | 42 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `synthetic/Generator.zig` | 42 | `synthetic/generator.v` | targeted | divergence-confirmed |
| `termio/Options.zig` | 41 | `termio/termio.v` | inventory-only | unverified |
| `input/KeymapNoop.zig` | 39 | `input/keymap_default.c.v` | branch-reviewed | no-discrepancy-observed |
| `terminal/osc/parsers/mouse_shape.zig` | 39 | `osc/mouse_shape.v` | inventory-only | unverified |
| `termio.zig` | 39 | `termio/termio.v` | inventory-only | unverified |
| `terminal/osc/encoding.zig` | 38 | `osc/encoding.v` | inventory-only | unverified |
| `terminal/c/paste.zig` | 36 | `terminal_c/terminal_c.v`<br>`lib_vt_c.v` | targeted | no-discrepancy-observed |
| `terminal/kitty/graphics.zig` | 36 | `terminal/kitty_graphics_command.v`<br>`terminal/kitty_graphics_exec.v`<br>`terminal/kitty_graphics_image.v`<br>`terminal/kitty_graphics_storage.v`<br>`terminal/kitty_graphics_unicode.v` | targeted | no-discrepancy-observed |
| `simd/index_of.zig` | 35 | `simd/index_of.v` | targeted | divergence-confirmed |
| `benchmark/CApi.zig` | 34 | `benchmark/benchmark.v` | targeted | no-discrepancy-observed |
| `build/main.zig` | 34 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `terminal/osc/parsers/change_window_icon.zig` | 33 | `osc/change_window_icon.v` | inventory-only | unverified |
| `lib/struct.zig` | 31 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `apprt/gtk/flatpak.zig` | 29 | `apprt/gtk/flatpak_linux.v` | inventory-only | unverified |
| `apprt/runtime.zig` | 29 | `apprt/runtime.v` | inventory-only | unverified |
| `build/gtk.zig` | 27 | `build/gtk.v` | targeted | no-discrepancy-observed |
| `os/kernel_info.zig` | 27 | `internal_os/platform.v` | inventory-only | unverified |
| `terminal/kitty/graphics_render.zig` | 27 | `terminal/kitty_graphics_image.v` | targeted | no-discrepancy-observed |
| `main.zig` | 26 | `main_darwin.v`<br>`main_linux.v` | targeted | divergence-confirmed |
| `main_wasm.zig` | 26 | `font_web_canvas_wasm32.v`<br>`font_atlas_wasm32.v`<br>`config_wasm32.v`<br>`lib_allocator_wasm32.v` | targeted | divergence-confirmed |
| `os/mouse.zig` | 25 | `internal_os/mouse_macos.c.v`<br>`internal_os/mouse_default.c.v`<br>`internal_os/mouse_darwin.h` | inventory-only | unverified |
| `os/wasm.zig` | 25 | `lib_allocator_wasm32.v` | inventory-only | unverified |
| `synthetic/main.zig` | 25 | `synthetic/cli.v` | targeted | unverified |
| `datastruct/main.zig` | 24 | `datastruct/blocking_queue.v`<br>`datastruct/cache_table.v`<br>`datastruct/circ_buf.v`<br>`datastruct/intrusive_linked_list.v`<br>`datastruct/message_data.v`<br>`datastruct/segmented_pool.v`<br>`datastruct/split_tree.v`<br>`datastruct/lru/lru.v` | targeted | no-discrepancy-observed |
| `renderer/Options.zig` | 24 | `renderer/options.v` | inventory-only | unverified |
| `config/ErrorList.zig` | 23 | `configpkg/error_list.v` | inventory-only | unverified |
| `renderer/backend.zig` | 23 | `renderer/backend.v` | inventory-only | unverified |
| `terminal/search.zig` | 22 | `search/main_exports.v`<br>`search/search_thread.v` | targeted | no-discrepancy-observed |
| `crash/main.zig` | 21 | `crash/crash.v`<br>`crash/envelope.v` | targeted | no-discrepancy-observed |
| `os/dbus.zig` | 21 | `internal_os/internal_os.v` | inventory-only | unverified |
| `os/pipe.zig` | 21 | `internal_os/internal_os.v` | inventory-only | unverified |
| `benchmark/options.zig` | 20 | `benchmark/benchmark_core.v` | targeted | no-discrepancy-observed |
| `os/wasm/target.zig` | 20 | ∅ (see scoped finding/limitations) | no-counterpart | unverified |
| `apprt/none.zig` | 19 | `apprt/none.v` | branch-reviewed | no-discrepancy-observed |
| `font/Glyph.zig` | 19 | `font/glyph.v` | inventory-only | unverified |
| `terminal/osc/parsers.zig` | 19 | `osc/change_window_title.v`<br>`osc/change_window_icon.v`<br>`osc/color_parser.v`<br>`osc/osc9.v`<br>`osc/report_pwd.v`<br>`osc/hyperlink_parser.v`<br>`osc/clipboard_parser.v`<br>`osc/semantic_prompt.v`<br>`osc/mouse_shape.v`<br>`osc/rxvt_extension.v`<br>`osc/iterm2_parser.v`<br>`osc/kitty_color.v`<br>`osc/kitty_text_sizing.v` | inventory-only | unverified |
| `build/zig.zig` | 18 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `unicode/props_table.zig` | 18 | `unicode/properties.v` | targeted | no-discrepancy-observed |
| `font/opentype.zig` | 17 | `opentype/opentype.v` | inventory-only | unverified |
| `unicode/symbols_table.zig` | 17 | `unicode/properties.v` | targeted | no-discrepancy-observed |
| `build/mdgen/main_ghostty_1.zig` | 16 | `build/docs.v` | inventory-only | unverified |
| `build/mdgen/main_ghostty_5.zig` | 16 | `build/docs.v` | inventory-only | unverified |
| `lib/main.zig` | 15 | `lib_allocator/allocator.v`<br>`terminal_c/terminal_c.v`<br>`apprt/action.v` | inventory-only | unverified |
| `math.zig` | 15 | `mathutil/math.v` | targeted | no-discrepancy-observed |
| `terminal/cursor.zig` | 15 | `terminal/cursor.v` | inventory-only | unverified |
| `terminal/kitty.zig` | 15 | `terminal/types.v`<br>`osc/kitty_color.v`<br>`terminal/kitty_graphics_command.v`<br>`terminal/kitty_graphics_exec.v` | targeted | no-discrepancy-observed |
| `apprt/gtk.zig` | 14 | `apprt/gtk/app_linux.v`<br>`apprt/gtk/surface_linux.v` | inventory-only | unverified |
| `cli.zig` | 14 | `cli/actions.v`<br>`cli/action_help.v` | inventory-only | unverified |
| `simd/main.zig` | 14 | `simd/base64_scalar.v`<br>`simd/index_of.v`<br>`simd/base64.v`<br>`simd/vt.v`<br>`simd/codepoint_width.v` | targeted | unverified |
| `benchmark/main.zig` | 13 | `benchmark/benchmark.v` | targeted | no-discrepancy-observed |
| `lib/types.zig` | 13 | `terminal_c/terminal_c.v`<br>`apprt/action.v` | inventory-only | unverified |
| `terminal/tmux.zig` | 13 | `tmux/main_exports.v`<br>`tmux/control.v`<br>`tmux/layout.v`<br>`tmux/output.v`<br>`terminal/tmux_viewer.v` | targeted | no-discrepancy-observed |
| `terminfo/main.zig` | 13 | `terminfo/ghostty.v`<br>`terminfo/terminfo.v` | targeted | no-discrepancy-observed |
| `terminal/c/color.zig` | 12 | `terminal_c/terminal_c.v`<br>`lib_vt_c.v` | targeted | no-discrepancy-observed |
| `stb/main.zig` | 10 | `stb/stb.v` | targeted | no-discrepancy-observed |
| `unicode/main.zig` | 10 | `unicode/properties.v` | targeted | no-discrepancy-observed |
| `build/webgen/main_actions.zig` | 9 | `build/docs.v` | inventory-only | unverified |
| `input/config.zig` | 8 | `input/input.v` | inventory-only | unverified |
| `inspector/main.zig` | 8 | `inspector/inspector.v` | inventory-only | unverified |
| `cli/tui.zig` | 6 | `tui/tui.v` | inventory-only | unverified |
| `lib/target.zig` | 6 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `terminal/c/result.zig` | 6 | `terminal_c/terminal_c.v`<br>`lib_vt_c.v` | targeted | no-discrepancy-observed |
| `apprt/browser.zig` | 4 | `apprt/browser.v` | branch-reviewed | no-discrepancy-observed |
| `build/xcframework.zig` | 3 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `inspector/units.zig` | 3 | `inspector/units.v` | inventory-only | unverified |
| `main_bench.zig` | 3 | `benchmark/benchmark.v` | inventory-only | unverified |
| `main_gen.zig` | 3 | `synthetic/cli.v` | inventory-only | unverified |
| `renderer/WebGL.zig` | 2 | `renderer/webgl.v` | targeted | no-discrepancy-observed |

</details>

## Additional source and resource inventory

These 111 entries preserve coverage of Python generators/input data, shaders, GTK styles/blueprints, font resources, and fixtures. For binary resources, “targeted / no-discrepancy-observed” means byte identity/provenance was checked, not semantic execution. Missing original fixtures are test-coverage gaps; they do not by themselves establish missing runtime behavior. Font resources and generated V data do not translate an absent regeneration workflow.

<details>
<summary>All 111 additional mappings</summary>

| Original (relative to Ghostty `src/` unless prefixed) | Lines | V counterpart(s) | Review | Status |
| --- | ---: | --- | --- | --- |
| `font/res/spleen-8x16.bdf` | 22328 | `font/res/spleen-8x16.bdf` | targeted | no-discrepancy-observed |
| `font/nerd_font_codepoint_tables.py` | 10449 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `renderer/shaders/shaders.metal` | 853 | `renderer/shaders.metal` | targeted | no-discrepancy-observed |
| `font/nerd_font_codegen.py` | 577 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `apprt/gtk/ui/1.2/surface.blp` | 366 | `apprt/gtk/surface_class_linux.v` | inventory-only | unverified |
| `apprt/gtk/ui/1.5/window.blp` | 309 | `apprt/gtk/window_linux.v` | inventory-only | unverified |
| `font/sprite/draw/octants.txt` | 234 | `sprite/symbols_for_legacy_computing_supplement.v` | targeted | no-discrepancy-observed |
| `apprt/gtk/css/style.css` | 183 | `apprt/gtk/style.css`<br>`apprt/gtk/application_linux.v` | targeted | no-discrepancy-observed |
| `renderer/shaders/glsl/common.glsl` | 156 | `renderer/shaders/glsl/common.glsl` | targeted | no-discrepancy-observed |
| `renderer/shaders/glsl/cell_text.v.glsl` | 146 | `renderer/shaders/glsl/cell_text.v.glsl` | targeted | no-discrepancy-observed |
| `renderer/shaders/glsl/bg_image.v.glsl` | 145 | `renderer/shaders/glsl/bg_image.v.glsl` | targeted | no-discrepancy-observed |
| `apprt/gtk/ui/1.5/command-palette.blp` | 110 | `apprt/gtk/command_palette_linux.v` | targeted | divergence-confirmed |
| `renderer/shaders/glsl/cell_text.f.glsl` | 100 | `renderer/shaders/glsl/cell_text.f.glsl` | targeted | no-discrepancy-observed |
| `apprt/gtk/ui/1.4/clipboard-confirmation-dialog.blp` | 96 | `apprt/gtk/clipboard_confirmation_dialog_linux.v` | inventory-only | unverified |
| `apprt/gtk/ui/1.2/search-overlay.blp` | 94 | `apprt/gtk/search_overlay_linux.v` | inventory-only | unverified |
| `font/res/OFL.txt` | 91 | `font/res/OFL.txt` | targeted | no-discrepancy-observed |
| `apprt/gtk/ui/1.0/clipboard-confirmation-dialog.blp` | 86 | `apprt/gtk/clipboard_confirmation_dialog_linux.v` | inventory-only | unverified |
| `renderer/shaders/glsl/bg_image.f.glsl` | 63 | `renderer/shaders/glsl/bg_image.f.glsl` | targeted | no-discrepancy-observed |
| `renderer/shaders/glsl/cell_bg.f.glsl` | 61 | `renderer/shaders/glsl/cell_bg.f.glsl` | targeted | no-discrepancy-observed |
| `renderer/shaders/test_shadertoy_crt.glsl` | 59 | ∅ (see scoped finding/limitations) | no-counterpart | unverified |
| `apprt/gtk/ui/1.2/key-state-overlay.blp` | 58 | `apprt/gtk/key_state_overlay_linux.v` | inventory-only | unverified |
| `font/sprite/draw/README.md` | 55 | ∅ (see scoped finding/limitations) | no-counterpart | unverified |
| `config/config-template` | 52 | `configpkg/config-template` | inventory-only | unverified |
| `apprt/gtk/ui/1.5/imgui-widget.blp` | 51 | `apprt/gtk/imgui_widget_linux.v` | targeted | divergence-confirmed |
| `renderer/shaders/glsl/image.v.glsl` | 47 | `renderer/shaders/glsl/image.v.glsl` | targeted | no-discrepancy-observed |
| `cli/lorem_ipsum.txt` | 45 | `cli/lorem_ipsum.txt` | inventory-only | unverified |
| `renderer/shaders/shadertoy_prefix.glsl` | 43 | `renderer/shaders/shadertoy_prefix.glsl` | targeted | no-discrepancy-observed |
| `renderer/shaders/test_shadertoy_focus.glsl` | 41 | ∅ (see scoped finding/limitations) | no-counterpart | unverified |
| `font/res/README.md` | 39 | `font/res/README.md` | targeted | no-discrepancy-observed |
| `apprt/gtk/ui/1.5/inspector-window.blp` | 38 | `apprt/gtk/inspector_window_linux.v` | inventory-only | unverified |
| `apprt/gtk/ui/1.2/config-errors-dialog.blp` | 28 | `apprt/gtk/config_errors_dialog_linux.v` | inventory-only | unverified |
| `apprt/gtk/ui/1.2/resize-overlay.blp` | 27 | `apprt/gtk/resize_overlay_linux.v` | inventory-only | unverified |
| `apprt/gtk/ui/1.5/split-tree.blp` | 25 | `apprt/gtk/split_tree_class_linux.v` | inventory-only | unverified |
| `font/res/BSD-2-Clause.txt` | 24 | `font/res/BSD-2-Clause.txt` | targeted | no-discrepancy-observed |
| `renderer/shaders/glsl/full_screen.v.glsl` | 24 | `renderer/shaders/glsl/full_screen.v.glsl` | targeted | no-discrepancy-observed |
| `apprt/gtk/ui/1.3/surface-child-exited.blp` | 22 | `apprt/gtk/surface_child_exited_linux.v` | inventory-only | unverified |
| `renderer/shaders/glsl/image.f.glsl` | 21 | `renderer/shaders/glsl/image.f.glsl` | targeted | no-discrepancy-observed |
| `apprt/gtk/ui/1.5/split-tree-split.blp` | 20 | `apprt/gtk/split_tree_class_linux.v` | inventory-only | unverified |
| `apprt/gtk/ui/1.5/surface-title-dialog.blp` | 19 | `apprt/gtk/surface_title_dialog_linux.v` | inventory-only | unverified |
| `font/res/MIT.txt` | 19 | `font/res/MIT.txt` | targeted | no-discrepancy-observed |
| `apprt/gtk/ui/1.5/tab.blp` | 18 | `apprt/gtk/tab_linux.v` | inventory-only | unverified |
| `cli/README.md` | 13 | ∅ (see scoped finding/limitations) | no-counterpart | unverified |
| `renderer/shaders/glsl/bg_color.f.glsl` | 13 | `renderer/shaders/glsl/bg_color.f.glsl` | targeted | no-discrepancy-observed |
| `apprt/gtk/ui/1.2/close-confirmation-dialog.blp` | 12 | `apprt/gtk/close_confirmation_dialog_linux.v` | inventory-only | unverified |
| `inspector/AGENTS.md` | 12 | ∅ (see scoped finding/limitations) | no-counterpart | unverified |
| `renderer/shaders/test_shadertoy_invalid.glsl` | 12 | ∅ (see scoped finding/limitations) | no-counterpart | unverified |
| `apprt/gtk/ui/1.2/debug-warning.blp` | 11 | `apprt/gtk/debug_warning_linux.v` | inventory-only | unverified |
| `apprt/gtk/ui/1.5/surface-scrolled-window.blp` | 11 | `apprt/gtk/surface_scrolled_window_linux.v` | inventory-only | unverified |
| `apprt/gtk/ui/1.5/inspector-widget.blp` | 10 | `apprt/gtk/inspector_window_linux.v` | inventory-only | unverified |
| `apprt/gtk/ui/1.3/debug-warning.blp` | 9 | `apprt/gtk/debug_warning_linux.v` | inventory-only | unverified |
| `apprt/gtk/css/style-dark.css` | 8 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `apprt/gtk/css/style-hc-dark.css` | 3 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `apprt/gtk/css/style-hc.css` | 3 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `font/shaper/testdata/arabic.txt` | 3 | ∅ (see scoped finding/limitations) | no-counterpart | unverified |
| `config/testdata/theme_simple` | 2 | `configpkg/configpkg_test.v` | inventory-only | unverified |
| `config/testdata/theme_dark` | 1 | `configpkg/configpkg_test.v` | inventory-only | unverified |
| `config/testdata/theme_light` | 1 | `configpkg/configpkg_test.v` | inventory-only | unverified |
| `font/res/CodeNewRoman-Regular.otf` | — | `font/res/CodeNewRoman-Regular.otf` | targeted | no-discrepancy-observed |
| `font/res/CozetteVector.ttf` | — | `font/res/CozetteVector.ttf` | targeted | no-discrepancy-observed |
| `font/res/GeistMono-Regular.ttf` | — | `font/res/GeistMono-Regular.ttf` | targeted | no-discrepancy-observed |
| `font/res/Inconsolata-Regular.ttf` | — | `font/res/Inconsolata-Regular.ttf` | targeted | no-discrepancy-observed |
| `font/res/JetBrainsMonoNerdFont-Bold.ttf` | — | `font/res/JetBrainsMonoNerdFont-Bold.ttf` | targeted | no-discrepancy-observed |
| `font/res/JetBrainsMonoNerdFont-BoldItalic.ttf` | — | `font/res/JetBrainsMonoNerdFont-BoldItalic.ttf` | targeted | no-discrepancy-observed |
| `font/res/JetBrainsMonoNerdFont-Italic.ttf` | — | `font/res/JetBrainsMonoNerdFont-Italic.ttf` | targeted | no-discrepancy-observed |
| `font/res/JetBrainsMonoNerdFont-Regular.ttf` | — | `font/res/JetBrainsMonoNerdFont-Regular.ttf` | targeted | no-discrepancy-observed |
| `font/res/JetBrainsMonoNoNF-Regular.ttf` | — | `font/res/JetBrainsMonoNoNF-Regular.ttf` | targeted | no-discrepancy-observed |
| `font/res/JuliaMono-Regular.ttf` | — | `font/res/JuliaMono-Regular.ttf` | targeted | no-discrepancy-observed |
| `font/res/KawkabMono-Regular.ttf` | — | `font/res/KawkabMono-Regular.ttf` | targeted | no-discrepancy-observed |
| `font/res/Lilex-VF.ttf` | — | `font/res/Lilex-VF.ttf` | targeted | no-discrepancy-observed |
| `font/res/MonaspaceNeon-Regular.otf` | — | `font/res/MonaspaceNeon-Regular.otf` | targeted | no-discrepancy-observed |
| `font/res/NotoColorEmoji.ttf` | — | `font/res/NotoColorEmoji.ttf` | targeted | no-discrepancy-observed |
| `font/res/NotoEmoji-Regular.ttf` | — | `font/res/NotoEmoji-Regular.ttf` | targeted | no-discrepancy-observed |
| `font/res/TerminusTTF-Regular.ttf` | — | `font/res/TerminusTTF-Regular.ttf` | targeted | no-discrepancy-observed |
| `font/res/spleen-8x16.otb` | — | `font/res/spleen-8x16.otb` | targeted | no-discrepancy-observed |
| `font/res/spleen-8x16.pcf` | — | `font/res/spleen-8x16.pcf` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+1CC00...U+1CCFF-11x21+2.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+1CC00...U+1CCFF-12x24+3.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+1CC00...U+1CCFF-18x36+4.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+1CC00...U+1CCFF-9x17+1.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+1CD00...U+1CDFF-11x21+2.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+1CD00...U+1CDFF-12x24+3.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+1CD00...U+1CDFF-18x36+4.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+1CD00...U+1CDFF-9x17+1.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+1CE00...U+1CEFF-11x21+2.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+1CE00...U+1CEFF-12x24+3.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+1CE00...U+1CEFF-18x36+4.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+1CE00...U+1CEFF-9x17+1.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+1FB00...U+1FBFF-11x21+2.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+1FB00...U+1FBFF-12x24+3.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+1FB00...U+1FBFF-18x36+4.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+1FB00...U+1FBFF-9x17+1.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+2500...U+25FF-11x21+2.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+2500...U+25FF-12x24+3.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+2500...U+25FF-18x36+4.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+2500...U+25FF-9x17+1.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+2800...U+28FF-11x21+2.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+2800...U+28FF-12x24+3.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+2800...U+28FF-18x36+4.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+2800...U+28FF-9x17+1.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+E000...U+E0FF-11x21+2.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+E000...U+E0FF-12x24+3.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+E000...U+E0FF-18x36+4.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+E000...U+E0FF-9x17+1.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+F500...U+F5FF-11x21+2.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+F500...U+F5FF-12x24+3.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+F500...U+F5FF-18x36+4.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+F500...U+F5FF-9x17+1.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+F600...U+F6FF-11x21+2.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+F600...U+F6FF-12x24+3.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+F600...U+F6FF-18x36+4.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |
| `font/sprite/testdata/U+F600...U+F6FF-9x17+1.png` | — | `sprite/face_test.v` | targeted | no-discrepancy-observed |

</details>

## Large supporting-library inventory and explicit review limit

The 36 files below are at least 500 physical lines in the local libxev/vaxis/locked-zigimg references. This is an inventory with selected API/platform/decoder checks, **not** a completed branch audit of every dependency body. In particular, Linux/BSD/macOS async backends, all watcher/timer/socket/file paths, vaxis screen/parser/widget algorithms, and all image codecs require further direct comparison. The PNG row reports only the valid matrix just tested; generic loader/JPEG gaps are reported separately in S11.

| Original (relative to Ghostty `src/` unless prefixed) | Lines | V counterpart(s) | Review | Status |
| --- | ---: | --- | --- | --- |
| `zigimg/src/color.zig` | 3173 | `zigimg/color.v`<br>`zigimg/color_float.v`<br>`zigimg/pixel_storage.v`<br>`zigimg/pixel_iterator.v` | inventory-only | unverified |
| `libxev/src/backend/kqueue.zig` | 2777 | `xev/kqueue_process_darwin.c.v`<br>`xev/kqueue_timer_darwin.c.v`<br>`xev/kqueue_darwin.c.v`<br>`xev/kqueue_stream_darwin.c.v`<br>`xev/kqueue_async_darwin.c.v` | inventory-only | unverified |
| `libxev/src/backend/iocp.zig` | 2376 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `libxev/src/backend/epoll.zig` | 2061 | `xev/epoll_async_linux.c.v`<br>`xev/epoll_process_linux.c.v`<br>`xev/epoll_timer_linux.c.v`<br>`xev/epoll_stream_linux.c.v`<br>`xev/epoll_linux.c.v` | inventory-only | unverified |
| `libxev/src/backend/io_uring.zig` | 1787 | `xev/io_uring_stream_linux.c.v`<br>`xev/io_uring_timer_linux.c.v`<br>`xev/io_uring_process_linux.c.v`<br>`xev/io_uring_async_linux.c.v`<br>`xev/io_uring_linux.c.v`<br>`xev/linux_io_uring_linux.c.v` | inventory-only | unverified |
| `libxev/src/backend/wasi_poll.zig` | 1648 | ∅ (see scoped finding/limitations) | no-counterpart | gap-confirmed |
| `libxev/src/watcher/stream.zig` | 1443 | `xev/io_uring_stream_linux.c.v`<br>`xev/epoll_stream_linux.c.v`<br>`xev/kqueue_stream_darwin.c.v`<br>`xev/dynamic_stream_linux.c.v` | inventory-only | unverified |
| `zigimg/src/formats/tga.zig` | 1425 | `zigimg/tga.v` | inventory-only | unverified |
| `vaxis/src/Vaxis.zig` | 1411 | `vaxis/vaxis.v`<br>`vaxis/image.v` | targeted | gap-confirmed |
| `zigimg/src/PixelFormatConverter.zig` | 1408 | `zigimg/pixel_format_converter.v` | inventory-only | unverified |
| `vaxis/src/Parser.zig` | 1285 | `vaxis/parser.v` | inventory-only | unverified |
| `zigimg/src/formats/png/reader.zig` | 1135 | `zigimg/png_reader.v`<br>`zigimg/png_header.v`<br>`zigimg/png_filtering.v`<br>`zigimg/png_processors.v`<br>`zigimg/png_info.v` | targeted | unverified |
| `vaxis/src/vxfw/ScrollView.zig` | 1087 | `vaxis/vxfw/scroll_view.v` | inventory-only | unverified |
| `zigimg/src/formats/gif.zig` | 1020 | `zigimg/gif.v` | inventory-only | unverified |
| `libxev/src/watcher/udp.zig` | 1003 | ∅ (see scoped finding/limitations) | inventory-only | unverified |
| `libxev/src/watcher/tcp.zig` | 935 | ∅ (see scoped finding/limitations) | inventory-only | unverified |
| `vaxis/src/Window.zig` | 889 | `vaxis/window.v` | inventory-only | unverified |
| `libxev/src/watcher/file.zig` | 848 | ∅ (see scoped finding/limitations) | inventory-only | unverified |
| `libxev/src/watcher/async.zig` | 828 | `xev/epoll_async_linux.c.v`<br>`xev/io_uring_async_linux.c.v`<br>`xev/kqueue_async_darwin.c.v`<br>`xev/dynamic_async_linux.c.v` | inventory-only | unverified |
| `libxev/src/ThreadPool.zig` | 827 | `xev/thread_pool.v` | targeted | unverified |
| `vaxis/src/widgets/terminal/Terminal.zig` | 784 | ∅ (see scoped finding/limitations) | inventory-only | unverified |
| `vaxis/src/vxfw/ListView.zig` | 767 | `vaxis/vxfw/list_view.v` | inventory-only | unverified |
| `vaxis/src/tty.zig` | 749 | ∅ (see scoped finding/limitations) | inventory-only | unverified |
| `zigimg/src/formats/pcx.zig` | 712 | `zigimg/pcx.v` | inventory-only | unverified |
| `libxev/src/watcher/timer.zig` | 641 | `xev/io_uring_timer_linux.c.v`<br>`xev/timerfd_linux.c.v`<br>`xev/epoll_timer_linux.c.v`<br>`xev/kqueue_timer_darwin.c.v`<br>`xev/dynamic_timer_linux.c.v` | inventory-only | unverified |
| `vaxis/src/vxfw/ScrollBars.zig` | 631 | `vaxis/vxfw/scroll_bars.v` | inventory-only | unverified |
| `vaxis/src/vxfw/App.zig` | 602 | `vaxis/vxfw/app.v` | inventory-only | unverified |
| `vaxis/src/vxfw/TextField.zig` | 598 | `vaxis/vxfw/text_field.v` | inventory-only | unverified |
| `zigimg/src/formats/iff.zig` | 591 | `zigimg/iff.v` | inventory-only | unverified |
| `vaxis/src/vxfw/vxfw.zig` | 578 | `vaxis/vxfw/vxfw.v` | inventory-only | unverified |
| `libxev/src/watcher/process.zig` | 572 | `xev/epoll_process_linux.c.v`<br>`xev/kqueue_process_darwin.c.v`<br>`xev/io_uring_process_linux.c.v`<br>`xev/dynamic_process_linux.c.v` | inventory-only | unverified |
| `zigimg/src/io.zig` | 562 | `zigimg/io.v`<br>`zigimg/bit_stream.v` | targeted | gap-confirmed |
| `zigimg/src/formats/pam.zig` | 558 | `zigimg/pam.v` | inventory-only | unverified |
| `libxev/src/dynamic.zig` | 524 | `xev/dynamic_process_linux.c.v`<br>`xev/dynamic_linux.c.v`<br>`xev/dynamic_timer_linux.c.v`<br>`xev/dynamic_stream_linux.c.v`<br>`xev/dynamic_async_linux.c.v` | inventory-only | unverified |
| `vaxis/src/widgets/terminal/Screen.zig` | 514 | `vaxis/screen.v` | inventory-only | unverified |
| `vaxis/src/vxfw/Text.zig` | 508 | `vaxis/vxfw/text.v` | inventory-only | unverified |

The initial audit added only `AUDIT_FINDINGS_ULTRA.md` and preserved existing production changes. The subsequent requested fixes and commits are recorded below. No pull request was requested or created.


## Fix resolution ledger

The original findings above describe the audited snapshot and remain historical evidence. This ledger records subsequent implementation and validation against Ghostty `6c0e02d1138d5376e4ac2f5e311b225494514a97`. “Implemented” means the finding's code change has been integrated; validation remains limited to the evidence listed. It does not certify unexecuted native platform branches or whole-file parity. Pending entries remain required work.

Ten isolated worker checkouts were used in parallel waves: this environment permits three active workers alongside the integrating agent. Each fix is committed separately; the hashes below refer to the main checkout after integration.

| Finding | State | Main commits / assigned worker | Evidence |
|---|---|---|---|
| T01 | Implemented | `81711ba, d3a40fe` | Bounded file acceptance; unsigned size cap regressions |
| T02 | Implemented | `c7e7b6f, 78ca2de` | Bound applies while expanding; bounded zlib and Kitty tests |
| T03 | Implemented | `5cdce9d, a76d02b` | Selected TMPDIR/TMP policy and fixture tests |
| T04 | Implemented | `92a6a4b, 3d506f5` | Strict UTF-8 validation; encoder regressions |
| T05 | Implemented | `5f1b2d2` | Nonfatal QoS failure continues search startup |
| T06 | Implemented | `d1c73e9` | u21 truncation at C boundary; regression |
| T07 | Implemented | `ac40ca6, 8c528ec, 3277fc6` | Enum checks before C dispatch; checked/production tests |
| T08 | Implemented | `9834594` | 990 unchanged Ghostty encoder differential cases matched |
| T09 | Implemented | `0bc93b8` | Absent versus invalid progress; parser regression |
| T10 | Implemented | `3e3a56d, 284e6b7` | All 242 key-table rows and native columns; table tests |
| T11 | Implemented | `4ddfe66, 154f46e, ec1ce0c, e49db79, 06262b5, faf49b1, 00f8a38, 4956cdb, a606e15, 9281161, c80b7e1`; workers08/01 | Contiguous packed mmap storage, source arena pools/free lists/retained reset, pooled pins/pointer identity/remap and allocator failure cleanup; native Page/53 allocator events/5 PageList snapshots and full ReleaseSafe consumer suites pass |
| T12 | Implemented | `cdad202, b4d9170, bfebcb4`; worker08 | Caller-backed generic maps/refcount sets, source AutoHash pointer/fixed array/selected union/optional/error/equality/rejection and unique-representation raw-byte branches; 15 unchanged Zig hash comparisons and five paired rejection checks pass |
| T13 | Implemented | `defa489, 8daa873` | Caller allocator reaches payload, ArrayList and SegmentedList; allocation failure, reset, OSC/terminal/C tests and original missing-allocator warning |
| T14 | Implemented | `c3267ae` | Original Oniguruma grammar and failure handling; tmux tests |
| R01 | Implemented | `b2db4d1, 203eecb, 3037638, 6dfc84c`; worker10 | ConPTY/read/write HANDLE lifecycle, cancellation and NT cwd access; source Linux fork selection and Darwin terminal branches include iOS; Darwin PTY/Exec tests, Windows COFF ABI compile and full Windows/iOS/FreeBSD termio checks pass; native Windows/iOS/FreeBSD execution unavailable |
| R02 | Implemented | `0329051` | Nullable strings write NULL successfully; config ABI tests |
| R03 | Implemented | `ede5f8d` | Notification error is warned/caught; mailbox regression |
| R04 | Implemented | `0740574` | Exclusive atomic file, permissions and exact bound; cache tests |
| R05 | Implemented | `c5dad01` | Original blueprint/native command model, filter/factory/gettext/config property and trigger signal; Linux GTK typecheck passes; native GTK execution unavailable here |
| R06 | Implemented | `289b3da, c38a060` | Unique portal-ID map replacement; Linux typecheck/collision tests |
| R07 | Implemented | `56a2ec3` | Pinned gettext canonicalizer/archive; enabled and disabled i18n tests |
| R08 | Implemented | `7b847ba` | Original CSS/icon/Blueprint resources and actual gresource generation/compilation paths; resource tests and Linux GTK typecheck pass; native resource compilation/display unavailable here |
| R09 | Implemented | `0b40e1c` | Native ImGui/Inspector virtual classes; Linux typecheck |
| RF-01 | Implemented | `bb72641, a7862f3` | Production selected backend; all 24 font files/Metal alternatives tested; native debug CoreText axes/variation/SVG tests pass after preserving its deferred cleanup under a single combined platform/debug condition |
| RF-02 | Implemented | `dcfd8a5` | Run grid lock held during shaping; blocking concurrency regression |
| RF-04 | Implemented | `fb7870d` | Live shaper uses translated feature parser; feature tests |
| RF-05 | Implemented | `822384b, e805710, db6bd89, 6f5c6e4` | Actual locked libraries, complete header closure, clean root rebuild; native SPIRV/GLSL/MSL and failure probes |
| RF-06 | Implemented | `36a9461` | Glass alpha zero; renderer tests |
| RF-07 | Implemented | `cf23a2a` | Lazy row shaping/preedit catch-up; renderer regressions |
| RF-08 | Implemented | `b03a939` | Live page widget and five tracked-pin columns; real ImGui frame tests |
| RF-09 | Implemented | `6c7149a` | Public key detail renderer, bounded error path, Debug demo; real ImGui tests |
| RF-10 | Implemented | `f41e9f2, 3b189cf, d52b838` | Optionals and narrow inputs; face/Nerd Font/boundary tests |
| RF-11 | Implemented | `cac7626, 3277fc6, 4da3d9c` | Original atlas/sprite/FreeType invariant traps; native probes |
| RF-12 | Implemented | `a729075, 70ced6a` | Native bounded ImGui filter/input, reflected original metadata; original Zig fixture and inspector tests |
| S01 | Implemented | `bef54e9` | Unchanged native SIMD dependencies plus translated scalar algorithm; native/scalar tests |
| S02 | Implemented | `227ebde` | Checked empty/all-padding traps and InvalidPadding warning; subprocess probes |
| S03 | Implemented | `6cea9e6` | Source aligned libc allocation/in-place remap; alignment 1–65536 and over-32-bit growth tests |
| S04 | Implemented | `6166ffc, ef531fb` | Exact native SDK/Breakpad build; real SIGSEGV minidump and restart local transport; clean tracked-only build |
| S05 | Implemented | `ced0309, 30b6d21, a49c083, fe11b40, b33c55b, 1b9bc49, d163a1e, ef1f85e, 0574201, 7100753, ea111be, d024dab, 7adea4d, 4dc9980, c6af427, ac1b819, 9b96b00, a651c96, 3037638, 6dfc84c`; root/workers02/10 | Real install/run/test/native dependencies/generators/resources/distribution/retargeted XCFramework/V native bundle graph; installed VT C examples/generated hashes/full native C library consumer and rebuilt Wasm 50-export API probe pass; full iOS/FreeBSD termio checks and production FreeBSD native ABI compilation pass; Xcode/Metal/GTK packaging execution unavailable |
| S06 | Implemented | `3277fc6, 38b8900, f012e5e, ea111be, 4dc9980, a02674a`; root | Current GitVersion/channel and four-mode/artifact options reach production artifacts/host generators/tests; full native C consumer reports ReleaseSafe/version 1.3.0 and initializes/configures successfully; finalized updater defaults use the live compiled channel, with stable/tip/explicit override regressions passing |
| S07 | Implemented | `8c24731, a2e85b9, 5fd055c, ba265aa, 41e8b32, 0ef9c19, 8c01e7b, 0b9f876, 8607472, 6d38e29`; workers02/05/06 | Actual borrowed config clone and scoped main-thread projection, clone-before-guard unresolved Surface isolation, distinct controller/app and per-surface configuration, original host 1-point increments and logical cell-size window resizing, initial-size points without immediate resizing, source focus-follows-mouse guards, numeric/last/relative tab navigation, app appearance KVO, cached per-surface color publication and hidden/empty Quick class guards; native scope/opposite split-zoom policy/full dispatcher/scale-2 window/appearance/font tests and host typecheck pass; 20 unchanged Swift config/command string records and full native title/font consumers match |
| S08 | Implemented | `af434d2` | Original startup messages and status 1; executable probes; timer subclaim corrected below |
| S09 | Implemented | `2b553c8` | ConEmu nominal limit is not a writer-capacity rejection; regression |
| S10 | Implemented | `2c4b036` | Xoshiro/random selection/streaming; 756 unchanged Zig differential cases matched |
| S11 | Implemented | `bf0e21d, 60d05b4, b55e129, 51ee537, 9653064, 58eabe2, c3aa316, b3c548d, ef04635, 0274965, a5cd41f, da5df5a` | 43 image suites; complete pinned PNG decoder/chunk writer, format interfaces, inline storage, color models/scientific spaces/named and general matrices, constructors/getters and native-layout utilities have committed unchanged-source matrices; optimized color/math hashes retained; inherited undefined state and unsupported legacy APIs remain documented |
| S12 | Implemented | `695dedc` | Original 9-bit lookahead, sorted alphabet and linked fallback; Huffman/codec tests |
| S13 | Implemented | `7aab070, a651c96`; worker10 | Locked source IOCP/WASI and shared macOS/iOS/FreeBSD kqueue selection, cancellation/timers/completions and native thread/futex paths; Darwin regressions, source batch/ABI tests, Windows COFF and production AArch64 FreeBSD ELF compile, independent Zig/native FreeBSD ABI assertions and both WASI feature typechecks pass; native Windows/WASI/iOS/FreeBSD execution unavailable |
| S14 | Implemented | `9b1dc71` | Decoded image path/memory loading, premultiplied conversion, transmission; V tests and native conversion probe |
| S15 | Implemented | `4242ed4` | Actual C-backed V type factories; compiled enum holes, layout/defaults/alignment/padding/nested/zero-size cases |
| S16 | Implemented | `930e186` | Build-time SDK/minimum-version mapping and embedding; helper tests pass; actual Apple Metal compiler unavailable |
| SH01 | Implemented | `c7c4d5a, 0974804, adf1233, 053c282`; worker05/root | Immutable split tree and native controls, source performability/resize/zoom navigation, insertion failure cleanup, focused-tab observer guards and asynchronous zoom focus restoration; model/native controller tests and host typecheck pass |
| SH02 | Implemented | `4882e78, 7462457, cbbb804, 95665ee, f353557`; worker05 | Native Quick Terminal panel/lazy surface, sizing/screen/cache/focus/Space/Dock/previous-app/animation lifecycle and saved-tree restoration; selected-surface focus retries and source alert/reference lifetime; native geometry/cache tests and original Swift screen-cache archive comparisons in both directions pass |
| SH03 | Implemented | `e393c79, 7462457, f4d0e80, 770c8f5, 8147453, d4c9263, 7c5e8c3, c7102f9, d27d149, d8a17f5`; workers05/06 | Actual NSUndoManager/timed weak targets and retained terminal trees; secure nested NSKeyedArchiver/window/versioned split/Quick restoration and AppKit restoration callbacks; source async cascade, weak parent/group references, deferred intrinsic size/clamped origin, native window ownership and queued window-only sibling-tab undo; native undo/expiry/window/cascade/key-call tests and unchanged Swift archive decoding in both directions pass; captured-tree undo/redo, live deferred focus and retained explicit-from native regression passes; inherited terminal/inspector subclass responder dispatch also passes |
| SH04 | Implemented | `8de10ae, d245a1f, 26053a2, 55940bc, cd30e95, f78f0c8, e2e9b27, 0b9f876, 8607472, 4f7fb99`; workers02/05/06 | Configured geometry/decorations/shadow/theme/opacity/blur/buttons/fullscreen exception, source Ventura titlebar/accessory layout and tab/titlebar/toolbar zoom controls, live scoped title/tab/toolbar fonts, native key/resign selector hooks and distinct config/preferred/actual-window color roles; real native opposite-color/opaque/transparent/threshold, font scope/key attributes, zoom-button and fullscreen parent probes pass; selected Tahoe model/toolbar/layout/KVO/event/hot-reload branch and native focused new-tab route; five native fixtures and ten unchanged Swift records match |
| SH05 | Implemented | `617f532, 6eff167`; worker05 | Four fullscreen styles, source restoration and active non-native fullscreen new-tab warning/refusal; native contract/window tests and typecheck pass |
| SH06 | Implemented | `c66db29, df7be78, 63ce485, 1d92aca, f0a8987`; workers05/09/root | Termination/reopen guards, real Sparkle updater/driver/model/install producer, titlebar/overlay badge and weak delayed ownership; native tests including real updater startup in a private bundle pass; four unchanged original Swift files match 14 states and install/cancel lifecycle |
| SB-01 | Implemented | `450725b, 0558262` | Native text-input client, IME and key responder; explicit typed split-zoom optional preserves behavior with the pinned C compiler; native contract and full dispatcher tests |
| SB-02 | Implemented | `a938d46, 26c0fa6` | Native Services, drag/drop, accessibility and Swift-compatible Unicode range/grapheme cases; worker and root native tests |
| SB-03 | Implemented | `3bd3844, 0ebfcc5, bf6684b, a708706, 751b462, 469d0dc, 1ab9fd0, 2f566f6, bf3ac6c, a6740b0, c41f849, 06c1c14, 5f60b96, 9074fd7, ded9c35, 576e844, 058abf2, 1ce17a4, 19646d3, 5ad3ea3, ea27ec4, a50bd7b`; workers06/09/root | Live window/palette/menu/search/key/progress/bell/health/readonly/secure input/cursor/link/notifications, retained main-queue notification delegate, delayed title/prompts, native scrollback and MTKView inspector, source void/Bool/target/raw-enum guards and queued focus/retry; 85 unchanged Swift URL/config routes and 88 string projections match; real full dispatcher/string-consumer/inspector/focus/overlay probes pass |
| SB-04 | Implemented | `d566e33, 6bec729` | Matching-window display ID, backing refresh and true zeroing weak view lifetime; AppKit tests |
| SB-05 | Implemented | `c56924a` | Configuration-driven menu conversion/apply/clear; native menu tests |
| SB-06 | Implemented | `b988d4f, eb109ee, 0ff0fdc` | Surface-targeted reload preserves target; unresolved surfaces leave app config untouched while acknowledging the original void handler with true; full native host reload regression compiles, links and executes |
| PH01 | Implemented | `938dd7e` | Embedding argv snapshot consumed on Linux/FreeBSD; config/argv tests |

### Source-backed corrections and remaining validation limits

S08's initial GTK quit-timer subclaim was incorrect. The pinned `src/apprt/gtk/App.zig` has 99 lines and no `startQuitTimer` declaration; the method exists only on its private Application class. Thus `src/main_ghostty.zig`'s `@hasDecl(apprt.App, "startQuitTimer")` evaluates false for GTK, matching the V adapter. Adding that call would introduce behavior rather than translate the effective original. The separate startup diagnostic/exit-status discrepancy was fixed and tested in a compiled executable.

The pinned browser font implementation itself lacks Collection-required metrics/name/color APIs. RF-01 preserves that original unsupported path and connects existing browser/backend logic; browser execution remains unverified. GTK native class/portal tests currently have Linux typechecking evidence, not an executed GTK desktop session on this macOS host. Windows/FreeBSD branches likewise need their native environments to establish execution parity.

The large fixed-Huffman flate match-at-64KiB trap is confirmed in the actual pinned Zig decompressor with the same 200,000-byte fixture and small output bound. It is retained as inherited checked-source behavior, rather than silently replaced. The source fixture and native log are recorded in `/tmp/witty-ultra-fixes/image-flate-probe/`.

The S05 resource install was exercised through the translated driver into an isolated prefix. All completions and terminfo matched recorded original hashes, every locked theme matched its source bytes, all 25 gettext catalogs were compiled/installed, and the Darwin documentation placeholder matched. Sparkle 2.8.0 was resolved from the original SwiftPM lock and its binary archive matched the original Package.swift SHA-256. Subsequent install/native library/Wasm checks are recorded below; full Apple bundle/XCFramework execution remains limited by the missing Xcode tools.

### Further integrated build/platform verification

The source-pinned native build graph now compiles the original zlib, libpng,
FreeType, Oniguruma, HarfBuzz, libxml2, Fontconfig and Dear ImGui inputs with
artifact target/SDK/optimization options. Both Debug and ReleaseSafe native
package builds were exercised. System header/link choices and independent
glslang/SPIRV-Cross build choices are wired into the compiler arguments.

The VT artifact was exercised from the four unchanged upstream C examples,
including a separate C process that tests exported V initialization. Scalar
and SIMD builds passed; installed versioned Darwin libraries, relative aliases
and loader paths also passed those examples. This caught and corrected V
initialization/archive-classification defects that module tests did not cover.
The SGR example inherits a pinned original header/enum discrepancy: public
`sgr.h` inserts RESET_UNDERLINE at tag 8, while actual `Attribute.Tag` has no
such member. V preserves the original exported tags. The example's successful
exit does not certify that inconsistent original header. Reproducible fixtures
and the explanation are in `build_support/reference_probes/vt_examples`.

The unchanged source framegen C program and all 235 frame inputs are restored.
Its freshly generated compressed bytes match `cli/framedata.compressed`
(SHA-256 `cda4389141fa7a180dd78b7c8f6742c118273ef7bd3e449ef322a9e85e3dc8c6`).
Generator/benchmark native CLI checks pass, including source SIGPIPE startup
needed for successful generator shutdown when stdout closes. Full macOS/GTK
packaging and native target execution are validation limits: Apple
Metal/Xcode tools, GTK runtime and Windows/WASI execution are unavailable on
this macOS Command Line Tools host.

### Integrated generator and installed-artifact verification

The actual `tools/build install` step ran into an isolated prefix with help and Unicode generator emission enabled. It installed the versioned VT library and relative aliases, all VT headers, pkg-config metadata, the source Darwin documentation placeholder, and all three generators. The four unchanged original C VT examples compiled and ran against this installed library. Generated help output matched native Zig SHA-256 `2d783d30d916b038b592d2fb9f8cd9897fc5d1bfee6eab8a48e43a16f6a0d658`. Property and symbol generator output matched the previously recorded native hashes `b32ded890688c75f0dad566e4b07060ecdbaa367c8e18f0e717fe576713dfea9` and `43bbdff55dc0787b17fa2f73cd6b183ebbaa640e999b4ca27276970e1d71d869`; the compiled Unicode byte import matched `c66888cff0007450992232712af32fa216455db60987abaa9dec00f681fb3eed`.

The Unicode input was independently regenerated by the unchanged pinned uucode dependency generator with the original Ghostty build configuration. Its two-stage buildtime input matched 72,192 bytes and SHA-256 `756ffe2c8f8778509a3a37706f7767f9c8cfdcf02d436bb90f46f29136cc9f40`; the V generator did not read the finished runtime properties/symbol table to produce its output. The full u21 dependency-input/runtime-output comparison, generated runtime Unicode suite, generated CLI help suite, native plist metadata/Services check, and production driver config/version tests passed.

The macOS V bundle compiler adaptation preserves source resources, Icon Composer input, project plist values, entitlements, architecture choices, signing/copy operations and run environment. Native V contract tests replace the Swift XCTest compiler step. A full app/Metal/asset-catalog/XCFramework build requires Xcode tools absent from this CLT-only environment, and is not certified by the successful plist/library tests. The resolved Wasm compiler/runtime adaptation and actual artifact checks are recorded below.

### Further native host integration

Close undo uses the actual NSUndoManager and timer expiry, retaining terminal views/Core surfaces for the original undo lifetime. Native window overrides dispatch superclass calls from the defining class; real AppKit dynamic subclasses exposed a recursion defect that was corrected in `55940bc`.

Secure restoration encodes the original nested NSKeyedArchiver NSData and versioned keys. The original Swift SplitTree and QuickTerminalScreenStateCache decoders read the V archives; V reads the unchanged Swift fixtures. Native title publication retains the original 75 ms delay and 500 ms fallback; native scrollback and 30 fps MTKView inspector event producers are live.

The full OpenGL/CoreText embedding library compiled and linked against the locked native packages. Its first actual C metadata/init consumer run exposed an alignment-1 opaque mutex buffer in the selected V compiler's `os` runtime, before Ghostty initialization. The build-local compiler runtime adaptation preserves its 128-byte capacity and operations while providing native alignment; the rebuilt native C consumer passes metadata, initialization and configuration allocation/loading/finalization/free, including font-size=17. Runtime font backend dispatch in V also retains Fontconfig/HarfBuzz references, so the full native graph now includes those unchanged packages in `c6af427`.

### Native embedding and Wasm completion checks

The full managed OpenGL/CoreText ReleaseSafe library was rebuilt through the translated artifact driver and loaded by a separate native C consumer. It reports mode=1/version=1.3.0, completes initialization, and preserves the NSProcessInfo CLI configuration policy. `ac1b819` fixes only the selected compiler runtime's opaque mutex storage alignment; `c6af427` supplies the unchanged native packages retained by V backend dispatch. The compiler installation itself is unchanged. The actual stable and tip finalization regressions also preserve explicit updater channel overrides (`a02674a`).

`9b96b00` installs the actual Wasm VT binary and Emscripten runtime loader with all 50 original exports, including the 12 allocation helpers. Node executes the installed artifact and checks source Kitty encoding, OSC title/reset, Kakoune SGR values, paste safety, checked warning paths, every paired allocation/free family and memory growth. The source custom logger calls `env.log`; default/scoped prefixes, log levels and 2048-byte stack/allocation fallback match the unchanged original Wasm implementation in Debug, ReleaseSafe, ReleaseFast and ReleaseSmall. Reproducible probes and compiler adaptation details are in `build_support/reference_probes/wasm_vt`. Browser execution is unverified.

The Wasm C backend preserves the source VT import boundary instead of importing native key tables, ImGui and process APIs. Emscripten supplies its real compiler runtime imports. Link-time static data starts at 64 KiB to respect this selected V runtime's low-address memory-operation guard. Emscripten musl supplies its unchanged decimal-dot float parser where locale-specific variants are unavailable. No OS/import placeholder functions were used to make the module instantiate. `ca48737` also disables the selected compiler's automatic remote C-error diagnostic submission in the build driver; the one diagnostic record emitted during the initial failed Wasm experiment was removed successfully.

### Final platform and native action verification

`a651c96`, `3037638` and `6dfc84c` connect the source iOS/FreeBSD kqueue and Darwin terminal branches. Full managed termio checks pass for iOS OpenGL, iOS Metal and FreeBSD OpenGL. Production-generated V xev C compiles to AArch64 FreeBSD ELF with the real SDK headers; independent unchanged Zig `std.c` assertions agree with native C assertions on kevent, socket and private umtx layouts. Native macOS kqueue, Mach Async, Process, ThreadPool and Exec regressions also pass. No iOS SDK link or native FreeBSD execution is claimed.

The locked libxev FreeBSD internal Wakeup lifecycle is resource-free, and its wakeup operation explicitly panics. Its thread-pool completion wake and public MachPort conversion retain macOS-only source guards, including the original iOS limitation. The source WASI Process/threaded Async types are empty; the original WASI pool retains its allocator-required thread failure. These inherited source omissions remain documented in `xev/PLATFORM_TRANSLATION.md`; filling them with new algorithms would violate source preservation.

The native window, command palette, menus, search/key/progress/bell/cursor/secure-input/renderer-health overlays and notification producers now have live consumers. Notification delegate callbacks retain native objects and completion blocks across main-queue dispatch. The dispatcher preserves the original distinction between void acknowledgements and explicit Bool performability, including unsupported `.render`, missing Surface targets, App new-tab behavior and undo/redo window guards. Full `native_action_darwin_test.v` and `reload_target_darwin_test.v` compiled, linked against the managed native packages, and executed successfully.

The last source comparisons corrected config-change target ambiguity and initial sizing. `a2e85b9` retains the original clone-before-guard ordering and releases the clone for an unresolved Surface target, preventing app-wide config replacement. `5fd055c` stores initial-size values directly as points because the source Core producer already divides by content scale; it preserves deferred controller sizing. The full dispatcher regression uses a real AppKit window reporting backing scale 2, verifies 800×600 remains 800×600, and checks that the window frame stays unchanged by that action.

Native AppKit probes exercise actual windows, tab groups, sheets, buttons/accessories, undo managers, timers, archives, MTKView and user-notification content/delegate contracts. Interactive whole-application appearance, multi-screen/Space/Dock animation, user-driven fullscreen/inspector sessions, real notification authorization/delivery and outer archive migration from an installed Swift app remain unexecuted. The unchanged Swift probes establish inner split/cache archive compatibility in both directions, and the actual Sparkle updater starts in a private app fixture; they do not certify those separate interactions.

The native URL/config consumer preserves Foundation parsing, UTType/editor selection and explicit-length NSString decoding (`19646d3`, `1ce17a4`). Extracted unchanged Swift wrappers, the original open-URL handler and NSWorkspace extension match all 85 recorded routes. The shared NSString bridge preserves embedded NUL, multibyte and astral characters (`5ad3ea3`). The source string wrappers distinguish strict first-NUL C decoding, repairing Swift C decoding and bounded UTF-8 decoding (`ea27ec4`); all 22 malformed/valid/NUL boundary fixtures match the unchanged Swift results for each of four projections. These native/source probes are reproducible from `build_support/reference_probes/{open_url,source_strings}` and the corresponding `macos` tests.

`a50bd7b` connects those conversions to title, pwd, notification, search, key-table and hover actions. The real full module-main `native_string_darwin_test.v` compiles, links and executes against the managed native packages in ordinary and `-cg` debug builds: invalid title/pwd leave prior values intact, invalid notification title/body returns before authorization, search repairs malformed bytes, and bounded key-table strings preserve embedded NUL. The test also verifies a valid C prefix with malformed bytes beyond its first NUL.

Controller config and surface config are separate source notification scopes (`ba265aa`). App updates affect controller policy/global surface settings while individual surface appearance waits for its surface-targeted update. Focus-follows-mouse follows the original key-window, palette and focused-surface guards. Host split layout retains the source 1-point increments; window step sizing uses logical cell dimensions. The actual native config-scope fixture passes, and conflicting controller/surface preserve-split-zoom values in both directions verify that navigation reads controller policy (`41e8b32`).

`0ef9c19` connects original `.new`/`.initial` observations of NSApplication.effectiveAppearance after app initialization, applies app config appearance independently of surface config, and publishes the app's effective color scheme to all controller tree surfaces with the source cache. Actual native KVO initial/change/removal/auto/system tests and full module-main app/two-surface API publication/cache/hidden regular-window/empty-tree tests pass. The Quick Terminal source places publication before its visibility guard; regular TerminalWindow places it after that guard.

Native focus operations retain captured views, queue the first attempt and use the original delayed attachment retry/backoff (`06c1c14`). Palette/maximize handlers select the containing controller and its focused view (`5f60b96`); inspector presentation explicitly resigns the terminal responder before queued inspector focus (`ded9c35`). Unknown inspector control is ignored, unknown progress state removes progress, and raw split/close/fullscreen modes follow the original wrapper guards (`9074fd7`, `c41f849`). Real AppKit split, Quick Terminal, palette, queued-focus, presentation and MTKView first-responder fixtures pass.

The selected V compiler emits unmatched C preprocessor directives for CoreText's `defer` nested inside separate platform and debug conditions. `a7862f3` combines the equivalent conditions without changing the source axes logging, assertions, error cleanup or deferred CFArray release. Native `font/face_coretext_test.v` compiles and executes with `-cg`, including variable-font axes/variation and SVG cases; its generated C has 1,166 matched conditional pairs. The full host string-dispatch debug test also compiles, links and executes; its generated C has 4,779 matched conditional pairs. The compiler installation is unchanged.

`f78f0c8` and `e2e9b27` preserve native optional title fonts, default/invalid-family fallback, single-line title handling, attributed tab titles and their active/inactive colors, Ventura toolbar label fonts and the original fullscreen toolbar-window parent filter. Real AppKit probes verify font/color attribute values, subclass title dispatch, actual toolbar labels and the parent filter. The fullscreen-parent fixture supplies the source private class-name/style predicates on native windows; it does not claim an interactive fullscreen transition.

`8c01e7b` preserves Quick Terminal's NSPanel class guard and color publication while hidden, with empty or populated trees and no focused surface. `0b9f876` connects title fonts at startup/restoration/undo and config notification scopes: a populated regular tree keeps its focused surface's family until a Surface update; an empty regular tree uses the App-derived family through the source private `syncAppearance` overload. The live class uses Objective-C `becomeKeyWindow`/`resignKeyWindow`, the actual selectors imported into Swift as `becomeKey`/`resignKey`. Full native font-scope and automatic class/key-hook fixtures pass.

`8607472` separates focused config luminance for normal automatic appearance and Ventura chrome, preferred border color for Ventura's appearance override, and native NSWindow.backgroundColor for both very-dark-background paths. The latter follows the unchanged source sRGB conversion/component read, so a transparent white-alpha window is not classified from a black configured terminal background. Native opposite-color, opaque, transparent, forced-opaque and threshold tests pass; restoring each former predicate independently fails its relevant regression. On macOS 26 the Ventura backdrop test uses an attached native NSView/CALayer fixture where the old accessory-parent class guard cannot attach it; the actual window/tab group/titlebar and native appearance/color values are exercised.

`c7102f9` preserves sibling-tab undo's outer queued window key/order call without changing first responder, accepts a missing focused surface and avoids an already-closed controller's released native window. The actual NSUndoManager/native fixture checks async call order, native selector forwarding, retained controller lifetime and responder preservation. Its key predicate matches a direct source-call baseline on the same command-line native window; it does not certify OS foreground activation.

The final selected-path review found that the original TerminalController factory selects `TerminalTabsTitlebarTahoe` for compiler >= 6.2 on macOS >= 26. The host has Swift 6.3.3 and macOS 26.5, so that source branch is reachable; configured tabs are not filtered out by `Ghostty.Config`. The V host's unconditional Ventura path omits Tahoe-specific tab constraints/reset observation, main-window title model, event forwarding and toolbar item behavior. This branch is now integrated and validated by five native fixtures and ten unchanged Swift model/toolbar records, as described below.


### Continued image API and native focus verification

`b55e129` verifies complete PNG loading against unchanged source with 60,760
returning cases and eight isolated traps. Its matrix covers all fifteen valid
color/depth pairs, all filters, Adam7, IDAT fragmentation, CRC failures,
truncation, callbacks and buffered memory/file reads. The result SHA-256 is
`96ee46b18345684842d8ae9cd64290f7c5e9b86228458a83386a602bbd646e9c`.
Small file-buffer rebasing, repeated transparency chunks and the tall Adam7
row-counter trap retain their inherited behavior.

`51ee537` finishes the pinned direct PNG chunk writer. Its 5,960 returning
cases and two isolated traps match unchanged zigimg, including empty chunks,
oversized unframed writes and buffered state after partial failure. The
original `writer()` and zlib-compressor helpers still fail to compile with
Zig 0.15.2; the audit retains those unsupported source boundaries.

`9653064`, `58eabe2`, `c3aa316` and `b3c548d` add the 17 codec callback
interfaces, general inline fixed storage, codec debug hooks, HSL/HSV/CMYK and
float grayscale models, predefined colors, vector/matrix APIs, magic numbers
and deprecated enum-checked struct readers. Their unchanged-source matrices
match 49,344, 2,373, 31,167, 12,419 and 20,992 returning cases respectively,
with the associated option, resize and shift traps. Codec diagnostics retain
V's language-specific logger/struct rendering. Native-layout read callers
must provide corresponding widths, alignment and padding. Original struct
writers reference the removed `std.io.StreamSource` and remain unsupported.

The continuing utility review found that V production optimization removed
the magic-number and inline-storage assertions. Explicit guards now retain
both oversized-signature traps and twenty independent resize traps, including
all eighteen generic capacity/type combinations and both specialized buffers.
The existing 20,992 and 2,373 returning-case hashes remain unchanged in
ordinary and production V builds. Endian and native-layout field aliases now
follow their underlying types; 54,528 additional source cases match in both
builds, SHA-256
`5a841a2f84a10641b1ebf1268d6e60326576459bafc54b84fb732287096032e6`.
The alias matrix covers exhaustive and non-exhaustive enums, nested structs,
byte arrays, scalar fields, short input and read positions. Wider inline
arrays and dynamic byte slices, with and without aliases, retain four ordinary
source compile rejections.

The live native clipboard paths now share the source's URL-first opinionated
pasteboard reader, map MIME types through UTType, declare write types before
setting values, and project callback strings through the same repairing or
strict first-NUL conversions as Swift. Confirmed writes publish only approved
plain text; malformed UTF-8 and unknown read-request tags retain the source
early return without completion. An actual module-main AppKit fixture uses a
unique named pasteboard and injected alert results. All 21 records match the
unchanged pinned Swift helpers, app callbacks and controller completion method.
The runner checks each extracted/compiled source file against its pinned Git
contents. The fixture validates content and cleanup policy; synchronous alert
presentation remains a V adaptation, and source SwiftUI sheet rendering/timing
is not certified. All tested MIME names yield UTTypes, so the translated raw
MIME fallback after a nil lookup remains unexercised on this host.

The classic Vaxis alignment, Scrollbar and ScrollView implementations now expose
their runnable Window-based source APIs. All 41,649 cases match an unchanged
source-tree copy in ordinary and production V builds, SHA-256
`12bc9172a2cf6e8e65d9e410ae3902aa35ab546b8e58814a11f04249e53c7308`.
Retained cell/style data, clipping, five alignments, saturated input and bounds,
reserved scrollbar padding and content writes are compared. Three overflow/
coordinate-cast traps remain explicit. The original optional-return readCell
method fails to compile with Zig 0.15.2; V leaves that inherited boundary
unavailable, verified by paired compile probes. The locked source tree hash
and flattened API mapping are documented with the probe. These widgets are
separate from the previously translated `vxfw` implementations.

Classic View and LineNumbers are now translated, along with TextView's runnable
data/style/borrowed-adapter/input/draw APIs and CodeView's configuration/input.
The exact locked uucode package is recovered and hashed; its unchanged table
generator runs through the original dependency module graph. Ordinary and
production V comparisons match 18,307 cases, 17 checked traps and four ordinary
compile rejections, SHA-256
`8f1e7d605790217fc5d8426f487cced18a5998d945da9ec50b92ed57c8b6750e`.
Retained image/scale/cell/style fields, Unicode clusters, render origins,
scrolling, byte-indexed styles and adapter pointers are compared. View keeps
checked i17 offsets, direct copying and alias traps. LineNumbers keeps its
exclusive endpoint and zero digits above 99,999,999. TextView append/update/
writer-write inherit the source error-union subtraction failure; CodeView.draw
inherits a usize-to-optional-u16 width error. The methods remain unavailable,
verified by paired compile probes. Five shared consumer tests pass, and native/
Linux module checks pass. GC destruction and source-undefined reuse limits
are recorded in `vaxis/reference_probes/widgets_classic/README.md`.

The quantizer's accumulation, averaging, capacity, reduction and level checks
now survive V production optimization. Sixteen subprocess probes reject both
successful returns and returned domain errors; this closes a previous verifier
false positive where an outer panic masked an erased color-level guard.
The original 2,160 tree/palette/index and 336,128 normalization hashes remain
`fb25faff7d5b5837` and `2e3cf0cdc340afc4` in Debug and V-production/source-
ReleaseSafe builds. A further 2,816 records compare aliases of all eleven
supported RGB(A) types, SHA-256
`9c9d1fc6249abb82c5ce2d642655a4f6b6b7789e7ad540a9c65993a47cea09d3`.
The runner verifies the complete locked source tree and V-computed hashes
independently of assertions. Deliberate removeLeaves wrapping and the existing
GC/root/private-context adaptations remain unchanged.

The continuing stream comparison restores borrowed reader/writer adapters and
native integer helpers, including aliases. File truncation updates cached EOF;
Darwin positional vector writes return after the source's first nonempty
vector. Pipe writes expose the initial zero-progress transition, while flush
retries it; streaming seeks retain cached failures. Checked seek additions,
positions, capacities and bit/count shifts remain explicit in production.
The source-hashed runner matches 36,962 returning cases, 17 strict checked
traps and four ordinary compile rejections in both V build modes, SHA-256
`f1aa0b894555ca0ee8864ce10e7605112cc2ccfeaa1ae6b21a07e3573cbc99dc`.
Both focused test files pass in ordinary and production builds. The integrated
43-file image suite, native/Linux module checks, Windows DLL and both focused
test cross builds pass. Windows execution and Zig's non-native scalar widths
retain their documented limits. Reproduction and ownership rules are in
`zigimg/reference_probes/streams/README.md`.

Streaming file constructors now start at the descriptor's current position.
The reader exposes buffered length, initially reports `Streaming` for file
size, then retains EOF's discovered size and unavailable backward seeks.
The expanded Debug matrix matches 37,133 records, SHA-256
`d5d4aadd97fafef40388dd894267e0b09d6db36b902c2f4356d4fb287eab8eeb`;
the original 36,962-record hash remains unchanged. The 171 streaming records
also match with V production optimization, SHA-256
`37175ccb3eb0e9b5b36005a5c2443f6f59b1ee2cbd7de2fd1336c2761a8bcfab`.

The classic Vaxis Table translation preserves its width styles, context
defaults, allocated row snapshots, repeated N-by-N columns, screen rendering,
callback errors and callback mutations. Debug and V-production/source-
ReleaseSafe comparisons match 7,058 returning records, fourteen checked traps
and four ordinary compiler failures, SHA-256
`a9aa2c68decee1101f62bfc02cd52ccbfceed8142377c1919c9a60c194c91a82`.
Five consumer tests and a Windows focused-test build pass. Zig 0.15.2 rejects
source slice inputs and direct/optional string-slice field formatting; the
translated APIs retain these compile boundaries. GC ownership, custom `{any}`
formatting and source-undefined subset header limits remain in
`vaxis/reference_probes/table/README.md`.

The TextInput continuation preserves per-grapheme insertion and gap geometry,
malformed UTF-8 consumption, zero-width drawing order, and the public u16
draw/count/width boundaries. Explicit Buffer guards cover growth, slices,
insertion, both movements and both gap growth operations, including zero-count
movement and large public cursor values. Ordinary and production comparisons
match 14,346 returning records and 22 checked traps, SHA-256
`4003872debd68d8f2886119b492cc0d14ac1c5692a049662b043074cb67aaaf0`.
Six focused consumers pass. Source count/width overflow and malformed combining
mark underflow remain checked traps. At this checkpoint the iterator/width
helper left the module's global APIs unchanged; the subsequent shared Unicode
continuation is recorded below. GC ownership, string call shapes and int-sized
arrays remain documented representation limits.

The classic Terminal key encoder matches 59,072 returning cases and all 31
nonzero Kitty press traps in Debug and V-production/source-ReleaseSafe builds,
SHA-256 `fef07475371a26194ffa5a396745016d36ef5eb33b005ef1a47f115888a96d6a`.
Two focused consumers pass. Source legacy-only presses, decimal CTRL+ALT
lowercase output, generated text precedence, modifier masking, empty releases,
unsupported keys and partial writer failures are retained. The exact source
tree and locked Unicode dependency are verified by the committed runner in
`vaxis/reference_probes/terminal/key/README.md`.

TextInput's caller-buffer copy now returns the borrowed caller prefix, leaves
trailing bytes intact and retains capacity/aliasing traps. The full Debug corpus
matches 14,442 records and 24 traps, SHA-256
`d334fced0a688b98041dc3d197722ecfb4fb54dca8b1c6baf20b4e11cbc51b9b`;
the original 14,346-record hash is unchanged. The 96 additional records and two
traps also pass V production optimization, SHA-256
`4ea3a4ac46f14ef27d6583ab094004525b0af9e5a0e2356d91cfc1c738a5e149`.
Seven consumer tests pass. A separate source-hashed constructor runner checks
twelve complete classic/vxfw widget inputs and twenty-three paired missing-field
errors. Source allocators are supplied separately and excluded from omission
comparisons. The vxfw TextField consumer explicitly initializes its required
buffer and passes after the marker change.
After streaming constructors, the image suite again passes all 43 files,
native/Linux checking, Windows DLL compilation and the focused file-I/O cross
build. Cross builds do not establish platform runtime behavior.

The classic Terminal Parser and ANSI helpers match 140,489 returning records
and sixteen checked arithmetic traps in Debug and V-production/source-
ReleaseSafe builds, SHA-256
`d161050f1a033fd4f73a1e4cff01a7a61b6100f50773a40d8528e82f1ef1bf53`.
The matrix compares events/errors, raw bytes, borrowed buffer reuse, reader
positions/buffering, pending controls, formatting and typed iterator/lookahead
state. DCS/SOS/PM skip only the ESC delimiter; OSC/APC discard the following
byte without extra prefetch and propagate cutoff EOF. Five ordinary compiler
boundaries and three focused consumers pass. Generic missing-`bytes` omission
is explicitly measured as source rejection/V acceptance; the pinned V compiler
ignores the required annotation for that generic field. The runner counts this
adaptation separately and does not claim whole terminal runtime parity.

The classic Terminal Screen translation matches 6,414 returning records and
fourteen checked traps in Debug and V-production/source-ReleaseSafe builds,
SHA-256 `9700325e0d87d1893e34375f5d8951eb5eadd2c469734b9cce078c52f7e183a4`.
A separate inherited insert-line hang, two complete constructors and five
paired omission rejections also pass. Eight focused consumers cover screen,
cell, cursor and region contracts. The source's equal-width reads, first-row
character deletion, dirty-copy omissions, self-copy clearing and u16 counter
traps remain intact. Borrowed fixture serialization avoids optimized quadratic
GC root tracking while retaining the exact records. Undefined cursor URI,
allocator/capacity and GC limits are in
`vaxis/reference_probes/terminal_screen/README.md`.

The classic Terminal core matches 12,394 public-control/draw/input/cleanup
records and five checked traps in Debug and V-production/source-ReleaseSafe,
SHA-256 `6be3faff0915dedb07e6d0d65983f526a2b2a5d283d66fb6b9d2647359c2143e`.
Three focused consumers pass in both V modes. Three complete constructors and
fourteen ordinary omission pairs retain required PTY, Command and Terminal
fields. Six lifecycle APIs retain source/V macOS compiler rejections, while
unchanged-source Linux consumers and translated Linux compiler checks pass.
The Linux PTY/process/thread translation also compiles and links as an ELF
shared library; no Linux lifecycle runtime comparison is claimed on this host.
Source allocator omission, registry and thread adapters are documented in
`vaxis/reference_probes/terminal/core/README.md`.
Its separate three-record Debug fixture confirms the source registry's stale
count of two while live entries decrease from two to zero; V exposes source
count through `globals.count` and live entries through map length. SHA-256:
`fffc0c277b830839c956ad90dff7fef86557ecb03194fffd50b602ac9ef928fb`.

The fixture-exposed private Terminal loop matches 1,767 returning records,
ten exact checked-trap categories, an inherited insert-line timeout pair and
ordinary external private-access rejection in Debug and V-production/source-
ReleaseSafe builds. SHA-256:
`e7dc5af0356c8a4f074b5b94114cb70addee9c1fc5c638d9d40c2ebd5ab43b0b`.
One helper is appended to a copied source file, preserving every original byte
as an identical prefix and every other source file unchanged. The isolated V
module fixture adds no public API. Cases compare CSI/OSC/C0 processing, malformed
print bytes, replies, events, three complete screens, streaming EOF position
and released mutex state. Provenance and capacity/lifecycle limits are in
`vaxis/reference_probes/terminal/private_run/README.md`.

The integrated Vaxis suite passes all 33 test files. Native/Linux checking,
Linux generated-C linking as a shared library with GC disabled, the Windows
DLL and focused Screen/Parser test cross builds also pass. These compile gates
do not certify cross-platform PTY/process/thread runtime behavior.

The ten classic widget exports now have counterparts for their runnable public
methods. Five source compilation failures remain explicit: ScrollView `readCell`,
TextView buffer `append`/`update`, its writer's `write`, and CodeView `draw`.
Table input/format boundaries, source protocol/scrollback TODOs and GC limits
remain recorded separately. This closes the identified live method omissions
in the classic widget slice without certifying whole-repository equivalence.

The complete PNG decoding matrix was repeated after the stream changes and
retains all 60,760 returning records and eight checked traps, SHA-256
`96ee46b18345684842d8ae9cd64290f7c5e9b86228458a83386a602bbd646e9c`.
Its runner now accepts a positive `--timeout` in seconds and reports completed
cases plus the next case on a deadline failure. The default remains 180 seconds;
the integrated rerun uses `--timeout 600` on this busy host.

`6d38e29` applies Swift's repairing first-NUL C-string projection to native
config title/font and command title/description consumers. The extracted
unchanged getters/initializer match 20 records (40 getter results and 38
command fields); full native module-main title/font consumers pass.

`d27d149` preserves the source's captured replacement tree for redo, the outer
queued focus closure, explicit old-view retention and deferred focused-view
lookup. The actual NSUndoManager/terminal-view regression mutates tree/focus
between registration and invocation and passes. Pending focus captures and
both undo trees keep detached surfaces alive. `d8a17f5` dispatches terminal
and inspector superclass methods from their defining classes; real further
native subclasses execute inherited responder/tracking/backing hooks without
recursion and preserve the expected focus callbacks.


The selected macOS 26 Tahoe branch now follows the entire original titlebar
class and its inherited transparent appearance/KVO paths. Native title/font
updates retain the asynchronous source model, independent repeated toolbar
item views, empty-title spacing, main-window color, the one-by-one tab
placeholder, eight tab constraints, frame observation/reset and click
forwarding. The window class remains fixed across config hot reloads: tab
accessories receive right layout before AppKit, titles stay hidden and update
pills stay outside accessories. The inherited glass-style predicate uses the
current derived config. Native new-tab buttons dispatch the focused surface's
source core binding. Full native action, title-font and updater fixtures and
explicit Ventura appearance/font/zoom regressions pass.

The unchanged 342-line Tahoe class and traversal helpers match ten extracted
model/toolbar records. V renders the source SwiftUI title through AppKit text
and container views; this establishes model/API behavior, not identical
SwiftUI typography or interactive fullscreen/context-menu behavior. The
reproducible source probe and limitations are in
`build_support/reference_probes/window_tahoe/README.md`.

The latest image suite passes all 43 test files. Native and Linux image-module
checks and the Windows DLL cross build pass; Windows execution remains
untested here. Both Vaxis image consumer test files also pass.
The managed OpenGL test driver also rebuilds locked Debug native packages and
passes both new tree-focus cases:

```sh
VEXE=/path/to/v-0.5.2 V_C_ERROR_BUG_REPORT_DISABLED=1 \
  /path/to/v-0.5.2 -path "$PWD|@vlib|@vmodules" run tools/build test \
  -Drenderer=opengl -Dsentry=false \
  -Dtest-filter=tree_replacement_captures_explicit_from_before_outer_queue \
  -Dtest-filter=tree_undo_redo_use_captured_tree_and_live_focus
```

A default Metal bundle build still requires the unavailable Xcode Metal
compiler. The executed managed OpenGL checks do not certify that separate
packaging path or a full interactive application session.


`ef04635` and `0274965` complete the exported scientific color-model and
RGB-colorspace functions. The 6,961 primitive and 5,792 colorspace cases
retain their hashes under V production optimization. Separate sine/cosine
calls prevent Apple clang's combined routine from changing final rounding.
The source HSLuvAlpha Float4 type typo is preserved. The color-space corpus
covers all eleven presets, twenty-nine whitepoints, default initialization,
Bradford adaptation, gamma functions and sixteen copied/in-place alpha
slice families. Copy allocation and compile-time namespaces use the documented
V runtime/type adaptations.

`a5cd41f` completes built-in RGB(A) constructors/getters, unsigned numeric
scaling, HTML parsing and premultiplication. Target conversions retain custom
factory dispatch, and packed/grayscale aliases retain their logical widths.
The unchanged-source comparison matches 35,362 returning cases, four checked
component-limit traps and twenty-one ordinary compiler rejections in both
ordinary and production builds. Its SHA-256 is
`d0e9543322de17f813724ff1ed5b51793a68277be165a96bf4266ae17461adf3`.
V static methods replace source namespaces, and explicitly typed scaling
replaces comptime integer inference. Focused private-factory extensions for
custom mixed-precision colors remain V adaptations; the recorded source
comparisons cover built-ins, public custom factory delegation and aliases.

`da5df5a` adds the general square f32 `Matrix[B]` factory, preserving inline
values, scalar/vector arithmetic and elimination without pivoting. Its 6,467
unchanged-source cases across dimensions 1, 2, 3, 4, 5 and 8 retain SHA-256
`f303b568d8901d722b61cb805d2ccd212e57c10a758d2b530f15ab4d710e9c0f`
in ordinary and production builds. Three explicit shape guards survive
optimization, protecting bounded direct indexing around the compiler's
generic bounds-metadata defect. The existing 12,419-case math matrix retains
its prior hash in both modes. Direct named storage arrays replace the Zig
type factory; zero-length arrays, extra alias layers and forwarding static
factories through enclosing generics remain pinned V boundaries. Storage uses
V's array ABI. Examples and limits are recorded in
`zigimg/reference_probes/math_generic/README.md`.

The final integrated `v test zigimg` run passes 43/43 files. Native/Linux
module checks and the Windows DLL cross build were repeated after the math
integration and pass. These checks establish the recorded implementation
paths; allocator contracts, unsupported original helpers, unexecuted platform
runtimes and interactive native packaging retain the limits described above.

The shared Unicode continuation exposes borrowed Grapheme spans and initialized
iterators, and routes public width/grapheme helpers through the locked byte
decoder. DrawContext factories preserve source prefetch timing. Ordinary and
V-production/source-ReleaseSafe runs match 72,225 records, fourteen strict
traps, one complete span constructor and two paired missing-field rejections,
SHA-256 `f7555397b8c48374500b4558a166e5701f30ad7f2b35d056a4d5c56297913f4c`.
The original 72,065-record prefix retains its hash independently. The additional
160 mutation traces verify all three factories and previously returned borrowed
views. Six focused consumers pass, and the full original TextInput comparison
retains its 14,442-record/24-trap hash. Iterator state remains opaque in V;
source state literals, allocator lifetime and aggregate ABI are outside this
comparison. Reproduction is in
`vaxis/reference_probes/unicode_gwidth/README.md`.

TextField now uses the shared raw-byte iterator, preserves checked count/width/
draw arithmetic under production optimization, and borrows both caller-buffer
prefixes and rendered gap-buffer graphemes. Ordinary and V-production/source-
ReleaseSafe comparisons match 18,911 records and sixteen strict trap pairs,
SHA-256 `c9a34b722a8b37cf2d7916679118d07dae1a2bbd11a3bd68ccfe7fdf1dd93be3`.
Six focused tests pass. Callback mutation/error timing, previous-value snapshots,
state reset order and 1,824 additional pointer/mutation records are included.
The unused source u4 scroll field still has wider u8 storage; its source-only
literal rejection/V acceptance is measured separately. Allocator, GC and
readonly-slice contracts retain the limits in
`vaxis/reference_probes/vxfw_text_field/README.md`.

The Surface/SubSurface continuation restores checked u16 buffer/index
arithmetic and invariant checks that survive production builds, source-wide
i17 clipping, and checked delegated Window child/cell/cursor sums. Ordinary
and V-production/source-ReleaseSafe comparisons match 11,162 records and
twenty-eight strict traps, SHA-256
`852eb3f3eae04a383dd8af7fc2055971d9fc1bd1f49760135457cc4d5c6bc265`.
Four focused consumers pass. Borrowed trimming and child storage, cursor reset,
stable render order and pre/post-render hit routing are included. Remaining
framework constructor requirements, scroll i17 arithmetic and Spinner u4
overflow are recorded in the live audit; this method proof does not certify
those state contracts or the unmodified Window fill/print paths. Reproduction
is in `vaxis/reference_probes/vxfw_surface/README.md`.

The six zigimg SIMD lane helpers now support named native numeric lane arrays,
checked load/store assignment, raw-byte loading, integer/float conversion and
the non-AVX2 permutation. Stores also support compatible boolean, struct and
pointer arrays, preserve array overlap and retain the written prefix on bounds
failure. Box clamping and image pixel counts use explicit checks in source
order that survive production optimization. Both ordinary and V-production/
source-ReleaseSafe comparisons match 60,109 records, twenty-two strict trap
pairs, thirty-five ordinary compiler pairs and one panic-visible prefix pair,
SHA-256 `d67067e84ac4022693c27f755806a944c51909088df51a144f1438be1679f51e`.
Eight focused consumers pass in both modes. Four measured boundaries retain
source comptime length rejection, zero-length array support, native vector
overlap, and the pinned V pointer-alias constructor defect. The last is checked
in generated C without executing undefined behavior; valid alias values use
typed pointer-bit views. The ARM64 NaN cast result is measured in both source
modes. Other CPU NaN behavior, AVX2 indexing, native vector ABI and non-native
source numeric/tuple carriers remain outside this proof. Reproduction and
examples are in `zigimg/reference_probes/simd/README.md`.

Final integration passes 36/36 Vaxis and 44/44 image test files, native/Linux
module and whole-application checks, both Windows DLL cross builds and the
four new focused Windows test builds. The Vaxis Linux shared module also
links as x86_64 ELF with GC disabled for compilation/link verification. Cross
runtime behavior and allocator/lifetime parity remain unverified; the live
audit retains the remaining framework limits; subsequent scoped verification
is recorded below.

## Vaxis framework continuation

ListView/ScrollView checked scroll, origin, cursor and dimension operations now
survive V production optimization. The unchanged-source ordinary/Debug and
production/ReleaseSafe comparisons match 5,284 ListView records/twenty trap pairs
and 14,353 ScrollView records/twenty-two trap pairs. Output hashes are
`1c0060888edc4691761a3d3e2e5d9751c4a673b181457850c147cf9f104c9a9e` and
`013c5025c4b6192747e19df33a046090b3d0e2781f33f7a70d8824571a05625f`.
Each checks two isolated inherited builder loops and constructor omissions.
Source deinit-then-append child-list reuse is measured separately as undefined
storage, with V retaining its GC array adaptation. Wider i32 initializer storage
is disclosed separately; no out-of-domain state equivalence is claimed.

Spinner embeds atomic values for independent by-value copies and preserves
checked u4 increments, frame indexing, atomic wrapping/saturation and tick state
ordering. Both modes match 15,183 records and six strict traps, SHA-256
`91e0cf4dd5aee36836a99662a3271b4f9c38b8dfdbb044a88e193e69d1f74acc`.
Concurrent starts, one wider-u8 constructor boundary and three source-only
allocator-error cases are included. Stronger V atomic ordering, allocator failures
and arbitrary concurrent interleavings remain separate contracts.

The previous Unicode, TextField and Surface returning hashes remain unchanged in
both modes after explicit required-field caller updates. Reproduction, focused
consumer coverage and precise state limits are in the new
`vaxis/reference_probes/vxfw_list_view`, `vxfw_scroll_view` and `vxfw_spinner`
README files, with remaining layout arithmetic and iterator/lifecycle constructor
contracts recorded in the live audit.

The constructor continuation restores required fields for every exported
framework widget and its public builder/slice payloads, plus core contexts,
commands, widgets, surfaces and coordinates. Both modes pass 38 complete
constructor pairs, 57 paired ordinary omission rejections and 79 default-value
comparisons, SHA-256
`2917ca5cdc672d99b1c440daed7882a2da028cc5a1325097b444ce88a501dbbd`.
Source allocator arguments, pointer nullability/readonly types,
iterator records, Segment aliases and App manual lifecycle construction remain
explicitly outside this proof. Reproduction and exact excluded fields are in
`vaxis/reference_probes/vxfw_constructors/README.md`.

Recovery now registers a successful Tty initialization by value and exposes
`recover`, `panic_handler` and `Panic.call`. It emits the exact reset sequence,
restores terminal state even on write failure and preserves the saved snapshot
across repeated calls. The native macOS ordinary/Debug and production/ReleaseSafe
comparisons match 56 returning PTY records and fourteen explicit panic/order
pairs, SHA-256
`4101322a2b3636fd13ba3fa721e6bcedc928df711057799a2a46688d8d0dd645`.
Two focused consumer tests pass. Forty-eight source-only buffered observations,
SHA-256 `336343f9e968444519d30154bd7c1d6fed3e0451066c9f19f03b581da34db850`,
measure the separate buffered-source/unbuffered-V boundary. Six ordinary compiler
pairs record the removed Zig 0.15.2 `FormattedPanic` aliases; public-global access
is a separate measured adaptation. These digests include the fixture's macOS
termios representation. Writer state, global-variable access, panic stack/address
handling and cross-platform runtime parity remain excluded. Reproduction and
exact limitations are in `vaxis/reference_probes/recovery/README.md`.

Final integration passes 40/40 Vaxis and 44/44 image test files, Boo's focused
tests and native/Linux whole-application checks. Both Windows DLLs and all four
new focused widget/recovery test executables compile, and Vaxis links as an
x86_64 Linux shared library with GC disabled for that cross build. Cross-target
runtime parity and the live audit's remaining layout/iterator/lifecycle
boundaries remain unverified.

## Vaxis layout, text and Window output continuation

Layout widgets now preserve checked dimensions, proportions and callback order,
including captured Flex iteration slices alongside live distribution checks.
Text/RichText retain checked widths, rows, columns and usize cursors, source
saturation/truncation distinctions, borrowed graphemes and iterator reset order.
Window fill uses source-wide i17 endpoints and usize buffer products; all print
wrap modes use checked arithmetic and borrowed raw-byte grapheme views.

Both unchanged-source Debug/V ordinary and ReleaseSafe/V production comparisons
match 27,963 layout records/37 strict traps, 7,562 Text records/15 traps,
22,366 RichText records/11 traps and 33,215 Window records/15 traps. Their output
SHA-256 values are, respectively:

- `7530b735b2181ad9675dbf776110002b759a5fd3c60df25f2e794f553984c164`
- `d6f81838ac48054b14f76b3f3d607c13ca1e3153f1fb9959902596d47f0facac`
- `82d672df1b109891fa701681f003009fc56e1d28acfc32cfe27c946502342b48`
- `d97f410c29c874baeee7e5506ce5e55dd68bbdb2740061d1f7b2ea5a037d617b`

Text/RichText iterator records now require their source payload fields and retain
usize indices. Separate constructor probes measure source-private/V-public
iterator adapters and the GC arena adaptation. Plain CellSegment requires text;
the pinned V compiler still ignores this marker through TextSpan, whose compatible
alias remains. Source-only allocator outcomes are measured separately, and
undefined FlexRow cache reads are excluded from parity. Inherited CR/tab/Unicode
failures are isolated, and nonadvancing wide-glyph wrapping is retained. Private
heap shells avoid quadratic production keepalive
scans while retaining public values and borrowed storage; valid 65,535-cell draws
are included. The sixteen large RichText production cases now finish in 1.43
seconds on the measured host, replacing a timeout; timing is not a pass threshold.

Exact scope, reproduction and focused tests are in
`vaxis/reference_probes/vxfw_layout`, `vxfw_text`, `vxfw_rich_text` and
`window_output`. Source allocator/arena lifetime, readonly types, int-sized V
lengths, native ABI, App lifecycle and Window scroll/mouse/border contracts remain
outside this proof. Cross-target builds do not establish runtime parity.

Final integration passes 44/44 Vaxis test files, Boo's four focused tests and
native/Linux whole-application checks. Both Windows DLLs, all four new focused
test executables and the x86_64 Linux shared-library link pass. The unchanged
image module retains its preceding 44-file test result; it was not rerun for
this checkpoint. The existing constructor gate retains its 38 complete pairs,
57 omission pairs, 79 defaults and historical hash in both build modes.

## Vaxis Window and retained storage continuation

Window scroll/mouse operations now preserve checked copy/endpoint arithmetic,
overlap failures and source short circuits. Child borders retain complete edge
order before corners, including the cells written before a later failure.
Window records restore mutable fields and required payloads. Screen cell
methods use usize indices and explicit bounds checks before narrowing.

InternalScreen owns prior-frame character/link bytes, preserves capacity-fit
reuse and borrowed reads, and follows Source's public header/copy update order.
Initial spaces are independently allocated. Source's strict coordinate guards,
u16 read indices and equality fastpath remain intact. GraphemeCache retains its
inline 8 KiB/by-value storage with public mutable fields, checked usize sums,
wrapping, alias guards and mutable borrowed returns.

The six new unchanged-source comparisons pass in ordinary/Debug and
production/ReleaseSafe: 170,387 scroll/mouse records/16 strict traps, 19,963
border records/16 traps, 311 record-contract observations, 7,088 Screen
records/12 traps, 6,570 InternalScreen records/19 traps and 32,932 cache
records/10 traps. Total returning records are 237,251 with 73 strict trap pairs.
Separate fixture-only panic/exit observers match 16 border, four retained-cell
and ten cache failure states without changing Source statements or resuming
execution. Hashes and reproduction commands are in the corresponding
`vaxis/reference_probes/window_state`, `window_border`, `window_contracts`,
`screen_cells`, `internal_screen` and `grapheme_cache` README files.

Window constructor probes separately check seven complete pairs, eleven
required omissions and two invalid fixed-array lengths. Wider i17 V literals,
required fields through aliases, explicit nil pointers, packed ABI and boxed
border-carrier copies remain measured differences. InternalScreen measures two
supplied-allocator differences and a V-only array limit; capacity-growth
remapping, ArrayList payload APIs and post-deinit Source state remain separate
contracts. Undefined unwritten cache defaults are excluded. These scopes do not
certify allocator/GC, readonly/nullability, native ABI, oversized V carriers or
the remaining App lifecycle/private pipeline behavior.

Integration passes 50/50 Vaxis test files, Boo's four focused consumers and
native/Linux application checks. Both Windows DLLs, all six new focused test
executables and an x86_64 Linux shared-library link pass. Cross-target runtime
was not exercised; the unchanged image module retains its preceding 44-file
test result.
