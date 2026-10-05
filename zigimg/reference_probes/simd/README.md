# SIMD lane helpers and checked image arithmetic

The runner compares all six helpers in pinned `src/simd.zig` and the checked arithmetic in `ImageEditor.Box.clamp` and image creation/cropping. It verifies the complete dependency source tree before compiling unchanged bodies. The source pin is zigimg `d7b7ab0ba0899643831ef042bd73289510b39906`; sorted-path/NUL/content SHA256 is `ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b`.

Run on the native ARM64 macOS host with Zig 0.15.2 and the pinned V 0.5.2 compiler:

```sh
python3 zigimg/verify_simd_reference.py /path/to/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 /path/to/zig /path/to/v
python3 zigimg/verify_simd_reference.py /path/to/zigimg-d7b7ab0ba0899643831ef042bd73289510b39906 /path/to/zig /path/to/v --v-prod
```

`--v-prod` automatically selects Zig `ReleaseSafe`; the first command selects `Debug`. `--zig-mode` can override that selection. The source target is `aarch64-macos.14.0`, linked with libc. Core dumps are disabled. Returning comparisons are byte exact; trap checks require the operation's panic category and reject `UNEXPECTED` return/error markers. Compiler-rejection checks require ordinary diagnostics and reject compiler crashes, generated-C failures, and linker failures.

## V API

Load/byte-load/conversion outputs use named fixed arrays carrying the supported native integer types (`u8/i8/u16/i16/u32/int/u64/i64/usize/isize`) or f32/f64 lanes. Store also accepts compatible fixed arrays of bools, structs, or pointers:

```v
type FourWords = [4]u16
type FourFloats = [4]f32

words := zigimg.simd_load[FourWords, u16]([u16(1), 2, 3, 4], 0)
floats := zigimg.simd_int_to_float[FourFloats, &FourWords](&words)
restored := zigimg.simd_float_to_int[FourWords, &FourFloats](&floats)
mut destination := []u16{len: 6, init: 9}
zigimg.simd_store[u16, FourWords](mut destination, restored, 2)
```

`simd_load_bytes[B](bytes, length)` copies native-endian lane bytes and preserves floating-point bit patterns; it requires a whole number of lane elements. Zero `length` in load, byte-load, and store selects all lanes. Conversion result length comes from the output array type. Conversion inputs can be dynamic/fixed arrays, pointers to fixed arrays, or scalar pointers corresponding to Source many-item pointers. Scalar-pointer callers provide valid storage for every output lane, as in the unchanged source.

`simd_vpermd([8]int, [8]int)` returns `SimdI32x8`, the eight-i32 fallback permutation. Native scalar aliases, named lane-array aliases, and aliases of scalar/fixed-array pointers are supported. Load/store permit source-valid widening and ordinarily reject narrowing, signed-to-unsigned assignment, and integer/float category mixing; explicit conversions use the conversion helpers.

## Verified scope and representation boundaries

Debug and V production/Zig ReleaseSafe each match **60,109 returning records**, **22 strict trap pairs**, **35 ordinary compile pairs**, and the **panic-visible store prefix pair**. Returning SHA256: `d67067e84ac4022693c27f755806a944c51909088df51a144f1438be1679f51e`. The four separate language/representation/compiler boundaries below are verified in both modes.

The returning matrix covers twelve native scalar types, five lane counts, every partial length, native byte layout, NaN/infinity/signed-zero lane bit patterns, integer/float casts, aliases, safe Box clamps, zero-pixel images, permutation masks, widening assignments, and 7,500 conversion pointer records, including scalar aliases and aliases of array/scalar pointers. Twenty-two strict trap pairs cover short inputs/destinations, byte-length remainders, invalid float casts, invalid permutation indices, Box arithmetic, and managed/unmanaged image pixel counts. Thirty-five ordinary compile pairs cover lane/container and assignment/conversion type constraints.

One additional panic-visible prefix pair proves that a short destination has received preceding stores before the checked trap. `store_prefix.zig` provides a fixture-root panic observer delegating to Zig's normal panic; `store_prefix.v` registers a fixture-only atexit observer. Neither changes dependency bodies. Eight focused V tests exercise borrowed buffers, aliases, pointer conversions, partial tails, unaligned float bytes, fractional truncation, permutation order, and boolean/struct stores.

The runner measures four language/representation/compiler boundaries separately:

* Source excessive comptime length ordinarily rejects; the V length argument is runtime checked and panics on the same invalid index. Source fixed input lengths shorter than conversion output can likewise reject at compile time, while V checks their length at runtime; the paired short-input traps use dynamic Source slices.
* Source zero-length array load compiles and returns normally; pinned V cannot declare `[0]T`. Source heterogeneous tuple inputs and non-native numeric widths also have no direct carrier in these APIs.
* Source direct and local **array** stores into overlapping memory propagate earlier writes: `[1,2,3,4,5,6]` stored into positions 1–4 becomes `[1,1,1,1,1,6]`. Native **vector** arguments preserve `[1,1,2,3,4,6]`. Both Debug and ReleaseSafe observations agree. V fixed-array helpers retain the measured Source array behavior; they do not expose the native vector ABI or its overlap semantics.

* Pinned V's ordinary nominal constructor for a pointer alias to a fixed array generates `memcpy(aliased_pointer, &words, sizeof(PointerAlias))` with an uninitialized pointer destination. Source's type-alias pointer declaration compiles and runs. The runner checks the V generated C without executing undefined behavior. Consumer tests and returning probes construct valid V pointer aliases through a typed view of pointer bits:

```v
type FourWordsPointer = &FourWords
base := unsafe { &words }
aliased := unsafe { *(&FourWordsPointer(&base)) }
floats := zigimg.simd_int_to_float[FourFloats, FourWordsPointer](aliased)
```

Native ARM64 runtime float casts return zero for both quiet and signaling NaN in f32/f64 inputs, for every supported signed/unsigned integer output; both source build modes are measured. V follows that measured ARM64 result. NaN behavior on other CPUs and under other source optimization modes is outside this comparison. Finite out-of-range casts panic after truncating the fractional part, so unsigned `-0.9` remains valid and returns zero. Integer-to-float rounding is compared by output bits.

The permutation follows Source's ARM/non-AVX2 fallback, which traps when a mask lane's u32 bit pattern is outside 0–7. Source's x86 AVX2 instruction masks upper index bits and has different invalid-mask behavior; that hardware branch is not represented by the fixed-array API. This checkpoint proves the stated ARM64/fallback behavior, not cross-platform vector ABI or CPU-feature parity.
