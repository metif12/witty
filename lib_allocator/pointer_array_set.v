module lib_allocator

import internal_hash

// Source std.AutoArrayHashMapUnmanaged(*Pin, void) specialization. Pointer
// keys have cheap equality and no stored hash/value column. The dense key
// allocation follows MultiArrayList growth; the optional Robin Hood index
// retains the stdlib's u8/u16/u32 index representations and swap removal.
pub struct PointerArraySet[T] {
pub mut:
	keys []T
mut:
	capacity  uint
	header    voidptr
	bit_index u8
}

struct ArraySetSlot {
	entry    uint
	distance uint
}

fn array_set_cache_line() uint {
	$if arm64 || amd64 {
		return 128
	} $else {
		return 64
	}
}

fn array_set_hash[T](key T) u32 {
	return u32(internal_hash.wyhash(unsafe { (&u8(&key)).vbytes(int(sizeof(T))) }, 0))
}

fn (set &PointerArraySet[T]) index_len() uint {
	return uint(1) << set.bit_index
}

fn (set &PointerArraySet[T]) width() uint {
	return if set.bit_index <= 8 {
		uint(1)
	} else if set.bit_index <= 16 {
		uint(2)
	} else {
		uint(4)
	}
}

fn (set &PointerArraySet[T]) sentinel() uint {
	return if set.bit_index <= 8 {
		uint(0xff)
	} else if set.bit_index <= 16 {
		uint(0xffff)
	} else {
		uint(0xffffffff)
	}
}

fn (set &PointerArraySet[T]) index_capacity() uint {
	return if set.bit_index == 32 { uint(0xffffffff) } else { set.index_len() * 3 / 5 }
}

fn (set &PointerArraySet[T]) slot(index uint) ArraySetSlot {
	ptr := unsafe { &u8(uint(set.header) + 4 + (index & (set.index_len() - 1)) * set.width() * 2) }
	return if set.bit_index <= 8 {
		unsafe {
			ArraySetSlot{
				entry:    uint(ptr[0])
				distance: uint(ptr[1])
			}
		}
	} else if set.bit_index <= 16 {
		ArraySetSlot{
			entry:    uint(unsafe { *(&u16(ptr)) })
			distance: uint(unsafe { *(&u16(ptr + 2)) })
		}
	} else {
		ArraySetSlot{
			entry:    uint(unsafe { *(&u32(ptr)) })
			distance: uint(unsafe { *(&u32(ptr + 4)) })
		}
	}
}

fn (mut set PointerArraySet[T]) set_slot(index uint, slot ArraySetSlot) {
	ptr := unsafe { &u8(uint(set.header) + 4 + (index & (set.index_len() - 1)) * set.width() * 2) }
	unsafe {
		if set.bit_index <= 8 {
			ptr[0] = u8(slot.entry)
			ptr[1] = u8(slot.distance)
		} else if set.bit_index <= 16 {
			*(&u16(ptr)) = u16(slot.entry)
			*(&u16(ptr + 2)) = u16(slot.distance)
		} else {
			*(&u32(ptr)) = u32(slot.entry)
			*(&u32(ptr + 4)) = u32(slot.distance)
		}
	}
}

fn (mut set PointerArraySet[T]) insert_index(key T, entry uint) {
	mut index := uint(array_set_hash(key))
	mut displaced := entry
	mut distance := uint(0)
	for _ in 0 .. set.index_len() {
		slot := set.slot(index)
		if slot.entry == set.sentinel() {
			set.set_slot(index, ArraySetSlot{ entry: displaced, distance: distance })
			return
		}
		if slot.distance < distance {
			set.set_slot(index, ArraySetSlot{ entry: displaced, distance: distance })
			displaced = slot.entry
			distance = slot.distance
		}
		index++
		distance++
	}
	panic('unreachable full array hash map index')
}

fn (mut set PointerArraySet[T]) ensure_capacity(allocator Allocator, minimum uint) ! {
	if set.capacity < minimum {
		mut capacity := set.capacity
		initial := array_set_cache_line() / sizeof(T)
		for {
			increment := capacity / 2 + initial
			capacity = if capacity > ~uint(0) - increment {
				~uint(0)
			} else {
				capacity + increment
			}
			if capacity >= minimum { break
			 }
		}
		if capacity > ~uint(0) / sizeof(T) { return error('OutOfMemory') }
		bytes := capacity * sizeof(T)
		raw := allocator.alloc_bytes(bytes, alignment_log[T](), 0)
		if isnil(raw) { return error('OutOfMemory') }
		register_value_storage(raw, bytes)
		if set.keys.len > 0 { unsafe { vmemcpy(raw, set.keys.data, set.keys.len * int(sizeof(T))) } }
		if set.capacity > 0 {
			unregister_value_storage(set.keys.data, set.capacity * sizeof(T))
			allocator.free_bytes(set.keys.data, set.capacity * sizeof(T), alignment_log[T](), 0)
		}
		set.keys = borrowed_array[T](raw, set.keys.len, int(capacity))
		set.capacity = capacity
	}
	if minimum <= array_set_cache_line() / sizeof(T) { return }
	if !isnil(set.header) && minimum <= set.index_capacity() { return }
	if minimum > uint(0xffffffff) { return error('OutOfMemory') }
	mut bit := u8(0)
	for (uint(1) << bit) < minimum {
		bit++
	}
	if minimum > (uint(1) << bit) * 3 / 5 && bit < 32 { bit++ }
	if bit < 5 { bit = 5 }
	width := if bit <= 8 {
		uint(1)
	} else if bit <= 16 {
		uint(2)
	} else {
		uint(4)
	}
	len := uint(1) << bit
	bytes := 4 + len * width * 2
	header := allocator.alloc_bytes(bytes, 2, 0)
	if isnil(header) { return error('OutOfMemory') }
	unsafe {
		vmemset(voidptr(uint(header) + 4), 0xff, int(bytes - 4))
		*(&u8(header)) = bit
	}
	if !isnil(set.header) {
		allocator.free_bytes(set.header, 4 + set.index_len() * set.width() * 2, 2, 0)
	}
	set.header = header
	set.bit_index = bit
	for i, key in set.keys {
		set.insert_index(key, uint(i))
	}
}

fn (set &PointerArraySet[T]) find_slot(key T) ?uint {
	mut index := uint(array_set_hash(key))
	mut distance := uint(0)
	for _ in 0 .. set.index_len() {
		slot := set.slot(index)
		if slot.entry == set.sentinel() || slot.distance < distance { return none }
		if voidptr(set.keys[int(slot.entry)]) == voidptr(key) {
			return index & (set.index_len() - 1)
		}
		index++
		distance++
	}
	panic('unreachable array hash map lookup')
}

pub fn (set &PointerArraySet[T]) get_index(key T) ?uint {
	if isnil(set.header) {
		for i, existing in set.keys {
			if voidptr(existing) == voidptr(key) { return uint(i) }
		}
		return none
	}
	return set.slot(set.find_slot(key) or { return none }).entry
}

pub fn (mut set PointerArraySet[T]) put_no_clobber(allocator Allocator, key T) ! {
	set.ensure_capacity(allocator, uint(set.keys.len) + 1) or {
		// getOrPut may not fail for an existing key, even if growth fails.
		if set.get_index(key) != none {
			assert false, 'putNoClobber existing key'
			return
		}
		return err
	}
	assert set.get_index(key) == none, 'putNoClobber existing key'
	entry := set.keys.len
	set.keys = borrowed_array[T](set.keys.data, entry + 1, int(set.capacity))
	set.keys[entry] = key
	if !isnil(set.header) { set.insert_index(key, uint(entry)) }
}

pub fn (mut set PointerArraySet[T]) swap_remove(key T) bool {
	mut entry := uint(0)
	if isnil(set.header) {
		entry = set.get_index(key) or { return false }
	} else {
		removed := set.find_slot(key) or { return false }
		entry = set.slot(removed).entry
		mut last_slot := removed
		mut index := removed + 1
		for _ in 0 .. set.index_len() {
			slot := set.slot(index)
			if slot.entry == set.sentinel() || slot.distance == 0 {
				set.set_slot(last_slot, ArraySetSlot{ entry: set.sentinel() })
				break
			}
			set.set_slot(last_slot, ArraySetSlot{ entry: slot.entry, distance: slot.distance - 1 })
			last_slot = index & (set.index_len() - 1)
			index++
		}
		last := uint(set.keys.len - 1)
		if last != entry {
			slot := set.find_slot(set.keys[int(last)]) or {
				panic('unreachable moved array hash entry')
			}
			old := set.slot(slot)
			set.set_slot(slot, ArraySetSlot{ entry: entry, distance: old.distance })
		}
	}
	last := set.keys.len - 1
	set.keys[int(entry)] = set.keys[last]
	set.keys = borrowed_array[T](set.keys.data, last, int(set.capacity))
	return true
}

pub fn (mut set PointerArraySet[T]) deinit(allocator Allocator) {
	if set.capacity > 0 {
		unregister_value_storage(set.keys.data, set.capacity * sizeof(T))
		allocator.free_bytes(set.keys.data, set.capacity * sizeof(T), alignment_log[T](), 0)
	}
	if !isnil(set.header) {
		allocator.free_bytes(set.header, 4 + set.index_len() * set.width() * 2, 2, 0)
	}
	set = PointerArraySet[T]{}
}
