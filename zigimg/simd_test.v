module zigimg

type SimdTestWords = [4]u16
type SimdTestFloats = [4]f32
type SimdTestBytes = [4]u8
type SimdTestWord = u16
type SimdTestAliasWords = [4]SimdTestWord
type SimdTestWordPointer = &SimdTestWord
type SimdTestWordsPointer = &SimdTestWords

fn test_simd_partial_load_and_store_preserve_tails() {
	input := [u16(1), 257, 65535, 4]
	loaded := simd_load[SimdTestWords, u16](input, 2)
	assert loaded == SimdTestWords([u16(1), 257, 0, 0]!)
	mut destination := [u32(9), 9, 9, 9, 9, 9]
	simd_store[u32, SimdTestWords](mut destination, loaded, 2)
	assert destination == [u32(1), 257, 9, 9, 9, 9]
	simd_store[u32, SimdTestWords](mut destination, loaded, 0)
	assert destination == [u32(1), 257, 0, 0, 9, 9]
	assert input == [u16(1), 257, 65535, 4]
}

fn test_simd_native_bytes_copy_unaligned_float_bit_patterns() {
	mut raw := [u8(42), 0, 0, 0, 128, 1, 0, 128, 127, 0, 0, 128, 63, 0, 0, 0, 0]
	loaded := simd_load_bytes[SimdTestFloats](raw[1..], 0)
	assert unsafe { *(&u32(&loaded[0])) } == 0x80000000
	assert unsafe { *(&u32(&loaded[1])) } == 0x7f800001
	assert loaded[2] == 1
	raw[1] = 1
	assert unsafe { *(&u32(&loaded[0])) } == 0x80000000
}

fn test_simd_integer_float_conversions_truncate_fractional_parts() {
	floats := simd_int_to_float[SimdTestFloats, []i16]([i16(-32768), -1, 0, 32767])
	assert floats == SimdTestFloats([f32(-32768), -1, 0, 32767]!)
	bytes := simd_float_to_int[SimdTestBytes, []f64]([f64(-0.9), 0.9, 1.9, 255.9])
	assert bytes == SimdTestBytes([u8(0), 0, 1, 255]!)
}

fn test_simd_store_preserves_source_array_aliasing() {
	mut storage := [u16(1), 2, 3, 4, 5, 6]
	mut destination := unsafe { storage[1..5] }
	lanes := unsafe { &SimdTestWords(storage.data) }
	simd_store[u16, SimdTestWords](mut destination, unsafe { *lanes }, 0)
	assert storage == [u16(1), 1, 1, 1, 1, 6]
}

fn test_simd_conversion_accepts_borrowed_lane_arrays() {
	words := SimdTestWords([u16(1), 257, 65535, 4]!)
	floats := simd_int_to_float[SimdTestFloats, &SimdTestWords](&words)
	converted := simd_float_to_int[SimdTestWords, &SimdTestFloats](&floats)
	assert converted == words
	assert words[2] == 65535
	assert floats[2] == 65535
	pointer_floats := simd_int_to_float[SimdTestFloats, &u16](&words[0])
	pointer_words := simd_float_to_int[SimdTestWords, &f32](&pointer_floats[0])
	assert pointer_words == words
	base_pointer := unsafe { &words }
	array_pointer := unsafe { *(&SimdTestWordsPointer(&base_pointer)) }
	assert simd_int_to_float[SimdTestFloats, SimdTestWordsPointer](array_pointer) == floats
	alias_words := SimdTestAliasWords([SimdTestWord(1), 257, 65535, 4]!)
	base_alias_pointer := unsafe { &alias_words[0] }
	alias_pointer := unsafe { *(&SimdTestWordPointer(&base_alias_pointer)) }
	assert simd_int_to_float[SimdTestFloats, SimdTestWordPointer](alias_pointer) == floats
}

fn test_simd_native_scalar_and_lane_aliases() {
	input := [SimdTestWord(1), 257, 65535, 4]
	loaded := simd_load[SimdTestAliasWords, SimdTestWord](input, 0)
	assert loaded[2] == SimdTestWord(65535)
	floats := simd_int_to_float[SimdTestFloats, SimdTestAliasWords](loaded)
	assert floats[2] == 65535
	bytes := unsafe { (&u8(&loaded[0])).vbytes(int(sizeof(SimdTestAliasWords))) }
	reloaded := simd_load_bytes[SimdTestAliasWords](bytes, 0)
	assert reloaded == loaded
}

fn test_simd_permutation_retains_the_source_fallback() {
	result := simd_vpermd([1, 2, 3, 4, 5, 6, 7, 8]!, [7, 7, 0, 0, 3, 2, 1, 5]!)
	assert result == SimdI32x8([8, 8, 1, 1, 4, 3, 2, 6]!)
}

struct SimdTestItem {
	x u16
	y u32
}

type SimdTestItems = [4]SimdTestItem
type SimdTestBools = [4]bool

fn test_simd_store_supports_boolean_and_struct_values() {
	mut bools := [false, false, false, false, false, false]
	simd_store[bool, SimdTestBools](mut bools, SimdTestBools([true, false, true, true]!), 2)
	assert bools == [true, false, false, false, false, false]
	input := SimdTestItems([SimdTestItem{ x: 1, y: 11 }, SimdTestItem{ x: 2, y: 22 },
		SimdTestItem{ x: 3, y: 33 }, SimdTestItem{ x: 4, y: 44 }]!)
	mut items := []SimdTestItem{len: 6, init: SimdTestItem{
		x: 9
		y: 99
	}}
	simd_store[SimdTestItem, SimdTestItems](mut items, input, 0)
	assert items[0] == input[0]
	assert items[3] == input[3]
	assert items[4] == SimdTestItem{
		x: 9
		y: 99
	}
}
