# Ongoing Source-Fidelity Audit

This is a working record of the function-by-function audit of Witty against the
pinned Ghostty source. It is not evidence of full coverage, and the repository
must not be described as a 100% translation while the remaining divergences
below exist. Earlier versions of this document overstated the completed review.

Later sessions recorded additional fixes in the resolution ledger of
[AUDIT_FINDINGS_ULTRA.md](AUDIT_FINDINGS_ULTRA.md). Older entries below are
historical checkpoints; the dependency coverage notes are updated as their
current implementations and verification are checked again.

## Bugs found and FIXED this pass

| Area | Bug | Fix |
|---|---|---|
| zigimg JPEG public headers and tables | Header fields were immutable/defaulted, Huffman constructors silently omitted required fields, component reading and cleanup hooks were private/absent, sampling maxima used int, and quantization records admitted both union arms. | Restore required mutable represented fields, expose component reading and cleanup hooks, return usize maxima and use tagged fixed-array quantization payloads. Both modes match 17,747 returning observations, 22 omission pairs, seven immutable-binding pairs and two invalid-tag constructor pairs. Eighteen boxed payload-copy differences, one const-slice difference and five wider-carrier construction differences remain measured adaptations. Decoder hashes and failure states remain unchanged. |
| zigimg JPEG checked decoding and Huffman borrowing | Production removed segment/header/entropy checks and marker validation, coefficient arithmetic wrapped, the reader copied its table, and eager table unwrapping changed short-input failure order. | Preserve explicit source panic categories and checked i32 intermediates, borrow stable mutable table storage, defer optional-table access until the source does, and check the q8 arm only during actual sample multiplication. Both build modes match 15,805 returning observations, thirty strict panic/state pairs, three inherited discard loops and reader constructor controls; the historical 132-row matrix retains its results. Undefined coefficients, remaining record/allocator/ABI contracts and the source quantization-header compiler failure remain separate limits. |
| vaxis URI reports and rendering arithmetic | Working-directory reports interpolated raw host/path bytes, resize mouse names used V enum spelling, and widened counters/assertions lost checked render/pretty-print boundaries. | Translate the pinned URI byte predicates and uppercase percent escapes, use source mouse names, and retain u16/u8/usize arithmetic, invariant and pixel-offset failures explicitly. Public comparisons cover successful output and retained state; failing-writer defers, partial output and flush ordering remain boundaries of the existing string-return adapter. |
| vaxis input Parser and macOS TTY lifecycle | Public Parser storage was private, Result fields defaulted, malformed APC/DA1/mouse/clipboard input and UTF-8 capacity ordering diverged, and production removed checks. macOS TTY deinit invalidated a descriptor that the source leaves usable. | Restore mutable Parser/required Result records, checked input boundaries and partial scratch order. Preserve the macOS descriptor and repeated terminal restoration. Both build modes match 79,299 Parser records, nineteen strict trap pairs, direct constructor contracts and forty real PTY records; alias-required markers, packed carriers, GC and configurable writer buffers remain measured boundaries. |
| zigimg TIFF production checks | Assertions disappeared in optimized V builds, allowing invalid metadata enums, tag-array mismatch and palette powers to return; strip, CCITT, PackBits and shared DEFLATE checks also depended on assertions. | Preserve explicit checked failures in source order, distinguish HashMap cast and power overflow, and guard V-only array length limits separately. Modernize the decoder proof and add a provenance-checked metadata proof with strict panic categories, retained commands/diagnostics and ordinary/production modes. Their defined returning results retain the source hashes. |
| vaxis App public state and event pipeline | Required state fields were private or defaulted, production erased command/focus checks, callback errors skipped per-event reset, and adding a timer sorted only the last item even when callers reordered the public list. | Restore public mutable required fields and explicit init payloads, preserve runtime invariants and zero-size division traps, defer per-event reset, and stably sort the complete timer list. Separate unchanged-source record and public PTY comparisons cover supported copies, lifecycle, routing, commands, timers and callback failures; allocator, buffered TTY output, alias markers and cross-target runtime remain documented boundaries. |
| vaxis shared Unicode APIs | Public width and grapheme helpers decoded through V runes and lost malformed-byte consumption, checked width totals, and source borrowing/prefetch timing. | Reuse the locked byte decoder for the public helpers and expose borrowed Grapheme spans and initialized iterators. DrawContext initializes its decoder at the factory call. Ordinary and production comparisons match 72,225 records, fourteen strict traps and both required-span-field omission checks; the original TextInput matrix retains its hash. Opaque iterator state and V string call shapes remain documented adaptations. |
| vaxis vxfw TextField | Insertion/navigation/drawing normalized raw bytes, count/width/draw arithmetic lost checked source bounds in production, caller-buffer copying omitted alias checks, and rendered graphemes copied the gap buffer. | Use the shared byte decoder, explicit checked arithmetic and borrowed buffer views. Preserve callback mutation/error ordering and retained previous-value snapshots. Ordinary and production source comparisons match 18,911 returning records and sixteen strict trap pairs. Six focused tests pass. The unused u4 scroll field remains a measured wider-storage constructor boundary. |
| vaxis framework surfaces and delegated Window coordinates | Surface indexing widened source u16 operations, production erased invariant checks, rendering restricted valid i17 offsets to i16, and delegated coordinate sums lost checked arithmetic and short-circuit order. | Restore explicit u16/i17 checks, borrowed trimming, source-wide offsets, and checked child/cell/cursor coordinates. Ordinary and production comparisons match 11,162 records and twenty-eight strict traps; four focused consumers pass. The comparison covers initialized surface methods and delegated Window methods, with constructor/allocator and wider backing-field limits recorded separately. |
| zigimg SIMD helpers and image dimension checks | All six public array/vector helpers were absent, and production optimization erased image pixel-count and crop-box assertions. | Add fixed-array load, byte load, compatible numeric/boolean/struct/pointer stores, integer/float conversion and fallback permutation helpers with checked casts, per-lane bounds, named lane types and pointer inputs. Enforce source assignment widths, signedness and numeric categories explicitly for aliases. Preserve partial stores and the pinned ARM64 NaN result. Replace image dimension assertions with explicit checked operations in source order. Both build modes match 60,109 records, twenty-two strict traps and thirty-five ordinary compiler pairs. Native vector layout/overlap, AVX2 indexing, comptime lengths, zero-length arrays and the pinned pointer-alias constructor defect retain documented boundaries. |
| zigimg complete PNG reader verification | The integrated reader lacked a committed complete-image differential runner and dedicated decoder tests; its final decompression call was inside an assertion. | Evaluate final decompression once, then assert its result as in the source. Add unchanged-source comparisons for memory/file loading, all 15 color/depth pairs, every filter, Adam7, stored/fixed/dynamic zlib, consecutive IDAT lengths/read-ahead/CRCs, metadata, truncation, callback order/failures, and large rows/windows. Isolate pixel-count, extra-output, Adam7 byte-row, skip-length, palette-alpha, and repeated-16-bit-tRNS traps. Dedicated tests cover pixel values, processor state, registry loading, and the inherited small-file-buffer IHDR CRC failure. Allocator/root-option and representation boundaries remain below. |
| zigimg PNG information processor | The pinned diagnostic processor and its options wrapper were absent. | Translate every chunk/palette diagnostic, IDAT counters, binary byte-size formatting, text-field truncation, and zTXt buffered decompression using the pinned zlib dependency. Preserve raw compressed iTXt output, unknown-zTXt-method positioning, ignored ancillary CRCs, suppressed writer failures with partially consumed chunks, exact spelling/spacing, and checked delimiter/tag/counter traps. The unchanged source matches 51,223 cases and twelve isolated traps. All 28 image test files, native/Linux checks, and Windows DLL/focused-test compilation pass. The complete reader and file streams were subsequently integrated; allocator/root-option and representation boundaries remain open. |
| zigimg PNG header, filtering, and processors | Header loading, scanline filtering/defiltering/spreading, and the reader processor/options surface were absent. | Translate chunk IDs/headers, IHDR validation and CRC, all five filters and the pinned heuristic, opaque-context callbacks, borrowed generic option storage, and tRNS/PLTE processors. Preserve open compression/filter bytes, error positions, first ancillary versus all critical callbacks, callback state after failure, repeated tRNS replacement, gray16 byte-index comparisons, and RGBA palette writes independent of destination channel order/width. Unchanged-source matrices match 74,260 defined cases; fourteen checked traps and the inherited zero-stride loop match in isolated processes. All 27 image test files, native/Linux checks, and Windows DLL/focused-test compilation pass. The later complete-reader checkpoint is below; allocator/root-option and representation/undefined-memory boundaries remain open. |
| zigimg TIFF decoder | The pinned strip reader, compression wrappers, and read/readImage APIs were absent. | Translate all five accepted pixel storage paths and all six accepted compression kinds, including the Zig 0.15.2 zlib buffered-reader dependency. Preserve unchecked TIFF versions, ignored compressed byte counts outside PackBits, floor-rounded one-bit rows, wrapping predictors for every value other than one, CCITT photometric truncation, linear clipping, partial writes, and read-ahead/error positions. An unchanged-source differential run matches 39,707 cases and fifteen checked traps. All 25 image test files, native/Linux checks, and Windows DLL/test compilation pass. Undefined-memory/GC/ABI boundaries, diagnostics, automatic loading, and the remaining codecs/interfaces stay open below. |
| zigimg TIFF metadata | The pinned packed records, IFD/tag model, bitmap metadata processing, format selection, and row sizing were absent. | Translate all 32 tag IDs, both byte orders, SHORT/LONG and rational access, duplicate-tag replacement, Zig 0.15.2 hash-table placement/growth/iteration, bitmap defaults, palette planes, and pixel-format constraints. Preserve raw inline SHORT words, ignored fill-order/orientation tags, partial tag-array reads, capacity-dependent palette processing order, and floor-rounded one-bit row sizes. Native hashes match 3,072 table mutations, 38,400 format/row cases, and 4,224 metadata/palette cases. Thirteen checked-trap probes, all 24 image test files, native/Linux checks, and Windows DLL/test compilation pass. Host-specific logger/rendering, the remaining generic map API, allocator reclamation, and undefined-memory/aggregate representation limits remain below. |
| zigimg in-memory format detection | Both image APIs lacked the pinned 17-detector registry and JPEG/TIFF signature checks. | Translate ordered detection with seeking before each check and propagated detector errors. Preserve short-input blocking, TIFF's byte-order-only acceptance and swallowed peek errors, TGA precedence over TIFF, and the inherited XBM non-advancing loop. The unchanged native source matches 589,824 prefix/length cases; direct tests cover every returning format, both image APIs, detector positions, and ambiguous signatures. Separate process timeouts verify the XBM loop through both image APIs. Twenty-three image test files, native/Linux checking, and Windows DLL/test compilation pass. Automatic loading, reader dispatch, file methods, and the remaining codec/interface surfaces stay open. |
| zigimg managed images and encoder dispatch | Managed image construction/editing methods, image-wide encoder options, managed/unmanaged views, and fixed-memory image writers were absent. Image dimensions could wrap in creation/cropping and zero-height row/flip operations lacked explicit checked traps. | Translate creation/raw copying, metadata, editing, live iteration, conversion, shallow views, lifecycle hooks, all 17 option tags, and fixed-buffer dispatch. Views copy slice headers while sharing pixels, palettes, and frame arrays. Preserve partial writes and the pinned JPEG/TIFF no-op writers. Twenty-two image test files pass; an unchanged-source native matrix matches 6,528 managed/unmanaged writer cases, and eight subprocess probes verify dimension overflow and zero-height traps. Linux checking and Windows DLL/test compilation pass. File I/O, loading/detection, allocator reclamation, read-only slice enforcement, and aggregate ABI boundaries remain below. |
| zigimg pixel-format converter | The locked conversion table and unmanaged-image conversion methods were absent. | Translate all 460 table entries through their source conversion groups, including indexed quantization, integer scaling, weighted f32 grayscale, and alpha handling. Preserve omitted pairs, nine BGR555 wrong-union traps, straight rgba-to-RGB332, premultiplied indexed-to-RGB332/rgba64-to-BGRA32, full returned palettes despite local slice shortening, four empty alignment traps, and SIMD-prefix truncation versus scalar-tail rounding. Twenty-one image test files pass; unchanged native hashes match 18,432 format-pair cases and 6,066,176 precision conversions. Separate probes verify nineteen traps and the pinned ARM64 NaN-prefix result; Linux checking and Windows DLL/test compilation pass. Allocator, CPU-feature/float-cast, and remaining image API boundaries are recorded below. |
| zigimg octree quantizer | The locked palette quantizer, per-level node lists, and RGB(A) input normalization were absent. | Translate tree insertion, weighted averages, palette borrowing/order, first-child lookup fallback, checked leaf accumulation, wrapping reduction sums, and f32 alpha/channel scaling. Preserve sufficient-budget behavior, skipped level zero, zero-budget/default indices, and repeated-reduction/capacity traps. Twenty image test files pass; native hashes match 2,160 tree/palette/index cases and 336,128 color-normalization cases, with six separate checked-bound probes. Linux checking and Windows DLL/test compilation pass. Arena/root/generic representation limits remain below. |
| zigimg TGA codec | The locked TGA record/extension model, raw/RLE reader, and encoders were absent. | Translate the packed metadata, 512-byte buffered packet decoder, palettes, alpha policy, seven encoder storage formats, row ordering, and scalar equivalents of both RLE encoders. Preserve the 26-byte minimum, different detector/reader footer checks, unchecked origins/direction flags, active-palette indexing, extension-only alpha override, 256-byte ID omission, 39-byte metadata-name limit, SIMD tail splitting, and conversion runs across rows. Native hashes match 2,016 encoder and 1,120 decoder cases; nineteen image test files, separate checked-bound probes, Linux checking, and Windows DLL/test compilation pass. CPU-feature selection, sentinel/initialization, and image-wide API boundaries remain below. |
| zigimg GIF decoder | The locked GIF header/extension model, sub-block/LZW reader, and animation renderer were absent. | Translate both versions, global/local palettes, comments/application records, frame grouping/filtering, interlacing, transparency, all disposal paths, and first-frame sharing. Preserve ignored extension size/terminator fields, byte-scanned unknown extensions, indexed transparency without palette-alpha changes, final-local-palette overwrite, canvas-height interlacing, linear clipping, shifted RGBA background channels, opaque restoration to a transparency color, ignored LZW write failures, and the no-op writer. Eighteen image test files and unchanged native reference checks pass; separate probes verify text-count, buffered-toss, loop-count, and indexed-background bounds. Linux checking and Windows DLL/test compilation pass. GC/initialization and image-wide API boundaries remain below. |
| zigimg IFF decoder | The locked IFF chunk/header model, PBM/ILBM/ACBM reader, planar conversion, Atari ByteRun2, and HAM/EHB palette paths were absent. | Translate them with source chunk lengths, unpadded walking, unclipped planar bits, ACBM's raw path despite the compression flag, HAM row state, EHB priority, and partial-input positions. Preserve rejected DEEP detection, its zero/non-consuming header stub, and the no-op writer. Seventeen image test files and unchanged native reference checks pass; separate V/Zig probes verify checked stride, padding, empty-palette, and HAM bounds. Linux checking and Windows DLL/test compilation pass. Initialization and diagnostic/API boundaries remain below. |
| zigimg compression helpers | The locked PackBits, endian-parameterized LZW, and CCITT decoders were absent. | Translate declared-length PackBits runs, LZW dictionaries/clear/end codes/early change/partial-input continuation, and all 195 CCITT codes with row/color state. Preserve ignored LZW unknown codes, first partial-code processing, empty-resume data loss, dictionary mutation order on write failure, PackBits's unread final control, and CCITT's cumulative padding and absent partial-byte flush. Sixteen image test files pass; a separate native harness verifies unchanged locked source copies and exact table fingerprints. Linux checking and Windows DLL/test compilation pass. |
| zigimg BMP codec | The locked BMP headers, reader, and writer were absent. | Translate all three info-header representations, color-space/intent/CIE metadata, V4/V5 BGR24/BGRA32 selection, bottom-up rows, and exact encoder header bytes. Preserve ignored offsets/masks, omitted row padding, Windows 3.1 header rejection after consumption, signed and zero-dimension paths, unconventional encoder masks, and partial-write/error positions. Thirteen image test files and unmodified native reference checks pass, with Linux checking and Windows compilation. |
| zigimg PCX codec | The locked PCX reader, writer, and RLE encoders were absent. | Translate the 128-byte header, indexed and planar RGB decoding, built-in/end-relative VGA palettes, bit/nibble packing, and streaming/16-byte RLE paths. Preserve ignored compression flags, signed stride comparison, row discard boundaries, even-width bitmap tail loss, short active palettes, whole-slice indexed encoding, and the fast encoder's run accumulation across different 16-byte chunks. Twelve image test files and unmodified native reference checks pass, with Linux checking and Windows compilation. |
| zigimg XBM decoder | The locked XBM decoder was absent. | Translate ordered define values, zero-sentinel hotspots, white/black indexed palette, continuous LSB-first bits, hexadecimal token collection, truncated two-byte words, and newline/EOF behavior. Preserve the no-op writer and source detector that repeatedly peeks at a leading define without advancing. Eleven image test files and native reference comparisons pass, with Linux checking and Windows compilation; separate bounded V/Zig process probes verify the detector loop without hanging the suite. |
| zigimg PAM codec | The locked PAM header parser, sample decoding/encoding, and image-sequence handling were absent. | Translate tuple inference/validation, comments and token boundaries, all six tuple types, source little-endian 16-bit samples, floor scaling, monochrome-alpha AND, subsequent animation frames, and encoder comments. Preserve short trailing magic bytes, error positions, and the source's omitted grayscale2 writer branch. Native checks verify decoding and exact encoder bytes; duration formatting matches Zig over 19,968 float bit patterns. Ten image test files, Linux checking, and Windows compilation pass. |
| Windows numeric locale helper | Importing the shared numeric parser into PAM exposed its unconditional use of POSIX locale APIs under MinGW. | Use the Windows CRT's locale creation, float/double conversion, and locale release functions while retaining the C numeric locale and direct f32 conversion. Native numeric tests pass and the float-parser test executable cross compiles. Windows runtime behavior remains untested. |
| zigimg SGI decoder | The locked SGI decoder and shared fixed palette storage were absent. | Translate its 510-byte big-endian header, planar channels, bottom-up rows, uncompressed data, and 8/16-bit RLE with absolute row tables. Preserve the source's byte-indexed/byte-swapped RGBA64 alpha, grayscale8 selection for 16-bit grayscale, unclipped RLE runs, consumption of trailing compressed data, and successful writer that emits no bytes. Nine V test files and native reference comparisons pass, with Linux checking and Windows compilation. |
| zigimg Sun raster decoder | The locked RAS decoder was absent, including its inline palette and RLE path. | Translate the 28-byte big-endian header, pixel-format selection, planar palette, opaque 32-bit color conversion, one-bit padding/polarity, and clipped RLE runs. Preserve the source's raw copy for one-bit indexed images, absent padding for other depths, consumed-prefix EOF behavior, and successful writer that emits no bytes. Eight V test files, native reference comparisons, Linux checking, and Windows compilation pass. |
| zigimg Netpbm codecs and bit streams | The locked dependency's PBM/PGM/PPM readers and writers, and its borrowed Zig bit-stream implementations, were absent. | Translate all six Netpbm encodings and both bit orders, preserving source comments/token limits, bitmap polarity/row padding, sample-scaling differences, partial EOF, bit-pattern casts, and failed-flush state. The native reference harness checks decoder results, exact encoder bytes, parser errors, and bit-stream boundary cases. Seven V test files and Windows DLL cross compilation pass. Arbitrary-width/aggregate bit types and the image-wide encoder-options union remain outside this slice. |
| zigimg image editing and pixel iteration | The image foundation lacked pinned `ImageEditor` and `PixelStorageIterator`. | Translate crop-box clamping, independent cropped pixel/palette storage, in-place vertical row swaps, and pointer-backed pixel iteration across every storage variant. Preserve straight alpha, packed channel bit order, the iterator's initial length and live storage pointer, and the editor's animation behavior. Five image test files, native checks against the unmodified locked Zig dependency, and Windows DLL cross compilation pass. Allocator and representation limits remain below. |
| zigimg image foundation and memory codecs | The locked vaxis image dependency had no V translation. | Translate all pixel-format words/storage variants, borrowed raw storage, indexed palette capacity/slices, memory streams, raw image construction, and QOI/farbfeld memory codecs. Preserve the exact pinned PNG writer, whose chunk-writing bodies are commented out and which emits only its signature. Native Zig reference execution verifies QOI/farbfeld bytes and PNG output/errors; three V test files and Windows DLL cross compilation pass. Remaining library/API and format coverage is listed below. |
| vaxis fixed reader/parser storage | POSIX input accumulated in a dynamic pending buffer, Windows embedded ANSI input grew dynamically, CSI key text owned independent strings, and malformed OSC color/base64 reports silently lost the source errors. | Restore the 1,024-byte POSIX read buffer, pinned incomplete-sequence offset/read-count behavior, 128-byte Windows ANSI state, and public parser with borrowed input/CSI text. Translate the locked uucode UTF-8 DFA and unsigned parameter/base64 validation; propagate OSC errors on both live reader paths. Focused tests cover source buffer quirks, partial CSI scratch writes, malformed UTF-8 byte consumption, and report errors; the native PTY smoke and Windows framework DLL cross compilation pass. |
| vaxis input reader thread creation | V's `spawn` panicked on native thread creation failures, used a different default stack, and reader I/O errors were silently discarded. | Restore fallible POSIX/Windows thread creation with the source's 16 MiB default stack, native argument ownership, join/handle cleanup, allocation/resource error results, and reader-error reporting. The preview and framework propagate start failures. Native PTY tests cover idempotent start and status-query shutdown; the framework PTY smoke passes and its Windows DLL cross compiles. |
| vaxis widget framework and `boo` | The pinned `vxfw` package was absent and `boo` emitted ANSI frames from a polling/sleep loop. | Translate the framework event/command surface, surfaces, hit testing, focus and mouse routing, timers, retained application loop, and all 15 widgets. Route `boo` through `vxfw.App` and its fixed 4,100-cell widget buffer with borrowed cells, source span styles, centering/minimum-size layout, tick scheduling, and exit keys. Six focused framework test files and all-frame `boo` tests pass; a native PTY smoke test exercises startup queries, rendering, Escape exit, device-status shutdown, and restoration. GC/allocator and coordinate representation limits remain below. |
| vaxis grapheme cache inline storage | The wrapping cache used a dynamic array to work around V's copying fixed-array slices, so its aggregate storage differed from pinned `GraphemeCache`. | Restore the inline `[8192]u8` and return explicit borrowed byte views. Tests pin aggregate size, overwrite-on-wrap, and an empty view at the end of the buffer. |
| vaxis application event loop | The input loop was specialized to `InputEvent`, so applications could neither post their own event variants nor subscribe to a subset of terminal events as pinned `Loop(Event)` permits. | Translate `Loop[T]` over an application sum type, retaining the 512-entry queue and blocking/nonblocking operations; filter terminal variants at compile time while processing reports regardless of subscriptions. Initial and signal resizes use the same subscription filter, and the theme preview declares the source's four terminal event variants. Unit and PTY cases cover custom events, omitted variants, report interception, queue bounds, and multiple loop specializations. |
| vaxis reader key text and shutdown boundary | The translated wrapping grapheme cache was not used by the input reader, Windows shutdown omitted the source's device-status query, and POSIX shutdown could remain blocked because `Tty.next_input` kept reading after a status reply that the parser discarded. Existing PTY tests supplied an application key to wake it. | Borrow subscribed key-press/release text from the reader's cache, preserving overwrite-on-wrap behavior; send the device-status query on both platforms; restore the POSIX raw-read boundary through `Tty.read` so an ignored reply lets the worker observe shutdown. PTY tests now reply to the actual query without adding application events. Platform reader files and an opaque thread argument avoid the pinned V compiler's generic platform-condition and thread-wrapper ABI defects. |
| vaxis blocking capability query | Pinned `queryTerminal` sends the probe, waits up to the caller's deadline for the reader's DA1 wakeup, then enables features; Witty implemented this only as an 8 ms poll loop in the theme preview and drained application events into a side list while waiting. | Add a source-shaped `Vaxis.query_terminal` with a timed wake condition, signal it from DA1 interception, and let the preview use it so queued application events remain in the loop. PTY coverage checks an early DA1 wakeup before queue drainage and the timeout path. The condition/mutex are a V representation of the source futex and are released with the session. |
| vaxis Windows console input | The loop read Windows input through V's `term.key_pressed`, losing native key releases, mouse, focus, and resize records; the session handler also discarded key-release events even if they were produced. | Translate pinned `WindowsTty.nextEvent`'s `ReadConsoleInputW` loop, UTF-16 pair and embedded ANSI handling, virtual-key map, button-state tracking, and mouse/focus/resize records; forward key releases through the Windows event handler. The Windows vaxis DLL cross compiles with MinGW. The unused legacy `Tty.poll` adapter remains below. |
| vaxis Windows console session setup | The Windows `Tty` adapter never read or set console modes or the output code page, wrote through process `print`, and derived winsize from a generic terminal helper. Pinned `WindowsTty` saves the original modes/code page, enables raw window/mouse input and VT/UTF-8 output, writes to its console handle, queries the visible buffer rectangle, and restores/closes those handles at teardown. | Translate that console ownership and I/O surface through Win32 APIs. The Windows vaxis type gate passes, but no Windows runtime test was available. |
| vaxis POSIX terminal restoration diagnostics | Pinned `PosixTty.deinit` logs a failed restoration of the original termios, while Witty ignored the `tcsetattr` result. A teardown failure could leave a user's terminal in raw mode without a diagnostic. | Check the restore result and log its POSIX error before following the pinned descriptor-close policy. |
| GTK command-palette activation lifetime | Ghostty obtains a strong reference to the selected command from its selection model before closing the dialog. Witty closed first and only then indexed palette-owned command arrays, so a synchronous close/finalize could dispose the command and clear the window before activation used them. | Resolve the visible command before closing and hold a native palette reference through dispatch, preserving the selected wrapper and its action/surface state until activation returns. Invalid positions still close the dialog as in Ghostty. |
| vaxis reader-thread capability handling | The input loop queued parsed terminal reports and applied vaxis capability and DA1 handling only when the preview drained that queue. A DA1 response therefore could not end startup's query wait until the UI polled, and other capabilities could be delayed behind unrelated application events. The shared query flag was also a plain boolean despite cross-thread access. | Intercept parsed input on the reader thread before posting application events, keep direct and SIGWINCH events as direct queue posts, and use an atomic query flag. PTY coverage verifies DA1 completes before queue drainage and that the report does not become an application event. |
| GTK template byte ownership | Nine hand-expanded class initializers retained the caller's `GBytes` reference after `gtk_widget_class_set_template`, leaking one reference per registered class. | Drop the caller reference immediately after installing each template, following the existing clipboard dialog pattern; GTK retains its own template reference. |
| Theme preview clipboard output | The preview's copy-name and copy-path keys still called the old stdout helper after the session renderer moved to the controlling TTY, so OSC 52 could be redirected away from the terminal. | Bind the preview's active `Tty` during `run` and write the translated clipboard sequence through its terminal descriptor. |
| vaxis previous-screen storage | Pinned vaxis keeps an `InternalScreen` of prior cells for diff rendering, including default/skipped/skip flags, link IDs, cursor state, and mouse/cursor shapes; Witty had no corresponding state. | Translate `InternalCell` equality and `InternalScreen` initialization, indexed read/write, release, and state fields. V strings replace the source arena-owned byte lists; render-diff integration remains open. |
| vaxis Window behavior | The adapter had no retained window type, so source child clipping, borders, cell writes, fill, cursor state, wrap modes, word/line tokenization, scrolling, and mouse hit testing could not be expressed. | Translate pinned `Window.zig`'s child/border, read/write, fill/clear, cursor, print, scroll, and mouse methods over the retained `Screen`, including source word-wrap and line-iterator quirks. Verify source print and child cases directly. Preview migration to these types remains open. |
| vaxis Cell and Screen storage | The compatibility layer had no retained source `Cell` values or `Screen` buffer, so even basic indexed cell writes, reads, clears, cursor state, image placement values, and width-method storage were absent. | Translate the pinned value records and `Screen` state with its in-bounds read/write, clear, and release operations; retain `Scale`'s thirteen-bit packed value and source defaults. This is the base for the render-diff migration. |
| Theme preview width propagation | List rows, links, boxes, and sample segments kept clipping with the default `wcwidth` method after the preview switched its search widget to Unicode width. Preview centering also counted runes where Ghostty uses byte lengths. | Carry the selected width method through all ANSI preview helpers and restore Ghostty's byte-length centering calculations. |
| Theme sample segment widths | The preview's sample code advanced and wrapped syntax-colored segments by rune count, so wide glyphs and combining sequences shifted subsequent colors or caused early wrapping. | Walk vaxis grapheme clusters, use the selected terminal width method, and carry one cursor across all segments exactly as pinned `Window.print(.grapheme)` does. |
| vaxis ANSI adapter clipping | The preview's `truncate` helper used rune count, so a two-cell grapheme could spill past a child window and combining sequences could be split at the edge. | Traverse pinned vaxis grapheme clusters and advance by the selected width method, skipping zero-width clusters and stopping at a newline as `Window.print` does. The default adapter call uses vaxis' initial `wcwidth` method. |
| vaxis clipboard copy terminator | The theme preview's OSC 52 copy helper ended its payload with BEL, while pinned vaxis uses ST. | Emit the source's OSC 52 sequence and verify the encoded payload and terminator directly. |
| Theme preview Unicode width selection | The preview never queried vaxis' Unicode width capability, so its search widget continued counting every codepoint with `wcwidth` even after a terminal reported Unicode grapheme width support. | Query DECRQM 2027, retain the reported method in preview state, enable mode 2027 on a positive response, and pass the method to the translated text-input renderer and cursor measurement. |
| vaxis grapheme width | The text-input draw adapter used Ghostty's Unicode width table, and the compatibility layer had no translation of vaxis' three `gwidth.Method` strategies. The two pinned uucode revisions share Unicode 16 data but differ on emoji modifier grapheme boundaries. | Generate vaxis' East Asian width, mark, emoji-presentation, and control ranges from its locked uucode UCD; translate `unicode`, `wcwidth`, and `no_zwj` width rules and adapt emoji modifier boundaries to vaxis' untailored iterator for parser and widget text. Verify the generated binary is reproducible from the pinned UCD. |
| vaxis text-input drawing | The gap-buffer editor had no translation of `TextInput.draw`, `drawWithStyle`, or `widthToCursor`. The theme search box instead printed the entire buffer from the wrong interior column, counted runes instead of cell widths for the cursor, and never scrolled or drew edge ellipses. | Translate the widget's scroll offset, first/second-half cell writes, cursor position, and ellipsis rules into cell commands for the existing ANSI adapter; draw those cells in the search box's interior and test narrow, moved-cursor, wide, and combining-grapheme cases. |
| Theme preview terminal color scheme | `Preview.init` and `run` guessed dark/light from `COLORFGBG`, although pinned vaxis starts in light mode and changes only after a terminal report. Witty neither queried support for color-scheme updates nor subscribed after receiving that capability. Its session wrapper also used OSC 0 with BEL and an incomplete mouse mode sequence. | Start light, query DECRQM 2031, subscribe with the pinned request/mode sequences when support is reported, reset the subscription on exit, and restore vaxis' OSC 2/ST title and mouse mode sequences. |
| Theme preview rendering | The preview omitted the pinned cursor and selection swatches, most styled code segments, the second shell prompt component, diagnostic formatting, and continuous lorem text; it also compressed the six-row palette into five rows and erased the source iterator's empty tokens. | Restore Ghostty's color, sample, palette, diagnostic, and repeated-text layout using the translated ANSI renderer, retaining empty split tokens and the source's explicit-color requirement for optional cursor/selection values. |
| GTK wrapper ownership surface | Application, ImGui/inspector widgets, resize/search/child-exit/scrolled-surface widgets, tabs, and windows omitted the public native `ref`/`unref` entry points supplied by Ghostty's class `Common` helper; the surface `ref` also returned an unsafe address expression instead of its receiver, and four non-dialog wrappers omitted their source `refSink` entry point. Search match setters additionally widened source `usize` values to `u64` at the V API boundary and callers manually projected them back. | Restore each audited ownership operation on its canonical native object, return each wrapper from `ref`/`ref_sink`, retain `usize` through the search API, and widen only in the registered `u64` GObject property storage. |
| GTK config identity and diagnostics | Application reload mutated a stable `Config` wrapper and compensated by manually reapplying surface and tab state from the window callback, rather than replacing Ghostty's reference-counted config object. `diagnostics_buffer` also exposed a nonoptional native pointer and accepted diagnostics larger than Ghostty's fixed 4095-byte writer. | Replace the application config GObject on every config change so normal property bindings and ownership propagate it, remove the stable-wrapper mutation API and source-external refresh loop, restore the optional buffer contract, and omit/log diagnostics that overflow the source-sized writer. |
| GTK dialog ownership helpers | The otherwise source-faithful base `Dialog`, `DebugWarning`, and `SurfaceTitleDialog` translations incremented their native reference counts but discarded the self pointer returned by Ghostty's shared `Common.ref` helper. | Restore the self-returning `ref` contract on all three audited wrappers while retaining their existing native reference operations. |
| GTK config-errors dialog ownership | `ConfigErrorsDialog` retained the same `Config` in both its native object property and a V wrapper field, but no production path called the wrapper's manual disposer, leaking the second reference. It also connected each instance to the inherited response signal instead of installing Ghostty's response virtual method, retained an unused parallel callback, returned a nonoptional config, and discarded the return from `ref`. | Make the registered private property the sole config owner, recover it through the canonical `Config` wrapper only on demand, install the response vfunc at class initialization, construct transient wrappers from weak native references, and restore the optional getter and self-returning ownership helper. |
| GTK clipboard-dialog property authority | `ClipboardConfirmationDialog` registered its source boxed request as an unowned raw pointer, left native request notifications inert, registered the text-buffer property as generic `GObject`, and kept parallel V request/buffer/blur/template state. Construction bypassed all four properties, confirmation read a copied string instead of the native buffer, the remember result was incorrectly forced false whenever the row was hidden, and the 1.4-only switch template was installed even when the capability check rejected `AdwSwitchRow`. | Register and own the exact `GhosttyClipboardRequest` boxed value, make the native private properties authoritative, construct through those properties, drive request text from `notify::request`, type the buffer property as `GtkTextBuffer`, read confirmation text back from that buffer, restore the optional getter and self-returning `ref`, derive the response flag solely from the supported switch as Ghostty does, and select the corresponding 1.0 template when that switch is unavailable. |
| GTK close-dialog property authority | `CloseConfirmationDialog` duplicated its writable native `target` property in a V field and used the duplicate for heading/body text, so an external property change was ignored. Its translated Common ownership surface also omitted `refSink`, and `ref` discarded the returned self pointer. | Keep target state solely in the registered instance-private property, read it when presenting, and restore the source-shaped `ref`/`refSink` ownership results. |
| GTK scrolled-surface contract | `SurfaceScrolledWindow.get_surface` claimed to return a non-null surface even though the property is optional and its translated test sets it to null. The property callback also silently skipped a missing or wrong-type template child where Ghostty requires and casts the `GtkScrolledWindow`. | Restore the optional getter type and assert the required template child and native widget type before reparenting the surface. |
| GTK tab close action ordering | The translated callback parsed and diagnosed the close mode before checking whether the tab belonged to an `AdwTabView`, while Ghostty ignores the action for a detached tab before validating its externally supplied string. Its typed public helper also retained an impossible enum fallback absent from the source. | Resolve the parent view/page first inside the private action handler, then validate and exhaustively dispatch the three close modes in source order. |
| GTK tab child invariants | Tab accessors silently accepted a missing template split-tree child even though Ghostty requires that child after initialization. | Restore the non-null split-tree child invariants in active-surface, surface-tree, and quit-confirmation accessors. |
| GTK split rebuild cleanup | Each tree rebuild retained the V wrappers for every disposed scrolled-window and split-pane object until the entire tab finalized. The `new-split` action also silently ignored a missing parameter, and the surface close confirmation was presented relative to the leaf surface rather than Ghostty's split-tree widget. | Release obsolete wrappers at the orphaned-tree rebuild boundary, restore the externally-triggerable action warning, and present close confirmation from the split tree. |
| GTK split-tree ownership | New split surfaces kept their constructor's floating GObject reference rather than sinking and releasing it as Ghostty does. The single-node, split, resize, equalize, and remove trees also remained owning after `set_tree` cloned them, leaking one native surface reference per leaf in each temporary result. | Sink the new surface reference and defer its release, and free every owning temporary tree after the widget has cloned it, matching each source `defer surface.unref()` and `defer tree.deinit()`. |
| GTK split focus lifetime | `SplitTreeWidget.last_focused` was a raw V pointer described as weak, rather than Ghostty's `WeakRef(Surface)`. A finalized surface could therefore leave a stale pointer for active-surface fallback or post-rebuild focus, and split-tree/split-divider disposal silently ignored failed GLib source removals. | Store the translated `GWeakRef`, take and release the same temporary strong reference around every lookup/focus operation, set it through the native surface object, and restore both source-removal warnings. |
| GTK split-tree lifecycle invariants | A close request from a surface without an initialized core was treated as an unconditional close and cleared pending-close state, whereas Ghostty rejects it before mutating state. Rebuild scheduling omitted the single-source assertion, failed source removals were ignored, orphan-state violations silently skipped rebuilding, and impossible split/leaf node kinds were converted into false/none/null results. | Restore Ghostty's core-first close-request ordering, rebuild source diagnostics and assertions, and fail-fast leaf/split invariants throughout active-surface lookup, navigation, close focus selection, and recursive widget construction. |
| GTK split zoom preservation | Split navigation always cleared an existing zoom and retained an obsolete comment claiming `split-preserve-zoom` was untranslated. With `split-preserve-zoom = navigation`, Ghostty instead moves the zoom to the newly focused split. | Read the translated configuration flag during navigation, clearing zoom by default and retargeting it to the destination when navigation preservation is enabled, while retaining the same tree/zoom notifications. |
| GTK selected-tab invariants | Witty omitted Ghostty's `getSelectedTab` helper and treated a selected page containing a non-`GhosttyTab` child, plus a negative tab-view page count, as recoverable state. That hid violations of the window's native child/page contract. | Restore the selected-tab helper, assert the registered child type before active-surface/title synchronization, and restore the nonnegative page-count assertion used by quit-confirmation traversal. |
| GTK tab position invariants | Window tab selection and movement replaced Ghostty's impossible-position assertions with silent `false` returns, masking invalid internal state, and widened the native-width move amount to an intermediate `i64`. | Restore both post-computation assertions and carry the canonical `isize` move amount unchanged from the action payload through the window operation. |
| GTK surface window routing | Horizontal touchpad tab navigation called the cached window wrapper directly instead of activating Ghostty's `tab.next-page`/`tab.previous-page` GTK actions. Child-environment setup likewise followed the cached split-tree/window backpointer instead of resolving the registered native window ancestor. | Route horizontal navigation through the surface widget's GTK action propagation and recover the owning window through the native `GhosttyWindow` ancestor before adding protocol/quick-terminal environment values. |
| GTK window navigation | With no currently active toplevel, Ghostty tries the first GTK window before wrapping in either direction, but Witty's index translation started `goto_window(previous)` at the last window. | Restore the source list-head first candidate for both directions while preserving traversal from the active index when one exists, with direct tests for both initial states. |
| GTK split navigation | The application action dispatcher mapped `goto_split` previous/next to the split tree's non-wrapping operations, while Ghostty explicitly uses `previous_wrapped`/`next_wrapped`; navigating past the first or last split therefore failed instead of cycling. | Restore the wrapped linear traversal mapping, retain the four spatial mappings, and cover all six action directions directly in the Linux GTK module. |
| renderer background opacity | Renderer initialization and every terminal-state refresh truncated the configured floating-point background opacity to an eight-bit shader alpha, whereas Ghostty rounds the scaled value; for example, `0.5` became 127 rather than 128. | Centralize the source rounding conversion and use it in the Metal, OpenGL, and per-frame uniform paths, with direct boundary and midpoint coverage. |
| terminal/modes | `ModePacked` was `u32` with `& 31` masking, but 40 modes exist → modes ≥32 (cursor_keys, mouse_alternate_scroll, alt_esc_prefix…) aliased onto modes 0-7. Also 4 wrong table defaults and a hardcoded `data:5` default. | `data` → `u64`, mask `& 63`; corrected `send_receive_mode`/`mouse_alternate_scroll`/`ignore_keypad_with_numlock`/`alt_esc_prefix` defaults; default now derived from the table via `build_default_modes()`. |
| terminal (screen/types/style) | SGR 58 underline color written into the **foreground** fields (no dedicated storage); `underline_color_rgb` read from fg. | Added `underline_r/g/b/palette` to `CellStyle`; `set_attribute` and `underline_color_rgb` use them; `eql`/`hash` include them. |
| terminal/terminal | `index()` didn't mark the new row `prompt_continuation` on a plain linefeed in prompt/**input** mode (logic was only in `print_wrap`, only for `.prompt`). | Added the `defer` marking for `semantic_content != .output` (prompt AND input). |
| terminal renderer flags | Ghostty's 19-bit terminal flag pack, nested four-bit dirty value, and two-bit screen dirty value were expanded into ordinary V enums/booleans. The renderer also omitted Ghostty's assignment that marks `search_viewport_dirty` whenever its terminal snapshot is dirty, so the search thread could skip a required viewport refresh. | Store the terminal pack in one `u32` and both dirty values in one byte each with the exact source bit order/defaults, route every live consumer through typed accessors, and restore the renderer-to-search dirty notification. |
| terminal search tags | Screen state/selection, sliding-window direction, thread message/event, and aggregate tick tags all used V's default 32-bit enum storage instead of Ghostty's source-inferred tags. | Restore byte backing for all six retained tags and verify every declaration-order ordinal. |
| terminal search reload failures | `ScreenSearch.reloadActive` was made infallible and Ghostty's two typed history-append checkpoints plus their partial-result cleanup were explicitly folded away. Initialization, feed, selection, and the search-thread boundary consequently erased that error channel as well. | Restore the byte-backed `history_append_new`/`history_append_existing` tripwire module, clean every cloned partial result and temporary search window on failure, propagate the fallible contract through `ScreenSearch.init`, `feed`, `searchAll`, and `select`, and catch/log it at the same search-worker reconciliation boundaries as Ghostty. |
| terminal PageList initialization failures | `PageList.init` and `Screen.init` were made infallible, and both PageList tripwire modules were absent: four top-level pool/page/pin checkpoints and three per-page node/buffer checkpoints. Partial multi-page initialization therefore had no translated cleanup/error boundary. | Restore both byte-backed typed tripwire modules and all seven source checkpoints, split initial page construction back into its own fallible helper, tear down every already-initialized page on failure, and propagate the result contract through `Screen`, `ScreenSet`, and `Terminal`. The memory-pool and standard/non-standard buffer points model Ghostty's allocator failures over V's GC-backed page storage. |
| terminal formatter flags | Both formatter `Extra` values are packed in Ghostty, and the terminal value nests the six screen bits after its own six bits; Witty expanded them into twelve separately stored booleans. | Store `ScreenExtra` in one byte and `TerminalExtra` in one `u16`, preserve the source bit ordering and `none`/`styles`/`all` constants, and expose typed field mutation without widening the retained values. |
| terminal style flags | Every `Style` retained Ghostty's packed `u16` as eight booleans plus an underline enum in a different declaration order, then rebuilt the canonical bits by hand only for hashing. | Store bold/italic/faint/blink/inverse/invisible/strikethrough/overline and the three-bit underline value directly in their source positions, mutate them through typed setters, and hash the retained word without reconstruction. |
| terminal protocol tags | `device_status.Tag` was expanded from its packed `u16` into a separate integer and boolean, while `modes.ModeTag` was omitted entirely even though the generated enum values happened to encode its high ANSI bit. The formatter used parallel entry fields instead of decoding the canonical tag. | Restore byte-for-byte `u16` tag values for device-status requests and modes, retain the low 15-bit value/high flag layout, and make formatter serialization consume the translated mode tag. |
| terminal/stream, terminal/terminal | Ghostty's repeat, character-edit, line-edit, and scroll actions carry `usize`, but Witty collapsed them into the shared `u16` event field and then narrowed them to V's 32-bit `int` at both handlers. | Add a dedicated `usize` action count, route all eight actions through it, and restore those eight `usize` terminal method contracts; bounded screen operations clamp before conversion to array indexes. |
| input/key | `w3c()` blindly did `- 32` on the char after `_`, corrupting digits (`digit_1` → "Digit\x11"). | Uppercase only `a-z`. |
| input public key ABI and primary modifier | Key action, the complete 176-case physical key enum, and Option-as-Alt relied on V's implicit enum layout instead of their explicit Ghostty `enum(c_int)` contracts. `Key.ctrl_or_super()` also always recognized Meta, while Ghostty recognizes Ctrl on every non-Darwin target, affecting live mouse-shape transitions. | Give all three public enums explicit signed 32-bit backing, verify their complete declaration-order ordinals, and restore the target-selected Ctrl/Meta predicate. |
| input/Link | Flattening the tagged `Highlight` union left `mods` storage on `.always`/`.hover`; the initial correction merely ignored and canonicalized that source-nonexistent payload while duplicating it through surface and renderer link records. | Represent all four highlight arms directly, keep `Mods` only on `.always_mods`/`.hover_mods`, carry the union unchanged through derived state and renderer links, and match its active payload for equality and highlighting. |
| input binding flags ABI | The canonical binding flag value was an ordinary four-boolean V struct; only `cval()` reconstructed Ghostty's exported packed byte, leaving every retained binding with a source-incompatible representation. `input.v` also carried an unused, source-external one-flag binding/C pair. | Store consumed, all-surfaces, global, and performable directly in their source bit positions in one byte, use that canonical value throughout parsing, lookup, dispatch, and the C projection, and remove the orphan duplicate types. |
| Kitty keyboard flags | The live terminal stack stored eight widened integers, the key encoder and `kitty/key.v` each declared separate ordinary-boolean flag structs, and the core surface manually projected between those three representations. The encoder's packed CSI-u and Kitty modifier values were expanded into ordinary boolean structs too. | Establish one byte-backed canonical five-bit flag value and stack (in the cycle-free terminal module), alias it at the Kitty and input boundaries, pass it unchanged through core, and retain the source bit layouts in byte-backed encoder modifier values. |
| input/command | The 88 translated command-palette entries were already present, but defaults traversed a manually duplicated 83-tag list and `action_commands` used a catch-all, losing Ghostty's compile-time requirement to classify every new action. `Command.clone` also shared all owned strings because the translated `Action.clone` was absent. | Enumerate `ActionTag` through V type reflection, make the command switch exhaustive, assert every generated command's tag, and restore deep cloning for string and cursor-key action payloads plus command text. |
| input scoped actions | `Action.scope()` was translated, but `Action.scoped()` was omitted and production dispatch repeated an untyped scope comparison. | Restore the checked conversion and use it at the surface dispatch boundary. Zig's comptime-generated reduced union is represented as an optional canonical `Action` because V cannot express a return type dependent on a runtime enum argument; all active payload data is preserved. |
| GTK GValue lifetime | The typed settings getters and split-tree property readers allocated every temporary `GValue` with `vcalloc`; `g_value_unset` releases only the value's active payload, so the translated wrapper leaked on every read. | Retain the zeroed, eight-byte-aligned 24-byte `GValue` on the caller's stack, matching Ghostty's value lifetime, and continue to call `g_value_unset` for the active payload. |
| GTK settings source-external API | The translated `gsettings.zig` appended an unused five-function GNOME `GSettings` API and opaque type that do not exist anywhere in the pinned file; its own comment identified them as additions from an earlier translation brief. | Remove the invented schema API and retain only Ghostty's three typed `GtkSettings` property readers and their stack-owned `GValue` implementation. The complete Linux target still passes the checker. |
| Windows process attribute value | `os/windows.zig`'s Ghostty-owned `ProcThreadAttributeValue` implementation and its pseudoconsole constant were absent along with the standard-library Win32 re-export facade. | Restore the exact WinBase.h number/flag packing, explicit `DWORD`-width attribute enum, unknown-number masking, and `PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE` value. V's Windows runtime remains the provider for the surrounding standard Win32 declarations. |
| input/function_keys | `make_kp_keys` returned only the unmodified keypad entry, dropping the 15 modifier combinations. The translated PC-style and manual modified-key entries also forced `mods_empty_is_any=false`, while Ghostty inherits the entry's `true` default everywhere except the unmodified keypad fallback. | Generate all 16 (`kpDefault ++ pcStyle`), retain `mods_empty_is_any=false` only on `kpDefault`, and preserve the source default on generated and manual nonempty-modifier entries. |
| zf filename ranking and index widths | The handwritten basename helper returned a separator for root-only paths; on Windows it also recognized only backslashes and treated `C:` as a filename. Pinned zf delegates to Zig's native `std.fs.path.basename`, so filename-priority ranking diverged for those paths. The public segment and highlight APIs plus their scan state also narrowed source `usize` indices to 32-bit `int`. | Translate the pinned POSIX/Windows basename algorithm, including empty roots, trailing separators, both Windows separator forms, and drive-designator boundaries; retain `usize` throughout segment lookup, scan results, and highlight buffers; and add direct platform-specific coverage. |
| CLI theme discovery, preview events, and invariants | Theme discovery diagnosed ordinary missing search directories, omitted error details for other open failures, and excluded broken or non-file-target symbolic links even though Ghostty accepts every `.sym_link` entry. The preview applied every mouse event immediately and discarded hover state, while Ghostty retains only the latest event and consumes it during `draw`, where it highlights the hovered row. Theme indexes/counts were narrowed from `usize` to `int`, and guards silently accepted End, clipboard, and save-modal operations for which the source traps through checked subtraction/indexing. | Silently skip only absent directories, retain other open diagnostics and symbolic-link entries, queue and consume the latest mouse event at the draw boundary with hit-testing/hover styling, carry selection state and movement counts as `usize`, and restore the source invariant failures for selection-dependent operations. |
| input paste/key options | Both source `Options.fromTerminal` constructors were omitted and their state projection was duplicated in `Surface`. Paste encoding was also moved into the generic input file and silently allocated/replaced newlines for immutable data, erasing Ghostty's `MutableRequired` contract and its explicit duplicate-then-mutate retry path. | Restore both terminal-derived constructors and route `Surface` through them; return `MutableRequired` for immutable unbracketed newlines, provide the mutable in-place specialization, restore the retry path and fallible `lib_vt` API, and keep paste logic in its source-corresponding file. A three-field internal result works around the pinned V compiler's invalid C for fixed arrays inside error unions; the public boundary still returns three elements. |
| omitted source helper entry points | The font alias wrapper lacked `getConstEntry`, tripwire lacked `checkConstrained`, and terminal C SGR omitted the WebAssembly attribute allocation/free pair. The primary mutable/runtime equivalents existed, which hid the incomplete public surfaces from production call paths. | Restore the read-only alias resolver (V pointers do not encode constness), the constrained tripwire check (V errors do not encode error sets), and matching SGR aggregate allocation helpers, with direct coverage for every entry point. |
| font feature streaming parser | `Feature.fromReader` was omitted and `FeatureList` split the input eagerly, so callers could not retain parser position or continue from the next comma boundary after an invalid field. | Add the V string-reader counterpart, preserve boundary consumption and invalid-field recovery, and route list parsing through the restored entry point. |
| sprite Canvas public surface | Canvas rectangle drawing was exposed only as the translated name `draw_box`, while the source's public `box`, padding `transformation`, and lifecycle entry points were absent. The actual padding transform was open-coded in path construction. | Restore `box`, `transformation`, and `deinit`, route all 56 translated sprite call sites through the source-shaped rectangle entry point, and make path construction consume the public transformation. |
| renderer overlay color helpers | The overlay's `Color.rectFill`, `rectBorder`, and `pixel` entry points were replaced by alpha-only helpers, leaving premultiplication open-coded inside compositing and removing the public source API. | Restore a premultiplied RGBA pixel value and all three color helpers, then make both rectangle paths consume those canonical source-derived pixels. |
| renderer cell failure isolation | Font-shaping cache insertion, underline/overline/strikethrough construction, row rebuilding, and whole GPU-cell rebuilding errors were silently discarded. More importantly, a single glyph construction failure propagated out of row rebuilding, whereas Ghostty logs every one of these errors and continues rendering subsequent cells. | Restore warnings at the cache, cell, row, and GPU rebuild boundaries; catch glyph construction per cell; and retain the newly shaped data plus the rest of the row when an individual cache or cell operation fails. |
| renderer diagnostics | Display-link changes, regex-link search, overlay rebuild and feature drawing, background-image rejection, and shader reload either silently discarded failures or bypassed Ghostty's logger; the successful display-ID transition log was absent. | Route all of these boundaries through the translated logger at the source info/warn levels and restore the display-link transition event. |
| platform renderer diagnostics | OpenGL and Metal shader loading, postprocess initialization, target presentation, display callbacks, and display-link notification bypassed the scoped logger; the OpenGL wrapper also omitted successful shader/program create, link, and destroy events. | Restore the source logger levels and OpenGL resource lifecycle events across both platform renderer specializations and their backend value types. |
| renderer worker diagnostics | The renderer worker and its callbacks wrote failures directly to stderr and omitted Ghostty's thread start/shutdown/exit, successful QoS change, and per-message debug events. | Restore the complete worker lifecycle and mailbox debug boundaries and route draw, render, wakeup, drain, timer, cancellation, and QoS failures through the logger at their source levels. |
| Core Foundation release-worker diagnostics | The Darwin CF release worker wrote loop, wakeup, and mailbox failures directly to stderr and omitted Ghostty's normal and abnormal thread lifecycle events. | Restore the source warning/error levels and the start, shutdown, exit, and abnormal-drain completion debug boundaries. |
| search worker diagnostics | Search thread, callback, screen initialization/reload/feed, and QoS failures bypassed Ghostty's logger. Thread lifecycle, mailbox, needle-change, and result-notification debug events were absent, and feed failures omitted the affected screen key. | Restore source-level warnings and debug boundaries, including shutdown-drained messages, screen identities, result counts, selection changes, and completion. |
| search selection reload recovery | Two active-search reload branches directly selected from the existing result arrays after clearing a stale selection, skipping Ghostty's full reload/prune/select path; all three translated recovery failures also bypassed the search-screen logger. | Route stale history and unmatched-active recovery through `ScreenSearch.do_select` and restore the source info diagnostic at every fallible translated recovery boundary. |
| core app continuation diagnostics | Global chains, focused app keybindings, and all-surface action dispatch correctly continued after individual failures but silently discarded each error; conditional-state reapplication wrote directly to stderr. | Preserve the source continue-on-error behavior while logging the failed action tag and, for surface dispatch, the target pointer; route the configuration warning through the same logger. |
| configuration finalization diagnostics | Replay path-expansion and Windows shell fallback warnings bypassed the logger, while shell selection from the environment/passwd database, passwd home selection, and the Unix no-shell fallback warning were omitted. | Restore the source warning/info events at each configuration decision point, including the selected values and replay failure. |
| exec subprocess startup and diagnostics | The exec backend attempted the Flatpak host-command path whenever `/.flatpak-info` existed even when Flatpak support was not built, skipped Ghostty's fallback to a local child, wrapped oversized initial PTY dimensions instead of clamping them, and leaked the newly opened PTY on several failures before process startup. Process, termios, write, shutdown, cwd, shell-integration, and read-thread diagnostics were also omitted or printed directly to stderr. | Gate host execution and its PATH/cwd handling on the translated build option, retain local execution with the source warning when support is absent, restore failure cleanup and initial-size clamping, use the source access check for a proposed cwd, and restore the corresponding source-level lifecycle and error logging. |
| terminal ScreenSet lazy initializer | `ScreenSet.getInit` was behaviorally implemented as the source-external name `get_or_init`, so the translated public surface was incomplete despite the terminal's working alternate-screen path. | Restore `get_init` and route the terminal plus direct tests through the source-shaped entry point. |
| configuration edit path | `config.edit.openPath` was consolidated into `configpkg` as the source-external `editable_config_path`; callers worked, but the public source entry point was absent. | Restore `open_path` and route both the C API and GTK open-config action through it. |
| renderer shadertoy loader surface | The translated shader loaders and target tag carried source-external names (`load_shaders_from_files`, `load_shader_from_file`, and `ShaderTarget`) even though their public Ghostty counterparts are `loadFromFiles`, `loadFromFile`, and `Target`. | Restore the source-shaped V names and route every renderer and test call site through them. |
| input key and CoreText descriptor entry points | `Key.fromW3C` was flattened into a package function, the source `printable`/`modifier`/`keypad` methods were renamed with `is_` prefixes, and `Descriptor.toCoreTextDescriptor` collapsed the `CoreText` word boundary. Their implementations existed, but the translated public surface did not. | Restore `Key.from_w3c`, `Key.printable`, `Key.modifier`, `Key.keypad`, and `Descriptor.to_core_text_descriptor`; route production callers and direct tests through those source-shaped entry points. |
| scalar Base64 sizing surface | The scalar fallback collapsed `calcSizeUpperBound` and `calcSizeForSlice` into one private helper, so both source entry points were absent even though the main decoder used equivalent arithmetic. | Restore source-shaped `calc_size_upper_bound` and `calc_size_for_slice` functions, route the decoder through the slice form, and cover every valid remainder plus invalid one-byte input. The scalar `decode` body retains a prefix because the merged V module also contains the public high-level `decode`. |
| SSH cache default path | `DiskCache.defaultPath` used V's infallible `os.state_dir()`, which creates the state directory as a lookup side effect and can panic, instead of Ghostty's fallible XDG resolution. | Resolve the path through the translated `xdg_state` helper, propagate lookup failures, and leave directory creation to cache-mutating operations. |
| diagnostic iterator location entry point | `Location.fromIter` behavior existed only as a config-private generic helper, leaving the source's reusable public dispatch API absent. | Restore `Location.from_iter` on the translated location type and route config diagnostic creation through it. |
| termio mailbox union and constructor | Ghostty retains the SPSC queue and wakeup inside the explicit `Mailbox.spsc` union arm (the alternative unbounded arm is commented out). Witty flattened that payload directly into `Mailbox`, and its `initSPSC` constructor had earlier been renamed to generic `init`. | Restore the explicit `MailboxSpsc` payload and `spsc` wrapper, route lifecycle, send/notify, thread wakeup/draining, and tests through the active arm, and retain the restored source-shaped `Mailbox.init_spsc` constructor. |
| termio output render invariant | The PTY output path silently discarded a renderer-wakeup failure even though Ghostty marks that state unreachable after successful thread initialization. | Restore the invariant boundary so a broken renderer async handle fails immediately instead of continuing with terminal state that may never be displayed. |
| CLI action iterator detector | `cli.action.detectArgs`/`detectIter` and its `SpecialCase` union were collapsed into a handwritten slice loop, removing the reusable iterator contract and the source `Action.detectSpecialCase` entry point. | Restore `detect_args`/iterator-generic `detect_iter`, the special-case value, and the action hook; make global-state detection a thin explicit-slice adapter. V cannot reproduce the source's comptime enum type factory, so the value is specialized to Ghostty's sole action enum. |
| focused surface accessor | `App.focusedSurface` was renamed `focused_surface_valid` to avoid colliding with the snake-cased backing field, dropping the source public entry point. | Rename the private backing field and restore `App.focused_surface`, routing the embedded working-directory bridge and direct tests through it. |
| terminal style public helpers | `Style.bg`/`fg` were exposed as `bg_rgb`/`fg_rgb`, and `formatterVt`/`formatterHtml` were collapsed into direct string helpers, dropping the source formatter-value entry points. | Restore the source-shaped color resolvers and formatter constructors, represent each formatter as a palette-configurable V value, and route renderer and terminal formatting through them. |
| remaining scalar helper entry points | `device_status.reqFromInt` was moved onto the request type, paste `isSafe` carried a source-external module prefix, and `Style.underlineColor` remained exposed as `underline_color_rgb`; all three behaviors existed but their source public functions did not. | Restore the free device-status and paste helpers, rename the flattened underline tag so the source-shaped resolver can exist, and route the parsers, renderer, C layer, lib-vt layer, and paste confirmation through them. |
| remaining OS and termio entry points | Shell integration `setup`, its `ShellIntegration` result, startup `prepareInput`, i18n `initGlobalDomain`, and the OS argument `iterator` all had working bodies under translation-only expanded names. | Restore their source-shaped V spellings and route the subprocess setup, GTK startup, direct callers, and focused tests through those canonical entry points. Startup input remains stored directly on `Termio` because V does not retain Ghostty's private arena-owned `ThreadEnterState` wrapper. |
| POSIX PTY child setup | The signal-reset shim returned an error on the first failed `sigaction`, and `child_pre_exec` propagated that source-external failure before `setsid`; the pinned implementation intentionally ignores every reset result. PTY creation also silently swallowed both `fcntl` failures. | Make signal restoration best-effort exactly as in Ghostty, retain the real session/controlling-terminal errors, and restore warnings for both master-fd `CLOEXEC` operations. |
| CLI slice iterator and GTK action constructors | The CLI slice adapter was exposed only as the source-external `SliceIterator.new`, while GTK action descriptors replaced `Action.init`/`initStateful` with `.new` constructors. | Restore `slice_iterator`, `Action.init`, and `Action.init_stateful`; route global-state detection, configuration tests, and every GTK descriptor table through the source-shaped entry points. |
| benchmark dispatcher and GTK no-op protocol entry points | The benchmark `mainAction` dispatcher remained folded into the C string entry point, and `noop.Window.updateConfigEvent` was absent. | Restore `main_action` with process/string argument variants and route the C adapter through it; restore the no-op GTK method with an opaque unused argument because the pinned declaration's `ApprtWindow.DerivedConfig` type does not exist and the pinned protocol union never dispatches it. |
| synthetic generator CLI | The generator primitives existed, but all four `src/synthetic/cli*` files were absent: no action dispatcher, options, implementation lifecycle, stdout loop, ASCII command, UTF-8 command, or OSC streaming/parser framing. | Translate the dispatcher and all three implementations, including general-string/process argument modes, per-action option parsing, seeded PRNG, fixed 1024-byte generation loops, closed-output handling, and native-width little-endian parser records. The allocator parameters are omitted under V's GC and nested source types use `*Cli`/`*Options` names in the flat module. |
| renderer and inspector public entry points | Renderer display-ID handling retained the source's internal warning behavior but dropped its fallible signature and the renderer-thread `try`; inspector renderer-panel access and batch PTY recording existed only through private fields/per-byte bridges. | Restore the renderer `set_macos_display_id` error contract and thread propagation, plus `Inspector.renderer_info` and `Inspector.record_pty_read`. The latter routes each byte through the existing pre-terminal parallel parser and omits only the allocator parameter under V ownership. |
| GTK surface public callbacks | `Surface.childExited`, `actionPromptTitle`, and `actionNotifyOnNextCommandFinish` were behaviorally translated but exposed only under adapter-specific private names. | Restore the source-shaped public names and route the application dispatcher, surface dispatcher, and GLib action table through them. The action callbacks retain V's required opaque GLib user-data parameter in place of Zig's typed third parameter. |
| inspector widget entry points | Faithful terminal, screen, renderer, cell-chooser, VT-stream, and shared-style widget implementations were retained as private translation helpers, and the source screen table names were expanded to `draw_screen_*`. | Restore the public widget types, lifecycle/draw methods, VT batch-read method, five source-shaped screen table entry points, and shared `table`/`color` functions; route the live inspector and event details through them. Explicit `cimgui.Context` parameters remain a V binding adaptation. |
| keybind help generator surface | The complete `input/helpgen_actions.zig` algorithm was exposed under source-external `HelpFormat` and `generate_help` names. | Restore public `Format` and `generate`, and route the CLI and direct tests through them. V returns the accumulated string instead of accepting Zig's allocator-backed writer. |
| CLI action source mapping | The translated action enum retained its display-name mapping but omitted Ghostty's public compile-time `Action.file` helper. | Restore the runtime-equivalent `file` method and verify every action maps to its pinned `cli/<action>.zig` source path. |
| inspector detachable-header API | `DetachableHeader.window`, `header`, and `windowEnd` were absent even though their cimgui behavior was open-coded throughout the terminal inspector. | Restore all three public methods (with the explicit V cimgui context) and route every attached and detached terminal panel through them. |
| GTK application and scrollable entry points | Public `Application.actionOpenConfig` was folded into its private C callback, while the four `Surface` adjustment methods collapsed the `HAdjustment`/`VAdjustment` word boundaries. | Restore `action_open_config`, `get_h_adjustment`, `set_h_adjustment`, `get_v_adjustment`, and `set_v_adjustment`; route the callback and GObject property setters through the source-shaped methods. |
| OS iterator and macOS version entry points | `ArgIterator.initWithAllocator` was folded into the module `iterator`, and `macos.isAtLeastVersion` was exposed only under the source-external `is_at_least_macos_version` name. | Restore `ArgIterator.init_with_allocator` (without an allocator under V ownership) and `is_at_least_version`; route the canonical iterator and direct tests through them, and remove the old macOS alias once no callers remain. |
| list-themes preview public surface | The translated interactive theme preview kept its initializer, event loop, update, drawing, preview-pane, and ten UI-style methods private, renamed `init` to `new`, and had no separate lifecycle method. | Restore public `Preview.init`, `deinit`, `run`, `update`, `draw`, `draw_preview`, and every `ui_*` method; route the TUI launcher and tests through the canonical lifecycle. Allocator and TTY scratch-buffer parameters remain omitted under V ownership. |
| CLI parser iterator and splitter surface | `CommaSplitter.init`, `LineIterator.init`, `ArgsIterator.deinit`, and process-level `argsIterator` were renamed or absent. `Config.load` consequently read V's libc-backed `os.args` on macOS instead of Ghostty's `NSProcessInfo.arguments`, whose snapshot remains valid after `NSApplicationMain`. | Restore all four source-shaped entry points and route composite parsing, configuration parsing, and process configuration loading through them. A CLI-local Darwin bridge reads and owns the Cocoa argument snapshot without creating the module cycle that importing the consolidated `internal_os` module would cause; allocator parameters are omitted under V ownership. |
| CLI action option lifecycle and manual parsing | Flattening the action modules made most public `Options` types private and dropped their `deinit`/`help` methods. The generic parser also reversed `parseManuallyHook`'s boolean contract, so `new-window -e` consumed later arguments through translation-only state instead of consuming the supplied iterator and ending option parsing. | Expose every action-prefixed option type and restore all source lifecycle/help methods (GC-backed `deinit` methods are no-ops), route help through those methods, and restore the source hook contract. `NewWindowOptions.parse_manually_hook` now consumes the remaining slice iterator in one call and returns false to stop, preserving `--help` as command input after `-e`. The type prefixes are required because V merges the separate Zig action files into one module. |
| resource-directory and hostname entry points | `ResourcesDir.deinit` was absent and global teardown discarded the value directly, while `hostname.isValid`/`isLocal` were exposed only under flattened `hostname_is_*` names. | Restore the GC-backed resource lifecycle and route global teardown through it; restore `is_valid`/`is_local` and route SSH-cache validation plus OSC 7 locality checks through the source-shaped names, then remove the unreferenced flattened aliases. |
| font metrics and terminal iterator entry points | Eight `FaceMetrics` getters carried source-external `_val` suffixes because their translated names also name fields, while `PromptIterator.nextRightDown`/`nextLeftUp` were private. V permits field/method name overlap and disambiguates calls with parentheses. | Restore all eight source-shaped metrics getters, route metrics calculation and fallback scaling through them, and expose both directional prompt-iterator methods. |
| surface text and termio locked entry points | `Surface.dumpText`/`dumpTextLocked` were private, the unlocked wrapper no longer acquired the renderer-state mutex, returned `Text` values lacked their lifecycle method, and `Termio.colorSchemeReportLocked` was private. | Restore all four public entry points and the source lock boundary; the GC-backed `Text.deinit` clears its owned values instead of accepting an allocator. |
| terminal page canonical API | `Capacity.adjust` had lost its `Adjustment` request type; `Cell.codepoint`, both `pauseIntegrityChecks` methods, and `Cell.hasGrapheme` carried translation-only suffixes or were absent; `Page.reinit` incorrectly accepted a replacement capacity; cell-based `lookupHyperlink` was renamed; and PageList's source `IncreaseCapacity` enum had a translation-only name. `CellData` also stored a redundant grapheme boolean beside the canonical content tag, creating invalid states absent from Ghostty. | Restore every source-shaped method and value type, route all page, terminal, renderer, font, inspector, and reflow callers through them, keep the coordinate hyperlink lookup private as a representation adapter, and derive grapheme presence solely from `content_tag == codepoint_grapheme`. |
| terminal cursor parameter widths | Cursor up/down/left/right, absolute positioning, and both margin setters narrowed Ghostty's `usize` requests to V `int`. The movement methods then converted to `u16` before applying the terminal bounds, so a count such as 65,536 wrapped to zero instead of moving to the edge. | Restore all seven pointer-width contracts through the mutable and read-only stream handlers and Kitty cursor movement, clamp movement before narrowing, and clamp full-width absolute positions before converting to cell coordinates. |
| terminal screen-switch result | `Terminal.switchScreen` represented Ghostty's `!?*Screen` contract as a non-optional V reference and returned an unsafe nil reference when the requested screen was already active. Mode switching then compared and dereferenced that invalid reference manually. | Carry the optional previous screen in an explicit fallible-result value (V cannot directly nest result and option), return true absence for a no-op switch, and consume it with option binding in all three legacy screen modes. |
| terminal render-state string API | `RenderState.string` was split into source-external `to_string` and `to_mapped_string` return-value helpers, so callers could not write into an existing destination and the source's optional byte-to-coordinate map contract was absent. The replacement map also used the render cursor's narrower viewport-point value instead of the source coordinate type. | Restore one writer-based `string` operation, represent its optional map argument explicitly, populate one canonical coordinate per emitted UTF-8 byte and newline, and route renderer link matching plus direct tests through it. V's concrete `strings.Builder` replaces Zig's generic fallible writer, and the nested source map type is module-level because V has no nested declarations. |
| terminal cursor lifecycle | `Screen.Cursor.deinit` was omitted and both screen teardown and reset discarded the cursor value directly, bypassing the source lifecycle boundary for its owned pending hyperlink. | Restore `Cursor.deinit`, clear the GC-owned hyperlink value and active ID there, and route both `Screen.deinit` and `Screen.reset` through it before discarding cursor state. |
| terminal color-name surface | Ghostty's public `color.Name` enum was renamed to the translation-only `ColorName`, and `Name.default` was flattened into an optional free function, erasing its invalid-value error contract. | Restore the exact flattened-module `Name` type and fallible `Name.default` method, then route default-palette generation and direct tests through them. |
| terminal size integer types | All six public integer types from `terminal/size.zig` were replaced by translation-only `*_max` constants, so downstream declarations could not express Ghostty's size contracts even though the handwritten fields happened to use the same primitive widths. | Restore `OffsetInt`, `CellCountInt`, `StyleCountInt`, `HyperlinkCountInt`, `GraphemeBytesInt`, and `StringBytesInt` as public V primitive aliases; use `OffsetInt` in the translated offset value and test every retained width. |
| terminal parser result contract | The source `Parser` was renamed `VTParser`, its private `clear`/`collect` helpers were exposed, and `next` allocated a compacted dynamic action list instead of retaining Ghostty's three optional exit/transition/entry positions. | Restore the `Parser` name and helper visibility, return a fixed three-field optional result without per-byte list allocation, and dispatch each position in source order. The pinned V compiler emits invalid C for a returned `[3]?ParserAction`, so named fields preserve the same three positions; direct tests cover exit-only and exit-plus-transition results. |
| terminal highlight type surface | The complete highlight algorithms already lived in their own cycle-free `highlight` module, but all three source types were exposed only as translation-specific `UntrackedHighlight`, `TrackedHighlight`, and `FlattenedHighlight` names. | Restore the module-scoped `Untracked`, `Tracked`, and `Flattened` names and route the search thread, all four search implementations, renderer messages/state, and direct tests through them. The source's nested `Flattened.Chunk` remains module-level `Chunk` because V has no nested declarations. |
| terminal search namespace exports | All five search implementations existed under their concrete implementation names, but the public aliases from `terminal/search.zig` (`Active`, `PageList`, `Screen`, `Viewport`, and target-selected `Thread`) were absent from the V search module. | Restore the five namespace aliases; `Thread` selects Witty's translated native search worker because the repository does not build Ghostty's libxev web/native variants. |
| terminal point union and coordinate accessor | Ghostty's four-arm `Point` union was flattened into a mutable tag plus an always-live coordinate, and its `coord` entry point had previously been retained only as a representation field. | Represent active, viewport, screen, and history points as direct union arms, keep the coordinate only in the selected arm, and route pin conversion, page iteration, screen logic, renderer images, embedded input, inspector views, and tests through the canonical coordinate accessor. V's sum representation is 24 bytes rather than Zig's 12-byte tagged union, but it now enforces the same discriminated-payload invariant. |
| terminal tmux namespace export | The control parser and notification union were implemented, but the public `ControlNotification` alias from `terminal/tmux.zig` was absent; callers could only use the control module's shorter implementation name. | Restore `tmux.ControlNotification` as an alias of the canonical notification sum type. `Viewer` remains `terminal.TmuxViewer` because moving the terminal-owning viewer into the `tmux` V module would create a `terminal`/`tmux` import cycle. |
| terminal root type exports | Eight representable aliases from `terminal/main.zig` were absent, forcing `lib_vt` and external callers to use translation-specific implementation names such as `CellData`, `CSIAction`, `StreamEvent`, and `SgrAttribute`. | Restore `Cell`, `CharsetActiveSlot`, `CSI`, `DCS`, `Style`, `StreamAction`, `CursorStyleReq`, and `Attribute`, and route `lib_vt` through the canonical root names. The implementation names remain public because V module visibility is file-flat. The root build `Options` alias cannot coexist with the already-flattened `Terminal.Options` type under V's single module namespace. |
| file-type detector entry points | `FileType.detect` and `FileType.guessFromExtension` were translated as module-level free functions, leaving the source's type-scoped API absent even though the matching logic and tables were complete. | Restore both type methods using V spelling and route renderer custom-shader image detection plus all direct tests through them; remove the source-external free-function surface. |
| termio stream-handler error boundary | `StreamHandler.vt` and its fallible public handlers were translated as `void`, while terminal, screen-switch, hyperlink, DCS/tmux, and Kitty failures were discarded with `or {}`. The two output-dispatch loops consequently had no equivalent of Ghostty's outer catch-and-log boundary. | Restore the fallible `vt`, DCS/APC, mode, cursor, index, hyperlink, device-report, reset, and query contracts; propagate representable failures through them; and catch/log once in each process-output path. V's GC-backed string formatting and message construction remain infallible language-level adaptations, so their Zig allocation errors have no V result to propagate. |
| CLI comma-splitter implementation | The faithful `cli/CommaSplitter.zig` translation coexisted with a second handwritten splitter inside `cli_args`; production struct and command parsing used the duplicate, whose API and Unicode-escape arithmetic differed from the pinned source. | Remove the duplicate implementation and its duplicate tests, import the source-corresponding `comma_splitter` module, and route both auto-struct parsing and repeatable command parsing through its single state machine and error state. |
| font fallback size adjustment | The translated root `default_fallback_adjustment` was `.none_` instead of Ghostty's `.ic_width`, so discovered fallback faces and the four embedded JetBrains Mono backup styles skipped the source's ideograph-width matching. | Restore `.ic_width` at the shared font constant while preserving the source's explicit `.none_` exceptions for configured primary faces, symbol fonts, and emoji faces; assert the root default directly. |
| font root style export | Ghostty's root `font.Style` enum was translated as the source-external `font.FontStyle`, and that spelling leaked through collection, resolver, grid, discovery, renderer, CLI, and test contracts. | Rename the canonical byte-backed enum to `Style` and route every font-module and external consumer through the source-shaped root name; the unrelated configuration `fontstyle.FontStyle` tagged value remains unchanged. |
| font collection API names | `Index.int`, `Collection.setSize`, and the private `syntheticBold`/`syntheticItalic` helpers were all implemented under source-external expanded names, so even this otherwise translated collection logic did not retain its source-shaped entry points. | Restore `Index.int`, `Collection.set_size`, `Collection.synthetic_bold`, and `Collection.synthetic_italic`, and route every production and test call site through the canonical names. |
| font collection behavior | A failed resize after loading a deferred face leaked the newly loaded native face; read-only searches bypassed `getConstEntry`; collection synthesis omitted all source diagnostics and passed the computed inherited-size options even though the pinned source passes the original load options; and scale calculation added a source-external zero-denominator fallback. | Restore the source-equivalent error cleanup, const-entry paths, diagnostics, effective pinned synthesis options, and direct metric division; remove an unused source-external face-list accessor and restore the source-private deferred predicate. |
| font codepoint resolver | `StyleStatus` discarded the regular-style element of Ghostty's enum array; override lookup rewrote the requested descriptor, iterated until it found coverage, swallowed discovery/add errors, and accepted codepoints outside the source `u21` boundary; fallback discovery bypassed `Entry` presentation semantics and omitted diagnostics; sprite rendering returned an invented missing-sprite error instead of the source invariant trap. | Retain and mutate all four style statuses, restore the source first-result/cache/error algorithm through small V result wrappers, enforce the `u21` boundary, route fallback checks through a fallback `Entry`, restore discovery diagnostics and fallible iteration, remove the source-external presentation projection helper, and preserve the sprite invariant. |
| CoreText fallback discovery errors | CoreText matching-collection creation failure was treated as a successful empty result, and `discoverCodepoint` collapsed Ghostty's fallible optional into an optional. A failure loading the first face of a requested style was silently skipped, allowing a lower-priority style or no fallback to hide the error. | Reject a missing matching-descriptor array, restore the error-plus-optional descriptor result, and propagate the selected collection face's load failure exactly where Ghostty uses `try`. A macOS regression test constructs a deferred face without load options and pins the error boundary. |
| CoreText candidate scoring | The native scoring shim seeded bold/italic/monospace from the loaded font instead of Ghostty's candidate-descriptor traits, and identified variation axes by numeric OpenType tag instead of the CoreText axis-name string consumed by the pinned algorithm. This could reorder otherwise close variable-font candidates. | Read the descriptor's traits dictionary first, then retain Ghostty's OpenType/variation refinements; consume the axis name while continuing to use its identifier only to look up the active value. |
| CoreText scoring implementation | `Score.score` was only a V wrapper around a handwritten C reimplementation of Ghostty's discovery algorithm. Besides violating the translation boundary, it duplicated style matching, variation precedence, OpenType parsing, and packed-score construction outside the translated module. | Translate `Score.score` directly into V, use the translated OpenType and ASCII helpers, and reduce the C shim to primitive CoreText value extraction that V's C interop cannot express. Remove the packed-result bridge and restore the source's malformed-table warnings. |
| CoreText face metrics implementation | `Face.getMetrics` delegated ASCII measurement, aggregate bounds, CJK `ic_width` validation, and fallback metric decisions to a handwritten C routine. It clamped negative CoreText leading, invented underline/strikethrough defaults later discarded by V, silently rejected malformed CJK advances, and omitted table, atlas-depth, and debug variation-axis diagnostics. | Translate the complete metric path into V and route its scalar, glyph, advance, orientation, and units-per-em operations through source-shaped macOS CTFont bindings. Preserve raw leading and source table precedence, restore the CJK/font-name warning and malformed-table logs, restore atlas-depth diagnostics, and enumerate native variation metadata in debug builds. |
| CoreText glyph rasterization implementation | `Face.renderGlyph` delegated allocation, color-space and bitmap-context selection, smoothing, drawing colors, synthetic bold, transforms, and the CoreText draw call to a handwritten C routine. The routine also omitted Ghostty's explicit transparent fill and added a source-external text-matrix reset. | Translate the complete rasterization sequence into V and add only the source-shaped `CTFont.draw_glyphs` primitive to the macOS bindings. Restore the explicit fill and remove the extra text-matrix mutation while retaining direct grayscale, color-emoji, thickening, and synthetic-bold coverage. |
| CoreText face-copy implementation | Synthetic italic and variation application delegated Ghostty's descriptor algorithms to handwritten C, where failed variation-number/descriptor creation was silently skipped. The shared copy helper also rewrote CoreText's size `0` (preserve the existing size) to 13 points, so synthetic bold unexpectedly resized fonts. | Translate font and descriptor copying into V over source-shaped macOS primitives, propagate every variation error, use CoreText's native preserve-size sentinel, and cover synthetic italic/bold size retention directly. |
| CoreText color-table implementation | Font-table copying and `ColorState` construction were hidden in handwritten C that combined symbolic-trait detection, `sbix` probing, CFData copying, and allocation. Empty native tables were also reported as absent even though Ghostty distinguishes a present empty table. | Add source-shaped table-tag, table-copy, and symbolic-trait primitives to the macOS bindings; translate table ownership, `sbix` detection, SVG parsing, and deferred presentation checks directly into V; preserve present empty tables. |
| CoreText glyph lookup implementation | UTF-32 conversion, CoreText glyph lookup, and missing-glyph policy were delegated to handwritten C for live faces, deferred faces, and discovery scoring. The helper omitted Ghostty's surrogate-pair invariant check on live face lookup. | Add the source-shaped `CTFont.get_glyphs_for_characters` primitive and translate all three callers' UTF-16 conversion directly, including the live face's second-glyph assertion while retaining the deferred/discovery boolean contracts. |
| CoreText font construction implementation | In-memory face initialization and discovery descriptor loading were delegated to C routines that assembled CFData, font descriptors, and CTFont objects. The same shim retained unused path/default-font constructors with source-external fallback to Menlo. | Translate in-memory and descriptor font construction through the macOS CFData/CTFont APIs, route test and deferred fixtures through those bindings, propagate the source construction failures, and delete the unused fallback constructors. |
| CoreText codepoint-fallback implementation | `discoverCodepoint` delegated UTF-8/UTF-16 preparation, `CTFontCreateForString`, `LastResort` rejection, and descriptor copying to a handwritten C routine. | Translate the complete fallback selection sequence into V and expose only a range-marshalling `CTFont.create_for_string` primitive, preserving style priority, the UTF-16 range length, the 64-byte PostScript-name check, `LastResort` rejection, and descriptor ownership. |
| CoreText search-descriptor implementation | `Descriptor.toCoreTextDescriptor` delegated optional family/style strings, codepoint character sets, rounded size, packed symbolic traits, and the nested traits dictionary to handwritten C. Allocation failures in individual fields were silently skipped, producing a broader descriptor rather than propagating Ghostty's error. | Translate descriptor construction directly into V, add the complete pinned CoreText font-attribute, trait-key, and variation-axis-key surfaces to the macOS bindings, and propagate every intermediate CoreFoundation construction failure. |
| CoreText matching-collection implementation | `CoreText.discover` delegated descriptor-array creation, font-collection construction, matching, array traversal, and member retention to handwritten C helpers even though each source API was already translated in the macOS module. | Reproduce Ghostty's descriptor-array, collection, matching-array, and retained-copy sequence directly in V and remove the redundant collection/array C wrappers. |
| CoreText discovery score primitives | Discovery scoring delegated glyph count, symbolic-trait dictionary decoding, and style-name extraction to handwritten C, with traits repacked into private bridge bits. The shim also retained an unused descriptor-color probe. | Add the source-shaped glyph-count binding, read the descriptor's trait number and style string through the translated CoreFoundation types, and remove all four redundant helpers. |
| CoreText variation attribute handling | Face diagnostics and discovery scoring delegated variation-axis arrays, axis dictionaries, configured values, number conversion, and name conversion to four handwritten C helpers. | Add the source-shaped `CTFont.copy_attribute` binding and directly translate both Ghostty loops over `variation_axes`, including default/configured value selection and debug metadata logging. |
| CoreText discovery descriptor cleanup | Iterator loading delegated the source's character-set override dictionary and descriptor copy to C, and retained/released the result list through private aliases. | Translate the `kCFNull` character-set override and descriptor copy directly, and use the typed CoreFoundation release path for retained matching descriptors. |
| CoreText face names and file URL loading | Family/display names, descriptor copying, and file-path extraction were hidden in C. Deferred family lookup used `CTFontCopyFamilyName` instead of Ghostty's optional `.family_name` attribute, and the FreeType path bypassed the source URL path and percent-decoding sequence with a larger private buffer. | Add the source-shaped name bindings, use the family attribute for deferred faces, translate URL copying and percent decoding through the macOS module with the source's 1024-byte contract, and cover the complete CoreText-to-FreeType load path. |
| CoreText HarfBuzz font and scale | `CoreTextFace` stored an opaque HarfBuzz pointer behind the final font C shim. That shim bit-cast an IEEE `float` pixel value into the integer scale, producing values such as `0x41400000` for 12 pixels instead of Ghostty's 26.6 fixed-point value `768`. | Store the translated `harfbuzz.Font` directly, create/destroy it through that module, convert pixels with `F26Dot6.from`, set the raw scale, and delete `font/coretext_shims.h` after its final callers are removed. |
| duplicate FreeType shim implementation | `freetype/freetype_shims.h` retained a second handwritten lifecycle, load-flag, bitmap, and metric implementation after the live FreeType binding moved to its source-shaped API plus opaque-struct accessors. The file had no include or caller and no pinned-source counterpart. | Delete the unused duplicate; retain only `bridge.h`, whose inline field/macro accessors are required ABI marshalling for FreeType's opaque C structures. |
| obsolete global-state signal shim | `global_state/global_state_shims.h` retained an unused `SIGPIPE` helper after `GlobalState.init` was translated to call `signal(SIGPIPE, SIG_IGN)` directly. | Delete the unreferenced duplicate header; the live initialization path remains the direct translation of `global.zig`. |
| deferred-face naming surface | `DeferredFace.familyName` and `name` were replaced by infallible source-external accessors, and the font-list action therefore omitted both source error paths while the resolver could not use the canonical display-name API. | Restore fallible `family_name` and `name` methods with the caller-buffer contract, route resolver and CLI callers through them, and restore font-list diagnostics. Fontconfig reads names from its owned prepared pattern; CoreText uses the caller buffer against the retained native font. |
| font hashing entry points | The byte-exact hashing logic for discovery descriptors, codepoint maps, shared-grid keys, and metric modifiers was hidden behind private `hash_into` helpers; metric modifiers additionally exposed an invented zero-argument hash. The widened codepoint-map range also accepted values outside the source `u21`. | Restore all four public `hash(hasher)` entry points, make each `hashcode` a thin source-shaped wrapper, route nested hashing and direct tests through those methods, and enforce the `u21` boundary at the widened V API. `SourceHash` is the V specialization of Zig's `anytype` hasher contract. |
| font metrics modifier surface | `Modifier.parseCLI` was absent and configuration bypassed it, while the public generic `apply` contract was narrowed to `u32` and `Metrics.apply` called three private implementations directly. Percentage overflow was silently saturated instead of retaining the source integer-conversion trap, negative signed absolute overflow returned `minInt` instead of the source's `-maxInt`, and the mutating `addFloatToInt` helper had been replaced by a source-external return-value helper. | Restore `parse_cli`, a generic `apply` entry point specialized for the retained `u32`, `i32`, and `f64` metric fields, and the mutating `add_float_to_int`; route configuration and every metrics field through those methods; and align both integer-overflow boundaries with the pinned expression. |
| font shared-grid and cursor error paths | `SharedGrid.renderCodepoint` erased errors from font lookup, deferred loading, and glyph rendering; both shared-grid tripwire modules and all three init cleanup boundaries were absent. The renderer substituted the rectangular sprite for Ghostty's lock glyph, truncated cursor alpha instead of rounding upward, and silently discarded preedit and cursor failures. | Restore the two typed tripwire surfaces, source-order init cleanup, the error-plus-optional render contract, lock-codepoint rendering, ceiling alpha conversion, and source diagnostics at every caller. `RenderValue` is the V representation of Zig's `!?Render`, and V's GC maps cannot expose real capacity-allocation errors, so the capacity tripwires preserve those source test boundaries. |
| font shared-grid set and deferred discovery | The live deferred face discarded Fontconfig's render-prepared pattern and CoreText's retained font, so configured families had to be eagerly loaded; discovery iteration searched past failed candidates and erased its error channel, while `SharedGridSet` swallowed discovery/load errors instead of retaining Ghostty's first result. Set construction also leaked native collection state on late failure, omitted source logging, silently accepted corrupt descriptor offsets, widened counts/offsets, and exposed translation-only `GridSetKey`/`GridSetDerivedConfig` names without `DerivedConfig.init`. | Retain the complete owned Fontconfig pattern with its cached borrowed charset/langset, or the native CoreText font, and use that state for lazy naming, coverage, and loading. Represent `!?DeferredFace` explicitly in V, propagate/catch iterator errors at the same source boundaries, and make the set add exactly the first result with ownership cleanup. Restore source-shaped `Key`/`DerivedConfig`, their fallible initializers and lifecycle, `usize` counts/offsets, invariant-preserving slicing, and route core plus `show-face` through the single derived-config constructor. V still combines FreeType rendering with retained CoreText shaping state rather than reproducing Ghostty's compile-time backend type selection. |
| Fontconfig package surface | The local binding recognized only nine of Ghostty's 51 pattern properties and flattened four value kinds without a tag; `.file`/`.index` were handled by source-external helpers. Pattern parse/delete/filter/object-value iteration, object/font-set operations, exact language matching, config font listing, full result/binding enums, and Fontconfig lifecycle/version operations were absent. | Restore all properties and the complete `FcValue` tag/payload model through a small union-safe C bridge, route deferred-face file/index reads through generic `Pattern.get`, translate the omitted package operations and constants, and add direct tests for typed values, filtering, listing, and nested pattern iteration. The process initializer remains `fc_init` because V reserves `init` for module initialization; opaque C pointers are represented by handle wrappers instead of Zig pointer casts. |
| FreeType package face and flag surface | The binding retained only one of 14 encodings, three of six render modes, four of seven SFNT selectors, and 7 of 21 glyph-load flags in an expanded struct. It omitted runtime version reporting, tag string conversion, SFNT existence checks, and transforms; widened `mulFix`; narrowed name indexes inconsistently; and converted an absent raw SFNT table into an invented error. | Restore every pinned enum/flag value in the canonical 32-bit load word, route live glyph loading through typed bit accessors, add the four missing operations, restore `i32` fixed multiplication and `usize` name indexes, and represent the fallible optional table result explicitly. Direct tests verify every flag bit/target, enum/tag values, the library version, table access, and transforms against an embedded repository font. `Tag.str` returns a V string rather than Zig's fixed byte array because V reserves `str()` for string-returning methods. |
| FreeType error contracts | Every wrapper discarded Ghostty's exhaustive 91-member FreeType error set and returned a different ad-hoc string containing only an operation name and integer. The public `intToError`/`errorToInt` conversions were absent, so callers could not distinguish invalid input, unsupported formats, memory failures, or corrupt font tables. | Retain every pinned FreeType error code in `ErrorKind`, expose both conversion directions, carry the kind in V's `IError.code()`, classify unknown/newer library codes as the source's `UnknownFreetypeError`, and route all fallible package calls through the single translated converter. V reserves `Error` as its built-in error implementation, so the exported error-set analogue uses the `ErrorKind` name. |
| FreeType face behavior | Variation-axis reads and writes silently returned success on three FreeType failures, the coordinate update iterated a source-external truncated range, and debug builds omitted Ghostty's face/axis inspection. Unsupported pixel modes were converted from an invariant panic into a recoverable error, while unsupported glyph formats and invalid CJK width metrics lost their source diagnostics. | Propagate all three variation errors, restore the source axis iteration and debug metadata path, preserve the unsupported-pixel panic, and restore the glyph-format and `ic_width` diagnostics with the source values and font name. |
| FreeType face invariants | Missing size metrics, glyph slots, and the per-face mutex were converted into zero/empty metrics, false color detection, or recoverable render failures even though Ghostty dereferences those initialized-face invariants. A zero units-per-em value was also silently replaced by `1`. | Restore invariant failures for the face state and post-load glyph slots, and use the selected units-per-em directly in the source calculation instead of manufacturing a metric scale. |
| HarfBuzz common and buffer surface | The wrapper omitted all 160 pinned script tags, language handles, version reporting, feature serialization, the grapheme cluster level, five bulk input encodings, and every buffer property getter except length. Its remaining common enums were widened, and an empty-but-valid glyph-position result was changed to `none`. | Restore compact common tags with every pinned ISO 15924 value, language/version/feature operations, the complete buffer input/property API, and the source distinction between a null position pointer and a valid empty result. Direct tests exercise all input forms and round-trip content, direction, script, language, features, and representative boundary script values. |
| HarfBuzz ownership and backend surface | `Blob` and all four memory modes were absent, along with user-data lifecycle callbacks, FreeType face construction/font-function installation, CoreText font construction, and font scaling. The wrapper instead added an unused file-to-face constructor and silently ignored shaping with a null font. | Restore the blob lifecycle and user-data contract, both FreeType constructors, callback installation, Darwin-only CoreText construction, and checked source-width scaling; remove the source-external file constructor and null-font no-op. Direct tests cover blob destruction callbacks and each available backend constructor. |
| HarfBuzz result and shaper fidelity | Glyph info/position values omitted HarfBuzz's private ABI fields and were allocated copies instead of borrowed native slices. The live shaper duplicated a one-item feature string list, did not accept comma-separated option lists like `FeatureList`, and returned handwritten unshaped codepoints when its required grid was absent. | Restore both complete 20-byte native layouts and no-copy result views, build global HarfBuzz features from the canonical translated `FeatureList`, reject the impossible missing-grid state, and remove the fallback plus its source-external `has_positions` dependency. |
| Oniguruma option and region ABI | The 32-bit `Option` word was expanded into 25 booleans and rebuilt for each call. `Region` was replaced with a separately heap-allocated opaque pointer; `starts`/`ends` allocated copies; and `errorString` allocated its own buffer instead of filling the caller's. | Retain the canonical option word with all 25 typed bit accessors, restore the native five-field stack region and non-owning range views, pass that value directly through both search entry points, and restore caller-buffer error formatting. `Options` remains as a compatibility spelling beside source-shaped `Option`. |
| OpenGL buffer and wrapper contracts | Buffer uploads accepted only byte slices and treated element counts as byte counts; the typed null allocator and homogeneous attribute helper were absent; `setDataNullManual` was misnamed; extension iteration discarded GL errors; all C-backed enums used V's implicit storage; info-log getters returned allocated strings; and several calls added error checks or fallback behavior absent from the pinned wrappers. | Restore slice and single-item-pointer byte sizing, both null allocation forms, fixed-f32 array attributes, a fallible optional-result value for extension iteration, every signed/unsigned C enum width, fixed 512-byte info logs, source compile/link error names and destruction assertions, generic integer pixel storage, no-copy framebuffer attachments, and the source's exact per-call error checks. |
| OpenGL Glad loader and version contract | `load` ignored its procedure resolver, queried directly linked GL symbols, and encoded the reported version as a 16/16 bit pack; `unload` was an empty stub. Every translated wrapper consequently bypassed Ghostty's thread-local `GladGLContext`, and real Glad results such as `40003` decoded as major zero. | Vendor Ghostty's exact pinned Glad 2.0.8 generated header/source, load it through the supplied resolver or Glad's platform loader, route all 75 consumed GL entry points through the thread-local context, release and invalidate that context on unload, and decode Glad's `major * 10000 + minor` result. A synthetic 4.3 resolver regression test exercises load, a routed call, version decoding, and unload. |
| stb public surface and resize behavior | The translated stb module omitted Ghostty's PNG-only `stbi_load_from_memory` and matching `stbi_image_free` exports. Its remaining resize wrapper selected a box filter, returned a V boolean, and rejected invalid dimensions before calling C instead of exposing the pinned `stbir_resize_uint8` function directly. | Vendor the exact pinned stb image header, compile it with Ghostty's PNG-only and 131072-dimension configuration, restore both image entry points, and call the source default resize implementation with its integer result and C-width arguments. Tests decode/free a pinned PNG, verify failure output preservation, and pin interpolation output that differs from the removed box-filter substitute. |
| Wuffs image package and live decoding | The complete `pkg/wuffs` package was absent. Kitty PNGs and renderer background images used V's stb binding, while renderer upload used a handwritten per-pixel conversion loop instead of Ghostty's Wuffs swizzler. JPEG/PNG overflow handling and the public swizzle entry points therefore had no translation. | Vendor the exact pinned Wuffs v0.4 amalgamation and source test pixels; restore `ImageData`, the 4 GiB limit, PNG/JPEG configuration and frame decoding, all five swizzlers, status/error propagation, and the source namespace modules. Route Kitty PNG decoding, renderer PNG/JPEG backgrounds, and pending-image conversion through those canonical modules. Direct tests cover both decoders, invalid and oversized PNGs, every supported swizzle, and the pinned Wuffs version's own unsupported `YA_PREMUL` result. |
| C string slice contract | The translated `String` split `fromSlice` into string/byte constructors but left the ordinary byte form named `from_bytes`, omitted the source `deinit` method, and built `ghostty_config_open_path` through the sentinel string form. The returned C record therefore claimed its ordinary allocated path had a NUL sentinel. | Restore `from_slice` for non-sentinel bytes and `deinit`, route the exported free function through the method, and return the config path with `sentinel=false`; the V string constructor remains the explicit sentinel form because V types do not encode sentinel slices. |
| SSH cache public lifecycle surface | Disk-cache `defaultPath` was a module-prefixed free function, `deinitEntries` was absent under GC ownership, and the action's public `runInner` entry point remained folded into a private cache-injection helper. | Restore type-scoped `default_path`/`deinit_entries` plus public `run_inner`, retain a private injected-cache helper for deterministic tests, and route the action through the public standard-path entry point. |
| GTK command-palette jump accessor | `Command.getJumpSurface` was folded into a private presentation helper, removing the public caller-owned strong-reference API. | Restore `get_jump_surface`, including the weak-to-strong promotion and caller `unref` contract, and route presentation through it. |
| GTK command-palette constructors | The source `Command.new` and `Command.newJump` constructors were exposed as module-level `command_new`/`command_new_jump` functions, leaving the translated type surface incomplete. | Restore both type-scoped constructors and route regular-command tests plus both production collection paths through them. |
| PageList tracked-pin accessor | The tracked-pin backing array occupied the V spelling of Ghostty's public `trackedPins` method, forcing callers onto the source-external `tracked_pins_view` name. | Rename only the private storage, restore `PageList.tracked_pins`, and keep every mutation and remapping path on the same canonical backing array. |
| GTK explicit paste entry point | `Clipboard.paste` was translated only as a private drag-and-drop helper, so the source's explicit-text paste API was absent even though its unsafe-paste confirmation logic existed. | Expose the method as `SurfaceWidget.paste` and route both drop-target call sites through the public entry point. |
| crash envelope transport and directory | The disabled Sentry lifecycle path also omitted the source transport's privacy-critical filtering and local persistence logic. `default_dir` was infallible and called V's directory helper, which creates the base directory as a side effect, instead of using Ghostty's fallible XDG path resolution. | Translate event detection, non-crash envelope discard, UUID naming, directory creation, and byte-for-byte local envelope persistence with no network transport; restore the fallible, side-effect-free XDG state-directory lookup. |
| Linux cgroup build | The write-only cgroup helper called variadic libc `open` with two arguments; the pinned V compiler requires its declared mode slot, so the Linux whole-project check failed before C generation. | Pass the ignored zero mode argument for non-creating write-only opens and restore the Linux semantic-check gate. |
| input modifier ABI | `Mods.translation()` fully inverted the option-as-alt policy, while the retained value was seven expanded fields and `SideInfo` was four bytes; `int()` merely rebuilt the low ten bits and `mods_from_int` discarded Ghostty's six padding bits. | Match the source translation policy and retain the complete public `Mods` ABI in one `u16`, including padding through bitcasts and bitwise operations; retain side metadata in one byte, route construction/mutation through typed bit accessors, and consume the retained word directly in binding order and remapping. |
| input modifier remapping | The side enum added a third `none_` state absent from Ghostty, remap input accepted the translated identifier `super_`, and `parse_cli` exposed internal missing-assignment/modifier errors instead of its source `InvalidValue` contract. | Restore the two-value, byte-backed side enum with left as zero/default, accept only source CLI spellings, and normalize remap parser failures to `invalid value`. |
| input modifier remap mask | Ghostty's 12-bit fast-rejection mask stores key, inverted-left-side, and right-side state in three four-bit lanes, while Witty retained those lanes as three independent bytes. | Retain the mask in one `u16`, preserve the source lane order, and perform update/match directly against typed lane accessors. |
| input helper tags | Function-key modes, modifier identity, link union tags, keyboard layout, and help format used V's default 32-bit enum storage. The keyboard-layout enum also added three cases absent from Ghostty. | Restore byte-backed source-inferred tags with their exact declaration order, remove the source-external layouts, and make layout detection exhaustive over the three source cases. |
| input binding tags | The 83-case action union tag, both flattened helper-union tags, and thirteen nested action enums all used V's default 32-bit storage. The flattened trigger key happened to be 32-bit too, but did not explicitly preserve Ghostty's deliberate `enum(c_int)` tag contract. | Restore byte backing for every source-inferred tag, explicitly retain the trigger key's signed 32-bit C tag, and exhaustively verify every declaration-order ordinal. |
| input/keymap | Darwin and no-op keymaps were collapsed into one C wrapper, causing the non-macOS path to reject an empty output buffer and return the input modifiers (minus Ctrl) instead of a completely default translation. The Darwin path also looked up its Unicode layout per keypress and required spare room for a C terminator. | Restore platform-selected keymap files; make the no-op translation ignore every argument; retain Darwin's input-source and Unicode-layout pointers; return an explicit UTF-8 byte length from the Carbon shim. |
| input/mouse ABI | The public button enums relied on V's implicit enum layout instead of Ghostty's explicit `c_int` contract, while `ScrollMods` expanded the packed source byte into an ordinary two-byte struct and its C decoder discarded the four padding bits and invalid momentum bit pattern. | Give both public button enums explicit 32-bit backing and represent `ScrollMods` with its exact raw byte, preserving all eight C ABI bits while exposing typed precision and momentum accessors. |
| apprt/ipc | The optional new-window argument slice was collapsed to an always-present V array, and all of Ghostty's target/action C ABI projections were omitted. | Preserve absent versus present-empty arguments through the CLI and GTK path; restore target/action tags, unions, C layouts, null-terminated argv allocation, and deinitialization. |
| apprt/structs | Compact `ClipboardRequestType`/`ColorScheme` and non-GTK `Clipboard` enums were widened to V's default 32-bit enum; the flattened clipboard request consequently had the wrong layout outside GTK. | Restore 8-bit compact backing, platform-select GTK's C-int clipboard backing, and assert the resulting request layout on GTK and non-GTK targets. |
| apprt/action | `MoveTab.amount` was fixed-width `i64` instead of source `isize`; present search totals/selections silently wrapped through the signed C projection; and the flattened key-sequence end arm leaked an ignored stale trigger instead of Ghostty's explicit default C trigger. | Carry `isize` through the queued action, range-check optional `usize` counts before reserving `-1` for absence, and canonicalize the C payload of an ended sequence. |
| apprt/action C enums | The action discriminant and all seventeen C-visible action payload enums depended on V's default enum representation rather than preserving Ghostty's explicit `enum(c_int)` contracts. | Give every C-facing enum signed 32-bit backing, retain non-exhaustive positive tab/palette values through raw casts, and verify complete declaration-order ordinals. |
| apprt/none | The no-op runtime's IPC entry point returned plain `bool`, unlike Ghostty's fallible runtime contract and the other application runtimes. | Restore the `!bool` result contract while retaining the source's always-unhandled result. |
| apprt/surface mailbox | The flattened callback erased `BlockingQueue.Timeout`, so the stream handler's nominal instant probe actually performed a forever-blocking app-mailbox push while holding the renderer mutex; selection-scroll ticks also became blocking. | Carry the timeout and `u32` queue size through the surface callback, preserve instant/forever at every producer, and only retry the stream-handler write after releasing the renderer lock. |
| apprt/surface tags | The flattened surface-message discriminant and title-report style used V's default 32-bit storage, while the shared new-surface context merely depended on that default for Ghostty's explicit `enum(c_int)` contract. | Restore byte backing for both source-inferred tags, signed 32-bit backing for the C-facing context, and verify every ordinal. |
| apprt/core bridge | Runtime-neutral preedit/text wrappers invented boolean results absent from `Surface.zig`, and the duplicated embedded size projection returned zero grid dimensions below one cell instead of using `GridSize`'s minimum-one contract. | Restore void error-union callback results and mirror the source floating-point, checked `u16`, minimum-one grid calculation. |
| apprt/runtime | The two-case source enum used default 32-bit V storage, while its source `default` method had been replaced by an unused string dispatcher plus a duplicate free function. | Use byte storage and expose one platform-selected `Runtime.default()` method, eliminating the source-external string API. |
| core/App teardown | App teardown silently deinitialized a non-empty shared font-grid set, omitting Ghostty's ownership assertion that all surfaces must release their grid references before application destruction. | Restore the zero-grid assertion immediately before `SharedGridSet.deinit()`. |
| apprt/GTK new-surface context | The GTK runtime declared a second `NewSurfaceContext` enum and threaded it through its window, tab, and surface classes even though Ghostty uses the shared `apprt.surface.NewSurfaceContext` contract directly. | Remove the GTK-local enum and use `apprt.NewSurfaceContext` throughout the runtime boundary. |
| apprt/embedded text | The internal embedded text result narrowed Ghostty's `usize`/`uintptr_t` text length to V's 32-bit `int` before the public C projection. | Preserve `usize` from the dumped text through the embedded result and assert pointer-width storage with a value above `int` range. |
| apprt/embedded platform | Surface initialization replaced explicit zero/negative scale factors with `1`, accepted platform tags outside the source enum, and constructed Darwin-only platforms on other targets. | Preserve Ghostty's direct `f64` to `f32` scale conversion, reject unknown tags, and return `UnsupportedPlatform` outside Darwin. |
| apprt input/embedded tag backing | Core input effects used default 32-bit storage for a source-inferred enum, while embedded platform and point-coordinate tags only accidentally matched Ghostty's explicit `enum(c_int)` ABI through V's default. | Byte-back the internal input effect, give all three public tags explicit signed 32-bit backing, and verify their complete numeric values. |
| apprt IPC C tag backing | IPC target and action tags both relied on V's implicit enum representation even though Ghostty deliberately gives the target signed `c_int` backing and the action unsigned `c_uint` backing. | Give both C-facing tags explicit 32-bit backing with the source signedness and verify their complete numeric values and enclosing C projections. |
| apprt/embedded key event | The raw `unshifted_codepoint` conversion treated Ghostty's `u21` as a Unicode scalar and rejected values above `0x10FFFF`, although the source cast accepts every 21-bit value through `0x1FFFFF`. | Restore the actual `u21` numeric boundary and clamp only values that do not fit in 21 bits. |
| apprt/embedded initial input | A present-but-empty surface `initial_input` was ignored, leaving configured startup input in place; Ghostty clears it and installs one empty raw input entry. | Branch on optional presence rather than string length, preserving empty-string override semantics. |
| core/surface scroll | The translated core callback narrowed Ghostty's `input.ScrollMods` parameter to a `precision` boolean, and both embedded and GTK adapters discarded the momentum field before dispatch. | Restore the full scroll-modifier contract at the core surface boundary and propagate it unchanged from embedded callers. |
| core/surface pressure | Mouse state duplicated the source input enums (`normal` was renamed `light`), compact pressure/momentum enums were widened to V's default integer, the bridge translated pressure values, and a deep press selected the word at the current cursor rather than Ghostty's retained original click pin. | Use byte-backed input pressure/momentum enums and the input button-state type directly, remove the bridge mapping, and select from the stored click pin. |
| core/surface private tags | Mouse-report, write-screen, key-sequence cleanup, and normalized-scroll direction values retained source local/anonymous enum tags as default-width V enums. | Store all five source-inferred tags in one byte apiece and verify their complete declaration order. |
| core/surface size | The translated core callback split Ghostty's `apprt.SurfaceSize` parameter into independent width and height integers, forcing every runtime adapter to reconstruct a source-external call shape. | Restore the shared surface-size value through the core, embedded, and GTK callback path. |
| core/surface geometry | Core-local content-scale and cursor-position structs duplicated Ghostty's shared `apprt` contracts; the cursor duplicate also widened both source `f32` fields to `f64`, with adapter-side copying in both directions. | Use `apprt.ContentScale`, `apprt.SurfaceSize`, and `apprt.CursorPos` directly for runtime queries and callbacks; widen coordinates only where the source calculation accepts `f64`. |
| core/surface renderer size | `Surface` carried a second handwritten implementation of renderer screen/cell/grid/padding/aggregate sizes, including zero-cell grids and different balanced-padding math, then copied it into the translated renderer and termio types. | Store and forward `renderer.Size` directly, restoring its source `u16` minimum-one grid and balanced-padding behavior and removing the duplicate converter. |
| core/surface shared values | The core surface redefined `apprt.IMEPos` and copied it at the bridge, and exposed a redundant local `ColorScheme` alias instead of the source callback/query types. | Return `apprt.IMEPos` directly and accept `apprt.ColorScheme` directly, removing the extra projection layer. |
| core/surface derived config types | `DerivedConfig` redeclared six configuration enums and both input link enums, populated them with unsafe integer casts, and omitted the valid `link-previews=osc8` case from its duplicate type. | Retain the canonical `configpkg` and `input.Link` types directly, removing eight duplicate enums and every projection cast. |
| core/surface binding flags | The core surface copied `input.Binding.Flags` into a differently ordered duplicate struct; the embedded bridge duplicated it again and manually rebuilt the C bitmask. | Return and retain `input.Flags` directly across the opaque bridge and use its translated `cval()` projection at the C boundary. |
| core/surface action payloads | The runtime-neutral surface action record declared parallel prompt-title, fullscreen, inspector, split, window, resize, close-tab, goto-tab, search-navigation, and write-screen types. The embedded and GTK paths then converted those copies back to the canonical `apprt`/`input` types. | Carry the canonical payload enums and structs directly, resolve only the input-only automatic split case, and remove the duplicate core/GTK types and bridge projections. |
| core/surface action discriminant | The surface runtime wrapper declared a 62-case `AppActionKind` copy in a different order from `apprt.ActionKey`, including three values that could never validly reach runtime dispatch. | Store `apprt.ActionKey` directly in the wrapper, map app-scoped input actions to that canonical key, and remove the dead close/ignore/unbind bridge arms. |
| core/surface action value | The surface runtime wrapper flattened Ghostty's tagged action value into more than thirty parallel fields, and the embedded bridge reconstructed the canonical `apprt.ActionValue` with a second handwritten dispatch switch. | Carry `apprt.ActionValue` unchanged through the core and runtime adapters, construct every canonical payload at its source producer, and retain Ghostty's supported-only OSC color projection at the surface boundary. |
| core/surface runtime action transport | Core still declared a second `RuntimeApp` and `AppAction` queue around the now-canonical target, key, and value, so every surface action crossed an unnecessary source-external record and runtime implementation. | Use the shared `apprt.RuntimeApp` and `apprt.RuntimeAction` directly for both app- and surface-scoped actions; retain only a runtime callback hook for V's compile-time module boundary. |
| core/surface runtime surface transport | Core duplicated the runtime surface's close, scale, size, cursor, title, clipboard, environment, renderer-view, and Linux-cgroup state plus every dispatch method. Its clipboard-capability callback accepted no location even though Ghostty queries a specific clipboard. | Use one shared `apprt.RuntimeSurface`, move the V module-boundary callbacks onto it, pass the requested clipboard location unchanged, and retain both the source clipboard location and tagged request in headless captures. |
| core/surface IO messages | The surface declared a second IO message enum/struct and projected it into `termio.Message` at the live boundary. Its queued-key and fixed-buffer paths labeled payloads up to 128 bytes as the 38-byte `write_small` arm, silently truncating them when a live PTY was used. | Queue canonical `termio.Message` values directly, represent queued keys with the translated `MessageData(u8, 38)` storage contract, and select the small/allocated arm at the source 38-byte boundary without truncation. |
| core/terminal viewport scroll | Normalized mouse-scroll deltas used fixed `i64`/`u64`, then narrowed to V's 32-bit `int` through core, termio, and terminal; jump-to-prompt messages were narrowed the same way. | Restore source `isize`/`usize` storage across the complete message/API path and clamp only where the flat screen representation reaches its bounded array indexes. |
| core/surface coordinates | `pos_to_viewport` independently reimplemented padding removal, cell division, and clamping rather than using Ghostty's renderer coordinate conversion path. | Delegate directly to the translated `renderer.SizeCoordinate.convert(.grid, size)` and only project the resulting grid pair into the terminal coordinate. |
| core/surface mouse helpers | The live surface duplicated `terminal.Coordinate.eql` and the rectangle-selection modifier predicate, while `mouse_selection` added an invalid-cell guard absent from Ghostty. | Use the terminal coordinate method and the canonical translated `surface_mouse` helpers directly, and preserve the source function's preconditions. |
| root/surface_mouse | An unused second implementation in module `main` defined private substitute key, modifier, and mouse-event types; only its parallel test suite referenced it, while the live core used `core/surface_mouse.v`. | Remove the orphan implementation and move its transition coverage onto the live core helper using canonical input and terminal types. |
| renderer/background file type | The translated file-signature detector lived unused in module `main`, while the live renderer bypassed Ghostty's format policy and decoded any image accepted by stb directly from its path. | Move the detector into an importable module; make the renderer read bytes, use magic detection with extension fallback, reject unknown/unsupported formats, and decode only source-supported PNG/JPEG from those bytes. |
| root/math | An unused root `Mat` wrapper coexisted with a second renderer-local `ortho2d`, so production bypassed the translated `math.zig` module and the root representation did not match the shader matrix. | Replace both with one importable `mathutil` translation, represented as the shader-compatible fixed array, and call it from the live renderer. |
| OpenType packed values | `Version16Dot16`, 16.16 `Fixed`, and 2.14 fixed-point values were expanded into component fields (widening `F2Dot14` to four bytes), while OS/2 `FSSelection` occupied ten booleans and discarded its six reserved bits whenever serialized. | Retain each value in its exact `u32`/`i32`/`i16`/`u16` source backing, expose typed component/flag accessors, parse directly into those canonical words, and preserve all selection bits on round-trip. |
| root/fastmem | The root translation was disconnected and byte-only, while live translated call sites used handwritten element loops instead of Ghostty's generic memory helper. | Restore generic libc-backed move/copy/rotation functions in an importable module and use them from the live cache table, circular buffer, tabstops, and font atlas paths. |
| root/quirks | The translated helper was stranded in module `main`; both font backends omitted Ghostty's explicit `disableDefaultFontFeatures` initialization and happened to get the current result only from V's false zero value. | Move the helper into an importable, cycle-free generic module and call it from both live FreeType and CoreText face constructors. |
| root/tripwire | The failure-injection translation used untyped string points in a private instance exercised only by its own tests, so none of Ghostty's live error sites could be armed; Atlas initialization/growth and the selection-string map-copy boundary had also been made infallible. The translated Atlas, shared-grid, and tabstop point tags retained V's default 32-bit backing. | Restore a generic typed-point module with test-only checks; wire the tabstop allocation, Atlas init/reserve/grow, shared-grid, and selection map-copy points into live paths; restore the fallible result contracts; and byte-back every source-inferred point tag with exhaustive layout checks. |
| font/Atlas format | The three-value atlas format enum and its `depth()` result were widened from Ghostty's `u8` contracts to V's default 32-bit integer. | Restore byte-backed values `0..2` and a byte-sized depth result, retaining explicit widening only at consumers that require it. |
| font/Atlas counters | The atlas modification and resize counters were ordinary fixed-width `u64` fields even though the font producer and renderer consumer run on different threads; Ghostty uses atomic `usize` values and monotonic operations. Renderer frame snapshots were also fixed-width `u64`. | Store both counters as atomic `usize`, use V's atomic increments/loads at every live access, and retain `usize` in Metal and OpenGL frame snapshots. |
| font discovery score | CoreText result priority is a 29-bit packed score in Ghostty, but Witty retained seven expanded fields, repacked them only for comparisons, and widened both the integer method and native bridge to `u64`. | Retain the score in one `u32` with the exact glyph/style/trait bit order, restore the source-named `int()` comparison value, and narrow the CoreText shim contract to the same physical backing width. |
| compact internal enum contracts | Explicitly sub-byte Ghostty enums for font style/presentation, synthetic UTF-8 length, screen selection, mouse mode/format, packed cell metadata, underline style, and Kitty key events were translated as default-width 32-bit V enums. | Use byte-backed V enums (the narrowest supported representation) with every source raw value explicit. |
| remaining explicit narrow enum contracts | The style color-union tag, CSI parameter separator, and sprite corner/edge enums still used V's default 32-bit storage despite explicit `u8`/`u1`/`u2` source backings. | Use one-byte V storage (the narrowest representation for the sub-byte tags), preserve every source ordinal, and assert all four layouts. |
| terminal ANSI protection layout | `ProtectedMode` is an inferred two-bit Zig enum even when the terminal is built for its C ABI, but Witty stored it as a default-width 32-bit enum alongside four intentionally C-width `lib.Enum` values. | Use byte-backed storage only for `ProtectedMode`, retain the four C-facing enums at 32 bits, and assert both contracts and all protection-mode ordinals. |
| terminal title push/pop layout | The nested push/pop operation is an inferred one-bit Zig enum, but Witty stored it as a default-width 32-bit tag and widened `TitlePushPop` from four bytes to eight; the adjacent size-report style is intentionally C-width. | Use byte-backed storage for the operation only, preserve its declaration order, retain the C-facing style enum at 32 bits, and assert the four-byte enclosing layout. |
| terminal DCS setting layout | The five-case DECRQSS setting retained in parsed DCS commands is an inferred three-bit Zig enum, but Witty stored it as a default-width 32-bit enum. | Use byte-backed V storage (the narrowest addressable representation), preserve declaration order, and assert all five ordinals. |
| terminal selection enum layouts | Selection order and adjustment are inferred two-bit/four-bit Zig enums, but Witty stored both as default-width 32-bit values. | Use byte-backed V storage for both internal tags and assert their complete declaration-order ordinals. |
| terminal point tag layout | The four-way point reference tag is an inferred two-bit Zig union discriminant, but Witty stored it as a default-width 32-bit enum in its tagged-struct adaptation. | Use byte-backed V storage, preserve all source ordinals, and assert the tag, coordinate, and alignment-preserving aggregate sizes. |
| terminal render-dirty layout | The three-state dirty marker retained on every render snapshot is an inferred two-bit Zig enum, but Witty stored it as a default-width 32-bit enum. | Use byte-backed V storage and assert the exact declaration-order ordinals beside the dirty-state behavior tests. |
| terminal formatter mode layout | The plain/VT/HTML formatter mode is an inferred two-bit Zig enum, but Witty stored it as a default-width 32-bit enum throughout formatter instances. | Use byte-backed V storage and assert its layout, declaration order, and style classification. |
| terminal SGR attribute ABI | The public SGR tag kept the required 32-bit width but not Ghostty's `lib.Enum(.c, ...)` numeric order: `unknown` moved from 1 to 30, and underline plus background/foreground tags were rearranged even though the C adapter exposes this value. | Restore the exact 31-entry source order while retaining 32-bit storage, and assert every exported numeric value. |
| terminal generated C enum backing | ANSI request/style/display/key-format enums, CSI size-report style, the 93-case stream action key, and the SGR tag all relied on V's default enum width for Ghostty's `lib.Enum(.c, ...)` contract. The stream key also lacked a complete ordinal guard. | Give all seven generated C enums explicit signed 32-bit backing and verify every stream-key ordinal while retaining the previously checked helper/SGR orders. |
| residual flat-page tags | Flat viewport/reflow and semantic-prompt tags used default-width enums; viewport `.pin` was renamed `.pinned`; the reflow result gained a source-external impossible `out_of_space` branch; and `terminal.Direction` was an unused declaration with no source counterpart. | Use byte-backed declaration-order tags, restore `.pin`, remove the unproducible branch/member and orphan direction type, and give the duplicated cycle-boundary prompt tags the same source layout. |
| semantic prompt click representation | Ghostty retains click handling as a tagged union with `none`, `click_events`, and a four-way `cl` payload; Witty flattened that into a tag plus an always-live duplicate of the OSC click enum, forcing downstream switches to project the invented representation. | Represent the three click arms directly, retain the canonical byte-backed OSC click enum only in the `cl` arm, route terminal parsing, prompt movement, the surface, and inspector through that value, and translate the missing OSC-133 click-option regression cases. |
| screen cycle-boundary lifecycle | The semantic-input clear tag was widened to 32 bits, while Kitty image lifecycle calls were routed through a source-external `KittyImagesEvent` enum and a handwritten dispatcher in the Kitty module. | Byte-back the direct two-case semantic tag; replace the event multiplexer with operation-specific cycle-boundary hooks so each screen call maps directly to reset, deinit, dirty, or clear storage behavior. |
| terminal viewport scroll payload | Ghostty carries viewport scrolling as one tagged union whose delta arm owns an `isize`; Witty flattened it into an enum plus an always-live integer through surface messages, termio, and terminal. The adjacent switch-screen and local wrap tags were widened too. | Represent the three viewport arms directly through the full call chain so only the delta arm owns the pointer-width payload, preserve deltas above 32-bit range, and byte-back the two inferred source enums. |
| terminal parser tags and absence | Parser state, transition action, parser-action, and inspector event-kind tags were widened from inferred sub-byte Zig enums to 32-bit values, expanding each transition from two bytes to eight. Invalid CSI dispatches also emitted an invented `.none` action that the inspector had to classify and filter, whereas Ghostty emits no action. | Use byte-backed declaration-order tags, restore two-byte transitions, return optional absence for invalid CSI dispatches, and remove the synthetic tag from parser tests and inspector storage/dispatch. |
| terminal internal enum layouts | The terminal artifact and cursor-style tags plus five PageList direction, viewport, cell-subset, reflow-result, and capacity-adjustment tags were inferred sub-byte enums in Ghostty but default-width 32-bit enums in Witty. | Use byte-backed storage for all seven internal tags and assert every declaration-order ordinal beside their translated tests. |
| termio internal tag layouts | Shell integration and APC state tags were inferred sub-byte enums in Ghostty but default-width 32-bit enums in Witty. The flattened startup-input adapter also widened its source union tag and retained the configuration names `.raw`/`.path` rather than the prepared source arms `.string`/`.file`. | Use byte-backed tags throughout, restore the prepared-input arm names, and assert complete source ordinals and live prepared values. |
| datastruct internal tag layouts | Split-tree layout/navigation tags, circular-buffer iteration direction, and the flattened MessageData/BlockingQueue timeout union tags were inferred sub-byte enums in Ghostty but retained as default-width 32-bit V enums. | Use byte-backed declaration-order tags and verify every ordinal plus the pointer-width timeout payload and aggregate layout. |
| datastruct message and timeout unions | Ghostty's generic `MessageData` retains exactly one of `small`, `stable`, or allocator-owned storage, and `BlockingQueue.Timeout` retains one of two void arms or a nanosecond payload. Witty kept every payload side by side in ordinary structs behind the byte tags, so inactive arrays and timeout data survived every value. | Make both values V sum types with one struct per source arm, match directly on the active variant in queue waits and termio message selection, and keep `kind()` only as the compact tag projection used by tests and callback probes. |
| split-tree handle representation | Every split-tree node reference was widened from Ghostty's `u16` `Node.Handle` to a signed `int`; zoom and navigation used `-1` sentinels, the bounded `Handle.offset` operation was absent, and the GTK owner repeated those widened/sentinel contracts. | Restore one two-byte `Handle` with `idx`/bounded `offset`, optional zoom/navigation/close state, and carry the typed handle through every tree operation, iterator entry, spatial lookup, and GTK split widget. |
| split-tree numeric and view contracts | Ratios and normalized spatial coordinates widened Ghostty's `f16` to `f32`, changing actual layout geometry (the pinned mixed `0.8`/`0.3` tree produced a different diagram). Dimensions widened from `u16`, traversal counts narrowed from `usize`, `splitTreeLabel` became mandatory instead of optional, and `resizeInPlace` silently ignored a leaf rather than trapping. | Retain IEEE-754 binary16 bits and round after every source arithmetic operation despite V having no native `f16`; restore the integer widths, handle-label fallback, and resize invariant. Verify the exact pinned spatial diagram, compact layouts, tie-to-even patterns, and every non-NaN binary16 round trip. |
| recursive approximate comparison | `expect_approx_equal` recursed through direct floats, arrays, structs, and optionals, but its tagged-union branch handled only direct `f32`/`f64` payloads. A union carrying an array or struct with approximately equal floats therefore failed even though Ghostty recursively compares every active union payload. | Dispatch through the active V sum-type variant and call the same generic comparator on that payload, preserving tag mismatch failures while covering exact scalar/string payloads and nested array/struct float payloads. |
| deep union comparison | `deep_equal` used V's built-in equality for a sum type after checking for an `equal` method on the union itself. Ghostty instead recursively compares the active payload, so a payload struct's custom `equal` method was ignored. | Dispatch equal union tags into the canonical recursive comparison and directly cover a struct payload whose declared equality intentionally differs from field equality. |
| segmented-pool zero capacity | `SegmentedPool.init(0)` added an assertion absent from the generic source even though its non-growing operation has defined `OutOfValues` behavior and source-equivalent zero-length growth remains exhausted. | Accept zero preallocation and retain `OutOfValues` from both `get` and `getGrow`. |
| synthetic generator helper semantics | The translated byte generator omitted its formatting entry point, UTF-8 generation rejected source-valid zero-length requests/ranges, and OSC validity inverted the source comparison. The last form is ordinarily equivalent but selects invalid rather than valid when `p_valid` is `NaN`. | Restore the byte-format helper over V's owned-byte writer adaptation, allow zero-length UTF-8 output, and use Ghostty's exact `random > p_valid` validity branch together with its named helper structure. |
| terminfo package entry | The complete 268-capability source table was exposed as translation-specific `ghostty_terminfo` even though the source package contract is simply `ghostty`. | Restore the source declaration name and route build-data generation plus live XTGETTCAP responses through it; verify every capability's name, kind, value, and order against the pinned table. |
| terminfo capability value union | Ghostty's capability value is a four-arm union with two void arms, a `u32`, or a string. Witty retained the numeric and string payload together in every capability behind a manual tag, including all 268 entries in the generated table. | Make the value a four-variant sum type, construct variants directly in the table, match active payloads in source encoding and XTGETTCAP generation, and verify the compact source tag order plus the complete capability-kind counts. |
| Sentry envelope attachment surface | Attachment encoding existed only as a private `encode_attachment` implementation and the source's public `ObjectMapUnmanaged` declaration was absent, so callers could decode an attachment but could not use its source API to encode one directly. | Expose the translated ordered-header representation under the source type name and restore public `Attachment.encode`, including header preservation, required fields, optional-type insertion/removal, payload retention, and the existing in-place `Item.encode` path. |
| theme location iterator width | `LocationIterator` narrowed Ghostty's pointer-width `usize` search cursor to a signed `int`, even though the two-value location tag itself was already compact and the search/reset logic was complete. | Retain a `usize` cursor through iteration and convert only at V's array-index boundary; verify source location priority, reset, path diagnostics, and iterator layout. |
| benchmark execution semantics | Ghostty's wcwidth, lookup-table, and SIMD width steps and its uucode/table symbol steps are independent hot loops selected once through their benchmark vtables. Witty merged each group into a handwritten per-codepoint mode switch, measuring extra dispatch logic and dropping those source functions; decoder and setup invariants became returned errors or disappeared; `ScreenClone.setup` added file cleanup absent from the source; and the OSC benchmark treated partial EOF as malformed input instead of ending the step. | Restore all five complete step functions and select them directly in their vtables; retain the source decoder/setup assertions, fast ASCII table branch, and `ScreenClone` file lifetime; and preserve EndOfStream behavior for partial OSC length/payload reads. |
| systemd notification entry points | The translated `systemd.notify.ready` and `systemd.notify.reloading` implementations were complete but exposed only through source-external `systemd_notify_*` names, despite no collision in the merged OS module. | Restore public `ready` and `reloading`, route GTK startup and configuration-reload notification through them, and exercise both directly with no notification socket. The source's nested `notify` namespace is flattened by V's module model. |
| generic cache table | `datastruct/cache_table.zig` had been reduced to the shaper's identity-`u64`, 256-by-8 specialization, omitting the reusable key/value/context cache, configurable power-of-two bucket geometry, context equality, and optional eviction callback. | Restore generic `CacheTable[K, V, C]` and its `cache_table` factory, complete put/get/clear LRU behavior, and optional eviction callbacks; implement the existing shaper specialization as a thin instantiation of that translation. V stores the source's comptime bucket dimensions as immutable constructor fields because it has no integer-valued generic parameters. |
| blocking queue wait semantics | The blocking queue rejected Ghostty's valid zero-capacity specialization and replaced its not-full condition variable with one prefilled channel token per slot. Draining several entries therefore woke every waiting producer, while the source emits exactly one condition signal when the drain iterator is released. | Permit zero capacity, make the mutex-protected ring the fullness authority, and translate the `std.Thread.Condition` wait/timed-wait/signal operations used by the queue: each waiter parks on its own one-slot channel, a signal wakes at most one registered waiter and is lost when none is waiting, and a timed waiter already selected by a signal consumes it rather than timing out. This avoids both stale wake tokens and a send that could block while holding the queue lock. Retain the source's one-wait/no-retry push, map `u64` timeouts beyond V's signed duration to an unbounded wait, and cover lost signals, registered wakeups, zero capacity, and the two-producer drain boundary. |
| renderer mailbox queue | Ghostty's renderer mailbox is `BlockingQueue(renderer.Message, 64)`, but Witty kept a separate handwritten `RendererMailbox`: a dynamic array with front deletion, lazily created locks, an instant-only `push`, and a `push_wait` loop that retried where Ghostty waits once. Termio's source `.forever` pushes (resize and the stream handler's post-unlock retry) consequently became instant pushes that silently dropped the message when the queue was full. Surface pushes went through source-external `send_wait`/`queue_renderer_message` helpers that woke the renderer after every message (including inspector, configuration, and focus changes, where Ghostty does not notify) and, with no mailbox, discarded the message or dereferenced the old font grid itself; that per-message wakeup also masked the omission of `updateConfig`'s explicit post-send render notification. `Termio.init` fabricated a renderer state, lock, and mailbox when none were supplied, mailbox destruction deinitialized queued messages, and the stream handler dropped Ghostty's failed-notify warning. | Alias `renderer.Mailbox` to the translated `BlockingQueue[RendererMessage]`, with `Mailbox.create` supplying the fixed 64-entry capacity because V generics have no integer parameters. Push at every source site with its exact instant/forever timeout, notify the renderer only where Ghostty does (restoring the configuration-change notification and its warning), remove the helpers, fallbacks, and nil branches, restore the warning, and give test fixtures real mailboxes. The search test now verifies the renderer messages and their order. The documented pending-font-grid release at thread teardown is retained. |
| app mailbox and surface identity | Ghostty's `App` owns a bare `Mailbox.Queue`, and producers push through `App.Mailbox{rt_app, mailbox}.push(msg, timeout)`, which always wakes the runtime app. Witty merged both into a lazily created queue wrapper with source-external `try_push`/`push`/`push_timeout`, plus `request_new_window`, `request_open_config`, `request_present_surface`, and `pending_message_count` App helpers. Ghostty keys close, new-window parent, focus, and surface messages by the core `Surface`; Witty keyed them by its runtime wrapper, split the single `surface_message` into wrapper and core variants, and added a source-external `PresentSurfaceMsg` address message, so `focusCallback` needed a separate `focus_core_surface` lookup. The renderer's `SurfaceMailbox` also dropped the source timeout, turning its instant scrollbar push into a forever-blocking push. | Restore the six-variant message union in source order with one core-keyed surface message, and key close, focus, new-window, configuration update, and surface dispatch by the core `Surface` through `hasSurface`'s `core()` comparison. Store the queue on `App` and push through `Mailbox.push`, which wakes the runtime. GTK activate, new-window, open-config, and present-surface now push directly (present-surface forwards the unvalidated pointer for app-thread validation), and the new-window parameter type warning is restored. Renderer surface events carry the source instant/forever timeouts. Redraw requests are keyed by the core surface because Witty's renderer callback has no runtime-surface pointer, and the focused-surface field keeps its `last_focused_surface` name because V forbids a field sharing the `focused_surface` accessor's name. |
| surface renderer-state locking | Ghostty always takes the heap-allocated `renderer_state.mutex` around terminal access and unconditionally destroys it in `deinit`. Witty wrapped 40 surface critical sections, both embedded-bridge lock callbacks, and teardown in source-external `mutex != nil` branches so zero-initialized test surfaces could skip locking entirely, meaning a surface without its lock silently ran unsynchronized. | Lock, unlock, and destroy unconditionally at every site (keeping `mouseShiftCapture`'s explicit caller-selected lock), and give the test surface fixture a real mutex. |
| search thread terminal lock | Ghostty initializes the surface search thread with `renderer_state.mutex`, the lock that the IO thread and renderer hold while mutating the terminal. Witty gave each search a freshly created private mutex, so the search thread's feeds, match selection, and viewport scrolling read and wrote the live terminal without excluding concurrent terminal updates. `Thread.init` also rejected absent options with an invented error, and the surface callback ignored a null userdata pointer the source dereferences. | Pass the surface's shared renderer lock and terminal to the search thread (its callbacks already run outside that lock, as in Ghostty), drop the private lock and its teardown, remove the invented init validation and null-userdata branch, and restore the callback's thread-safety note. |
| surface child-exit handling | Message dispatch narrowed Ghostty's `u64` child runtime to `u32` before the abnormal-exit comparison, so a process that ran past 2^32 ms could wrap into the abnormal range and be reported as a failed launch. The handler also split the `ChildExited` value into two integers, continued writing its "Process exited" notice after a failed linefeed or print where Ghostty abandons the block, and both exit paths skipped terminal output when the terminal pointer was nil, a case the source does not have. | Pass the complete `ChildExited` value through dispatch, compare the retained `u64` runtime, emulate the source's labeled terminal block so a failed write stops the notice, and remove the nil-terminal branches. The handler keeps its `child_exited_handler` name because V forbids a method sharing the `child_exited` field's name. A regression test covers a runtime beyond 32 bits. |
| surface error reporting | Twenty-two `Surface` call sites silently discarded failures that Ghostty logs, covering app actions (bell, progress, secure input, mouse visibility, scrollbar, renderer health, key sequences, key tables, and soft reload), renderer and IO notifications, initial-size recomputation, link refresh, scroll-to-bottom, and per-clipboard writes. `updateRendererHealth` also omitted its unconditional status warning. `deactivateAllKeyTables` propagated a runtime failure that Ghostty logs, so configuration reload and key-table deactivation could fail where the source continues. `endKeySequence` cleared its sequence before notifying the runtime. `copySelectionToClipboards` replaced the exhaustive format switch and its non-empty assertion with overlapping conditions and a silent return, and deinit ignored the renderer re-entry that Ghostty treats as unreachable. | Restore each source warning or error message, the health status log, the logged key-table notification, notify-then-clear ordering, the exhaustive four-format switch with its assertion, and a panic for the unreachable renderer re-entry failure. Restore the `updateScrollbar` name. |
| surface key binding dispatch | `maybeHandleBinding` was split into a source-external `handle_binding_entry` and reduced to an optional result. That version performed `global:`/`all:` bindings only on the focused surface instead of through `App.performAllChainedAction` on every surface, and silently dropped failed actions that Ghostty logs. It checked closing and `ignore` actions in one loop, so a chained `ignore` before a closing action reported `.ignored` rather than `.closed`. It recorded the inspector binding before the actions ran and even for unconsumed events, and discarded one-shot key-table deactivation errors. `encodeKey` also left the inspector PTY copy to one caller, so leader keys never recorded it, and a `key_is_modifier` wrapper duplicated `Key.modifier()`. | Restore a single `maybe_handle_binding` in source order with an explicit error-and-optional result, app-wide dispatch of global/all bindings, logged action failures, separate closing-then-ignore scans, consumed-only inspector binding capture, propagated table deactivation, and the inspector PTY copy inside `encode_key`. Remove the wrapper. Tests cover all-surface dispatch and inspector capture. |
| home directory lookup | `homedir.home` returns Ghostty's fallible optional, but Witty returned only an optional. A passwd lookup failure was replaced with an empty entry that fell through to spawning `/bin/sh`, and a shell spawn failure became absence. On macOS, a missing NSFileManager path also fell through to passwd and the shell even though the source returns the NSFileManager result directly. The `homeUnix`/`homeWindows`/`trimSpace`/`expandHomeUnix` structure was folded into two functions with ad-hoc error strings, and the Windows configuration default dropped Ghostty's missing-shell warning. | Return an explicit error-and-optional `HomeResult`, restore the four source functions, the macOS early return, propagated passwd and spawn errors, and the source `HomeDetectionFailed`/`NoHomeDir` errors, and propagate lookup failures from XDG and configuration callers. Restore the Windows warning. |
| shell integration setup errors | `shell_integration.setup` and `setupBash` return Ghostty's fallible optional, and `Exec` propagates their errors so the subprocess launch fails. Witty flattened both to optionals, so a failure became a silent fallback to the unintegrated command. `Exec` also dropped Ghostty's diagnostics for disabled integration (which the source says it always logs), a missing resources directory, and an undetected shell. | Return explicit error-and-optional results from `setup` and `setup_bash`, propagate home lookup failures through them and `Subprocess.init`, and restore the three diagnostics. |
| surface initialization lifecycle | `Surface.init` never applied the app's conditional configuration state, so a surface created while the app was in dark mode started with the light-theme values until a later reload. A failure to build the default child environment aborted surface creation, where Ghostty logs it and falls back to the process environment. `GHOSTTY_LOG` leaked into every child process. The function had none of Ghostty's errdefer cleanup: after a mid-initialization failure the derived config, renderer, renderer lock, renderer and IO threads, and termio were never released. It instead set a source-external `initialized` flag that `deinit` and `SurfaceRef.deinit` checked to skip teardown, and the renderer and IO thread shutdown was conditional on the threads existing. | Apply the conditional state first (preserving the original working directory), restore the logged environment fallback and `GHOSTTY_LOG` removal, and create the renderer, lock, renderer thread, and IO thread in source order. Emulate each errdefer with a reached `defer` that runs only while initialization has not succeeded, and remove the `initialized` flag so teardown and thread shutdown are unconditional. A regression test creates a surface after the app switches to dark mode. |
| termio option ownership | Ghostty's Surface creates the `Exec` backend and SPSC mailbox, releases them via errdefer if `Termio.init` fails, and passes both through `termio.Options`. `Termio.init` reads scrollback and grapheme-cluster defaults from `full_config`. Witty's options replaced the backend and mailbox with a source-external `backend_config` that `Termio.init` used to construct both, and added `max_scrollback`/`grapheme_cluster` options with their own defaults plus a nil `full_config` branch. | Restore the source option set, construct and conditionally release the backend and mailbox in `Surface.init`, derive both terminal defaults from `full_config`, and give the termio test fixture a real configuration, backend, and mailbox. |
| process exit watcher shutdown race | libxev reports a child's exit only while the termio loop runs, and Ghostty's `threadExit` kills and reaps the child after that loop stops, so its `processExit` treats a watcher failure as unreachable. Witty's watcher is a separate thread blocked in `waitpid`. When a surface closed, `Subprocess.stop` could reap the killed child first, and the watcher's `ECHILD` hit the unreachable panic and aborted the application (seen intermittently in the embedded bridge test). | Treat `ECHILD`, which only shutdown's reaping can cause, as a watcher that never fires; keep every other wait failure unreachable. A deterministic test runs the watcher on an already-reaped child. |
| surface IO mutex state | Ghostty's `queueIo` takes the caller's `Termio.MutexState`, and twelve call sites that hold the renderer lock (alternate-scroll cursor keys, all five mouse reports, prompt-click reports and arrow moves, and selection-scroll start/stop) pass `.locked`. When the termio mailbox is full, `Mailbox.send` then releases the renderer lock while it waits for the writer thread, which may itself need that lock to drain. Witty dropped the parameter and always sent `.unlocked`, so a full mailbox during mouse reporting or scrolling could block forever while holding the lock the writer needed. A source-external `queue_write_request` helper also wrapped two write requests. | Restore the mutex-state parameter through `queue_io` and `TermIO`, pass `.locked` at exactly the twelve source sites (each verified to hold the lock) and `.unlocked` elsewhere, and inline the helper. |
| termio mailbox drain errors | Ghostty's termio `drainMailbox` is fallible. The first failing handler (writes, focus, resize reports, clearing, scrolling, configuration changes, color-scheme reports) aborts the drain before the renderer is woken, and `wakeupCallback` logs `error draining mailbox`. The coalesce callback logs a failed resize. Witty discarded every handler error and the renderer-notify error, continued draining after failures, and dropped the resize warning. The coalesce, synchronized-output reset, and selection-scroll intervals were inline literals rather than the source constants. | Make the drain fallible with the source's abort-before-redraw behavior, log drain and resize failures, and restore the `coalesce_min_ms`/`sync_reset_ms`/`selection_scroll_ms` constants. |
| renderer mailbox autorelease scope | On Darwin, Ghostty's renderer `drainMailbox` wraps every message handler in an Objective-C autorelease pool, because visibility, focus, configuration, display-ID, and font-grid handlers can create autoreleased objects on the renderer thread, which has no run-loop pool of its own. Witty drained without a pool, so those objects accumulated for the thread's lifetime. It also skipped the font-grid dereference when the grid-set pointer was nil, a case the source does not have. | Hold a macOS autorelease pool for the duration of each drain and dereference the old grid unconditionally. |
| subprocess kill sequence | Ghostty's `Subprocess.stop` delegates to `killCommand`/`killPid`/`getpgid`. `killPid` returns `KillFailed` when `killpg` fails (except the expected Darwin `EPERM`), and `stop` logs that the command may hang. For Flatpak commands it signals and then waits for exit. Witty inlined the POSIX path, ignored every `killpg` result (so a persistently failing kill could spin forever), dropped the pgid warnings and the source's `ESRCH` early return, and never waited for a signaled Flatpak command. | Restore the three source functions with the `KillFailed` error, Darwin `EPERM` exemption, pgid warnings, and `ESRCH` check, log kill and wait failures from `stop`, and wait for Flatpak commands after signaling. |
| subprocess process union | Ghostty's `Subprocess.process` is one optional union retaining either a native `Command` or Flatpak host command. Witty split it into a running boolean, optional native command, and independent Flatpak pointer, allowing contradictory live states and permitting a stopped subprocess with an existing PTY to start again. | Represent native and Flatpak processes as the two direct arms of one optional value, keep the Flatpak command GC-stable for asynchronous watching, dispatch watcher and shutdown behavior by active arm, clear that value on external exit, and restore the source's pre-start PTY/process assertion. |
| Kitty protocol tag layouts | Ten parser, command, transmission, animation, deletion, and composition tags plus the special-color tag were inferred sub-byte enums in Ghostty but retained as default-width 32-bit V enums. Kitty color also redeclared the shared OSC terminator instead of using the canonical source type. | Use byte-backed tags with complete source ordinals, byte-back the canonical OSC terminator, and alias that exact type at the Kitty color boundary. |
| OSC parser and color tags | Parser, semantic-action, iTerm2-key, color-operation, color-target, and Kitty-color tags were widened to 32 bits. `DynamicColor` was renumbered from Ghostty's canonical OSC values `10..19` to `0..9`, requiring a handwritten ten-way conversion, while the Kitty kind union tag was reversed and iTerm2 added a source-external `.unknown` member. | Restore byte-backed source ordinals, use the dynamic color value directly on the wire and for sequential advancement, restore palette-before-special tag order, and represent an unknown iTerm2 key as absence. |
| OSC generated/tag backing | Progress state, the 23-case command key, and Kitty text-sizing alignments relied on V's default width for Ghostty's explicit/generated C-enum contracts. The ConEmu tab-title union tag and V's writer-selection adaptation were also widened to four bytes. | Give C-facing values signed 32-bit backing, source-inferred/internal values byte backing, and exhaustively verify every ordinal. |
| renderer internal tags, image lifecycle, and blending | Coordinate/cursor/cell/overlay/shader and local selection tags were widened to default 32-bit enums. The six-arm image lifecycle union was flattened into a state enum plus always-live optional pending pixels, optional texture, and duplicate dimensions; `mark_for_replace` consequently accepted only the pending payload rather than the source image value. Both renderer backends also stored a duplicate alpha-blending enum with `.native` renamed `.none_`, requiring handwritten mapping at init and config updates. | Restore byte-backed source tag order and the complete cell key; represent pending, replace, ready, and all three unloading image arms directly through common code, Metal, OpenGL, background images, and tests; accept a pending image in replacement; and retain `configpkg.AlphaBlending` directly in both backends with no projection switches. |
| sprite helper enum layouts | Ghostty's inferred tags for sprite thickness, both alignment axes, and fractions require only two or five bits, but Witty stored each as a default-width 32-bit enum and consequently widened `Alignment` from two bytes to eight. | Use byte-backed V enums (the narrowest addressable translation of the inferred Zig tags), retain declaration order and behavior, and assert the one-byte tags and two-byte alignment layout. |
| sprite z2d tag layouts | The translated path-node, line-cap, and internal line-join tags from Ghostty's pinned z2d 0.10.0 dependency were stored as default-width 32-bit V enums instead of the dependency's inferred two-bit tags. | Use byte-backed V enums (the narrowest addressable representation), preserve the dependency declaration order, and assert all tag layouts and ordinals. |
| renderer cell shader layout | Ghostty stores its exact 32-byte shader `CellText` in the renderer cell collection. Witty widened its atlas selector, stored the two shader bits as separate booleans in a reordered logical struct, then allocated and rebuilt every cell through two handwritten backend projection types each frame. | Restore the source field order, byte-backed atlas values, and packed flag byte in `CellText`; use that one verified 32-byte layout for both Metal and OpenGL and remove both backend conversion types/functions. |
| renderer cell-background shader type | Ghostty's background-cell shader value is exactly `[4]u8`; Witty introduced a named four-field RGBA struct with the same incidental layout. | Use the source array representation directly throughout cell storage, construction, and GPU buffer uploads. |
| renderer background-image shader layout | Both source backends store the same compact `BgImage` shader value with a four-bit position, two-bit fit, and repeat bit. Witty stored those as default-width enums plus a boolean and duplicated an identical projection type/function in each backend. | Store the packed source byte directly beside opacity, verify the resulting eight-byte shader layout, upload it unchanged, and remove both backend projections. |
| renderer image shader layout | The Metal and OpenGL translations declared separate, structurally identical image-vertex types even though the selected source shader package exposes one `Image` type to generic rendering code. | Use one verified 40-byte image shader value for buffer creation, pipeline stride, and both backend attribute declarations. |
| renderer thread flags | Ghostty's cursor-blink, inspector, visibility, and focus state is a packed four-bit value; Witty expanded it into four ordinary booleans. | Restore the source bit order in a one-byte flag value and route mailbox, timer, draw, and QoS decisions through typed accessors. |
| renderer OpenGL uniform flags | Ghostty packs the four OpenGL shader booleans into bits 0–3 of one `u32`; Witty projected them as four independent bytes. GLSL reads the field as one `uint`, so all flags except bit-zero `cursor_wide` were encoded at the wrong bit positions. | Give the OpenGL projection its source `u32` `padding_extend`/`bools` fields and explicitly pack the four source bits, while retaining Metal's intentionally different byte layout. |
| terminal CSI erase modes | `terminal.v` duplicated both byte-backed CSI erase enums as unrelated default-width enums with declaration-order values, making `Terminal.erase_line`/`erase_display` consume a different type and giving `scroll_complete` the wrong raw value. | Use the canonical `csi.v` `u8` enums directly at the terminal API boundary, retain their exact source values, and remove both duplicate definitions. |
| root/Command | The translated process launcher was stranded in module `main` and exercised only by parallel tests, while the live termio backend independently rebuilt argv/envp and repeated cgroup clone, fork, descriptor, cwd, rlimit, pre-exec, and exec logic. Its empty environment incorrectly meant inheritance; fd setup omitted Ghostty's platform contract; child errors exited inside `Command`; and stopped children were misclassified as signal 127. | Move `Command` into an importable module and delegate the live PTY launch to it; preserve optional environment/PID and `ExecFailedInChild` contracts; restore target-specific fd setup and correct wait-status classification. |
| global logging defaults | Stderr logging was hardcoded on even for Ghostty's `.none` application runtime, and unified logging recognized macOS alone instead of all Darwin targets. | Select the stderr default from the same target rule as `apprt.Runtime.default()` and enable unified logging on macOS and iOS. |
| global state teardown | `GlobalState.deinit()` restored the process file-descriptor limit, but Ghostty retains the raised parent-process limit for its lifetime and restores it only in the forked child before exec. | Remove the source-external parent restoration; retain the translated `ResourceLimits.restore()` call in `Command.childPreExec()`. |
| os/uri authority boundary | The URI adaptation searched only for `/` after `scheme://`, so an authority followed directly by `?` or `#` absorbed that suffix during MAC repair and returned an empty `raw_path`, unlike Ghostty's path-slice boundary. | Terminate authority scanning at `/`, `?`, or `#` in both normal and MAC-recovery paths and preserve the complete suffix for `raw_path`. |
| CLI action help | Although the general help text told users to run `+<action> --help`, every translated action parser rejected `--help`/`-h`; `show-face` and `new-window` also swallowed parser errors that Ghostty explicitly propagates to its central action dispatcher. | Embed all 15 byte-for-byte generated action documentation entries, restore `ActionHelpRequested` propagation at each parser and at the two catching runners, and handle it centrally while retaining `new-window -e ... --help` as command input. |
| CLI action options | Simple actions independently hand-parsed flags, accepting source-invalid separated values (`--style Italic`, `--config-file path`), rejecting source-valid explicit booleans such as `--docs=false`, and rejecting repeated option assignments instead of applying them in order. The shared parser also could not address source identifiers translated with V's keyword suffix. | Route list-actions/colors/keybinds/fonts/themes, validate/edit/show-config, SSH-cache, crash-report, and boo option structs through the translated generic parser; retain argument-order help checks and map V's trailing keyword underscore back to the source CLI name. |
| CLI new-window parsing | The action manually recognized only `--class`, returned ad-hoc errors instead of source diagnostics, removed the action token before parsing (shifting CLI locations), and kept its command-tail state as a parser-visible field. | Route the action through the shared parser and translated `-e` hook, mark translated underscore fields as internal, filter diagnostics to the action-owned `class` field, and retain skipped action tokens in argv so diagnostic indexes match Ghostty. |
| CLI show-face config diagnostics | Config diagnostics were interpolated as V structs, exposing representation text instead of Ghostty's user-facing diagnostic format. | Render every retained config diagnostic through the translated `Diagnostic.format()` contract. |
| CLI show-face parsing | The action manually partitioned action and Config arguments, returned ad-hoc parser errors, treated empty option values differently, and could not reproduce Ghostty's two-pass diagnostic ownership filter. | Parse the full argv through both the shared action parser and Config, preserve the source `u21` bound with a translated field annotation, and filter each diagnostic stream by reflected action-field ownership and location. |
| CLI version metadata | The version action was embedded in the C dispatcher, printed the compiler executable path as the V version, reported the artifact (`exe`) as the application runtime, omitted the selected font and renderer backends, and discarded Git-derived version/commit data. | Restore a dedicated CLI version module and report the actual V compiler version plus the translated runtime, font, renderer, build-mode, release-channel, platform metadata, and the pinned source's generated `1.3.0-main+6c0e02d` version and TTY commit hyperlink. |
| CLI list TTY presentation | `list-colors` and `list-keybinds` parsed `--plain` but ignored it, always emitting the pipe-oriented serialization even on a TTY; the keybind path also discarded `--docs` rather than passing it to the source-equivalent formatter. | Restore TTY detection and both pretty renderers: color columns retain the source's column-major layout and truecolor swatches, while keybinds recursively flatten chords/tables, use the source comparator, align actions, and style modifiers, separators, tables, and action arguments. Preserve the plain path for pipes and `--plain`. |
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
| synthetic generator contracts | The common generator interface and every `Bytes`/`Utf8`/`Osc` length boundary were narrowed from `usize` to 32-bit `int`; `Bytes.max_len` and `Utf8.max_len` consequently stopped at `2^31-1`, and an absent byte alphabet was conflated with a present empty alphabet. The public predicate-based `Bytes.generateAlphabet` operation was omitted while OSC duplicated it with a handwritten kind switch. The owned-slice OSC adapter also returned oversized output where Ghostty's fixed writer reports `WriteFailed`. | Carry `usize` across the complete generator stack, restore the pointer-width maximum defaults and optional alphabet state, range-check only when materializing a V array, derive every OSC alphabet through the translated predicate helper, and enforce the source writer boundary before returning an OSC slice. |
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
| font/FreeType synthetic flags | FreeType faces stored Ghostty's packed italic/bold state as two independent booleans and manually copied the opposite flag in each synthetic-face constructor. | Retain the two declaration-order bits in one byte, copy the canonical packed value before enabling a style, and read the same value from the glyph embolden/skew paths. |
| font collection index | `Collection.Index` retained style and face index as an expanded struct and only reconstructed Ghostty's packed `u16` at selected cache boundaries. `TextRun` then widened that value plus its two `u16` positions to `u32`, forcing handwritten decode paths through every shaper and the renderer. | Retain the index in its exact two-byte style/index bit layout, carry the typed value unchanged through text runs and rendering, restore `u16` offsets/counts, and use the translated `special()` contract instead of raw sprite comparisons. |
| font config option packs | `FontSyntheticStyle` and `FreetypeLoadFlags` were retained as expanded booleans, then independently repacked for grid hashing and the C config API. The FreeType V declaration also swapped the source order of `monochrome` and `autohint`. | Store both values in one byte with the exact source field order and defaults, read the canonical bits throughout collection/rasterizer logic, and pass the same byte to hashing and C projection without reconstruction. |
| font shaping-break config | `FontShapingBreak` retained Ghostty's one-bit packed option as an ordinary boolean struct, while the font layer introduced a second handwritten `RunBreakConfig` projection solely to avoid a V module cycle. | Store the config in one byte with the source cursor bit/default, expose its canonical integer value to the C API, remove the duplicate font-side type, and pass the decoded bit across the cycle-free method boundary. |
| packed config feature sets | `ShellIntegrationFeatures`, `SplitPreserveZoom`, `BellFeatures`, `AppNotifications`, `ScrollToBottom`, and `NotifyOnCommandFinishAction` expanded 18 packed bits into ordinary booleans and rebuilt five of their integer values with handwritten C helpers. | Retain each feature set in one byte with its exact declaration-order bits and defaults, route parsers/formatters/runtime consumers through typed accessors, and export the canonical stored bytes directly. |
| renderer/Metal API contracts | Metal's native constants were represented as sequential V enums plus handwritten conversion switches; the GPU-family bridge used `3003` for Apple3 and omitted Ghostty's Apple10 32,768-pixel limit. The shared renderer health enum also relied on implicit layout and values. | Give the exposed Metal and health enums their source ABI widths and numeric values, pass native values directly instead of remapping them, and restore the Apple10/Apple3 maximum-texture-size checks with the source constants. |
| renderer/Metal option bitsets | `MTLResourceOptions` was flattened into separate byte fields on buffer/texture options and repacked by duplicate helpers, while `MTLTextureUsage` retained only two expanded booleans and was rebuilt at upload time. The IOSurface bridge hardcoded render-target usage instead of accepting the canonical value. | Retain both native option sets in their exact 64-bit `c_ulong` layouts, expose all source fields without discarding reserved bits, carry them unchanged through resource wrappers, and pass target usage through the native bridge. |
| Kitty placement identifiers | The internal/external tag and full `u32` placement ID were stored as independent fields instead of Ghostty's 33-bit packed key, so retained map keys did not have the source bit representation. | Store the tag in bit 0 and the ID in bits 1–32 of one canonical value, use that value for placement-key equality, and route every storage and Unicode-placeholder construction through the packed initializer. |
| Kitty animation background | The animation-frame `Y` parameter was decoded into four separate channel fields instead of retaining Ghostty's packed `u32` RGBA word. | Store the parsed word unchanged and expose its four declaration-order bytes through typed accessors. |
| build/GTK target detection | `src/build/gtk.zig` had no translated file, including its packed X11/Wayland result and non-fatal GTK `pkg-config` probe. | Add the missing V module, retain both flags in their declaration-order bits in one byte, and preserve substring detection plus the empty result on probe failure. |
| build metadata enums | `ReleaseChannel` reversed Ghostty's `tip, stable` declaration order and both it and `Artifact` used default-width V storage for source-inferred tags. | Restore the exact release-channel order, byte-back both build enums, and verify the selected tip/executable constants. |
| sprite/face | `render_glyph` hardcoded glyph `offset_x/offset_y` to 0. | Compute from canvas clip + padding (matches `Face.renderGlyph`). |
| sprite/braille | The Unicode braille byte was expanded into eight stored booleans; the final dot-width adjustment stopped debiting its remaining pixels, and every source geometry/codepoint invariant was omitted. | Retain the source byte as the canonical pattern with bit accessors, restore the final accounting, and enforce the same layout and U+2800–U+28FF preconditions. |
| sprite/branch | The five-bit branch-node specification was expanded into five stored booleans, both branch-node and fading-line centering used wrapping `u32` arithmetic where Ghostty uses saturating subtraction/addition, and the public range dispatcher silently ignored impossible codepoints instead of preserving the source invariant. | Retain branch nodes in one byte with the source declaration-order bits, decode them through typed accessors, restore `-|`/`+|` semantics through shared sprite arithmetic helpers, and trap the unreachable dispatch arm. |
| sprite quadrant masks | Ghostty's shared four-bit `Quads` value was expanded into four stored booleans, and the separate local packed value used by supplementary separated-block glyphs was flattened into four independent locals. Both affected live block/legacy glyph renderers, whose range dispatchers also ignored impossible codepoints. | Store the common quadrant mask in one byte with the exact `tl`/`tr`/`bl`/`br` bit order, use it for the supplementary codepoint bitcast too, route all consumers through bit accessors, and restore unreachable dispatch arms. |
| sprite legacy masks | The 10-bit smooth-mosaic vertices and two six-bit sextant values were expanded into independent booleans, while every entry of the 230-element octant table occupied eight booleans instead of Ghostty's packed byte. The sextant range assertion and octant bounds trap were replaced by masking/default fallback, and the remaining block/legacy range dispatchers silently accepted impossible codepoints. | Store smooth mosaics in `u16` and sextants/octants in `u8` with declaration-order accessors, verify all 44 mosaic patterns and all 230 octant masks against the pinned tables, restore the sextant assertion and direct octant indexing, and preserve every source `unreachable` dispatch arm. |
| sprite box-line masks | Ghostty's four two-bit line styles occupy one packed byte, but Witty retained four widened enums; its line intersection geometry also used wrapping additions for every source saturating `+|` operation. | Store `up`/`right`/`down`/`left` in their exact two-bit positions, verify all 116 construction masks against the pinned call sites, decode typed styles at the renderer boundary, and restore saturating geometry additions. |
| termio/termio | `resize` sent renderer `.font_grid` (should `.resize`); cursor reset sent `.focus` (should `.reset_cursor_blink`). | Correct message kinds (+ wired the two MessageKind variants). |
| termio thread diagnostics | The merged Termio/Thread/mailbox translation wrote source warnings and errors directly to stderr, omitted the input filename from open failures, and dropped the IO-thread start, shutdown, exit, abnormal-drain completion, and per-message debug boundaries. The stream handler's renderer-wakeup failure bypassed logging too. | Route each failure through the translated logger at Ghostty's warn/error level, preserve the failed input path and underlying error, and restore all source thread lifecycle and mailbox-message debug events. |
| termio message discriminants | The flattened `MessageKind`, nested size-report kind, and mutex-state enums used default 32-bit V storage; the message and size-report declaration orders also differed from their source unions/enums. | Restore byte backing and the exact source declaration values for all three translated discriminants. |
| termio derived config enums | The IO layer redeclared both `configpkg.ClipboardAccess` and `Config.OSCColorReportFormat`, converted into them case-by-case, and carried those parallel types through `StreamHandler`. | Store both canonical config values directly in derived IO state and the stream handler, removing the duplicate enums and conversions. |
| simd/stream | SIMD search/decode offsets and terminal bulk-stream lengths were narrowed to `u32`, creating artificial overflow boundaries that do not exist in Ghostty's `usize` contracts. | Restore `usize` through `simd.index_of`, VT/base64 decode results, and terminal stream consumption. |
| Unicode packed lookups | Each generated one-byte codepoint property was expanded into width/enum/bool fields, while the grapheme transition path omitted Ghostty's packed 13-bit key and four-bit value types and reconstructed their layout inline. `Properties.eql` was omitted too, and impossible values outside the source `u21` domain received handwritten defaults. | Retain generated property bytes directly with typed accessors/equality, restore byte-backed grapheme values and `u16`-backed keys with the exact state/gb1/gb2 bit order, use those canonical values for transition lookup/state updates, and enforce the source input domain. |
| CLI diagnostics | Diagnostic CLI indexes and file line numbers were narrowed from Ghostty's `usize` to V's 32-bit `int`, and its tag-keyed `containsLocation` operation was replaced by two CLI/file-only predicates. | Preserve pointer-width locations through both iterators and diagnostic cloning/formatting, and restore one canonical location-kind query including the `.none` tag. |
| CLI parser-state tags | The boo frame markup state and both comma-splitter states were direct inferred enums in Ghostty but retained as default-width V enums. | Store all three state-machine tags in one byte apiece and verify their complete declaration order. |
| CLI result and mode tags | Theme filtering, preview mode, and SSH-cache add results were source-inferred enums retained with V's default 32-bit storage. | Give all three tags byte backing and verify their complete source declaration order. |
| CLI action optional representation | The translated `cli.ghostty.Action` inserted a leading `.none` case to simulate Ghostty's optional global action, renumbering all fifteen real source tags and widening them to V's default enum storage. | Keep successful absence in an explicit result wrapper around an optional action, restore the exact fifteen-case byte-backed source enum, and remove the impossible branch from dispatch. |
| resource directories | `ResourcesDir.app()`/`host()` collapsed absence into an empty string, and live surface initialization passed the application-visible path to the child PTY instead of Ghostty's host-visible path. | Restore both optional accessors and pass `host()` unchanged into `termio.Exec`, preserving Flatpak host-path semantics while application resource consumers continue to use `app()`. |
| Flatpak child environment | The translated `internal_os.get_env_map()` always copied the sandbox environment, although Ghostty deliberately returns an empty environment map in Flatpak so the host command starts from its host environment. The runtime-neutral surface fallback bypassed the helper too. | Return an empty map under the canonical Flatpak predicate and route fallback surface environment construction through the same translated helper. |
| Flatpak passwd lookup | `get_passwd()` always returned the sandbox passwd record, whose home and shell are not the corresponding host values. | On Flatpak, retain the sandbox username only long enough to run Ghostty's `/bin/sh -l -c "getent passwd …"` host command over a PTY, then derive home and shell from the last two returned fields. |
| Linux package build flags and child environment | Witty had no importable `flatpak`/`snap` build options. Flatpak resource probing therefore ran in every sandbox regardless of how the binary was packaged, while Snap path filtering was absent. The GTK child environment also skipped the owning window-protocol hook and quick-terminal marker. | Add canonical `-d flatpak`/`-d snap` feature flags, gate Flatpak resource probing, translate `filterSnapPaths`, and complete `defaultTermioEnv` with `addSubprocessEnv` plus `GHOSTTY_QUICK_TERMINAL`. |
| generated terminal feature wiring | The translated build options did not synthesize `kitty_graphics` and `tmux_control_mode` from Oniguruma. APC always entered the Kitty parser and DCS always entered tmux control mode, including the reduced library configuration where Ghostty compiles both features out. | Make Oniguruma the single canonical feature selection (`-d no_oniguruma` models the reduced build), expose both synthesized terminal options, and gate Kitty APC plus tmux DCS at their protocol entry points. |
| system click interval | The Cocoa shim overloaded a valid zero-millisecond interval as its missing-class sentinel and its Darwin file selection also exposed the macOS-only implementation to iOS. | Return success separately from the `u32` value and select the AppKit implementation only for macOS, leaving every other target on Ghostty's absent-value branch. |
| Linux cgroup controls | Cgroup moves, controller configuration, and limits used a create-and-truncate file helper instead of Ghostty's existing-file, write-only opens; the tagged limit payload was fixed at `u64` instead of `usize`. | Share a write-all helper that opens only existing control files with `O_WRONLY`, preserve write errors and short writes, and carry pointer-width limit values behind a compact tag. |
| OS cgroup and Flatpak unions | Ghostty's cgroup `Limit` retains only the selected `usize` payload, and `FlatpakHostCommand.State` retains started-only event-loop/completion handles or exited-only status. Witty flattened both into structs, so inactive cgroup and process-state fields remained live, including the prior state's pointers after exit. | Make both values sum types with one struct per source arm, construct variants directly at every transition and limit call, match the active payload in cgroup writes and the synchronous/asynchronous wait paths, and retain the inferred Flatpak tag in one byte. |
| POSIX pipe setup | The `pipe2(.CLOEXEC)` adaptation ignored both `fcntl` results, so it could return descriptors without the mandatory close-on-exec flag and leaked both descriptors if setup needed to fail. | Propagate the platform errors from `pipe`/both `fcntl` calls, close the pair on either flag failure, and verify `FD_CLOEXEC` on both returned ends. |
| URL opener output | The detached URL-handler reaper drained stdout completely before reading stderr; a handler that filled its stderr pipe while keeping stdout open could deadlock both processes, unlike Ghostty's concurrent `collectOutput`. A first repair made the reads concurrent but still slurped unbounded streams and applied the 50 KiB limit only to logging after allocation. | Drain both redirected streams concurrently, retain at most Ghostty's 50 KiB plus the one byte needed to detect overflow, reject oversized output, then wait and close the child. |
| POSIX URL opener spawn | V's combined process-redirection API also piped stdin, while Ghostty redirects only stdout/stderr and inherits stdin. The unused parent write end could leave an opener that reads stdin blocked; launch failure also had no reliable exec boundary. | Spawn the POSIX opener with source-shaped stdout/stderr and close-on-exec error pipes, leave descriptor 0 inherited, report fork/dup/exec failures synchronously, and hand the resulting PID/output descriptors back to the existing concurrent collector. Direct tests feed inherited stdin, exercise the 128 KiB dual-stream case, and verify a missing executable is reaped and reported. Windows remains part of the separately recorded unsupported target gate. |
| macOS process arguments | The shared argument iterator always copied libc-backed `os.args`, although Ghostty deliberately reads `NSProcessInfo.arguments` because `argc`/`argv` may no longer be valid under `NSApplicationMain`; its source `usize` position was also narrowed to `int`. | Select a Cocoa argument snapshot on macOS, retain the ordinary process arguments elsewhere, and preserve a pointer-width iterator position. |
| macOS desktop launch detection | The executable artifact honored `GHOSTTY_MAC_LAUNCH_SOURCE=app`, although Ghostty reserves that override for library artifacts and otherwise identifies Finder/`open` launches from parent PID 1. | Keep the pinned executable build on the parent-PID branch and ignore the library-only launch marker. |
| global logging flags | Ghostty retains its stderr/macOS logging switches in a packed two-bit value, while Witty used a two-byte boolean struct whose generic parser depended on the widened physical fields. | Store logging state in one byte with the source target-dependent defaults and translate the packed boolean parser at this boundary, preserving whole-value and individual-field forms. |
| file-limit result contract | `fix_max_files()` exposed a fallible result even though Ghostty intentionally logs and converts a `getrlimit` failure to optional absence. | Return only the previous limit or absence, preserving the best-effort public contract and eliminating a source-nonexistent error path. |
| terminal RGB layout | Ghostty's internal packed 24-bit RGB value explicitly occupies four bytes, while Witty's ordinary three-channel struct occupied only three; the separate C projection is intentionally three bytes in both trees. | Give the internal RGB value four-byte alignment and assert both the four-byte internal and three-byte C-facing layouts. |
| PTY mode layout | Ghostty stores the shared canonical/echo mode as a packed two-bit value, while Witty expanded it to an ordinary two-byte boolean struct. | Store both flags in one byte (V's narrowest available backing), retain the source defaults, and expose typed accessors to the termios polling path. |
| termio thread flags | The writer thread flattened Ghostty's packed drain, linefeed-mode, and inspector flags into independent fields on the thread object. | Restore a dedicated one-byte flag value with the source bit order and route startup, mailbox, and write handling through it. |
| temporary-directory selection | `TempDir.init()` independently used V's `os.temp_dir()`, which ignores `TMPDIR` on macOS and has different Windows fallbacks, instead of Ghostty's shared `allocTmpDir()` policy. | Route `TempDir.init()` through the translated `alloc_tmp_dir()` helper and retain the source current-directory fallback when it returns absent. |
| tmux viewer protocol state | Notifications for entering tmux control mode were converted from Ghostty's `unreachable` invariant into a graceful defunct transition in all three post-entry states; the four-state enum also used default-width storage. | Make an impossible repeated enter fail immediately in each source state and store the translated state tag in one byte. |
| crash report iteration | `ReportIterator.next()` silently skipped metadata errors and returned the same optional absence as a clean end of iteration; its three-case crash-thread tag also used default-width storage. | Preserve Ghostty's fallible optional result with an explicit V wrapper, propagate the native metadata error, skip only confirmed non-files, and use byte-backed thread-kind values. |
| standalone internal tags | Crash-envelope item type, detected file type, theme search location, and tripwire reset mode were source-inferred enums retained with V's default 32-bit storage. | Give all four values byte backing and verify their complete source declaration order. |
| OS URL/desktop tags | The desktop-environment tag used default 32-bit storage. The OS URL opener also redeclared the C-backed application URL kind as an unrelated enum, forcing core and GTK to maintain handwritten three-way projection switches absent from Ghostty. | Byte-back the inferred desktop tag, retain one cycle-free signed 32-bit URL kind aliased at the application boundary, and pass it unchanged through both live opener paths. |
| inspector key-navigation tag | The inspector removed Ghostty's middle `.none` navigation case in favor of optional absence, widening the tag and renumbering `.up` from 2 to 1. | Restore the exact byte-backed `down, none, up` state and source-style no-action dispatch, and verify all three ordinals. |
| inspector display units | The standalone `inspector/units.zig` translation was missing and each screen/page-list widget open-coded its KiB division. | Restore `to_kibi_bytes(usize)` in its own module file and route every inspector memory display through that translated source function. |
| font glyph source identity | `font/Glyph.zig` existed only as a differently named `GlyphInfo` record buried in `font.v`, with its atlas coordinates moved before the source's dimensions and bearings. | Restore the standalone `font/glyph.v`, the source `Glyph` name and exact six-field order, route every face/resolver/render result through it, and verify every field offset. |
| tmux parser/output contracts | The control parser state and 32-case output-variable tag used V's default 32-bit storage. Integer parsing hardcoded 64 bits instead of Ghostty's platform-width `usize`, and output retained an unused enum pretending to translate the source error set. | Byte-back both inferred tags, derive parsing width from `sizeof(usize)`, verify every ordinal and the numeric boundary, and remove the dead error-enum stand-in while retaining actual V error results. |
| root/terminal C enum backing | Build metadata mode and OSC command-data tags relied on V's implicit enum representation despite both being explicit Ghostty `enum(c_int)` ABI values. | Give both tags signed 32-bit backing and verify their complete numeric order together with the existing C result contract. |
| platform configuration enum layouts | Twelve macOS/GTK/Linux option enums used V's default 32-bit storage instead of compact inferred source tags, while non-native fullscreen and GTK titlebar style only accidentally matched their explicit `c_int` contracts. `GtkSingleInstance` was also reordered from source `false, true, detect` to `detect, false, true`. | Restore byte backing for inferred options, signed 32-bit backing for both C-facing values, the exact single-instance order, and exhaustive ordinal checks for the complete cluster. |
| configuration value/union tag layouts | Terminal color, padding color, colorspace, alpha blending, background blur/image, readable-input, and font-style tags used default 32-bit storage. The flattened blur tag moved `radius` ahead of both macOS glass arms, and background-image position inserted `center` at ordinal 4 instead of the source-final ordinal 9. | Byte-back all nine inferred tags, restore both exact source declaration orders, and exhaustively verify their ordinals and compact flattened color/blur aggregates. |
| general configuration enum contracts | Twenty behavior/window/runtime tags used V's default 32-bit enum storage, three explicit C enums lacked signed `c_int` backing, and shell integration, link previews, clipboard access, close confirmation, and Shift-capture had source-incompatible declaration orders. Config also redeclared terminal cursor style in a different order and projected it manually, while root and config each redeclared the build release channel. | Restore every source ordinal and compact/C backing, use `terminal.CursorStyle` directly through termio, retain one cycle-free build release-channel declaration shared by root and config, and exhaustively verify the complete tag sets including Zig 0.15.2's 40-target OS enum. |
| configuration local/quick-terminal tags and replay union | Command-argument and replay discriminants, optional-file action, the quick-terminal size union tag, and all five quick-terminal option enums used default 32-bit storage. Replay steps were also flattened into a kind plus always-live argument, diagnostic, and conditional fields. The quick-terminal C projection represented Ghostty's explicit `enum(c_int) { none, percentage, pixels }` as untyped integer literals. | Byte-back all nine inferred source tags, introduce the exact signed typed C discriminator, and exhaustively verify every ordinal while retaining the source's separate internal and external size tags. Represent replay arguments, expansion bases, conditional arguments, diagnostics, and the command marker as direct arms through cloning, theme loading, iteration, and tests. |
| OpenGL render-attachment target union | Ghostty's render-pass attachment retains either a texture or framebuffer target inside its `target` union. Witty stored both payloads beside a manual kind, leaving an inactive GPU object live on every attachment. | Represent the nested target as a direct `GLTexture | GLTarget` sum type, construct only the selected arm in the renderer, and match that arm when binding the render-pass framebuffer. |
| font collection/metrics tags | Collection size/presentation and face constraint tags used default 32-bit storage. The generated `Metrics.Key` translation omitted its final four source fields and hashing manually enumerated only the shortened list instead of inheriting source declaration order. | Byte-back all six inferred tags, restore the complete 17-case metrics key, iterate its values through compile-time reflection during hashing, and exhaustively verify the source ordinals. |
| font-style configuration handoff | The font layer redeclared Config's flattened `FontStyle` union as `GridSetFontStyleConfig`, added an extra helper, and both core surface and show-face paths maintained handwritten tag-by-tag conversion switches. | Retain one cycle-free `FontStyle` value shared by config and font derived state, clone it directly at both source handoff sites, and remove the duplicate type, helper, and projections. |
| font-style configuration union | Ghostty's `FontStyle` is a tagged union whose `default` and `false` arms are void and whose `name` arm alone owns a string. Witty retained one struct containing both a tag and an always-live name string. | Represent the three source arms as a sum type, keep default-valued config and derived fields explicitly on the `default` arm, and match the active value for parsing, cloning, formatting, name lookup, and enabled-style checks. |
| GTK quit-timer union | The GTK application's `quit_timer` is a source union whose `active` arm alone owns the GLib source id. Witty split it into a state enum and an always-live source field, then manually cleared the inactive payload. | Represent `off`, `active(source)`, and `expired` as direct variants; match the active source when canceling and transition by replacing the complete value. |
| GTK window-protocol unions | Ghostty's application and window protocol state are unions that retain exactly one of the no-op, Wayland, or X11 backends. Witty stored a protocol tag beside all three backend states and dispatched through the tag, leaving two complete inactive backends live in every value. | Represent both protocol values as sum types of the three backend states, construct the selected backend directly, and narrow the active value for every lifecycle, modifier, quick-terminal, decoration, environment, resize, appearance, and urgency operation. |
| GTK tab-selection union | Ghostty's tab-selection value has three payload-free navigation arms and one `usize` numeric arm; Witty flattened it into a tag plus an always-live numeric payload. | Represent all four arms directly, retain the numeric value only for `.n`, and route action dispatch plus horizontal-scroll navigation through the tagged value. |
| GTK command-palette data union | Ghostty's command wrapper retains either regular-command data or jump-command data. Witty flattened both payloads into every command behind a separate kind enum, so inactive command, cached-string, weak-reference, pointer, and sort-key fields remained live. | Represent regular and jump payloads as variants of one `CommandData` sum type, construct only the selected payload, and narrow it for properties, accessors, disposal, activation, and sorting. |
| terminal-color configuration union | Ghostty's `TerminalColor` has one RGB-carrying arm and two payload-free cell-relative arms. Witty kept an RGB value live beside a separate tag for all three cases, allowing inactive color data to be observed by consumers that accessed the field directly. | Represent the three source arms as a sum type, construct only the active arm, and narrow it for parsing, formatting, terminal conversion, renderer color resolution, and shader-uniform extraction. |
| bold-color configuration union | Ghostty's `BoldColor` retains either an explicit RGB value or the payload-free `bright` arm. Witty represented it as a boolean plus an always-live RGB in both Config and its terminal cycle-boundary copy, then projected both fields unconditionally. | Represent both values as two-arm sum types, construct and format only the active config arm, narrow during the unavoidable config-to-terminal handoff, and match the active terminal arm during default, palette, and RGB foreground resolution. |
| background-blur configuration union | Ghostty's `BackgroundBlur` has four payload-free arms and one byte-radius arm. Witty stored a radius byte beside a separate five-case tag, leaving inactive radius data representable for every non-radius value. | Represent all five source arms as variants, retain the byte only in `radius`, and match the active value for parsing, enabled-state checks, C sentinel conversion, formatting, defaults, and compatibility handling. |
| font discovery backend selection | Ghostty aliases `Discover` and its iterator directly to the build-selected native implementation, while Witty stored both implementations behind a new runtime enum, dispatched every operation through handwritten switches, and made the infallible native initializers fallible. | Select CoreText or Fontconfig with platform-specific V type aliases, use each native API directly, remove both wrapper structs and their runtime tag, and restore infallible initialization at every call site. |
| renderer shader-animation configuration | The renderer thread redeclared Config's C-backed shader-animation value in reverse order and projected all three cases through a handwritten switch. | Retain `configpkg.CustomShaderAnimation` directly in thread-derived state and copy the source value unchanged. |
| renderer render-pass contracts | OpenGL added an empty attachment arm ahead of Ghostty's `texture`/`target` union, a fallible no-argument constructor, guarded the source-invariant first attachment, and carried a duplicate per-step vertex-count fallback. Both GPU backends narrowed source `usize` draw counts, while OpenGL also narrowed pipeline stride. | Restore the exact two-arm byte-backed attachment order, infallible attachment construction and direct first-attachment invariant; remove the duplicate count fallback; retain pointer-width draw counts and OpenGL stride; and byte-back the pipeline step-function tag. |
| renderer GPU buffer contracts | Both backend wrappers narrowed Ghostty's pointer-width allocation length to `u32`. OpenGL split the source length into a current length plus capacity, silently swallowed every `sync` error, omitted `initFill`, and leaked a newly created buffer when later initialization failed. Metal added a separate one-value initializer and changed its retained initialization length whenever the native buffer grew. | Retain `usize` lengths, restore fallible OpenGL synchronization and error cleanup, propagate those failures through frame drawing, implement the source `initFill` contract for both backends, use it for image vertices, and preserve Metal's initialization-length semantics across native reallocations. |
| renderer GPU texture/target contracts | Both backends narrowed target and texture dimensions from source `usize` to `u32`; Metal also narrowed bytes-per-pixel and both renderer/frame modification counters. Its texture-region method added bounds, exact-data-size, and empty-region branches despite Ghostty's explicit no-check contract, while OpenGL made the source fallible upload silently return and leaked textures/samplers on partial initialization. Both APIs exposed a source-external `target_options` method. | Retain pointer-width resource dimensions, bytes-per-pixel, and modification counters; restore Metal's direct infallible region upload and OpenGL's fallible upload; clean up partially initialized OpenGL resources; and construct targets through each source-shaped `init_target` API. |
| renderer OpenGL constructor surface | OpenGL retained no-argument compatibility constructors for the API, frame, pipeline, and shader set, renamed the real constructors to `begin_for_target`/`init_with_sources`, and supplied source-nonexistent defaults for required draw and resource-option fields. | Remove unused compatibility entry points, restore the source constructor names and required renderer options, and mark source-required draw, step, target, sampler, texture, and shader-source values as required at V construction sites. |
| renderer Metal pipeline attachments | Ghostty's pipeline options accept every color attachment as a slice, but Witty flattened the value to one pixel format and one blending flag; its Objective-C shim consequently configured only attachment zero. | Restore the attachment record and slice through renderer options, shader construction, the V/C bridge, and the native descriptor loop, retaining the source default blend policy independently for each attachment. |
| renderer Metal vertex-format ABI | The translated native `MTLVertexFormat` exposed only 11 values from Ghostty's 54-case `enum(c_ulong)`, omitting formats handled by the source pipeline reflection function. | Restore all 54 numeric cases with unsigned-long-compatible backing and exhaustively verify their source declaration order and values, including Apple's gaps at 43 and 44. |
| synthetic OSC tags | The public 13-case valid-kind and two-case invalid-kind source enums used V's implicit 32-bit storage. | Give both inferred tags byte backing and exhaustively verify their source declaration order. |
| benchmark action and mode tags | The retained benchmark action and four implementation-mode source enums used V's implicit 32-bit storage. | Give all five inferred tags byte backing and exhaustively verify their source declaration order. |
| benchmark symbol implementations | The `is-symbol` benchmark accepted the source's `uucode` and `table` modes but sent both through the same generated lookup table, so it did not benchmark two implementations. | Translate the pinned `computeIsSymbol` predicate (the `Co` category plus eight selected Unicode blocks) as the uucode path, retain the generated three-stage table as the table path, and exhaustively prove they agree over V's complete `u21` domain. |
| benchmark control and implementation objects | The complete `Benchmark` type, callback vtable, lifecycle/error behavior, once/duration loop, timing result, and Darwin Instruments signpost interval were omitted; all seven implementation types and their `create`/`destroy`/`benchmark` plus setup/step/teardown boundaries had been flattened into direct C-entry-point work. The initial translation also represented `RunMode` as a tag plus an always-live duration payload and added source-external constructors. | Translate the reusable control layer and all seven implementation objects, preserve parsing/construction outside the measured interval, route every action through `Benchmark.run(.once)`, and directly cover both run modes plus failure cleanup. Represent `RunMode` as direct once/duration variants, retaining the duration payload only on its source arm; GC-backed allocation remains the V ownership adaptation. |
| benchmark and synthetic CLI argument unions | Both public `Args` unions gained a source-external already-tokenized slice arm; benchmark used that arm in place of Ghostty's payloadless process-argument arm. Synthetic's process path also passed the `+action` selector into option parsing rather than consuming it through the canonical CLI iterator. | Retain only the source `cli` and `string` variants in both modules, collect process arguments through the translated `ArgsIterator` (which removes action selectors), and keep the C adapters on the general-string arm. |
| IPC action union boundary | Ghostty's one-arm `apprt.ipc.Action` tagged union was erased into a direct alias of its `NewWindow` payload, so the public action value had no `new_window` boundary even though its C projection reconstructed that tag. | Retain `IpcAction` as a wrapper with exactly the source `new_window` arm and route CLI construction, GTK dispatch, C projection, and tests through the active payload. V cannot express the source's comptime-dependent `Value(key)` return type, so runtime dispatch retains the whole wrapper. |
| Valgrind runtime behavior | The renderer always used a 600 ms cursor blink interval because V has no built-in equivalent of `std.valgrind.runningOnValgrind()`. | Translate Zig 0.15.2's architecture-specific Valgrind client request into the native interop layer and retain Ghostty's fivefold (3,000 ms) interval whenever the runtime probe is nonzero. |
| Metal frame completion block | `draw_frame_metal` always waited for every command buffer, even when the caller requested an asynchronous frame, then ran the source completion body inline. | Translate the pinned zig-objc stack-block ABI, register it with `addCompletedHandler:`, capture the renderer/target like `Frame.zig`, register Metal's foreign callback thread with the V GC, and retain the source synchronous wait/direct-invoke path only when requested. |
| renderer swap-chain synchronization | The renderer advanced through its per-frame resources without Ghostty's swap-chain semaphore. Once Metal completion became asynchronous, the CPU could wrap around and mutate a frame state's buffers or target while the GPU still owned them; teardown likewise freed resources without waiting for in-flight frames. The health callback also returned before releasing a slot when health was unchanged. | Initialize each backend with one permit per frame state, acquire before mutating the selected frame, release unconditionally from frame completion, return the permit on pre-submit errors, drain every permit before teardown, and recreate the semaphore across OpenGL unrealize/realize. |
| Metal render resource typing | Render-pass attachments and draw-step uniforms, buffers, textures, and samplers were all raw pointers, allowing every resource kind in every position and replacing source optionals with null sentinels. Image state likewise split only OpenGL into a typed wrapper. The background-color Metal step also omitted the source's second `cells_bg` buffer entirely. | Restore the texture-or-target attachment sum type and optional typed resource slices, retain uploaded Metal images as `MetalTexture`, route all production/test passes through the wrappers, and restore the missing background-cell buffer binding. |
| GTK tag and action contracts | Six native GTK/GLib values, the app-defined close-dialog target, and the KDE decoration mode relied on V's implicit signed enum representation, while six retained internal/union tags were widened. The tab redeclared the canonical C-backed close-tab mode, and window callbacks passed through a source-external ten-case tag only to rebuild canonical input actions. | Give C values signed 32-bit and the protocol value `u32` backing, byte-back inferred tags, alias the apprt close-tab type, and pass `input.Action` directly through the window helper. |
| renderer Metal pixel-format ABI | The translated native `MTLPixelFormat` exposed only the six formats currently selected by the renderer instead of Ghostty's complete 139-case `enum(c_ulong)`, and its bytes-per-pixel helper omitted every other source-supported value. | Restore all 139 values in exact declaration order with unsigned-long-compatible backing, restore every source-supported byte-size group and panic branch, and exhaustively verify the ABI values. |
| renderer auxiliary Metal enums | The native GPU-family wrapper exposed only two of Ghostty's fifteen values, while index type, purgeable state, barrier scope, and render stage were omitted entirely from the translated Metal API surface. | Restore all five unsigned-/signed-long-compatible enums with their complete declaration order and raw values. |
| renderer Metal native records | The translated native API renamed `MTLClearColor`'s four fields and omitted Ghostty's viewport, region, origin, and size records. | Restore all five eight-byte-aligned value layouts with exact source field names, order, scalar widths, and aggregate sizes. |
| renderer Metal render-pass contracts | The pass constructor was fallible and rejected missing native objects despite Ghostty's direct infallible Objective-C dispatch; the step flattened its required nested draw record, silently skipped a missing encoder/pipeline, and bound null entries that source optional-resource loops skip. Completion also mutated the retained encoder to null. | Restore source-shaped options and draw records, add `Frame.render_pass`, construct directly, keep only the zero-instance early return, skip null optional resources, and end encoding without changing the wrapper. |
| renderer Metal constructor contracts | Ghostty's sampler, target, and texture options are all mandatory, but every translated field carried a default, so a call site could silently construct a resource with an invented pixel format, storage mode, or filter. The sampler, target, and pipeline constructors also pre-checked nil devices/libraries, empty function names, and zero dimensions, none of which the source does. | Mark all option fields required and pass explicit values at every call site; remove the source-external pre-checks, leaving the native allocation failures the source actually reports. |
| renderer Metal texture factories | The Metal image-texture factory took the six-case image pixel format instead of the source's three-case `ImageTextureFormat` and fell back to RGBA for the three layouts it cannot represent. `initAtlasTexture` was missing entirely: its layout was open-coded in the renderer's atlas sync from an image factory with the BGR rejection hoisted out, and the frame state built its initial 1x1 atlas textures the same way with an invented zero-byte upload. The general texture/sampler option factories were also renamed for custom shaders. | Use the three-case enum (shared by both backends in V's single module namespace) with a per-backend pixel-format conversion, restore `atlas_texture_options`/`init_atlas_texture` and route the frame state and atlas sync through them, and restore the source factory names. |
| renderer Metal API entry points | Five graphics-API methods the renderer calls on every backend were missing from Metal, so the renderer reached past the API and open-coded them. Most consequentially, nothing ever created the per-frame `NSAutoreleasePool` that the source brackets every `drawFrame` with, so autoreleased Objective-C objects accumulated for the lifetime of the renderer thread. | Add `draw_frame_start`/`draw_frame_end` backed by a new `macos.AutoreleasePool`, plus `loop_enter`, `init_shaders`, and the no-op `present_last_target` that marks the skipped-redraw path, and route the renderer through all five. |
| renderer Metal drawable path | The Metal backend renders into an IOSurface-backed target and never acquires a `CAMetalDrawable`, but an earlier drawable-based presentation path survived beside it: `next_drawable`, `create_command_buffer`, and `present_and_commit` on the API, their Objective-C wrappers, and the single-attachment render-pass descriptor builder the multi-attachment one replaced. None had a caller; none exists in the source. | Remove the entire path, along with the load/store action constants it was the last user of. |
| renderer buffer array-list sync | Both backends' buffer wrappers omitted `syncFromArrayLists`, which copies a set of per-row lists straight into the mapped GPU buffer and returns the item count. The renderer instead summed the row lengths, allocated a flat array, and copied every foreground text cell into it on every frame, in both draw paths. Metal's buffer options also carried defaults (the source requires them) and its constructors pre-checked a nil device. | Add the method to both buffer wrappers, call it directly on `cells.fg_rows.lists` from both draw paths and take the draw instance count from its result, and restore Metal's required options without the source-external pre-checks. OpenGL's options do default in the source and were left alone. |
| renderer Metal buffer growth | Witty deliberately replaced Ghostty's `req_bytes * 2 * @sizeOf(T)` growth expression with `req_bytes * 2`, avoiding the source's second element-size multiplication and therefore changing the retained native allocation size. | Preserve the pinned expression in both typed `sync` and `syncFromArrayLists`; direct `u32` tests verify that an eight-byte requirement grows to 64 bytes exactly as the source does. |
| renderer Metal layer wrapper | The translated `IOSurfaceLayer` wrapper was never used: the API kept the layer as a bare handle and called the four Objective-C layer functions directly, so the wrapper existed only as a type one test constructed. `present` also pre-checked a nil layer, which the source has no need for because its layer always exists. | Make `MetalAPI.layer` the wrapper (absent for the off-screen API), route init/deinit/`loop_enter`/`present`/`surface_size` through it, replace the `owns_layer` flag and the nil pre-check with the optional, and stop the wrapper's methods mutating their receiver. |
| renderer Metal postprocess shader reporting | A custom shader that loaded but failed to compile was discarded silently; the source logs a warning before falling back to no postprocess shaders, so a broken shader gave the user no diagnostic at all. The shader set also pre-checked a nil device. | Restore the warning on postprocess initialization failure and remove the source-external pre-check. |
| renderer frame health vs presentation | Both backends folded a failed present into the frame's health: OpenGL silently set `healthy = false`, Metal propagated the error out of `draw_frame`. The source presents only if the rendered health is good, logs a presentation failure, and reports the rendered health unchanged, so a frame that rendered correctly but could not reach the compositor was being fed to the renderer's health tracking and surface notifications as a failure. Metal also reported health before presenting, inverting the source order, and OpenGL's `complete()` had dropped the `sync` parameter both backends' frames take. | Report the rendered health, log presentation failures without changing it, restore the source ordering, and restore the `sync` parameter. |
| lib_vt type exports | `lib_vt.zig` re-exports `terminal.MouseShape` alongside the other VT types; the translation had all 49 other aliases but not that one. `lib_vt_test.v` already asserted the export existed, but the file did not compile, so the assertion had never run. | Add the alias, and fix the unrelated compile error in `main_c_test.v` (a quick-terminal-size tag compared against an int literal) that kept that file from running too. |
| production build | Three declarations were warnings in a debug build but errors under `-prod`, so the release binary could not be built at all: a keybind-table map read that V requires an or-block for, and two optional thread handles with a redundant explicit `none` default. | Fix all three; `v -prod` now builds. |
| datastruct/SplitTree generic | `SplitTree.new` never compiled. Its array literal built the node list as `[Node[T](Leaf[T]{...})]`, which V rejects on instantiation ("invalid array element: expected `Node[View]`, not `Node[T]`"). Nothing on macOS instantiates `SplitTree` -- only the Linux-only GTK widget code does -- so the project still built and the defect stayed hidden, while `split_tree_test.v` reported "compilation failed" with no diagnostic because instantiating this generic inside its own module segfaults the V compiler. | Build the list and push the leaf. Convert the test to an external test, which avoids the compiler crash and runs its 18 tests / 245 assertions for the first time; the two that called the private `previous`/`next_node` now go through `goto_` with `GotoPrevious`/`GotoNext`, which dispatches straight to them, rather than widening visibility the source also keeps private. |
| GTK activate test | `test_application_activate_queues_new_window` called `application_activate_cb`, which is not declared anywhere. The GTK apprt is Linux-only and none of it compiles on macOS, so nothing had ever type-checked the file. | Call the `activate` method the real callback wraps; the callback itself resolves its wrapper from a GObject instance and chains to the parent vfunc, so it cannot take the plain `Application` struct the test builds. |
| GTK drag and drop | Dropping files or text onto the terminal did nothing. The source sets a `GtkDropTarget` accepting `GdkFileList`, `GFile` and string, whose handler shell-escapes dropped paths and pastes them, or pastes dropped text directly. The port had neither the controller nor the handler, only a comment listing `drop_target` among the template children it had not built. | Add the controller with the same accepted types in the same order and translate the handler through the existing `ShellEscapeWriter`, factoring the paste into `clipboard_paste` as the source's `Clipboard.paste`. The single-`GFile` arm builds its string and returns without pasting, as the source does. |
| terminfo module | Verified end to end: the emitted entry compiles with `tic -x` and round-trips through `infocmp`. `src/terminfo` had no counterpart. It defines Ghostty's terminfo entry as structured data and encodes it to terminfo source format, feeding both the build's terminfo install and XTGETTCAP. XTGETTCAP worked, but from a separately hand-transcribed copy of the same data in `stream_handler.v` -- two copies free to drift. | Translate `Source` and the 268-capability entry with both of the source's tests. Checking the transcribed table against it showed all 271 responses matched exactly, so the table is removed and the handler reads the generated map as the source does. That drops the transcription's case-insensitive hex decoding, which answered lower-case requests the source ignores. |
| editor support files | `src/extra` generates the editor and shell support files for the config format from Config's fields; none of it had a counterpart. | Translate the vim (syntax, ftdetect, ftplugin, compiler) and sublime generators, carrying the file bodies over verbatim and generating the keyword lists from `configpkg.config_keys`. |
| build data command | `src/main_build_data.zig` is the command the build runs to produce the generated artifacts. Nothing in the translation emitted the terminfo, editor-support, or shell-completion files, so they existed only as disconnected pieces or were missing entirely; its inferred action tag was later left at V's 32-bit default. | Translate the complete nine-action dispatcher as plain functions at the repository root, following `helpgen.v`; embed the three pinned compile-time shell-completion constants; retain the compact declaration-order action tag; and verify every emitted artifact byte-for-byte against the pinned Ghostty executable by SHA-256. |
| dead capacity stubs | `Screen.increase_capacity` and `Screen.split_for_capacity` were empty no-ops with no callers; the real implementation is `PageList.increase_capacity`, which is fully translated and has fourteen tests. | Remove both. |
| GTK progress bar fraction | The source converts an OSC progress percentage through `computeFraction`, which clamps to 0..100 before dividing and is tested to map 255 to 1.0. The translation inlined `progress / 100.0` at all three call sites without the clamp. Both OSC parsers clamp what they parse, so this is the source's second line of defence rather than a reachable bug, but a `ProgressReport` is an ordinary value nothing stops from holding 250. | Restore the function, its clamp, and the test. |
| crash thread state | `crash_test.v` died with SIGSEGV on the first write to the per-thread crash state, before producing any output. tcc, V's default C backend for debug and test builds, miscompiles `_Thread_local` on macOS arm64: it emits a direct `TPIDR_EL0` plus static offset access, but Darwin resolves thread locals dynamically. Correct under clang, so `-prod` was unaffected and it only ever showed up in testing. | Hold the state in a pthread key, which every supported toolchain implements correctly. This was the only thread local in the project. |
| renderer font grid handoff | A font grid handoff transfers ownership of the old grid's reference to the renderer thread, which must accept the new grid and dereference the old. The surface swaps to the new key as soon as it queues the message, so it derefs only the new key at teardown -- but the renderer loop breaks out of its wait on stop without draining, dropping any queued handoff along with the old grid's only remaining reference. `App.deinit` then asserted on a non-empty grid set, intermittently, depending on whether the thread got scheduled to drain first. | Release the font grid references still owned by undelivered mailbox messages before destroying the mailbox. |
| macOS argument iterator test | The source reads arguments from NSProcessInfo on macOS, documenting that libc argc/argv are not valid under `NSApplicationMain`, and the translation does the same. The test then asserted the iterator equalled `os.args`, which V fills from argv -- asserting the two sources agree, which is the thing the source deliberately does not rely on. It failed because NSProcessInfo reports the path as invoked (`/tmp/...`) where V records the resolved path (`/private/tmp/...`). | Assert the same argument count, the same executable name, and identical arguments after it. |
| documentation generators and help data | The two manpage generators and three website-reference generators under `src/build/mdgen`/`webgen` had no counterpart. Auditing them also showed that Witty's embedded configuration-help table was stale: 15 documented fields, including `theme`, `command`, `keybind`, and `term`, were absent, and the keybind generator retained final empty doc fields that Ghostty explicitly skips. | Translate all five generator outputs plus the two complete manpage entry points, embed the four byte-identical templates, regenerate all 181 public documented configuration records from the pinned HelpStrings output, and restore the final-empty-line rule. All nine complete/section outputs are byte-for-byte checked against the pinned Zig 0.15.2 generators by SHA-256. |
| renderer overlay z2d path | The overlay used a scratch inside-border rectangle loop instead of Ghostty's z2d path. It rounded color premultiplication and src-over arithmetic instead of truncating, moved the right/bottom border inward by one pixel, composited each corner only once instead of retaining the closed hairline path's shared endpoints, and did not collapse degenerate paths like z2d's polyline plotter. | Translate the exact z2d 0.10 direct rectangular fill, axis-aligned hairline, integer premultiplied src-over, and duplicate-point behavior used by `Overlay.zig`. Complete normal and degenerate RGBA goldens generated from the pinned z2d implementation verify fill bounds, boundary placement, corner overlap, path collapse, colors, and alpha. |
| OS URI parser surface | `os/uri.parse` was renamed to `parse_uri`, its options type was renamed, and its standard URI result was reduced to only scheme/host/path, erasing a repaired MAC address's port plus all query, fragment, user, and raw-path state. The pinned V `urllib` also mis-splits `/path??` as a path ending in `?` with an empty forced query, unlike Zig's `std.Uri`. | Restore `ParseOptions` and `parse`, return the complete standard URL value, retain repaired MAC ports, and normalize the path/query boundary to the source behavior. Route OSC 7 through the restored API and cover numeric/alphabetic MAC hosts, explicit ports, decoded paths, raw queries/fragments, and the source's slash-only invalid-port recovery boundary. |
| OS opener and i18n initialization surface | The URL opener replaced Ghostty's `OpenType` alias and `open(kind, url)` with a translation-only `open_kind` plus a one-argument convenience overload, so every live caller used the renamed boundary. The i18n `init` entry point was likewise renamed, and `os.dir` turned basename-only resource paths into `./locale` instead of returning Ghostty's `InvalidResourcesDir`; missing gettext could hide that error entirely. | Restore `OpenType`, `open`, and `init`, route core, GTK, and global startup through those contracts, and reproduce Zig's POSIX `dirname` behavior before attempting to load gettext. Direct tests pin the opener ABI values and basename, root, trailing-separator, relative, and absolute resource-path cases. |
| passwd lookup surface and Flatpak feature gate | The translated passwd `Entry` and `get` boundary were exposed only as `PasswdEntry`/`get_passwd`, lookup failures silently lost Ghostty's diagnostics, and every Linux build queried the Flatpak host whenever `/.flatpak-info` existed. The pinned source deliberately uses the sandbox entry and warns when Flatpak support was not compiled in. | Restore the source-shaped `Entry`/`get` boundary and route home, config, and macOS login-shell callers through it; preserve distinct `getpwuid_r`/missing-entry warnings; and query the host only in a `-d flatpak` build, with the source warning/info diagnostics on both branches. Native, ordinary Linux, and Flatpak-enabled Linux checks pass. |
| remaining Mach and C-SGR entry points | Tagged page mappings exposed their source `unmap` operation only as the translation-only `deinit`, while the public SGR projection/allocation helpers retained translation prefixes. The bodies existed, but the pinned callable names did not. | Restore `TaggedPageMemory.unmap`, `unknown_full`, `unknown_partial`, `attribute_tag`, `attribute_value`, `wasm_alloc_attribute`, and `wasm_free_attribute`, and route direct coverage through those entry points. The owned mapping value replaces the source allocator's aligned slice, and the safe V SGR value replaces its C-union payload pointer. |
| C OSC command tag entry point | The translated C OSC parser projected command data through the source-shaped `command_data`, but its companion public `commandType` query still carried the unnecessary `osc_` translation prefix. | Restore `command_type` and route valid, null, and Kitty-color command tests through it. Parser lifecycle names retain their prefixes because V merges the separate OSC and SGR C files into one module where `new`, `free`, `reset`, `next`, and `end` would collide. |
| SFNT fixed-point conversion methods | The three concrete products of Ghostty's `FixedPoint` type factory retained their math but exposed `to` as `to_f64` and `from` as three unrelated module functions. That lost the public API even though only the factory itself requires Zig comptime. | Restore `Fixed.from`/`to`, `F26Dot6.from`/`to`, and `F2Dot14.from`/`to`, route all OpenType consumers through them, and retain `f64` as the V specialization of the source's caller-selected floating type. |
| Adwaita capability helpers | The five non-conflicting `adw_version.zig` capability queries all carried an `adw_` translation prefix solely because the GTK and Adwaita version files share one V module. | Restore `supports_dialogs`, `supports_tab_overview`, `supports_switch_row`, `supports_toolbar_view`, and `supports_banner`; route every dialog/banner consumer through them and verify their exact version boundaries. The duplicated generic version-query names remain qualified because they genuinely collide in the merged module. |
| GTK unshifted-key helper | `key.zig`'s public `keyvalUnicodeUnshifted` algorithm was complete but buried as a private `SurfaceWidget` method, removing the reusable entry point and putting GDK keymap declarations in the wrong translated file. | Restore public `keyval_unicode_unshifted` beside the other key helpers, move its C declarations with it, and route the live Kitty keyboard event path through the free function. |
| GTK runtime-until helper | `gtk_version.zig`'s `runtimeUntil` was unnecessarily exposed as `gtk_runtime_until`; unlike the shared GTK/Adwaita at-least queries, this name has no collision in the merged V module. | Restore `runtime_until`, route GTK environment setup through it, and verify it remains the strict inverse of the same-version `gtk_runtime_at_least` check. |
| inspector raw-event helper surface | The translated inspector folded `VTHandler.vtRaw` into a void private recorder, losing the handled/continue result, kept `VTEvent.passFilter` private, and omitted the standalone `eventTable` renderer. | Restore `VTStream.vt_raw` with the source result on every ignored/recorded path, route the parallel parser through it, expose `VTEvent.pass_filter`, and translate the source's reverse-order read-only event table with the explicit V cimgui context. The V/GC specialization is infallible because it performs no fallible manual allocation. |
| Linux cgroup public surface | All eight `os/cgroup.zig` operations were fully translated but unnecessarily exposed as `cgroup_current`, `cgroup_create`, `cgroup_remove`, `cgroup_move_into`, `cgroup_controllers`, `cgroup_configure_controllers`, `cgroup_configure_limit`, and `cgroup_clone_into`. | Restore `current`, `create`, `remove`, `move_into`, `controllers`, `configure_controllers`, `configure_limit`, and `clone_into`, then route the GTK cgroup layer and command spawn path through the source-shaped functions. The current-path wrapper remains the V representation of a fallible optional result. |
| GTK cgroup duplicate API | After the source-shaped OS cgroup repair, the GTK layer still published seven pass-through `cgroup_*` functions and an unused three-value error enum absent from `apprt/gtk/cgroup.zig`; its own implementation and surface lifecycle called that duplicate API instead of `internal_os` as Ghostty does. The source's successful transient-scope log and non-fatal surface create/remove warnings were also commented out or printed directly to stderr. | Remove the source-external API and enum, route application and surface operations directly through the translated OS cgroup functions, and restore the source logging boundaries. The complete Linux target passes the checker. |
| XDG directory helper surface | `os/xdg.zig`'s translated `Options`, `config`, `cache`, and `state` retained unnecessary `Xdg`/`xdg_` prefixes even though their merged V module has no collisions; only `parse_terminal_exec` kept its source spelling. | Restore the source-shaped type and all three directory functions, and route theme, configuration, crash-report, SSH-cache, and direct-test consumers through them. V ownership makes the allocator parameter unnecessary. |
| editable configuration path | `config/edit.zig` still selected candidates through four older infallible helpers that swallowed XDG/Application Support lookup errors and invented `$HOME` fallback paths. Candidate inspection used `is_file`/`file_size`, silently treating every open/stat error as absence, and file creation used an existence check followed by truncating create rather than the source's atomic exclusive create. | Build candidates through the translated fallible `file_load` functions, propagate unexpected open/stat errors while retaining the non-empty/first-existing priority, remove the fallback API, and create with `O_CREAT|O_EXCL`, tolerating only `EEXIST`. The focused config suite and native/Linux target checks pass. |
| obsolete translation compatibility exports | After their canonical entry points had been restored, the tree still exposed unreferenced `hostname_is_*`, `is_at_least_macos_version`, `GlyphConstraint*`, `none_constraint`, `font.Grid`, and `LineIterator.new` names that have no declarations in the pinned source. | Remove those translation-only aliases and keep only the source-shaped entries. `font.CellSize` remains a documented module-cycle projection of `renderer.CellSize`, which `SharedGrid.cellSize` returns in Zig. Native/Linux checks pass; the affected CLI, OS, and font tests pass. |
| atlas Wasm optional-pointer test gate | The full-atlas failure assertion compared an optional region pointer directly with `none`. The pinned V compiler accepted the source but failed in generated assertion diagnostics by trying to dereference the optional pointer. | Preserve the same full-atlas contract through explicit optional branching and free an unexpected region before failing, avoiding only the compiler's broken optional-pointer assertion formatter. The complete macOS suite passes: 244 passed and 32 platform skips. |
| FreeBSD PTY binding and child diagnostic | The POSIX PTY bridge selected Linux's `<pty.h>` branch on FreeBSD and linked libutil only on Linux, despite the pinned source's explicit FreeBSD `<libutil.h>` selection. Failure to set the controlling terminal also omitted Ghostty's errno diagnostic. | Select and link FreeBSD libutil at the same source boundary, and restore the controlling-terminal error log before returning the existing translated failure. |
| file-limit diagnostics | `fix_max_files` had the source's best-effort optional result and binary-search behavior, but silently returned on `getrlimit` failure and omitted both normal debug decisions. | Restore Ghostty's query-failure warning plus its already-maximized and successfully-raised debug events without changing the optional contract. |
| process-locale diagnostics | Locale initialization performed Ghostty's environment, system-default, UTF-8 fallback, and Cocoa-preference state changes, but every success, fallback, conversion, buffer, and environment failure boundary was silent. | Restore the source info/warn/debug events for libc locale selection, Cocoa locale detection, preferred-language canonicalization, fixed-buffer exhaustion, and environment updates while preserving the existing fallback order. |
| gettext runtime completeness | The dynamic gettext adaptation accepted a candidate containing `dgettext` even if `bindtextdomain` or `textdomain` was absent, then silently returned success from the corresponding initializer. Domain binding also omitted Ghostty's debug event. | Accept only a runtime providing all three source-required functions, continue to the next candidate after closing an incomplete library, and restore the domain/path binding diagnostic. The dynamic lookup remains Witty's substitute for Ghostty's build-linked gettext. |
| systemd notification diagnostics | Systemd launch detection and notification failures bypassed Ghostty's scoped logger through direct stderr writes, and socket/connect/write/clock errors discarded the platform error value. | Restore source-level error/warning routing and include the translated OS error at every syscall boundary, while preserving detection and best-effort notification behavior. |
| macOS click-interval diagnostic | The translated Objective-C bridge preserved `clickInterval`'s optional result but silently returned absence when the `NSEvent` class lookup failed. | Restore Ghostty's missing-class error before returning `none`; the millisecond conversion and ordinary success path remain unchanged. |
| obsolete OS helper exports | The merged OS module exposed an unused `TempDir.create_file`, a test-only `shell_escape` convenience function, and public executable-path, cgroup-parser, and page-size extraction helpers with no counterparts in the pinned source API. | Delete the two unnecessary wrappers, exercise `ShellEscapeWriter` directly, and keep the three required platform/test extraction points private to the merged module. |
| LRU reused-entry result ordering | The LRU translation snapshotted the complete evicted key/value pair before reusing its entry and added tests for that friendlier behavior. Ghostty assigns the incoming key first and then copies the entry into `evicted`, so the observable result contains the incoming key paired with the evicted value. | Preserve the pinned statement order and update the direct eviction/recency tests to assert the source result instead of translation-invented semantics. |
| circular-buffer element access | `CircBuf.Iterator.next`, `first`, and `last` returned element copies instead of Ghostty's stable pointers, and Witty added a source-external indexed `get` method that the search sliding window used in place of the source iterator loops. | Return pointers into the shared backing storage, remove the invented accessor, and translate pruning, highlight construction, integrity checks, and direct tests through the source iterator boundary. |
| LRU custom contexts | The reusable LRU retained only its automatic built-in-key lookup and omitted `getOrPutContext` and `getContext`, so callers could not supply Ghostty's custom hash/equality contexts. | Restore both context-aware entry points over the same map and recency queue, invoke the supplied hash/equality contract, and cover equality, lookup, promotion, and eviction with a case-folding context. |
| segmented-pool counter overflow | The pool advanced its circular acquisition counter with ordinary increment even though Ghostty explicitly uses wrapping `usize` addition. A sufficiently long-lived pool could therefore overflow-trap instead of returning to index zero. | Translate the wrap explicitly because V has no wrapping-add operator, and cover the maximum-counter boundary directly. |
| shell-integration resource diagnostics | Bash, XDG-based shells, and zsh silently returned no integration when their source script/directory could not be opened. Ghostty warns with the attempted path and filesystem error at all three boundaries. | Restore the scoped warnings and use fallible file/stat operations so the available platform error is retained, without changing the source's environment rollback and mutation order. |
| shell-command builder ownership transfer | `ShellCommandBuilder.to_owned_slice` returned a joined copy while retaining every argument in the builder. Ghostty transfers its allocating writer's storage, leaving the builder empty and safe to deinitialize or reuse. | Make the translated operation consuming, clear its backing argument list after producing the command, and verify that a subsequent append starts a new command. |
| stream-handler failure diagnostics | `change_config`, SGR dispatch, and the mode-3 terminal resize all used empty V error handlers, silently discarding the exact failures Ghostty reports. Unknown SGR attributes were likewise ignored without the source warning. | Restore the warning/error branches at each source boundary while preserving their non-fatal behavior. The complete stream-handler test passes. |
| global startup diagnostics | Global initialization printed xev, crash, and i18n failures directly to stderr instead of Ghostty's logging boundary and omitted all startup metadata: version, optimization mode, runtime, font backend, HarfBuzz/Fontconfig versions, renderer, and selected xev backend. | Restore the warnings and startup reports using the translated build metadata, backend, and dependency APIs. The disabled-Sentry path retains Ghostty's warning wording if initialization ever becomes fallible. The global-state test and native/Linux checks pass. |
| GTK/Adwaita version checks | The version reporters printed hand-prefixed lines directly to stderr. More importantly, both `atLeast` translations consulted only the runtime library, so a newer linked library could report a feature available even when the headers used to compile Witty were older; Ghostty rejects that case before its runtime check. | Route both reports through the logger and restore the compile-header guard ahead of each runtime comparison. Direct Linux-only coverage pins the one-patch-newer-than-headers boundary, and the complete Linux target passes the checker. |
| special-sprite draw function names | All eleven functions in `font/sprite/draw/special.zig` acquired a source-external `draw_` prefix even though Ghostty deliberately names these functions exactly after the corresponding special-sprite cases. | Restore `underline`, its four variants, `strikethrough`, `overline`, and the four `cursor_*` names; route the sprite dispatcher and direct tests through those exact entry points. |
| lib-vt allocator convenience API | `lib/allocator/convenience.zig` was entirely absent, along with the ten Wasm symbols that `lib_vt.zig` exports for hosts to allocate and release typed ABI storage. | Translate `Opaque` plus all five allocation/free pairs, preserve nullable destruction, zero-length ownership tokens, element widths, and overflow failure, and add the exact `ghostty_wasm_alloc_*`/`ghostty_wasm_free_*` exports for wasm32. V's process allocator replaces Zig's selected default allocator. |
| lib-vt allocator interface | The allocator convenience exports existed after the earlier repair, but `lib/allocator.zig` itself was still absent: embedders had no `GhosttyAllocatorVtable`/`GhosttyAllocator` layout, custom allocator dispatch, default selection, or allocator round-trip. | Restore the four-callback vtable and two-pointer allocator ABI, custom/default allocation operations, and `from_zig`/`zig` round-trip with direct callback and layout coverage. V uses the same allocator value on both sides because its runtime does not expose a second replaceable language allocator; the vtable's `free` field is spelled `free_fn` in V because `free` is reserved for V's generated aggregate destructor, without changing field order or C layout. |
| lib-vt object allocator ownership | The C-facing key-event, key-encoder, OSC-parser, and SGR-parser translations constructed GC-owned values and their destructors only cleared state, so the newly restored custom allocator interface was never consumed by the objects whose pinned constructors accept it. | Add allocator-aware fallible constructors for all four opaque objects, retain the selected allocator alongside each value, and return their exact object allocation through the same vtable during destruction. Existing V convenience constructors remain thin GC-backed forms; direct callback-counting coverage verifies all four C-facing lifecycles use the supplied allocator. |
| native lib-vt C ABI and SGR projection | `lib_vt.zig`'s 38 native `ghostty_key_event_*`, `ghostty_key_encoder_*`, `ghostty_osc_*`, paste, color, and SGR exports were absent even though V-only wrappers existed. The SGR wrapper also omitted Ghostty's 72-byte tag-plus-union C value and the Wasm SGR helpers allocated the unrelated internal value. | Export every pinned native symbol, preserve borrowed key text, parser-owned OSC command pointers, fixed-buffer key encoding, and allocator-aware opaque lifecycles; route SGR parameter copies and replacement through the retained allocator; restore the exact 32-byte unknown payload, 64-byte union, and 72-byte SGR attribute layouts plus every payload projection; make the two Wasm helpers own the C attribute type. Focused tests invoke every API family, a native linked build succeeds, and its symbol table exactly matches all 38 pinned native exports. |
| Unicode three-stage LUT generator | Runtime property/symbol tables had been reproduced as a pinned binary, but `unicode/lut.zig` itself was absent, including its complete u21 generator, block/value interning, generic lookup object, and generated-Zig writer. | Translate the type factories as `LutGenerator[T, U]` and `LutTables[T]`, retain the full 0x200000-codepoint traversal, u16 overflow errors, 256-entry block deduplication, direct three-stage lookup, custom property formatting, and byte-complete writer behavior. V-managed arrays replace the explicit Zig allocator parameter. |
| faithful Page inspector widget | `inspector/widgets/page.zig` was absent; the live inspector contained only a separately written projection over the flat `Pages` screen model, even though Witty's faithful `Page` implementation is available to the translated `PageList`. | Translate `inspector`, `tree_node`, `managed_memory`, and all four private list/table helpers against `terminal.Page`, including logical contiguous-memory accounting, style/hyperlink reference tables, row flags, and the overlaid page-tree metadata header. The explicit cimgui context is the standard V binding adaptation. |
| surface mouse state-machine surface | The complete `surface_mouse.zig` state machine was translated and used by the live key callback, but both its root `SurfaceMouse` type and public `keyToMouseShape` function were private in the merged `core` module. | Expose `SurfaceMouse` and `key_to_mouse_shape` with the source fields, keeping the existing production call and complete direct state-transition tests on the canonical entry point. |
| sprite, Mach, and Kitty color helper entry points | The complete fraction conversion/coordinate helpers, rounded box-corner, and legacy-computing circle implementations were exposed only as `fraction_val`, `to_min`, `to_max`, `to_float`, `box_arc`, and `draw_circle`. Tagged page memory duplicated `realloc` inside `resize`/`remap`, and Kitty color OSC omitted its deliberately void C projection. | Restore `Fraction.fraction`/`min`/`max`/`float`, sprite `arc`/`circle`, `TaggedPageMemory.realloc`, and `ColorOSC.cval`; route production helpers and direct tests through them. Zig's comptime `Triangle(T)`/`Quad(T)` type factories remain concrete V structs because V cannot return a type from a function. |
| Atlas WebAssembly ownership API | The atlas implementation was complete, but none of its WebAssembly allocation, reservation, upload, growth, or clear entry points existed, leaving the already translated `config_*` exports as the only root Wasm API. | Restore `atlas_new`, `atlas_free`, `atlas_reserve`, `atlas_set`, `atlas_grow`, and `atlas_clear` in the font module, add exact root export symbols for wasm32, and exercise success, mutation, ownership, reserve failure, and grow failure directly. The browser-only debug-canvas export remains part of the WebAssembly platform divergence below. |
| WebCanvas Wasm face/shaper entry points | The translated face and shaper ownership helpers retained `wasm_` prefixes and were not exported from the root module; the face constructor accepted an already materialized string and widened point size, while `shaper_new` ignored its capacity argument entirely. | Restore the source `face_new`/`face_free`/`face_render_glyph`/`face_debug_canvas` and `shaper_new`/`shaper_free` spellings and signatures, add their exact wasm32 export symbols, and allocate the requested shaping-result capacity. Direct tests cover both nullable destructors and the retained capacity; the browser bridge and `shaper_test` remain documented below. |
| WebCanvas deferred-face Wasm API | Ghostty's WebAssembly module can allocate, free, and smoke-load a deferred browser face, but Witty exposed only the underlying `WebCanvasDeferredFace` methods and no host-callable boundary. | Restore `deferred_face_new`, `deferred_face_free`, and `deferred_face_load` with their source pointer/length, presentation, point-size, and void-result contracts, export all three for wasm32, and directly verify copied ownership and nullable destruction. |
| sprite Canvas atlas insertion and full-atlas retry | `Canvas.writeAtlas` was replaced by a dependency-free raster projection plus font-owned reserve/upload code, so the source operation was absent. That bridge also grew the atlas itself, while Ghostty propagates `AtlasFull` and lets `SharedGrid.renderGlyph` grow once and rerender. The translated shared-grid catch compared the wrong text (`atlas full` versus the actual `AtlasFull`), a latent failure hidden by the misplaced growth. | Move the four-field region value into the existing cycle-free sprite types module, restore generic `Canvas.write_atlas` with the exact trim/reserve/upload sequence, and route live sprite rendering through it. Propagate `AtlasFull`, fix the shared-grid retry discriminator, and directly cover trimmed upload, full propagation, and the shared-grid grow/rerender path. The generic parameter is the V adaptation that avoids a `font`/`sprite` import cycle; it is instantiated with `font.Atlas`. |
| benchmark data-file helper | `benchmark/options.zig` exports the common `dataFile` selector, but its translated optional-file wrapper and function were private even though all seven benchmark implementations consumed them. The wrapper also treated stdin as borrowed even though the source benchmark teardown closes every returned file handle. | Expose `DataFile`, `data_file`, `read`, and `close`; restore uniform close behavior for stdin and ordinary files; and directly verify absent input, stdin selection, ordinary file input, EOF-compatible reads, and close state. The wrapper is required because V cannot return an error union containing an optional `os.File`. |
| SIMD Base64 public surface | `simd/base64.zig`'s `maxLen` and `decode` functions were exposed only as translation-prefixed `base64_max_len` and `base64_decode`, even though the merged V module has no conflicting entry points. | Restore `max_len` and `decode`, route the Kitty graphics parser through them, and exercise the source-shaped calls directly. The implementation remains Ghostty's selected scalar fallback because Witty does not link the optional Highway C++ implementation. |
| libxev dependency | Ghostty's renderer, IO, search, and CoreText release threads run on libxev, but Witty did not translate libxev and emulated each loop by hand (semaphores with monotonic deadlines, a 1 ms polling loop, V channels with a timed `select`). | Translate libxev (pinned 34fa508) into the `xev` module: the kqueue, epoll, and io_uring backends (with Zig's `std.os.linux.IoUring` and the `std.posix` wrappers they call), the thread pool, intrusive queues and heap, the Async/Timer/Process/Stream watchers for each backend, the Darwin default API, and the Linux dynamic API, with the upstream tests on macOS and Linux. File/TCP/UDP and the WASI/IOCP backends are not translated because Ghostty does not use them. |
| renderer thread event loop | The renderer thread waited on a semaphore and polled timer deadlines instead of running Ghostty's xev loop with wakeup, stop, and draw-now asyncs and render, draw, and cursor timers. Losing focus never cancelled the cursor-blink timer, `reset_cursor_blink` restarted a separate deadline instead of resetting the timer completion, and the display link called into the thread object instead of notifying `draw_now`. | Port `renderer/Thread.zig` onto `xev`: the loop, handles, completions, and callbacks, cursor cancellation through `cursor_c_cancel`, the display link notifying `&thread.draw_now`, and termio and the surface notifying the renderer through the `xev.Async` handles. |
| termio writer thread and exec backend | The IO thread polled its mailbox every millisecond, and resize coalescing, synchronized-output reset, selection scrolling, and termios polling were deadlines on that loop. Exec wrote to the pty with blocking `write` calls and watched the child on a dedicated `waitpid` thread (the source of the earlier shutdown `ECHILD` race). The termio mailbox recorded a wakeup flag instead of owning an `xev.Async`, and the handlers read backend state from `Exec` instead of the thread's `ThreadData`. | Port `termio/Thread.zig`, the SPSC `Mailbox`, and Exec's thread side: `ThreadData` (loop, backend state) threaded through every handler, coalesce, sync-reset, and scroll timers, the pidfd/kqueue `xev.Process` exit watcher, the termios timer, and queued non-blocking writes through `xev.Stream.queueWrite` with pooled requests and buffers. |
| search thread transport | The search worker used V channels and a timed `select` instead of Ghostty's xev loop, wakeup and stop asyncs, and refresh timer. Surface producers called helper methods rather than pushing to the mailbox and notifying the wakeup. | Port the thread onto `xev` with the source's interleaved tick/`run(.no_wait)` loop, the `BlockingQueue` mailbox, and the refresh timer, and split the surface callback into `searchCallback`/`searchCallback_` so wakeup failures propagate as in Ghostty. |
| CoreText CF release thread | Ghostty's `os/cf_release_thread.zig` runs an xev loop with wakeup and stop asyncs and a drain flag for abnormal exits. Witty used a semaphore/mutex worker with a `stop_requested` boolean, placed it in `macos`, and joined it inside `deinit`. | Translate the thread into `internal_os` on `xev`, and have the CoreText shaper spawn it, notify `stop`, and join it as the source does. |
| libxev backend reporting and selection | `+version` printed libxev as unavailable, global initialization did not run `xev.detect()`, and GTK ignored `async-backend`. | Report `xev.backend()`, detect the Linux backend during global initialization, and restore `startupXev`'s `prefer` call and logs. `backend` is an accessor because V module globals cannot be read from other modules. |
| Flatpak host command | Ghostty's `os/flatpak.zig` host command (GIO DBus calls on a dedicated GLib thread, a mutex/condition state machine, and `waitXev` delivering the exit through the termio loop) was replaced by a hand-written C bridge without `waitXev`, so the exec backend waited on a separate thread and reported the exit off the termio loop. The Flatpak cwd probe also required a zero exit status, where Ghostty accepts the cwd whenever the probe spawns, and it swallowed `/dev/null` and wait errors that Ghostty propagates. | Translate `FlatpakHostCommand` into V over GIO (GVariants built with typed constructors instead of format varargs), including `waitXev`, restore Exec's `flatpakExit` completion, and restore the source cwd probe. The C bridge is removed. |
| compile-time renderer and platform selection | Ghostty builds exactly one graphics API into its renderer (`GenericRenderer(Metal)` on Apple platforms, `GenericRenderer(OpenGL)` on Linux) and only compiles `pkg/macos`, CoreText discovery, and the CoreText shaper for Darwin. Witty kept Metal and OpenGL fields, shaders, frame states, and image textures side by side behind a runtime `backend` switch, and compiled the macOS bindings, Metal renderer, and CoreText code into every build, so Linux builds type-checked but could never compile to C (CoreFoundation and Objective-C headers, CoreVideo constants). | Select the graphics API, shaders, frame state, texture, display link, and autorelease pool per platform with compile-time aliases, keep one `api`/`shaders`/`frames` set as the source does, move the backend-specialized renderer and image code into Darwin- and Linux-only files, make the `macos` module, Metal, CoreText discovery/shaping, and the CF release thread Darwin-only, and gate the remaining CoreText state behind `$if macos`. |
| exec read-thread POSIX constants | Ghostty's exec read thread uses `posix.O.NONBLOCK`, `posix.POLL.IN`, and `posix.POLL.HUP` from the target's headers. Witty hardcoded them as literals: `O_NONBLOCK` as the macOS `0x0004`, which is not `O_NONBLOCK` on Linux (`0x800`), so the pty read stayed blocking and `exec_test` hung, and `POLLHUP` as `0x0004`, which is `POLLOUT` on both platforms, so the read thread never saw the hangup it polls for. The signal, `fcntl`, and `waitpid` constants were literals too. | Read `SIGHUP`, `F_GETFL`, `F_SETFL`, `O_NONBLOCK`, `POLLIN`, `POLLHUP`, and `WNOHANG` from the C headers; `exec_test` now passes on macOS and Linux. |
| GTK instance-private data | zig-gobject's `defineClass` stores the size returned by `g_type_add_instance_private`, calls `g_type_class_adjust_private_offset` first thing in `class_init`, and reads private data at the adjusted offset. Witty's 16 GObject classes kept or discarded that size but never adjusted the offset, so GLib reserved no private area and `g_type_instance_get_private` returned the instance itself. Every private write, starting with `priv.wrapper`, overwrote the GObject header, and template-child offsets pointed past the instance. The GTK app aborted during startup on its first Linux run. | Store the offset per class, adjust it at the start of each `class_init`, and read private data through `instance_private(obj, offset)`, as zig-gobject's `getPrivate` does. |
| GTK blueprint templates | Ghostty compiles its `.blp` files with blueprint-compiler into the gresource. Witty's 11 hand-written `.ui` strings nested `<binding>` elements inside `<property>`, which GtkBuilder rejects (the search, key-state, and resize overlays failed to build), turned `bind template.x` into expression bindings instead of `bind-source`/`bind-property` object bindings, left the clipboard dialog's XML unbalanced, reordered the close dialog's `close-response`, and replaced the debug-warning text. | Embed blueprint-compiler 0.16.0's output (Ghostty's required version) for each pinned `.blp` verbatim, without its generated-file header. All 11 are now structurally identical to the compiled files. |
| GTK void signal return type | Ghostty's `defineSignal(name, Self, params, void)` registers `G_TYPE_NONE`. Eleven Witty signals (`reload-config`, both close dialogs' `close-request`/`cancel`, `set`, the child-exited `close-request`, the four search-overlay signals, and the clipboard `confirm`/`deny`) passed `GType(0)`, which is `G_TYPE_INVALID`, so GLib refused to create them. | Register every void signal with a named `g_type_none` (`1 << 2`), including the ones that already spelled it `GType(4)`. |
| window tab bar lifetime | In Ghostty `tab_bar` is a bound template child, and `gtk_widget_init_template` holds a reference to every bound child until dispose, so `syncAppearance` can remove the tab bar from the toolbar and add it back. Witty builds the window in code, so the toolbar held the only reference: the removal finalized the tab bar and the re-add passed a freed widget (the second startup abort). | Hold a reference to the tab bar from init until dispose, as the template does. |
| GTK debug-build indicators | Ghostty's window `debug` property, `devel` style class, and the window and inspector debug-warning banners follow `build_config.is_debug`, which Witty translates as `$if debug` (and `+version` reports). The GTK code used `$if !prod` instead, so a plain build reported ReleaseFast in `+version` while showing the debug banner. | Use `$if debug` at all five sites. |
| page memory alignment | Ghostty aligns page layouts to `std.heap.page_size_min`: 16 KiB on arm64 Darwin, 4 KiB on x86_64 Darwin and on Linux. Witty used 16 KiB for every macOS build, so Intel Macs laid out larger pages than Ghostty does. The page reference tests also encoded only the arm64 macOS totals and failed on Linux. | Use 16 KiB only on arm64 macOS, and give the reference tests each target's total size and the capacities derived from it (for example `initial_capacity(80).rows` is 582 with 16 KiB pages and 576 with 4 KiB pages). |
| page row cell offsets and erase rotation | A Ghostty `Row` holds an offset to its cells in page memory, and the page's grapheme and hyperlink maps are keyed by cell offset, so `eraseRow`, `eraseRowBounded`, and `eraseRows` rotate or swap `Row` values and the managed memory travels with them. Witty keyed those maps by row index, so its PageList could not move rows: it re-cloned every following row cell by cell (O(rows x cols) per erased row) instead of rotating. | Give each `RowData` a `cells_offset` handle to its cell block, key the page maps by it, and translate the three erase functions with the source's `rotateOnce` and row swaps. |
| page-owned grapheme storage | `CellData` carried a GC array of additional grapheme codepoints while the page bitmap allocator merely accounted for equivalent bytes, so cell layout, clone behavior, lookup ownership, and allocation growth differed from Ghostty. | Remove the cell array, store codepoints directly in the page's bitmap-allocated chunks, return borrowed typed views from page lookup, and translate the four-codepoint in-place append and allocate/copy/release growth paths. Route formatter, reflow, terminal, and page tests through page lookup. |
| recycled page reinitialization | Ghostty clears a pruned standard page's existing mapping and reinterprets it in place. Witty's `Page.reinit` discarded and reallocated every row, cell block, bounded set, and bitmap buffer each time scrollback recycled a page; sustained terminal input spent most of its time allocating and collecting those replacement arrays. | Reset matching row/cell storage, style and hyperlink sets, bitmap allocators, and sparse maps in place, rebuilding arrays only when a resized standard page has a different shape. Direct tests pin backing-buffer identity across same-capacity reinitialization. |
| Screen and Terminal on PageList | Ghostty's `Screen` is built on `PageList`: the cursor holds a tracked page pin plus row and cell pointers, styles, hyperlinks, and graphemes live in each page's ref-counted sets, and `Terminal` edits rows through those pointers. Witty ran `Screen` and `Terminal` on an invented flat `Pages` row array whose cells carried inline copies of their style and hyperlink, while the translated `PageList` was exercised only by its own tests and the formatter. | Re-translate `Screen.zig` on `PageList` (cursor pins and reloads, `cursorDownScroll`, `cursorScrollAbove` with row rotation, `clearCells`, `splitCellBoundary`, resize, styles and hyperlinks, selection and word/line/output selection, prompt clicks, `dumpString`) and re-translate `Terminal`'s print, wrap, index, line and character insertion/deletion, erase, and DECALN paths against page rows. Delete the flat `Pages` model and the inline `style`/`hyperlink` cell fields; every reader now resolves them through the page sets. |
| index with a top margin | Ghostty's `index` at the bottom margin creates scrollback only when the region spans the full screen, uses `scrollUp` for left/right margins or a non-zero blank cell, and otherwise rotates the region with `eraseRowBounded`. Witty called `cursorScrollAbove` for a full-width region with a top margin, pushing the rows above the region into history, and never checked the blank cell. | Restore the three branches and the `eraseRowBounded` fast path. |
| tracked selections | Ghostty's `Selection` holds tracked pins owned by the screen, so it moves with scrolling, resize, and erasure; its methods take the `Screen`. Witty's live selection stored flat coordinates that the screen remapped by hand after each mutation, while a separate `PageSelection` held the faithful code unused. | Make `selection.v` the translation of `Selection.zig` (tracked/untracked bounds, `track`, `deinit`, `topLeft`, `bottomRight`, `order`, `ordered`, `contains`, `containedRow`, `adjust`) and remove both flat selection types. |
| render state on PageList | `RenderState.update` iterates the viewport's page rows, clears the last dirty page's flag, reads styles and graphemes from the page, and resolves `linkCells` through the page hyperlink set. Witty adapted the flat rows instead, so cross-page viewports and page dirty tracking never reached the renderer. | Re-translate `update`, `linkCells`, and the flattened-highlight update against `PageList`, and add the upstream "linkCells with scrollback spanning pages" test. |
| mouse selection, word drag, and text dump | Ghostty's `left_click_pin` is a tracked pin; `dragLeftClickDouble` selects from the word under the click to the word under the drag point (clearing the selection when either is missing); `dumpTextLocked` formats with `trim = false`. Witty kept flat click coordinates, selected only the word under the click, and trimmed dumped text. | Track the click pin (untracking the previous one), translate the double- and triple-click drags and `mouseSelection`'s pin moves, format dumped text untrimmed, and add the upstream "selection logic" and "rectangle selection logic" tests. |
| screen search on the live page list | Ghostty's `ScreenSearch` searches the screen's own `PageList` and tracks its result pins; the search thread scrolls to a selected match with a pin scroll when it is outside the viewport. Witty searched a snapshot copy of the flat rows, rebuilt whenever a fingerprint changed, and scrolled by flat row. | Search `screen.pages` directly, remove the snapshot and fingerprint layer, restore the viewport page-overlap check and `ScrollPin` scroll, and translate the upstream search tests. |
| Kitty placement pins | Ghostty anchors Kitty placements to tracked pins, deletes intersecting placements with `Pin.isBetween`, untracks pins when placements are removed, and resolves virtual placeholders by iterating page rows. Witty stored flat coordinates, so placements did not follow scrolling and resize. | Store `PlacementPin{pin: &Pin}` from `track_pin`, untrack in `Placement.deinit`, merge the two intersect deletes into the source's `deleteIntersecting`, iterate placeholders with a `RowIterator`, and translate the upstream storage and Unicode placeholder tests with their tracked-pin counts. |
| page row metadata on clone | `clonePartialRowFrom` copies every `Row` field from the source and, for a partial copy, restores only the destination's wrap, wrap-continuation, grapheme, hyperlink, and styled flags and ORs `dirty`. Witty left the destination's semantic prompt and Kitty placeholder flags on partial copies, so growing columns without reflow (which copies fewer cells than the new width) dropped prompt marks. | Copy the source row and restore the same five flags plus `dirty`, keeping the destination's cell block. |
| page integrity checks | `Page.assertIntegrity` and `getCells`' ownership check run only under `slow_runtime_safety`, and `getCells` compares pointer bounds. Witty ran the full page integrity scan in every build and `get_cells` scanned all rows to find the row, both on the live print and render paths. | Skip both in production builds, like `PageList.assert_integrity`, and compare pointer bounds in `get_cells`. |
| formatter option mutability | Zig struct fields are mutable, and the upstream formatter tests set `formatter.opts.unwrap` and `.trim` after `PageFormatter.init`. Witty declared `PageFormatter.opts` and every `FormatOptions` field immutable. | Make them mutable and translate those tests as written. |
| renderer frame critical section | Ghostty's `updateFrame` holds `state.mutex` while it updates the render state, reads the scrollbar, clones the preedit, refreshes Kitty images, and collects hovered OSC 8 links, then logs and continues if regex link matching fails. Witty's comment claimed the caller held the mutex, but nothing locked it, so the renderer read the terminal while the IO thread resized or wrote it (caught as a torn page read in the embedded bridge test). Regex link errors also aborted the frame. | Take `state.mutex` around the same critical data as the source, return it as `UpdateFrameCritical`, and log regex link errors. |
| OSC command union | Ghostty's `osc.Command` is a tagged union whose variants carry their own payloads, with a response terminator only on `color_operation` and the Kitty color OSC; the Kitty color `Kind` and `Request` and the ConEmu tab title are unions too; `Terminal.semanticPrompt` takes the parsed command; and `kittyColorReport` is one function. Witty used a flat `Command` struct with a `cmd_type` tag, a shared `str_value`, every variant's fields side by side, and a terminator on every command; flattened the Kitty kinds and requests and the tab title into tagged structs; split the semantic prompt entry into `semantic_prompt(action, exit_code)` and `semantic_prompt_options(action, options)`; spread the Kitty color report over five helpers; and returned a null title pointer from the C API for an empty title. | Make `Command` a sum type of per-variant payload structs with `key()`, build the matching variant in every OSC parser, make the Kitty color kind and request and the tab title unions, carry the typed payloads through the stream and `ParserAction` (dropping the `OscCommand` alias), translate `semanticPrompt(cmd)` and `kittyColorReport` as single functions, return the title pointer as the source does, and re-translate the upstream OSC 21 tests. |
| synchronous stream dispatch | Ghostty's `Stream(Handler)` calls `handler.vt(action, value)` synchronously while it parses, with each action's own payload type, lets a handler intercept raw parser actions through an optional `vtRaw`, and is owned by `Termio` together with its handler. The inspector parses PTY reads with its own `Stream(VTHandler)` through `nextSlice`, so only parser actions reach `vtRaw`. Witty queued flat `StreamEvent{key, ActionPayload}` values, one struct carrying every action's fields, for a later handler pass; split `csiDispatch` into invented helpers; kept the termio handler beside the stream; and recorded inspector events byte by byte, including prints and C0 controls that never reach `vtRaw`. The termio handler also rebuilt DSR requests from payload fields the stream never set, so device status reports (`CSI 5 n`, `CSI 6 n`) were never answered. | Re-translate `stream.zig` as the generic `Stream[H]` with an `ActionKey` and an `ActionValue` sum of the source's payload types, detect `vt_raw` at comptime, and translate `csiDispatch`, `oscDispatch`, `escDispatch` and `configureCharset` as written. `ReadonlyStream` is `Stream[ReadonlyHandler]`, `Termio` owns `Stream[StreamHandler]`, and the inspector and benchmark use their own handlers. Re-translate the upstream stream and read-only stream tests. A live Linux check now gets `ESC[3;7R` back for `CSI 6 n`, where the previous build sent nothing. |
| concrete stream print payload | Ghostty's comptime action tag gives the dominant `.print` path a concrete `Action.Print` payload. V's generic runtime `ActionValue` representation heap-copied that payload for every codepoint; a 610 MiB ASCII scroll run spent most sampled time allocating and collecting those copies. | Make the concrete `vt_print(ActionPrint)` branch part of every translated stream handler, call it directly from the source's inline `print`, and keep the generic `.print` arm delegating to the same implementation for callers of `vt`. The identical sustained run improves from 7.13 to 17.81 MiB/s without changing parser or terminal logic. |
| mailbox message unions | Ghostty's apprt surface `Message` and termio `Message` are tagged unions: each variant carries only its own payload, and senders build variants directly (`.{ .focused = true }`, `.{ .write_small = ... }`) apart from the `writeReq` helper; `handleMessage` also frees the `pwd_change` and allocated clipboard-write requests. Witty used one struct per mailbox, with a kind enum beside every variant's fields, twelve invented `*_msg` constructors for the termio mailbox, and no release of the write requests. | Make both messages sum types of per-variant payload structs with `kind()` for the compact tag, keep only `Message.write_req` (upstream's `writeReq`), build variants directly at every sender, dispatch on the variant in `Surface.handleMessage`, `App.surfaceMessage` and the termio thread's mailbox drain, and release the write requests as the source does. |
| split idle source on dispose | Ghostty's `SplitTreeSplit.dispose` removes its pending `onIdle` source, so a split replaced by a tree rebuild never repositions a torn-down `GtkPaned`. Witty's split is a plain struct around an `AdwBin` with no dispose, so the idle queued when the old paned was torn down ran afterwards and read its properties from a finalized object: `g_object_get_property: assertion 'G_IS_OBJECT (object)' failed` three times per split-down in the Linux D-Bus probe. | Remove the idle source from the split widget's `destroy` signal (emitted by GTK's dispose) and stop refreshing once the paned is gone; the probe now logs no criticals. |
| apprt action values | Ghostty's `performAction(target, action, value)` takes each action's own payload type (`void` for most, `SplitDirection`, `SetTitle`, and so on), and the nested `KeySequence` (`trigger` or `end`) and `KeyTable` (`activate`, `deactivate`, `deactivate_all`) values are unions too; the C API converts the active payload. Witty passed one `ActionValue` struct with a field per action (`set_title_`, `new_split`, ...), flattened `KeySequence` into `active` plus an unused trigger and `KeyTable` into a tag plus a name. | Make `ActionValue` a sum type of the payload types with `ActionVoid` for `void`, make `KeySequence` and `KeyTable` unions (`KeyTable.tag()` for the C tag), build the payload directly at every `perform_action` call, and read it by variant in the C API, the embedded runtime, the macOS host, and the GTK application and surface handlers. |
| parser action union | Ghostty's `Parser.Action` is a tagged union whose print, execute, CSI, ESC, OSC, DCS, and APC variants each carry only their own payload. Witty's `ParserAction` was one struct with an `action_type` tag beside `char`, `byte_val`, `csi`, `esc`, `osc`, and `dcs` fields. | Make `ParserAction` a sum type (`ParserPrint`, `ParserExecute`, `CSIAction`, `ESCAction`, `osc.Command`, `DCSAction`, and the DCS/APC put and marker variants) with `tag()` for the inspector's filter, and dispatch on the variant in the stream and the inspector's event encoder. |
| terminal APC module and state union | `terminal/apc.zig` was not translated as a terminal module. Termio instead owned a second APC parser whose byte enum sat beside an always-live Kitty command parser, and its end operation returned the Kitty command directly rather than the source's APC command arm. | Add the terminal-owned APC handler and upstream tests, represent inactive/ignore/identify/Kitty states as direct variants so only Kitty owns parser storage, retain the one possible command arm explicitly, and have the termio stream handler consume and deinitialize that command. |
| search thread message and event unions | Ghostty's search `Thread.Message` (`change_needle`, `select`) and `Thread.Event` (`quit`, `complete`, `total_matches`, `selected_match`, `viewport_matches`) are tagged unions. Witty stored each as one struct with a `kind` tag beside every variant's payload fields, and initially retained source-external tag enums and projection switches after converting the payloads. | Make `Message` and `Event` direct sum types of per-variant structs, have the thread emit and drain the variants, match on them in consumers and tests, and remove the redundant tag types and `kind()` projections. |
| SGR attribute union | Ghostty's `sgr.Attribute` is a tagged union whose color variants carry an `RGB`, a palette index, or a `color.Name`; the bright 8-color variants hold the bright name (`bright_black` through `bright_white`, 8 to 15), and the launch-failure report sets `.@"8_fg" = .bright_red`. Witty stored one struct with a `kind` tag beside `r`, `g`, `b`, `index`, `underline`, and unknown-slice fields, stored bright colors as 0 to 7 and added 8 in `Screen.setAttribute`, so `ghostty_sgr_attribute_value` reported bright colors as their non-bright palette index. | Make `SgrAttribute` a sum type of per-variant structs with `tag()` returning `SgrAttributeTag` (the source's `underline` tag name restored), parse with the source's `switch` shape and `- 82`/`- 92` bright offsets, store bright names directly, match on the variants in `Screen.setAttribute`, the stream handlers, and the C projection, and restore the report's `8_fg` bright-red attribute. |
| binding action union | Ghostty's `Binding.Action` is a tagged union of 83 actions whose payloads are strings, `f32`, `i16`, `isize`, `usize`, per-action enums, `CursorKey`, `WriteScreen`, and the `SplitResizeParameter` tuple; `parse`, `format`, `clone`, `hash`, and `equal` reflect over its fields. Witty stored one struct with a tag beside `str_param`, `float_param`, `int_param`, `uint_param`, `enum_param`, `enum_param2`, and `cursor_key` fields, widened the integer payloads to 64 bits, stored enums as `i32`, and built actions through `Action.new_*` helpers. | Make `Action` a sum type of per-action structs carrying the source payload types with `tag()`, restore `SplitResizeParameter` and `WriteScreen.parse`/`format`, resolve names through the tag enum and dispatch `parse` by payload kind as the source's field loop does, rewrite `clone`, `hash` (same byte stream), `format`, and `equal` over the variants, construct the variants directly at every call site, and match on them in the surface, app, and GTK dispatchers. `deep_equal` now refuses interfaces, which V instantiates through the sum type's variant loop. |
| binding set value and parser element unions | Ghostty's `Set.Value` is a tagged union of `leader: *Set`, `leaf: Leaf`, and `leaf_chained: LeafChained`, each leaf type providing `generic()`, and `Parser.Elem` is a union of `leader: Trigger`, `binding: Binding`, and `chain: Action`. Witty stored `SetValue` as one struct with a `typ` tag beside `leader`, `leaf_action`, `leaf_flags`, `chain_actions`, and `chain_flags`, and `ParserElem` as a struct with `typ`, `trigger`, `binding`, and `action`. | Make `SetValue` a sum type of `Leader`, `Leaf`, and `LeafChained` (with the source's per-leaf `generic()`), make `ParserElem` a sum type of its three variants, and match on the variants in the set operations, the parser, the surface and app binding lookups, the global-shortcut mapping, `+list-keybinds`, and keybind equality. |
| binding generic-leaf actions union | Ghostty's common leaf view retains a fixed one-element array for a single action or a borrowed slice for a chained leaf. Witty collapsed both arms to a dynamic slice, erasing the single-versus-many tag even though `GenericLeaf` is part of the binding API. | Represent the fixed single action and many-action slice as direct variants, construct the matching arm from `Leaf.generic` and `LeafChained.generic`, and retain `actions_slice` as the source's common read-only view for dispatchers. |
| clipboard request union | Ghostty's clipboard request has a payload-free `paste` arm and separate OSC-52 read/write arms that each carry a `Clipboard`. Witty stored one discriminator beside an always-live clipboard, so ordinary paste requests retained invented clipboard state and every consumer projected the flat record manually. | Represent all three request arms directly, expose the source discriminator only through `tag()` for embedded callback metadata, and match the active request through core completion/validation, the embedded runtime, and GTK reads and confirmation dialogs. |
| binding trigger key union | Ghostty's `Trigger.Key` is `union(C.Tag) { physical: key.Key, unicode: u21, catch_all }`. Witty stored `TriggerKey` as a struct with a `typ` tag beside `physical` and `unicode` fields, compared it with an operator overload, and built keys through `TriggerKey.new_*` helpers and tagged struct literals. | Make `TriggerKey` a sum type of `TriggerKeyPhysical`, `TriggerKeyUnicode`, and `TriggerKeyCatchAll` with `tag()` returning the C tag enum, match on the variants in `Trigger`'s equality, folded equality, hash, format, and unset check and in the C, GTK, and `+list-keybinds` projections, and construct the variants directly, including the backwards-compatible key-name table. |
| fontconfig value union | Ghostty's fontconfig binding defines `Value` as `union(Type)` over void, integer, double, string, bool, matrix, char set, FreeType face, language set, and range payloads, with `init` and `cval` converting to and from `FcValue`, and the font code reads payloads directly (`.string`, `.integer`, `.char_set`, `.lang_set`). Witty stored one struct with a `tag` beside every payload field, built values through `Value.from_*` helpers, and kept a `PatternValue` alias. | Make `Value` a sum type of per-type variants with `tag()`, translate `init` and `cval` over the variants, construct the variants directly, and read payloads with checked `as` casts in the deferred face and discovery code. |
| z2d path node union | z2d 0.10's `PathNode` is `union(PathNodeTag)` of `move_to: PathMoveTo`, `line_to: PathLineTo`, `curve_to: PathCurveTo` (three control points), and `close_path: PathClose`. Witty's sprite renderer stored one struct with a `kind` beside `x`, `y`, and curve control coordinates, and named the close tag `close`. | Make `PathNode` a sum type of the four node structs with `tag()` returning `PathNodeTag` (the `close_path` name restored), build the variants in the static path and context builders, and match on them in closed-subpath detection, the inner-stroke mask, and the fill and stroke plotters. |
| kqueue operation and result unions | libxev's kqueue backend defines `Operation` as `union(OperationType)` with a distinct payload struct per operation (including separate `send` and `recv` structs and the heap `Timer`) and `Result` as a union of per-operation error unions; the loop switches on the active payload, and the watchers read `c.op.<op>` and `r.<op>` directly. Witty stored `KqueueOperation` as a struct with a `tag` beside all seventeen payloads (reusing the write and read payloads for send and recv) and `KqueueResult` as one record with `err`, `socket`, `n`, `timer`, and `exit_code`. | Make `KqueueOperation` a sum type of the per-operation structs (adding `KqueueSendOp` and `KqueueRecvOp`) and `KqueueResult` a sum type of per-operation result structs carrying the error name and payload, both with `tag()`; switch on the variants in `add`, `start`, `stop_completion`, `kevent`, `perform`, and `syscall_result` (the heap still stores a pointer into the timer payload), build results through tag-directed helpers, and read payloads with checked casts in the async, process, timer, and stream watchers and the backend tests. |
| epoll operation and result unions | libxev's epoll backend defines `Operation` and `Result` as tagged unions over its sixteen operations, with distinct `send` and `recv` payload structs. Witty stored both as flattened records like the kqueue backend. | Make `EpollOperation` and `EpollResult` sum types of per-operation structs with `tag()` (adding `EpollSendOp` and `EpollRecvOp`), switch on the variants in the loop's tick, `start`, `stop_completion`, `perform`, and `fd`, build results through tag-directed helpers, and read payloads with checked casts in the watchers and tests. The pending-result checks use an `if _ := res_` guard because V miscompiles `res_ == none` after an `or` block assigns a sum-type option. |
| io_uring operation and result unions | libxev's io_uring backend defines `Operation` and `Result` as tagged unions over its seventeen operations, including `timer_remove` and distinct `send` and `recv` payloads. Witty stored both as flattened records, and the completion handler mutated one record's `timer` field in place. | Make `IoUringOperation` and `IoUringResult` sum types of per-operation structs with `tag()` (adding `IoUringSendOp` and `IoUringRecvOp`), switch on the variants in SQE preparation, `invoke`, and the read-result helper, start each result from the tag's empty success variant, keep the kernel-visible timespec and buffers inside the active payload, and read payloads with checked casts in the watchers and tests (the recvmsg test now reads its own result). |
| libxev buffer unions | Each libxev backend (and the dynamic API) defines `ReadBuffer` as `union(enum) { slice: []u8, array: [32]u8 }` and `WriteBuffer` as `union(enum) { slice, array: struct { array, len } }`. Witty stored every one as a record with a `BufferKind` tag beside both payloads (and the write array's length in `array_len`). | Make each backend's `ReadBuffer` and `WriteBuffer` a sum type over shared `ReadBufferSlice`/`ReadBufferArray` and `WriteBufferSlice`/`WriteBufferArray { array, len }` variants, drop `BufferKind`, switch on the variants in the buffer helpers, stream write remainders, io_uring read-result check, and dynamic conversions (which copy the active variant, as `fromBackend`/`toBackend` copy the union), and keep SQE preparation going through `slice_ptr`/`bytes` so the kernel sees the live payload. |
| kitty graphics storage placement | Ghostty's `Screen` embeds `kitty_images: kitty.graphics.ImageStorage`, sets its limit from `Screen.Options.kitty_image_storage_limit` in `init`, deinitializes it in `deinit`, replaces it with `.{ .dirty = true }` on reset, sets `dirty` directly, and has `Terminal.kittyGraphics` call `graphics.execute`; `eraseDisplay` and the termio clear call `kitty_images.delete(.{ .all = true })`. Because Witty's `kitty` module imported `terminal`, the screen held the storage as an opaque pointer materialized on first use with four lifecycle callbacks, `Terminal` kept a separate `kitty_image_limit`, the full reset preserved the configured limit, and callers went through `kitty.execute`, `terminal_storage`, `set_terminal_storage_limit`, and an approximate `clear_screen_images`. | Move the graphics command, exec, image, storage, and unicode files (and their tests and test data) into the `terminal` module with Ghostty's exported names (`CommandParser`), embed `ImageStorage` in `Screen`, add `ScreenOptions.kitty_image_storage_limit` (applied when the screen set creates a screen, and inherited by the alternate screen), add `Terminal.kitty_graphics`, and replace the callbacks and helpers with the source's direct storage calls in the screen, terminal, termio, stream handler, renderer, and inspector. A Kitty `a=q` query from the pty now answers `\e_Gi=31;OK\e\\` on Linux. |
| Kitty graphics delete union | The eleven-arm graphics delete command was split into `DeleteKind`, a partly tagged `DeleteData` sum, and `FullDelete`, allowing the kind and payload to disagree and making the two boolean arms indistinguishable without the outer tag. | Represent every delete arm directly, give cursor-intersection and animation-frame deletion distinct boolean payloads, and carry the one canonical value through parsing, graphics execution, storage mutation, erase-display, termio clear, and tests. |
| Kitty graphics control union | Ghostty's command control has distinct `query` and `transmit` arms that both carry a `Transmission`. Witty collapsed them into one `Transmission` variant and added a source-external `is_query` field to the payload, so the command's meaning lived outside the union tag. | Represent the two arms as distinct `ControlQuery` and `ControlTransmit` variants, remove the invented payload flag and constructors, build every parser arm directly, and dispatch query versus transmission on the active variant. |
| terminal style color union | Each of Ghostty's foreground, background, and underline colors is an independent `none | palette: u8 | rgb: RGB` tagged union. Witty stored three tags beside twelve always-live palette/channel fields, admitted impossible inactive payload state, and made all style consumers reconstruct the active value manually. | Represent each color as a direct `StyleColor` sum, keep the source byte tag only as `tag()` for packed hashing, and match the active payload in equality, resolution, background cells, SGR mutation, VT/HTML formatting, DECRQSS, rendering, inspection, font shaping, and Kitty Unicode placement. The hash still packs the source's three tags, three 24-bit active payloads, flags, and padding before folding to 64 bits. |
| termio backend unions | Ghostty retains its backend configuration, live backend, and thread-local backend data as three `union(Kind)` values even though the pinned `Kind` currently has only `exec`. Witty flattened those boundaries into `ExecConfig`, `Exec`, and `ExecThreadData`, so shared termio code and tests owned exec-specific state directly. | Restore the byte-backed `BackendKind` and explicit `BackendConfig`, `Backend`, and `BackendThreadData` exec-arm wrappers; route initialization and every lifecycle, resize, focus, write, config, and deinit operation through those boundaries; and keep exec-local callbacks accessing the explicit thread-data arm as the source does. |
| renderer coordinate export | The complete surface/terminal/grid coordinate union and conversions existed only under the translation-specific name `SizeCoordinate`, while Witty exported `renderer.Coordinate` as an alias of the unrelated `terminal.Coordinate` integer grid point. The live mouse path therefore avoided the claimed public type. | Restore `Coordinate` as the canonical renderer sum type, remove the incorrect terminal alias, and route conversion tests plus the surface mouse-position conversion through the source-shaped name. |
| configuration path union | Ghostty's `Path` retains either an optional path or a required path as distinct union arms. Witty flattened it into one string plus a Boolean, permitting contradictory inactive state and making config and renderer consumers interpret the tag manually. | Represent optional and required paths as direct variants, preserve the arm through parsing, cloning, formatting, successful expansion, and repeatable lists, replace either arm with an empty required path on expansion failure exactly as the source does, and match the active variant in recursive config loading, background images, and shader loading. |
| split position idle source | Ghostty's `SplitTreeSplit.new` only wires the paned's `notify::position`, `max-position`, and `min-position` signals, and `onIdle` resolves its `SplitTree` with `getAncestor`, returning when the split is orphaned. Witty's constructor also queued a refresh, so the first idle could run before the paned's first allocation, while `max-position` is still `G_MAXINT`: it set the position to 1073741824, the allocation clamped that to the full width, and the next idle took the clamp for a drag and wrote ratio 1.0 into the tree, collapsing the new pane (caught in a traced split-right run). `onIdle` also used a stored `split_tree` pointer, so an orphaned split's idle could resize the live tree. | Drop the constructor refresh, resolve the split tree through the widget's `SplitTree` ancestor and return when there is none, read the paned position inside `on_idle` as the source does, and remove the stored pointer and its constructor parameter. |
| page pin value allocation | Ghostty's `PageList.Pin` and all of its methods are by-value; only pins registered through `trackPin` are allocated from the pin pool. Witty marked the entire `Pin` type `@[heap]` and translated its read-only methods with pointer receivers, so every cursor move, equality check, and up/down calculation allocated short-lived pins through the garbage collector. | Keep ordinary pins and their method receivers by-value, while the viewport and `track_pin` continue to allocate explicit `&Pin` values. Confine V escape-checker overrides to the two source APIs that deliberately retain caller-proven pointers (`TrackedPinsRemap` and `Tracked.initAssume`). Generated C for the production stream benchmark drops from 73 `HEAP(Pin)` sites to the intentional viewport allocation, the same 61 MiB sustained-scroll run improves from 8.24 to 17.43 MiB/s, and the full PageList stress file falls from roughly 354 to 137 seconds. |
| quick-terminal size union | Ghostty's `QuickTerminalSize.Size` retains either a percentage `f32` or a pixel `u32`; Witty flattened it into a kind plus both payloads, even though the separate exported C projection is the only boundary that requires a tag/value record. | Represent percentage and pixel sizes as direct variants, match the active payload for parsing, formatting, calculation, cloning, and C projection, and keep the explicit tag/value layout only in `CQuickTerminalSize`. |
| readable-input union | Ghostty's configuration `ReadableIO` retains either a raw escaped string or a deferred path. Witty stored both behind a separate kind in one record, requiring consumers to interpret an always-live generic value. | Represent raw and path inputs as direct variants, preserve the active arm through parsing, cloning, escape decoding, equality, and formatting, and match it directly when termio prepares strings or opens all input files before startup. |
| font presentation-mode union | Ghostty's collection lookup mode retains a `Presentation` only for its explicit and Unicode-default arms; `any` is payload-free. Witty stored a presentation on every mode behind a separate kind, including an inactive default value on `any`. | Represent explicit, default, and any as direct variants, preserve the source's fallback-only conversion from default to explicit matching, and test the active arm directly in the codepoint resolver. |
| font collection entry unions | Each Ghostty collection entry retains either a deferred or loaded face and either a pending size adjustment or computed scale; `EntryOrAlias` likewise retains an inline entry or a stable alias pointer. Witty stored all six payloads behind three booleans, so inactive font resources and pointer states remained representable. | Represent the face, scale factor, and entry-or-alias values as direct variants; load by replacing the deferred arm only after all fallible work succeeds, deinitialize only active owned entries, and keep heap-stable sum values so aliases retain valid entry pointers. |
| font metrics modifier union | Ghostty's metrics modifier retains either a percentage multiplier or an absolute pixel delta. Witty stored a Boolean tag beside both payloads, so callers could construct contradictory values and hashing/application had to ignore an inactive field. | Represent percentage and absolute modifiers as direct variants, construct the active arm during configuration parsing, and dispatch formatting, hashing, integer saturation, and floating-point application on that arm. |
| CLI special-case union | Ghostty's action detector carries an action only for immediate-action and fallback cases; `abort_if_no_action` is payload-free. Witty stored a default `Action` on all cases behind a separate kind. | Represent all three cases as direct variants, retain values only on the action and fallback arms, and match those variants directly in the iterator-generic detector. |
| command argument-iterator union | Ghostty's `Command.ArgIterator` retains either the allocating general shell parser or a direct argument slice plus index. Witty put the shell string/position and direct slice/index side by side behind a kind enum. | Represent shell and direct iterator state as separate mutable variants, construct the matching arm from `Command`, and dispatch `next` directly on the active payload while retaining V's GC-backed no-op deinitializer. |
| tmux viewer input union | Ghostty's `Viewer.next` accepts an `Input` union whose pinned implementation currently has one `tmux: Notification` arm, then dispatches to `nextTmux`. Witty omitted the input boundary and accepted the notification payload directly. | Restore the explicit `TmuxViewerInput` wrapper, make `next` dispatch its active tmux payload through `next_tmux`, and construct the arm at the stream-handler boundary. Tests use a small adapter to keep the upstream notification scenarios readable; the production boundary uses a package constructor because the pinned V compiler cannot resolve this new wrapper's cross-module struct literal even though it resolves the public method signature. |
| Core Foundation release message union | Ghostty's dedicated Darwin release thread queues a `Message` union whose pinned implementation has one `release` arm containing the reference slice and its allocator. Witty queued the release payload directly, omitting the union boundary. | Restore the explicit `CFReleaseMessage.release` wrapper, construct that arm in the CoreText shaper, and drain references through its payload. V's GC remains the ownership adaptation for the source allocator field and frees the detached slice after the message is consumed. |
| prepared startup-input union | Ghostty's termio startup preparation returns either an owned byte string or an open file. Witty stored both payloads in every item behind a separate tag, leaving an inactive file handle on strings and an inactive byte slice on files. | Represent string and file inputs as direct variants, match them when queuing startup writes, and close only the active file variants during success and error cleanup. |
| libxev backend tag contracts | The kqueue, epoll, and io_uring operation and timer tags plus the retained `std.posix.ShutdownHow` used compact inferred enums in the pinned dependency but retained V's default 32-bit storage. Kqueue's local `StartAction` union was flattened into an enum plus an always-live result integer, and the Linux dynamic poll event became ordinal zero instead of the source's explicit `u32` `POLLIN`/`EPOLLIN` value 1. | Byte-back all seven inferred tags with their complete source order, represent all five kqueue start actions directly with the syscall result owned only by its arm, restore the dynamic poll event's four-byte value 1, and retain compiler atomic-order constants with C `int` storage. |
| renderer OpenGL option types | Ghostty's buffer, texture, target, and sampler options store the canonical `opengl` package enums directly. Witty redeclared seven smaller ordinal-only enums, projected them through handwritten switches at every GL call, collapsed distinct minification/magnification filters into one type, and retained three unused debug-enum declarations with no renderer-source counterpart. Its V-only vertex-reflection adapter tag also used implicit 32-bit storage. | Store the canonical C-value-backed OpenGL enums directly in every option and resource, pass them unchanged to the translated package API, restore distinct min/mag filter types and the full set of values they admit, remove all ten duplicate or orphan enum declarations and conversion switches, and byte-back the exhaustive local adapter. |
| Oniguruma encoding and syntax handles | Ghostty exposes every encoding and syntax as an opaque native pointer and passes those pointers directly to `onig_initialize`/`onig_new`. Witty replaced both pointer types with ordinal enums and reconstructed the native values through handwritten 31-way and 12-way C switches; the synthetic IDs also occupied only four bytes instead of pointer width. | Retain `Encoding` and `Syntax` as single-pointer opaque wrappers, expose every pinned native constant directly, pass the handles unchanged through initialization and regex compilation, and remove both invented ID protocols and switch tables. Associated zero-argument constructors stand in for source constants because V cannot initialize a compile-time value from a C symbol. |
| vaxis style and mouse contracts | The pinned vaxis dependency declares color scheme as `dark, light`, underline as `off, single, double, curly, dotted, dashed`, twelve explicitly valued `u8` mouse buttons, and four mouse event types. Witty reversed the scheme, reordered underline styles, retained only five incorrectly numbered buttons, omitted drag, discarded all mouse modifiers, and widened coordinates to `int`; motion with a held button was reported as plain motion. | Restore every source value with byte backing, retain the packed three modifier bits and `u16` coordinates/offsets in the mouse value, decode the full SGR button mask and shift/alt/control state, distinguish drag from unbuttoned motion, and preserve vaxis' default-one and saturating-zero coordinate parsing. |
| vaxis key model and keyboard parser | Witty retained only Ctrl/Shift as separate booleans, omitted key text and alternate codepoints, assigned ad-hoc values to navigation/function/keypad keys, and reduced matching to raw codepoint equality. Its parser conflated LF with Enter, synthesized Shift for uppercase input, emitted Escape for unknown CSI/SS3 reports, omitted Alt input and most legacy/Kitty fields, and split multi-codepoint graphemes. | Retain all eight modifier bits in source order, the five default Kitty flags, every pinned private-use key value and name, all five key fields, and vaxis' exact/UTF-8/shifted/shortcut matching rules. Restore ground, Alt, SS3, legacy CSI, CSI-u, SGR/X10 mouse, ignored-event consumption, text payloads, and first-grapheme decoding against Witty's translated pinned Unicode break table. V names the otherwise unrepresentable source constant `f32` as `f32_key` while preserving the `"f32"` name-map entry. |
| vaxis text input | Witty replaced pinned vaxis' cursor-aware gap buffer with one append-only string, deleted both Backspace and Delete from the end, inserted synthesized codepoints instead of the key's text payload, and omitted every cursor, home/end, word movement, and Ctrl/Alt editing operation. The theme preview then duplicated this replacement string in `search_text`, so cursor movement could not affect filtering or cursor drawing. | Restore the gap buffer's first/second halves, growth, cursor/gap movement, deletion, clear, ownership, and byte-length operations; use the translated grapheme boundary table for cursor movement and deletion; restore every pinned editing binding and text insertion rule; and make filtering, display, and cursor placement read the canonical widget buffer directly. |
| vaxis parser event surface | The compatibility parser exposed only key presses and mouse events. Escape-prefixed OSC/DCS/SOS/PM/APC strings were misreported as Alt keystrokes; key releases, bracketed paste boundaries, OSC 52 paste, color reports, focus, in-band resize, color-scheme updates, capability reports, and mouse-leave events could not be represented. `Winsize` also omitted both pixel dimensions. | Restore the complete pinned event payload surface (using explicit empty V variants for payload-free union arms), the four-field winsize, string-terminator skipping, APC Kitty graphics, BEL/ST OSC color and clipboard reports, key-release and bracketed-paste events, focus and resize events, color-scheme reports, and every pinned CSI capability response. Route color-scheme and resize events into the theme preview while dropping unrequested events at the same application boundary as vaxis' generic loop. |
| vaxis color and style model | Witty reduced vaxis' tagged default/index/RGB color to an always-RGB record and omitted underline color plus dim, blink, reverse, invisible, and strikethrough style state. Its renderer consequently forced both RGB colors on every segment, used legacy semicolon RGB syntax, and could not emit palette colors or the missing attributes. | Restore the three-arm color union, color equality and RGB constructors, all pinned style fields and equality, and the standard vaxis SGR sequences for base, bright, indexed, RGB, underline colors/styles, and every style attribute. Theme-preview colors now construct the explicit RGB arm. |
| cimgui and fontconfig enum ABI | Dear ImGui exposes its key and mouse-button handles as C `int`, while Ghostty's pinned fontconfig wrapper explicitly retains the C-imported unsigned width for weight, slant, spacing, match-kind, and result values. Witty left the two cimgui handles and four of the five fontconfig types on implicit V enum storage, and incorrectly signed the match kind. | Give the cimgui handles explicit native-`int` backing, retain all five fontconfig contracts as `u32`, and exhaustively pin their source values and widths in focused tests. |
| macOS framework value contracts | Witty left twelve translated CoreFoundation, CoreText, CoreGraphics, os.log, signpost, and CoreVideo enums on implicit storage. `CFNumberType` was additionally truncated from all sixteen source cases to one, declared as 32-bit despite its 64-bit `CFIndex` ABI, and omitted `Number.getValue`; `StringEncoding` gained an extra alias. The AppKit bridge introduced a reordered private key-action enum and converted it back to the canonical input action by hand. | Restore every source enum backing and value, the complete 16-case number kind plus its value getter, and the exact string-encoding set. Route AppKit key events through `input.KeyAction` directly, eliminating the private protocol and conversion switch. V uses explicit `i64` for `CFNumberType` because it cannot use `isize` as enum storage and all supported macOS targets have 64-bit `CFIndex`. |
| OpenType real-font test stubs | The translated test file declared seven Julia Mono integration tests for SFNT directory/table lookup and the `head`, `hhea`, `OS/2`, `post`, and `SVG ` parsers, but every body was empty despite the exact pinned font fixture already being present. | Embed the same Julia Mono fixture as Ghostty and translate every upstream expected field, optional-version boundary, directory/table length, and SVG glyph assertion. |
| inspector setup lifecycle | Ghostty creates each Dear ImGui context in its owning runtime, assigns the runtime-specific backend name, and then calls public `Inspector.setup`. Witty folded all setup into `Context.create`, made the GTK setup callback a no-op, and consequently identified GTK contexts as `ghostty_embedded`. | Separate context allocation, backend identity, and inspector setup; restore public `inspector.setup`, invoke it from both source-equivalent runtime boundaries, and assign `ghostty_gtk` versus `ghostty_embedded` exactly where Ghostty does. |
| renderer background-cell accessor | Ghostty centralizes the row-major background-cell offset in public `Contents.bgCell(usize, usize)`. Witty replaced it with separately written `u16` set/get methods that added out-of-range fallback behavior and kept the live renderer on the replacement API. | Restore `bg_cell` with the exact unchecked `usize` offset and route every live background write through it. Its return is `voidptr` only because the fallback V compiler miscompiles pointers to fixed-array aliases; callers cast it back to the unchanged four-byte `CellBg` ABI at dereference. |
| inspector shared widget helpers | Ghostty exports `helpMarker`, `DetachableHeaderState`, and a callback-based `detachableHeader` in addition to the older detachable-header object. Witty moved help rendering into cimgui and omitted the newer state and helper entirely. | Restore both public helpers and the state object, route all inspector help markers through the canonical boundary, and translate the callback helper's ID scope, 0.3 right-side docking, first-show reset, pop-out control, tooltip, window close state, and balanced Begin/End behavior. The explicit cimgui context is the standard V binding adaptation. |
| apprt string-payload formatters | `SetTitle`, `Pwd`, and `DesktopNotification` each define a public custom formatter in Ghostty, but Witty retained only their fields and C projections. | Restore all three public formatters with the exact source punctuation and unquoted payload text. The flattened V types named `PwdValue` and `DesktopNotificationValue` deliberately emit the original source type names. |
| GTK URL action handling | The GTK `open_url` action returned false when the platform launcher failed, and `open_config` likewise treated an editor-launch failure as unhandled. Ghostty's void `openUrl` helper catches that failure, so both actions remain handled once their payload/path is valid; returning false could pass the triggering key through to the terminal. | Catch and report launcher errors without changing the action result. `open_config` still returns false when the editable configuration path itself cannot be resolved, matching its source contract. |
| GTK application accessors | `Application.default` returned an optional wrapper and was paired with an invented raw `default_app` accessor, while `get_config` returned the core configuration value without the source's GObject ownership contract. | Make a missing/wrong/unwrapped default application an invariant violation, remove the unused raw accessor, and return the shared GTK `Config` wrapper from `get_config` with one caller-owned reference exactly as Ghostty does. |
| GTK startup config recovery | `Application.new` propagated `Config.load` failures and aborted before GTK could show a window, while Ghostty falls back to defaults and attaches the load error as a configuration diagnostic. | Recover with a fresh default configuration containing the exact startup diagnostic, allowing the existing GTK diagnostics UI to report the failure after application startup. |
| GTK cgroup startup diagnostics | `Application.startup` discarded cgroup hard-fail errors, so the diagnostics dialog never reported a requested isolation failure; the translated cgroup helper also replaced Ghostty's two typed error names with prose. | Restore the `cgroup initialization failed: …` diagnostic before the startup dialog check, synchronize it into both retained config views, and return the source `DbusConnectionFailed`/`CgroupInitFailed` names. |
| GTK 4.20 CSS color-scheme propagation | The style-manager handler ended with a comment claiming the GTK 4.20 branch was translated, but it never set `GtkCssProvider:prefers-color-scheme`; runtime and custom stylesheets therefore could not respond to dark/light media queries. | Restore the complete native `GtkInterfaceColorScheme` value contract and set the runtime plus every custom CSS provider to the mapped light/dark value whenever the runtime is GTK 4.20 or newer. |
| GTK config-error dialog lifetime | `Application` replaced Ghostty's `WeakRef(ConfigErrorsDialog)` with a raw wrapper pointer, manually disposed/unreferenced it, and failed to clear the cached pointer when a reload response began closing the dialog. Later config changes could reuse stale wrapper state. | Retain the native dialog through the translated GObject weak reference, acquire/release a temporary strong reference for every update or close, restore typed wrapper recovery, and clear the weak reference before reload exactly as the source handler does. |
| GTK new-window command inspection | `Application.action_new_window` checked that `new-window-command` received an array of strings but omitted Ghostty's iteration over the child variants, even though its comment said the arguments were logged. | Restore the native variant iterator, defensive per-element string type check, length-aware extraction, diagnostic logging, and child-reference release before queuing the unchanged new-window message. |
| GTK About action | `Window.action_about` always opened the legacy GTK dialog with replacement “Witty” labels and omitted Ghostty's developer, version, and issue metadata plus its libadwaita-dialog branch. | Restore the pinned Ghostty identity and URLs, translated developer/title labels, build version, full libadwaita dialog on supported versions, and the source GTK fallback on older versions. |
| GTK surface presentation ownership | `Window.present_surface` searched its local tab list but focused the requested surface and raised the window even when no owning tab was found; it omitted Ghostty's checks for detached and cross-window surfaces. | Validate the translated Surface→SplitTree→Window ownership link, require a corresponding local tab and native tab page, and return with a diagnostic before focus/presentation when any ownership check fails. |
| GTK command-palette lifetime | `Window` held a raw owning wrapper pointer and deliberately kept every command palette alive until window disposal, whereas Ghostty retains only a weak reference and the presented palette releases its self-reference when closed. The replacement also missed live config rebuilds while the palette was open. | Store the native dialog in `WeakRef`, recover its typed wrapper through GObject data only while a temporary strong reference is held, release the palette and its commands from the `closed` callback, clear only the weak reference on window disposal, and rebuild an open palette when window config changes. |
| GTK command-palette native ownership | The programmatic command-palette replacement conflated its initial/self and caller ownership into one native dialog reference, performed source `dispose` work directly from `closed`, and borrowed its config instead of owning the property reference. It also rebuilt the model and cleared search text from `toggle`, work absent from Ghostty's toggle path. | Preserve distinct self and caller references, make `dialog_closed` release only the self-reference, finalize V state from native finalization, retain/release the config property independently of command objects, and rebuild only when that property changes. Window creation now defers its caller `unref`, exactly like the source. |
| GTK key-state optional properties | `KeyStateOverlay.get_tables` and `get_sequence` returned nominally required pointers while using null as an untyped sentinel, their setters likewise hid the source's optional property contract, and `unref` mutated the V wrapper after performing Ghostty's native-only reference operation. | Expose both properties as optional pointers in their getters and full-transfer setters, derive the has-state values through those optionals, and leave wrapper memory untouched by native `unref`. Display-backed coverage exercises empty, populated, cleared, and finalized states. |
| GTK surface-title property API | `SurfaceTitleDialog` registered and initialized Ghostty's optional `initial-value` property but omitted the source's public property getter and setter entry points, leaving the native state accessible only during construction and presentation. | Restore optional get/set operations, route mutation through GObject property machinery so notification and string replacement retain the source semantics, and cover absent, repeated, cleared, and finalized states. |
| GTK surface optional API contracts | The GTK surface wrapper exposed its not-yet-initialized core and nullable horizontal/vertical adjustments as required pointers carrying null, accepted an untyped nullable on-screen-keyboard event, and omitted the source's public `setConfig`. Its scrollbar update also silently constructed a missing signal group where Ghostty asserts that a live adjustment already established it. | Restore optional result/parameter types and the public config setter, unwrap core surfaces at the same adapter/tree/window boundaries as Ghostty, and enforce the adjustment/signal-group lifecycle invariant. |
| GTK surface command-palette API | `Surface.toggleCommandPalette` was absent and application action dispatch invoked GTK's window action directly, bypassing the source's public surface boundary. | Restore the surface method and route `Application.perform_action` through it. |
| GTK scrolled-surface optional contract | `SurfaceScrolledWindow.setSurface` required a surface at the V type boundary even though the native property setter and tests passed null through an unsafe required pointer; Ghostty accepts an optional surface and uses absence to clear the child and its config binding. | Restore the optional public parameter and project it into the wrapper's nullable native storage only inside the implementation. |
| GTK readonly property source of truth | The core toggles its readonly state before emitting the runtime action, and Ghostty's `Surface.setReadonly` ignores the action value and only notifies the derived GObject property. Witty copied the payload into a second GTK-side boolean and drove the overlay from that duplicate. | Remove the duplicate field, restore the source-shaped action parameter and boolean result, and refresh the programmatic overlay from `core.Surface.readonly` after property notification. |
| GTK surface metric error boundary | The GTK GObject's `getContentScale`, `getSize`, and `getCursorPos` are infallible upstream; only the thin runtime adapter conforms them to apprt's fallible interface. Witty made the class methods fallible too and added a source-external fallback while handling GL resize. | Restore the infallible class methods, use the scale directly in the resize callback, and introduce fallibility only in the runtime callback/adapter signatures. |
| GTK nullable config property accessors | The native config properties for surfaces, scrolled surfaces, tabs, windows, and global shortcuts are nullable during property clearing and disposal, but their V accessors accepted required pointers while callers smuggled null through `unsafe`. | Give the internal property accessors optional parameters and confine projection into nullable native storage to the accessor implementations; retain required parameters on source-public config setters. |
| GTK global-shortcut connection contract | `GlobalShortcuts.setDbusConnection` accepts an optional connection upstream so the portal session can be closed and the property cleared. Witty exposed a required handle even though its implementation contained a null branch. | Restore the optional public parameter and project absence only at the native storage boundary. |
| GTK surface runtime-app lookup | The thin GTK `Surface.rtApp` adapter followed the surface widget's stored application pointer, while Ghostty intentionally ignores the surface and resolves the process-default `Application`. | Route the adapter through `Application.default().rt()` so it preserves the source invariant and cannot return a stale or non-default application backpointer. |
| GTK weak-reference API surface | The translated weak-reference wrapper added public `init` and `clear` operations that do not exist on Ghostty's `WeakRef(T)` and were used only by V tests after the target had already finalized. | Remove the source-external methods and test calls, retaining the source's zero-valued `empty`, `set`, and strong-reference-returning `get` API. |
| GTK key-event modifier boundary | Ghostty exposes `key.eventMods` and always passes the process-default application's window-protocol state, while Witty inlined the logic as a `SurfaceWidget` helper and silently fell back to generic GDK modifiers when the surface backpointer was absent. | Restore the source-level key helper, keep sided and Num Lock handling inside it, and resolve `Application.default().winproto()` at the key-event call site so initialization failures remain invariant violations. |
| GTK transient-cgroup error reporting | A failed systemd `StartTransientUnit` call freed GLib's `GError` and returned a generic error without Ghostty's error-code and message diagnostic. | Read and log the public `GError` fields before releasing the error, retaining the source fallback when no message is present. |
| GTK dialog parent optionals | `Dialog.present` and the close-confirmation, config-errors, and clipboard-confirmation wrappers declared their source-optional parent widgets as required pointers, then smuggled null through unsafe pointer values at parentless call sites. | Restore optional parent parameters throughout the base/subclass API, project `none` to native null only at the Adwaita call, and keep `SurfaceTitleDialog.present` required as its source declares. |
| GTK inspector widget API and failure boundary | `InspectorWidget.getSurface` was absent while source-public `setSurface` and `queueRender` were private; the setter propagated core inspector activation failure through `new_inspector_window` and `Surface.control_inspector`, inventing fallibility above the boundary where Ghostty logs and returns. | Restore all three public widget methods, preserve the optional weak surface, absorb activation failure with the source warning, and make inspector window construction/control infallible as declared upstream. |
| GTK command-palette jump source | `CommandPalette.collect_jump_commands` reconstructed live surfaces by walking the GTK window/tab graph instead of using Ghostty's canonical `CoreApp.surfaces` registry, so detached or transitional surfaces could be omitted and GTK bookkeeping became a second source of truth. | Iterate the translated core surface registry directly and follow each core surface's runtime user-data pointer back to its validated GTK wrapper before constructing the weak jump command. |
| GTK notification localization | The configuration-reloaded and clipboard copied/cleared toasts passed hard-coded English directly to libadwaita, omitting the source's gettext lookup. | Route all three messages through the translated `i18n_` boundary before constructing the toast. |
| GTK tab-close confirmation identity | `Window` stored one mutable `pending_close_page` for all close-confirmation dialogs, so overlapping close requests could confirm or cancel a different tab from the one named by a dialog. Ghostty carries the page as each signal callback's user data. | Pass the native tab page directly to both dialog callbacks, recover its current tab view at response time, tear down translated surface state only for that confirmed page, and eliminate the shared pending slot. |
| GTK close-action validation | The tab and window close-action callbacks silently discarded malformed external parameters instead of preserving Ghostty's missing, null, and unknown-mode diagnostics. | Restore defensive validation and source-equivalent warnings at both action scopes before dispatching a recognized close mode. |
| GTK window action and protocol diagnostics | Seven window-protocol failure paths retained only comments where Ghostty logs the error, binding and bell failures bypassed the logger, and the inspector action made a round trip through the core binding dispatcher instead of calling the active GTK surface as the source does. | Restore the source diagnostics and route inspector toggling directly to the active surface's translated `controlInspector` implementation. |
| GTK config-less tab construction | `Window.new_tab_page` returned null before constructing anything when its config property was absent, even though Ghostty creates a tab, lets its initializer inherit the application config, and appends the page. The translated computed-title fallback was also changed from `Ghostty` to `Witty` and silently accepted a missing config. | Restore application-config inheritance during tab construction, append a config-less window's tab as the source does, and preserve the source fallback title and diagnostic. |
| GTK native tab hierarchy | Active-tab recovery, quit confirmation, tab movement, and surface presentation treated the translated `Window.tabs` wrapper cache as authoritative, whereas Ghostty derives each operation from the native tab view and widget ancestors. This could reject or omit a page while libadwaita was transferring it between windows. | Recover typed tab wrappers from each native page, scan the native page count, and locate surface owners through registered `GhosttyTab`/`GhosttyWindow` ancestors before moving, selecting, focusing, or raising them. |
| GTK startup environment inheritance | `set_gtk_env` wrote `GDK_DEBUG` and `GDK_DISABLE` only when its computed flag list was non-empty. Ghostty writes both variables unconditionally, so the omission let inherited parent-process flags alter GTK renderer behavior whenever one computed list was empty. Several surrounding initialization and run-loop diagnostics were also left as comments or direct stderr output. | Always overwrite both variables, including with an empty value, and restore the source initialization, application-id, protocol fallback, run-loop, quit-reason, and source-removal logging paths. |
| GTK custom CSS diagnostics | The GTK 4.16+ CSS parsing callback omitted Ghostty's copy of the offending stylesheet bytes, and custom stylesheet loading bypassed the scoped logger and omitted the successful-load event. | Read the native CSS section bytes on supported GTK versions, append them to parse failures, and restore source-equivalent custom-CSS and startup/backend logging. |
| GTK auxiliary class diagnostics and shortcut invariants | Resize-overlay source removal, missing command-palette configuration, and global-shortcut portal responses wrote directly to stderr or stayed silent. The shortcut response path also silently tolerated a missing D-Bus connection and an already-active subscription where Ghostty asserts both lifecycle invariants. | Route the auxiliary class warnings/debug events through the logger, restore successful/cancelled portal response events and session-handle diagnostics, and enforce the D-Bus/subscription preconditions before binding shortcuts. |
| GTK Dear ImGui lifecycle | The translated widget silently accepted missing and duplicate contexts, treated OpenGL backend initialization as a new fatal branch, and destroyed the Dear ImGui context during GL-area unrealize. Ghostty asserts the realize/unrealize lifecycle, retains the context until object teardown, ignores the backend initializer's return, warns whenever a context-dependent callback runs without a context, and supplies warning default virtual methods. The source-public `setup` and `render` virtual wrappers were also folded into realize and the GL-area handler, leaving no matching entry points. | Restore the source lifecycle assertions and callback diagnostics, keep the context alive across unrealize until the V wrapper's explicit teardown, remove the invented backend-failure branch, route setup/render defaults and GL-area failures through the logger, and restore the public virtual-method wrappers used by the lifecycle handlers. |
| GTK window-protocol initialization and global lifecycle | Wayland registry/roundtrip failures and X11 XKB failures were collapsed into the same optional result as a non-matching display, causing the protocol selector to silently fall through to another or no-op backend. Wayland global removal also returned as soon as any earlier interface slot was empty, so later removed globals stayed live. Per-window native surface casts were omitted, generated-listener allocation failures were ignored, and the source Wayland/X11 diagnostics were direct stderr writes or absent. | Represent each backend probe as a result containing an explicit match flag so initialization failures propagate, scan every non-null Wayland global on removal, restore native-surface validation, clean up binding-adapter listeners on every failure, and restore the source protocol/XKB/blur/quick-terminal diagnostics. |
| GTK surface lifecycle diagnostics and clipboard invariant | Surface parent/config misuse, scale fallback, GL realize/unrealize/resize, core initialization, input callbacks, source removal, cgroup, notifications, scrolling, search, and clipboard failures were silent or bypassed the scoped logger. The clipboard confirmation denial path also silently accepted a remembered paste decision even though Ghostty treats that impossible UI state as a panic. | Restore the source log levels and detailed GL/scale lifecycle messages, the realize/init assertions and resize debug event, every translated input/action/clipboard boundary, and the remembered-paste invariant. |
| font shaper and Kitty image diagnostics | The CoreText release-thread and oversized-PNG warnings bypassed the logger, while both shapers' private position-debug functions were replaced by one translation-authored summary over an arbitrary five-codepoint window. That dropped Ghostty's cluster-neighborhood rendering, Python-style escaped codepoints, visible text, prepend-property detection, and separate position, vertical-offset, and potential-ligature reports. | Translate both debug helpers statement-for-statement against the generated Unicode property table, including surrogate padding handling in CoreText, and restore the source-selected logger severity for CoreText lifecycle and Kitty PNG failures. Native shaper tests and native/Linux checks pass. |
| Flatpak host-command and temporary-directory diagnostics | Every Flatpak setup/RPC failure bypassed the logger, the successful host-command start and exit events were absent, and failed scratch-directory removal printed a differently worded message directly to stderr. | Restore all source-selected Flatpak warning/debug events and the temporary-directory error through the translated logger without changing their recovery behavior. Native and Flatpak-enabled Linux checks pass. |
| C/Wasm configuration and C CLI diagnostics | Configuration allocation/clone failures and invalid trigger lookup were silent, all C/Wasm load/finalize/open failures bypassed Ghostty's scoped logger, and the C CLI entry omitted the successful action-dispatch event while formatting its failure differently. | Restore the source logging boundary and wording across the complete translated C configuration API, the Wasm finalizer, global initialization, and C CLI dispatch. The C API suite and native/Linux checks pass. |
| GTK runtime-action diagnostics | The runtime dispatcher silently accepted unexpected app-targeted mouse and PWD events, and silently rejected invalid split/tab targets, missing native ancestors, and every explicitly unimplemented action. Ghostty diagnoses each of those control paths. | Restore the source warnings without changing handled/unhandled results, including the source's existing `new_tab` wording on missing window ancestors. |
| GTK runtime-action routing | Close-tab, close-window, equalize-splits, and new-split bypassed the source GTK action groups and invoked translated wrapper methods directly. The dispatcher therefore reported success based on cached wrapper state instead of GTK action activation, and bypassed the same propagation path used by keybindings and menus. Its remaining window lookup also followed the split-tree wrapper backpointer rather than the native ancestor. | Activate the source `tab.close`, `win.close`, `split-tree.equalize`, and `split-tree.new-split` actions from the surface widget, preserve GTK's activation result, and recover windows through the registered native `GhosttyWindow` ancestor/private wrapper. |
| GTK application callback dispatch | GTK reload/quit actions called runtime helpers directly instead of entering through `core.App`; global surface shortcuts could leave emitted runtime actions queued; and the color-scheme handler notified surfaces before dispatching Ghostty's conditional soft reload. Callback failures and per-surface color errors were also printed inconsistently or discarded. | Route reload, quit, and global-shortcut actions through the corresponding core entry points, immediately drain their runtime actions, restore SIGUSR2's direct reload path, apply the color reload before surface callbacks, and restore source-scoped diagnostics. |
| GTK config and toplevel authority | Application config changes traversed the translated window/tab/surface caches and replaced every surface's independently derived conditional config with the app config. Window cycling and quick-terminal lookup also treated the wrapper list as authoritative rather than GTK's toplevel list. | Restore Ghostty's application-to-window GObject config binding, leave surface config ownership to core's per-surface `config_change`, and cast registered `GhosttyWindow` instances directly from native ancestors/toplevels for cycling and quick-terminal lookup. |
| GTK split action authority | Goto/resize/zoom resolved split trees through the translated surface backpointer, split zoom mutated the wrapper directly, and command-palette toggling called the window wrapper rather than the registered GTK actions. Several invalid action targets also lacked Ghostty's diagnostics. | Resolve registered `GhosttySplitTree` ancestors from the native surface widget, activate `split-tree.zoom` and `win.toggle-command-palette`, preserve GTK activation results, and restore the source target/ancestor warnings. |
| GTK core action payload lifetime | The application runtime bridge queued core actions even though action payloads such as `ConfigChange.config` are only valid for the duration of `perform_action`. A surface reload then manually installed the original config after core had synchronously emitted its surface-derived config, masking the dangling event while discarding conditional surface settings. The bridge also lacked the source wakeup callback. | Install synchronous GTK action and wakeup callbacks on the core runtime bridge, retain queue draining only for explicit headless/test events, and let core's synchronous surface `config_change` install the conditionally derived config without an application-side overwrite. |
| GTK reload ownership and logging | Hard/soft reload retained its temporary `Config` after core cloned it, open-config path failures were silent, and the GLib writer printed directly to stderr with compile-time debug filtering instead of using the application's logging backend. | Release reload temporaries after propagation, clone only for the no-core fallback owner, restore the open-path warning, and route every GLib severity through `log` so runtime logging policy remains authoritative. |
| GTK duplicate surface action dispatcher | Each core surface used a translation-authored `surface_core_action_cb` that reimplemented the application action switch with wrapper backpointers and direct method calls. Ghostty initializes every core surface with `app.rt()`, so the duplicate bypassed native GTK action routing, ancestor validation, application diagnostics, and correct surface `config_change` ownership. Core app reload bindings also emitted a void payload that could never match the required default `ReloadConfig` value. | Initialize core surfaces with the application's synchronous runtime bridge and delete the duplicate dispatcher/wakeup path, leaving `Application.perform_action` as the single source-translated action implementation; emit the source default hard-reload payload from core bindings. |
| Hard-reload action payloads | Surface keybindings and the runtime-neutral core fallback still forwarded `reload_config` as `ActionVoid`, so their events could not match the required `ReloadConfig` payload even after the main `core.App` path was corrected. | Forward `ReloadConfig{soft:false}` from every hard-reload binding path and cover both app and surface dispatch with focused payload tests. |
| GTK new-surface configuration | The translated `apprt.new_config` helper matched Ghostty's focused-surface working-directory inheritance, but it accepted only the embedded-runtime app adapter and GTK initialized surfaces with a plain config clone. A parent-provided PWD masked this for normal tab/split creation, while parentless context creation could silently retain the base working directory. | Express the helper's focused-PWD dependency as a shared app capability implemented by both canonical and embedded core apps; build GTK surface configs through it with the stored creation context, apply the source's font/PWD overrides afterward, and deinitialize the temporary config after core initialization. |
| Terminal unsupported-operation diagnostics | Unsupported OSC dynamic/special color mutations, resets, and queries plus unknown erase-line modes silently returned, while Ghostty logs each protocol limitation at its source-selected severity. | Restore the info/warning/error diagnostics on every corresponding branch without changing Ghostty's intentionally unimplemented protocol behavior. |
| Surface selection-string contract | `Surface.selection_string` swallowed formatter failures into `none` and treated a valid selected empty string as if no selection existed. `search_selection` could therefore reject an action that Ghostty performs with an empty needle. | Restore the fallible optional return contract with an explicit result value because V cannot spell `!?string`, preserve empty selected text, propagate errors through binding dispatch, and cover the no-selection/empty-selection distinction directly. |
| OSC 52 clipboard-write decoding | Surface clipboard writes used V's permissive Base64 decoder, which returns empty or arbitrary bytes for malformed input, and propagated runtime clipboard failures even though Ghostty diagnoses and absorbs them. | Validate padded standard Base64 shape/alphabet, decode through the translated scalar path while preserving Ghostty's accepted noncanonical trailing-bit case, ignore malformed writes, and catch runtime clipboard failures at the source boundary. |
| Surface link opening | Link activation reused `clipboard-trim-trailing-spaces`, swallowed selection-format errors, skipped empty URL actions, and silently used the fallback opener/missing OSC 8 branch. Ghostty formats link selections with `trim=false` independently of clipboard policy and keeps those diagnostics. | Restore untrimmed fallible link formatting, dispatch every selected URL, and restore the fallback-opener and missing-OSC-8 warnings. |
| Clear-screen binding payload | The `clear_screen` binding queued `MessageClearScreen{history:false}`, while Ghostty explicitly requests `history=true`; the keybinding therefore cleared only the visible screen rather than the scrollback history promised by the action. | Restore the source payload and assert the exact queued termio message. |
| Binding-action dispatch exhaustiveness | Surface dispatch ended in a permissive catch-all that reported every omitted action as handled, and app dispatch silently ignored surface-scoped actions. Ghostty narrows both switches with `Scoped(...)` and exhaustively handles the resulting unions. | Explicitly list the app-only variants excluded from the surface switch and make a wrong-scope app dispatch unreachable, preserving source exhaustiveness despite V's lack of dependent union types. |
| Clipboard binding failure boundaries | After a successful copy, selection-clear and render-notification failures escaped the binding even though Ghostty diagnoses and absorbs them. URL/title clipboard failures had the right booleans but silently discarded the source diagnostics. | Restore the catch-and-log boundaries for post-copy cleanup and both clipboard actions, retaining `false` for a failed URL copy and `true` for a failed title copy. |
| App failure and invariant diagnostics | Quit-timer actions, chained/app keybindings, per-surface broadcasts, conditional-config failure, and desktop-notification suppression discarded Ghostty's diagnostics; app key dispatch also converted the source's nonempty-leaf assertion into a silent `false`. | Restore every catch-boundary warning and notification suppression message, plus the source assertion and focus/quit lifecycle diagnostics. |
| OSC 52 read completion helper | `completeClipboardReadOSC52` was folded into the public request switch, which changed the source's impossible-denied-state assertion into a normal authorization error and omitted the denied-request diagnostic. Paste rejection/scroll and selection-copy failures also bypassed the translated logger. | Restore the dedicated read-completion function, its assertion and empty-response behavior; keep authorization in request startup/confirmation and restore the corresponding source diagnostics. |
| Surface catch-boundary logging | Search, config, shutdown, runtime notification, key sequence/table, renderer, child-exit, and input catch blocks wrote directly to stderr, losing Ghostty's selected log levels and structured logger routing. | Route every remaining Surface catch diagnostic through `log.error`, `log.warn`, or `log.info` at the severity chosen by the pinned source. |
| Embedded queued-action delivery | The translation-only runtime bridge silently swallowed action-delivery failures and converted an unknown/stale surface target into an app target. Ghostty dispatches synchronously to the original typed target, so it can never broaden a surface action this way. | Make bridge flushing fallible, propagate it at fallible source boundaries, log it at source catch boundaries, and drop stale surface-targeted actions instead of retargeting them app-wide. |
| Windows subprocess command construction | `Subprocess.init` always chose `sh` as its default command, and `exec_command` sent every non-macOS shell command through `/bin/sh`, omitting Ghostty's complete Windows branch and its fatal missing-environment boundary. | Select `cmd.exe` by default on Windows, build shell argv as `%WINDIR%/System32/cmd.exe /C <command>`, clone direct argv unchanged, and propagate a logged `SystemError` when `WINDIR` is unavailable. Native and Linux checks pass; the Windows checker reaches the already-recorded xev platform gaps without reporting an error in the restored branch. |
| subprocess argument formatting | The translated startup log interpolated the raw V argument array, replacing Ghostty's `ArgsFormatter` and changing the diagnostic's structure and quoting. | Restore the private formatter so every argument, including spaces and empty strings, is independently backtick-quoted and comma-separated exactly as the source writes it. |
| stream-handler stable replies and tmux invariant | XTGETTCAP copied generated table replies into owned/small messages instead of using Ghostty's stable-storage arm, and a second tmux enter event silently destroyed and replaced the active viewer rather than asserting the protocol invariant. Tmux/Kitty keyboard/graphics, ENQ, XTVERSION, and unsupported tertiary-device events also omitted the source diagnostics. | Send XTGETTCAP's process-lifetime table strings through `write_stable`, enforce the single active tmux viewer, restore the nearby source logs, and route charset/reset behavior through the translated source helpers. |
| OSC 7 and title validation diagnostics | Oversized window titles and every invalid OSC 7 boundary were silently ignored; hostname lookup errors were collapsed into an ordinary nonlocal host, and Windows entered URI/path handling that Ghostty explicitly marks unsupported. The empty-PWD reset also omitted the source's post-title invariant. | Restore the oversized-title, parse, scheme, missing-host, hostname-error, nonlocal-host, Windows, and successful-path diagnostics, preserve hostname lookup errors, and assert that an automatic title reset leaves `seen_title` false. |
| stream-handler color response boundaries | OSC color queries accumulated into an unbounded V string instead of Ghostty's 1024-byte fixed allocator, dynamic foreground/background absence silently suppressed a reply instead of enforcing the source invariant, and Kitty OSC 21 replies selected the small-message arm rather than transferring their allocated writer buffer. Unsupported Kitty color keys were also silent. | Enforce the fixed response capacity before queueing any partial result, retain the required-color assertions and cursor fallback, send Kitty query output through `write_alloc`, and restore all three unsupported-key warnings. |
| stream-handler cursor saturation and APC boundary | Relative row/column actions widened the operands before ordinary addition instead of preserving Ghostty's `u16` saturating `+|` intermediate in both live and readonly handlers. Terminal clamping made current endpoints equivalent, but the translated operation itself differed. Kitty graphics response encoding also lost the caller's 1024-byte fixed-writer error boundary and weakened its source length guard. | Saturate both relative coordinates at `u16` maximum before terminal clamping, reject graphics encodings beyond the pinned stack capacity, and retain the exact greater-than-two emission condition. |
| stale Keybind formatter coverage gap | The Keybind test section still claimed the configuration formatter was untranslated and omitted the pinned single, multiple, nested, table-only, and mixed root/table formatter cases, even though the formatter implementation had since been restored. | Remove the obsolete scope claim and translate all five pinned Keybind formatting tests against the live generic entry formatter. |
| renderer swap-chain frame selection | Witty initialized the current frame index to `-1` and advanced it only after fallible shader/custom-state preparation. Ghostty initializes it to zero and `nextFrame` advances immediately after acquiring the semaphore, so Metal's first slot and the round-robin position after a preparation failure differed. | Initialize at zero, select the next frame immediately after semaphore acquisition on both renderer backends, and perform all subsequent preparation through that selected frame. The off-screen Metal frame test now pins the source's first-slot behavior. |
| renderer shader-reload failure state | Both renderer backends initialized a replacement shader set before deinitializing the active one, preserving the old pipelines if reload failed. Ghostty deinitializes first and then calls the fallible initializer, leaving the shader set defunct after failure instead of silently continuing with stale shaders. | Restore the source operation order on Metal and OpenGL: clear the reload flag, deinitialize the current set, load the requested sources, and assign only the successfully initialized replacement. |
| renderer realization and focus state | OpenGL display realization rebuilt the shader set but did not update `has_custom_shaders` before constructing its replacement frame state, so an unrealize/config-change/realize sequence could retain the previous shader mode. `setFocus` also omitted Ghostty's assertion that callbacks represent actual transitions. | Derive the custom-shader flag from the newly loaded sources before initializing the swap chain, and restore the focus-transition invariant with direct state coverage. |

## Focused behavior reviewed

The following areas have received focused source comparisons and regression
tests. This list does not certify their entire modules or their representation
and ABI boundaries as one-for-one translations.

terminal: color, csi, ansi, dcs, apc, charsets, device_status, tabstops,
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
keycodes (243/243), command, binding (83-tag order), key (logic),
function_keys, keyboard, mouse, paste, Link.
kitty: graphics_command, graphics_unicode, graphics execution/storage. renderer:
cell, cursor, size, row, Atlas, shader cell layouts. Both graphics backends
are now compared function-for-function against the pinned tree: the Metal
wrappers api/buffer/Pipeline/RenderPass/Sampler/Target/Texture/IOSurfaceLayer/
shaders (pipeline table, vertex attributes, and the Uniforms/CellText/CellBg/
Image/BgImage ABI structs) and the OpenGL wrappers Frame/Pipeline/RenderPass/
Sampler/Target/Texture/buffer/shaders, plus the `Metal.zig` and `OpenGL.zig`
API surfaces, including Metal's asynchronous command-buffer completion block.
datastruct: CircBuf, ArrayListCollection, CacheTable, comparison,
IntrusiveDoublyLinkedList, LRU HashMap, SegmentedPool. ssh: cache Entry/DiskCache. tmux:
control, layout, output.
termio: exec, shell_integration, stream_handler. simd: index_of, base64, vt.
synthetic: Bytes, Generator, Utf8, Osc, and all three CLI actions.
terminfo: Source encoding, XTGETTCAP map generation, and the complete Ghostty
capability table (also covered by the pinned build-data SHA-256).
crash: Sentry envelope parsing/serialization and attachment encode/decode.
config theme: location iteration, named/absolute lookup, and diagnostics.
benchmark: lifecycle, CLI/data-file helpers, CodepointWidth, GraphemeBreak,
IsSymbol, TerminalParser, TerminalStream, ScreenClone, and OscParser.
native image wrappers: stb and Wuffs PNG/JPEG decoding plus pixel swizzling.
root: quirks, build_config, file_type, fastmem, math,
opentype (all 6 tables), cli_args, split_tree, command (POSIX). apprt: structs,
none, browser, action, ipc. dependencies: zf 0.10.3 ranking/highlighting.

## Remaining known divergences (NOT yet fixed)

- **vaxis screen and terminal session:** The theme preview now draws into the
  translated `Cell`, `Screen`, and `Window` values and uses the session render
  diff. The translated session has terminal capability and option state, pinned
  query bytes, feature enablement, resize/reset control, pixel-mouse
  translation, and a cell render diff with source style, link, image placement,
  scaling, cursor, and synchronized-output sequences. Clipboard, title,
  notification, color query/set, scheme subscription, and Kitty image
  transmission/control sequences are now translated, along with image cell
  sizing and placement, working-directory control, pretty printing, and
  capability/F3-probe event interception. The preview sends the pinned
  capability query, waits up to one second for DA1, enables detected features,
  and renders the retained screen. The pinned event queue ring and wrapping
  grapheme cache are translated. On POSIX, the preview now opens `/dev/tty`,
  applies the pinned raw termios flags until deinit, reads input bytes from that
  descriptor, queries its winsize, and writes session output there. A reader
  thread now feeds the translated bounded event queue and is stopped with the
  pinned device-status wakeup. The POSIX TTY installs a SIGWINCH handler, the
  loop registers its resize callback and posts the initial winsize, and parsed
  in-band resize reports reset that handler. The preview blocks on the queue
  between renders. Parsed input is now intercepted on the reader thread before
  posting application events, including DA1 query completion; its cross-thread
  completion flag is atomic. The preview now uses a blocking capability query
  with a timed DA1 wakeup, leaving application events in the loop queue. The
  loop is now generic over application event sum types, with compile-time
  terminal subscriptions, application-event posting, and borrowed key text
  from the reader's wrapping cache. POSIX shutdown now completes on an ignored
  device-status reply instead of requiring an application event. The live POSIX reader now uses the source's fixed 1,024-byte buffer,
  including its incomplete-sequence offset/read-count quirks. The public parser
  borrows ground text from input and CSI text from its inline 128-byte scratch
  buffer, propagates OSC errors, and uses the locked uucode UTF-8 decoder.
  Windows embedded ANSI decoding also uses inline 128-byte state. Thread creation is now fallible with the
  source's default stack size and native allocation/join lifecycle. Windows now owns the pinned
  console mode/code-page lifecycle and handle-based output/winsize query; its
  threaded input path decodes native `INPUT_RECORD` key, mouse, resize, and
  focus events. `boo` now uses the same generic loop through `vxfw.App`.
  The retained source-external `Tty.poll` adapter still uses V's key polling
  on Windows, but neither interactive CLI calls it.
  High-level path/memory image loading and decoded-image transmission are now
  implemented in `vaxis/image.v`, including the source's premultiplied
  conversion and PNG/raw transmission. The locked zigimg dependency now has
  automatic codec dispatch and memory/file loading; remaining coverage is below.
  Pinned vaxis width data and all three `gwidth.Method` algorithms are
  available.

These are confirmed structural boundaries or larger refactors. The absence of
an item here does not mean its full module has been certified yet.

- **zigimg image dependency:** The translation now pins
  `d7b7ab0ba0899643831ef042bd73289510b39906`, with all 24 pixel-format tags,
  storage variants, raw initialization/slices, palette capacity operations,
  memory/file and bit streams, QOI/farbfeld/PBM/PGM/PPM/PAM/RAS/SGI/XBM/PCX/BMP/IFF/GIF/TGA/JPEG codecs, image editing,
  pixel iteration, PackBits/LZW/CCITT compression helpers, and the octree palette
  quantizer, pixel-format converter, managed image construction/editing
  methods, image-wide encoder options, managed/unmanaged fixed-memory writing,
  memory/file format detection and loading/reader dispatch, file writing,
  TIFF metadata/IFD/strip decoding, and PNG header/filter/processors,
  complete IDAT/Adam7 reading, and information diagnostics.
  The source PNG writer is translated
  as it actually exists: it emits only the eight-byte signature because its
  chunk-writing bodies are commented out. A native Zig 0.15.2 reference harness
  verifies those codec behaviors and bytes without modifying the source. The
  pinned RAS, SGI, XBM, IFF, GIF, JPEG, and TIFF writers succeed without
  emitting bytes; that is also preserved.
  SGI retains the source's RGBA64 alpha byte indexing and endian swap,
  grayscale8 storage for 16-bit grayscale, and unclipped RLE scanlines.
  PAM preserves little-endian 16-bit samples, monochrome-alpha AND, subsequent
  animation frames, comments, and the source's absent grayscale2 writer arm
  after successful header construction. Its duration formatter uses V's Ryu
  mantissa conversion with Zig decimal/sign placement; a native reference hash
  matches 19,968 boundary and deterministic sampled float bit patterns.
  XBM preserves continuous bits across rows, zero-sentinel hotspots, ignored
  unterminated data lines, and the pinned detector's non-advancing peek loop on
  a leading define line. Separate V/Zig probes with a 250 ms process timeout
  verify that loop; direct decoding tests bypass it as the source reader does.
  PCX preserves its 16-bit extent overflow boundary, ignored compression flag,
  stride and partial-byte quirks, end-relative palette seek, and the fast
  encoder's run accumulation across distinct 16-byte blocks. That encoder uses
  scalar comparisons in place of source SIMD vectors; `reserved0` replaces
  the source field name `_reserved0`, which V rejects. Source PCX pixels left
  unwritten by zero/undersized strides or skipped RGB zeros remain undefined
  allocator memory; V storage starts zeroed. Comparisons cover defined output
  bytes and do not certify identical behavior for those uninitialized pixels.
  BMP supports the source's V4/V5 BGR24/BGRA32 paths, including immediate pixel
  reads, ignored color masks, absent row padding, bottom-up rows, and the
  writer's unconventional V5 masks. Windows 3.1 headers remain unsupported
  after being consumed. Signed dimensions are retained; negative-height reads
  can leave allocated pixels unwritten, with the same zero-initialization
  boundary described above. Default `BMP` headers use initialized V values in
  place of source `undefined` fields, which callers must initialize before use.
  IFF preserves PBM's raw-prefix copy, ILBM/ACBM planar ordering, Atari ByteRun2
  column runs, HAM6/HAM8 component updates and per-row reset, and EHB expansion
  before HAM reduction. The source ignores FORM/BODY lengths in its raw paths,
  does not consume odd-byte chunk padding, and does not clip planar set bits at
  image width. It rejects DEEP detection while retaining a zero/non-consuming
  DEEP header helper. Separate probes verify the source's checked row-stride
  overflow, set padding-bit bounds, empty CMAP, and invalid HAM palette bounds.
  Source default IFF headers and inactive palette entries are undefined;
  incomplete PackBits input can also leave temporary planes unwritten. V
  initializes this storage, so comparisons certify defined outputs only.
  IFF's public header debug hooks now preserve the pinned anonymous-record
  payload syntax and field/enum presentation through V's logger. Default levels,
  logger routing/prefixes and allocation remain host-language adaptations.
  GIF preserves frame grouping by animation extensions, filtering of frames
  without graphic controls when any control exists, independent rendered
  frames with the image sharing its first frame, and all disposal methods.
  Small palettes remain indexed even with transparency; palette alpha stays
  opaque. Multiple local palettes overwrite the output palette in order.
  Interlaced sub-images use canvas height, horizontal positions use linear
  bounds, and RGBA initial background channels follow the source's u32Rgb-to-
  u32Rgba conversion. Background disposal uses the transparency palette color
  with opaque alpha. The source ignores graphic/application block sizes and
  graphic terminator values, scans unknown extensions to their first zero,
  skips only one plain-text sub-block, and ignores LZW writer overflow.
  Its plain-text count of 255, out-of-buffer toss, short animation-loop data,
  and narrow indexed background cast retain checked traps. Packed GIF flags
  use byte words/accessors; its nonexhaustive disposal enum uses wider backing
  values. GC replaces the arena and allocated record lifetimes; the codec and
  record `deinit` methods therefore do not reproduce allocator reclamation.
  Source default magic/version, absent color-table entries, incomplete comment
  entries, and pixels left unwritten by short LZW data can be undefined. V
  initializes them; comparisons certify defined outputs only.
  TGA retains packed metadata/extension bytes, grayscale/indexed/RGB555/BGR/
  BGRA decoding, seven encoder storage types, row ordering, raw/RLE packets,
  and 512-byte read-ahead with source positions and failed-stream buffering.
  Detection checks footer dot/null values while reading checks only its
  signature; reading requires 26 bytes even for 1.0 images. Palette origins
  index the active slice directly, image origins/right-to-left are ignored,
  and extension attributes other than useful-alpha force opaque pixels.
  Writing accepts a 256-byte ID but truncates its length to zero and omits it;
  metadata names are limited to 39 bytes by source sentinel-array lengths.
  Direct-storage RLE splits runs at rows and SIMD tails, while converted RGB/
  RGBA retains runs across rows. Scalar comparisons match the pinned baseline
  amd64/arm64 vector lengths; other Zig CPU-feature selections remain a build
  configuration boundary. Sentinel record fields use physical V byte arrays
  and option names use strings, without Zig's sentinel type contract. Source
  undefined RGB555 padding bits, default footer signatures, and incomplete
  ID storage are initialized in V; comparisons exclude undefined output bits.
  The octree quantizer now retains linked per-level lists, checked leaf sums,
  wrapping reduction sums, weighted floor averages, palette traversal/order,
  borrowed output, and first-child fallback for colors absent from the tree.
  A sufficient palette budget leaves the tree intact; reduction skips level
  zero, and a zero budget emits no entries while lookup retains default zero
  indices. Repeated reduction can encounter collapsed nodes and trap on a
  negative removed-leaf cast; output capacity is checked by indexed writes.
  Input normalization preserves the f32 round-trip for integer alpha,
  intermediate 16-bit quantization before narrowing, packed channel scaling,
  and NaN upper clamping. GC replaces the arena and allocation failures;
  the root now remains inline, preserving independent copied root metadata
  with borrowed child and level pointers.
  Source `allocateNode` returns uninitialized storage until `Node.init`, while
  V allocation initializes it. Generic input covers translated RGB(A) types,
  rather than arbitrary caller structs with Zig's color-method namespaces.
  The pinned V compiler also emits invalid default formatters for recursive
  fixed pointer arrays; pointer assertions use `voidptr` to avoid that path.
  Tests compare defined behavior; allocator/lifetime and aggregate ABI parity
  are not certified. The pixel-format converter now retains all 460 pinned
  table entries through the same conversion groups. Indexed-to-grayscale and
  RGB(A)/float-to-grayscale16 remain unavailable. Nine BGR555 entries select
  the source's wrong RGB555 union arm and trap, including for empty storage.
  Integer downscaling truncates; widening rounds. Integer alpha drops through
  f32 with quantization back to its source width before RGB conversion;
  grayscale alpha drops directly through f32 instead. The table's rgba-to-
  RGB332 path retains straight channels, indexed-to-RGB332 premultiplies, and
  rgba64-to-BGRA32 premultiplies while retaining alpha. RGB-to-grayscale-alpha
  normalizes alpha through f32, rather than narrowing its integer bits.
  Indexed quantization reads every active source palette entry and retains
  the full returned palette with opaque black tail: the source shortens only
  a local IndexedStorage copy. SIMD float-to-byte prefixes truncate, whereas
  their scalar tails round/clamp. Four allocated empty float conversions trap
  on unconditional f32 alignment casts. Empty float allocation retains the
  source's maxInt(usize) align(1) sentinel, as does empty raw initialization.
  Empty views sliced from float storage can pass with aligned pointers.
  Unaligned float input traps. Scalar NaN scaling
  clamps upward, while the pinned Zig/ARM64 SIMD
  float cast emits zero for NaN without trapping. That cast's behavior on
  other targets/compiler modes, and CPU-feature-specific vector lengths,
  remain build/representation boundaries. Individual native page allocations
  satisfy the source's destination alignCast; an align(1) arena may not.
  V GC allocation/alignment does not reproduce caller-selected allocators.
  Image convert/convertNoFree replace only the main pixels, leave animation
  frames unchanged, and return early for the current format. GC replaces the
  source's distinct old-storage freeing contracts.
  Managed/unmanaged views retain shared pixel, palette, and animation-frame
  backing data with independent slice lengths and scalar metadata. Iterators
  point at the live managed pixels through replacement. Raw creation copies
  input without validating dimensions against its length; cropping drops
  animation. Fixed-memory image writing dispatches all 17 encoder tags and
  returns a borrowed prefix, preserving buffer mutation on errors. Dimension
  multiplication and zero-height row/flip checks retain source traps.
  The managed image has no allocator field and delegates explicitly rather
  than reproducing the source's prefix layout and pointer cast to unmanaged
  storage. Lifecycle hooks retain the skipped shared first animation frame,
  but GC replaces all explicit reclamation. Encoder options use a V sum type
  with empty markers for void arms and distinct PBM/PGM/PPM wrappers; Format
  uses a byte instead of the source's u5 tag. These aggregates are not ABI
  aliases. V byte arrays also lack the source's read-only slice type contract.
  In-memory detection visits all 17 source detectors in declaration order,
  seeks before each, and propagates errors from earlier signature checks;
  a short valid JPEG/GIF/TIFF signature can therefore fail before its detector.
  TIFF checks only II/MM byte-order markers and suppresses peek errors; TGA
  can win before TIFF, including through its footer on an invalid header.
  Unknown inputs without a newline can fail in XBM's final delimiter peek,
  while leading define lines retain its non-advancing loop. JPEG now has its
  frame/table/scan reader and baseline/progressive/restart paths. The later
  native comparison matches 132 result rows in ordinary/production builds;
  seven cases involving inherited undefined coefficient state remain excluded.
  Its eighth former exclusion, a restart-input marker failure, now matches as a
  checked enum trap. A separate strict JPEG comparison covers 15,805 returning
  cases, thirty panic/state pairs and three file-discard loops in both modes.
  Quantization Header.read itself has an inherited u8-to-u4 compilation failure
  under Zig 0.15.2; the decoder's actual table parser compiles and is covered.
  Public component/header/Huffman records now have required mutable represented
  fields, component reading and cleanup hooks, usize sampling maxima and tagged
  quantization arrays. A further comparison matches 17,747 observations and
  constructor controls in both modes. Eighteen boxed-copy differences, one
  const-slice difference and five wider-carrier controls remain separate.
  Public Frame records and operations now match another 10,697 observations,
  35 exact panic/state pairs and three inherited zero-step loops in both modes.
  Frame copies preserve value metadata and borrowed coefficient/table storage;
  table records expose fixed four-slot arrays. This does not certify undefined
  memory or allocator/lifetime behavior. Public Scan records and entry points
  now match 76,400 further observations and 27 panic/state pairs in both modes,
  including destination bounds before entropy fill and checked MCU/restart
  arithmetic. Const-pointer and wider integer carrier differences remain separate.
  TIFF now has its packed 6/12/10-byte records, all 32 tag IDs, IFD parsing,
  bitmap metadata processing, format selection, and row-byte sizing. IFDs
  preserve duplicate replacement, next-directory offsets, and partial-read
  positions, with unknown tag IDs retaining checked enum traps. Tag arrays
  return the raw inline word for count one even for a big-endian SHORT; longer
  arrays decode their byte order. Non-SHORT/non-LONG arrays retain the source's
  checked parallel-loop length mismatch. Short reads succeed with an undefined
  tail in the source; V initializes it, and comparisons exclude that tail.
  Metadata retains default bits-per-sample initialization, truncation of
  component arrays to u16, ignored fill-order and orientation tags,
  planar/sample fields, rational pairs, and palette
  component scaling. Palette size uses the bits value present when its tag
  is visited. The IFD map therefore reproduces Zig 0.15.2 Wyhash placement,
  load thresholds, duplicate-triggered growth, reservation, and bucket-order
  iteration: pre-reserving capacity can make the palette precede the bits tag.
  The one-bit row helper shifts width by three without rounding up; other
  supported totals truncate bits to bytes. Four-bit formats and unsupported
  compression kinds remain rejected. RGB/RGBA selection uses the bits-array
  length independently of samples-per-pixel, while row sizing uses that field.
  Missing component/alpha data, invalid
  enums, fixed capacities, palette powers, and tag-byte arithmetic retain
  checked traps. GC replaces optional-strip-array and map reclamation; V slots
  track usage and compare full keys in place of the source's packed metadata
  and fingerprints. The source's full general-purpose HashMap API is not
  exposed. Endian uses byte backing for
  the source's u1 tag. Undefined default TIFF fields/fixed storage initialize
  in V. Metadata and SGI/IFF header debug hooks are available through the V
  logger, with host-specific generic rendering and logger selection. These
  aggregate, diagnostic and lifetime boundaries are not ABI certification.
  TIFF's read/readImage and strip paths now cover grayscale1/grayscale8/indexed8/
  RGB24/RGBA32 with uncompressed, PackBits, CCITT RLE, LZW, DEFLATE, and Pixar
  DEFLATE. Versions are read without validation; only the first IFD is decoded.
  Strip byte counts constrain only PackBits. Other paths read from the strip
  offset through their own stream termination, retaining read-ahead and partial
  input positions. Predictor values other than one apply wrapping horizontal
  differences except at row starts; grayscale8 does not invert photometric
  zero. One-bit rows retain floor byte sizing, continuous bit expansion,
  and pixels left unwritten. Clipping occurs after each write. The CCITT helper
  truncates photometric interpretation to its low bit before the source decoder.
  Compression helpers map decode/write errors to InvalidData; PackBits retains
  its errors and checked bounds directly. Strip-count and image-pixel products
  retain u32 overflow checks, absent optional-array traps, zero-row division,
  and checked strip/pixel/channel/palette bounds.
  The private TIFF zlib adapter translates the pinned Zig 0.15.2 indirect-reader
  path with a 64 KiB output window and 32 KiB retained history. Stored/fixed/
  dynamic blocks preserve their distinct yield/error points, word-sized input
  read-ahead, byte alignment, and consumed trailer. The source checks only the
  first zlib header byte; FCHECK/FDICT and the Adler32 value are ignored.
  A fixed-block match crossing the window retains the source's unreachable
  writer-rebase trap. The source's small Huffman lookup, sorted alphabet, and
  linked fallback are now restored; GC owns these and the window. Generic
  input paths cover memory, file, and the PNG buffered IDAT reader. This
  adapter does not expose Zig's general flate API, raw/gzip containers, or metadata.
  Source short strip/output tails and unfilled pixels are undefined; V starts
  them at zero and tests compare defined data. Source read defers reclaim IFD
  maps and strip arrays while leaving scalar metadata; V keeps GC-backed data.
  PNG now has the source's 17 chunk constants, packed chunk header with a
  borrowed native-order name view, IHDR loading with exhaustive color/interlace
  enum validation, and its IEEE CRC. Unnamed compression/filter bytes are
  accepted as in the source's non-exhaustive enums. Header helpers preserve
  checked u8/u32 arithmetic. Filtering packs sub-byte samples, swaps native
  16-bit words to big endian, preserves pixel-stride neighbors, and maps fixed
  writer failures to InvalidData after retaining written prefixes. The
  heuristic uses the entire row length as its horizontal stride and omits
  unfinished final runs; TryAll traps only after a nonempty row is filled.
  Defiltering and spreading preserve byte wrapping, unscaled sub-byte samples,
  untouched channel gaps, and optional word swaps; complete PNG loading now
  uses those helpers.
  Reader callbacks preserve initial chunk-ID matching, all critical
  notifications, first-only ancillary processing, stride-growth checks,
  palette ordering, and row source-format restoration only after success.
  The one/two-processor generic options borrow their inline callback arrays
  and embedded live contexts. tRNS skips CRC validation, allows replacement
  chunks until palette/row processing, keeps partial indexed-alpha writes,
  and compares a byte at each u16 sample index in the gray16 path. Its RGB24
  direct API retains the zero-stride loop for grayscale-alpha destinations.
  PLTE borrows the live palette and writes RGBA8 bytes even for BGRA32/RGBA64
  destinations. Source processor palette/default storage and failed scalar
  tRNS union assignments can be undefined; V initializes them and preserves
  the old scalar arm after a failed read. Comparisons exclude undefined state
  and alpha tails. The wasm checked-multiply branch is translated but not run.
  V string/array headers replace Chunk's sentinel pointer and read-only name
  slice. Explicit opaque-context callbacks and GC-backed vtables replace
  generated typed-pointer adapters/static tables; allocator selection,
  NoopAllocator, getWithTempAllocator, and root DefaultPngOptions overrides
  are not exposed. PNG load/loadWithHeader, readImage, consecutive IDAT
  buffering, and Adam7 now follow the pinned chunk walker and zlib reader.
  Each IDAT CRC is checked during read-ahead before notification; callbacks
  for later consecutive IDATs retain the first chunk's length. Empty IDATs
  retain source termination behavior. IEND ignores its length and CRC;
  unknown critical chunks are not automatically skipped. Adam7's byte-sized
  destination row can overflow even after the last row of a pass. Repeated
  16-bit tRNS chunks can shrink the chosen format and trap. File buffers that
  rebase while reading IHDR's CRC can overwrite the borrowed header payload
  and reject a valid image; the 16/31-byte fixture reproduces this in both
  implementations. PNG's direct generic chunk writer now preserves fixed
  inline storage, empty flushes, oversized writes that bypass framing after a
  flush, call order, and retained buffers on partial failures. The unchanged
  legacy writer() adapter and ZlibCompressor fail to compile with Zig 0.15.2's
  removed standard-library APIs; those inherited unsupported boundaries remain.
  PNG information diagnostics now translate every known/unknown chunk branch,
  palette counts, IDAT totals, and shortest f64 binary byte-size formatting.
  Text/iTXt inspection retains a 1,024-byte limit and zTXt an 81-byte initial
  read. iTXt prints compressed data without decoding; unknown zTXt methods
  leave the remainder after that initial read and skip only four further bytes.
  The known method uses the same 64 KiB buffered zlib state machine as TIFF,
  with 1,024-byte short reads and propagated input/error positions. Ancillary
  CRCs are skipped without verification. Every diagnostic write failure is
  swallowed, returns the current format, and can leave payload/CRC bytes
  unconsumed. Source capitalization, spaces, separators, and misspellings are
  retained. Missing delimiters/fields, enum tag names, and counter sums retain
  checked traps. This processor accepts the translated memory/file writer;
  arbitrary std.Io.Writer interfaces remain absent. GC
  scratch/format strings replace stack storage and streaming format calls;
  allocation errors and the general Zig formatting API are not reproduced.
  Public FormatInterface callbacks and all 17 codec factories now drive the
  live detection/loading/writing registry. The source's reflected factory
  table becomes an explicit V table; allocator callback arguments remain
  omitted under GC ownership. Public built-in color constructors/getters and
  scaling are translated; caller-selected allocator contracts remain adapted.
  Arrays use GC ownership and V length fields in place of allocator slices;
  allocation failures are not reproduced. Sub-byte scalar fields/indices use
  bytes or backing words, sum variants have named V wrappers, and nested
  declarations use module-level names. The shared inline `FixedStorage` helper
  has 8- and 256-element specializations and a general FixedStorage[T, B]
  inline-array API: a storage type replaces the integer factory parameter.
  Empty slices represent zero capacity. SGI/IFF header and TIFF metadata
  debug hooks use the standard V logger and generic struct rendering, whose
  type names/enum names/presentation differ from Zig's. Bit streams support V's native integer
  and floating point scalars, with type markers for compile-time endianness;
  Zig arbitrary-width integers and other bit-castable types are not reproduced.
  Compression helpers use wider backing values for the source's `u13`, `u4`,
  and `u1` state, preserving their checked bounds and truncation where used.
  LZW dictionary storage uses V maps and GC instead of an allocator-backed
  array hash map and arena. Its free `lzw_decoder_init[E]` constructor supports
  calls from generic functions, where the pinned V compiler mis-specializes
  the static constructor; concrete static calls remain available.
  This is an incremental dependency translation, not certification of the
full library or every vaxis image-loading branch.
- **vaxis widget framework representation:** All pinned `vxfw` widgets and
  the `boo` widget pipeline are translated. Frame buffers, command arrays, and
  layout temporaries use V GC ownership in place of explicit allocators and
  per-frame arenas; allocation failures are not exposed. The source's signed
  `i17` coordinates use `i32`, spinner atomic values use V atomic wrappers,
  nested source declarations have module-level V names, and widget callbacks
  retain opaque user-data pointers. Public APIs that allocate therefore do
  not reproduce the source's allocator arguments/failure modes. Native event
  routing/layout/timer tests and a PTY application smoke pass; Windows runtime
  behavior remains untested. These representation limits do not certify
  identical layouts or lifetime/failure contracts.
- **vaxis framework remaining boundaries:** ListView/ScrollView retain wider
  `i32` storage for source `i17` values, with explicit checked operations;
  Spinner retains a `u8` carrier for source `u4`, with checked increments and
  indexing. Wider explicit initializers remain representation differences.
  Spinner atomic values are embedded so ordinary copies are independent, but
  V's stronger atomic ordering and raw-field API do not reproduce the source
  atomic interface or ABI. Both scrolling widgets inherit empty-builder loops
  and a source branch that deinitializes then reuses its child list; the latter
  is excluded from defined-behavior parity and V retains managed storage.
  Core and widget constructor checks are scoped to field presence and defaults,
  excluding allocator arguments, pointer nullability and readonly slice types.
  The original core/widget constructor proof excludes App. A separate App
  matrix now verifies mutable options, required represented fields, public
  pending focus, and timer item borrowing with independent copied list headers.
  Source allocator and buffered-writer storage have no V fields; the pinned V
  compiler also ignores required markers through an App alias. TTY copies and
  full Vaxis resource ownership remain outside that record proof.
  Separate layout and Text/RichText matrices now verify checked arithmetic,
  public iterator payload requirements and usize indices, callback ordering,
  and borrowed drawing state. A FlexRow callback that changes an initially
  positive weight to zero can make the source read an uninitialized size-cache
  slot; that undefined branch is excluded. Text/RichText iterator methods are
  private in source and public V adapters. The pinned V compiler ignores the
  inherited required text field through the TextSpan alias, although plain
  CellSegment construction enforces it; the alias remains compatible with
  shared segment inputs. Allocator/arena failures, readonly slice types and
  lengths beyond V's int-sized carriers remain distinct contracts. Window
  fill/print, scroll/mouse and borders now have separate checked-arithmetic,
  borrowed-state and failure-order comparisons. Window/PrintResult field
  presence, defaults and public mutation are checked separately. Wider explicit
  i17 literals, inherited required fields through V aliases, explicit nil
  pointers and boxed border-carrier copies remain measured differences;
  logical flags do not certify packed layout or native ABI.
  Terminal recovery
  comparison covers the existing unbuffered Tty adapter; source buffered output,
  public global-variable access, panic-runtime stack/address handling and
  cross-platform runtime behavior are distinct remaining contracts, not certified
  by these framework matrices. The six source FormattedPanic aliases cannot
  compile unchanged with Zig 0.15.2; that removed standard-library bundle is an
  unsupported source boundary rather than a runnable V implementation gap.
- **Fixed-array type aliases:** the pinned V compiler accepts a public alias
  declaration for Ghostty's `[256]RGB` `color.Palette` but emits invalid C as
  soon as that alias is used as a field or parameter type. Witty therefore
  keeps the exact fixed array directly in color APIs rather than exposing a
  nominal alias that cannot be consumed.
- **Integer generic storage:** V has no integer generic parameters, so
  `MessageData(T, small_size)` receives its inline threshold at construction
  and its `small` sum-type arm owns a dynamic array rather than a type-sized
  fixed array. Likewise, `BlockingQueue(T, capacity)` retains a runtime-sized
  backing array. Their active union arms, copy/stable ownership choices,
  bounded capacities, and observable behavior match the source, but their
  aggregate memory layouts do not.
- **OSC representation:** the `Command` union and its nested unions are now
  sum types, but Ghostty's sentinel-terminated slices are V strings, its
  fixed and allocating `std.Io.Writer` objects are an `OscWriter` tag over one
  GC-backed buffer, and the allocator is reduced to a presence flag. Observable
  parser boundaries are enforced, but this is not a one-for-one memory or ABI
  translation.
- **Stream action key:** Ghostty's handlers receive a comptime action tag, so
  each action compiles to its own code path. V has no dependent comptime
  parameters, so the remaining actions pass a runtime `ActionKey` with an
  `ActionValue` sum type and handlers smart-cast the value. The dominant print
  action uses a required concrete `vt_print(ActionPrint)` handler branch to
  retain the source's typed path. `lib_vt` cannot re-export the generic
  `Stream` because V does not implement generic type aliases.
- **Surface termio wrapper:** Ghostty's Surface stores `termio.Termio`
  directly. Witty wraps it in a `TermIO` value whose `live` flag and message
  buffer exist for zero-initialized test surfaces.
- **Shell-integration allocation errors:** Ghostty's `detectShell`,
  `setupZsh`, `setupNushell`, `setupXdgDataDirs`, and `setupFeatures` are
  fallible only through allocation, which V does not surface, so Witty
  keeps them optional or infallible. `setup` and `setupBash`, whose home
  lookup can fail, keep the source's fallible optional result.
- **Reduced terminal feature structure:** Witty now synthesizes
  `kitty_graphics`/`tmux_control_mode` from the Oniguruma selection and gates
  both live protocol entry points. Unlike Zig, V cannot change a sum type's
  variants or struct fields with a build option, so the disabled build still
  compiles the unreachable Kitty/tmux parser types and storage.
- **Generated-data pipeline:** Witty embeds pinned generated Config, CLI-
  action, keybind-action, and shell-completion records and exposes the correct
  data through its translated helpers. All nine `build-data` outputs are
  byte-for-byte checked against the pinned source generator. Its build does
  not yet regenerate those embedded records by parsing the translated
  declarations as Ghostty's Zig build steps do.
- **Allocator and memory representation:** `Page`, typed `Offset(T)` slices,
  allocator failure paths, and generic `RefCountedSet` storage are adapted to
  V GC arrays/specializations. Their reviewed observable behavior is close,
  but they are not literal layout, ownership, or failure-mode translations.
  In particular, the mmap-buffer-specific `Page.initBuf` and `Page.cloneBuf`
  entry points have no faithful operation on the GC-array representation and
  remain unrepresentable rather than being replaced with source-external copy
  semantics.
  Each page row owns its own `cells` array, identified by a `cells_offset`
  handle in place of an offset into one page buffer. Grapheme codepoints now
  reside in the page's bitmap-allocated byte chunks and are exposed as borrowed
  typed views, but those chunks are still separate V arrays rather than regions
  of Ghostty's single page mapping.
- **Deferred-face backend representation:** Ghostty's canonical `DeferredFace`
  conditionally owns native Fontconfig, CoreText, or WebCanvas state and loads
  through backend-specific private functions. Witty's canonical live face now
  owns the complete render-prepared Fontconfig pattern (with cached borrowed
  charset/langset) or the retained CoreText font and performs lazy naming and
  coverage through that state. Its portable fallback fields and WebCanvas
  implementation still share/parallel one cross-backend struct, and its runtime
  combines FreeType rendering with CoreText shaping state rather than selecting
  Ghostty's type at compile time. The deferred-font layer therefore is not yet
  backend-for-backend representation certified.
- **Crash timestamp width:** Ghostty retains filesystem modification times and
  `nanoTimestamp()` arithmetic as `i128`. V has no `i128` integer type, so the
  crash-report directory and CLI retain the platform nanosecond value as `i64`.
- **Sentry SDK integration:** Ghostty enables sentry-native with the Breakpad
  backend by default on macOS. Witty does not build or link that external SDK,
  so its lifecycle follows Ghostty's `sentry=false` branch. The translated
  transport can filter and persist serialized event envelopes locally, but no
  native crash handler currently supplies those envelopes.
- **Shadertoy toolchain:** Witty invokes external `glslangValidator` and
  `spirv-cross` executables through temporary files, whereas Ghostty links the
  shader compiler/cross-compiler libraries. This has different availability,
  process, filesystem, and error contracts.
- **Source placement:** V module-cycle constraints keep the translated shaper
  run algorithm in `font/font.v` while `font/shaper/run.v` exposes aliases, and
  place the application URL kind, build release channel, and configuration font
  style in cycle-free leaf modules so their otherwise-cyclic consumers can use
  one canonical type. Ghostty's `terminal/kitty/graphics_*.zig` files live in
  the `terminal` module as `terminal/kitty_graphics_*.v` (a V subdirectory
  would be a separate module that imports `terminal`). These are behaviorally
  implemented but not file-for-file layout matches.
- **Crash lifecycle spelling:** the translated `sentry=false` lifecycle uses
  `crash.initialize`/`crash.shutdown` because V reserves a module-level `init`
  function as a private, infallible automatic initializer. V rejects a public
  or fallible `crash.init`, so Ghostty's exact public spelling cannot be
  represented without changing the module boundary.
- **CLI action type placement:** `Action` currently lives in `global_state`
  while its translated dispatcher lives in the root C entry module; the `cli`
  package imports `global_state` for help enumeration and resource lookup.
  Restoring `Action.run` as a method therefore requires breaking that module
  cycle and moving the type back into `cli`. Ghostty's `Action.options` returns
  a different type for each compile-time enum value, a dependent-type API V
  cannot express directly. Ghostty's per-file `Options` names likewise require
  action prefixes after all action files are merged into V's single `cli`
  namespace; the prefixed values now retain their public fields and methods.
- **Runtime bridge representation:** Ghostty selects the concrete apprt types at
  compile time. Witty's merged V module boundary instead adds callbacks to its
  runtime-neutral `apprt.RuntimeApp` and `apprt.RuntimeSurface` and uses a
  process-global table of opaque core callbacks. This bridge is source-external
  architecture, even where each callback delegates to the translated core
  implementation.
- **libghostty ABI type generators:** `src/lib` is a comptime toolkit that
  builds C-ABI-compatible enums, tagged unions and structs from Zig
  declarations, parameterized on a C-or-Zig target, and `terminal/stream.zig`,
  `ansi.zig`, `sgr.zig`, `osc.zig`, `csi.zig` and `charsets.zig` declare their
  public types through it. V has no equivalent type-returning comptime, so
  Witty declares those types directly with explicit backing instead. The
  *output* of that layer is what many entries above verify; the layer itself
  is not translated and cannot be.

- **GTK UI definition pipeline:** Ghostty defines its GTK widget trees in 21
  Blueprint files (about 1,400 lines of `.blp`), which `build/blueprint.zig`
  compiles to GTK `.ui` XML and `build/gresource.zig` embeds through
  `glib-compile-resources`; the classes then call `gtk_widget_init_template`.
  Witty has neither build helper. The dialog and overlay classes embed
  blueprint-compiler's output for their `.blp` files verbatim (diffed against
  the compiled files), but the surface, window, tab, split-tree, command
  palette, and inspector widget trees are still constructed programmatically
  in V. Those graphs are intended to match, but they are not a translation of
  their Blueprint sources and cannot be diffed against them.

- **GTK class Common mixin:** `class.zig` exposes a `Common(Self, Private)`
  generic supplying each GObject class its upcast, ref/refSink/unref, and
  private-data helpers from one place. Witty re-implements those helpers
  per class, noting the correspondence in comments, because V has no
  equivalent comptime type-returning mixin. Behaviour is intended to match
  per class, but there is no single shared implementation to certify.

- **Metal shader library build step:** Ghostty's build compiles the `.metal`
  sources into a `ghostty_metallib` archive that `initLibrary` loads with
  `newLibraryWithData:`. Witty embeds the `.metal` source and compiles it at
  runtime with `newLibraryWithSource:`, so shader syntax errors surface at
  startup rather than at build time, and every launch pays the compile cost.

- **WebAssembly browser bridge:** Ghostty's Wasm font backends use the
  `zig-js` object registry to call Canvas APIs and return retained JavaScript
  object IDs. Witty's existing WebCanvas platform implementation is selected
  only by V's JavaScript backend; V's Wasm backend and wasm32 C target do not
  provide that `zig-js` bridge. The source-faithful Atlas ownership/data
  exports and the deferred-face/face/shaper ownership symbols are restored,
  but `atlas_debug_canvas`, `shaper_test`, and operational Canvas calls still
  require translating the bridge rather than inventing a different host ABI.

- **Native/platform coverage:** The complete FreeType/CoreText/web-canvas,
  discovery, Metal/OpenGL, shadertoy, regex,
  embedded-resource, locking, configuration, and platform application surfaces
  have not all been certified function-by-function against the pinned tree. A
  Windows-target V check currently stops on pre-existing platform gaps before
  reaching a complete application build: libxev has no translated IOCP backend
  and exposes POSIX socket/process types on Windows, its thread pool explicitly
  supports only macOS and Linux, the selected font module has no Windows
  `Discover`, and `internal_os.clone_into` has no Windows implementation.
  Windows therefore cannot yet be counted as a passing gate.
- **Comment style:** many large files use a verbatim "Original Ghostty Comments"
  header-dump block plus paraphrased inline comments, rather than each comment
  attached in place.

## Status

Vaxis loop/framework and image foundation verification: all 24 vaxis test files pass,
including the POSIX PTY and six framework test files; all-frame `boo` tests
pass, and native/Linux application checks pass. A native PTY application
smoke covers capability queries, frame rendering, Escape exit, reader-thread
shutdown, and terminal restoration. The framework DLL cross compiles with
MinGW. The focused theme preview and `boo` tests pass; the previous generic-loop
checkpoint also verified a Windows loop test executable. Existing platform/compiler
warnings remain. These checks use
`/Users/alex/.cache/v/v1-fallback/0.5.2/v`, with `VEXE` set to that executable
so it loads its matching standard library. No Windows runtime behavior was
exercised on this macOS host. The Metal build compiler is absent here
(`xcrun --find metal` fails), so the remaining metallib build divergence
cannot be validated on this host yet.

All twenty zigimg V test files pass. The image dependency DLL cross compiles
with MinGW, and the unmodified locked Zig dependency passes the standalone
QOI/farbfeld/PNG/PBM/PGM/PPM/PAM/RAS/SGI/XBM/PCX/BMP/IFF/GIF/TGA, editing, all-format pixel iteration, and bit-stream
reference harness in
`zigimg/verify_reference.zig`. The harness
uses Zig 0.15.2 targeting macOS 14.0 to avoid native linking failures against
this host's newer SDK. The dependency passes Linux checking, and the bit-stream,
Netpbm, raster, SGI, PAM, XBM, PCX, BMP, IFF, and GIF test executables cross compile with MinGW. The two
numeric-parser test files pass, and its float test executable cross compiles
after restoring Windows CRT locale operations. Native and Linux application
checks pass with existing warnings. These checks do
not exercise a Windows runtime.

IFF's separate checked-bound probes in `zigimg/reference_probes/iff_bounds`
run both V and the unchanged locked source in subprocesses. They verify traps
for 16-bit ILBM row-stride overflow, a final-row set padding bit, empty CMAP,
and HAM palette reduction below four bits. The regular reference harness
compares PBM/ILBM/ACBM, PackBits/ByteRun2, direct RGB24, HAM6/HAM8 including
oversized palette reduction, EHB/HAM priority, header bytes, stream positions,
and the no-op writer. Upstream binary fixture files are absent from the locked
source archive; these checks use synthetic fixtures.

GIF's native comparison cases cover header/flag layouts, empty canvases, both
version detectors, chunked LZW, Netscape/ANIMEXTS loop metadata, comments and
unknown extensions, plain-text skipping, indexed/RGB/RGBA selection, canvas-
height interlacing, linear clipping, transparency, all disposal paths, frame
filtering and palette overwrite, independent output storage, partial-input
positions, ignored LZW write failures, zero local dimensions, and its no-op
writer. Separate subprocess probes in `zigimg/reference_probes/gif_bounds`
verify plain-text byte overflow, checked buffered toss, short loop-count
records, and background casts outside the selected indexed width. These also
use synthetic fixtures against the unmodified locked dependency; upstream
binary fixture files are absent. Windows verification is compilation only.

TGA's native cases cover packed record/extension layouts, both detection
paths, ID and reusable-codec state, palettes and rounded RGB555 expansion,
alpha attributes, row order, read-ahead, partial EOF, bad extension offsets,
metadata limits, truncated ID lengths, and partial fixed-buffer output. Hashes
match 2,016 encoder cases across seven storage formats, four pixel patterns,
both row orders/compression modes, and vector/run boundaries; another 1,120
decoder cases compare raw/repeated/mixed packets, row order, alpha extensions,
palette bytes, and source positions across buffer boundaries. Undefined RGB555
padding bits are masked in comparisons. Separate subprocess probes in
`zigimg/reference_probes/tga_bounds` verify active-palette offset/capacity
checks and checked byte/palette-end arithmetic. The focused test executable
cross compiles with MinGW; Windows runtime remains untested.

The separate compression reference harness verifies LZW in both byte orders,
early-change modes, 5,120-literal code-size transitions, dictionary and partial
input state, write-failure ordering, PackBits boundaries, all 195 CCITT codes,
and CCITT row/padding behavior. Its runner checks locked source SHA-256 values
and copies unchanged source files into a temporary package to access private
modules, adding only the reference harness. The LZW, CCITT, and PackBits V test
executables also cross compile with MinGW; no Windows runtime was exercised.

The private octree quantizer has a separate source-hash-verified native runner
at `zigimg/verify_quantizer_reference.py`, which copies unchanged locked source
into a temporary package and adds its harness. Native hashes match 2,160
palette/index/tree-count cases and 336,128 input normalization cases, including
complete packed-color ranges, all 8-bit alpha/color pairs, 16-bit alpha
round-trips, and sampled float bit patterns. Direct cases compare node list
registration, wrapping merges, floor averages, palette borrowing, zero budgets,
missing colors, and all translated RGB(A) input types. Sixteen subprocess probes in
`zigimg/reference_probes/quantizer_bounds` compare palette capacity, repeated
reduction, component/reference overflow, average casts, and invalid color
levels. Explicit guards retain these checks in V production builds, while
removeLeaves additions still wrap. The probes reject returned domain errors,
fixing the former false positive for an erased color-level check. The runner
compares V-computed baseline hashes independently of test assertions and
verifies the complete locked source tree before copying it. Another 2,816
records compare one-layer aliases of all eleven built-in RGB(A) input types;
ordinary V/Debug source and production V/ReleaseSafe source both match, SHA-256
`9c9d1fc6249abb82c5ce2d642655a4f6b6b7789e7ad540a9c65993a47cea09d3`.
The module passes Linux checking, and its DLL and focused test
executable cross compile with MinGW; Windows runtime remains untested.

The private converter's source-hash-verified runner is
`zigimg/verify_converter_reference.py`. Its unchanged-source matrix covers
all 24 format tags, all source/destination pairs, eight pixel lengths, and
four input patterns: 18,432 cases compare errors, defined pixel bytes, palette
lengths/entries, and empty storage behavior. Another hash covers 6,066,176
conversions with complete packed-color ranges and all 8-bit alpha/channel
pairs, plus 16-bit and normalized float inputs. Unused RGB555 padding bits are
masked. Trap pairs use matrix markers and are executed separately by subprocess
probes. Direct cases verify prefix/tail rounding, finite fractional cast bounds,
NaN prefix/tail behavior, opaque palette tails, and unmanaged-image replacement,
same-format borrowing, failed-conversion state, and unchanged animation frames.
Nineteen checked traps and one native NaN result are compared by subprocesses
in `zigimg/reference_probes/converter_bounds`. Native comparisons use page
allocation because an align(1) arena can trigger the source's destination
f32 alignment cast. The module passes Linux checking; its DLL and focused test
executable cross compile with MinGW. Windows runtime remains untested.

The image API runner at `zigimg/verify_image_api_reference.py` verifies a hash
of the entire locked `src` tree before copying it unchanged. Its matrix covers
all 17 encoder tags, eight storage profiles, three option profiles, eight buffer
capacities, and both managed/unmanaged entry points: 6,528 cases compare errors,
successful lengths, borrowed pointers, and every buffer byte, including partial
writes and untouched tails. Direct V/native cases verify creation across all 24
pixel formats, raw copy/dimension independence, shared backing with independent
slice headers, animation-frame sharing, live iteration through conversion,
editing, failed/same-format conversion, and no-op writers with invalid images.
Eight subprocess cases in `zigimg/reference_probes/image_bounds` compare checked
creation/crop overflow and zero-height row/flip traps through both image APIs.
All 22 image test files, native/Linux checking, and MinGW DLL/focused-test
compilation pass; Windows runtime and allocator/aggregate ABI parity remain
uncertified.

That runner also compares in-memory detection through the unchanged source.
All 65,536 two-byte prefixes at nine buffer lengths produce the same hash:
589,824 cases include zero-length seeking, early detector failures, and final
XBM delimiter failures. Direct V/native examples cover every returning format,
both image APIs, byte-order-only TIFF acceptance, detector peek positions,
short valid signatures blocked by earlier checks, and BMP/TGA/TIFF precedence.
Separate bounded processes in `zigimg/reference_probes/image_detection` verify
the inherited XBM loop through both image APIs. All 23 image test files pass;
native/Linux checking and Windows DLL/focused-test compilation pass. Windows
runtime remains untested.

The TIFF metadata runner at `zigimg/verify_tiff_metadata_reference.py` verifies
the entire locked source tree before copying it unchanged. Native hashes match
3,072 map insertions/replacements with capacity and iteration checks, 38,400
bitmap-selection cases with six widths for row sizing, and 4,224 endian/tag/
capacity cases comparing every defined metadata field, optional strip arrays,
rational values, stream positions, and palette entries. Reserved and ordinary
maps reproduce palette-before-bits and bits-before-palette processing. Direct
cases verify packed sizes, inline SHORT words, endian arrays, rational reads,
zero-count arrays, duplicate IFD entries, and IFD truncation at every byte. Short
tag-array reads compare only complete defined samples, excluding the source's
undefined tail. Direct component-array cases verify LONG-to-u16 truncation,
RGB/RGBA selection independent of samples-per-pixel, and Unsupported errors
after resizing two-component arrays. Thirteen subprocess cases in
`zigimg/reference_probes/tiff_metadata_bounds` compare enum casts, fixed
capacities, missing sample/alpha entries, row indexing, tag-byte overflow,
parallel-loop length mismatch, and palette power/capacity/input bounds. All 24
image test files and native/Linux checking pass; the DLL and focused TIFF test
cross compile with MinGW. Windows runtime remains untested. These checks cover
metadata; the subsequent strip/read checkpoint is recorded below.

The TIFF decoder runner at `zigimg/verify_tiff_decode_reference.py` guards the
entire locked zigimg source tree and the Zig 0.15.2 flate, token, Huffman,
reader, and writer dependency files, then compiles unchanged native source.
It compares 39,707 cases through both translations: output pixels/palettes,
errors, stream positions, header/scalar metadata, and prefilled destination
buffers after failure. The recorded output SHA256 is
`22c929806d09ca615c320574abc8bb2be684f3d5596ba940f220164977fd6698`.
Fixtures cover stored/fixed/dynamic zlib blocks, mutated bits, truncations,
small/full/oversized destinations, trailing bytes, multi-window rebasing,
LZW partial codes and CCITT wrappers, all accepted TIFF storage/compression
paths, both byte orders, multiple/short last strips, oversized rows-per-strip,
palette planes, predictor wrapping, unsupported storage/row sizes, invalid
seeks, and version values zero/43/65535. Defined direct storage is prefilled;
short source allocator tails are excluded. Fifteen isolated processes compare
strip arithmetic, absent/short strip arrays, zero-length pixels, RGB stride,
palette/PackBits/CCITT bounds, image-pixel overflow, and the fixed-match window
trap. Ordinary returned errors cannot satisfy these trap probes. All 25 image
test files pass, as do native/Linux module checks and MinGW DLL/focused-test
compilation. Windows runtime remains untested. The full image library and
vaxis loading remain uncertified.

The PNG foundation runner at `zigimg/verify_png_foundation_reference.py` guards
the locked source tree and Zig 0.15.2 reader/writer/flate files before copying
the source unchanged. Its native/V matrices match 8,482 header cases
(`8cb5945cdde99fe7`), 43,200 filtering cases (`809cede448778a71`), 1,800 row
cases (`2ad35f81b5cd96cd`), 2,058 processor cases (`b0a838ddd9ac9218`), and
18,720 tRNS truncations (`0975e75ee48838d7`). Row goldens come from the full
unchanged native PNG reader; the V comparison exercises the translated filter,
defilter, and spread helpers without claiming a V image loader. Fixtures cover
all 15 accepted PNG formats, five filters/heuristic, packed rows, multiple rows,
short/full/oversized writer buffers with defined sentinel tails, every header
byte value, processor states, palette aliasing, and error positions. Failed
native scalar union assignments and unwritten allocated tails are excluded
from state hashing. Fourteen subprocess probes in
`zigimg/reference_probes/png_foundation_bounds` compare arithmetic, row/palette
bounds, wrong union/source arms, and TryAll; an ordinary returned error cannot
satisfy a trap probe. Separate 250 ms processes verify entry into the inherited
RGB24-to-grayscale-alpha zero-stride loop. All 27 image test files pass, as do
native/Linux module checking and Windows DLL/focused-test compilation. Windows
runtime remains untested; the remaining PNG reader and whole library are not
certified.

The PNG information runner at `zigimg/verify_png_info_reference.py` guards the
locked source tree, the same reader/writer/flate dependencies, and Zig 0.15.2
format/float sources. Both executions match 51,223 cases with output-buffer
hashes, written lengths, stream positions, returned formats/errors, and IDAT
counter state. The output SHA256 is
`87adba8bfd33b6f94e620ef6b277496fe1303c0fc80ca07a261f22fae0af7d4a`.
Fixtures cover every diagnostic branch, valid/invalid chunk lengths, input
truncations, output-capacity boundaries, header enum names, palette sizes,
large/sampled byte-size values, raw text and compressed iTXt flags, unknown
zTXt methods, stored/fixed/dynamic zlib blocks, mutated compressed bits,
1,024-byte print boundaries, and multi-window decompression. Twelve isolated
processes compare counter overflow, invalid tag-name access, and missing text
delimiters/fields; ordinary returned errors do not satisfy these trap probes.
All 28 image test files passed at that checkpoint, as did native/Linux checks
and MinGW DLL/focused-test compilation. The later image-reader integration
and its verification are recorded below; Windows runtime remains untested.

The complete PNG runner at `zigimg/verify_png_decode_reference.py` verifies
the same locked source/compiler hashes, copies the source unchanged, and
compares 60,760 returning cases. The result SHA256 is
`96ee46b18345684842d8ae9cd64290f7c5e9b86228458a83386a602bbd646e9c`.
Cases cover all 15 color/depth combinations, five filters, noninterlaced/Adam7
rows, three zlib strategies, every-byte truncation and small IDAT splits,
consecutive/empty/nonconsecutive IDATs, CRC and compressed-input failures,
PLTE/tRNS ordering and invalid lengths, metadata, ignored IEND fields,
unknown chunk walking, accepted open compression/filter bytes, 4-KiB input
and 64-KiB output boundaries, and large temporary rows. Comparisons include
status, dimensions, stream position, defined pixel/active-palette bytes,
tRNS/PLTE state, complete diagnostic output, and custom chunk/palette/row
callback ordering, positions, data and errors. File cases use 16/17/31/33/4096
byte buffers and preserve the source's seek and borrowed-IHDR behavior.
Eight isolated cases verify pixel-count overflow, extra inflated data,
Adam7's byte-sized row overflow, ancillary/post-IDAT-PLTE skip overflow,
short palette alpha bounds, and repeated grayscale16/RGB48 tRNS stride traps.
Ordinary returned errors cannot satisfy the trap checks. All 33 image test
files pass, including seven focused decoder tests. Native/Linux checks and
Windows DLL/focused-test compilation pass. The unchanged TIFF and PNG-info
matrices were also rerun after the other sessions' Huffman/stream changes:
39,707 plus 51,223 cases and fifteen plus twelve traps retain their prior
hashes. Windows runtime, custom allocator/lifetime behavior, root options,
and whole-library equivalence remain unverified or untranslated as above.

The direct PNG chunk-writer runner at
`zigimg/verify_png_chunk_writer_reference.py` checks those same source/compiler
hashes and compares 5,960 cases. Result SHA-256:
`934ba176552e9370b30073ea1f648fab7dcb4ca85424296097b173f4d298115e`.
It covers capacities 0/1/4/16/16384, full/partial writes, empty and repeated
flushes, oversized unframed writes, every framing-stage failure, and retries.
The comparison includes write counts, buffered payloads, output positions,
call ordering and destination bytes. Two isolated checked traps match, and
the unchanged legacy Writer and ZlibCompressor compilation failures are
verified separately. Focused tests additionally cover custom chunk IDs,
fixed-array aliases and native-width signed/unsigned endian writes.

`zigimg/verify_format_interface_reference.py` compares 49,344 returning direct
callback cases against the unchanged locked source. SHA-256:
`578f0de4bdaac7c2b67f294de64a2694c069cbb2fde6d2c43ca68494c6ca94eb`.
All 17 codec interfaces accept each source-supported encoder-options tag;
the matrix covers eight storage profiles, three option variants, eight
destination capacities, errors, stream positions and complete output bytes.
PNG/TGA wrong-option access retains two isolated checked traps. Focused
tests cover callback detection/loading and cross-option defaults. The live
registry also retains the 6,528-case encoder and 589,824-case detector hashes.

General `FixedStorage[T, B]` exposes the source's inline storage and borrowed
resize API, with the fixed-array type replacing its integer factory argument.
`verify_fixed_storage_reference.py` matches 2,373 returning resize cases and
twenty checked bounds against unchanged source in ordinary and production V
builds. Explicit guards retain the source's checked slice behavior when V
removes assertions. SHA-256:
`ba652143ec8ea584ce4522ed61dc6605986e90185c524ce8b13281b40b642c0b`.
Six capacities, u8/u16/RGBA elements, pointer identity, old views after resize,
active bytes and retained storage bytes are compared. Each capacity/type and
the existing 8/256 specializations receive a separate oversized-resize probe.
SGI/IFF and TIFF debug hooks now expose
the source logger operations with V's language-specific generic rendering;
exact cross-language diagnostic presentation is not claimed.

HSL/HSV/CMYK, floating grayscale and predefined colors now expose source
conversion APIs. The source-hashed `verify_color_models_reference.py` matches
31,167 cases, preserving signed zero and every non-NaN output bit; NaN
payloads are canonicalized. SHA-256:
`dc4e15c78150f3ce178a6fa9eab1f953d5ea3647239753ea7eb18648a805504f`.
`verify_math_reference.py` matches all 2/3/4-component vector and square-matrix
APIs across 12,419 cases, including singular/zero-pivot inverses, negative-zero
dot-product initialization, clamps and caller immutability. SHA-256:
`23be1b2c20e279a493dda64087e1916b58e6fdbc8bdcb76469c15b7231a4fb31`.

Public magic-number and deprecated enum-checked struct readers are translated
against unchanged `utils.zig`. The differential runner matches 20,992 cases
and two checked shift traps, SHA-256
`92204900e01795200a4b2585d19fb2ec6476f17ab099c4e3cfac3e6036346c3f`.
Struct types must preserve native field widths/layout/padding. Both source
struct writers fail to compile with Zig 0.15.2 because their declared error
type uses the removed `std.io.StreamSource`; the runner confirms that boundary.
Ordinary and production V builds retain the same records and both oversized
signature traps through explicit shift guards. A further 54,528 cases compare
endian, scalar, exhaustive/non-exhaustive enum, byte-array and nested-struct
aliases, invalid enum consumption and short reads, SHA-256
`5a841a2f84a10641b1ebf1268d6e60326576459bafc54b84fb732287096032e6`.
Four ordinary compile probes reject wider inline arrays and dynamic byte
slices, including aliases, at the source's unsupported field boundary.

The live macOS clipboard callbacks now use the source URL-first pasteboard
reader, Uniform Type Identifier mapping for MIME types, and repairing first-NUL
C-string conversion. Writes declare all types before storing values; approved
confirmation publishes only the plain text shown to the user. Read confirmation
retains strict UTF-8 and request-discriminator guards. The actual module-main
native fixture uses an isolated named pasteboard and injected alert results.
Its 21 records match unchanged pinned Swift helper/app/controller bodies through
`build_support/reference_probes/clipboard/run.py`, which verifies each source
file against the pinned Git revision before extraction. This establishes content
and completion/cleanup policy, without certifying SwiftUI sheet rendering or
asynchronous timing. The raw MIME fallback after a nil UTType is translated;
all tested host MIME names produce a known or dynamic UTI.

The omitted classic Window-based Vaxis alignment, Scrollbar and ScrollView
APIs are now translated independently of `vxfw`. Their unchanged-source runner
matches 41,649 cases in ordinary and production V builds, SHA-256
`12bc9172a2cf6e8e65d9e410ae3902aa35ab546b8e58814a11f04249e53c7308`.
The matrix compares retained cells/styles, clipping, all five alignments,
input saturation, restrictions, bounds predicates and content writes, including
64-bit boundaries. Three source arithmetic/cast traps remain active. The
source's ScrollView.readCell fails Zig 0.15.2 compilation because it returns
void from an optional Cell function; its V method remains unavailable and both
compile rejections are verified. API mappings, source hash and coordinate/
allocation adaptations are in `vaxis/reference_probes/widgets/README.md`.

The classic View and LineNumbers APIs are translated, together with TextView's
runnable buffer/styling/adapters/input/draw paths and CodeView's defaults/input.
An unchanged-source comparison using the exact locked uucode package matches
18,307 cases, 17 checked traps and four ordinary compile rejections in ordinary
and production builds, SHA-256
`8f1e7d605790217fc5d8426f487cced18a5998d945da9ec50b92ed57c8b6750e`.
The corpus compares retained cells/styles/images/scales, Unicode clusters,
render origins, byte-indexed styling, adapters and scrolling. View retains
direct-copy i17 arithmetic and overlapping-copy traps; LineNumbers retains
its exclusive endpoint and eight-digit ceiling. TextView append/update/writer
write fail in the pinned source at an error-union subtraction, and CodeView
draw fails at a usize-to-optional-u16 child width. Those methods remain
unavailable. Exact mappings, dependency hashes and GC destruction adaptations
are in `vaxis/reference_probes/widgets_classic/README.md`.

The octree quantizer now keeps its checked accumulation, averaging, capacity,
reduction and level arithmetic in production builds. Sixteen strict trap probes
close a previous false positive caused by panicking on a returned domain error.
The original 2,160 tree/palette/index and 336,128 normalization hashes remain
`fb25faff7d5b5837` and `2e3cf0cdc340afc4` in Debug and V-production/source-
ReleaseSafe builds. Aliases of all eleven RGB(A) types match 2,816 additional
records, SHA-256
`9c9d1fc6249abb82c5ce2d642655a4f6b6b7789e7ad540a9c65993a47cea09d3`.
The verifier checks the full pinned source tree and V-computed hashes
independently of assertions. Deliberate reduction wrapping and GC/root/private
context adaptations remain documented in the probe.

The image streams now expose borrowed reader/writer adapters and native-width
integer helpers, including scalar/endian aliases. File EOF refreshes cached
size after truncation; Darwin positional vector writes preserve the source's
first-vector return and pending bytes. Pipe writes retain the initial
zero-progress mode transition, retry it during flush, and cache seek failures.
Explicit seek, capacity, buffered-count and bit-shift guards survive production
optimization. `verify_streams_reference.py` matches 36,962 returning records,
17 strict checked traps and four ordinary compile rejections in ordinary and
production V builds, SHA-256
`f1aa0b894555ca0ee8864ce10e7605112cc2ccfeaa1ae6b21a07e3573cbc99dc`.
State, errors, positions, bytes and file contents are compared against unchanged
locked source. Borrowed ownership, native scalar widths and platform limits
are recorded in `zigimg/reference_probes/streams/README.md`.

Streaming file reader/writer constructors now preserve the descriptor's live
position and avoid the initial positional-I/O mode transition. EOF replaces
the streaming reader's cached size error; backward absolute seeks stay
unavailable. The expanded Debug corpus matches 37,133 records, SHA-256
`d5d4aadd97fafef40388dd894267e0b09d6db36b902c2f4356d4fb287eab8eeb`.
Its original 36,962-record hash is unchanged. The 171 added constructor and
buffered-length cases also match under V production optimization, SHA-256
`37175ccb3eb0e9b5b36005a5c2443f6f59b1ee2cbd7de2fd1336c2761a8bcfab`.

The classic Vaxis Table now retains all four width styles, context defaults,
the runnable MultiArrayList row snapshot, cell rendering, selection, callback
errors and live callback mutations. The unchanged source and locked uucode
dependency match 7,058 returning records, fourteen checked traps and four
ordinary compile boundaries in Debug and V-production/source-ReleaseSafe
builds, SHA-256
`a9aa2c68decee1101f62bfc02cd52ccbfceed8142377c1919c9a60c194c91a82`.
Five consumer tests and a Windows focused-test cross build pass. Source slice
inputs and direct/optional string-slice fields fail to compile with Zig 0.15.2;
the V APIs retain those boundaries. GC allocation, arbitrary custom-composite
formatting and undefined subset-header adaptations remain documented in
`vaxis/reference_probes/table/README.md`.

TextInput now inserts one source grapheme at a time, preserving its 512-byte
gap growth geometry, malformed UTF-8 consumption and zero-width draw ordering.
All buffer slice, allocation, movement and growth checks remain active under
production optimization, including zero-count movement and large public cursor
values. Ordinary and production comparisons match 14,346 records and 22 checked
traps, SHA-256
`4003872debd68d8f2886119b492cc0d14ac1c5692a049662b043074cb67aaaf0`.
Six focused consumer tests pass. Source u16 count/width overflow and malformed
combining-mark underflow remain inherited traps. At this checkpoint the byte
iterator and width helper were private to TextInput; the subsequent shared
Unicode continuation is recorded below.
GC ownership and int-sized-array limits remain documented in
`vaxis/reference_probes/text_input/README.md`.

The classic Terminal key encoder matches 59,072 returning records and all 31
nonzero Kitty press traps in Debug and V-production/source-ReleaseSafe builds,
SHA-256 `fef07475371a26194ffa5a396745016d36ef5eb33b005ef1a47f115888a96d6a`.
Two consumer tests cover generated text precedence, decimal CTRL+ALT output,
modifier masking, release-empty behavior and partial write failures. The source
only implements legacy presses; protocol TODOs and unsupported-key behavior
remain intact. Reproduction is in `vaxis/reference_probes/terminal/key/README.md`.

The caller-buffer TextInput API is now exposed as `slice_to_cursor_into`,
preserving the borrowed prefix, untouched buffer tail, insufficient-capacity
assertion and aliasing-copy trap. The full Debug matrix matches 14,442 records
and 24 traps, SHA-256
`d334fced0a688b98041dc3d197722ecfb4fb54dca8b1c6baf20b4e11cbc51b9b`;
its original 14,346-record hash remains unchanged. The 96-case/two-trap extension
also passes production optimization, SHA-256
`4ea3a4ac46f14ef27d6583ab094004525b0af9e5a0e2356d91cfc1c738a5e149`.
Seven consumers pass. The classic widgets and vxfw TextField retain their source
required fields; a source-hashed compile runner checks twelve complete
constructors and twenty-three paired omission rejections. Source allocator
members are supplied separately and excluded from omission comparisons.
TextField's consumer explicitly initializes its buffer and passes after the
required-field change. After the streaming constructor additions,
all 43 image test files, native/Linux checks, Windows DLL and focused file-I/O
test cross builds pass.

The classic Terminal Parser and ANSI helpers now preserve buffered print
batching, pending controls, raw UTF-8 bytes, partial errors, borrowed event
storage, CSI formatting and typed parameter/lookahead state. Skipped control
strings consume only their ESC delimiter; OSC/APC consume one following byte
without prefetching and propagate cutoff EOF. The unchanged source matches
140,489 returning records and sixteen arithmetic traps in Debug and
V-production/source-ReleaseSafe builds, SHA-256
`d161050f1a033fd4f73a1e4cff01a7a61b6100f50773a40d8528e82f1ef1bf53`.
Five ordinary compiler boundaries and three focused consumers pass. The pinned
V compiler accepts an empty generic iterator despite its required `bytes`
annotation; the runner measures that separately from paired failures. GC
allocation, native integer widths and other limits remain documented in
`vaxis/reference_probes/terminal/parser/README.md`.

The classic Terminal Screen translation now exposes every public screen, cell,
cursor and scrolling-region operation. Debug and V-production/source-ReleaseSafe
comparisons match 6,414 returning records, fourteen checked traps, a separate
inherited insert-line hang, two complete constructors and five paired omission
rejections. SHA-256:
`9700325e0d87d1893e34375f5d8951eb5eadd2c469734b9cce078c52f7e183a4`.
Eight focused consumers pass. Equal-width reads, first-row character deletion,
dirty-copy omissions, self-copy clearing and narrow counter overflow retain
the measured source behavior. Borrowing the fixture's serializer removes
quadratic GC root tracking without changing production screen operations.
GC strings, undefined cursor URI initialization and array-capacity limits are
documented in `vaxis/reference_probes/terminal_screen/README.md`.

The classic Terminal core now translates public controls, drawing, key input,
writer borrowing and descriptor/process cleanup, plus Linux PTY construction,
spawning, resizing and the VT thread. Debug and V-production/source-ReleaseSafe
comparisons match 12,394 returning records and five checked traps, SHA-256
`6be3faff0915dedb07e6d0d65983f526a2b2a5d283d66fb6b9d2647359c2143e`.
Three focused consumers pass in both V modes. Three complete constructor pairs
and fourteen ordinary missing-field pairs preserve required PTY, Command and
Terminal inputs. Six lifecycle APIs retain ordinary source/V macOS compiler
rejections; unchanged-source Linux consumers and translated Linux checking pass.
Linux C compilation and linking also pass, but PTY/process/thread runtime has
not been compared on this macOS host. GC ownership and global registry/thread
adapters remain documented in `vaxis/reference_probes/terminal/core/README.md`.
The separate three-record Debug registry fixture confirms the source's count
remains two while its live entries decrease from two to zero. V exposes that
count through `globals.count`; its map length reports live entries. SHA-256:
`fffc0c277b830839c956ad90dff7fef86557ecb03194fffd50b602ac9ef928fb`.

A separate private-loop fixture compares 1,767 returning records, ten exact
checked-trap categories, an inherited insert-line hang and ordinary external
private-access rejection in Debug and V-production/source-ReleaseSafe builds.
SHA-256: `e7dc5af0356c8a4f074b5b94114cb70addee9c1fc5c638d9d40c2ebd5ab43b0b`.
It executes CSI/OSC/C0 handling, malformed print bytes, replies, ordered events,
all three screens, streaming EOF position and mutex release. The fixture appends
one visibility helper to a copied source file; every original byte remains an
identical prefix and every other source file is unchanged. The V fixture runs
inside an isolated module snapshot without adding a public API. Exact provenance
and capacity/lifecycle limits are in
`vaxis/reference_probes/terminal/private_run/README.md`.

After integrating the screen and core, all 33 Vaxis test files pass. Native and
Linux compiler checks, a Linux C shared-library link with GC disabled, the
Windows DLL and focused Screen/Parser test cross builds pass. Cross compilation
does not establish PTY/process/thread runtime behavior on those platforms.

All ten classic widget exports now have V counterparts for their runnable
public methods. The five measured source compilation failures remain explicit:
ScrollView `readCell`, TextView buffer `append`/`update`, its writer's `write`,
and CodeView `draw`. Table input/format boundaries, inherited protocol and
scrollback TODOs, and GC representation limits remain in the individual probe
records; this closure is scoped to the classic widget slice.

Scientific CIE XYZ/Lab/Luv/LCh, HSLuv and Oklab conversions match 6,961
unchanged-source cases, SHA-256
`d97550d49bb60cf224fc60999d3603d6199aa9c99702a7c79b8d7ca9f10e8566`.
The scientific, HSL/HSV/CMYK and matrix runners also pass with V production
optimization and retain their hashes. Independent sine/cosine calls preserve
native rounding when Apple clang would otherwise select a combined routine.
The source's HSLuvAlpha Float4 factory/argument type typo remains unchanged.

RGB colorspaces, all sixteen alpha-slice APIs, Bradford conversion matrices,
eleven presets, twenty-nine whitepoints and gamma transfers match 5,792
unchanged-source rows in ordinary and production builds, SHA-256
`262e3417fd251373234d20d0b06d7fe53adc63028db4a708a71d99677cf9d6a0`.
Comparisons include borrowed output identity and input mutation. V typed
values replace compile-time gamma namespaces, callback fields use a `_fn`
suffix and copying slices use V allocation instead of the supplied allocator.

All eleven built-in RGB(A) types expose source constructors/getters, unsigned
scaling and premultiplication. Custom target conversions delegate to the target
factory; packed and grayscale aliases retain logical widths. The source-hashed
`verify_color_methods_reference.py` matches 35,362 returning cases, four checked
component-limit traps and twenty-one ordinary compile rejections. SHA-256:
`d0e9543322de17f813724ff1ed5b51793a68277be165a96bf4266ae17461adf3`.
The production build retains these records and checked traps. V static methods
replace zero-sized source namespaces, and callers specify scaling input/output
types. Source comptime integer casts require explicit V casts. Focused custom
mixed-precision helpers adapt private source factories; their V checks do not
claim unchanged-source factory parity. Known built-in target delegation avoids
the pinned compiler's generic static dispatch cache defect; custom targets use
inferred static calls.

General `Matrix[B]` adapts the source factory to directly named square f32
arrays. It exposes flat construction, identity, determinant, inverse,
transpose and matrix/fixed-vector multiplication. The unchanged-source runner
matches 6,467 cases across dimensions 1, 2, 3, 4, 5 and 8 in ordinary and
production builds, SHA-256
`f303b568d8901d722b61cb805d2ccd212e57c10a758d2b530f15ab4d710e9c0f`.
Three explicit shape checks remain active under production optimization.
The existing 12,419-case named-matrix corpus retains its hash after the bounded
direct-index workaround. Zero-length fixed arrays, further alias layers and
generic forwarding of static factories remain V 0.5.2 boundaries; storage uses
the V array ABI rather than Zig's SIMD-vector layout.

The focused tests and compile gates named in each audit session are expected to
pass at the recorded commit. A repository-wide build is not proof that every
Ghostty file and function has been translated, and no 100% claim is made.

Cross-platform verification: 42 `*_linux.v` files, about 21,700 lines of the
GTK apprt and its supporting code, are never compiled on a macOS host, which is
how the `SplitTree.new` defect stayed hidden. `v -os linux -check .` and
`v -os linux -o out.c .` both cover them without needing GTK headers, since
they stop before the C compiler. This was validated by reintroducing the
`SplitTree.new` defect and confirming the check reports it. Both now pass with
zero errors, as do all ten `*_linux_test.v` files individually.

Beyond the checker, Witty now compiles and links on Linux (aarch64 Ubuntu
24.04, GTK 4.14.5, libadwaita 1.5, clang, the pinned fallback V). The GTK app
had never run before that: its first runs aborted in GObject class setup (the
private-data, signal, template, and tab-bar rows above). It now starts under
Xvfb, draws the grid with the OpenGL renderer, and runs its pty child. The full
suite on Linux gave 258 passed and 13 skipped (Darwin-only files); the former
`font/atlas_wasm_test.v` compiler failure has since been fixed at its
test-expression boundary. Not yet exercised on Linux: Wayland
(including the layer-shell quick terminal), real keyboard and mouse input,
the Flatpak portal path, and GTK widgets beyond the default window.

Open issues seen while verifying:

- Under Xvfb, the tabs-and-splits D-Bus probe still shows a collapsed root
  split after `split-down` in roughly one run in 25 (before the split fix above
  it was about one in eight). A trace of a failing run shows the tree and the
  root paned positioned correctly (395 of 789 pixels), so the remaining cause
  lies outside the ratio logic and is not yet understood.
- Terminal stream throughput has not yet been compared with a matching Ghostty
  build. Profiling an 80-column ASCII `-prod` print benchmark found three
  translation costs: recycled-page reallocation (roughly 3 MiB/s), heap-only
  page pins (8.24 to 17.43 MiB/s in a 61 MiB A/B), and heap-copying the runtime
  print action payload. Removing the last cost raises a 610 MiB sustained run
  from 7.13 to 17.81 MiB/s. A source build is still needed for a fair endpoint.

Repository-wide test state, for honesty about what the gates actually cover:

- `v` and `v -prod` both build, and the full test suite passes.
- The earlier small-unit compiler crash while compiling `Config.format_config`
  no longer reproduces with the pinned fallback compiler: the full
  `configpkg_test.v` unit, including the restored Keybind formatter cases,
  passes without `-g`. Adding `-g` currently exposes a separate fallback
  compiler bug that places generated C `#line` directives after expressions;
  the normal project gates do not use that mode.
- Test files that report "compilation failed" with no diagnostic are worth
  treating as suspicious rather than as runner noise: two such reports this
  session turned out to be a V compiler segfault, one of them masking a real
  generic-instantiation defect in `SplitTree.new`.

The shared Unicode continuation compares public spans, all three width methods,
DrawContext adapters, borrowed addresses and mutable-caller prefetch timing.
Ordinary and V-production/source-ReleaseSafe builds match 72,225 records,
fourteen strict traps, one complete Grapheme constructor and two paired
required-field omission errors, SHA-256
`f7555397b8c48374500b4558a166e5701f30ad7f2b35d056a4d5c56297913f4c`.
The original 72,065-record prefix retains its separately checked hash. Six
focused consumers pass. V keeps iterator state opaque and requires an init
factory; it does not expose arbitrary source iterator state literals. The
existing TextInput comparison again matches all 14,442 records and 24 traps
with its previous hash. Reproduction and limits are in
`vaxis/reference_probes/unicode_gwidth/README.md`.

TextField's public insertion, navigation, drawing, widget callbacks and
caller-buffer copy match 18,911 unchanged-source records and sixteen strict
trap pairs in ordinary and production builds, SHA-256
`c9a34b722a8b37cf2d7916679118d07dae1a2bbd11a3bd68ccfe7fdf1dd93be3`.
The matrix includes change/submit errors and mutations, context flags, state
reset order, raw UTF-8, large zero-width iteration, and 1,824 borrowed-draw
pointer/mutation records. Six focused consumers pass. Source rejects the unused
scroll field's literal value 16 while V's u8 backing accepts it; the runner
measures this boundary separately. GC, allocator errors and readonly slice
enforcement remain adaptations. Reproduction is in
`vaxis/reference_probes/vxfw_text_field/README.md`.

Surface/SubSurface and their delegated Window child/cell/cursor methods match
11,162 unchanged-source records and twenty-eight strict traps in ordinary and
V-production/source-ReleaseSafe builds, SHA-256
`852eb3f3eae04a383dd8af7fc2055971d9fc1bd1f49760135457cc4d5c6bc265`.
Four focused consumers pass. The matrix separates u16 multiplication/addition,
i17 endpoint/max-size/absolute/parent sums and neighboring short-circuit paths;
it also checks borrowed trim buffers/children, cursor reset, clipped rendering,
stable sorting and hit routing before/after render. Window fill/print, arbitrary
source state constructors and allocator failures remain outside this proof.
Reproduction is in `vaxis/reference_probes/vxfw_surface/README.md`.

The six zigimg SIMD lane helpers and Box/image dimension guards match 60,109
unchanged-source records, twenty-two strict trap pairs, thirty-five ordinary
compiler-rejection pairs and one panic-visible store-prefix pair in ordinary
and V-production/source-ReleaseSafe builds. SHA-256:
`d67067e84ac4022693c27f755806a944c51909088df51a144f1438be1679f51e`.
Eight focused consumers pass in both modes. Native integer/f32/f64 lanes,
aliases, widening, raw floating-point bits, 7,500 pointer conversion records,
boolean/struct stores and source-ordered dimension checks are included.
Stores preserve prior writes on a short destination. Four measured boundaries
cover source comptime lengths, zero-length arrays, array/vector overlap, and
the pinned V fixed-array pointer-alias constructor's uninitialized-pointer
copy. Valid pointer aliases use typed views of pointer bits; the runner checks
the broken constructor's generated C without executing undefined behavior.
The native ARM64 NaN result is preserved; other CPUs, AVX2 permutation behavior,
vector ABI and non-native source numeric/tuple carriers remain outside this
proof. Reproduction is in `zigimg/reference_probes/simd/README.md`.

The final integrated runs pass all 36 Vaxis and 44 image test files. Native and
Linux module checks, native/Linux whole-application checks, both Windows DLL
cross builds and the four new focused Windows test builds pass. The Vaxis
Linux shared module also links as an x86_64 ELF with GC disabled for that build.
These are compilation/link checks for the cross targets; no new Linux/Windows
runtime parity, allocator/GC lifetime or complete dependency coverage is
claimed. The subsequent framework continuation is recorded below; the live
audit retains the remaining layout, iterator and representation boundaries.

## Vaxis framework state, construction and recovery continuation

ListView and ScrollView now check source i17/u32/u16/usize operations and source
assertions explicitly, including pending-scroll arithmetic, accumulated origins,
cursor subtraction/indexing, width calculations and state update order. Both
preserve source short circuits, captured builders, callback mutation/error timing
and inherited empty-builder navigation loops. Their native Source Debug/V ordinary
and Source ReleaseSafe/V-production matrices match, respectively:

| Scope | Returning records | Strict trap pairs | Output SHA-256 |
| --- | ---: | ---: | --- |
| ListView | 5,284 | 20 | `1c0060888edc4691761a3d3e2e5d9751c4a673b181457850c147cf9f104c9a9e` |
| ScrollView | 14,353 | 22 | `013c5025c4b6192747e19df33a046090b3d0e2781f33f7a70d8824571a05625f` |
| Spinner | 15,183 | 6 | `91e0cf4dd5aee36836a99662a3271b4f9c38b8dfdbb044a88e193e69d1f74acc` |

Each scrolling runner checks two isolated inherited loops and its complete
constructor/payload omission contracts. Both independently measure the source
branch that deinitializes then appends to a child list; its undefined storage is
excluded from parity, while V retains the managed-array replacement. ScrollView
also measures two wider-i32 literal acceptance boundaries. Its computed viewport
indexes remain unused, and the source's repeated post-insertion offset assignment
remains intact. Reproduction and scope are recorded in
`vaxis/reference_probes/vxfw_list_view/README.md` and
`vaxis/reference_probes/vxfw_scroll_view/README.md`.

Spinner now embeds atomic values so ordinary copies have independent counters.
It preserves source wrapping start increments, saturating load/subtract/store
stops, remembered-state clearing on stopped ticks, 83ms rearming, and checked u4
increments/indexing even under V production optimization. The runner compares
concurrent starts through u16 wraparound and independently measures its wider-u8
initializer boundary and three source-only allocator-error order cases. V atomic
ordering remains stronger than source and allocation failures remain absent from
the managed-storage adapter. No arbitrary-interleaving or atomic ABI equivalence
is claimed. Eight focused consumers pass in both modes; the ListView and
ScrollView consumers add five and four focused cases. Reproduction is in
`vaxis/reference_probes/vxfw_spinner/README.md`.

The constructor callers and prior Unicode, TextField and Surface probes now
provide the source-required fields explicitly. Their ordinary and production
returning hashes remain `f7555397b8c48374500b4558a166e5701f30ad7f2b35d056a4d5c56297913f4c`,
`c9a34b722a8b37cf2d7916679118d07dae1a2bbd11a3bd68ccfe7fdf1dd93be3` and
`852eb3f3eae04a383dd8af7fc2055971d9fc1bd1f49760135457cc4d5c6bc265`.
This preserves their previous scoped verification while restoring constructor
requirements; it does not close the other layout/iterator contracts in the live
audit.

Required constructor fields now cover all exported framework widgets as well as
core context, widget, surface, coordinate and command records. The unchanged-source
constructor runner passes 38 complete pairs and 57 paired ordinary omission
rejections in both modes, comparing sixteen core and sixty-three widget default
values, SHA-256
`2917ca5cdc672d99b1c440daed7882a2da028cc5a1325097b444ce88a501dbbd`.
This includes nullable-but-required notification titles, callback and
slice payloads, BorderLabel, size/width constraints and builder user data. Existing
application, Boo and focused consumers now supply explicit values. Source
allocator arguments, non-null/readonly pointer types, iterator records, Segment
aliases and App's manual lifecycle state remain outside this constructor proof;
their specific fields and API differences are listed in
`vaxis/reference_probes/vxfw_constructors/README.md`.

Terminal recovery now registers an independent value snapshot after every
successful Tty initialization, retains the previous snapshot on initialization
failure, writes the exact source reset sequence and restores terminal state even
when that write fails. `recover`, `panic_handler` and `Panic.call` are available;
the panic entry points restore state before handing the message to V's runtime.
Repeated recovery retains the saved source value despite V deinit mutating its
receiver. Two focused tests cover absent registration and independent replacement.
The native macOS Source Debug/V ordinary and Source ReleaseSafe/V-production
comparisons match 56 returning PTY records and fourteen explicit panic/order
pairs, SHA-256
`4101322a2b3636fd13ba3fa721e6bcedc928df711057799a2a46688d8d0dd645`.
The returning digest includes the fixture's macOS termios representation.

Forty-eight source-only buffered observations in both modes have SHA-256
`336343f9e968444519d30154bd7c1d6fed3e0451066c9f19f03b581da34db850`.
They explicitly retain a source boundary: a 48-byte buffer can hold the first
complete reset sequence without emitting it, while V's existing Tty adapter is
unbuffered. Six paired ordinary compiler checks independently demonstrate that
the source `Panic` aliases reference the removed Zig 0.15.2 `FormattedPanic`
bundle; V leaves those unsupported entry points absent. A separate probe records
source public-global access versus V's private registry. Writer state, direct
global-variable access, panic stack/return-address handling and other platform
runtimes remain outside parity. Reproduction and fixture details are in
`vaxis/reference_probes/recovery/README.md`.

The final integrated run passes all 40 Vaxis test files, and all 44 image test
files pass. Boo's focused tests and native/Linux whole-application checks also
pass. Both Windows DLLs and the four new ListView, ScrollView, Spinner and
recovery test executables compile, and the Vaxis module links as an x86_64 Linux
ELF shared library with GC disabled for that cross build. These cross-target
checks establish compilation/link success rather than platform runtime parity.
The remaining layout arithmetic and iterator/lifecycle construction boundaries
are retained in the live audit above.

## Vaxis layout, text and Window output continuation

Center, Padding, Border, FlexColumn and FlexRow now retain source checked
geometry, dimension and proportion operations in V production builds. Text and
RichText likewise check row/column, width/cast and usize cursor operations, while
preserving source saturation and intentional truncation. Window fill checks i17
endpoints before clipping and performs buffer products in usize; print uses
checked u16 arithmetic and borrowed raw-byte grapheme iterators. All four new
runners hash and copy the complete pinned Vaxis source and locked uucode graph
unchanged, reaching the source through public draw/widget or Window methods.
Both native Source Debug/V ordinary and Source ReleaseSafe/V production match:

| Scope | Returning records | Strict trap pairs | Output SHA-256 |
| --- | ---: | ---: | --- |
| Layout widgets | 27,963 | 37 | `7530b735b2181ad9675dbf776110002b759a5fd3c60df25f2e794f553984c164` |
| Text | 7,562 | 15 | `d6f81838ac48054b14f76b3f3d607c13ca1e3153f1fb9959902596d47f0facac` |
| RichText | 22,366 | 11 | `82d672df1b109891fa701681f003009fc56e1d28acfc32cfe27c946502342b48` |
| Window output | 33,215 | 15 | `d97f410c29c874baeee7e5506ce5e55dd68bbdb2740061d1f7b2ea5a037d617b` |

Layout callbacks can mutate current/later weights, child sizes, parent fields
and labels, or replace the child field during either Flex pass. Borrowed header
locals preserve the source loops' captured slices; distribution branches still
read the live child-field length. Column measures every item and checks its
remainder subtraction, while Row measures zero-flex items and saturates the
remainder. Error and state-update order, borrowed border labels, contradictory
constraints, empty layouts and inherited dimension behavior are covered.
Changing an initially positive Row weight to zero before its second visit can
read uninitialized source cache storage; that branch remains excluded, with
V's existing zero-initialized cache retained.

Text/RichText surfaces retain borrowed caller graphemes, copied styles and source
iterator/reset order. Public iterator payloads require context/input/line fields
as applicable, require both wrapped-line fields, and expose usize cursors. Text
checks three complete constructors, five paired omission rejections and three
source-private/V-public method boundaries. RichText checks four complete
constructors, seven omission pairs, four private-method adapters, two measured
constructor adaptations and eight source-only allocator observations. Plain
CellSegment now requires text; pinned V still ignores that inherited marker
through TextSpan, whose alias is retained for shared segment compatibility.
The missing arena parameter is a GC adaptation. Private source iterator bodies
are compared through public drawing, without source wrappers or visibility
changes. Unused source Text consumeCR/consumeLF helpers reference a nonexistent
field and are not exposed as speculative translated APIs.

Source leading-tab underflow, RichText standalone-CR underflow/range failures,
nonadvancing oversized wrapped graphemes, and malformed-byte Unicode underflow
are isolated and retained. Text's nonwrapped container width intentionally
truncates; RichText hard-line widths saturate. Zero maximum width returns before
decoding or allocation. Large valid draws include the 65,535-cell boundary.
Private heap shells for Surface and RichText iterator/line headers avoid pinned
V production's recursive keepalive enumeration of the entire cell arrays on
every write. Public values and borrowed storage remain unchanged. The formerly
timed-out RichText producer completes all sixteen large production cases in
1.43 seconds on the measured host; timing is an observation, not a gate or a
claim about general rendering throughput.

Window records compare all three wrap/width methods, clipping and measurement,
split segments, style/link metadata, borrowed pointer offsets and post-draw input
mutation. Fill retains the source's negative-y contiguous behavior and ignored
parent offsets. Buffer products near 65,535 squared are computed before clamping
without signed-int overflow. Grapheme iteration occurs before column checks,
preserving inherited malformed-input failures even in zero-width unwrapped
printing. Valid UTF-8 splits use codepoint boundaries; malformed-unit splits use
endpoints, so arbitrary malformed byte-split state is not exhaustively covered.

Reproduction, focused consumers and exact limits are in
`vaxis/reference_probes/vxfw_layout/README.md`,
`vaxis/reference_probes/vxfw_text/README.md`,
`vaxis/reference_probes/vxfw_rich_text/README.md` and
`vaxis/reference_probes/window_output/README.md`. GC/allocator failures, arena
lifetime, readonly slices, native ABI, int-bounded V strings/arrays and arbitrary
uninitialized/dangling source state remain outside parity. App manual lifecycle,
Window scroll/mouse/border and cross-platform runtime contracts remain in the
live audit.

Final integration passes all 44 Vaxis test files, Boo's four focused tests and
native/Linux whole-application checks. Both Windows DLLs and the four new focused
test executables compile. Vaxis also links as an x86_64 Linux ELF shared library
with GC disabled for that cross build. These cross-target checks establish
compilation/link success; Windows/Linux runtime behavior was not executed.
The existing constructor gate also passes in both modes, retaining 38 complete
pairs, 57 paired omission rejections and 79 defaults with its historical
`2917ca5cdc672d99b1c440daed7882a2da028cc5a1325097b444ce88a501dbbd` hash.
The image implementation is unchanged in this checkpoint; its preceding 44-file
test pass remains recorded in the previous continuation.

## Vaxis Window, cell storage and grapheme cache continuation

Window scroll now checks its u16 copy arithmetic, slice bounds and memcpy
overlap before copying. Mouse hit testing checks i17 endpoints in the source's
Boolean short-circuit order. Child borders draw complete top, bottom, left and
right edges before corners, preserving the cells already written when a later
operation fails. Public Window records restore mutable fields and required
payloads; callers now supply the required offsets, dimensions and PrintResult
overflow field. Screen cell indexing uses usize products and explicit bounds
invariants before narrowing to V array indices. These checks survive production
optimization.

Each new runner hashes and copies the complete pinned Vaxis source and locked
uucode graph unchanged, then calls public source methods. Native Source Debug/V
ordinary and Source ReleaseSafe/V production match the following observations:

| Scope | Returning records | Strict trap pairs | Output SHA-256 |
| --- | ---: | ---: | --- |
| Window scroll/mouse | 170,387 | 16 | `a10c9f8d70ece1a016a387f25c12c11bf2840224afc3e2e8e839fcb0523985f9` |
| Window child borders | 19,963 | 16 | `816665627ba1720864c64e93842e7270044f2019add2d181f3ff53f40e5d158f` |
| Window record contracts | 311 | 0 | `016aff5f7db4b2c5d9ba08210bc93d0e150a7c99244051cffdb800c93d54cc8d` |
| Screen cells | 7,088 | 12 | `56a76ac5d4b010ce3cef8fa8f65b5ca92e30d99c440b5432027fac6bd46d983a` |
| AllocatingScreen/InternalScreen | 6,570 | 19 | `c51b3c3a72977c3b02a883b513817c51ec2aec1c66ab3f9bfdd6129a32602404` |
| GraphemeCache | 32,932 | 10 | `331f02b2216d319c23197da6e34213dcfc0dc19bf6208a9ad89706f6a94d9b4d` |

The record-contract and cache hashes include their final newline; the other
hashes join records without a final newline. Traps require an anchored expected panic,
nonzero exit, no ordinary stdout and no unexpected-return marker. Bounds,
assertion, integer and alias failures are separate categories. Source bodies
and visibility are unchanged.

Scroll retains the source's absolute starting row and height-relative stopping
row, ignored parent clipping and over-height early return. Equal or overlapping
nonempty copies retain the inherited memcpy alias panic, including zero-count
scrolling that enters the copy loop. The corpus includes valid 65,025–65,535-cell
copies and caller-byte mutation after scroll. Mouse returns the original event
value and checks no Screen state; nonzero modifiers remain outside this matrix.

Border records cover every location arm and flag combination, borrowed custom
raw glyphs of forced width one, clipping, degenerate corners and saturating
interiors. Sixteen separate failure-state observations also match SHA-256
`98f463b314e182b3d60ac994303f0fe3900b05b7f5cbeef79f571d4da03181ed`.
The fixture-only native FullPanic observer saves cells before defaultPanic; V's
exit observer saves cells during the ordinary panic exit path. Neither resumes
execution or changes source statements. This proves edge-write order without
asserting panic-runtime or stack-trace parity.

Window contracts check seven complete constructors, eleven required-field
omission pairs, two invalid fixed-glyph lengths, thirteen selected defaults and
public record mutation/copy behavior. Twelve wider V i17 initializers, three
alias-required omissions and explicit nil Screen pointers are measured
differences. Source packed Locations layout and union ABI differ from V records.
Two separate carrier-copy observations show V's boxed border sum payloads share
mutable headers/flags, while direct payload record copies remain independent.
Those sum-carrier copies are outside logical copy parity. Screen cell records
include complete styles, hyperlinks, image options, scale, borrowed storage,
clipping before indexing and clearing oversized backing buffers; tiny seeded
arrays exercise indices beyond signed 32-bit range without huge allocations.

GraphemeCache preserves its inline 8 KiB buffer and independent value copies,
exposes the public mutable buffer/index, checks usize addition before wrapping,
checks destination bounds before aliasing, and advances only after copying.
Returned mutable views remain attached to cache storage, including after later
wrapping writes. Its matrix checks every initial index from zero through 8192,
large lengths, native usize endpoints, disjoint internal views and empty puts.
Ten fixture-only panic-state observations also match the actual index and full
initialized buffer at failure. Two constructor/public-state pairs check the
default index, written prefix and native inline size. Unwritten Source default
bytes are undefined and excluded; V retains its initialized fixed array.

InternalScreen, adapting Source's public AllocatingScreen export, now owns
retained grapheme/URI/ID bytes so caller changes can be detected on the next
frame. Initial space buffers are independently owned. Private byte buffers
preserve capacity-fit reuse and current/older borrowed read views, including
an old view's retained length after a shorter write. Writes use usize indices;
reads retain checked source u16 indices and both methods retain the inherited
strict-greater-than coordinate guards. The default equality fastpath and
omission of width/image/wrapped/scale from retained equality remain unchanged.
Public buffer construction is required.

Four alias traps also match separately observed failure state, SHA-256
`c649a7f33f7162d839dd233c1e9883e5395d540dd09d102d178e96c4a8ee6d1a`.
Character, URI and ID writes occur in source order: each public view is cleared,
capacity is ensured and incoming length becomes visible before memcpy. Style
and default state update only after all copies. Fixture-only panic/exit hooks
verify preceding writes, the failing field's length and unchanged flags. Two
supplied-allocator differences remain measured: Source init can fail with
OutOfMemory, and an append failure clears that field, logs and continues with
the other fields. V's managed API exposes neither supplied allocator behavior.
One V-only array-length trap and one complete/omission constructor pair are
checked separately. Capacity growth/remapping addresses, old-view validity
across growth, direct ArrayList payload APIs and post-deinit Source undefined
storage remain managed-storage boundaries.

Reproduction and precise scope are in
`vaxis/reference_probes/window_state/README.md`,
`vaxis/reference_probes/window_border/README.md`,
`vaxis/reference_probes/window_contracts/README.md` and
`vaxis/reference_probes/screen_cells/README.md`, with cache reproduction in
`vaxis/reference_probes/grapheme_cache/README.md` and retained-cell reproduction in
`vaxis/reference_probes/internal_screen/README.md`.

Allocator/GC failures, readonly/nullability type contracts, int-sized V
carriers, native ABI and arbitrary dangling or uninitialized Source state
remain outside these scoped comparisons. App manual lifecycle construction
and production assertions in its private command/focus pipeline require their
own public run/PTY verification; public init/deinit/run are translated, and a
commented Source destroy helper is not an implemented API to reproduce.

Final integration passes all 50 Vaxis test files, Boo's four focused consumers
and native/Linux whole-application checks. Both Windows DLLs and all six new
focused test executables compile, and Vaxis links as an x86_64 Linux ELF shared
library with GC disabled for that cross build. Cross-target runtime behavior
was not executed. The image module is unchanged; its preceding 44-file test
pass remains recorded in the previous continuation.

The affected WindowOutput, Surface, Table, Classic Widgets and Widgets runners
also retain all five historical hashes in both modes, totaling 111,391 returning
records per mode. Classic/Widgets legacy runners choose Source Debug internally;
this additional optimized check used a fixture-only Zig command wrapper that
adds `-O ReleaseSafe` to each native build-exe invocation, with delegated commands
recorded separately. No Source body changed. Their historical substring-based
trap checks remain historical evidence; WindowOutput/Surface retain strict
checks, and the new matrices above use strict failure classification.

## Vaxis App public contracts and runtime continuation

AppOptions is publicly mutable. App's four represented fields (`tty`, `vx`,
`timers`, `wants_focus`) are publicly mutable and required, matching the source's
field presence; init and manual callers supply them explicitly. Init preserves
Vaxis initialization before TTY initialization, empty timers, no pending focus,
clipboard support and all five Kitty keyboard flags. Both command-list and both
focus invariants now use explicit panic guards, retaining them in production.
Layout checks zero terminal dimensions before division and before invoking the
draw callback. Per-event context reset uses a defer, so callback errors reset
phase/consumption as in the source while leaving other fields and pending
commands intact.

Adding a timer now performs the source's stable descending insertion sort on
the complete public list, including existing entries reordered by callers.
The regression failed before the fix with deadlines firing in order 1, 2, 0;
the corrected/source order is 0, 1, 2. Equal deadlines retain arrival order.

Each new runner hash-checks and copies the complete pinned Vaxis source and
locked uucode graph unchanged. No private source methods are exposed or wrapped.
Source Debug/V ordinary and Source ReleaseSafe/V production match:

| Scope | Returning observations | Strict trap pairs | Output SHA-256 |
| --- | ---: | ---: | --- |
| App public record contracts | 5,377 | 0 | `4f65eaf15452bc86bc3df2276c3007e1a50a55d192d98022bb9c5055d7512270` |
| App init/run/deinit, controlled macOS PTY | 32 traces | 7 | `4947fb0e0877a64f4f62d3cf52b83d4833e0d1a2e4b5dcc8755678d3fcc4cc9e` |

Record comparisons cover all 256 framerates, the default, supported Vaxis scalar
projections, mutable pending focus, extreme signed timer deadlines and by-value
timer-list headers sharing item storage. Changing an item through a copied list
changes the original item; shortening the copied header leaves the original
length intact. Two complete constructor types compile in one batched consumer,
and four plain App required-field omissions reject independently in both
languages. Source-only allocator/buffer omissions and the two unavailable V
fields are measured separately. The source rejects an alias that omits timers;
the pinned V type checker accepts that alias, retaining the known required-marker
boundary.

The PTY fixture calls unchanged public App.init, App.run and App.deinit on a real
controlling terminal. It observes init defaults before preseeding the actual PTY
size through public resize, removing initial-reader scheduling variation from
the published dimensions. Callback barriers control input; a terminal controller
answers DA1 and DSR queries. All returning cases restore the complete initial
termios state, observed while the child is still alive. Scenarios cover initial
events and early quit, root/child focus, capture/target consumption, command
batches, equal timers and deferred rearming, manually seeded sorted/unsorted
timer lists and sorting after a new command, redraw, focus reports, local mouse
coordinates and exit behavior,
resize and callback errors. Framerates 0, 60 and 255 are exercised for basic and
timer scenarios. This establishes callback/state behavior rather than a
wall-clock timing or throughput guarantee.

Seven isolated public failures retain their pre-trap callback traces and anchored
panic categories: focus without a handler, a focused widget absent from the next
layout, zero width/height, an invalid render buffer, surface dimension overflow,
and commands added by a draw callback through its borrowed live EventContext.
The last case reaches the post-layout command invariant. The preceding
command-list invariant is retained by source review but is not separately
reached by this public corpus. Strict checks require nonzero exit, the expected
panic line and no ordinary return, DONE or unexpected fixture marker. These
checks do not certify panic stack traces, cleanup on panic or panic runtimes.

Three new focused V test files add ten consumers. Private-adapter checks retain
focus transition/capture error state, the inherited empty focus path, mouse
enter/leave error ordering, pending commands, retained hit lists, consumption
and repeated exits. Both focus assertions also have strict isolated V checks in
ordinary and production builds. The per-event defer has a focused callback-error
consumer; no source EventContext is inspected after App.run returns, since that
would extend its lifetime. Pixel cell dimensions retain floor division.
An additional regression in the existing routing test checks timer firing after
adding a command to a caller-reordered public list.
An isolated V snapshot containing only the previous add_tick body also reproduces
the public PTY mismatch: unchanged Source fires nodes 1, 3, 2, while that old V
body fires 3, 2, 1. This snapshot is separate from the shared implementation and
does not change a Source statement.

Raw terminal streams are retained with their byte lengths and hashes separately
from callback/state equality. Initial queued resize can place screen-clear bytes
before or after init commands, or be skipped on early callback failure. A held
public raw TTY write proves Source's 1,024-byte buffer delays a marker that V's
unbuffered adapter already emits. No normalized or complete terminal-output
parity is claimed. Allocator/GC failure, per-frame arena lifetime, copied TTY
resources and full Vaxis aggregate ownership, App's heap-pointer versus source
value return, ArrayList payload APIs, native ABI, dangling/uninitialized source
state and cross-platform runtime remain separate contracts. These real-clock
cases do not certify signed/unsigned timestamp extremes or arbitrary thread
scheduling.

Reproduction and exact scope are in
`vaxis/reference_probes/vxfw_app_contracts/README.md` and
`vaxis/reference_probes/app_run/README.md`. Final integration passes all 53
Vaxis test files, Boo's four focused tests and native/Linux whole-application
checks. Both Windows DLLs and all three new App focused test executables compile;
Vaxis links as an x86_64 Linux ELF shared library with GC disabled for that cross
build. Cross-target runtime was not executed. The image implementation is
unchanged and retains its preceding 44-file test result.

## TIFF production checks and terminal input/lifecycle continuation

Explicit TIFF guards now retain the source's checked enum, arithmetic, tag-array,
palette and strip failures in production builds. Before the change, production
metadata probes for invalid resolution, mismatched tag-array type and overflowing
palette power returned successfully; the unchanged source traps. Strip sum
addition and subtraction precede division, optional arrays precede height modulo,
and tag-byte multiplication precedes allocation and parallel-loop validation.
HashMap capacity first checks the u64-to-u32 cast, then the checked power-of-two
ceiling. These are distinct native failure categories. Shared DEFLATE fixed-window
rebasing traps before changing the writer end; CCITT and zero-length PackBits also
retain their checked source boundaries. V's signed-int allocation limits have
separate explicit guards and are not paired giant-allocation source results.

The TIFF proofs now pin the full dependency source, selected unchanged Zig 0.15.2
standard-library bodies, target and build mode. They retain exact commands,
consumer hashes, copied source, corpus and complete stdout/stderr with
`--workdir`. Public fixtures do not alter source bodies or visibility. Both
Source Debug/V ordinary and Source ReleaseSafe/V production pass:

| Scope | Returning records | Strict trap pairs | Output SHA-256 |
| --- | ---: | ---: | --- |
| TIFF public metadata/scalar/array/rational reads | 86 | 15 | `c22c2516d50b6861d84f15605a3904f2a4fc935e45c8b3583ca0ead0c76f1346` |
| TIFF decoder, compression helpers and stream positions | 39,707 | 17 | `22c929806d09ca615c320574abc8bb2be684f3d5596ba940f220164977fd6698` |
| Vaxis public input Parser | 79,299 | 19 | `526ddb882d3040c927af9264ffe7ce70cfe5e33fa269ef9f224a6b3b0d2e0502` |
| macOS TTY restoration/post-deinit writes, real PTY | 40 | 0 | `e07ae36d87128e0f3b4a1a18f47dede10a8083e6f5eab232f23d39649472f810` |

TIFF retains its historical decoder corpus/hash, adds zero PackBits length and
invalid CCITT padding traps, and initializes palette cells used by the destination
trap. Metadata covers both byte orders, count-one raw words for fourteen tag
types, empty/SHORT/LONG arrays, scalar reads and all rational input cutoffs without
observing undefined tails. Strict checks require nonzero exit, empty stdout and
an anchored expected panic category. TIFF additionally rejects any unexpected
fixture marker in either stream. Existing V enum/null/array diagnostics have
explicit mappings; panic text, stack, signal and cleanup equivalence is not
claimed. Reproduction and exact exclusions are in
`zigimg/reference_probes/tiff_metadata_bounds/README.md` and
`zigimg/reference_probes/tiff_decode/README.md`.

All five image codec debug hooks are present and their native counterparts run
on the pinned compiler. SGI/IFF/TIFF use V's runtime logger and host struct
rendering; RAS retains its explicit diagnostic schema. The source's default log
selection changes with build mode, while V retains its runtime logger policy.
The old metadata debug-formatter absence claim is corrected above. Generic
rendering, mutable-pointer signatures, allocator/GC ownership and aggregate ABI
remain adaptations.

Parser storage is public and mutable, and both Result fields are mutable and
required. Direct consumers preserve inline-buffer and Result value copies.
Ground text borrows input; CSI codepoint text borrows the Parser's live buffer.
The returning comparison initializes every scratch byte and observes successful
and failed parses, seeded writes, retained text and later input/buffer mutation.
Checks preserve APC slicing, DA1 assertions, invalid mouse enums, Xterm byte
underflow, optional clipboard allocator failure and the source's whole-input
delimiter lookup. UTF-8 output capacity is checked before surrogate rejection;
out-of-range Unicode rejects first. Two direct required-field omissions reject
in both languages. An empty Result alias is separately rejected by Source but
accepted by the pinned V compiler, which drops inherited required markers.

Parser traps require empty stdout, nonzero exit and a complete expected panic
header; emitted line-start unexpected markers reject returned errors or success.
Quoted fixture lines in native backtraces do not count as emitted markers. Packed
event carriers, V strings, GC allocation and the clipboard-presence boolean remain
representation boundaries. Undefined initial Source scratch bytes are excluded.
Details are in `vaxis/reference_probes/input_parser/README.md`.

On macOS, TTY deinit restores the saved termios and leaves the descriptor open as
Source does. Repeated deinit after intervening terminal changes restores it again;
writes and window-size queries remain usable. Query errors propagate through the
fixtures; all 112 post-deinit queries per mode succeed. Forty public PTY cases in
each mode observe raw mode, original/final termios while the child is alive, exact output,
zero through eight deinitializations and four terminal dimensions. The Source
writer has a zero-length caller buffer for this shared unbuffered domain. Larger
Source buffers, public writer/fd layout, error diagnostics, signal internals and
other POSIX runtime behavior remain separate. The runner drains output during
`tcsetattr(.FLUSH)` and retains each raw/state observation; no terminal bytes are
normalized. See `vaxis/reference_probes/tty_deinit/README.md`.

URI reports now preserve raw bytes while applying the pinned host/path escape
predicates and uppercase percent escapes. Existing percent characters are
escaped again, and invalid UTF-8 and NUL path bytes are encoded without rune
normalization. Hostname environment inputs exclude NUL, as environment variables
do. Mouse shape output uses `ew-resize` and `ns-resize`. Rendering and pretty-print
retain their different usize/u16 loop indices, u16 coordinates, u8 scaled-column
product, checked cursor math, skip/write order and denominator/invariant traps.
Pixel-mouse offset checks remain after the zero-dimension early return and survive
production optimization.

The public session comparison uses unchanged Source and an allocating writer for
successful writes. Both modes match 16,088 returning records (2,383 URI, 4,619
mouse, 4,415 pretty-print and 4,671 render), SHA-256
`23bf5bd5b3a2cd33d463591ab4fea0fa798b2427f8bb0502d6b14ab9ef18eb1d`.
Three-frame cases compare initial output, unchanged cache and later mutations,
styles, links, images, Unicode byte inputs, capability combinations, all mouse
shapes and cursor shapes. Large initialized screens distinguish pretty-print's
u16 index from render's usize index. Twelve isolated public failures match strict
panic categories and fixture-only retained-state observers, state SHA-256
`bdd32c1eb11f17c697dfae72d1cb5ce0c0cfffe8edcb0147572fec3adcde4780`.
Source statements and private visibility stay unchanged; observers write state
and continue into the normal fatal panic, without resuming execution.

The V session API returns complete strings. A failing Source writer can expose
partial bytes, run iteration error defers and leave state before a flush, while
V constructs state and output before an external write. Successful allocating
writer observations and strict panic states do not establish failing-writer,
partial-output, flush timing, allocator/GC, native ABI or broad aggregate ownership
parity. The runner retains exact commands, selected child environment, raw
outputs, fixture/source/Unicode provenance and unchanged-tree postchecks.
See `vaxis/reference_probes/session/README.md`. Two focused public regressions
cover raw URI bytes and repeated resize-mouse shape updates in ordinary and
production V builds.

Integration passes all 44 image test files and all 55 current Vaxis test files
(the 54-file module run plus the new session regression file), Boo's four
consumers, and native/Linux whole-application checks. Windows builds pass for
image, Vaxis and Vxfw DLLs, all four affected TIFF/CCITT/PackBits focused test
executables and the new Parser/session regression executables. Image and Vaxis
link as x86_64 Linux shared libraries with GC disabled for those cross builds.
Cross-target runtime was not executed. The shared DEFLATE changes also retain
ordinary native PNG reader and information hashes for 60,760 and 51,223 cases;
their older substring-based trap checks remain historical evidence, separate
from this continuation's strict classifiers. These are bounded checkpoints,
not full repository translation or whole-library equivalence.

## Public image, Style, packed-scale and TIFF record continuation

Image drawing now uses Source's `usize` pixel geometry throughout fit/contain
selection. A 65,535-pixel cell multiplied by a 65,535-cell window previously
overflowed V's signed 32-bit intermediate and selected the wrong scaling axis.
Image and CellSize fields are mutable and required; placement and pixel offset
also require their represented fields. The two path/memory sum wrappers require
their payload. The V-only combined ImageTransmission record retains its existing
zero-image default.

Transmission IDs advance in an exit defer after the capability check, including
the PathTooLong error path. Explicit u32 overflow checks preserve Source's fatal
boundary in production, without changing the retained ID. Local-path length is
checked before base64 allocation. Managed dimension casts occur after conversion
or PNG writing and before entering the transmission helper. PNG's header-validity
assertion now survives production compilation and still precedes buffer writing.
The locked PNG writer continues to emit only its eight-byte signature.

Style fields are public and mutable. Color index/RGB payloads are required and
remain read-only boxed variants. The u32 RGB constructor carrier explicitly checks
Source's u24 range. Color parsing validates all three channel lengths before any
hexadecimal suffix; `rgb:00ZZ/bad/cccc` therefore returns InvalidColorSpec.
The shared OSC parser retains its historical comparison hash. Every Style field
is independently tested in equality, alongside positive nondefault self/copy
equality and safe replacement after copying.

CellScale retains one packed 13-bit pattern in a u16, with checked field setters,
raw bits/from_bits and numeric VerticalAlignment construction. Numeric carriers
are u64 and validate before narrowing: the pinned V compiler can otherwise warn
and truncate literals before a u8 parameter reaches its guard. Source raw packed
alignment 3 remains representable and copyable; numeric enum conversion of 3
traps as an invalid enum, while 4 fails its two-bit cast first. Failed setters
leave the original packed value unchanged. Direct Source packed fields, compile
time builtins, narrow integer types and native layout remain API adaptations.

TIFF Header, PackedTag, TagField and IFD now require eleven represented fields.
IFD.init supplies its empty map explicitly. BitmapDescriptor retains every Source
default. The outer TIFF's Source undefined defaults remain V zero/default state,
with explicit zero Header and nil-stream/empty-map IFD. Existing callers spell
out previously implicit zero fields; decoding and metadata algorithms are unchanged.

New unchanged-source comparisons pass Debug/V ordinary and ReleaseSafe/V production:

| Scope | Returning records | Strict trap pairs | Returning SHA-256 |
| --- | ---: | ---: | --- |
| Image geometry and transmission | 5,506 | 8 | `e58eae6f7ede06b34fc86cfab106ec0a8f106162693f3f06ab0ae5bab3c6157e` |
| Color constructors/parsing/equality and Style mutation/equality | 175,302 | 4 | `8b7ea385d053e6b5fc140b221d6b87c7d026464bff628b613e31d49c8c61dc9c` |
| CellScale packed construction/mutation/copies | 24,580 | 44 | `1cd11fb0acef78afd31bb32546989e382fda9688b3275387855b0f3609b89a52` |
| TIFF defined records/defaults/borrows | 343 | 0 | `e58e21e70207affb3ec52c115ad2cd73af652ce6f14d81ae0385e9f8bf4dea26` |

Image includes all four scale modes, zero/u16-extreme geometry, preserved caller
options, overwritten cell fields, all transmission formats/media, raw bytes,
capability/error precedence, exact packet boundaries and post-conversion casts.
An exact 4,096-byte payload emits only the initial m=1 packet, as Source does.
Its eight strict failures retain next ID and initialized pixel format/raw size;
state SHA-256 is
`89e0105b69174290783306c5ecf88ff4b3ea6fbe07429fe0c5420524a3e77897`.
CellScale covers all 8,192 packed patterns, all field combinations including raw
alignment 3, and 8,192 independent mutation traces. Its 44 strict failures retain
state SHA-256
`3b12f3ab7fac4930f479b2ec9f320ddbe9ef18c293a1fee9e6f4d13b69430172`.

Compiler consumers require ordinary errors with the expected diagnostics; compiler
crashes and backend failures cannot satisfy them. Image pairs nine field omissions
and four fully mutable complete records, with two additional V-only payload wrapper
checks. Color pairs two payload omissions. TIFF pairs eleven omissions and one
immutable-header mutation rejection. CellScale pairs six type rejections and six
complete consumers. Alias-marker loss, Source-only constant/builtin boundaries,
nil/const stream pointers, omitted allocator, and boxed-copy/layout observations
are recorded separately. V aliases still omit inherited required fields, while
the corresponding Source aliases reject.

The Image runner pins both the complete recovered zigimg package and its root
entrypoint, which lies outside the src hash, alongside Vaxis/uucode and selected
Zig math/base64/writer sources. All runners retain exact commands, provenance,
raw diagnostics, inputs and unchanged-source postchecks. Fixtures do not change
dependency bodies or private visibility. Reproduction and precise exclusions are
in `vaxis/reference_probes/{image,style_color,cell_scale}/README.md` and
`zigimg/reference_probes/tiff_records/README.md`.

Source can write and flush a packet before a deferred ID increment traps; V's
complete-string adapter never returns that packet. ID/pixel panic observers do
not establish partial-output, failed-writer or flush-timing parity. Read-only
boxed Color and image-source payloads, unsafe shared Color copies, mutable union
headers, packed/aggregate ABI, allocator/GC lifetime, oversized primitive literals
and undefined Source storage remain separate limits. The pinned PNG writer's
commented encoder bodies and Zig 0.15.2-incompatible legacy helper APIs remain
documented source/compiler boundaries, not translated replacement algorithms.

Integration passes 45 image test files and 58 Vaxis test files, the focused
ordinary/production consumers, Boo's four consumers and native/Linux application
checks. Historical TIFF metadata (86/15), decoder (39,707/17) and Parser
(79,299/19) comparisons retain their preceding hashes in both modes. Windows
cross builds pass the three dependency DLLs and five affected/new test executables;
image and Vaxis link as x86_64 Linux shared libraries. Cross-target runtime is
unexecuted. These results close the listed contracts and remain bounded evidence
for the larger translation effort.

## PNG production checks and strict native comparisons — 2026-10-08

The PNG header, reader, processors, filtering and direct chunk writer now retain
the pinned Source's checked arithmetic and failure ordering in V production
builds. Checks that previously relied on removed assertions are explicit.
Header pixel multiplication remains u8; line multiplication and rounding remain
u32, including pixel overflow before multiplication by zero. Unsupported pixel
depths retain Source unreachable branches. Dynamic Chunk names require four
bytes at the V adapter boundary.

Reader and transparency arithmetic preserves u8/u32 products, additions,
division, casts and exact row division. Assertions retain the Source panic
category. Palette processing checks the unsupported format before an empty row,
preserves successful prefix writes before a bad palette index, and sets processed
state before failing where Source does. Filtering preserves source slice bounds,
eight-bit memcpy length checks, sixteen-bit exact division and unsupported format
branches. The spread helper converts the source row before the destination row.
Direct chunk writing checks addition overflow and memcpy aliasing, writes the
length and section before a flush slice failure, and retains inherited empty
flushes, oversized unframed writes and buffered bytes after returning write errors.

InfoProcessor now requires its writer and preserves tag-name, delimiter, slice
and IDAT arithmetic checks. Count increments before size addition; a size overflow
therefore leaves the incremented count. Earlier failed prints can suppress later
malformed header/text checks. The one-byte iTXt flag cases retain Source's distinct
indexed-access versus slice-range failure order.

The unchanged-source proofs pass both Source Debug/V ordinary and Source
ReleaseSafe/V production. Python constructs inputs; actual Source calls define
the expected output. The following 286,037 returning records and 69 strict panic
pairs exclude constructor controls, V-only adapter traps and the separate
historical foundation rerun:

| Public scope | Returning records | Strict panic pairs | Returning SHA-256 |
| --- | ---: | ---: | --- |
| Header helpers, borrowed names and loadHeader | 59,241 | 11 | `4c45f77f60ecc57f4c0a02c7c666d514eb3112b49bc35bd5d0cba65f2073db0d` |
| Complete decoder, unchanged corpus | 60,760 | 10 | `96ee46b18345684842d8ae9cd64290f7c5e9b86228458a83386a602bbd646e9c` |
| Direct processors and callback adapters | 64,395 | 16 | `09ac13edac49df9819661dccd6625541d1e4590d0e3935e4738bf01bb447d6af` |
| Information diagnostics, unchanged corpus | 51,223 | 16 together with next row | `87adba8bfd33b6f94e620ef6b277496fe1303c0fc80ca07a261f22fae0af7d4a` |
| Information suppression and limit cases | 1,041 | — | `05946f5a7cbbcdc928e51c71edb9d4d6ee25c208ef21611cd4562bf6c91bcff8` |
| Filtering, including historical 43,200 | 43,389 | 10 | `ba128302912d022c765fd89f37431e3961ffbe5b5c35cd6c9d140862401a9c7d` |
| Direct chunk writing, unchanged corpus | 5,960 | 6 together with next row | `934ba176552e9370b30073ea1f648fab7dcb4ca85424296097b173f4d298115e` |
| Chunk overlap, copies and failure order | 28 | — | `4632f854f9f77422d2de7a764c23a1a4fd81ff8223c310bcfb53f8032841e317` |

The two complete-decoder additions reach sixteen-bit spread checks through public
callbacks; no private Source helpers are exposed. Decoder/processor panic state
SHA-256 is
`f2c3d51b1acd37f3f435e2ac9399ae936ce897ff59a34426164bebba2ac8be35`.
Header state retains all seven initialized fields, SHA-256
`64d5b333aa2818162757b169e3a17bc82bdcd5fbeaab6291577b4981b4875797`.
Info state includes counters, input/output position and the entire initialized
output buffer, SHA-256
`529d510c5be49ae7fa2e42b35e70ec2c0786cc88e77e1d87c57c79f7e470445a`.
Filtering checks the actual panic category; chunk failures additionally check
the emitted writer-call prefix. Signals, returned errors, unexpected normal
output or category words occurring only in a backtrace cannot satisfy these
strict gates. The inherited RGB24 transparency zero-increment loop is isolated
and checked by timeout separately from panics.

Header tests cover safe depth/channel products and u32 boundaries, zero/extreme
dimensions, all 24 represented pixel formats, all four borrowed-name byte positions,
header bit flips/truncation, closed enum tags, open method tags, CRC errors and
13/16/17/31/33/64-byte file buffers. They retain the borrowed-IHDR overwrite/CRC
rejection behavior. Three wrong-length names are ordinary Source type rejections
and separate V runtime guards. Info adds a paired missing-writer rejection and
complete direct/init/copy/borrow controls; explicit nil and immutable writer
references remain Source-only rejections. Chunk writing separately checks two V
adapter guards, Source's compile-time invalid ID and two unchanged unsupported
helper diagnostics.

Every proof pins the complete Source src tree, checks it before/after execution,
and retains commands, fixture provenance, inputs, diagnostics and result metadata
in a supplied work directory. Relevant Zig 0.15.2 reader/writer, DEFLATE, formatting,
memory, debug or CRC files are pinned as appropriate. Fresh per-proof global caches
avoid stale shared cache references. Reproduction and precise exclusions are in
`zigimg/reference_probes/{png_header,png_decode,png_info,png_filtering,png_chunk_writer}/README.md`.

The historical foundation comparison also retains all five hashes in both modes:
headers `8cb5945cdde99fe7`, filtering `809cede448778a71`, rows `2ad35f81b5cd96cd`,
processors `b0a838ddd9ac9218` and transparency `0975e75ee48838d7`. Its older
14-failure/zero-stride-loop classifier is supplementary to the strict new gates.

Focused consumers pass ordinary and production; all 49 image and 58 Vaxis test
files, Boo, native/Linux application checks, three Windows dependency DLLs and six
PNG test executables pass. Image and Vaxis link as x86_64 Linux shared libraries.
Cross-target runtime remains unexecuted. Required header/chunk fields, mutable
Chunk fields, const-pointer enforcement, allocator ownership, arbitrary unsafe
carriers, undefined Source storage, aggregate ABI and oversized V array domains
remain separate limits. The pinned encoder bodies remain commented; legacy
writer() and ZlibCompressor remain incompatible with Zig 0.15.2. No replacement
encoder/compressor was invented to make those Source boundaries compile.

## PNG public records and PixelFormat contracts — 2026-10-08

PNG now marks 36 represented Source-required fields across HeaderData, Chunk,
ChunkHeader, specified filters, processor data/vtables/payloads/custom options,
and the generic chunk writer. Existing production callers, tests and native
comparison consumers explicitly initialize those fields. Header/Chunk/EncoderOptions,
standalone processor vtables and transparency payloads expose the Source's
mutable fields. ChunkHeader.name requires a mutable receiver and still borrows
the native-endian numeric type field. Defaults remain false/heuristic for encoder
options, empty processor lists, unset/unprocessed transparency and end=0 for
chunk writing. Source undefined palette, generic processor-array and chunk-buffer
storage is initialized in V and excluded until seeded by the consumers.

The chunk writer now accepts fixed arrays whose byte element is an alias of u8.
Pointer elements and pointer-to-array carriers remain rejected before byte alias
normalization. Inline buffers retain value copies and survive construction from
local storage; copied pointer writers share their underlying writer state.
PixelFormat.bits_per_channel preserves the Source unreachable branch for the
named RGB332/RGB565 values in production instead of relying on a removed assertion.

New unchanged-Source comparisons pass Debug/ordinary and ReleaseSafe/production:

| Public scope | Returning observations | SHA-256 |
| --- | ---: | --- |
| Header, Chunk, ChunkHeader and encoder records | 10,451 | `9cc70d9461b1b38135ca9ed12406d7016c9278e646074cf91277957908a24e03` |
| Chunk-writer records, inline bytes and aliases | 163 | `54fe144e5a027d6259fa65b01ae19169fd5470bf14f350593635306bd6dd9ec9` |
| Processor records, callbacks and option views | 199 | `75975f75febf19e8a3a7085652494075707bef6323eba6455002c39998da2c32` |
| Named PixelFormat methods and packed-info carriers | 197,777 | `9eeaca0cd04514798359ff079b7f9d7f80fd838a8b53bde663154f317a87d349` |

These are 208,590 new returning observations, excluding compiler controls,
separately measured representation differences and the preceding PNG reruns.

The header/chunk proof tests all eleven required fields with paired ordinary
omission rejections, a paired specified-payload rejection and three paired const
rejections. Its matching eleven V aliases accept omissions while Source aliases
reject them. Source rejects a direct short Chunk name and writable const-borrow
bytes; V's string/view adapters accept both. Source's header/filtering filter
enum types are nominally distinct; the translation uses one PngFilterType.

Twenty of 25 copied specified-payload mutations differ because V sum types box
payloads and share them on copying, while Source copies its union payload by
value. These separate observations have Source SHA-256
`1469df14428bc421bcc4aff834e1f6a6cf634da1a3ab3a82c5b8f8e053ef753b`
and V SHA-256
`d7f2fe6c87190cd8191c99c70372a837aba9f1320edd828762c815f08a7c52eb`.
They are excluded from the equivalent returning records. Whole-arm replacement
preserves the demonstrated independent record-copy behavior; direct payload
mutation remains a representation boundary.

Processor records add fourteen complete/default constructor pairs, nineteen
paired required-field omission rejections and two paired readonly rejections.
Three custom-option generic omissions and the DefaultOptions alias are ordinary
Source rejections and V acceptances. Two Source const-pointee rejections record
V's writable vtable/header pointer adapters. Runtime cases cover all callback
presence masks, callback failures with prior writes, copied data and shared
streams/context/header/palette/row storage, mutable standalone vtables, option
slice reslicing and custom-option get() views that borrow the owner's processor
array and refresh erased contexts. Native private vtable/payload types are
inferred from public field types without changing Source visibility.

Twelve direct transparency-payload member-copy mutations all differ separately:
Source SHA-256
`1ed0619962c4a745aa5c91bf340171ab52b454383daed56cf4c71ca11e407498`,
V SHA-256
`e396b5a8aec0e3d4362120be0d7127180cb55f1eb939a398a1916565c04ec456`.
Scalar/RGB payload fields and indexed slice headers share V boxed storage on
copying. Shared slice contents remain shared in both languages; whole-arm
replacement preserves independent descriptors in the equivalent cases.

The generic chunk record separately produces six ordinary Source omission
rejections and six fully built/running V omission acceptances. Pinned V ignores
required attributes on that generic record. Five paired storage rejections
cover word arrays, pointer arrays, pointer aliases, scalar storage and array
pointers. Source permits a record-only scalar W without instantiating writer
methods; V eagerly checks them and rejects it. An additional V control rejects
dynamic arrays of scalar byte aliases. Capacity zero retains V's empty []u8
adapter because V cannot declare a zero-length fixed array. Undefined default
Source buffer bytes are never observed.

PixelFormat covers all 24 named enum members and every low 16-bit info pattern
with three representative padding values, plus full-width edge words, defaults,
mutations, copies, live raw-word borrowing and 1,024 actual Source comptime packing
calls. Two isolated RGB332/RGB565 calls require Source's exact unreachable panic
category in both modes. Invalid closed-enum values never enter returning cases.
Source Info has u8/u4/open-u4/u16 mutable fields; V uses a raw u32 carrier and
projections. Seven Source-only width/field/comptime rejections, four V field-shape
rejections, one V runtime-packing acceptance and two V-only wide-variant values
measure those adaptations separately from numeric parity.

Each comparison pins the complete unchanged Source src tree, preserves private
visibility, verifies compiler versions and checks source/fixture/runner provenance
before and after execution. Selected compiler library files are pinned where the
semantics depend on them. Commands, inputs, raw output/diagnostics and result
metadata are retained. Constructor rejection gates exclude signals, compiler
crashes and backend/linker failures. Reproduction and exact limits are in
`zigimg/reference_probes/{png_records,png_processor_records,png_chunk_records,pixel_format}/README.md`.

The preceding PNG header, decoder/processors, information, filtering and direct writer comparisons
retain all returning and strict-failure hashes in both modes. The five historical
V goldens also retain headers `8cb5945cdde99fe7`, filtering `809cede448778a71`,
rows `2ad35f81b5cd96cd`, processors `b0a838ddd9ac9218` and transparency
`0975e75ee48838d7`. Two test-only empty-stream constructors now use named locals
to avoid a pinned V generated-C failure; this changes no observed algorithm.

All 53 image and 58 Vaxis test files, the new focused ordinary/production
consumers, Boo's four consumers and native/Linux application checks pass. Windows
builds the three dependency DLLs and four new test executables; image and Vaxis
link as x86_64 Linux shared libraries. Cross-target execution remains untested.
Alias/generic required-field enforcement, boxed payload copies, const/sentinel
typing, comptime-only helpers, arbitrary writer specialization, packed/aggregate
ABI, allocator/GC/OOM and undefined Source storage remain explicit limits.
The pinned PNG encoder bodies are commented and legacy writer()/ZlibCompressor
remain Zig 0.15.2 compiler boundaries; no substitute implementations were added.

## JPEG production checks and borrowed Huffman tables — 2026-10-11

JPEG now keeps explicit Source checks in ordinary and production builds:
exhaustive marker/density enum casts, unsigned segment subtraction, DRI's
subtraction before its invariant, late frame/scan length invariants, table
destination/selector bounds, Huffman acceleration/consumption checks, and u5
bit-buffer arithmetic. Its coefficient prediction/refinement, dequantization,
IDCT intermediates/biases/stores, and grayscale rendering use checked i32
operations. The q8 active-union check occurs after destination indexing and only
when a sample is actually multiplied; zero-sized q16 images therefore still return
success. No inactive payload is read in those returning comparisons.

`JpegHuffmanReader` borrows a stable `JpegHuffmanTable` pointer, so caller changes
to inline acceleration entries and lengths remain visible. Table fields and reader
state are public/mutable; the represented stream field is required. Null-table
access now occurs at the Source lookup point: empty input can return a read error
without unwrapping a table, whereas a sufficiently filled buffer still traps.
The decoder's source no-op writer is unchanged.

The unchanged-Source runner `zigimg/verify_jpeg_contracts_reference.py` compares
Source Debug/ordinary V and Source ReleaseSafe/production V:

| Observation group | Returning records |
|---|---:|
| Frame headers and component/sampling controls | 4,600 |
| JFIF headers, errors and truncations | 677 |
| Quantization tables and truncations | 1,032 |
| Huffman table maps/acceleration state | 1,056 |
| Reader operations, partial state, stuffing and restart bytes | 7,946 |
| Live borrowed-table mutations | 80 |
| Complete defined decoding, cleanup, historical fixtures and empty images | 414 |
| **Total** | **15,805** |

Both modes retain returning SHA-256
`c351ba2c35413cc9ff5951a77206a0b6aa3ed55f9a495d6c4f94505e5caa7ae4`.
Thirty isolated pairs require exact native panic categories and identical stream
positions or reader buffer/count/position state. They retain state SHA-256
`d7ddad1f92a7f409a59c64e289a68f9084f8590666d99563990a07640d9c402e`.
Three separate half-second process pairs verify the inherited positional-file
discard loop for a JFIF input ending before its NUL byte, using 16/31/4096-byte
buffers. Complete reader constructors build/run; stream omissions receive ordinary
compiler rejections in both languages.

The Source quantization Header.read helper has a separate ordinary compilation
failure under Zig 0.15.2 (`expected type 'u4', found 'u8'`). The probe preserves
that source boundary and runs two V-only helper controls separately. The actual
JPEG decoder's quantization table parser compiles and is compared without edits.
Each proof pins the full unchanged Source src tree, compiler versions and selected
standard-library sources. Before/after source, compiler-library, fixture, runner,
historical-input and V image-implementation checks retain provenance, commands,
inputs, output, diagnostics, observer files and summary metadata. Compiler crashes,
signals and backend/linker failures cannot satisfy an ordinary rejection gate.

The historical Pillow-generated decoder comparison retains 132 returning rows in
both modes. Seven progressive/subsampled inputs reading undefined coefficient
storage remain excluded; its eighth former exclusion,
`31x17-RGB-0-2-1.jpg`, now matches as an exact marker-enum trap, including any
preceding completed output. The historical runner retains commands/artifacts,
checks the full Source tree before/after, isolates its Zig cache, and rejects
unexpected Source terminations. Undefined coefficient memory is not certified.

All 54 image and 58 Vaxis test files pass, as do both focused JPEG consumers in
ordinary/production builds and native/Linux application checks. Image, Vaxis and
Vxfw build as Windows DLLs; image and Vaxis link as x86_64 Linux shared libraries
from V-generated C using Zig cc. Cross builds use `-gc none`; cross-target execution
is not tested. The new focused JPEG test executable also builds for Windows in
ordinary/production modes with `-skip-running`. Reproduction and the boundary list are in
`zigimg/reference_probes/jpeg_contracts/README.md`. Wider byte carriers, const
typing, one stream pointer in place of Source's reader/stream pair, remaining JPEG
record/Frame APIs, quantization union representation, map layout, SIMD selection,
allocator/GC/OOM/lifetime and aggregate ABI remain explicit limits.


## JPEG public header and table contracts — 2026-10-11

Public JPEG components, frame/JFIF/quantization headers and Huffman tables now
require their represented Source fields and permit caller mutation. Component
reading is public, maximum sampling projections return usize, and header/table
cleanup hooks are available with GC reclamation. Header copies retain independent
scalar fields and component-slice lengths while sharing component storage.

Quantization uses a tagged V sum type with JpegQuantization8/JpegQuantization16
fixed-array payloads, each requiring its values field. This replaces the flattened
precision/q8/q16 record and excludes simultaneous arms. The decoder retains its
explicit Source inactive-q8 check at actual multiplication after sample indexing;
empty q16 images still succeed. Existing consumers use the tagged representation.

The new unchanged-Source proof zigimg/verify_jpeg_records_reference.py matches
**17,747 returning observations** in ordinary and production builds: 12,288 public
component reads/truncations, 3,072 component/header mutation and copy observations,
768 quantization-array element/replacement observations, 1,536 quantization-header
field/replacement observations, eighteen JFIF copies, sixty-four Huffman inline
copies/map-value aliases/borrowed reader observations, and empty sampling maxima.
Returning SHA-256 is
`924be5dd9166431cce22672eead65ce550a96e1d48fc570078d35f145ca2323d`.

Seven complete constructors compile; twenty-two field omissions, seven mutations
through immutable bindings and two invalid tagged-table constructors receive
ordinary compiler rejections in both languages. Two cleanup compile controls
inspect no freed Source memory. The proof obtains private Source component/map-key
types through existing public fields and return types, without changing Source
visibility. Full Source/compiler-library/version pins and before/after fixture,
runner and V image implementation hashes retain provenance, commands, generated
consumers, raw results, diagnostics and summaries. Crash/backend/linker failures
cannot satisfy rejection checks.

Eighteen separately hashed observations expose V sum types sharing boxed array
payloads while Source copies them by value, including a table in a copied header.
Whole-table replacement preserves copies and is part of the matching corpus.
Source accepts const-header mutable-slice pointee mutation where V rejects it;
one compile pair measures this. Five further pairs record byte carriers accepting
constructor values rejected by Source u4/u5 fields. Source and V boxed output
SHA-256 respectively are
`7ddf49db31a6257661b6d7046a12f24466f517b43e4846a896cb176e5d485936` and
`22607c4ce6f4ad8ac93484824f0ecb3c5004ea4f0957dc823c05bfe570aebbca`.
These differences are excluded from returning equivalence counts.

The decoder comparison retains 15,805 returning rows and thirty exact panic/state
pairs in both modes, including the prior output/state hashes. The historical
132-row comparison and marker trap are unchanged; seven undefined-coefficient
inputs remain excluded. All 55 image/58 Vaxis test files, the focused record test
in production and native/Linux application checks pass. Three Windows dependency
DLLs and the new test executable in both modes build; image/Vaxis link as Linux
shared libraries from generated C. Compiler temporary files were moved to the
artifact volume after disk-space failures; affected checks passed on rerun.
Cross builds use -gc none and do not certify cross-target runtime.

Remaining public Frame/Scan/decoder records and methods, allocator/GC/OOM/lifetime,
undefined coefficient storage, boxed copies, const/narrow integer/key typing,
map layout/order/capacity, aggregate ABI and arbitrary SIMD selection remain
limits. Source quantization.Header.read still has its inherited u8-to-u4 compiler
failure under Zig 0.15.2; the actual decoder parser compiles. The generic V as-cast
failure category differs from Source union-field access; the decoder uses its
explicit Source check. The pinned JPEG no-op writer is unchanged. Reproduction
and exact boundaries are in zigimg/reference_probes/jpeg_records/README.md.

## JPEG public Frame operations and value copies — 2026-10-11

JpegFrame now exposes required mutable header, borrowed quantization/DC/AC table
records and coefficient storage, with u32 block dimensions and usize sampling
maxima. Public block wrappers retain fixed 64-sample and three-component arrays;
heap table wrappers expose fixed four-slot optional arrays through values. Frame
read, RGB rendering, chroma conversion, dequantization, IDCT and cleanup hooks are
public. The owner-JPEG pointer is replaced with direct table borrows. Frame.read
and JPEG.read return values, and JPEG.frame stores an optional value: scalar
metadata copies independently while coefficient slices and borrowed tables alias.
JPEG copies retain independent inline table slots; the prior boxed quantization
payload-copy limitation remains separate.

Checked operations preserve Source u16 header-dimension overflow after allocation,
native-width coordinate overflow/division and bounds, i32 chroma masks and RGB
casts, including production builds. RGB writes channels in Source order, retaining
red/green writes when a later cast traps. Destination bounds precede RGB sample
casts. Grayscale loads its coefficient before destination bounds and the checked
level addition. Chained chroma slices check the final eight-lane end against 64;
rows and component stores retain descending alias traversal and f32 arithmetic.
JPEG cleanup keeps record descriptors; GC handles backing reclamation.

The new unchanged-Source proof zigimg/verify_jpeg_frame_reference.py matches
**10,697 returning observations** in both modes: 6,952 Frame read/dimension/header
controls, 2,048 separate/aliased chroma blocks, 256 full conversion/dispatch cases,
640 dequantization/IDCT cases, 784 cropped RGB/grayscale renderings, five constructed
record-copy/full-u32 carrier observations and twelve decoded returned/stored frame
copies. Returning SHA-256 is
`02bea61a685969480894de6596bfd0f16c132107369c1bc4ed2f895d4e2509f0`.
Thirty-five exact panic pairs also match stream position, frame metadata, all
initialized coefficients and pixel bytes; failure-state SHA-256 is
`73fbe0b116d37d3721a82529cfdf615cd69ecc2308879180a9a953e1d97791ea`.

Five complete constructor pairs compile, including execution of six zero defaults.
Nine represented field/payload omissions and five immutable-binding mutations
receive ordinary compiler rejections with actual error-line checks that exclude
crashes and backend/linker errors. Three separately bounded process pairs retain
inherited zero-horizontal-step loops in full chroma conversion, dequantization
and IDCT, timing out without output. Source const Frame table-pointee mutation
accepted where V rejects it, and a V u16 marker value rejected by Source's enum,
are recorded as two separate construction adaptations. Source's undefined default
marker is not read. Full Source/compiler-library/version pins and before/after
fixture/runner/implementation hashes protect retained commands, diagnostics,
generated consumers, output, observer state, provenance and summaries.

The existing 15,805-row decoder and thirty panic/state pairs retain their prior
hashes, as do its three file-discard loops and the 17,747-row records/boxed-copy
proof. Historical JPEG checks retain 132 rows and the marker trap in both modes;
seven undefined-coefficient inputs remain excluded. All 56 image and 58 Vaxis test
files, focused production Frame tests and native/Linux application checks pass.
Three Windows dependency DLLs, the new Windows test executable in both modes and
two Linux shared libraries build with -gc none. Cross-target runtime is unverified.

Frame.read checks inspect metadata/allocation count, never undefined Source
coefficients. Decoded grayscale copy checks inspect only an explicitly written
active sample, excluding unused Source channels. Allocator/OOM/GC/lifetime,
aggregate ABI, const-pointer typing, boxed quantization copies, u4/u5 and map key
typing/layout/order, remaining public Scan APIs, Scan arithmetic on caller-mutated
records and arbitrary SIMD targets remain limits. Chroma bounds are compared with
Source's non-AVX2 aarch64 path; AVX2 mask
behavior is different. Source quantization.Header.read still has its inherited
Zig 0.15.2 compiler failure, and the pinned JPEG no-op writer is unchanged.
Reproduction and boundaries are in zigimg/reference_probes/jpeg_frame/README.md.

## JPEG public Scan records and checked traversal — 2026-10-13

JpegScanComponentSpec and JpegScan now expose mutable required fields; component
slots are fixed [4] optionals, and count/spectral fields retain Source u8 widths.
The public component reader, Scan.init and Scan.perform_scan preserve Source's
Frame/stream borrows. JPEG.read uses the public scan entry point. Source's OR
component/table validity rule, two-bit AC selector mask, spectral checks and late
length assertion remain intact. Native-width MCU identity, grouped block
coordinates, restart products and loop increments are checked explicitly in
production too. Destination block/component bounds precede the swallowed entropy
fill attempt, fixing consumed bytes on malformed caller-built Frames, including
markers without a decode branch.

The unchanged-Source proof zigimg/verify_jpeg_scan_reference.py matches **76,400
returning observations** in ordinary and production builds: 65,541 direct component
reads/truncations, 6,795 Scan initialization/validation/position controls, 1,024
public record mutation/copy/borrow observations and 3,040 direct scan operations.
Returning SHA-256 is
`22ff0ced5a3fb14f5f80f8ff99e012a7f2bb78d38b34e92baf202990342408c8`.
All scan coefficient lanes and padding are initialized before comparison. Direct
scan tables are explicitly constructed public records; canonical table construction
and decoding retain their separate existing comparisons.

Twenty-seven exact panic pairs also match consumed stream bytes and coefficient
state: selector/late-length checks, block/component bounds before fill, restart
overflow/division and missing DC/AC tables. Failure-state SHA-256 is
`26a190953880f66299ebb8834f75b8ad3603c881efa5285386a06543b17fd46e`.
Two complete constructors, twelve field-omission pairs and two immutable-binding
rejection pairs pass with actual error-line checks excluding compiler crashes,
backend and linker errors. Four separate pairs measure V byte carriers accepting
16 where Source u4 selectors/approximation fields reject it. One pair measures V
allowing scalar mutation through Scan's Frame pointer where Source's *const Frame
rejects it. Source const pointee typing is not encoded in the V pointer carrier.
Two bounded process pairs retain zero-horizontal/vertical-step loops without
output when component sampling and restart processing permit them.

Fixed component/prediction arrays, scalar metadata and reader bit state copy by
value; Frame and stream targets remain shared. V optional struct unwrapping
produces a local value, so payload updates require explicit slot replacement.
The pinned V compiler also requires a named option entry before or-unwrapping a
fixed-array element; direct syntax produces a C backend error. The probe and
focused test use the compiling named-entry/writeback idiom. Source and selected
compiler-library/version pins, before/after fixture/runner/implementation hashes,
retained commands/diagnostics/corpus/state/consumers and summaries protect provenance.

Existing Frame/record/decoder/historical JPEG comparisons keep their prior hashes
and exclusions in both modes. All 57 image and 58 Vaxis test files, focused
ordinary/production Scan tests and native/Linux application checks pass. Three
Windows dependency DLLs, the new Windows test executable in both modes and two
Linux shared libraries build with -gc none. Cross-target runtime is unverified.

Unknown components accepted by Source's OR rule leave performScan indexes/sampling
undefined and are compared in init only. Allocator/OOM/GC/lifetime, undefined
coefficient storage, ABI, const/narrow integer/key typing, map layout/order/capacity,
boxed quantization payload copies and arbitrary SIMD targets remain limits. The
Source quantization.Header.read compiler failure and pinned no-op JPEG writer are
unchanged. Reproduction, syntax and exact scope are in
zigimg/reference_probes/jpeg_scan/README.md.

## JPEG retained decoder records and null-pixel failure — 2026-10-13

JPEG.read now retains Source's exact attempt-to-use-null-value panic when a stored
Frame finishes dequantization/IDCT with no optional pixel storage. The previous
custom missing-pixel panic differed from Source. Earlier quantization/IDCT errors
still take priority, and ordinary/production checks observe the transformed
coefficients retained at the null access.

The new unchanged-Source proof zigimg/verify_jpeg_state_reference.py compares
**6,138 returning rows containing 6,408 read attempts** in both modes. Snapshots
include restart interval, Frame metadata and initialized coefficients, all four
tagged quantization slots, all eight Huffman slots and optional pixel tag/length/
bytes. Memory streams and buffered files with 16/31-byte buffers are covered.
Returning SHA-256:
`846e18ebd6cccfb3d5d01147a2b2bede3041669033b573d02cec62de14fb3b76`.

The matrix verifies stored-frame finalization, recoverable-error pixel cleanup,
retained records, truncated/overwritten tables and retries with caller pixel-reset
controls. Complete early tables remain installed when a later table is truncated.
Quantization length underflow precedes installation, while Huffman length underflow
follows installation. Duplicate-frame failure precedes header reads; restart
updates survive subsequent failures. Sixty exact panic/state pairs compare position
and all defined retained data, including missing pixels, earlier failure priority,
wrong arms, short pixel buffers, unreachable component counts, marker/skip failures,
table-installation order and restart lengths. State SHA-256:
`5c752672755ff2581f89c69aa911b00cd30cb1eabfc8d532ebd1242f54c08060`.

All constructed coefficient lanes and pixels are initialized. Fresh Source Frame
storage and unused grayscale channels are omitted from hashes, as are bytes from
fresh pixel allocations. Fresh returning inputs either fail before coefficient
reads or contain a complete baseline scan. Freed pixel storage is never inspected
after cleanup. Source remains unchanged; private component types come from public
fields. Full tree/library/version pins and before/after fixture/runner/implementation
hashes protect retained commands, corpus, output, diagnostics, state and provenance.

Existing JPEG decoder/record/Frame/Scan/historical proofs retain their previous
hashes and exclusions in both modes. All 58 image/58 Vaxis files, focused state
tests in both modes and native/Linux checks pass. Three Windows DLLs, the new
Windows test executable in both modes and two Linux shared libraries build with
-gc none. Cross-target runtime is unverified. Allocator/OOM/GC/lifetime, undefined
or freed memory, ABI, const/narrow/key typing, map layout/order/capacity, boxed
quantization payload copies and arbitrary SIMD remain limitations. The Source
quantization-header compiler failure and no-op writer remain unchanged. Exact
scope and reproduction are in zigimg/reference_probes/jpeg_state/README.md.

## TGA public packed mutation and production failure order — 2026-10-13

The TGA image-type/descriptor records exposed byte getters without counterparts
for assigning their Source packed fields. Encoder options were immutable even
through mutable bindings. Pixel-byte and palette-end checks used assertions
removed by V production builds, as did the shared indexed-8 palette-capacity check.
The 24-bit palette path consumed a byte before checking its destination index,
unlike Source; the old trap-only probes did not compare this position.

Nine public setters now preserve unrelated packed bits; u4/u2 setters check byte
arguments before mutation in both modes. Encoder options are public/mutable and
the writer uses these setters. Explicit guards preserve byte/palette-end overflow
and indexed-8 capacity failures. The 24-bit reader checks its palette destination
before reading a byte; the 16-bit path retains its read-before-index order.

`verify_tga_records_reference.py` compares unchanged pinned Source Debug with
ordinary V and Source ReleaseSafe with production V. Both modes match **274,453
returning observations**: 6,144 image-type mutations, 6,144 descriptor mutations,
262,144 header validations and 21 initialized record/default/copy/option rows.
Returning SHA-256:
`1a09cac1be76dea9fab61a3a330b4f0c484f4f67e5bc08e1cfe0e2f1e719ad36`.

Twenty-four panic/state pairs compare invalid field casts, every overflowing pixel
byte count, palette-end/capacity/index checks, an invalid index at EOF and competing
failure priorities. Snapshots include the unchanged packed byte or stream position,
header, active initialized ID bytes and retained initialized extension. State hash:
`dc9cb7be7b9c8d24f9cbf71550f8deba334d670042f07ab523795fd328586880`.
Twelve immutable-binding mutations receive actual compiler rejections. Three
literal narrow-field and one const ID-pointee compile pairs record differences;
Source sentinel logical lengths 40/40/40/80 versus V physical lengths 41/41/41/81
are also recorded separately. The matching corpus never observes undefined ID,
pixel or footer-signature storage; default Source footer signatures are explicitly
initialized in the fixture. Full tree/library/version pins and before/after hashes
protect the retained commands, fixtures, outputs, state, diagnostics and provenance.

Historical TGA encoder/decoder hashes remain `44cd8ebeb8f84afc` (2,016 cases) and
`04232c58bcb7f905` (1,120 cases) in both modes. All 59 image/58 Vaxis files and
focused production TGA/record/pixel-storage tests pass. Native/Linux application
checks, three Windows dependency DLLs, the new Windows test executable in both
modes and two Linux shared libraries build successfully with cross builds using
-gc none. Cross-target runtime, portable aggregate ABI, allocator/OOM/GC/lifetime,
undefined/freed storage, sentinel/const/narrow typing and arbitrary SIMD remain
boundaries. Reproduction and exact scope are in
zigimg/reference_probes/tga_records/README.md.

## TGA buffered RLE and positional file vector reads — 2026-10-13

TGA's raw RLE path used input buffer capacity as its available-byte count. This
could request more bytes than a file buffer could hold, use an unread capacity
suffix, or stop at a refill boundary. Source `Reader.stream` returns a buffered
prefix immediately and preserves File.Reader's zero-progress transition from
unsupported send-file streaming to direct reads. The translated adapter now
uses that behavior and retains the transition on the owning stream for retries.

The unchanged native comparison also exposed 62 stream-position differences
despite matching pixel bytes. Zig 0.15.2's macOS `posix.preadv` uses only its first
vector, whereas the C shim consumed both destination and read-ahead vectors.
The shim now follows Source on Apple/Haiku/Serenity positional fallback paths,
retaining streaming/native-vector behavior. The file test's former macOS
read-ahead expectation was corrected against Source; direct native comparisons
now verify this buffer state. Runtime certification here is native macOS only.

`verify_tga_decode_reference.py` matches **20,576 decoder rows containing 21,032
read attempts** in ordinary/production modes against unchanged Source
Debug/ReleaseSafe. The corpus covers four pixel widths, both row orders,
raw/repeated/mixed packets, zero dimensions, packet truncation, retries on the same
codec/stream, format failures and alpha extensions. Memory and seekable files
use 26/31/64/128/512/4096-byte buffers, plus 495-byte extension controls.
Successful defined pixels, formats, positions, headers, initialized active ID
storage and retained extensions match. Returning SHA-256:
`cacb26414a35edad54b8c5a41d39b951a5c50cb48ffc26a9544b5c14e381615c`.

Forty-eight separate positional vector-read observations compare byte counts,
destination bytes, positions and buffered lengths, including consecutive reads
and EOF. SHA-256:
`d9028cc6d0c1cb767a3739f9a4da6a994338cfcf11b752a6c3a6ad5a4a11fc2e`.
Fifteen panic/state pairs cover footer/extension capacity and pixel-byte overflow;
state SHA-256:
`62c58cd4c95bfb8d3f1ac53c9d2ba87b8a67be00fd97ef637b5f6c17933079d2`.
The proof pins the complete Source tree, selected compiler libraries including
`posix.zig`, versions, fixtures, runner and V/C implementations, with before/after
checks and retained commands, raw results, diagnostics, state and provenance.
Only successfully initialized pixels and active ID data are observed; Source
RGB555 padding is masked. Private RLE state, indexed palette file decoding,
custom/nonseekable reader modes, allocator/OOM/GC/lifetime, portable ABI and
undefined/freed Source memory remain outside this matrix.

Existing stream/TGA record/PNG decoder-and-processor/JPEG retained-state proofs
retain their hashes in both modes. Historical TGA encoder/decoder tests retain
their 2,016/1,120-case hashes. All 60 image/58 Vaxis files and focused production
TGA/file tests pass. Native/Linux application checks, three Windows DLLs, the new
Windows test executable in both modes and two Linux shared libraries build with
cross builds using -gc none; cross-target runtime is unverified. Reproduction and
exact scope are in zigimg/reference_probes/tga_decode/README.md.

## GIF public packed records and production failure state — 2026-10-13

GIF's header/descriptor/graphic-control flags exposed getters without methods
for assigning Source packed fields. Comment/application constructors accepted
omissions that Source rejects. Plain-text byte-count and indexed-background cast
checks used assertions erased by V production builds. The buffered toss adapter
also trapped before advancing its cursor, whereas Source advances then checks.

Thirteen public setters now preserve other bits and check u3/u2 values before
mutation. Source's nonexhaustive disposal tags 4..7 remain representable through
V's unsafe enum carrier; values beyond seven trap. Comment data and all three
application fields are required. The decoder explicitly initializes its partial
comment placeholder, preserving the existing undefined-memory adaptation.
Plain-text overflow and indexed background initialization/restoration casts now
use explicit production guards. Shared toss preserves cursor mutation for offsets
within V's `int` carrier and checks native usize overflow before assignment.

`verify_gif_records_reference.py` compares unchanged pinned Source Debug with
ordinary V and Source ReleaseSafe with production V. Both modes match **14,875
returning observations**: 5,120 header, 4,608 descriptor and 5,120 graphic-control
mutations plus 27 initialized record/default/copy/extension observations. Copies
preserve inline values, optional controls, borrowed pixels/palettes, sub-image
pointers and mutable extension slices. Returning SHA-256:
`c440937a2fdf13c1e0d4842500aad5820a32d1e23d8680a32cfdbb12e712ffbe`.

Thirty-five panic/state pairs cover invalid packed casts, plain-text overflow,
graphic toss, short loop data, indexed1/2/4 background restorations and direct
buffered-end/usize-overflow toss controls. Snapshots compare the flag byte, cursor,
or defined decoder headers, palettes, frame records, applications and position.
State SHA-256:
`fff55be0cc9007627f8ec87bfea8aa6a12260f7a581ad909294dde3f1fda72c7`.
Two complete constructors, four field omissions, thirteen immutable mutations
and two cleanup compile controls verify the public contract. Five narrow-literal
and one const-slice-pointee compile pairs record differences. A separate maximum
usize toss records Source's failed cursor at `18446744073709551615` versus V's zero;
wider failed cursor state remains outside V's array-index carrier. Source default
magic/version arrays are initialized explicitly; undefined palette/comment/pixel
storage and freed memory are excluded. Full tree/library/version pins and
before/after fixture/runner/implementation hashes protect retained proof artifacts.

Historical GIF Source/V decoder/renderer checks pass in both modes. Existing
stream and PNG decoder/processor proofs retain prior hashes and exclusions.
All 61 image/58 Vaxis files and focused production GIF/record/file tests pass.
Native/Linux application checks, three Windows DLLs, the new Windows test executable
in both modes and two Linux shared libraries build with cross builds using -gc none.
Cross-target runtime, allocator/OOM/GC/lifetime, array-list growth, portable ABI,
const/narrow/nonexhaustive enum typing, wider cursors and the complete decoder state
space remain boundaries. Reproduction and exact scope are in
zigimg/reference_probes/gif_records/README.md.

## Indexed constructors and raw PixelStorage production checks — 2026-10-13

All five indexed V records accepted omitted palette/index fields that Source
requires. Five constructor capacity checks and four remaining resize checks used
assertions erased by production compilation. Raw storage likewise lost its
exact-division and alignment checks in production and checked the original input
address even for empty slices, whereas Source's bytesAsSlice discards that address.

Both indexed fields are now required. Capacity checks trap explicitly before
allocation or active-length mutation, including maximum usize values. Raw views
check byte divisibility before alignment and retain Source's four aligned formats;
empty input bypasses the input-address check. Nine existing PCX fixtures explicitly
provide their previously implicit empty palette without changing expected bytes.
The existing float32 empty-pointer adaptation is retained. Source empty-slice
pointers are undefined: observing the Debug compiler's poison address does not
establish a pointer contract, so the proof excludes those pointer observations.

`verify_pixel_storage_reference.py` compares unchanged pinned Source Debug with
ordinary V and Source ReleaseSafe with production V. Both modes match **4,393
returning observations**: 1,168 indexed constructors, 25 initialized palette/copy/
slice records, 2,192 raw borrowed-storage cases and 1,008 unsupported controls.
Constructor cases inspect only active opaque palettes and explicitly initialized
indices; resize cases initialize the full allocation before shrinking/regrowing.
Raw cases include all tags, four byte patterns and offsets, empty inputs, pointer
identity for nonempty data, shared byte mutation and valid storage slices.
Returning SHA-256:
`8967f88d0296ceb0499e115b004ce6579c8fe87682fc6bd2b40b1f4f36a2823e`.

Ninety-seven strict panic/state pairs cover 45 capacity failures through
constructors/direct/union resizes, all 44 nonzero raw stride remainders and eight
odd-address alignment failures. Observers compare unchanged active palette lengths
and initialized bytes, or untouched raw input; odd-address remainder controls
verify division failure precedes alignment. State SHA-256:
`bc8fdb7c1c467f766f59bd7490211ddb0666cf8e4426fa2b2077fa4a3a506849`.
Five complete constructors, ten field omissions and five immutable resize controls
verify acceptance/rejection. Three narrow-index literal pairs, five constant-record
slice-pointee pairs and one const-byte-view pair record remaining type differences.

Five separate runtime controls confirm the indexed PixelStorage boxed-copy limit:
resizing an original union palette to one also changes the V copy's descriptor,
while Source's copy retains lengths 2/4/16/256/65536. Direct indexed record copies
retain independent lengths and share element storage in both languages. Generic
IndexedStorage/PaletteSize members and direct indexed allocator/deinit interfaces
remain without matching V APIs. Invalid PixelStorage.slice ranges are outside this
valid-range proof. Inactive/uninitialized/freed storage, empty pointers, wider V
array extents, allocator/OOM/GC/lifetime and portable ABI remain boundaries.
Full tree/library/version pins and before/after fixture/runner/implementation
hashes protect retained binaries, diagnostics, snapshots and proof summaries.
Reproduction and exact scope are in
zigimg/reference_probes/pixel_storage/README.md.

The later [public indexed factory checkpoint](zigimg/reference_probes/indexed_generic/README.md)
adds represented generic factories, capacity access and GC cleanup. Its measured
generic-constructor, type-identity and capacity boundaries are separate from
this earlier named/raw-storage matrix.

All 61 image and 58 Vaxis test files pass, together with focused production pixel
storage, PCX and converter tests. Historical native converter assertions pass in
Debug and ReleaseSafe. Existing PNG decoder/processor and buffered TGA decoder/
vector/failure-state proofs retain all prior hashes in both modes. Native/Linux
application checks, three Windows DLLs, the pixel-storage Windows test executable
in both modes and two Linux shared libraries build successfully. Cross builds use
-gc none and do not establish cross-target runtime behavior.

## Checked PixelStorage slices and live iterator bounds — 2026-10-13

PixelStorage.slice used unsafe V slicing without Source's reversed-range/end
checks. PixelStorageIterator narrowed its public usize cursor to int before
array access, so wide cursors could wrap into valid elements. Indexed palette
lookups relied on V array diagnostics instead of Source's checked index/length
failure contract.

Slices now check start/end order before the end bound, using the original usize
values in ordinary and production builds. Invalid storage still ignores all
bounds. The iterator checks its captured end before accessing its borrowed storage,
then checks the live data extent before narrowing the cursor, and checks indexed
palette bounds before conversion. Failed calls preserve the cursor; successful
calls increment once. Invalid variants with manually extended ends continue to
return opaque black, including at the last representable cursor. Initialization
continues to borrow the storage address and capture only its original length.

`verify_pixel_views_reference.py` compares unchanged pinned Source Debug with
ordinary V and Source ReleaseSafe with production V. Both modes match **18,028
returning observations**: 15,840 slice/mutation/color records, 864 independent
iterator copies, 1,152 live replacements across all 24 initial/replacement tags,
144 exhaustion controls, 25 invalid-storage wide-bound controls and three default/
wide-cursor controls. Inputs initialize full pixel bytes and active palettes,
respect narrow Source carriers and compare exact native color bytes, including
signed zero, infinities and quiet/signaling float NaN payloads. Pointer identity
uses integer addresses because V reference equality may compare pointed-to values.
Returning SHA-256:
`3fc36e2d20b78dd224bb160ad63b2c89a4c60203be140cab6bdb8d8173690f99`.

**1,039 strict panic/state pairs** cover 621 reversed/end slice bounds, 345 iterator
data indices, 46 replacements with shorter live storage and 27 active palette
lookup failures. Controls include combined range failures, values beyond 2^31/2^32
and maximum usize. Full Source start/end or index/length diagnostic prefixes match.
Observers compare the live variant, count, initialized pixel/palette bytes and
iterator cursor/end; replacement observers exclude the freed old allocation.
State SHA-256:
`e486145175e57fc2962952fea09e5292f443be38d460a45c5b0ccf8475dae528`.
Two compile acceptance pairs cover defaults and immutable storage passed through
init; four rejection pairs cover immutable next/field mutation. One separate
constructor pair records Source's const-pointer field versus V's mutable-reference
field: direct immutable borrowing is rejected by the V record initializer, while
the public init adapter supports that borrowed use case.

The earlier indexed/raw proof retains both output/state hashes and its separate
boxed sum-type copy differences. Its valid-range scope is supplemented by this
new checked-range proof. Generic factories/PaletteSize/direct indexed allocator/
deinit interfaces, const/narrow carriers, wider allocated array extents,
allocator/OOM/GC/lifetime and portable ABI remain boundaries. Default exhausted
iterators never inspect the undefined Source pixels pointer. Undefined empty
allocation/byte-view pointers and uninitialized/freed storage remain excluded;
empty slices of nonempty allocations retain defined borrowed pointers. Source
visibility and implementation remain unchanged. Tree/library/version pins and
before/after fixture/runner/implementation hashes protect retained proof artifacts.
Reproduction and exact scope are in zigimg/reference_probes/pixel_views/README.md.

All 61 image and 58 Vaxis files pass, along with production storage/iterator/
converter tests. Existing PNG decoder/processor/state matrices and the preceding
indexed/raw proof retain all previous hashes in both modes. Native/Linux app
checks, three Windows DLLs, both focused Windows test executables in ordinary and
production modes, and two Linux shared libraries build successfully. Cross builds
use -gc none and do not establish runtime behavior on those targets.

## Converter production alignment/cast guards and retained image state — 2026-10-13

The converter's unconditional f32 alignment checks and SIMD-prefix float-to-byte
bounds check used assertions erased by production builds. Indexed palette lookup
relied on V's generic array diagnostic. Explicit guards now preserve Source's
alignment, float integer-part bounds and indexed index/length traps in both modes.
Dispatch order is unchanged: same-format and unavailable cases return their Source
errors before alignment. Vector prefixes still truncate without clamping, while
scalar tails round/clamp; finite fractional bounds and pinned ARM64 NaN behavior
remain intact. Undefined empty raw pointers remain outside the comparison.

`verify_converter_contracts_reference.py` compares unchanged pinned Source Debug
with ordinary V and Source ReleaseSafe with production V. Both modes match **2,207
returning observations**: 272 normalized float patterns, 1,088 per-channel finite/
NaN/subnormal/boundary cases, 520 scalar-tail poison cases, 272 byte-to-float cases,
54 dispatch/unaligned-scalar/empty-borrow controls and one native lane-count control.
Cases cover lengths 1..17, repeated vector groups, RGBA/BGRA ordering, statuses,
output bytes and unchanged inputs. Empty borrowed views are sliced from initialized
nonempty allocations, preserving defined pointer alignment. Returning SHA-256:
`4d268d80305ae604a4677384bdb4e952b31656e4f72db0a593afad442c5a12c4`.

**488 strict panic/state pairs** cover 72 misaligned float buffers/views, 12 empty
owned alignment casts, 54 inherited BGR555 inactive-union selections, 30 indexed
palette failures and 320 invalid SIMD float casts. Direct converter and both
unmanaged-image entry points preserve source pixels and active palettes; image
observers also compare dimensions, animation loop count, frame duration and
independent frame pixels. First/final prefix positions and all four channels are
covered. Private failed destination writes and allocator effects are excluded.
State SHA-256:
`43494aae16df032ee5d9f187007f83cbc3c51ca2659806802b1473175f823292`.

The unchanged historical native harness retains its 18,432-slot matrix FNV
`e9de0fd7efd93e19` and 6,066,176-pixel precision FNV `9014fb50e8722857` in both
modes. V's existing two historical test functions and helpers are extracted into
an isolated module containing unchanged copies of implementation/header files.
The fixture prints its computed counts/hashes before assertions; the runner checks
those outputs independently in ordinary and production modes. Matrix slots retain
the historical skipped-trap markers, RGB555 padding masks and indexed-widening
palette scope; they are not counted as new returning cases. Original/generated
fixtures and both original/copied implementations are hashed, and full Source tree,
selected compiler library, versions and runner pins are checked before/after.

All 61 image and 58 Vaxis files pass, as do production converter/image-API tests.
The existing pixel-view and PNG decoder/processor/failure-state proofs retain
all prior hashes in both modes. Native/Linux app checks, three Windows DLLs,
converter test executables in both modes and two Linux shared libraries build.
Interrupted build checks were rerun after removing duplicate generated development
artifacts; completed proof directories and pinned sources/tools were preserved.
Cross builds use -gc none and do not establish cross-target runtime behavior.

Allocator/OOM/GC/lifetime, private failed vector destination state, allocator
alignment choices, undefined raw-empty pointers, narrow/const carriers, wider
allocated array extents and arbitrary SIMD targets remain boundaries. Source
visibility/implementation remain unchanged. Reproduction and exact scope are in
zigimg/reference_probes/converter_contracts/README.md.

## PCX production arithmetic and public failure state — 2026-10-13

PCX coordinate checks, u16 scanline multiplication, end-relative VGA palette
subtraction, zero image dimensions and odd-stride rounding used assertions erased
by production builds. Explicit guards now preserve Source's integer-overflow
traps in both modes. Inclusive dimensions use u16 arithmetic: spans of 65,535
return normally; reversed coordinates and spans of 65,536 trap.

Failure order remains intact. Oversized image dimensions return Unsupported
before zero-dimension subtraction; zero dimensions trap before format rejection.
Direct writing rejects unsupported pixel storage first, then emits the header
before checking dimensions. Its even-width indexed8 path encodes the whole slice
without evaluating height. Decoder scanline multiplication follows header/format/
dimension checks and allocation. VGA offset underflow follows decoding and occurs
before seeking. Existing indexed1/4 carrier assertions describe values Source's
u1/u4 types cannot represent; they are outside this Source arithmetic repair.

`verify_pcx_contracts_reference.py` compares unchanged pinned Source Debug with
ordinary V and Source ReleaseSafe with production V. Both modes match **135,766
returning observations**: 131,070 width/height records, one native header/default/
fixed-array-copy record, 4,480 public image/direct writer cases, 207 decoder cases
and eight return-order controls. Writer cases cover four supported layouts plus
unsupported grayscale8, seven widths, two heights, four initialized patterns and
eight memory capacities. Status, cursor and all visible output bytes match,
including partial writes. Main-output SHA-256:
`01a3c968e6dd94bc6b72e306cece9a095d71b27001f6fa88eb4ce6c991c82379`.
Decoder/control SHA-256:
`1ad4b52c6f7c2ecae9ba806bb86019a7182171bce87d3768f94d7cd9111a8633`.

Decoder cases include 192 fully written small indexed/planar outputs with both
compression flags, ignored zero-run markers and escaped high bytes, plus 15
recoverable failures. They compare retained public headers/cursors and, only for
successful fully initialized outputs, complete pixels and active palettes. Invalid
headers and unsupported formats precede reversed-coordinate arithmetic.

**41 strict panic/state pairs** cover eight direct coordinate failures, five read
coordinate failures, three scanline products, five short VGA end offsets, ten zero
image dimensions, two stride-rounding overflows and eight direct failures after
header output. Strict integer-overflow diagnostics match; observers compare public
header bytes and read cursors, or write cursors and initialized output buffers.
State SHA-256:
`622bc7a90a0f6de57f8e1cf369fdde0fde8aa892685ed79841b91feeb0cc949d`.

All 61 image and 58 Vaxis test files pass, together with production PCX/image-API
tests. The unchanged historical native PCX harness passes Debug and ReleaseSafe
after its complete pinned test-import tree is copied into the temporary fixture.
Existing PNG decoder/processor/failure-state matrices retain all prior hashes in
both modes. Native/Linux application checks, three Windows DLLs, PCX Windows test
executables in both modes and two Linux shared libraries build successfully.
Cross builds use -gc none and do not establish cross-target runtime behavior.

The proof uses public interfaces and initialized memory streams. Larger planar
inputs, dummy-byte paths, Source-unwritten pixels, private allocated/freed failure
state, file streams, allocator/OOM/GC/lifetime, enum/narrow/const typing, wider
allocated extents and portable ABI remain boundaries. Source's nonexhaustive
palette enum is represented with an explicit unsafe V carrier; compression values
remain within Source's two valid tags. Header reserved-field naming and allocator
parameters retain their documented V adapters. Source visibility/implementation
remain unchanged. Full tree/library/version pins and before/after fixture/runner/
implementation hashes protect retained proof artifacts. Reproduction and exact
scope are in zigimg/reference_probes/pcx_contracts/README.md.

## BMP production arithmetic, casts and public failure state — 2026-10-13

BMP dimension/scanline products, minimum signed-height subtraction, image byte/
file-size construction and integer casts relied on assertions erased by production
builds. Explicit guards now retain Source's arithmetic-overflow and destination-
type diagnostics in both modes. Pixel indexing checks signed addition, conversion
and the active array extent before access, preserving Source index/length traps.

The public image writer selects supported storage before size construction, and
constructs file size before dimension casts or output. Direct writing emits the
file header before rejecting Windows 3.1 headers, emits V4/V5 headers before
rejecting unsupported pixels, and checks row arithmetic/bounds afterward. Partial
memory writes therefore precede later arithmetic/bounds failures. Readers retain
parsed headers, reject unsupported formats before arithmetic and preserve cursors.
The Source's ignored offsets/masks, absent row padding, signed-dimension behavior
and V5 writer masks remain intact.

`verify_bmp_contracts_reference.py` compares unchanged pinned Source Debug with
ordinary V and Source ReleaseSafe with production V. Both modes match **11,378
returning observations**: one defined default-header/native-layout record, 75
signed dimension accessor records, 240 format dispatches, 10,368 public image/
direct writer cases, 654 direct/image decoder cases and 40 error-order controls.
Writer cases cover BGR24/BGRA32 and unsupported grayscale8, three direct header
variants plus image construction, six widths, four heights, three patterns and
twelve output capacities. Status, cursor and every initialized output byte match.
Main-output SHA-256:
`9b413f62c620cdc82ad314065a403fde50455c7eb04bde405c3c0953aff8e064`.
Decoder/control SHA-256:
`2d19b419f20e31609996f7887a5fd9258e4036c2d5fe2172a728a2d7da9c406d`.

Decoder cases include 480 fully written direct/image successes, 104 truncations,
24 validation-order checks, 18 unknown header sizes and four Windows 3.1 rejections.
Twenty-four negative-dimension direct reads compare lengths/headers/cursors only;
Source-unwritten pixels are excluded. Zero height with maximum signed width still
returns an empty image. Unsupported image pixels return before overflowing sizes.

**152 strict panic/state pairs** cover 16 read products, 16 negative count casts,
four minimum read heights, 24 negative image-reader dimensions, four minimum direct
write heights, eight direct scanline products, 60 direct pixel bounds, 16 image
size/dimension failures and four image bounds failures. Two of those image bounds
cases establish fitting u32 file-size construction at the boundary before failure
on an empty pixel slice. Diagnostics match complete expected prefixes. Observers
compare direct public headers/read cursors, or write cursors/initialized output
and direct headers. Image-reader observers expose only the public input cursor.
State SHA-256:
`59aacb757a0572b8742e645599d049965f7df9d2c7715abd1e075bb371510d89`.

All 61 image and 58 Vaxis test files pass, together with production BMP/image-API
tests. The unchanged historical native BMP harness passes Debug and ReleaseSafe.
Existing PCX and PNG decoder/processor/failure-state proofs retain all prior hashes
in both modes. Native/Linux application checks, three Windows DLLs, BMP Windows
test executables in both modes and two Linux shared libraries build successfully.
Cross builds use -gc none and do not establish cross-target runtime behavior.

The proof uses public interfaces and initialized memory streams. Source's default
BMP headers are undefined and excluded; all observed header fields and enum tags
are defined. Private allocations/partially constructed images, unwritten/freed
pixels, file streams, allocator/OOM/GC/lifetime, boxed union copies, enum/const
typing, wider allocated extents and portable ABI remain boundaries. Completed
proof binaries/logs/provenance and pinned sources/tools were retained while
regenerable compiler caches were cleared to recover disk space. Source visibility/
implementation remain unchanged. Full tree/library/version pins and before/after
fixture/runner/implementation hashes protect retained proof artifacts. Reproduction
and exact scope are in zigimg/reference_probes/bmp_contracts/README.md.

## Image editing production checks and retained mutation state — 2026-10-13

Both image APIs' row-size checks and the editor's zero-height flip check used
assertions erased by production builds. Explicit guards now preserve Source's
division-by-zero diagnostics. Crop offsets previously wrapped or narrowed to int
before source bounds checks; products/sums now check usize arithmetic in Source
order and ranges are validated before narrowing. Invalid-storage palette unwraps
retain Source's null-value diagnostic, including for zero-sized crops.

Native inspection also exposed overlapping rows during malformed flips. Source
uses floor byte rows and can complete outer swaps before a checked memcpy alias
failure on the inner rows. V now traps at that same point and preserves completed
mutations. A five-byte buffer at height two still keeps its middle byte; a nonempty
buffer whose byte row size is zero still loops without advancing. Width and pixel
stride do not replace Source's byte-based flip behavior. Crop still copies active
palettes before its zero-dimension early return and discards animation in results.

`verify_image_editor_contracts_reference.py` compares unchanged pinned Source
Debug with ordinary V and Source ReleaseSafe with production V. Both modes match
**42,034 returning observations**: one Box default/copy record, 8,100 clamps,
3,120 row-size records, 13,122 double-flip records, 17,664 crop/mutation records and
27 wide empty-crop/clamp controls. Row/flip cases cover all 24 storage variants;
crop cases cover all 23 data variants. Inputs initialize full pixel bytes and
active palettes, respect narrow carriers and compare float storage as raw bytes.
Returning flips observe both swaps; crop records compare independent nonempty
allocation pointers, changed result bytes/palettes and unchanged source storage.
Main-output SHA-256:
`6e4fbba5bf6989991bc3265f8853403464eea19843ed7056094ece7414d1faa3`.
Control SHA-256:
`9ad6adc71fc4b52ef25731150dbd38ec3571611a5e1a673f54874026c9661c91`.

**524 strict panic/state pairs** cover 144 zero-height flips, 96 zero-height row
sizes, 69 short crop sources after a privately copied first row, 138 crop offsets
above 2^31/2^32, 24 overlapping flips, 15 crop offset arithmetic failures, nine
crop count products, nine invalid palette unwraps, five direct clamp failures and
15 matching crop-clamp failures. Snapshots compare public input dimensions,
storage, active palettes, loop counts, duration bits, shared first-frame pixels,
independent second-frame pixels and caller boxes. Failed crops exclude private
destination writes; failed flips preserve and expose earlier completed swaps.
State SHA-256:
`913682a5a4bf69433ecdf609cf1e39b27a194d7c61291f0b2cb2bc7b3cf243cd`.
Three separate Source/V timeout pairs confirm inherited zero-row loops through
direct/unmanaged/managed entry points in each mode; they are counted separately.

All 61 image and 58 Vaxis test files pass, along with production editor/image-API
tests. The unchanged historical native image-API harness passes Debug/ReleaseSafe,
retaining its 6,528-case encoder FNV e49e6984a209c47b and 589,824-case detection
FNV ac90c12c037cfaf4. Existing pixel-view and PNG decoder/processor/failure-state
proofs retain all previous hashes in both modes. Native/Linux application checks,
three Windows DLLs, editor Windows test executables in both modes and two Linux
shared libraries build successfully. Cross builds use -gc none and do not
establish cross-target runtime behavior.

Allocator/OOM/GC/lifetime, private flip temporaries/crop destinations, undefined
empty pointer identities, uninitialized/freed storage, boxed sum-type copies,
narrow/const typing, wider allocated extents and portable ABI remain boundaries.
Source visibility/implementation remain unchanged. Full tree/library/version
pins and before/after fixture/runner/implementation hashes protect retained proof
artifacts. Reproduction and exact scope are in
zigimg/reference_probes/image_editor_contracts/README.md.

## SGI production RLE bounds and retained decoding state — 2026-10-13

SGI's channel-size and absolute-offset checks used assertions erased by production
builds. Its RLE table allocation also widened arithmetic that Source evaluates in
u16. Explicit guards now preserve the largest fitting 8,191-row/65,528-byte table
and trap on 8,192 rows before allocation or input consumption, retain u16 channel
products and preserve absolute-offset underflow. Byte indices are checked against
actual extents before narrowing to int, retaining full Source diagnostics.

Native comparison identified a separate failure-order difference in repeated
16-bit RLE words: V could write the high byte before failing to read the low byte.
Both bytes are now read before output, as in Source. Literal assignments check the
destination before reading each source byte; repeated assignments check each
destination byte after the full source word is available. Partial writes and
simultaneous source/destination failures retain Source behavior. Two-byte command
words still ignore their high byte for every channel width other than one.

`verify_sgi_contracts_reference.py` compares unchanged pinned Source Debug with
ordinary V and Source ReleaseSafe with production V. Both modes match **795
returning observations**: one initialized header/layout record, 25 dimension
records, 360 format dispatches and 409 public decode/decompression controls.
Controls cover initialized output capacities, packet prefixes, literal/repeated
counts 0..2, early terminators, multiple rows/channels, reversed packet storage,
trailing input, offsets, table boundaries, uncompressed/fully defined RLE reads
and validation order. All fixture enum tags are valid Source values.
Header/dimension/dispatch SHA-256:
`5d61def8690c6c1546c829ce329e011797d9aa47f8a68f66cd20eedd89eae9cd`.
Returning decoder SHA-256:
`4cc111e3180b24ed9a7eb7601251324feb34c4ecde170b703759e0ced25ea41c`.

**636 strict panic/state pairs** cover 549 packet bounds, 75 offset/data bounds,
four table arithmetic failures, two channel products and six zero-channel public
reads. Full panic text and case names are included in the state golden. Snapshots
compare reader cursors, initialized public headers, four active inline palette
entries and initialized caller output, including partially completed writes.
Private table/data buffers and failed/freed pixel allocations remain excluded.
State SHA-256:
`3e8a57024951a8948a64b350aaa3859a88338ece93378485fa104b4dfc0e0dd9`.

Source's word-view reinterpretation keeps the byte slice's original length. V
now checks the same logical word index/length before reading defined word bytes.
Source word reads beyond the physical byte allocation remain undefined and are
excluded. RGBA64's byte-indexed/endian-swapped alpha, two-byte grayscale selecting
grayscale8, unclipped RLE runs, absolute tables, complete compressed-input
consumption and the no-op writer remain intact. The private header type is inferred
through its public field without modifying Source visibility.

All 61 image and 58 Vaxis files pass, as do production SGI/image-API tests and the
unchanged historical native SGI harness in Debug/ReleaseSafe. Existing PNG decoder/
processor/failure-state hashes remain unchanged in both modes. Native/Linux app
checks, three Windows DLLs, SGI Windows test executables in both modes and two
Linux shared libraries build successfully. Interrupted checks were rerun after
clearing regenerable compiler caches and superseded discovery/development outputs;
completed checkpoint proofs and pinned sources/tools were preserved. Cross builds
use -gc none and do not establish cross-target runtime behavior.

Default Source headers/inactive inline palettes, malformed successful reads with
unwritten private data, allocator/OOM/GC/lifetime, pointer/slice layout, file
streams, invalid enum tags, wider allocated extents and portable ABI remain
boundaries. Source visibility/implementation remain unchanged. Full tree/library/
version pins, generated input hashes and before/after fixture/runner/implementation
hashes protect retained proof artifacts. Reproduction and exact scope are in
zigimg/reference_probes/sgi_contracts/README.md.

## Farbfeld production dimension casts and retained stream state — 2026-10-13

Farbfeld's image writer used an assertion for narrowing image dimensions to u32.
Production V erased it and silently truncated dimensions that pinned Source
rejects. An explicit guard now preserves the checked cast before storage dispatch
or output. Fitting zero/inconsistent/maximum dimensions, unsupported-storage
rejection before header output, and writing the entire rgba64 slice remain intact.

`verify_farbfeld_contracts_reference.py` compares unchanged pinned Source Debug
with ordinary V and Source ReleaseSafe with production V. Both modes match
**44,535 returning observations**: 26 initialized header/default/copy records,
43,200 direct/image writes across all valid storage tags, 1,024 truncated-prefix
reads, 16 trailing-input reads, eight wide zero-extent reads, 16 corrupted-magic
reads, 182 detection controls and 63 fixed-buffer/cursor write controls. Header/
write records have SHA-256
`30e565c1698cf8f2571c3405cc15e428acd7036147fa212e996733267dea1b33`;
the remaining records have SHA-256
`37dc326a7a00abc25b65792b07f77531565d3208007ad1425e21df2a3d63db35`.

**240 strict panic/state pairs** cover width/height/both casts above u32, values
through usize maximum, supported and unsupported storage, output capacities and
initial cursors. Exact panic text and case names join unchanged caller dimensions,
pixel storage, writer cursor and initialized output in the state golden:
`ac87959369cc8d77564382026061029c1d58bce6f7c6266cdd616e6a9ee5b287`.
Read failures compare retained initialized public headers and input cursors;
private failed/freed pixel allocations are excluded. Successful results compare
native channel bytes, independent nonempty allocation and post-mutation result/
input bytes. Header copies retain independent field mutation. No empty pointer
identities or inactive palette bytes are observed.

All 61 image and 58 Vaxis test files pass, as do production codec/image-API tests
and the unchanged historical native image-API harness in Debug/ReleaseSafe. Its
6,528-case encoder FNV e49e6984a209c47b and 589,824-case detection FNV
ac90c12c037cfaf4 remain unchanged. Existing PNG decoder/processor/failure-state
matrices retain their previous hashes in both modes. Native/Linux application
checks, three Windows DLLs, Windows codec test executables in both modes and two
Linux shared libraries build successfully. Disk-interrupted checks were rerun;
the remaining comparisons used a task-owned RAM disk and their completed
artifacts were archived before detaching it. Cross builds use -gc none and do not
establish cross-target runtime behavior.

Allocator/OOM/GC/lifetime, wider allocated extents, boxed storage copies,
pointer/slice layout, file streams, big-endian bulk writes, Source allocator/
ignored-options arguments and portable ABI remain boundaries. Native header bytes
do not establish portable layout. Source visibility/implementation remain
unchanged. Full tree/library/version pins and before/after generated-input,
fixture, runner and implementation hashes protect retained proof artifacts.
Reproduction and exact scope are in
zigimg/reference_probes/farbfeld_contracts/README.md.

## QOI required records, color factories and parsed-header traps — 2026-10-13

QOI color/header constructors omitted Source's required fields, encoder options
were immutable, and pixel-format checking used an assertion erased by production.
Required fields and mutable options are restored, with explicit exhaustive-format
and unsupported-factory traps. The factory now recognizes transparent RGB24/RGBA32
aliases while rejecting pointer inputs as Source does.

Native comparison identified a separate parsed-header failure-order gap: Source's
big-endian `takeStruct` validates both enum fields while swapping on little-endian
targets, before assigning the public header. V now rejects malformed enum bytes
at the same cursor with the previous initialized header intact. Full header reads
still precede validation. Incomplete headers, wrong magic, bytewise packet failures
and unconsumed/unvalidated decoder end markers retain their original behavior.
Image dimensions intentionally truncate to u32, and encoding still uses the full
pixel slice independently of header dimensions.

`verify_qoi_contracts_reference.py` compares unchanged pinned Source Debug with
ordinary V and Source ReleaseSafe with production V. Both modes match **198,560
returning records**: 36,864 color/factory observations, three alias/options/layout
records, 100 initialized header/dimension/format/copy records, 27,840 all-storage/
encoder writes, 133,749 decoder/detection controls and four valid enum controls.
Header/color/encoder SHA-256:
`8f25ed18baa760e49e30af9e067589232b0b0c4e9a85ed20c0a91351015ace36`.
Decoder/control SHA-256:
`defd0517da4d75e5e2c29738aef5727c6a952721b330828c13f865d909dccf0e`.

**677 strict panic/state pairs** cover every malformed format/colorspace byte,
simultaneous enum failures before allocation arithmetic, direct/image entry points,
initial cursors and five unsupported factory types. Exact panic text and names join
initialized reader/header/input or actual caller-value snapshots in SHA-256
`22a915f9007f737de8becde6d090e21e29d5ecc3541a5f145b303c0754e642e2`.
Two complete constructors, seven field omissions, default codec acceptance,
mutable options and const-option rejection pass compiler controls. Returning
decodes compare changed independent result bytes and unchanged input; failures
exclude private failed/freed storage. No empty pointer identities or inactive
palette bytes are observed.

All 61 image and 58 Vaxis test files pass, as do production codec/image-API tests
and the unchanged historical native image-API harness in Debug/ReleaseSafe. Its
encoder and detection matrix hashes remain unchanged. Existing PNG decoder,
processor and 26 retained failure-state hashes remain unchanged in both modes.
Native/Linux application checks, three Windows DLLs, Windows codec test
executables in both modes and two Linux shared libraries build successfully.
Checks used a task-owned RAM disk; completed artifacts were archived before
detaching it. Cross builds use -gc none and do not establish runtime parity.

Default Source QOI headers are undefined; the V placeholder is unobserved and
outside the parity claim. Direct invalid typed enum values, big-endian runtime,
allocator/OOM/GC/lifetime, wider allocated extents, boxed storage copies,
pointer/slice layout, const/narrow typing, file streams and portable ABI remain
boundaries. Source visibility/implementation remain unchanged. Full tree/library/
version pins and before/after generated-input/consumer, fixture, runner and
implementation hashes protect retained proof artifacts. Reproduction and exact
scope are in zigimg/reference_probes/qoi_contracts/README.md.

## Sun Raster required headers, palette bounds and parsed enum traps — 2026-10-13

Sun Raster's header omitted Source's required fields and its big-endian reader
accepted enum values that Source rejects while swapping on little-endian targets.
Required constructors and the parsed-header checks are restored, preserving the
previous initialized public header after consuming a complete malformed header.
Palette capacity checks now retain Source's full slice-end diagnostic before
resize, allocation or input; one-bit indexed reads retain the source-buffer slice
diagnostic before copying. Existing tests now initialize all required fields.

`verify_ras_contracts_reference.py` compares unchanged pinned Source Debug with
ordinary V and Source ReleaseSafe with production V. Both modes match **42,905
returning records**: native layout, dimensions/header copies, all-tag format
dispatch, no-op writers, raw/RLE/palette helpers, public decoding, truncation,
wide zero extents and validation order. **21 debug-print controls** preserve exact
enum labels. Header/dispatch/writer SHA-256:
`5eb7d5959e413859877b0343cb222f90f2555ccf0a80176cb7612508328f0583`.
Decoder/control SHA-256:
`9844e90533766c19eb07668ba6d0f3b9ad46947360dcb233e561161a1d53d493`.
Debug SHA-256:
`e6dc540b17c9a8383a48e25b22e44b27b0ce638a73c1fc64e10a9422992f9c96`.

**576 strict panic/state pairs** cover 448 one-bit indexed slice failures, 60
palette-capacity failures through u32 maximum length and 68 parsed enum failures.
Full diagnostics and case names join reader cursors, initialized public headers,
active palettes, caller output and unchanged input in SHA-256
`960db8d79a310328d870cefb371f62730d47fc48a4f74ecd8bf09b291afb41c8`.
All inline palette backing entries are initialized through public slices before
shrinking the active view; expanded active slices after short reads remain
defined. Palette resize precedes reading, and component assignments follow a full
planar-buffer read. Failed private/freed storage is excluded. Returning pixels/
palettes remain independent after mutation; input and codec palette stay unchanged.
One complete constructor, seven field omissions and default codec acceptance pass
compile controls. The private header type is inferred without visibility changes.

All 61 image and 58 Vaxis test files pass, as do production RAS/image-API tests
and the unchanged historical native RAS and image-API harnesses in Debug and
ReleaseSafe. Existing PNG decoder, processor and 26 retained failure-state hashes
remain unchanged in both modes. Native/Linux application checks, three Windows
DLLs, Windows RAS test executables in both modes and two Linux shared libraries
build successfully. Checks used a task-owned RAM disk; completed artifacts were
archived before detaching it. Cross builds use -gc none and do not establish
runtime parity.

One-bit padding/polarity and raw indexed copying, absent padding for other depths,
opaque 32-bit conversion, palette-length dispatch, ignored declared image length,
RLE escape/clipping/trailing-input behavior and successful no-op writing remain.
Default Source headers/inactive storage, the unobserved V header placeholder,
direct invalid typed enums, big-endian runtime, allocator/OOM/GC/lifetime, wider
allocated extents, boxed storage copies, pointer/slice layout, const/narrow typing,
file streams and portable ABI remain boundaries. Source implementation remains
unchanged. Full tree/library/version pins and before/after generated-input/
consumer, fixture, runner and implementation hashes protect retained artifacts.
Reproduction and exact scope are in
zigimg/reference_probes/ras_contracts/README.md.

## Netpbm required headers, production arithmetic and complete-row bounds — 2026-10-13

Netpbm's public header omitted five required fields, and both direct encoder
options and the three registry wrappers made Source's mutable binary flag
immutable. Required constructors and mutable options are restored. Image reads
now check usize pixel-count multiplication after assigning the parsed header and
choosing its format, before allocating. Sample normalization retains checked
multiplication and zero-divisor failure after Source's reads; ASCII RGB consumes
all three numeric tokens before normalization.

Binary PBM writing previously checked each pixel separately, so a short row could
emit bytes before failing. It now checks Source's complete row slices before any
bits from that row. Native comparison established that the pinned compiler merges
the nested slices and reports the absolute end against the full sample length.
Previous flushed rows and writer-header failure precedence remain intact.

`verify_netpbm_contracts_reference.py` compares unchanged pinned Source Debug with
ordinary V and Source ReleaseSafe with production V. Both modes match **137,228
returning records**, including two default/mutated option records: initialized header copies, all-tag format/storage/option dispatch,
P1..P6 decoding, every binary byte value across scaling boundaries, ASCII numeric
quirks, complete input prefixes, zero extents, detection, bounded partial output
and wide dimensions independent of gray/RGB storage. Decoder/header/writer
SHA-256:
`4118a6e16700c47662af2df6322aaf95bc166def639588c2f87410785b4a9da9`.
Option default/mutation SHA-256:
`91d67440ca5ce2fee2309c9b5ca5e2a28b6ac2aa5ff927010127c0a911e10b73`.

**969 strict panic/state pairs** cover 660 zero divisors after their required
reads, 288 dimension multiplication failures before allocation and 21 complete-row
failures across direct/static/interface PBM writers. Exact diagnostics and names
join reader/writer cursors, initialized scalar headers, caller output and
unchanged input in SHA-256
`03232409ef93ef7c3ff22f197b43c67876c19dd9d0b1cb0ac22fc140e0a0aa09`.
Successful decodes compare independently allocated, fully written pixels before/
after valid mutation and unchanged input. Failed private/freed pixels and header
padding are excluded. One complete header constructor, five field omissions,
three default codecs, four mutable option controls and four immutable-binding
rejections pass compiler controls.

Reader specialization still does not restrict parsed format. Writer format
rejection precedes output; unsupported storage follows the complete header.
ASCII bitmap and gray/RGB writing still use the complete pixel slice independently
of dimensions. Header/numeric comments, signed zero, repeated underscores, the
16-byte token limit, single delimiter consumption, raster bitmap polarity and
non-whitespace/comment-byte behavior, row padding, raw gray16, unscaled/truncated
ASCII grayscale and truncating RGB normalization remain unchanged.

All 61 image and 58 Vaxis test files pass, as do production Netpbm/image-API
checks and unchanged historical native Netpbm/image-API assertions in Debug and
ReleaseSafe. The image-API encoder and detection matrix hashes and existing PNG
decoder/processor/26 retained failure-state hashes remain unchanged in both modes.
Native/Linux application checks, three Windows DLLs, Windows Netpbm tests in both
modes and two Linux shared libraries build successfully. Disk-interrupted platform
checks were rerun with executable outputs and compiler temporaries on the owned
RAM disk. Completed proof artifacts are preserved before detaching it. Cross
builds use -gc none and do not establish runtime parity.

Default Source headers and the unobserved V placeholder, enum widths, narrow/
const typing, physical records/slices/unions, boxed copies, allocator/OOM/GC/
lifetime, wider allocations, file streams, big-endian runtime and portable ABI
remain boundaries. The largest native 16-digit sample fits normalization's
64-bit multiplication; narrower-target overflow is outside native runtime proof.
Source implementation/visibility remain unchanged. Full tree/library/version pins
and before/after generated-input/consumer, fixture, runner and implementation
hashes protect retained artifacts. Reproduction and exact scope are in
zigimg/reference_probes/netpbm_contracts/README.md.

## PAM public option unions, production traversal and retained stream state — 2026-10-13

PAM's public encoder options were immutable and its write methods accepted only
the PAM payload instead of Source's complete option union. Both mutable fields
and full-union calls are restored. Image writing defaults other option tags to
empty comments/no duration metadata. Frame writing retains unsupported-format
rejection before the exact PAM arm trap, then header output before traversal.
The format interface now passes the original option union through directly.

Frame writing flattened width × height into an int, changing wide extents and
pixel-bounds failures. It now follows usize row/column loops and checked offsets,
retaining complete earlier pixels/frames before the first missing pixel. Zero
height bypasses traversal even with maximum width. Source's omitted grayscale2
writer arm retains its production unreachable trap before indexing. Output
capacity errors keep their precedence through partial headers and components.

`verify_pam_contracts_reference.py` compares unchanged Source Debug with ordinary
V and Source ReleaseSafe with production V. Both modes match
**74,192 returning observations**, including three option borrow/copy/mutation
records: all tuple/depth/max-value combinations, every byte component, wide
little-endian samples, complete input prefixes, sequence compatibility, header
validation and overflow precedence, detection, all 24 storage/17 option tags,
partial output, wide dimensions and animation comments. Decoder/writer SHA-256:
`6918abab3af429f8fd98f930b0e70b800f100dd20c0f62571c82c373d373834f`.
Option SHA-256:
`ce4a89a7351dd22af4ec69bfe6cd07b1810e24616ac54ab2bbc842d720b90af1`.

**1,723 strict panic/state pairs** cover 960 wrong option arms, 368 pixel bounds,
275 grayscale2 unreachable cases and 120 decoder dimension overflows. Full
messages and names join reader/writer cursors, initialized caller output,
main/frame metadata and bytes, comments and unchanged input in SHA-256
`97974518c141b10b9c5952a4502ff89aa03a00c4e7015c0d91e9f203d5988908`.
Successful decodes compare independently allocated, fully written pixels/frames
before and after valid mutation. Failed private/freed decoder storage is excluded.
Animation controls include signed loop counts, raw comment profiles, both flags
and eleven f32 words through signed zero/subnormal/extrema/infinity/NaN.

Default options, mutation of both fields and two immutable-binding rejections
pass paired compiler controls. One separate adaptation records Source's const
comment-slice element rejection and V's mutable-array acceptance. Borrowed caller
arrays and replacement of whole option fields retain matching defined behavior.
Source Header/TupleType remain private; a compiler control requires the actual
visibility rejection. The exposed V header requires all six fields, with a full
constructor and six omission controls recorded separately as V-only checks.
Public Source encoding/decoding verifies header behavior without visibility edits;
private helper constructors/layout and V builder placeholders are unobserved.

Tuple inference/rest matching, duplicate numeric fields, raw comments, component
validation/scaling, little-endian 16-bit samples, monochrome-alpha AND, short
trailing magic retention, full-sequence compatibility and duration/loop defaults
remain unchanged. Loop comments remain main-image-only; durations appear per
frame, preserving the pinned decimal float formatter.

All 61 image and 58 Vaxis test files pass, as do production PAM/image-API
checks and unchanged historical native PAM/image-API assertions in Debug and
ReleaseSafe. The historical 19,968-word duration matrix retains FNV
721aeceda8f4ab7d. The image-API encoder/detection hashes and existing PNG decoder,
processor and 26 retained failure-state hashes remain unchanged in both modes.
Native/Linux application checks, three Windows DLLs, Windows PAM test executables
in both modes and two Linux shared libraries build successfully. Proof/build
outputs and compiler temporaries use the task-owned RAM disk; verified artifacts
are preserved before detaching it. Cross builds use -gc none and do not establish
runtime parity.

Allocator/OOM/GC/lifetime, explicit reclamation, file streams, wider allocations,
enum/narrow/const typing, exposed private helpers, physical records/slices/unions,
boxed payload copies, big-endian runtime and portable ABI remain boundaries.
Source visibility/implementation remain unchanged. Full tree/library/version pins
and before/after generated-input/consumer, fixture, runner and implementation
hashes protect retained artifacts. Reproduction and exact scope are in
zigimg/reference_probes/pam_contracts/README.md.

## IFF required chunks, parsed headers and palette contracts — 2026-10-13

IFF chunk records omitted Source's required fields, Chunk.init's assertion was
erased in production, and BMHD reads accepted malformed enum bytes. Both chunk
constructors now require their represented fields and preserve the four-byte
checked failure. Little-endian parsing validates the complete BMHD before
assignment. Wrong BMHD-arm access retains the exact active-union diagnostic,
while HAM pixel-format selection still short-circuits before that access.

CMAP capacity checks preserve the full requested slice-end diagnostic before
resize or reading. Empty CMAP resizes first, then retains the ceil-log2 assertion
in production. Partial reads commit complete RGB entries and leave cmap_bits
unchanged until all colors succeed. HAM reduction now preserves both u8 arithmetic
failures and its minimum-bit assertion; public palette/bit state changes only on
successful reduction, with the Source's native-width truncated shift.

`verify_iff_records_reference.py` compares unchanged Source Debug with ordinary V
and Source ReleaseSafe with production V. Both modes match **68,624 records**: fifteen native record/constant/flag/live-name controls,
chunk borrowing/scalar copies, header arms, format precedence, valid/short/invalid
header dispatch, CMAP/CAMG prefixes, EHB expansion and all 65,536 u8 HAM bit/plane
pairs, additional palette/shift boundaries and defined public reads.
Record SHA-256: `6cc1394883088df0aec445e92cbcb2da901e34d07b5fb11d47d968ecd6bea7ab`.
Header/palette/control SHA-256: `162b7a0ebf1e170cff5bfbee121a5a425d629dfa67307d8d496033eb1a7907a3`.
Failure-state SHA-256: `2a7fb4333d9a2214a69aefd5cd60bd4cc0db24db1b9a134aa2ca913d2a363b0a`.

The strict matrix covers **4,449 panic/state pairs**: 2,040 parsed enum failures,
1,184 assertions, 659 u8 arithmetic failures, 518 wrong-header union accesses and
48 palette-capacity slice failures. Exact messages and names join reader cursors,
initialized public codec/header fields, active palette bytes and unchanged input.
All inline palette backing is initialized through public slices before shrinking
its active view; inactive bytes and failed private/freed storage are unobserved.
Returning pixels/palettes remain independent after mutation; caller input and
codec palette remain unchanged. Default readImage private codec state is excluded.

Two complete chunk constructors, four required-field omissions and grouped default
header/codec construction are paired compiler controls. Two separate controls
record Source's const name-slice rejections and V's mutable byte-view acceptance.
A runtime adaptation records copied sum payloads sharing boxed storage in V where
Source copies its header payload by value. These differences are excluded from
the returning parity count. Native initialized header bytes/sizes and live name
views do not establish portable record layout.

DEEP loading remains a no-input zero-header stub. FORM length, CMAP remainders,
CAMG declared length, native-endian header names, the DBGL constant spelling and
EHB alpha remain unchanged. Broader planar conversion, ByteRun2, chunk traversal
and RGB/HAM arithmetic/bounds/production checks remain separate work.

All 61 image and 58 Vaxis test files pass, as do production IFF/image-API tests
and unchanged historical native IFF/image-API assertions in Debug and ReleaseSafe.
The image-API encoder/detection hashes and existing PNG decoder/processor/26
retained failure-state hashes remain unchanged in both modes. Native/Linux
application checks, three Windows DLLs, Windows IFF tests in both modes and two
Linux shared libraries build successfully. Artifacts and compiler temporaries use
the task-owned RAM disk; verified artifacts are preserved before detaching it.
Cross builds use -gc none and do not establish runtime parity.

Default Source header/format fields and inactive palette storage, allocator/OOM/
GC/lifetime, const/narrow typing, boxed payloads, physical chunk/sum/slice layouts,
wider allocated extents, file streams, logger presentation, big-endian runtime and
portable ABI remain boundaries. Source visibility/implementation remain unchanged.
Full Source-tree/library/version pins, a separate math.zig pin and before/after
fixture, generated-input/consumer, runner and implementation hashes protect the
proof artifacts. Reproduction and exact scope are in
zigimg/reference_probes/iff_records/README.md.

## IFF planar conversion and ByteRun2 failure contracts — 2026-10-13

Direct planar conversion now preserves Source's complete PBM source-slice check
and overlapping-copy panic before any output mutation. Other formats still clear
the destination before reading live borrowed plane bytes; overlapping input/output
views preserve that order. Horizontal ILBM retains its u16 pitch-times-plane
overflow in production, including row zero. Explicit source/destination checks
keep the Source index and length before narrowing to V's array index. Set padding
bits and incomplete groups of eight planes retain the existing spill and bounds
behavior. Vertical ILBM and the fallback plane-first traversal remain unchanged.

ByteRun2 retains command-count u16 underflow after consuming the count and exact
command/destination bounds in production. Literal assignments check each target
before reading that byte; a successful high-byte write and cursor advance remain
when the low-byte assignment fails. Repeat words are consumed before checking
their destinations. Zero-count commands, signed -128, zero height, odd/zero pitch,
plane boundaries, trailing data and shared stream/output backing preserve Source
order and partial writes.

`verify_iff_planar_reference.py` imports unchanged Source and compares Debug with
ordinary V and ReleaseSafe with production V. Both modes match **31,017 returning
or error records**, including every byte pattern, all five format branches and
compression tags, the u8 plane domain, distinct row/plane layouts, borrowed aliases,
all signed command bytes, prefixes, count boundaries and mixed command sequences.
Return SHA-256: `74895e84f384182b4ddeb7f3ee1a6f615fca7b9319b129744bae26d114b2925b`.

**1,225 exact panic/state pairs** cover 1,194 bounds failures, thirteen arithmetic
failures, ten wrong BMHD-arm accesses and eight overlapping PBM copies. Reader
cursor, full caller source/destination views and shared backing join names and
diagnostics in SHA-256
`da83479790fc43626a5326117ebad8ea0defbafe86d853389c32fb1188bc0328`.
All observed bytes are initialized, including destination and shared backing.
Private incomplete command arrays, inactive/default palette storage and freed or
undefined fields are excluded. The model only partitions cases; compiled Source
provides every compared output and failure state. Source visibility is unchanged.

All 61 image and 58 Vaxis test files pass, as do production IFF/image-API tests,
historical native IFF/image-API assertions in both modes, native/Linux application
checks, three Windows DLLs, both Windows IFF test executables and two Linux shared
libraries. PNG decoder/processor and 26 retained-state hashes remain unchanged in
both modes. Cross compilation provides build coverage only. Proofs and compiler
temporaries use the task-owned persistent cache; inputs, commands, outputs,
snapshots, binaries and provenance are retained with artifact hashes.

Chunk traversal and RGB/HAM conversion arithmetic/bounds/production checks remain
separate work. Allocation/OOM/GC/lifetime, readonly/narrow typing, boxed header
copies, physical slice/record/sum layout, extents beyond V array limits, file
streams, big-endian runtime and portable ABI remain boundaries. Full Source-tree,
selected library and compiler-version pins and before/after fixture/input/runner/
implementation hashes protect this proof. Exact scope and reproduction are in
[the planar/ByteRun2 probe](zigimg/reference_probes/iff_planar/README.md).

## IFF chunk traversal, RGB/HAM and PackBits failure order — 2026-10-13

The pixel decoder now preserves the zero-pitch assertion before format selection
or input in production. RGB padding subtraction retains the Source's u8 overflow
before loops, even for empty images; an empty HAM palette retains division by zero.
Explicit chunky-buffer bounds preserve the full Source index before narrowing.
Existing HAM row reset, previous-color updates, component/shift truncation and the
24-plane RGB branch remain unchanged. EHB extension still precedes HAM reduction
when the active-palette condition holds, including palette mutations before a
later conversion failure. Unreachable storage branches keep explicit traps.

The shared PackBits decoder now checks destinations before literal reads and
after consuming repeated values, preserving exact overrun diagnostics and cursor
order. Its declared-length early success and partial-output behavior remain.
ACBM still reads raw data for its byterun tag. Raw/ByteRun2 paths ignore declared
body length, and direct pixel decoding ignores the chunk ID. Traversal keeps the
complete-header read, strict seek-to-end rejection, ignored FORM/CAMG lengths,
unconsumed CMAP remainder and missing odd-chunk padding. The explicit zero-end
subtraction guard represents Source's checked u64 arithmetic; after a complete
chunk it is unreachable for these fixed-memory streams. File/cache/streaming
coverage remains outside this proof.

`verify_iff_pixels_reference.py` compares unchanged Source Debug with ordinary V
and ReleaseSafe with production V. Both modes match **18,248 returning/error
records**, including all representable HAM6/HAM8 indices over bit/palette choices,
all u8 RGB padding counts, reduction/viewport precedence, previous-color/row reset,
all format/compression branches, raw/PackBits/ByteRun2 body prefixes and public
reads, complete public HAM/EHB reads, chunk traversal and nonzero initial cursors.
Return SHA-256: `72ba805b4d37c4c51ba1f75703c63a514cdb1cef621227beac12a209047e450b`.

**1,561 exact panic/state pairs** cover 973 arithmetic failures, 243 assertion/
unreachable failures, 228 bounds failures, 101 zero-divisor failures and sixteen
wrong-header-arm accesses. Names and exact diagnostics join cursor, initialized
public codec/header fields, active palette and unchanged input in SHA-256
`848258baaaf14b0ec8c50981c29e19c2a7af845961039f077db65da397e0fdb5`.
All 256 caller palette backing entries are initialized before shrinking the active
view; only active bytes are observed. Returned pixel/palette copies retain their
independence after mutation. Default readImage private codec state and failed/
freed private buffers are excluded. The model partitions cases; unchanged compiled
Source supplies every output and snapshot, with its original visibility.

Thirty-seven successful partial PackBits controls would expose uninitialized
private plane bytes, and 37 default EHB controls would read uninitialized base
colors. They are excluded and counted separately. V allocation initialization
remains a representation boundary, alongside allocator/OOM/GC/lifetime, readonly/
narrow typing, boxed headers, physical layouts, extents beyond V array limits,
file streams, logger presentation, big-endian runtime and portable ABI. Pinned
DEEP/encoder stubs remain unchanged. Unreachable branches are not assigned
manufactured runtime observations.

All 61 image and 58 Vaxis test files pass, as do production IFF/image-API tests,
unchanged historical IFF/image-API/compression assertions in both modes,
native/Linux application checks, three Windows DLLs, both Windows IFF test
executables and two Linux shared libraries. The shared-helper TIFF regression
passes 39,707 records with its existing hash and seventeen strict trap pairs in
both modes. Existing PNG decoder/processor/26 retained-state hashes are unchanged.
A missing shared Zig cache archive interrupted the first TIFF build; the retained
retry uses an isolated cache and passes. Cross builds establish build coverage.

Proof artifacts, including the failed cache attempt, are retained in the task-owned
persistent cache with artifact hashes. Full Source/library/math/version pins and
before/after fixture/input/runner/implementation checks protect the new proof.
Exact scope, boundaries, counts and reproduction are in
[the pixel/chunk probe](zigimg/reference_probes/iff_pixels/README.md).

## XBM production arithmetic and parsing contracts — 2026-10-13

The non-advancing detector's u32 counter check now retains integer overflow in
production. Native-usize width/height multiplication and expected-byte rounding
also have explicit Source-order guards, after public field assignment and after
pixel allocation/palette initialization respectively. Bounded u32 dimensions
cannot overflow these usize expressions on the verified native 64-bit target.
Four detector loop pairs keep running over a half-second bounded interval with
matching initialized ready states. They intentionally do not reach the counter's
four-billion-iteration boundary; no dynamic arithmetic-trap or 32-bit-runtime
observations are claimed for these guards.

`verify_xbm_contracts_reference.py` imports the unchanged complete Source tree.
Debug/ordinary and ReleaseSafe/production both match **15,337 returning/error
records** covering all byte patterns, odd/continuous rows, lexical delimiters and
byte tokens, low-two-byte word truncation, signed/underscore/overflow numbers,
ordered definitions and zero-sentinel hotspots, prefixes/CRLF/EOF/initial cursors,
zero-area maximal dimensions, detector controls and default/mutable/scalar-copy
records. SHA-256:
`6544506d5e8c60983270a840d0b278fb9419c4690e7c7d1e8235040527065e0e`.

Errors retain Source's field-assignment and reader-cursor boundaries. Returned
pixels and white/black palettes match before/after mutation and remain independent
of unchanged input. Caller codec fields are fully initialized. Default readImage
private codec fields, empty pointer identities, failed/freed private storage and
unused byte-list capacity are excluded. Private helper visibility is unchanged.
The first pixel line's trimming, later CR tokens, ignored define names, rejection
of malformed ignored defines, extra-token acceptance, unterminated final lines,
continuous bit order and no-op writer remain intact.

All 61 image and 58 Vaxis test files pass, as do production XBM/image-API tests,
unchanged historical XBM/image-API/compression assertions in both modes,
native/Linux application checks, three Windows DLLs, Windows XBM tests in both
modes and two Linux shared libraries. Existing PNG decoder/processor and 26
retained-state hashes remain unchanged in both modes. Cross compilation provides
build coverage only. Proof artifacts, including the development fixture's initial
readonly rawBytes compiler rejection, are retained with artifact hashes; the final
fixture uses Source's public mutable PixelStorage view.

Allocator/OOM/GC/lifetime, growth/capacity, generic interfaces and ignored writer
options, readonly/narrow typing, physical layout, extents beyond V array limits,
file streams, big-endian/32-bit runtime and portable ABI remain boundaries. Full
Source/library/version pins, an additional fmt.zig pin and before/after fixture/
input/runner/implementation checks protect this proof. Exact scope, counts,
limitations and reproduction are in
[the XBM probe](zigimg/reference_probes/xbm_contracts/README.md).

## LZW u13 bit reads, production traps and retained dictionary state — 2026-10-13

LZW used assertion-only checks and native-u16 reads where Source uses u13. The
private reader now truncates at each Source u13 shift, retains narrow shift/cast
failure order after input consumption and preserves partial/oversized reads.
Pending resumes retain their subtraction, shift and clear order; remaining_data
is committed before a failing u4 remaining_bits cast. The shared BitReader and
other compression algorithms remain unchanged.

Factory/reset u4 casts and u13 shifts now retain their exact production failures.
Reset clears the dictionary and assigns code_size before computing next_code.
Dictionary insertion precedes next-code overflow and max-code shift checks;
early-change subtraction retains its checked failure. Empty values preserve
index-zero bounds after the corresponding writer/allocation boundary. Clear/end,
known/absent codes, partial initial codes and empty-resume behavior remain intact.
The dictionary field is marked required and factories initialize it explicitly;
the pinned V compiler accepts its omission in this generic record, so constructor
enforcement is a measured adaptation rather than a claimed fix.

`verify_lzw_contracts_reference.py` imports unchanged Source and compares Debug
with ordinary V and ReleaseSafe with production V. Both modes match **22,016
returning/error records** covering all constructor/code-size bytes, arbitrary input
bytes, both endian markers, growth/early-change, previous/next fields, empty and
borrowed values, pending bits/data, segmented resumes, short output and initial
cursors. Return SHA-256:
`ed8bb6c09434dfe1e443322d20f2995deee8a18ebfb2fd35af8568866ca18f36`.

**3,772 exact panic/state pairs** cover 2,030 cast failures, 1,256 arithmetic
failures, 450 shift failures and 36 empty-value bounds failures. Names and exact
diagnostics join initialized scalar/optional fields, segment/input cursor, writer
cursor, unchanged current input, full initialized output and canonical dictionary
contents in SHA-256
`0fe9b3c86c939dbbf71d079c9f9800ea2c779f3c03960e196e68f99506b60fd7`.
Dictionary hashes sort keys and include every key, length and byte. They do not
establish map placement, iteration/capacity, allocator or copy equivalence.
Factory failures exclude the private partially constructed decoder. Failed new
values, bit-reader scratch, unused map capacity, freed arena bytes and post-deinit
state are unobserved. Borrowed caller bytes are changed before decode to verify
live values. Source visibility/implementation remain unchanged; the model only
partitions cases and compiled Source supplies every comparison.

The complete constructor passes both compilers. Nine separate controls measure
V's generic dictionary omission acceptance, absent arena field, five wider code
carriers, wider remaining-bit storage and mutable dictionary values. Source
u13/u4 typing, readonly slices, arena/GC/OOM/growth/lifetime, broader map APIs and
copy/layout, file streams, wider extents and portable ABI remain boundaries.
These adaptations are excluded from the returning count.

All 61 image and 58 Vaxis test files pass, as do production LZW/GIF/TIFF/image-API
tests, historical GIF/image-API/compression assertions in both modes, native/Linux
application checks, three Windows DLLs, both Windows LZW test executables and two
Linux shared libraries. TIFF's 39,707 records and seventeen trap pairs retain
their historical results, and existing PNG decoder/processor/26 retained-state
hashes remain unchanged in both modes. Cross builds establish build coverage.

Artifacts retain development failures, constructor-control diagnostics and the
attempts stopped to record the V enforcement limit. Only regenerable compiler
caches from previously verified checkpoints were removed to recover disk space;
their verified archives and proof records remain. Source/library/version pins and
before/after fixture/input/consumer/runner/implementation hashes protect this proof.
Exact scope, counts and reproduction are in
[the LZW probe](zigimg/reference_probes/lzw_contracts/README.md).

## Shared bit-stream failure order and retained public state — 2026-10-13

Native bit-stream shifts previously used V-specific diagnostics, mask bounds
reported a generic width error, and the checked u4 writer-count addition tested
only after assigning its wider V result. Reader/writer operations now retain
Source's exact cast, arithmetic and mask-index failures, with count addition
checked before assignment after bits mutation. The latter overflow is unreachable
through the compared public native-width operations; no private helper runtime
observation is claimed. Reader masks still precede little-endian shift casts,
scalar-shift failures retain their consumed-byte/writer boundaries, and flush
subtraction/padding retain Source order and repeated-failure state.

Represented reader/writer pointers carry required markers and translated callers
initialize them explicitly. The pinned V compiler accepts their omission in both
native and alias generic records. These four compiler controls, plus two wider
count-field controls, are recorded as adaptations rather than enforcement fixes.
Complete reader and writer constructors pass both compilers.

`verify_bitstream_contracts_reference.py` imports unchanged complete Source and
compares Debug/ordinary and ReleaseSafe/production. Both modes match **136,889
returning/error records**, covering every byte over buffered short operations,
all native integer/float and actual V scalar aliases, aliased endian markers,
the full u4 count domain, requests through 65,535, partial EOF, all three reader
APIs, short output, repeated flushes, continuation, seek, scalar copies sharing a
live stream, and caller input mutation. Raw float patterns include signed zero,
infinities and quiet/signaling NaNs. Return SHA-256:
`bf6c23faab2083f34c10fb5dbfc8c5422e967f13cb0d31f3c7e505d516c18108`.

**1,064 exact panic/state pairs** cover 415 cast failures, 520 arithmetic failures
and 129 mask-index bounds. Exact diagnostics and case names join initialized
public bits/count, action index, both stream positions, the untouched/updated
out_bits slot, complete current input and full initialized output in SHA-256
`211259eb01a70a32820bfdd8b016c1c9056e97102ab9dda787acc2b130627a66`.
Equivalent same-width scalar trap operations use their unsigned-carrier
representative; returning native and alias specializations remain independently
observed. The model partitions cases and unchanged compiled Source supplies every
comparison. Private copied scratch, empty pointer identities and allocator state
are excluded; source visibility/implementation are unchanged.

All 61 image and 58 Vaxis test files pass, as do production bit-stream/LZW/CCITT/
Netpbm/image-API tests, unchanged historical GIF/image-API/compression assertions
in both modes, native/Linux application checks, three Windows DLLs, both Windows
bit-stream test executables and two Linux shared libraries. The existing 37,133
stream records retain their hash in both modes. LZW's 22,016 returning and 3,772
exact failure/state pairs retain their hashes; TIFF's 39,707 records/seventeen
traps and PNG decoder/processor/26 retained-state hashes remain unchanged. Cross
builds establish build coverage only.

Source non-native scalar widths, bool/packed bit carriers, u4 field typing, generic
required enforcement, underlying std.Io interfaces, GC/OOM/allocation/lifetime,
file-platform runtime, physical layout and portable ABI remain boundaries.
Artifacts retain development failures, including the fixture's initial empty
writer seek rejection, compiler controls and all final command records. Full
Source/library/version pins and before/after fixture/input/consumer/runner/
implementation hashes protect the proof. Exact scope, counts and reproduction
are in [the bit-stream probe](zigimg/reference_probes/bitstream_contracts/README.md).

## CCITT required records and retained decoder contracts — 2026-10-13

CCITT code entries previously allowed omitted required fields and prevented
mutation of copied records. Their represented run_length/code/code_length fields
now require initialization and remain mutable, matching Source's table element
record. The original Source type name is private; the fixture uses the inferred
public table element type without changing visibility. V's named CcittCode remains
an adapter. Three direct omission pairs reject in both compilers; complete code
and default decoder construction passes. Both compilers reject direct mutation of
the public constant code table, and scalar copies remain independent.

`verify_ccitt_contracts_reference.py` imports unchanged complete Source and compares
Debug/ordinary with ReleaseSafe/production. Both modes match **243,904 returning/
error records**, covering all 195 table entries and their historical logical hash,
every u13 code over both colors and seven length controls, every u8 length over
193 distinct code/length pairs, all three lookup methods and reversal states,
byte patterns, every table run, bounded output, prefixes and rows, continuation/
write retries, zero dimensions, default/mutable/copy records and factory dimensions
through native usize maximum. Return SHA-256:
`b8944f0d9d04f1546416591d8afb61138d85f0022fb2312c72e6d6d855aba394`.

**2,476 exact panic/state pairs** cover 310 narrowing casts and 2,166 arithmetic
failures. Two u16 decoded_bits overflows are reached through alternating zero-
pixel terminating codes. Exact diagnostics and names join initialized public
decoder fields, segment/input/writer positions, unchanged current input and full
initialized output in SHA-256
`2ee32767c8af907f13cb06609c1a4d24102f4c17193aa22236ebe764e6b8cc46`.
The proof preserves additional/make-up/terminating lookup priority, pending
reversal before underflow/write errors, accumulated code lengths, narrow padding,
EOF-as-zero, the invalid-code limit, unflushed partial output and decoder reuse.
No decoder algorithm changes were needed for the represented returning/failure
cases. The model partitions cases; unchanged compiled Source supplies every result.

Private bit-reader/writer scratch, partially constructed factory records, empty
pointer identities and allocator state are excluded. All observed caller storage
is initialized. Maximal factory/record fields do not establish execution of huge
row loops. Five separate compiler controls measure wider lookup arguments and
factory/stored white values accepted by V; native u13/u1 typing, packed color,
broader alias construction, underlying std.Io interfaces, GC/OOM/lifetime,
physical layout, file-platform runtime and portable ABI remain boundaries.

All 61 image and 58 Vaxis test files pass, as do production CCITT/TIFF/image-API
tests, historical GIF/image-API/compression assertions in both modes, native/Linux
application checks, three Windows DLLs, both Windows CCITT test executables and
two Linux shared libraries. TIFF's 39,707 records and seventeen strict trap pairs
retain their historical results in both modes. Cross builds establish build
coverage only.

Artifacts retain development fixture/compiler failures and the stopped proof used
to correct the exact required-field diagnostic marker. Low disk space required
pruning verified duplicate generated binaries and expanded proof files from prior
checkpoints; their original checksum-verified archives and manifests remain.
Source/library/version pins and before/after fixture/input/consumer/runner/
implementation hashes protect the new proof. Exact scope, counts and reproduction
are in [the CCITT probe](zigimg/reference_probes/ccitt_contracts/README.md).

## Quantizer inline-root copies and exact mutation failures — 2026-10-13

The octree quantizer stored its root behind a shared pointer, so copying the
quantizer shared root metadata where Source retains an inline value. The root is
now inline; quantizer/node copies preserve independent scalar metadata and borrowed
children. Palette contexts require their palette field, with independent copied
counters and shared palette storage. Complete context and inline-root construction
passes in both compilers, and both reject direct palette omission. Source's required
arena field remains a measured GC constructor adaptation.

Checked quantizer failures now retain exact Source cast, arithmetic, division and
level/palette bounds diagnostics. Node initialization resets fields before invalid
registration; leaf additions retain component/reference mutation order. Wrapping
child removal/clearing precedes reduction's negative cast or unsigned subtraction.
Palette bounds precede color conversion and palette/node/context assignment.
Leaf lookup bypasses level validation, and normal lookup keeps first-child fallback.
The bounded new graph cannot reach usize leaf-sum overflow; its guard remains
without a manufactured runtime observation.

`verify_quantizer_contracts_reference.py` imports unchanged complete Source and
compares Debug/ordinary and ReleaseSafe/production. Both modes match **4,594
returning/error records** over byte averages, checked leaf addition, level lists,
node reset, wrapping removal, palette indices, budgets, contexts, borrowed output,
mutable/copy records and factory scalar state. Return SHA-256:
`5a383dd64249c960f2d3698bc7a6fefc693daba1f196c3b462aab7c9594332ab`.

**1,134 exact panic/state pairs** cover 30 division failures, 584 casts, 284
arithmetic failures and 236 exact bounds. Names and exact diagnostics join context
counters, initialized fields/child/next links of five caller-owned nodes, all eight
level heads and the complete initialized RGBA palette in SHA-256
`b69ded40574ad13007fb9d03ff10b0f6ac7a43334fb207ffad0d249e7fe593dc`.
Canonical pointer IDs use address identity, with no raw-address/layout comparison.
The first fixture used V's pointed-value equality; its diagnostic and correction
are retained. The model only partitions cases; compiled unchanged Source supplies
every compared result. Source private Node/Context types are inferred through
public fields/function types without changing visibility.

Caller-owned roots are initialized at stable caller addresses. Factory controls
observe scalar root defaults and null level heads one through seven; the captured
level-zero root pointer and returned-record relocation/lifetime remain excluded.
Reduction skips level zero. Copied arenas are not allocated through or freed twice.
Private contexts, undefined freshly allocated Source nodes, freed arena bytes and
post-deinit state are unobserved. GC/arena/OOM/allocation/deinit, broader generic
color namespaces, larger graph extents, file-platform runtime, physical layout and
portable ABI remain boundaries.

All 61 image and 58 Vaxis test files pass, as do production quantizer/converter/
image-API tests, historical GIF/image-API/compression assertions in both modes,
native/Linux application checks, three Windows DLLs, both Windows quantizer test
executables and two Linux shared libraries. Historical quantizer hashes retain
2,160 tree/palette/index cases, 336,128 normalization cases and 2,816 alias records
in both modes. Cross builds establish build coverage only.

Proof artifacts retain the pointer-ID fixture failure and diagnostic/compiler
attempts. Verified prior archives retain the duplicate expanded proof files and
regenerable caches removed to recover disk space. Source/library/version pins and
before/after fixture/input/consumer/runner/implementation hashes protect the proof.
Exact scope, counts and reproduction are in
[the quantizer probe](zigimg/reference_probes/quantizer_contracts/README.md).

## Mutable codec interfaces and exact option-tag failures — 2026-10-13

FormatInterface's three required callback fields now permit replacement in mutable
records, matching Source. Copies retain independent callback choices. Complete
construction and three mutable-field assignments compile in both languages;
three separate omission pairs and three constant-record mutation pairs reject.
Callback allocator parameters remain omitted under V's existing GC adaptation.

PNG/TGA interface writers now report the exact Source inactive-union-arm diagnostic,
including both field names, before image validation or output. Explicit guards
preserve that contract in production. Other codec fallbacks, no-op writers,
registry ordering and encoder algorithms are unchanged.

`verify_format_interface_contracts_reference.py` imports unchanged complete Source
and compares Debug/ordinary with ReleaseSafe/production. Both modes match **43,200
returning/error records** over all 27 callback combinations, eight field-replacement
masks, four original/copy mutation-and-dispatch controls, five input lengths,
five output capacities and two starting-position controls. All 17 encoder-option
tags occur. Callback traces, boolean/image/error results, shared stream positions,
initialized image fields and full input/output bytes match. Return SHA-256:
`64ea2c6c5dcf3d0539e780a5acf86c390c3a35cd0c321f61202bec27d59c69dd`.

**1,024 exact panic/state pairs** cover PNG/TGA against every incorrect option tag,
four image profiles, four destination capacities and two writer-position controls.
Invalid, RGB24, grayscale8 and zero-height RGB24 images preserve option-access
failure priority. Names and exact diagnostics join image width/height/pixel-format,
all active initialized pixel bytes, writer position and complete initialized output
in SHA-256 `a5ec291c7761806756669c623761e922bef79b0349f448b0dd7f482f6a8c8c4e`.
Each pair requires the exact panic, failing exit, no stdout and matching nonempty
state. The unchanged historical 17-codec writer fixture also matches **49,344
returning/error records** in both modes, retaining SHA-256
`578f0de4bdaac7c2b67f294de64a2694c069cbb2fde6d2c43ca68494c6ca94eb`.

The new returning matrix uses custom callbacks to isolate record behavior from
codec behavior. Function identity, closures, arbitrary callback implementations,
null/dangling pointers, allocation/OOM/deinit/lifetime, file-platform runtime,
physical layout and portable ABI remain boundaries. No undefined/private storage,
palette or allocator internals are observed. Encoder-option boxed payload copying,
V's wider Format carrier and the existing pinned-source encoder compile boundaries
remain as recorded above.

All 61 image and 58 Vaxis test files pass, together with production interface/PNG/
TGA/image-API tests, unchanged historical image-API/GIF/compression assertions in
both modes, native/Linux application checks, three Windows DLLs, both Windows
interface test executables and two Linux shared libraries. Cross builds establish
build coverage only.

Proof artifacts retain development compiler diagnostics and the panic-fixture
formatting correction. Source/library/version pins and before/after fixture/input/
consumer/runner/implementation hashes protect the proof. Exact scope, counts and
reproduction are in [the interface contract probe](zigimg/reference_probes/format_interface_contracts/README.md).

## Required animation frames and retained copy behavior — 2026-10-13

AnimationFrame now requires explicit pixels and duration, matching the public
Source record. GIF's frame constructor initializes duration to positive zero
explicitly, preserving Source's initialization. Existing editor/iterator fixtures
spell both fields. Animation and managed/unmanaged image defaults are unchanged.
Four paired acceptance controls cover complete frames, Source's managed frame
alias, default records and mutable fields. Two independent omission pairs and
three constant-record mutation pairs reject in both compilers.

`verify_animation_contracts_reference.py` imports unchanged complete Source and
compares Debug/ordinary with ReleaseSafe/production. Both modes match **20,992
returning records**. The main 18,432 cases cover all 24 pixel-storage tags, counts
0/1/3, eight duration patterns, frame-array lengths 0 through 3 and five i32 loop
controls including both extrema. Another 2,560 cases cover every f32 sign/exponent
with five mantissa controls, including signed zero, subnormals, infinities and
quiet/signaling NaN payloads. Durations are assigned/copied without arithmetic.
Return SHA-256: `3898e0c8d02443126eebf2be9b483dad48af2686e9bf58dd7673e105df52960f`.

Snapshots compare duration bits, image dimensions/animation predicates, pixel tags/
counts, complete initialized pixel/palette bytes, loop counts, frame-array lengths
and every active frame. Frame scalar copies remain independent and borrow the same
pixel/palette elements. Whole pixel-storage replacement keeps copied frame fields
independent. Animation copies share mutable frame elements while retaining separate
loop/count headers. Replacing a frame-array descriptor and managed/unmanaged view
mutation preserve the represented Source behavior.

Five separate runtime controls extend the previously measured indexed PixelStorage
boxed-copy limit to frame copies. Resizing an original palette descriptor to one
also changes V's copied descriptor. Source's copy retains two entries for indexed1
and three for the other indexed tags; pixel counts remain three. These differences
are excluded from the matching count and retained in SHA-256
`e1bb37fc2732a1f753c59c9cdf48b1ef10c51f30307001a5cb5bb55e56feb623`.
No automatic by-value sum-type payload metadata copying is claimed.

All active caller storage is initialized, including every observed palette byte.
Source arenas release allocations once after each case; copied frames, animations
and managed/unmanaged views are not independently deinitialized. Inactive/freed
storage, record padding, empty pointer identity, allocator internals and post-deinit
state are unobserved. ArrayList capacity/growth/API, broader boxed metadata mutation,
GC/allocation/OOM/deinit/lifetime, file-platform runtime, physical layout and portable
ABI remain boundaries. V arrays and module-level types remain adapters for Source's
FrameList and managed/unmanaged frame aliases.

All 61 image and 58 Vaxis test files pass, as do production GIF/PAM/image-API/
iterator/editor tests, unchanged historical GIF/image-API/compression assertions
in both modes, native/Linux application checks, three Windows DLLs, both Windows
image-API test executables and two Linux shared libraries. Cross builds establish
build coverage only.

Proof artifacts retain development compiler diagnostics and the corrected mutable-
record fixture. The previous checkpoint's archive was read back and verified before
pruning duplicate expanded proofs and regenerable caches. Source/library/version
pins and before/after fixture/input/consumer/runner/implementation hashes protect
the proof. Exact scope, counts and reproduction are in
[the animation contract probe](zigimg/reference_probes/animation_contracts/README.md).

## Exact fixed-buffer resize diagnostics and retained views — 2026-10-13

Generic FixedStorage and its 8/256-element specializations now retain the exact
Source `index out of bounds: index N, len L` diagnostic before replacing data.
The generic implementation keeps its sizeof-based capacity calculation. An initial
attempt to use storage.len reported three after shrinking a seven-element buffer,
failing the existing ordinary/production tests. It was corrected before the final
proofs. The zero-capacity V array adapter retains its empty-storage guard; a nonempty
adapter has no corresponding Source zero-capacity array value. Separate V-only
guard checks pass in both modes, outside the matching observations.

`verify_fixed_storage_contracts_reference.py` imports unchanged complete Source and
compares Debug/ordinary with ReleaseSafe/production. Both modes match **11,508
returning records** and **1,320 exact panic/state pairs**. Three element types (u8,
u16, public Rgba32), six generic capacities and both real specializations cover
default/inline/full-external/offset-external data descriptors, old lengths, two byte
patterns, zero/one/half/full resizes, capacity plus one and native usize maximum.
Copies preserve independent inline arrays and descriptor headers while retaining
borrowed targets. Resize rebinds copied data to its own inline storage. Old views,
external descriptors and mutations preceding failure retain Source ordering.

Snapshots join both live data descriptors, the retained old view, both complete
initialized inline arrays and four initialized external elements. Canonical origin
and element offsets compare nonempty aliases without raw addresses. Empty identities
are omitted. Exact diagnostics and failing exits accompany nonempty matching panic
snapshots and no stdout. Return SHA-256:
`ca784ad0d6cf34998a7b78d16c63893daa7b6511fe6c8fb526973e2af64deb8d`.
Panic/state SHA-256: `8cf452e2aa375778bb4f19266e1fcb02ff2e65ce1c554f0700a518322d1c5fb4`.

Three paired acceptance controls cover default/initialized records and mutable
operations. Three rejection pairs cover constant resize, constant inline mutation
and mismatched array elements. A separate borrowed-pointee control measures Source
constant-record acceptance and V rejection. No undefined default Source storage is
observed. Undefined/inactive/freed data, record padding, empty identity, larger V
array extents, broader generic element/capacity types, record relocation/lifetime,
GC/allocation and portable ABI remain boundaries.

The unchanged historical fixed-storage fixture retains **2,373 records** in both
modes, SHA-256 `ba652143ec8ea584ce4522ed61dc6605986e90185c524ce8b13281b40b642c0b`.
TIFF's metadata proof retains **86 records and 15 trap pairs**, SHA-256
`c22c2516d50b6861d84f15605a3904f2a4fc935e45c8b3583ca0ead0c76f1346`.
Its three capacity failures now require exact Source messages. Task-owned compiler
caches replace the initial failed shared-cache archive lookup.

All 61 image and 58 Vaxis test files pass, along with production fixed-storage/
TIFF/GIF/image-API tests, unchanged historical image-API/GIF/compression assertions
in both modes, native/Linux application checks, three Windows DLLs, both Windows
fixed-storage test executables and two Linux shared libraries. Cross builds establish
build coverage only.

The V fixture uses concrete resize entry points after nested generic forwarding
failed code generation. Its state observer reads live built-in array headers and
fixed initialized extents; the initial generic record observer produced invalid
reads and was replaced. Development compiler/observer/capacity failures are retained.
The previous checkpoint's archive was read back before pruning duplicate expanded
proofs and regenerable caches. Source/library/version pins and before/after fixture/
input/consumer/runner/implementation hashes protect the proof. Exact scope, counts
and reproduction are in [the fixed-buffer contract probe](zigimg/reference_probes/fixed_storage_contracts/README.md).

### Matrix constructor and inline-copy checkpoint

Pinned `src/math.zig` requires its inline `matrix` field; the V named records
previously allowed omission. `Float2x2`, `Float3x3` and `Float4x4` now mark it
required. Factories initialize storage explicitly. Private identity, multiplication
and transpose helpers start with an initialized record and overwrite every result
component, preserving the source algorithms and arithmetic. RGB colorspace setup
initializes its temporary matrix placeholders, then replaces both before use;
Source's explicitly undefined temporary caches are not observed.

`verify_matrix_contracts_reference.py` matches **6,208 new records** in ordinary
V/Source Debug and production V/Source ReleaseSafe, SHA-256
`1e940bc5ea0d199b792cd64c703e955fc6aae99f6c37596f2398d72021358525`.
Named records and generic dimensions 1/2/3/4/5/8 retain independent values after
cell, row and whole-storage replacement, mutation of caller storage and flat input,
by-value returns and mutation of transposed results. Every initialized component,
retained original and identity is recorded. Signed zero, subnormals, infinities and
NaN payloads match bit for bit; this copy corpus does not canonicalize NaNs.

Both modes check nine accepted explicit constructor pairs, three named required-field
rejection pairs and eighteen immutable cell/storage rejection pairs. Six generic
omission controls record Source rejection versus V acceptance: V 0.5.2 ignores
`@[required]` on `Matrix[B].matrix`. The annotation states the required field;
actual generic enforcement remains a compiler boundary.

All **31,639 historical records** retain their four hashes: named math (12,419),
generic math (6,467), scientific colors (6,961) and colorspaces (5,792). Matrix
arithmetic matches corresponding Source Debug/ReleaseSafe modes. The two color
histories use their original Source Debug oracle against both V modes. Three V
shape guards remain active in production; historical arithmetic still compares
non-NaN bits and canonicalized NaN occurrence.

Separate Source ReleaseSafe color controls expose **five scientific and 32
colorspace differences**, retained with full inputs/outputs and locked hashes.
The scientific differences affect HSLuv saturation/chroma. Optimized native binaries
import Apple's combined `___sincosf_stret`, while Debug/V binaries use separate
sine/cosine calls. The proof checks symbol selection without claiming it explains
all colorspace differences. Previous production color claims establish V production
versus Source Debug parity, not complete native ReleaseSafe parity. No optimized
color-equivalence claim is made here.

All 61 image and 58 Vaxis test files pass. Production math/generic-math/colorspace/
scientific-color tests, native/Linux application checks, three Windows dependency
DLLs, four ordinary/production Windows matrix test executables and two Linux shared
libraries pass (17 platform commands). Cross builds establish build coverage.
Source/stdlib/compiler versions and before/after implementation, runner, fixture,
corpus-generator, input and consumer hashes are retained. Initial incomplete
production comparisons and development fixtures are archived separately.
An intermediate V compiler control exhausted temporary disk space. Its diagnostics
are retained, and the final proof uses task-owned V temporaries with pinned color
std.math helpers checked before/after; module/platform tests required no changes.

Undefined storage, padding/SIMD ABI, zero-length arrays, extra alias layers,
generic factory forwarding, allocation/lifetime and unrepresented shapes remain
boundaries. Reproduction, historical/difference hashes and constructor examples
are in [the matrix contract probe](zigimg/reference_probes/matrix_contracts/README.md).

### HSLuv required fields and optimized ray evaluation

`HSLuv` and `HSLuvAlpha` now require all seven represented fields, matching pinned
`color.zig`. Public mutation and inline copies remain available. The source's
float4 factory/argument signature typos remain intact and receive explicit
accepted/rejected compiler controls.

The HSLuv ray now evaluates its paired trig operations through the SDK primitive
selected by Source ReleaseSafe on Darwin. Ordinary V retains separate calls.
Only this primitive crosses the C boundary; the ray algorithm remains in V.
A broad paired-call experiment introduced 109 scientific mismatches and was
restricted to the ray calculation. Public cylindrical conversions retain their
independent calls; the experiment is consistent with caller-dependent optimizer
selection and does not establish one global optimization rule for those APIs.

`verify_hsluv_contracts_reference.py` matches **9,424 new records** in each mode:
ordinary V/Source Debug SHA-256
`f07e05a03320b8b6fe232813a45686fd2b21d4ebb7767a812900c0bd11436762`, and production
V/Source ReleaseSafe SHA-256
`e26a6d77e9297e5e9e3224fda48e876eba468443deea92806b181bda37f766af`.
Copies, replacement, by-value returns, retained originals, both conversion
directions, alpha/plain views and the float4 bridge are observed with four
matrices, every field target, threshold inputs and unusual f32 bit patterns.
Copy/bridge bits preserve NaN payloads; arithmetic canonicalizes payloads only.
Both modes pass three accepted consumer pairs, seven required-field rejection
pairs, seven immutable-field rejection pairs and two preserved-typo rejection pairs.

The **6,961 scientific-color records now match corresponding native modes**:
ordinary retains its Debug hash; production matches the native ReleaseSafe hash
`0f89855f7a8b779c3c40600a456fe34c9f88e8a006fb1702ce0d1906b7a939a8`. This closes
all five scientific differences recorded in the previous checkpoint. Ordinary
colorspaces remain exact across all 5,792 records. Production closes sixteen
colorspace differences and retains **16 cylindrical-conversion differences**,
V hash `2043e0e258e164d0671082d5a356d5a80c2f993580dee63aae38c8258e6d79cd`,
difference hash `e32e3f667c6a3c4e437f9fd658f7f3e10a3f32f67b835f944d958ca9ae5064d1`.
The native ReleaseSafe hash is unchanged. Full inputs/outputs and exact counts/hashes
prevent additional differences from being accepted. The standalone color runners
and retained matrix runner now compare corresponding compiler modes and report
these limits explicitly. Ordinary/ReleaseSafe cross-mode controls are separate.

The 6,208 matrix-copy, 12,419 named-math and 6,467 generic-math hashes remain
unchanged. Matrix frontend controls and all three production shape guards remain
active. All 61 image and 58 Vaxis test files pass; all 17 production/platform
commands from the preceding checkpoint pass. Before/after Source/library/math/SDK,
implementation, fixture, runner, input and consumer hashes protect the new proof.
An initial development output write exhausted temporary disk space; its diagnostics
remain retained, and inactive preview outputs were compressed after read-back checks.
An additional retained production build also exhausted space; the complete final
proof passed after space became available, with the failed run kept separately.

Undefined storage, floating-point exception flags, physical ABI, lifetime/allocation,
other compiler/SDK implementations and unrepresented caller optimizations remain
boundaries. Constructor examples, result pins and reproduction are in
[the HSLuv contract probe](zigimg/reference_probes/hsluv_contracts/README.md).

### Cylindrical RGB consumer rounding checkpoint

The remaining sixteen optimized colorspace differences came from Lab/Luv/Oklab
cylindrical RGB consumers. Source inlines their polar components before matrix
conversion; V previously routed them through standalone methods with independent
trig calls. The six plain/alpha RGB entry points now use three private V helpers
that evaluate both components together through the existing corresponding-mode
math primitive. Alpha is copied explicitly; RGB conversion, matrix arithmetic and
clamp order remain source-shaped. Public standalone cylindrical methods retain
their behavior, preserving the scientific-color consumers.

`verify_cylindrical_colorspace_reference.py` matches **50,832 new records** in each
mode: ordinary V/Source Debug SHA-256
`28d84845b25575f8818f23627bc011f621bb44fd3c0cb8af508eca9a15f8fe71`, and production
V/Source ReleaseSafe SHA-256
`3d1e90958a919819ccf65ddc2d0d2abbdb460d34892411d61c2b13e375ce4173`.
All presets, three cylindrical families, plain/alpha variants and both clamp
behaviors receive boundary and random inputs. Output non-NaN bits/NaN occurrence
and every retained caller-input bit match. Signed zero, subnormals, large angles,
infinities, NaNs and unusual alpha values are included.

The **5,792-row colorspace history now matches corresponding modes exactly**:
ordinary retains its previous hash, and production matches native ReleaseSafe
`f5cd4a24f8ea84428809ee7d55725c652f38d25add39f402276b1b62949fd5ba`.
All sixteen preceding corresponding-mode differences are closed; result pins
require zero differences. The 6,961 scientific-color and 9,424 HSLuv records
retain both mode hashes. HSLuv frontend controls and the 6,208 matrix-copy,
12,419 named-math and 6,467 generic-math hashes remain unchanged. The three
production shape guards and six generic required-field adaptation controls remain.
Cross-mode ordinary/ReleaseSafe observations are distinct from regressions.

All 61 image and 58 Vaxis test files, seventeen production/platform commands and
four standalone color-runner invocations pass. Source/library/math/SDK/compiler
pins and before/after implementation/runner/fixture/input hashes protect the new
proof. Unchanged Source at original visibility is the numeric oracle; no model
supplies expected values. Original mismatches and before-change implementations
are retained with the verified artifact.

Undefined storage, physical ABI, floating-point exception flags, allocation/lifetime,
other compiler/SDK math implementations and unrepresented callers remain boundaries.
Exact results are scoped to the represented native consumer paths; cross builds
establish compilation coverage. Details and reproduction are in
[the cylindrical colorspace probe](zigimg/reference_probes/cylindrical_colorspace/README.md).

### RGB colorspace record construction checkpoint

The pinned `RgbColorspace` requires all ten fields. V previously permitted omitted
chromaticities and transfer callbacks through implicit or explicit defaults.
All represented record fields now require explicit initialization; factory
temporaries also receive all four callbacks. The separate `InitArgs` record keeps
its source zero-chromaticity and identity-callback defaults.

`verify_colorspace_records_reference.py` matches **7,920 returning records** in
ordinary V/Source Debug and production V/Source ReleaseSafe, SHA-256
`20d49e2104dc25aa362ce0ffc8347fa7b074c17c154fe7c5f5531412f9eba1ad` in both modes.
Explicit/custom/default construction, all ten mutable fields, copied records,
whole-field and whole-record replacement, by-value returns and later argument
mutation retain the native results. Callback identifiers and raw argument bits
verify selection, RGB channel order and count; alpha retains its exact bits.
Each mode also passes three accepted consumers, ten required-field rejection
pairs and ten immutable-binding rejection pairs. Temporary source factory matrices
remain undefined until replacement and are excluded from observations.

Matrix, scientific-color, colorspace, HSLuv and cylindrical comparisons retain
their corresponding-mode hashes and frontend controls. All 61 image and 58 Vaxis
test files pass, along with seventeen production/platform checks and four
standalone color-runner invocations. Complete Source/library/math/SDK/compiler
pins and before/after implementation/runner/fixture/input/consumer hashes protect
the proof. The source implementation and visibility remain unchanged.

Undefined storage, physical ABI and callback pointer addresses, floating-point
exception flags, allocation/lifetime, other compiler/SDK implementations and
unrepresented callers remain boundaries. Generic matrix required-field omissions
remain a measured V compiler adaptation. Details and reproduction are in
[the RGB colorspace record probe](zigimg/reference_probes/colorspace_records/README.md).

### Grayscale required values and production conversion checks

All nine pinned grayscale types require `value`, while V previously supplied an
implicit zero when it was omitted. The nine represented fields now carry required
markers. The three alpha defaults remain 255, 65535 and 1.0. The u1/u2/u4
conversion adapters also use explicit width checks in place of assertions, so
production builds reject out-of-range values in their wider carriers.

`verify_grayscale_records_reference.py` matches **10,232 returning observations**
in each corresponding compiler mode, SHA-256
`dc6b5c8e04f277b0bd37a373851c553d46686d67092d95af8f7667b30d96b272`.
Default/explicit alpha, every mutable field, copied records, whole-copy replacement
and by-value returns retain all channel and public conversion bits, including
signed zero and NaN payloads. Each mode passes nine accepted constructors, nine
omitted-value rejection pairs and twelve immutable-field rejection pairs.

Three compiler controls measure the remaining u8 carrier adaptation: V can
construct values that Source's u1/u2/u4 fields reject. Six isolated failure pairs
verify the checked integer-width panic category in both modes. Source fails at
the input cast before record construction; V checks the retained wider value at
conversion. Construction and failure timing for invalid channels remain distinct.

Existing color-model and constructor/getter matrices retain both mode hashes.
Matrix-copy, named/generic arithmetic, scientific-color and colorspace comparisons
retain their corresponding results and compiler controls. All 61 image and 58
Vaxis test files pass, with nineteen production/platform commands. Complete
Source/library/math/SDK/compiler pins and before/after implementation, runner,
fixture, input and consumer hashes protect the proof. The source implementation
and visibility are unchanged.

Undefined allocator storage, physical sub-byte representation, allocator/lifetime,
arbitrary source generic grayscale types and unrepresented callers remain
boundaries. Details and reproduction are in
[the grayscale record proof](zigimg/reference_probes/grayscale_records/README.md).

### Public generic grayscale factory checkpoint

The public `Grayscale(T)` and `GrayscaleAlpha(T)` type factories were absent from
V. `Grayscale[T]` and `GrayscaleAlpha[T]` now retain mutable scalar storage and
public conversion through Source-shaped scaling. `GrayscaleAlpha.init(value)`
supplies the source integer-max or 1.0 default. Static conversion calls avoid
V 0.5.2's eager generic receiver checking for signed records. The compiler also
fails to resolve a type-dependent generic field initializer; explicit construction
through `init` is the verified default-alpha path.

The unchanged-source proof matches **25,740 returning records** in each
corresponding compiler mode, SHA-256
`65e24bc45804982251cc4a6fea67f6feb4f3501ad47c75aa33bcd51018c7aefa`.
Unsigned native widths, f32/f64 and two aliases cover plain/alpha construction,
default/explicit alpha, mutation, independent copies and by-value returns.
Every channel and conversion bit matches, including f64-to-f32 NaN results.
A separate native comparison observes five signed defaults and copied records.
Eighteen numeric and ten signed constructor pairs pass, along with twenty-seven
immutable-field and twelve unsupported-conversion rejection pairs.

Eighteen Source omission rejections remain V acceptance because generic required
markers are ignored. Nine direct generic alpha literals with omitted alpha retain
zero rather than the Source default; their complete differing outputs remain
retained. Six Source built-ins alias generic specializations while V keeps distinct
nominal types to preserve named required-field checks. These construction and
identity adaptations are measured separately from the returning comparisons.

The named-record and existing color-model/constructor matrices retain both mode
hashes. All 61 image and 58 Vaxis test files pass, with 23 production/platform
commands, including the generic probe's Windows and Linux builds. Complete
Source/library/math/SDK/compiler pins and before/after implementation, runner,
fixture, input and consumer hashes protect the proof. Source implementation and
visibility are unchanged.

Sub-byte and wider-than-native integers, unrepresented generic types/callers,
physical ABI and allocation/lifetime remain boundaries. Details and reproduction
are in [the generic grayscale proof](zigimg/reference_probes/grayscale_generic/README.md).

### Compact image enum storage checkpoint

`PostConversionBehavior`, `NetpbmFormat` and `PamTupleType` used V's default
four-byte enum storage. Explicit u8 backing and native ordinals now restore
their initialized one-byte storage and alignment. Source's inferred tag integer
widths remain u1/u2/u3; V's carrier is wider.

The unchanged-source proof matches **3,584 returning records** in each
corresponding compiler mode, SHA-256
`9009c28f3efdd4db457b134de4c62873ee83534cf7837b3c89a73b3071a49fee`.
Both public enums cover size/alignment, every named tag, copied values, by-value
returns, initialized array bytes, independent clones and borrowed-byte mutation.
Six PAM records compare with size/alignment/names/ordinals extracted from the
original decoder's native debug metadata. Private Source names remain private.

Two mutable controls and two immutable-assignment rejection pairs pass per
mode. Source rejects two unnamed constant literals; ordinary V accepts them,
while production V rejects them. Two private-name controls retain the existing
public V PAM adapter difference. Invalid runtime enum values and their failure
timing are excluded from the valid-value comparison.

The complete Netpbm/PAM matrices retain their returning and retained-failure-state
hashes in both modes (137,226/74,189 returns and 969/1,723 strict failure pairs).
The 5,792-case colorspace comparison retains both corresponding-mode hashes
with zero differences. All 61 image and 58 Vaxis test files pass, along with
nineteen production/platform commands. Complete Source/library/math/SDK/compiler
pins, metadata-tool versions and before/after implementation/runner/fixture/input/
consumer hashes protect the proof. Source implementation and visibility are
unchanged.

Enclosing record layout/padding, undefined storage, arbitrary ABI, allocation/
lifetime and unrepresented callers remain boundaries. Details and reproduction
are in [the compact enum proof](zigimg/reference_probes/compact_enums/README.md).

### Public indexed storage factory checkpoint

The public `IndexedStorage(T)` factory, its `PaletteSize` member and direct
cleanup interfaces were absent from V. `IndexedStorage[T]` now supplies mutable
palette/index slices, default/full and explicit palette constructors, static
capacity lookup and static palette resizing. Five named records also expose
capacity lookup and cleanup. V GC owns the allocations; Source allocator
selection, allocation failures, reclamation and lifetime remain adaptations.

The unchanged-source comparison matches **2,384 returning records** in each
corresponding compiler mode, SHA-256
`c0b156d0c049b331e851d03790c796d6e7f10fbb5dcc4ca699928c6ebac6a554`.
Bool, native signed/unsigned 8/16-bit values and aliases cover initialized opaque
palettes, initialized indices, shrink/regrow, shared element mutation,
independent copied lengths, by-value returns and whole-record replacement.
Five named capacity/cleanup records and three 32-bit capacity records match.
Thirty-two strict capacity failure/state pairs match, state SHA-256
`de4f2c99de990d467f02db399ebdc050189e8b85575dcbd0cc59dcb3040a53fd`.

Eight constructor/cleanup pairs, eight immutable-resize rejection pairs, three
wide direct-record pairs and three unrepresentable capacity conversion pairs
pass. Sixteen generic field omissions remain V acceptance, and two native
built-in aliases remain distinct V nominal records. Four V-only array-length
guards fail explicitly before allocation; native oversized allocations are
excluded. Generic capacity forms beyond represented scalars, native sub-byte
index typing, undefined/inactive/freed storage and physical ABI remain boundaries.

An explicitly typed fixture local avoids V 0.5.2 generating locals with the last
instantiated generic index type. The returning proof covers that call pattern;
the original compiler errors are retained. The existing named/raw-storage proof
retains all 4,393 returns and 97 strict failure pairs in both modes. All 61 image
and 58 Vaxis test files pass, with 23 production/platform checks including the
new generic fixture's Windows and Linux builds. Complete Source/library/observer/
compiler pins and before/after implementation/runner/fixture/input/consumer
hashes protect the proof. Source implementation and visibility are unchanged.

Details and reproduction are in
[the indexed factory proof](zigimg/reference_probes/indexed_generic/README.md).

### Public predefined color factory checkpoint

V's predefined colors were restricted to eleven built-in RGB(A) types. Source
also accepts caller-defined types with a public color-conversion namespace.
`predefined_colors[T]()` now delegates built-ins and aliases to their canonical
conversion and custom targets to public static `T.from_color(Colorf32) T`.
The canonical input colors retain opaque alpha; custom returned values and
alpha choices are preserved.

The unchanged-source proof matches **4,352 returning records** in each
corresponding compiler mode, SHA-256
`6978b2a5f30c126670686d36fb0ebac319823591d12fb008e34bc0a6d3d0c11c`.
Seventeen target cases cover every built-in, two aliases and four custom
factories. All canonical/replacement pairs cover copies, mutation, by-value
returns, whole replacement and unchanged original constants. Custom fixed-array
copies remain independent, and all represented values/floating bits compare
exactly, including signed zero and a NaN payload.

Seventeen mutable-copy compiler pairs and seventeen immutable-constant rejection
pairs pass in both modes. Two missing/incorrect conversion factory rejection
pairs pass. Source evaluates namespace constants at compile time; V evaluates
the typed value at runtime. A separate Source rejection/V acceptance pair and
retained sixteen-callback runtime observation measure that adaptation. Pure
returning factories do not establish side-effect or initialization-timing parity.
Source implementation and visibility are unchanged.

The existing 31,167-record color-model and 35,362-record constructor/getter
comparisons retain both mode hashes. All 61 image and 58 Vaxis test files pass,
with twenty-three production/platform checks including the new fixture's Windows
and Linux builds. Complete Source/library/math/SDK/compiler pins and before/after
implementation/runner/fixture/input/consumer hashes protect the proof. Native
namespace/value layout, allocation/lifetime, arbitrary callbacks and unrepresented
callers remain boundaries. Details and reproduction are in
[the predefined color proof](zigimg/reference_probes/predefined_generic/README.md).

### Gamma transfer factory construction checkpoint

The two V gamma-transfer adapters allowed omitted arguments that Source's
factories require. `NonLinearGammaTransferFunctions.parameters` and
`CurveGammaTransferFunctions.gamma` are now required. The historical colorspace
fixture supplies its previously implicit default parameter record explicitly,
matching the existing Source factory call. Defaults and explicit zero gamma
remain accepted.

The unchanged-source proof matches **24,192 returning records** in each
corresponding compiler mode, SHA-256
`75aa55611500c1763b7ae71e7150805173730abdca1db0b85e3fc87cb15c3c86`.
Twenty-eight parameter sets and thirty-six inputs cover defaults, presets,
thresholds, zeros/subnormals, finite extremes, infinities and NaNs. All six
parameter fields cover mutation, independent copies, by-value returns and whole
replacement. Parameter bits compare exactly, including NaN payloads. Captures
remain stable after caller mutation; all four nonlinear methods, four curve
methods and scalar gamma helpers retain every non-NaN output bit. Arithmetic
NaNs compare by occurrence rather than payload.

One default-parameter pair, six mutable-field pairs, six immutable-field
rejection pairs, two complete factory pairs and two omission pairs pass per
mode. Two V-only controls enforce immutable captures. Two Source runtime-argument
rejections remain V acceptance under the existing compile-time-namespace/runtime-
value adapter. The initial native fixture's missing-comptime diagnostic is
retained. Source implementation and visibility are unchanged.

The existing 5,792-case colorspace comparison retains both corresponding-mode
hashes with zero differences. All 61 image and 58 Vaxis test files pass, with
twenty-three production/platform checks including the new fixture's Windows and
Linux builds. Complete Source/library/math/SDK/compiler pins and before/after
implementation/runner/fixture/generated-input/consumer hashes protect the proof.
Namespace/type identity, physical layout, arbitrary parameters, arithmetic NaN
payloads, allocation/lifetime and unrepresented callers remain boundaries.
Details and reproduction are in
[the gamma contract proof](zigimg/reference_probes/gamma_contracts/README.md).

### Boolean bit-stream translation checkpoint — 2026-10-13

The public bit-stream API now accepts bool and aliases, matching pinned Source's
one-bit bitcasts. Its working carrier remains u8. Reads check the final one-bit
cast after consuming bytes and updating buffered state; values above one retain
`integer does not fit in destination type` in ordinary and production builds.
Writes retain byte-carrier shifts, padding and partial-writer behavior.

The unchanged-source boolean comparison matches **22,849 returning/error records**
and **1,049 exact failure/state pairs** in each corresponding compiler mode.
Return SHA-256 is
`8621064b96eb5c32c47a381bfb9d81c9807d3bbb670bc296a66d9da69468d838`; failure/state
SHA-256 is
`96601684c22c4529d17c5181d5a2796a3c118b97778b8f4032302a31f7287413`.
All bytes, native/aliased booleans and endian markers, read APIs, zero/one-bit
requests, buffered bits, EOF, oversized operations, copied buffers, borrowed
streams, caller mutations, capacities, padding, continuation and flush retries
are covered. Twelve paired accepted consumers pass per mode. The shared historical
fixtures add boolean dispatch without changing Source implementation or visibility.

The historical native-scalar matrix keeps all **136,889 returning records** and
**1,064 exact failure/state pairs**, with both previous hashes unchanged in both
modes. All 61 image and 58 Vaxis test files pass, together with twenty-three
production/platform checks. The extended fixture builds on Windows and Linux.

Non-native integer widths, packed caller values, arbitrary endian types,
generic required-field enforcement, u4 field typing, physical layout,
underlying std.Io interfaces, allocation/lifetime, file-platform runtime and
portable ABI remain boundaries. Details, compiler/library pins, reproduction and
retained artifacts are in
[the boolean bit-stream proof](zigimg/reference_probes/bitstream_bool/README.md).

### Packed RGB bit-stream translation checkpoint — 2026-10-13

Public bit-stream reads/writes now accept Rgb332, Rgb555, Rgb565, Bgr555 and
aliases. RGB555/BGR555 retain u15 working arithmetic despite V's u16 raw
carrier. Reads truncate after each shift/OR, writes ignore the padding bit, and
shift 15 retains `shift amount is greater than the type size` separately from
larger shift arguments' checked cast failures. Checks stay active in production.

The unchanged-source proof matches **273,066 returning/error observations** and
**567 exact failure/state pairs** in both corresponding modes. Return SHA-256 is
`d39aa4c766ca640e07beda5a21f1ea596762ea6761fd085d1951eba159eafd98`; state SHA-256 is
`4f357b8f6c9d5c4f42e145368dbf10de2ec446c0ed0f44ff9f55b1d585d8c6f5`.
Every logical packed value is read and written; dense cases alternate endian
order, while boundary, continuation and seeded random cases instantiate both
orders, types and aliases. Buffered bits, EOF, copies, borrowed input mutation,
capacities, oversized operations, padding, continuation and flush retries retain
Source behavior. Forty-eight accepted consumer pairs pass per mode. Shared
fixtures add packed dispatch without altering Source bodies or visibility.

Historical scalar (136,889 records/1,064 failure pairs) and boolean (22,849
records/1,049 failure pairs) hashes stay unchanged in both modes. All 61 image
and 58 Vaxis test files pass, with twenty-three production/platform checks
including Windows/Linux builds of the extended fixture. Two 180-second
production compile timeouts are retained; both comparisons passed with a
600-second command limit and unchanged compiler options.

Other non-native integer widths, arbitrary packed callers, undefined native
padding, physical layout, arbitrary endian types, generic required fields,
u4 field typing, underlying std.Io interfaces, allocation/lifetime,
file-platform runtime and portable ABI remain boundaries. Details, reproduction,
pins and retained artifacts are in
[the packed RGB bit-stream proof](zigimg/reference_probes/bitstream_packed/README.md).

### Bit-stream endian contracts checkpoint — 2026-10-13

The translated alignment and flush APIs previously accepted arbitrary endian
markers; flushing silently used the little-endian path. A shared compile-time
constraint now accepts only BigEndian/LittleEndian and direct aliases, protecting
all public bit-stream operations and represented record construction, including
zero-bit operations and pointer markers. Source bodies and visibility are unchanged.

Both corresponding modes match **71,680 returning/error records**, SHA-256
`4151f02c6b6aca387075822982c0d3d48dac17eeeb1602a6c2014d07178ffb2c`.
All buffered byte values, every Source u4 alignment count, flush counts 0..8,
capacities 0/1/2, repeated alignment/flush, exact padding, copied metadata,
borrowed stream identity, seeking and retained writer failures are covered.
Twenty-four accepted operation pairs, forty-two invalid-operation rejection pairs,
and two invalid-record rejection pairs pass per mode. Six separate controls
retain the pinned compiler's second-alias-layer limit: Source accepts the
corresponding endian choice while V rejects the nested alias.

All 61 image and 58 Vaxis test files pass, together with seventeen
production/platform checks. The new fixture builds on Windows and Linux.

Generic required fields, arbitrary alias chains, u4 field typing, physical
layout, underlying std.Io interfaces, allocation/lifetime, file-platform runtime
and portable ABI remain boundaries. Details and reproduction are in
[the endian contract proof](zigimg/reference_probes/endian_contracts/README.md).


### Quantizer custom RGB getter checkpoint — 2026-10-13

The quantizer previously rejected caller-defined color records. It now accepts
structs without an `a` field through a public `to_u32_rgb() u32` receiver method,
representing Source's `.to.u32Rgb()` namespace. Direct aliases work, and unrelated
RGB fields do not override the getter. Custom conversion runs at every insertion
level including the leaf and at every nonleaf lookup. Leaf lookup bypasses the
getter and level validation; invalid nonleaf levels trap after conversion.
Built-in normalization preserves its existing path.

Both corresponding modes match **9,984 returning/error records**, SHA-256
`b1194bf0c773e7d84e65679dfbe39601590d009286e8c7450223920a357e1095`, and
**600 exact panic/state pairs**, SHA-256
`22b5beca09fb157bc0ee4f44a92a8e31d87e558320fe98b1aeac611167cd534f`.
Two custom shapes and direct aliases cover pure and stateful getters, boundary
and seeded words, complete traces, initialized tree/palette state, reduction,
missing-color fallback, leaf shortcuts and ordered partial accumulation failures.
Sixteen accepted operation pairs and four missing-getter rejection pairs pass.
Four Source-accepted custom-alpha controls explicitly reject in V, preserving
that separate boundary without silently discarding alpha.

The comparison uses the complete unchanged pinned Source tree and infers its
private Node type through the public root field. Source bodies and visibility
remain unchanged. All 61 image and 58 Vaxis test files pass, together with eighteen
production/platform checks. Historical quantizer tree/normalization/alias hashes
and the 4,594-record/1,134-failure contract hashes remain unchanged in both modes.

Custom alpha namespaces, arbitrary alias chains, pointer colors, non-u32 getters,
mutable input receivers, physical namespace/receiver layout, portable ABI,
arena/GC allocation/OOM, factory root relocation and file-platform runtime remain
boundaries. Version/source/library and before/after implementation, fixture,
runner, input and consumer hashes protect the proof. Scope and reproduction are in
[the custom getter proof](zigimg/reference_probes/quantizer_custom/README.md).


### Quantizer custom alpha getter checkpoint — 2026-10-13

Custom colors with an `a` marker now call `premultiplied_alpha()` and the returned
value's `to_u32_rgba()` method at each tree level. These receiver methods represent
Source's corresponding `.to` namespaces. The marker's value/type does not replace
the custom getter. The returned word supplies RGB directly; its alpha byte is
ignored without a second premultiplication. Leaf lookup skips both callbacks and
level checks. Invalid levels and partial leaf overflows retain callback and
mutation order. Built-in normalization retains its existing path.

Both corresponding modes match **19,968 returning/error records**, SHA-256
`7653a7e51e6d1e8e00b5f3d4ef335dbbc93ee434b3e2d6038d2f5def96c0fa41`, and
**1,200 exact panic/state pairs**, SHA-256
`54f0e42d2d108ae9cabfd20a4ef52a6b0fab07acbb3ada79e90c6bf867558513`.
Four color records/direct aliases return RGBA32, RGBA64, float colors and an
aliased custom intermediate. Pure/stateful callback traces join full initialized
tree/palette state, reduction, lookup and ordered partial failure snapshots.
Thirty-two accepted compiler pairs and sixteen ordinary rejection pairs pass.
The complete Source tree and private type visibility remain unchanged.

Four Source-accepted/V-rejected controls retain the pinned compiler's private
alpha-only marker limitation. A public `a` works with an alpha-only getter;
a private marker works when an RGB getter is also present, although that getter
is uncalled. A generic helper prevents V from dropping intermediate getter bodies
referenced through reflected branches. Initial direct-field/offset/code-generation
attempts and the pre-golden comparison remain in retained evidence.

All 61 image and 58 Vaxis test files pass, including a new alpha callback/alias/
leaf regression, together with eighteen production/platform checks. Existing RGB,
quantizer contract and historical normalization/tree/alias hashes remain unchanged
in both modes. The RGB runner now accepts its four alpha controls.

Private alpha-only markers, arbitrary alias chains, pointer colors, unsupported
getter result types, mutable input receivers, physical layout, portable ABI,
arena/GC/OOM, factory root relocation and file-platform runtime remain boundaries.
Source/library/version and before/after implementation, fixture, runner, helper,
input and consumer hashes protect the new proof. Scope and reproduction are in
[the alpha getter proof](zigimg/reference_probes/quantizer_alpha/README.md).


### Quantizer unsigned getter widening checkpoint — 2026-10-13

The V custom RGB constraint accepted only methods declared to return u32.
Source's `Rgb24.from.u32Rgb()` call also accepts u8/u16 getter results through
implicit widening. Two additional structural interfaces now admit those native
unsigned widths before RGB unpacking. Signed, u64, boolean and float results remain
compile-time rejections. Direct color aliases work; tree mutation and built-in
normalization code is unchanged. Alpha selection still precedes the RGB path.

Both corresponding modes match **15,012 returning/error records**, SHA-256
`a42d9d71684d4e710d460a54f48c1fd93de9452e830855e65a2081939e4807fd`, and
**864 exact panic/state pairs**, SHA-256
`23c05fb50943d60a7dbf64fcff1ac189ed1811815ab5549cd08fdb5fbbc3a068`.
Three result widths and direct color aliases cover pure/stateful getter traces,
full initialized tree/palette state, reduction, lookup and partial failures.
Zero channels at component limits correctly return instead of manufacturing
an overflow. Twenty-four accepted operation pairs and twenty-eight invalid-width
rejection pairs pass. Eight private-alpha pairs build and execute without invoking
the narrow RGB getter that would panic if called.

Twelve Source-accepted/V-rejected controls measure the existing alias-return
signature limitation in V's interface matching. They differ from direct aliases
of the caller color, which are supported. The pinned complete Source tree and
private Node visibility remain unchanged. All 61 image and 58 Vaxis test files
pass with the mixed-width module regression, alongside eighteen production/platform
checks. Existing RGB/alpha and historical tree/normalization/alias hashes remain
unchanged in both modes.

Getter-result aliases, arbitrary alias chains, non-native Zig integer widths,
private alpha-only markers, pointer colors, mutable input receivers, physical
layout, portable ABI, arena/GC/OOM, factory root relocation and file-platform
runtime remain boundaries. Source/library/version and before/after implementation,
fixture, runner, helper, input and consumer hashes protect the proof. Scope and
reproduction are in [the getter width proof](zigimg/reference_probes/quantizer_getter_width/README.md).


### IFF header diagnostic payload checkpoint — 2026-10-13

The IFF debug hooks existed but rendered their header pointers through V's generic
formatter, producing V type names and field syntax. BmhdHeader/DgblHeader now
send the pinned Source's anonymous-record payloads to the host logger: exact
punctuation/spacing, declaration order, signed decimal values, dotted enum labels
and `x_asoect` spelling. The private union dispatcher continues to use these
methods. SGI/TIFF and RAS diagnostics and all decoder bodies are unchanged.

Both corresponding modes match **142,912 records**, SHA-256
`893786350ccb1081f99146384847741efd45b9f7a0e180a417c153ddea79591a`.
Each configured enabled/suppressed logger runs 71,456 records over full signed
coordinate and unsigned dimension domains, all byte values and enum choices,
zero through three repeats and seeded fields. Observations retain every payload
byte, debug/default classification, callback count and all caller fields before
and after logging. Unchanged Source public methods supply the expected text;
no alternate formatter model or widened visibility is used.

All 61 image and 58 Vaxis test files pass, including four Source-observed payload
regressions, with eighteen production/platform checks. Source logger thresholds
are configured at compile time; V's capture logger is configured at runtime.
Default levels, prefixes/timestamps, routing, ownership/synchronization, eager
versus lazy formatting, allocation/OOM, custom scopes, physical layout and logger
ABI remain adaptations. Invalid enum representations and undefined fields are
excluded. Source/library/version and before/after implementation, fixture, runner,
helper, settings/input, V logger and pinned formatter/logging hashes protect the
proof. Scope and reproduction are in
[the IFF debug proof](zigimg/reference_probes/iff_debug/README.md).
