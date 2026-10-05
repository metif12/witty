# TextField source comparison

The runner executes the original public `vaxis.vxfw.TextField` insertion,
navigation, deletion, caller-buffer copying, drawing and event methods. Widget
dispatch reaches the original private event/draw adapters and change checker
through the public widget interface. No dependency statements or declarations
are changed, appended or replaced.

`source_build.py` verifies the full pinned Vaxis `src` digest
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed` and the locked
uucode package digest
`2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380`.
It regenerates the dependency's original tables with its unchanged generator
and the Vaxis-selected configuration. The source consumer targets macOS ARM64
14.0 with libc to avoid the host's newer unsupported libSystem stub.

```sh
python3 vaxis/verify_text_field_reference.py /path/to/vaxis /path/to/zig /path/to/v
python3 vaxis/verify_text_field_reference.py /path/to/vaxis /path/to/zig /path/to/v --v-prod
```

Ordinary V uses Zig Debug by default; `--v-prod` selects Zig ReleaseSafe.
`--zig-mode` can explicitly override that selection. The runner reports build,
returning-comparison and isolated-trap progress.

Debug and V production/Zig ReleaseSafe both pass 18,911 returning records and
sixteen checked trap pairs, with returning SHA256
`c9a34b722a8b37cf2d7916679118d07dae1a2bbd11a3bd68ccfe7fdf1dd93be3`.
The corpus covers valid and malformed UTF-8,
all three width methods, codepoint-boundary splits within grapheme clusters,
cursor and word movement, deletion, clearing, owned extraction, horizontal
scrolling, width changes, zero-width surfaces, style propagation and event
dispatch. Records include complete rendered cells/cursor state, buffer layout
and contents, previous values, scrolling state, callback observations and
post-error event flags. Callback cases check snapshots, duplicate suppression,
mutations and errors, including the different consumption timing of change and
submit callbacks.

The 1,824 drawing-borrow cases record cell grapheme addresses relative to the
actual field buffer and then mutate both stored halves without resizing or
freeing them. Rendered cell bytes retain the original borrowed-buffer behavior.
Caller-buffer cases similarly verify returned-prefix identity, subsequent
caller writes and untouched trailing capacity.

Sixteen isolated checked trap pairs cover u16 counters/widths, u8 glyph-width
narrowing, surface-size multiplication, missing draw bounds, short or aliasing
caller buffers, and the inherited malformed-grapheme start underflow. The
verifier requires a real native/V panic-header line with the expected category;
success, returned errors, stdout and `UNEXPECTED:` diagnostics are rejected.

The source's unused `scroll_offset` field is a `u4`; V retains a `u8` field and
all returning inputs use its original 0–15 domain. A separate compile probe
measures ordinary source rejection of literal 16 and V acceptance. This is a
representation boundary, excluded from paired compilation claims. The shared
V TextInput buffer represents the source's separate TextField buffer and its
allocator through managed storage. Allocator failure, freeing borrowed data,
use after deinitialization, array capacities beyond V's index domain and racing
mutations remain language or validation boundaries.
