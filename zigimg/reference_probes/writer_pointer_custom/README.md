# Custom formatting through optional pointers

`WriteStream.print_value('?f', options, pointer, max_depth)` now invokes a present
optional pointee's fallible `format(mut writer WriteStream) !` method. The concrete
receiver is preserved; options and depth are not passed to the method. Absent
values keep aligned `null` and never enter the formatter. Ordinary `any`/default
reflection, explicit addresses and nonpointer custom formatting are unchanged.

V 0.5.2 checks an unused optional-address specialization when a custom record
alias is present. That specialization can lose its pointer flag and generate an
incompatible struct/pointer call. The address helper now rejects nonpointer
specializations before alias normalization. Optional unwrapping stays outside
reflected branches to avoid V's parser/type-temporary issues. The scalar address
comparison verifies that supported address outputs and failures are unchanged.

The native fixture calls the unchanged public Source method through the locked
image writer. Six carriers are optional record pointers, pointee aliases, whole
pointer aliases, absent pointers, sum pointers and concrete error-record pointers.
The method writes `custom(`, a signed number, `:`, borrowed binary data and `)`
separately. Injected errors precede/interrupt these writes. Five snapshots retain
backing/pending/unused bytes, position, descriptor/file state, inputs/options,
canonical values, method-entry counts and completed steps through caller-buffer
mutation and flush. Memory, positional/streaming files, replaced pipes, closed
descriptors, options, depth and every capacity through 39 bytes are covered.

An independent model predicts individual calls, writes and state. Each mode
matches **6,125 records**, including **4,086 WriteFailed records**, plus **106
isolated returning controls** and **two exact panic/state pairs**. Present methods
ignore maximal width/precision at zero depth. Absent values retain null-padding
overflow and failure order; both modes require one exact `integer overflow`
diagnostic and matching state for each trap.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete records | 6,125 | `cca41b43e17ff0506a959c4a5cd1b0cd7a7705b937ab4969095af6a2c7467612` |
| Returning controls | 106 | `1027b1869d27178b7f646fadf885839b7b991d7c9f752bef457e80c358695f17` |
| Panic/state controls | 2 | `36d4f88f11bcbc83180f6cefcd3894ac0f515c3cc82cd947f2d4a1a14d2338f3` |

Twelve external compiler pairs cover records, both alias forms, enum receivers,
active sum receivers, absence, print composition, method errors, missing and
nonfallible methods, invalid formats and runtime strings. Three public regressions
and a portable consumer also check enum/sum receiver contents, arbitrary V error
message/code propagation, partial writes and fixed arrays beside the new calls.
The aggregate-pointer compiler control now accepts direct optional `?f` in V;
its previous rejection is superseded by this checkpoint.

The fixture uses concrete optional constructors rather than a generic `?&T`
constructor, which makes V reuse the final specialization's type. A concrete sum
local preserves the descriptor while constructing its optional pointer; it does
not assert equality with Source's union representation. External methods must be
public. Source checks methods/formats statically; V accepts runtime strings and
can return an unsupported-format error. Source accepts nonfallible formatters;
V still requires the fallible signature.

All 126 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Historical scalar-address,
nonpointer custom and aggregate-pointer comparisons retain their record/state
hashes in both modes; the updated optional-custom compiler control now succeeds.
Vaxis runtime tests are not rerun.

Only the optional-pointer custom branch and unused address-specialization guard
change the runtime. Other dispatch/leaf formatters and IO/C remain byte-identical.
Source/library, executable, implementation, fixture, model/helper and input pins
are checked before/after. Expected results and bodies freeze before final runs.
Independent replay verifies observations, failures, compiler outcomes and
provenance; every retained archive member is read back.

Mutable receivers, arbitrary interfaces, present null/invalid pointers, private
layout/ownership/lifetime/copy equivalence, concurrent mutation and huge successful
output/storage remain boundaries. Runtime evidence is pinned little-endian 64-bit
macOS; cross builds establish compilation only. Existing aggregate address,
broader pointer and overlapping-alias limits remain documented separately.

```sh
python3 zigimg/verify_writer_pointer_custom_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-pointer-custom-20261104/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.
