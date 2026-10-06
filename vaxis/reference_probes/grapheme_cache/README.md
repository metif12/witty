# GraphemeCache reference comparison

The runner calls the public `GraphemeCache.put` method in the unchanged pinned
Vaxis source. The complete source tree and locked Unicode dependency are hashed;
`widgets_classic/source_build.py` builds the original dependency graph. No Source
body edits, visibility changes or private-method wrappers are used.

Source SHA256:
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed`.
Locked uucode SHA256:
`2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380`.

```sh
python3 vaxis/verify_grapheme_cache_reference.py \
  /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /tmp/witty-grapheme-cache-debug

python3 vaxis/verify_grapheme_cache_reference.py \
  /Users/alex/code/3rd/vaxis \
  /tmp/lota-bugs-cross/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --v-prod --workdir /tmp/witty-grapheme-cache-prod
```

Retained build directories must be new. Ordinary mode uses Zig Debug;
`--v-prod` selects Zig ReleaseSafe and V production. The native target is
`aarch64-macos.14.0`. Commands, inputs, complete output, diagnostics and panic-state
observations are retained. Core dumps are disabled.

Both modes pass 32,932 returning records, ten strict traps with observed state,
and two complete constructor/public-state pairs. Returning SHA256 (including the
last newline):
`331f02b2216d319c23197da6e34213dcfc0dc19bf6208a9ad89706f6a94d9b4d`.

The returning matrix checks every starting index from 0 through 8192 with lengths
0, 1, 2 and 15, then adds large lengths, external indices through native usize
maximum, 75 nonoverlapping internal views, 21 borrowed/mutable return cases and
21 independent cache value copies. It compares final index, returned pointer
offset, returned-byte hash and the entire initialized 8192-byte buffer hash.
Returned views remain attached to the same inline storage: caller writes and
later wrapping writes are visible through previous views. Copying the record
copies its inline array and index independently.

Strict cases cover two usize-addition overflows, two oversized destination slices,
equal pointers at both ends of the array, overlap in both directions, alias after
wrapping and a full-buffer self-copy. Each must produce the corresponding checked
panic category; ordinary returned errors and actual `UNEXPECTED` diagnostic lines
cannot pass. The Source fixture installs its own `std.debug.FullPanic` observer
and then calls unchanged `std.debug.defaultPanic`. The V fixture registers an
exit observer. These fixture-only hooks record the actual index and full-buffer
hash at failure without changing dependency operations. State equality proves
that overflow traps precede reset, slice failure can follow reset, alias failure
precedes copying, and failed operations do not execute the final index advance.
Empty equal-pointer views are measured returning cases and do not alias-trap.

Constructors check the default index, a written prefix from default storage,
public mutation of buffer/index, native usize maximum and inline record size.
Four focused consumers cover endpoint/empty puts, mutable returned storage,
wrapping, independent value copies and adjacent internal views.

Representation limits are explicit:

- Source's default buffer is undefined. Every byte inspected or hashed in the
  comparison is explicitly initialized first; the default constructor consumer
  observes only its zero index and the prefix written by `put`. V initializes its
  fixed array, and no parity claim is made for Source's unwritten default bytes.
- `GraphemeCache.new()` is a V convenience adapter for Source's public default
  record constructor. The record retains its inline `[8192]u8` array and native
  usize index; its measured native size is `8192 + sizeof(usize)`.
- Source takes a borrowed const byte slice and returns a mutable borrowed slice.
  V arrays provide the input carrier and an unsafe byte view provides the return;
  `put` preserves the input bytes. V's direct fixed-array slices copy, so internal
  alias inputs use explicit borrowed byte views to represent Source's slices.
  V's int-sized array lengths cannot represent
  every Source usize-sized slice. Oversized Source carriers, dangling/uninitialized
  inputs, unsynchronized concurrent access and cross-platform ABI are excluded.

The V checked guards remain active under production compilation. Destination
slice validation occurs before alias validation, and successful copying precedes
the index advance. Pointer comparisons use ordered subtraction, avoiding address
addition overflow for the bounded copy lengths.
