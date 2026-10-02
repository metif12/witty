module terminal

import lib_allocator
import internal_hash

struct CustomMapKey {
	value u32
}

struct CustomMapValue {
	number i64
}

struct CustomMapContext {
	mask u32
}

struct PaddedMapKey {
	small u8
	large u32
}

fn (ctx CustomMapContext) hash(key CustomMapKey) u64 {
	return u64(key.value & ctx.mask)
}

fn (ctx CustomMapContext) eql(a CustomMapKey, b CustomMapKey) bool {
	return a.value & ctx.mask == b.value & ctx.mask
}

struct AdaptedMapContext {}

fn (_ AdaptedMapContext) hash(value u32) u64 {
	return u64(value & 255)
}

fn (_ AdaptedMapContext) eql(value u32, resident CustomMapKey) bool {
	return value & 255 == resident.value & 255
}

fn test_generic_offset_map_custom_context_and_relocation() {
	layout := generic_hash_map_layout[CustomMapKey, CustomMapValue](16)
	assert layout.total_size == 224
	assert layout.keys_start == 16
	assert layout.vals_start == 80
	allocator := lib_allocator.default(none)
	base := allocator.alloc_bytes(layout.total_size + 64, 6, 0)
	copy := allocator.alloc_bytes(layout.total_size + 64, 6, 0)
	defer {
		allocator.free_bytes(base, layout.total_size + 64, 6, 0)
		allocator.free_bytes(copy, layout.total_size + 64, 6, 0)
	}
	ctx := CustomMapContext{
		mask: 255
	}
	offsets := generic_offset_hash_map_init[CustomMapKey, CustomMapValue, CustomMapContext](OffsetBuf.init(unsafe { &u8(base) }).add(64),
		layout, ctx)
	mut map_view := offsets.map(unsafe { &u8(base) }, ctx)
	map_view.put(CustomMapKey{ value: 7 }, CustomMapValue{
		number: 42
	})!
	map_view.put(CustomMapKey{ value: 263 }, CustomMapValue{
		number: 99
	})!
	assert map_view.count() == 1
	assert map_view.get(CustomMapKey{ value: 7 })?.number == 99
	unsafe { vmemcpy(copy, base, int(layout.total_size + 64)) }
	mut relocated := offsets.map(unsafe { &u8(copy) }, ctx)
	assert relocated.get(CustomMapKey{ value: 263 })?.number == 99
	assert relocated.remove(CustomMapKey{ value: 7 })
	assert relocated.count() == 0
	assert map_view.count() == 1
	assert offsets.map(unsafe { &u8(copy) }, ctx).count() == 0
	mut adapted := relocated.get_or_put_context_adapted(u32(5), AdaptedMapContext{})!
	unsafe {
		*adapted.key_ptr = CustomMapKey{
			value: 5
		}
		*adapted.value_ptr = CustomMapValue{
			number: 123
		}
	}
	assert relocated.get_or_put_context_adapted(u32(261), AdaptedMapContext{})!.found_existing
	assert relocated.get(CustomMapKey{ value: 5 })?.number == 123
}

fn test_auto_offset_map_struct_padding_and_pointer_access() {
	allocator := lib_allocator.default(none)
	layout := generic_hash_map_layout[PaddedMapKey, u64](16)
	base := allocator.alloc_bytes(layout.total_size, 6, 0)
	defer { allocator.free_bytes(base, layout.total_size, 6, 0) }
	offsets := auto_offset_hash_map_init[PaddedMapKey, u64](OffsetBuf.init(unsafe { &u8(base) }),
		layout)
	mut view := offsets.map(unsafe { &u8(base) }, AutoHashContext[PaddedMapKey]{})
	key := PaddedMapKey{
		small: 7
		large: 42
	}
	mut result := view.get_or_put(key)!
	unsafe {
		*result.value_ptr = 999
	}
	assert view.get(key)? == 999
	assert *view.get_key_ptr(key)? == key
	view.remove_by_ptr(view.get_key_ptr(key)?)
	assert view.count() == 0
}

struct HashNoPayload {}

struct HashPayload {
	value u32
}

type HashUnion = HashNoPayload | HashPayload

fn test_auto_hash_source_categories() {
	value := u32(0x11223344)
	ptr := &value
	assert auto_hash_bytes(ptr) == auto_hash_bytes(usize(ptr))
	fixed := [u16(0x1122), u16(0x3344)]!
	assert auto_hash_bytes(fixed) == [u8(0x22), 0x11, 0x44, 0x33]
	present := ?u32(value)
	absent := ?u32(none)
	assert auto_hash_bytes(present) == auto_hash_bytes(value)
	assert auto_hash_bytes(absent).len == 0
	no_payload := HashUnion(HashNoPayload{})
	payload := HashUnion(HashPayload{
		value: value
	})
	assert auto_hash_bytes(no_payload) == [u8(0)]
	assert auto_hash_bytes(payload) == [u8(1), 0x44, 0x33, 0x22, 0x11]
	assert AutoHashContext[HashUnion]{}.eql(payload, payload)
	assert !AutoHashContext[HashUnion]{}.eql(no_payload, payload)
}

fn test_auto_hash_source_error_numeric_identity_and_error_union() {
	first := error_with_code('first name', 1)
	second := error_with_code('different name', 1)
	assert AutoHashContext[IError]{}.hash(first) == AutoHashContext[IError]{}.hash(second)
	assert AutoHashContext[IError]{}.eql(first, second)
	assert !AutoHashContext[IError]{}.eql(first, error_with_code('first name', 2))
	result := SourceHashResult[u32]{
		value: 0x11223344
	}
	failure := SourceHashResult[u32]{
		is_error:   true
		error_code: 1
	}
	assert AutoHashContext[SourceHashResult[u32]]{}.hash(result) == AutoHashContext[u32]{}.hash(u32(0x11223344))
	assert AutoHashContext[SourceHashResult[u32]]{}.hash(failure) == AutoHashContext[u16]{}.hash(u16(1))
	assert !AutoHashContext[SourceHashResult[u32]]{}.eql(result, failure)
}

fn test_auto_offset_map_optional_key_inference_and_relocation() ! {
	present := ?u32(u32(0x11223344))
	absent := ?u32(none)
	allocator := lib_allocator.c_allocator_value()
	base := allocator.alloc_bytes(4096, 6, 0)
	copy := allocator.alloc_bytes(4096, 6, 0)
	assert !isnil(base) && !isnil(copy)
	defer {
		allocator.free_bytes(base, 4096, 6, 0)
		allocator.free_bytes(copy, 4096, 6, 0)
	}
	offsets := auto_offset_optional_hash_map_inferred(OffsetBuf.init(unsafe { &u8(base) }), 16,
		present, u32(0))
	ctx := AutoHashContext[SourceHashOptional[u32]]{}
	present_key := source_hash_optional(present)
	absent_key := source_hash_optional(absent)
	mut view := offsets.map(unsafe { &u8(base) }, ctx)
	view.put(present_key, u32(42))!
	view.put(absent_key, u32(7))!
	assert view.count() == 2
	assert view.get(present_key)? == 42
	assert view.get(absent_key)? == 7
	unsafe { vmemcpy(copy, base, 4096) }
	mut moved := offsets.map(unsafe { &u8(copy) }, ctx)
	assert moved.get(present_key)? == 42
	assert moved.remove(absent_key)
	assert moved.count() == 1
	assert view.count() == 2
}

enum SourceHashTag as u8 {
	zero = 0
	high = 127
}

// Values printed by unchanged Zig 0.15.2 std.hash_map.AutoContext in
// reference_probes/auto_hash/main.zig. These verify the final hash, not merely
// byte encodings produced by the V implementation.
fn test_auto_hash_original_native_results() {
	assert AutoHashContext[u32]{}.hash(u32(0x11223344)) == u64(4378133365921508531)
	fixed := [u16(0x1122), u16(0x3344)]!
	assert internal_hash.wyhash(auto_hash_bytes(fixed), 0) == u64(9630118702735392078)
	present := ?u32(u32(0x11223344))
	absent := ?u32(none)
	assert internal_hash.wyhash(auto_hash_bytes(present), 0) == u64(4378133365921508531)
	assert internal_hash.wyhash(auto_hash_bytes(absent), 0) == u64(290873116282709081)
	assert AutoHashContext[SourceHashOptional[u32]]{}.hash(source_hash_optional(present)) == u64(4378133365921508531)
	assert AutoHashContext[SourceHashOptional[u32]]{}.hash(source_hash_optional(absent)) == u64(290873116282709081)
	assert AutoHashContext[HashUnion]{}.hash(HashUnion(HashNoPayload{})) == u64(18151106360299273605)
	assert AutoHashContext[HashUnion]{}.hash(HashUnion(HashPayload{ value: 0x11223344 })) == u64(12856782651805138456)
	assert AutoHashContext[IError]{}.hash(error_with_code('any source name', 1)) == u64(4180067508479897175)
	assert AutoHashContext[SourceHashResult[u32]]{}.hash(SourceHashResult[u32]{ value: 0x11223344 }) == u64(4378133365921508531)
	assert AutoHashContext[SourceHashResult[u32]]{}.hash(SourceHashResult[u32]{
		is_error:   true
		error_code: 1
	}) == u64(4180067508479897175)
	null_pointer := ?&u32(none)
	assert internal_hash.wyhash(auto_hash_bytes(null_pointer), 0) == u64(16624905383039181106)
	assert AutoHashContext[PaddedMapKey]{}.hash(PaddedMapKey{ small: 7, large: 42 }) == u64(13689850338909966510)
	assert AutoHashContext[SourceHashTag]{}.hash(SourceHashTag.high) == u64(15579651072214242561)
	assert AutoHashContext[bool]{}.hash(true) == u64(15398492003712018733)
	assert AutoHashContext[i16]{}.hash(i16(-7)) == u64(2743915450954940543)
}

fn hash_function_first(value u32) u32 {
	return value
}

fn hash_function_second(value u32) u32 {
	return value + 1
}

type SourceHashFunction = fn (u32) u32

fn test_auto_hash_function_addresses_and_shallow_nested_slices() {
	first := SourceHashFunction(hash_function_first)
	second := SourceHashFunction(hash_function_second)
	assert auto_hash_bytes(first) == auto_hash_bytes(usize(voidptr(first)))
	assert auto_hash_eql(first, first)
	assert !auto_hash_eql(first, second)
	text := 'identity'
	optional_text := ?string(text)
	assert auto_hash_bytes(optional_text) == auto_hash_bytes(text)
	source_optional := source_hash_optional(optional_text)
	assert source_optional.source_auto_hash_bytes() == auto_hash_bytes(text)
	fixed := [text]!
	assert auto_hash_bytes(fixed) == auto_hash_bytes(text)
	same_storage := unsafe { tos(text.str, text.len) }
	other_storage := text.clone()
	assert auto_hash_eql(source_optional, source_hash_optional(?string(same_storage)))
	assert !auto_hash_eql(source_optional, source_hash_optional(?string(other_storage)))
}
