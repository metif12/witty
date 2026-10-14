# GIF public records and production checks

`verify_gif_records_reference.py` compares unchanged zigimg
`d7b7ab0ba0899643831ef042bd73289510b39906` with V: Source Debug against ordinary
V and Source ReleaseSafe against production V.

```sh
python3 zigimg/verify_gif_records_reference.py \
  /path/to/locked-zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 \
  --workdir /path/to/empty-proof-directory
```

Repeat with `--v-prod` and another empty directory. `--target` defaults to
`aarch64-macos.14.0`; cross builds do not verify runtime behavior. `--timeout`
bounds commands and `VTMP` can select compiler temporaries.

Thirteen public setters represent assignment to the Source header, descriptor
and graphic-control packed fields. They preserve unrelated bits and check
u3/u2 values before mutation in both modes. For example:

```v
mut header := zigimg.GifHeaderFlags{}
header.set_global_color_table_size(3)
header.set_color_resolution(7)
header.set_use_global_color_table(true)
mut descriptor := zigimg.GifImageDescriptorFlags{}
descriptor.set_is_interlaced(true)
mut control := zigimg.GifGraphicControlExtensionFlags{}
control.set_disposal_method(.restore_background_color)
control.set_has_transparent_color(true)
```

Source's disposal enum is nonexhaustive u3. Numeric values 4..7 are preserved
through getters and setters using V's unsafe enum cast; values beyond seven
trap before changing the packed word. V retains its wider exhaustive enum carrier.

`GifCommentExtension.comment` and all three `GifApplicationExtension` fields
are now required, as in Source. The decoder explicitly initializes its placeholder
comment slice to preserve V's existing adaptation of Source's incomplete undefined
comment record. All other represented defaults remain unchanged.

| Returning observations | Count |
|---|---:|
| All header-flag bytes, every field/value, getters and copies | 5,120 |
| All image-descriptor flag bytes, every field/value, getters and copies | 4,608 |
| All graphic-control flag bytes, including disposal tags 4..7 | 5,120 |
| Initialized defaults, header/descriptor/control/frame copies and extensions | 27 |
| **Total** | **14,875** |

Returning SHA-256:
`c440937a2fdf13c1e0d4842500aad5820a32d1e23d8680a32cfdbb12e712ffbe`.

The record observations cover scalar and inline-array value copies, replacement
of optional graphic controls, shared sub-image pointers and pixel slices, and
copied fixed palette storage whose active slice still borrows the original owner.
Comment/application copies retain shared data slices and independent fixed arrays.

Thirty-five strict panic/state pairs cover eighteen invalid packed-field casts,
plain-text byte-count overflow, graphic-control toss, short loop data, nine invalid
indexed background restorations, three buffered toss failures and two usize toss
overflows. Plain-text overflow and indexed casts stay active in production.
The shared toss helper now advances its representable cursor before checking the
buffered end, matching Source; integer overflow precedes assignment. Snapshots
compare the unchanged packed byte, direct cursor, or decoder header/palette/frame/
application state and position. Parsed sub-image pixels are inspected only in
the complete one-pixel restoration cases.

State SHA-256:
`fff55be0cc9007627f8ec87bfea8aa6a12260f7a581ad909294dde3f1fda72c7`.

Two complete required constructors compile in both languages. Four field omissions
and thirteen immutable packed mutations receive ordinary compiler rejections.
Two additional compile controls exercise cleanup hooks using owned empty Source
allocations. Actual error lines are checked; crashes, signals and backend/linker
failures are excluded. Separate measured differences remain outside the matches:

- Five out-of-domain Source literals are rejected during compilation; V's byte
  setters compile and check their arguments at runtime. Narrow field syntax and
  disposal-enum typing remain adaptations.
- Source permits mutation through a const comment record's mutable slice. V rejects
  mutation through an immutable record binding. One compile pair measures this.
- V array cursors use `int`. A failed toss from zero by `usize` maximum leaves the
  V cursor at zero; Source advances to `18446744073709551615` before its end assertion.
  One isolated pair records this wider failed-offset boundary. Matching toss states
  stay within V's cursor carrier or fail on native usize overflow before assignment.

Default Source header magic/version arrays are explicitly initialized in the
fixture. Every observed palette/pixel/extension byte is initialized. Unused fixed
storage, incomplete comments, Source undefined defaults and freed data are omitted.
GC replaces allocator and arena ownership. Cleanup hooks do not establish Source
reclamation behavior. Portable aggregate ABI, array-list growth/lifetime, const/
narrow/enum typing and the complete decoder state space remain outside this proof.

The runner pins the complete Source tree, compiler versions and selected Zig
reader/writer/file/POSIX/memory/debug/map files. Before/after hashes protect original/
copied Source, compiler libraries, fixtures, runner and top-level V/C implementations.
Source algorithms and visibility remain unchanged. Commands, generated compile
consumers, raw output, diagnostics, state, provenance and summaries are retained.

Historical GIF record/decoder/renderer checks pass against Source and V in both
modes. Existing stream and PNG decoder/processor comparisons retain their hashes
and exclusions. All 61 image and 58 Vaxis test files pass; focused GIF/record/file
tests also pass in production. Native/Linux application checks, three Windows
dependency DLLs, the new Windows test executable in both modes and two Linux shared
libraries build with cross builds using `-gc none`; cross-target runtime is unverified.

The later [stream guard proof](../stream_guards/README.md) aligns shared capacity/
toss and addition diagnostics with exact Source messages. Existing output/state
hashes remain unchanged; wider failed cursor representation limits remain.

The later [loop-count proof](../gif_loop_count/README.md) compares all 16-bit
counts, metadata precedence and slice mutations. It replaces generic V array
errors for short recognized data with exact Source slice/load diagnostics;
this proof's returning and retained-state hashes remain unchanged.
