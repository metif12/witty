# Framework constructor contracts

The runner checks 38 complete constructor pairs and 57 required-field omissions
against unchanged Vaxis source. The original 18 core types and 31 omissions are
retained unchanged; 20 widget and adapter types add 26 omissions. Selected optional
defaults and command payloads are covered. Source union payloads map to the
existing named V command wrappers.
`Notification.title` remains required even though its value can be absent.
Source EventContext/DrawContext allocator fields are always supplied and excluded
from omission comparisons because V uses GC storage. Pointer nullability and
function ABI, allocator failures and narrow integer representations (i17/u4)
are outside this constructor proof. Requiring `Widget.userdata` establishes field
presence; the V `voidptr` carrier can still hold an explicit null pointer.

A native executable and a V executable compare the original 16 default values,
followed by 63 widget default values: styles, enums, cursor/scroll state, optional
callbacks, buffer state and atomic spinner state. Every negative case must produce
an ordinary type-checking error for the omitted field or union arm. Compiler crashes and generated-C errors
fail the runner. Complete constructors are checked separately to prevent unrelated
module errors from masquerading as omission rejection.

Debug/ordinary V and ReleaseSafe/production V both pass all 38 complete pairs,
57 omission pairs and 79 selected default values. Default-consumer output SHA256
(including both line terminators):
`2917ca5cdc672d99b1c440daed7882a2da028cc5a1325097b444ce88a501dbbd`.

The widget extension covers every widget exported by `src/vxfw/vxfw.zig`:

| V type | Source type | Required fields |
| --- | --- | --- |
| Center | Center | child |
| Padding | Padding | child |
| SizedBox | SizedBox | child, size |
| Border | Border | child |
| BorderLabel | Border.BorderLabel | text, alignment |
| FlexColumn | FlexColumn | children |
| FlexRow | FlexRow | children |
| Button | Button | label, on_click (`onClick`) |
| Text | Text | text |
| RichText | RichText | text |
| TextField | TextField | buf |
| ScrollBars | ScrollBars | scroll_view |
| SplitView | SplitView | lhs, rhs, width |
| Spinner | Spinner | none; complete constructor and defaults only |
| ListView | ListView | children |
| ListBuilder | ListView.Builder | userdata, build_fn (`buildFn`) |
| ListSlice | ListView.Source slice arm | widgets (required slice payload) |
| ScrollView | ScrollView | children |
| ScrollBuilder | ScrollView.Builder | userdata, build_fn (`buildFn`) |
| ScrollSlice | ScrollView.Source slice arm | widgets (required slice payload) |

This historical runner proves constructor field presence and selected defaults.
The separate [layout comparison](../vxfw_layout/README.md) now verifies checked
arithmetic, assertions, child errors and callback ordering in Center, Padding,
Border, FlexColumn and FlexRow, plus the SizedBox widget adapter. Borrowed label
storage and captured Flex child slices are covered. The source FlexRow branch
that reads an uninitialized size cache remains excluded from defined parity.

Additional iterator payload contracts are covered by the new
[Text](../vxfw_text/README.md) and [RichText](../vxfw_rich_text/README.md) probes,
without changing this runner's counts or output hash. V `LineIterator.buf`,
`SoftwrapIterator.ctx/hard_iter` and `WrappedLine.width/bytes` now require explicit
fields. `RichSoftwrapIterator.ctx/text/line` and `RichWrappedLine.width/cells`
likewise require fields. Their payloads are public and their indices use Source
usize, with borrowed string and cell views. Source iterator methods remain
private; the existing public V `new`, `reset`, `next_hard_break` and `next` methods
are measured convenience adapters where applicable. Native behavior is compared
through unchanged public draw methods, while private-access rejections and V
adapter calls are checked separately.

Source allocator and RichText arena ownership map to V GC storage. Private heap
shells preserve borrowed data and draw/reset order while avoiding repeated
production keepalive scans; supplied-allocator failure and ABI parity remain
outside the V comparison. The `RichText.TextSpan` alias retains compatibility
with `vaxis.CellSegment`. Direct `CellSegment{}` rejects omitted required text,
but pinned V ignores the inherited marker on `TextSpan{}` and accepts an empty
string. This measured compiler boundary remains documented separately. The
[Window output comparison](../window_output/README.md) also covers delegated
fill/print arithmetic, operation order and borrowed tokenizer/grapheme views;
its broader representation limits remain explicit.

Source App's manual state requires `allocator`, `tty`, `vx`, `timers`,
`wants_focus` and `buffer`. V `App.init()` returns a managed pointer, omits the
allocator/caller buffer, uses a V array for timers, and keeps timers/focus private;
its manual literal requirements are not compared here. TextField's Buffer aliases
the existing `vaxis.TextInputBuffer` translation, whose constructor/allocator
adaptation is covered by the dedicated TextInput/TextField probes.

The source tree SHA-256 is
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed`.
The locked Unicode dependency is hashed and built with the shared unchanged-source
helper in `../widgets_classic/source_build.py`.

```sh
python3 vaxis/verify_vxfw_constructors_reference.py /path/to/vaxis /path/to/zig /path/to/v
python3 vaxis/verify_vxfw_constructors_reference.py /path/to/vaxis /path/to/zig /path/to/v --v-prod
```
