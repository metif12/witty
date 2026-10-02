module terminal

import lib_allocator

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
