# Direct native string addresses

`WriteStream.print_address` now accepts V strings and string aliases, using the
same `u8@…` spelling as existing value-format `*`. The string maps to a typed
Source `[]const u8` payload, so its byte pointer is formatted. Source literal
array/sentinel pointer types are outside that mapping.

The branch is after pointer dispatch, preserving the existing pointer-to-string
boundary. It writes `u8@` and hexadecimal digits separately, normalizing the
string alias through a named local. An inline cast followed by `.str` generates
invalid C in V 0.5.2; the local avoids that form. No private layout is interpreted,
characters are not read, and the original byte pointer/length remain unchanged.
Removing this branch reconstructs the previous runtime exactly. Existing string
value formatting, parsing, element names and C are byte-identical.

Unchanged public pinned Source methods and an independent writer-state model
match **5,984 full records per mode**, including **2,811 WriteFailed records**.
Direct native/alias calls, existing native/alias `*`, present/absent optional value
routes, 190 addresses, lengths zero/one/three, capacities, ignored present options
and memory/file/pipe/closed-descriptor states retain four snapshots through caller
buffer mutation and flush. These include observed string pointer/length, position,
backing/buffered/unused bytes and file/descriptor state.

**90 isolated returning controls per mode** check native/alias/value routes,
prefix/digit failures, maximal addresses, optional null padding and maximal null
width in finite memory. No controls panic. Production V is paired with Zig
ReleaseSafe.

| Observations | Count per mode | SHA-256 |
| --- | ---: | --- |
| Full records | 5,984 | `3dae8e7c2db63964eba7f98924ef96647db03a5e6ca7f12a64dfc520b841cc99` |
| Isolated return states | 90 | `df634ec0f878189c58ed4b07f5ac33f8dbfd93e6f63b37aef3493f08bbe46980` |

Ten external compiler pairs cover the six present routes, owned storage and
mutation, print, empty strings, unsupported carriers, runtime/static formats,
preserved contents and element-address regression. Five public regressions and a
portable consumer check original pointers/storage, length independence, arbitrary
address bits, partial writes and optional nulls. Owned consumers compare their own
addresses; process-local literal pointers are not compared across languages.

All 142 image test files and 24 additional production/application/platform
commands pass. Portable consumers run natively in both modes and compile for
Windows/Linux; cross builds establish compilation only. Historical string values
and string-element addresses retain record/control/state hashes in both modes.
Vaxis runtime tests are not rerun.

Source/library, executable, implementation, fixture/model/helper and input pins
are checked before/after. Expected returning outputs freeze before final runs.
Independent replay checks observations, failures, compiler outcomes and provenance;
every retained archive member is read back before commit. Completed proof caches
and archive-backed inactive extras were reclaimed with verified archives retained.

Direct optional strings and pointer-to-string payload names remain boundaries;
optional values keep their existing `?*` route. The Source read-only byte-slice
mapping does not equate string layouts, ownership or allocation rules. General
allocation/layout/ownership/lifetime contracts, compiler-generated GC traversal,
overlapping input/output, concurrency and huge successful output remain outside
the claim. Synthetic strings use the pinned public unsafe `vstring_with_len`
constructor to preserve their pointer bits without a character scan; they prove
formatting only. Runtime evidence is little-endian 64-bit macOS.

```sh
python3 zigimg/verify_writer_string_address_api_reference.py /path/to/locked/zigimg /path/to/zig-0.15.2/zig /path/to/v-0.5.2 --workdir /path/to/empty/workdir
# Add --v-prod for production / ReleaseSafe.
```

Session evidence: `/Users/alex/.cache/witty-writer-string-address-api-20261105/verified-proofs.tar.gz`,
with a per-file manifest and full member readback. Regenerable caches are excluded.


Disk exhaustion interrupted the final production historical compiler controls.
Before resuming, the saved returning corpus was replayed against Source/V and the
model, and implementation, source, fixture, helper and compiler pins were checked.
Completed command outputs and executables were pinned through the resume. The
remaining controls passed; independent audit also verifies the retained prefix.
Inactive completed proof extras were archived and read back before removing their
unpacked duplicates. The resume and cleanup receipts accompany this checkpoint.
