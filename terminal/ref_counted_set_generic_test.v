module terminal

import lib_allocator

@[heap]
struct DeletionLog {
mut:
	values []u32
}

struct GenericSetContext {
mut:
	log &DeletionLog
}

fn (_ GenericSetContext) hash(value u32) u64 {
	return u64(value & 3)
}

fn (_ GenericSetContext) eql(a u32, b u32) bool {
	return a == b
}

fn (mut ctx GenericSetContext) deleted(value u32) {
	unsafe { ctx.log.values << value }
}

fn test_generic_ref_set_independent_types_callback_and_relocation() {
	allocator := lib_allocator.default(none)
	layout := generic_ref_set_layout[u32, u8, u32](16)
	assert layout.total_size == 172
	assert layout.items_start == 16
	assert layout.cap == 13
	base := allocator.alloc_bytes(layout.total_size + 64, 6, 0)
	copy := allocator.alloc_bytes(layout.total_size + 64, 6, 0)
	defer {
		allocator.free_bytes(base, layout.total_size + 64, 6, 0)
		allocator.free_bytes(copy, layout.total_size + 64, 6, 0)
	}
	mut log := &DeletionLog{}
	mut set := generic_ref_set_init[u32, u8, u32, GenericSetContext](OffsetBuf.init(unsafe { &u8(base) }).add(64),
		layout, GenericSetContext{ log: log })
	first := set.add(unsafe { &u8(base) }, 100)!
	assert set.add(unsafe { &u8(base) }, 100)! == first
	assert log.values == [u32(100)]
	set.use_multiple(unsafe { &u8(base) }, first, u32(100000))
	assert set.ref_count(unsafe { &u8(base) }, first) == 100002
	unsafe { vmemcpy(copy, base, int(layout.total_size + 64)) }
	mut relocated := set
	for _ in 0 .. 400 {
		relocated.release_multiple(unsafe { &u8(copy) }, first, u8(250))
	}
	relocated.release_multiple(unsafe { &u8(copy) }, first, u8(2))
	assert relocated.add(unsafe { &u8(copy) }, 200)! == first
	assert *set.get(unsafe { &u8(base) }, first) == 100
	assert *relocated.get(unsafe { &u8(copy) }, first) == 200
	assert log.values == [u32(100), 100]
}
