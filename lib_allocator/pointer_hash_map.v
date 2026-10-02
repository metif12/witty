module lib_allocator

import internal_hash
import buildcfg

// Zig 0.15.2 std.AutoHashMap pointer-key specialization used by
// PageList.Clone.TrackedPinsRemap. It retains the source's single allocation,
// packed fingerprints, linear probing, 80% load and fallible growth.
struct PointerMapHeader {
mut:
	values   voidptr
	keys     voidptr
	capacity u32
}

pub struct PointerHashMap[K, V] {
pub mut:
	allocator Allocator
mut:
	metadata  &u8 = unsafe { nil }
	size      u32
	available u32
}

pub fn PointerHashMap.init[K, V](allocator Allocator) PointerHashMap[K, V] {
	return PointerHashMap[K, V]{
		allocator: allocator
	}
}

fn (table &PointerHashMap[K, V]) header() &PointerMapHeader {
	return unsafe { &PointerMapHeader(usize(table.metadata) - sizeof(PointerMapHeader)) }
}

pub fn (table &PointerHashMap[K, V]) capacity() u32 {
	if isnil(table.metadata) { return 0 }
	return table.header().capacity
}

pub fn (table &PointerHashMap[K, V]) count() u32 {
	return table.size
}

fn pointer_map_hash[K](key K) u64 {
	return internal_hash.wyhash(unsafe { (&u8(&key)).vbytes(int(sizeof(K))) }, 0)
}

fn pointer_map_align(n usize, alignment usize) usize {
	return (n + alignment - 1) & ~(alignment - 1)
}

fn pointer_map_layout[K, V](capacity u32) (usize, usize, usize, u8) {
	key_align := usize(1) << alignment_log[K]()
	val_align := usize(1) << alignment_log[V]()
	mut alignment := alignment_log[PointerMapHeader]()
	if alignment < alignment_log[K]() { alignment = alignment_log[K]() }
	if alignment < alignment_log[V]() { alignment = alignment_log[V]() }
	keys_start := pointer_map_align(sizeof(PointerMapHeader) + usize(capacity), key_align)
	values_start := pointer_map_align(keys_start + usize(capacity) * sizeof(K), val_align)
	total := pointer_map_align(values_start + usize(capacity) * sizeof(V), usize(1) << alignment)
	return keys_start, values_start, total, alignment
}

fn (mut table PointerHashMap[K, V]) allocate(capacity u32) ! {
	keys_start, values_start, total, alignment := pointer_map_layout[K, V](capacity)
	raw := table.allocator.alloc_bytes(total, alignment, 0)
	if isnil(raw) { return error('OutOfMemory') }
	register_value_storage(raw, total)
	mut header := unsafe { &PointerMapHeader(raw) }
	unsafe {
		*header = PointerMapHeader{
			keys:     voidptr(usize(raw) + keys_start)
			values:   voidptr(usize(raw) + values_start)
			capacity: capacity
		}
	}
	table.metadata = unsafe { &u8(usize(raw) + sizeof(PointerMapHeader)) }
}

fn (mut table PointerHashMap[K, V]) deallocate() {
	if isnil(table.metadata) { return }
	_, _, total, alignment := pointer_map_layout[K, V](table.capacity())
	ptr := table.header()
	unregister_value_storage(ptr, total)
	table.allocator.free_bytes(ptr, total, alignment, 0)
	table.metadata = unsafe { nil }
	table.available = 0
}

pub fn (mut table PointerHashMap[K, V]) deinit() {
	table.deallocate()
}

fn (table &PointerHashMap[K, V]) get_index(key K) ?usize {
	if table.size == 0 { return none }
	hash := pointer_map_hash(key)
	mask := usize(table.capacity() - 1)
	fingerprint := u8(hash >> 57)
	mut limit := table.capacity()
	mut index := usize(hash & u64(mask))
	keys := unsafe { &K(table.header().keys) }
	for unsafe { table.metadata[index] != 0 } && limit != 0 {
		meta := unsafe { table.metadata[index] }
		if meta & 0x80 != 0 && meta & 0x7f == fingerprint {
			if unsafe { voidptr(keys[index]) == voidptr(key) } { return index }
		}
		limit--
		index = (index + 1) & mask
	}
	return none
}

pub fn (table &PointerHashMap[K, V]) get(key K) ?V {
	index := table.get_index(key) or { return none }
	return unsafe { (&V(table.header().values))[index] }
}

fn (mut table PointerHashMap[K, V]) put_assume_capacity_no_clobber(key K, value V) {
	if buildcfg.runtime_safety { assert table.get_index(key) == none
	 }
	hash := pointer_map_hash(key)
	mask := usize(table.capacity() - 1)
	mut index := usize(hash & u64(mask))
	for unsafe { table.metadata[index] & 0x80 != 0 } {
		index = (index + 1) & mask
	}
	if buildcfg.runtime_safety { assert table.available > 0
	 }
	table.available--
	unsafe {
		table.metadata[index] = u8(hash >> 57) | 0x80
		(&K(table.header().keys))[index] = key
		(&V(table.header().values))[index] = value
	}
	table.size++
}

fn (mut table PointerHashMap[K, V]) grow(capacity u32) ! {
	new_capacity := if capacity < 8 { u32(8) } else { capacity }
	if buildcfg.runtime_safety { assert new_capacity > table.capacity()
	 }
	mut next := PointerHashMap[K, V]{allocator: table.allocator}
	next.allocate(new_capacity)!
	unsafe { vmemset(next.metadata, 0, int(new_capacity)) }
	next.available = u32(u64(new_capacity) * 80 / 100)
	if table.size != 0 {
		keys := unsafe { &K(table.header().keys) }
		values := unsafe { &V(table.header().values) }
		for i in 0 .. table.capacity() {
			if unsafe { table.metadata[i] & 0x80 == 0 } { continue
			 }
			next.put_assume_capacity_no_clobber(unsafe { keys[i] }, unsafe { values[i] })
			if next.size == table.size { break
			 }
		}
	}
	table.deallocate()
	table.metadata = next.metadata
	table.size = next.size
	table.available = next.available
}

pub fn (mut table PointerHashMap[K, V]) put_no_clobber(key K, value V) ! {
	if table.available == 0 {
		load := u32(u64(table.capacity()) * 80 / 100) - table.available
		minimum := u32((u64(load + 1) * 100) / 80 + 1)
		mut capacity := u32(1)
		for capacity < minimum {
			capacity *= 2
		}
		table.grow(capacity)!
	}
	table.put_assume_capacity_no_clobber(key, value)
}
