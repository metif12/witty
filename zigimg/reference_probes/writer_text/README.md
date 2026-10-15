# Byte, Unicode, hex and Base64 formatting

`print_ascii_char(byte, options)`, `print_ascii(bytes, options)`,
`print_unicode_codepoint(codepoint)`, `print_hex(bytes, letter_case)` and
`print_base64(bytes)` translate the pinned std.Io.Writer helpers through the
unchanged zigimg WriteStream adapter. `FormatCase` supplies lower / upper.
ASCII helpers accept arbitrary bytes, preserve alignment/padding order and ignore
precision. Unicode emits UTF-8; surrogate halves and values above U+10FFFF within
the u21 range emit U+FFFD. Hex writes each nibble separately. Base64 uses the
standard alphabet and '=' padding, writing each three-byte input window's encoded
output separately. Empty hex/Base64 input performs no writes. Existing IO/C
bodies, Source bodies, visibility and syscalls are unchanged.

Debug/ordinary and ReleaseSafe/production match:

| Observation | Count per mode | SHA-256 |
| --- | ---: | --- |
| Complete returning records | 36,852 | `58e0014715351e78da9be5515aa662042b5b5427cca2615a171a5f707e8b18f1` |
| Returning boundary controls | 512 | `f44ede993d6d5eda6c01e71998feb8bc24724e3c5c68cccbb7b8086bc16d787f` |
| Exact panic/state pairs | 188 | `e197512268320b43d73ad4686c4deabf926ba1bb794865ef14e62cc9d977937a` |

Returning records include caught WriteFailed. Each complete record/control has
five independently modeled snapshots: initialized backing, pending bytes/length,
logical position, unused-view length/offset/bytes, unchanged input payload /
relative byte-span header, option fields, descriptor validity/reference
observations, caller changes, flush results and complete file/pipe output. The
model uses Python's UTF-8, hex and Base64 encoders and separately reconstructs
Source's write calls, padding, scratch preparation, positional/streaming drains
and pipe transitions. Trap checks require empty stdout, one exact panic message,
identical retained state and the independently predicted state after prior writes.
FullPanic / at_exit capture state before opening the retained state file.

The 36,852 deduplicated records cover all five APIs, all alignments,
zero/equal/smaller/larger or omitted ASCII widths, ignored precision, every input
byte, both hex cases, all three Base64 remainder lengths, long byte input,
UTF-8 sequence boundaries, every one of the 2,048 surrogate halves, plane samples,
noncharacters, maximum Unicode/u21 values, memory/positional/streaming writers,
zero/short/large capacity, zero/three starts, empty/full pending output,
regular/replaced-pipe/closed descriptors, caller changes and flushes.
Maximum-width controls retain only finite failure/trap/bypass paths, excluding
huge successful padding. The 188 exact pairs comprise 104 padding overflows and
84 checked u21 conversions; 512 other controls return. Argument specifications
and their hashes retain the codepoint and letter-case choices too.

V uses a u32 carrier for Source's u21 argument. Values above 0x1FFFFF panic before
writer effects in both modes, matching a checked Source conversion at the probe's
call boundary. This conversion check is a V representation adaptation, not a
panic inside Source's printUnicodeCodepoint body. Source rejects a direct
0x200000 literal at compile time; V accepts the literal and requires the runtime
check. A compiler fixture proves that static acceptance without executing the
invalid call; runtime probes establish the actual check and unchanged state.

Ten paired compiler rejections per mode check wrong byte/options/codepoint /
hex-case/buffer types, negative codepoints and bool option fields. Separate
literal controls establish Source rejection of byte 256 and u32-overflow
4294967296, V ordinary warnings / actual emitted zero bytes, and V production
rejection. External consumers verify all five methods, FormatCase aliases and
emitted bytes. Other numeric coercions, invalid enum tags and enum ABI remain
outside the claim.

Four public regressions, all 95 image test files and 17 focused production,
application, Windows and Linux checks pass. Historical alignment retains 17,712
records, 1,058 returning controls and 384 exact overflow/state pairs per mode.
Full/streaming IO retains 37,133 records, 17 generic traps and four compile
boundaries per mode. Their hashes are unchanged. Generic traps do not establish
exact state. Vaxis source is unchanged; its runtime tests are not rerun and its
dependency builds pass. Cross builds establish compilation only.

Complete locked zigimg Source retains
`ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.
Selected compiler libraries retain
`ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d`.
Whole Io.zig and fmt.zig retain their existing pins. This suite additionally pins
whole unicode.zig at
`541dbd778c2765ea7c6479a873c234f32ad5ca4b7a96252410bea075a71c8348`
and whole base64.zig at
`f506bb85c053a0bda914258c3c295107e9987c48674c2addf57ffecd5dddca8d`.
Runtime and compiler controls check all pins before/after, plus versions,
path/encoder libraries, implementation, probes, direct helpers and inputs.
Runtime bodies are frozen before discovery; only EXPECTED assignments change
afterward. A preliminary u21 panic-text mismatch is retained separately; the
corrected preflight passes 161 records and nine exact traps. No final comparison
is launched until preflight and compiler controls pass.

Independent replay checks every record/model, exact failure, compiler control,
actual mode, binary, provenance pin and old IO/C body. Lossless parent compression
pins raw/compressed outputs. Every retained archive member is read back before
committing the exact reviewed files and releasing the owned RAM workspace.
Recorded local jobs survive headless input turns.

From the repository root, with pinned compilers and a fresh work directory:

```sh
python3 zigimg/verify_writer_text_reference.py \
  /Users/alex/.cache/witty-src/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 \
  /Users/alex/.cache/witty-jpeg-scan-20261013/tools/zig-aarch64-macos-0.15.2/zig \
  /Users/alex/.cache/v/v1-fallback/0.5.2/v \
  --workdir /path/to/fresh/proof
```

Add `--v-prod` for ReleaseSafe / production. Runtime is little-endian 64-bit
macOS. Windows/Linux/other CPU runtime, big-endian/32-bit runtime, arbitrary
devices/short drains, injected errors/signals, timing/syscall counts, invalid or
concurrently changed headers/tags, input/output overlap, huge storage/OOM,
allocator lifetime, portable ABI and remaining V representation limits remain
boundaries. Caller backing must stay alive. Other formatting APIs remain outside
this checkpoint.
