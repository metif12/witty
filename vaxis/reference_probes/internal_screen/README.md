# AllocatingScreen retained-cell comparison

The V type `InternalScreen` adapts Source's public `AllocatingScreen` export (`src/InternalScreen.zig`); `InternalCell` is flattened from its public nested type. This proof calls unchanged public `init`, `deinit`, `writeCell`, `readCell` and `InternalCell.eql`. The complete pinned Source tree and locked uucode package are hash checked, copied unchanged, and built with the original dependency graph/tables through `widgets_classic/source_build.py`.

From the repository root:

```sh
python3 vaxis/verify_internal_screen_reference.py /Users/alex/code/3rd/vaxis /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig /Users/alex/.cache/v/v1-fallback/0.5.2/v
python3 vaxis/verify_internal_screen_reference.py /Users/alex/code/3rd/vaxis /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig /Users/alex/.cache/v/v1-fallback/0.5.2/v --v-prod
```

Ordinary builds use native Debug; `--v-prod` selects native ReleaseSafe unless `--zig-mode` overrides it. A positive `--timeout` controls returning runs. The corpus observes empty default InternalCells, independently owned initialized spaces (including borrowed mutations and a 65,535-cell creation), all screen metadata and retained buffer cells, full styles/hyperlinks, borrowed read values and addresses relative to the caller input, caller mutation after writes, and mutation through current read views. It checks the both-default equality fastpath and equality's deliberate omission of width/image/wrapped/scale. Writes leave skipped/skip/scale flags untouched. Source's strict `width < col` and `height < row` guards accept coordinates equal to dimensions; the proof preserves these inherited edge cases using oversized seeded buffers.

Writes use Source usize indexing; reads intentionally retain checked u16 multiplication/addition. Separate strict traps cover short buffers, multiplication, addition, dimensions equal to coordinates, and write indices exceeding signed 32-bit range. Traps require nonzero exit, no ordinary stdout, an anchored panic header with the expected category, and no `UNEXPECTED` line; core dumps are disabled. A complete constructor and paired ordinary missing-buffer compiler rejection check Source's required buffer contract. V omits the Source arena field because storage is GC managed.

Borrowed lifetime and failure order are compared directly. Private per-field owned byte buffers back the public string views. Fit writes retain storage, so an older read view follows a same-capacity write and can retain its old length after a shorter write (for example `abc` becomes `xef` when the current cell becomes `x`). The additional 159 fit-write records cover all three fields at byte ArrayList capacity boundaries, including empty, shorter and exact-capacity replacement lengths. Native arm64/amd64 growth uses the unchanged `std.atomic.cache_line` increment of 128 bytes; the initial character capacity is exactly one byte.

Four alias traps cover whole-character self-copy, partially overlapping character copy, URI copy after a successful character write, and URI-ID copy after successful character/URI writes. Public view length is first cleared, capacity is ensured, and incoming length is restored before the guarded copy, following Source's `appendSliceAssumeCapacity`. Style/default updates occur only after all three copies. Fixture-only failure-state observers prove the exact public values and lengths, preceding writes, untouched flags and delayed style/default updates: the native root uses `std.debug.FullPanic` and then unchanged `std.debug.defaultPanic`; V registers an `at_exit` observer after its ordinary panic path. Neither observer resumes execution or modifies Source statements. Four observation files must match in addition to strict anchored panic classification.

Two supplied-allocator boundaries are measured separately:

- A Source caller-supplied zero-byte FixedBufferAllocator causes `init` to return `OutOfMemory`. V has no caller allocator and normal managed creation returns one cell.
- With a 4,096-byte fixed allocator, Source's 8,192-byte grapheme append fails after clearing the old text, logs `couldn't write grapheme`, then still writes URI/params/style/default. V managed allocation retains all 8,192 bytes and the same other fields. Supplied allocator failure behavior cannot be represented by V's constructor/write API.

Allocation/remap/address behavior and the lifetime of old borrowed views across capacity growth remain managed-storage boundaries. V allocates a fresh byte array on growth; Source's allocator can remap or invalidate old views. Direct Source ArrayList payload/capacity methods are not a V string API. These limits do not apply to the capacity-fit reuse and alias behavior checked here.

Final ordinary/Debug and production/ReleaseSafe results: **6,570 returning records, 19 strict paired traps, four matching failure-state observations, two separately measured allocator boundaries, one V array-limit trap, and one complete/one omission constructor pair**. Six focused consumers pass in both V modes after the settled header setter.

Returning-record SHA256: `c51b3c3a72977c3b02a883b513817c51ec2aec1c66ab3f9bfdd6129a32602404`. Ordered alias failure-state SHA256: `c649a7f33f7162d839dd233c1e9883e5395d540dd09d102d178e96c4a8ee6d1a`.

V arrays have signed int lengths. Creation checks the usize product before conversion and traps with `V array length limit` above 2,147,483,647 cells; the proof verifies this V boundary separately and avoids huge Source allocations. Managed deinit empties the buffer; Source deinit frees its arena and sets the structure undefined, so post-deinit state/lifetime is outside parity. V strings replace Source ArrayList payload/capacity APIs. This checkpoint does not assert complete renderer or caller allocator parity.
