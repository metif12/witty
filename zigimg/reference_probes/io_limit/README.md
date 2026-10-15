# IO limit values and borrowed slices

```v
limit := zigimg.Limit.limited(3)
mut view := limit.slice(mut bytes)
// view borrows up to three bytes from bytes.
```

`Limit` provides the typed prerequisite for the remaining header-write APIs.
It maps pinned std.Io.Limit with a V value record containing a public immutable
usize `value`. Source's nonexhaustive enum permits every usize value. V exposes
`Limit.nothing()` / `unlimited()` constructors in place of enum symbols, plus
`limited`, `limited64`, `count_vec`, `min`, `min_int`, `min_int64`, `slice`,
`slice_const`, `to_int`, `slice1`, `nonzero` and `subtract`. V's default record is
zero; this does not establish Source's enum construction/coercion rules.
Existing IO and C helper bodies are unchanged. Header methods remain unported.

Zero maps to nothing; usize maximum maps to unlimited. Optional conversion of
unlimited returns none. Subtraction keeps unlimited for every amount; finite
underflow returns none. Slice lengths use minima; slice1 checks nonempty input
before saturating the limit-plus-one operation. Returned slices borrow their
input backing, which must stay alive. Mutable views and caller writes remain
visible through all saved views. count_vec counts shared/overlapping input spans
without changing headers or bytes and retains checked usize addition.

V cannot enforce Source sliceConst's const element type. A separate compiler /
consumer boundary proves Source rejects a write through that view, while V allows
it and changes the original backing in both modes. This is a representation
limit. This checkpoint introduces no raw-pointer fabrication or invalid headers.

Debug/ordinary and ReleaseSafe/production each match **20,100 returning records**,
SHA-256 `f556ae2116c0ffc169394c708a70fff51249c91de8a13346bb42cb8f471a188d`.
Each record checks constructors, vector counting, minima, options, subtraction,
nonzero and borrowed slices. Values cover 0/1/small limits, 31/32/63-bit edges,
usize maximum and its predecessor, u64 counts through maximum, lengths
0/1/8/17/64 and every byte value. Groups contain 15,000 value/slice and 5,100
every-byte profiles, retaining duplicate specifications once. Five vector
profiles cover empty/all-empty, overlapping/shared spans, lengths through 255,
and 33 shared vectors. count_vec totals reach 288; allocation-size overflow
cases are not established by these valid-storage fixtures.

Every complete record has an independent model of all scalar/optional results,
initialized backing and input payload, relative input headers, view lengths /
offsets/bytes, caller changes and writes through borrowed views. Empty views
normalize offsets only when the backing is empty. Mutable-prefix and slice1
writes test overlapping saved views; read-only views observe backing changes.
Absolute addresses are not compared.

The **240 returning controls** retain SHA-256 `98eaf99b9a6ff428299c6502d5fc523e86d64c7c12fd898c1dddb8103a0fce29`.
The **240 exact assertion/state pairs** retain SHA-256 `fa31f245894f7498bc54a8032884eb468efeb09e7ec2c76d042dbad2f54db07c`.
The failures check slice1's empty-input assertion for small/large limits before
saturating addition or mutation. Processes have empty stdout, one exact message
and identical retained state. Independent reconstruction checks the full
initialized pre-call state, scalar/options, input payload and relative headers.
FullPanic/at_exit observers capture state before opening retained output.

Twenty-six paired compile rejections per mode cover invalid constructor,
minimum, subtraction, vector and slice types. The separate const-view mutation
boundary retains Source rejection / V alias mutation. External consumers in both
languages/modes check count aliases, value copies/replacement, unlimited options,
subtraction, shared vector counts and overlapping borrowed views. General caller
coercions remain outside these finite controls.

Three public regressions pass. All 90 image test files and 17 focused production /
application/Windows/Linux checks pass. Historical preserved repetitions (18,079
records, 984 returning controls, 360 exact failures) and full/streaming IO (37,133
records, 17 generic traps, four compile boundaries) retain their hashes in both
modes. Generic traps do not establish exact state. Vaxis runtime tests are not
rerun; source is unchanged and dependency builds pass. Cross builds establish
compilation only.

The native probe directly calls the pinned compiler's std.Io.Limit. Complete
unchanged locked zigimg Source is retained/pinned for provenance; its stream
wrapper is not invoked by this pure limit probe. Existing selected libraries are
pinned, with an additional whole-file Io.zig pin:
`09df1114cba703f824337f20489c7df5294db9f07961d4ac46abbbbf9c7ecaef`.
Both the final runtime and compiler controls check this pin before/after.
Versions, implementation, probes, direct helpers and inputs are pinned too.
Source bodies/visibility/syscalls are untouched. Final implementation/probe /
runtime-runner/direct-helper bodies stay frozen; only EXPECTED assignments change
after ordinary discovery. Development diagnostics are retained separately:
initial Zig fixture spacing, V array-initializer copies, fixture-correction
syntax/bookkeeping, and preliminary runs before the added Io.zig pin. The final
fixture appends borrowed slices explicitly. Recorded local jobs survive headless
input turns. Independent replay checks complete records/models, failures,
compiler controls, binaries, actual modes, source pins and unchanged IO bodies.
Lossless parent compression pins raw/compressed output. Proofs are archived from
an owned RAM workspace; every retained member is read back before commit/release.

Runtime uses little-endian 64-bit macOS. 32-bit limited64 saturation and wider
min_int64 conversion paths are not established by these runtime fixtures.
Windows/Linux, other CPU, big-endian and 32-bit runtime remain outside the proof.
Invalid/concurrently mutated headers, large allocations/count_vec overflow,
allocator lifetime, arbitrary coercions, portable ABI and remaining V
representation limits remain boundaries.

```sh
python3 zigimg/verify_io_limit_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --workdir /empty/proof/ordinary
python3 zigimg/verify_io_limit_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2 /path/to/v-0.5.2 --v-prod --workdir /empty/proof/production
```
