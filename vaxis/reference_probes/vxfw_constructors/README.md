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

This proves constructor field presence and selected defaults, not widget layout
arithmetic. Padding's u16 padding sums, child-size additions and assertion guards,
and Border's size additions, label-width casts and subtractions remain separate
unchecked translation gaps in `vxfw/layout.v`.

Other public record construction is outside this extension. Source
`Text.LineIterator` requires `buf`; `Text.SoftwrapIterator` requires `ctx` and
`hard_iter`; its `Line` requires `width` and `bytes`. V `LineIterator`,
`SoftwrapIterator` and `WrappedLine` currently permit omitted state. V keeps the
softwrap context and iterator state private and exposes public `new`/`next`
methods, while Source's iterator `init`/`next` methods are private.
Source `RichText.SoftwrapIterator` requires `arena`, `ctx`, `text` and `line`, and
its `Line` requires `width` and `cells`. V `RichSoftwrapIterator` omits the arena,
keeps context/text/state private, and supplies managed storage through `new`;
`RichWrappedLine` fields currently have defaults. Iterator indices use V int
in place of Source usize. The `RichText.TextSpan` alias maps Source Segment to
`vaxis.CellSegment`; Segment's required `text` field is not part of this proof.

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
