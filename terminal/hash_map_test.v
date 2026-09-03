module terminal

// Tests for hash_hm.v
// Translated from Ghostty's terminal/hash_hm.zig test cases.

fn test_hash_map_basic_usage() {
	mut hm := HashMapUnmanaged.init(16)

	count := u32(5)
	mut total := u64(0)
	for i in 0 .. count {
		hm.put(u64(i), u64(i)) or {
			assert false, 'put failed'
			return
		}
		total += u64(i)
	}

	mut sum := u64(0)
	mut it := hm.iterator()
	for {
		kv := it.next() or { break }
		sum += kv.key
	}
	assert sum == total

	sum = 0
	for i in 0 .. count {
		val := hm.get(u64(i)) or {
			assert false, 'get failed'
			return
		}
		assert val == u64(i)
		sum += val
	}
	assert sum == total
}

fn test_hash_map_ensure_total_capacity() {
	mut hm := HashMapUnmanaged.init(32)

	initial_cap := hm.capacity()
	assert initial_cap >= 20
	for i in 0 .. 20 {
		result := hm.fetch_put_assume_capacity(u64(i), u64(i + 10))
		assert result == none
	}
	// shouldn't resize from put_assume_capacity
	assert initial_cap == hm.capacity()
}

fn test_hash_map_ensure_unused_capacity_with_tombstones() {
	mut hm := HashMapUnmanaged.init(32)

	for i in 0 .. 100 {
		hm.ensure_unused_capacity(1) or {
			assert false, 'ensure failed'
			return
		}
		hm.put_assume_capacity(u64(i), u64(i))
		hm.remove(u64(i))
	}
}

fn test_hash_map_clear_retaining_capacity() {
	mut hm := HashMapUnmanaged.init(16)

	hm.clear_retaining_capacity()

	hm.put(1, 1) or {
		assert false
		return
	}
	assert hm.get(1) or { 0 } == u64(1)
	assert hm.count() == 1

	hm.clear_retaining_capacity()
	hm.put_assume_capacity(1, 1)
	assert hm.get(1) or { 0 } == u64(1)
	assert hm.count() == 1

	actual_cap := hm.capacity()
	assert actual_cap > 0

	hm.clear_retaining_capacity()
	hm.clear_retaining_capacity()
	assert hm.count() == 0
	assert hm.capacity() == actual_cap
	assert !hm.contains(1)
}

fn test_hash_map_ensure_total_capacity_with_existing() {
	mut hm := HashMapUnmanaged.init(hash_map_minimal_capacity)

	hm.put(0, 0) or {
		assert false
		return
	}
	assert hm.count() == 1
	assert hm.capacity() == hash_map_minimal_capacity

	// Should fail with OutOfMemory
	mut got_error := false
	hm.ensure_total_capacity(65) or { got_error = true }
	assert got_error
	assert hm.count() == 1
	assert hm.capacity() == hash_map_minimal_capacity
}

fn test_hash_map_remove() {
	mut hm := HashMapUnmanaged.init(32)

	for i in 0 .. 16 {
		hm.put(u64(i), u64(i)) or {
			assert false
			return
		}
	}

	for i in 0 .. 16 {
		if i % 3 == 0 {
			hm.remove(u64(i))
		}
	}
	assert hm.count() == 10

	mut it := hm.iterator()
	for {
		kv := it.next() or { break }
		assert kv.key == kv.value
		assert kv.key % 3 != 0
	}

	for i in 0 .. 16 {
		if i % 3 == 0 {
			assert !hm.contains(u64(i))
		} else {
			assert hm.get(u64(i)) or { 999 } == u64(i)
		}
	}
}

fn test_hash_map_reverse_removes() {
	mut hm := HashMapUnmanaged.init(32)

	for i in 0 .. 16 {
		hm.put_no_clobber(u64(i), u64(i)) or {
			assert false
			return
		}
	}

	mut i := u32(16)
	for i > 0 {
		i--
		assert hm.remove(u64(i)) == true
		assert !hm.contains(u64(i))
		for j in 0 .. i {
			assert hm.get(u64(j)) or { 999 } == u64(j)
		}
	}

	assert hm.count() == 0
}

fn test_hash_map_multiple_removes_same_metadata() {
	mut hm := HashMapUnmanaged.init(32)

	for i in 0 .. 16 {
		hm.put(u64(i), u64(i)) or {
			assert false
			return
		}
	}

	hm.remove(7)
	hm.remove(15)
	hm.remove(14)
	hm.remove(13)
	assert !hm.contains(7)
	assert !hm.contains(15)
	assert !hm.contains(14)
	assert !hm.contains(13)

	for i in 0 .. 13 {
		if i == 7 {
			assert !hm.contains(u64(i))
		} else {
			assert hm.get(u64(i)) or { 999 } == u64(i)
		}
	}

	hm.put(15, 15) or {
		assert false
		return
	}
	hm.put(13, 13) or {
		assert false
		return
	}
	hm.put(14, 14) or {
		assert false
		return
	}
	hm.put(7, 7) or {
		assert false
		return
	}
	for i in 0 .. 16 {
		assert hm.get(u64(i)) or { 999 } == u64(i)
	}
}

fn test_hash_map_put_and_remove_loop() {
	// Simplified version of the random order test.
	// Tests that repeated put/remove cycles work correctly.
	mut hm := HashMapUnmanaged.init(64)

	size := u32(32)

	// Fill the map
	for i in 0 .. size {
		hm.put(u64(i), u64(i)) or {
			assert false
			return
		}
	}
	assert hm.count() == size

	// Remove all
	for i in 0 .. size {
		hm.remove(u64(i))
	}
	assert hm.count() == 0

	// Refill and remove again
	for i in 0 .. size {
		hm.put(u64(i), u64(i)) or {
			assert false
			return
		}
	}
	assert hm.count() == size
	for i in 0 .. size {
		hm.remove(u64(i))
	}
	assert hm.count() == 0
}

fn test_hash_map_put() {
	mut hm := HashMapUnmanaged.init(32)

	for i in 0 .. 16 {
		hm.put(u64(i), u64(i)) or {
			assert false
			return
		}
	}

	for i in 0 .. 16 {
		assert hm.get(u64(i)) or { 999 } == u64(i)
	}

	// Overwrite all values
	for i in 0 .. 16 {
		hm.put(u64(i), u64(i) * 16 + 1) or {
			assert false
			return
		}
	}

	for i in 0 .. 16 {
		assert hm.get(u64(i)) or { 999 } == u64(i) * 16 + 1
	}
}

fn test_hash_map_put_full_load() {
	cap := u32(16)
	mut hm := HashMapUnmanaged.init(cap)

	for i in 0 .. cap {
		hm.put(u64(i), u64(i)) or {
			assert false
			return
		}
	}
	for i in 0 .. cap {
		assert hm.get(u64(i)) or { 999 } == u64(i)
	}

	// Should fail - map is full
	mut got_error := false
	hm.put(u64(cap), u64(cap)) or { got_error = true }
	assert got_error
}

fn test_hash_map_put_assume_capacity() {
	mut hm := HashMapUnmanaged.init(32)

	for i in 0 .. 20 {
		hm.put_assume_capacity_no_clobber(u64(i), u64(i))
	}

	mut sum := u64(0)
	for i in 0 .. 20 {
		idx := hm.get_ptr(u64(i)) or {
			assert false
			return
		}
		sum += hm.values[idx]
	}
	assert sum == 190

	for i in 0 .. 20 {
		hm.put_assume_capacity(u64(i), 1)
	}

	sum = 0
	for i in 0 .. 20 {
		sum += hm.get(u64(i)) or { 0 }
	}
	assert sum == 20
}

fn test_hash_map_repeat_put_assume_capacity_remove() {
	cap := u32(32)
	mut hm := HashMapUnmanaged.init(cap)

	limit := cap
	for i in 0 .. limit {
		hm.put_assume_capacity_no_clobber(u64(i), u64(i))
	}

	// Repeatedly delete/insert an entry without resizing the hm.
	// Put to different keys so entries don't land in the just-freed slot.
	mut i := u32(0)
	for i < 10 * limit {
		assert hm.remove(u64(i)) == true
		if i % 2 == 0 {
			hm.put_assume_capacity_no_clobber(u64(limit + i), u64(i))
		} else {
			hm.put_assume_capacity(u64(limit + i), u64(i))
		}
		i++
	}

	i = 9 * limit
	for i < 10 * limit {
		val := hm.get(u64(limit + i))
		assert val != none
		if v := val {
			assert v == u64(i)
		}
		i++
	}
	assert hm.count() == limit
}

fn test_hash_map_get_or_put() {
	mut hm := HashMapUnmanaged.init(32)

	for i in 0 .. 10 {
		hm.put(u64(i * 2), 2) or {
			assert false
			return
		}
	}

	for i in 0 .. 20 {
		hm.get_or_put_value(u64(i), 1) or {
			assert false
			return
		}
	}

	mut sum := u64(0)
	for i in 0 .. 20 {
		sum += hm.get(u64(i)) or { 0 }
	}
	assert sum == 30
}

fn test_hash_map_basic_hash_map_usage() {
	mut hm := HashMapUnmanaged.init(32)

	r1 := hm.fetch_put(1, 11) or {
		assert false
		return
	}
	assert !r1.had_previous
	r2 := hm.fetch_put(2, 22) or {
		assert false
		return
	}
	assert !r2.had_previous
	r3 := hm.fetch_put(3, 33) or {
		assert false
		return
	}
	assert !r3.had_previous
	r4 := hm.fetch_put(4, 44) or {
		assert false
		return
	}
	assert !r4.had_previous

	hm.put_no_clobber(5, 55) or {
		assert false
		return
	}

	r5 := hm.fetch_put(5, 66) or {
		assert false
		return
	}
	assert r5.had_previous
	assert r5.previous.value == 55
	r6 := hm.fetch_put(5, 55) or {
		assert false
		return
	}
	assert r6.had_previous
	assert r6.previous.value == 66

	gop1 := hm.get_or_put(5) or {
		assert false
		return
	}
	assert gop1.found_existing == true
	assert hm.values[gop1.idx] == 55
	hm.values[gop1.idx] = 77
	entry5 := hm.get_entry(5) or {
		assert false
		return
	}
	assert entry5.value == 77

	gop2 := hm.get_or_put(99) or {
		assert false
		return
	}
	assert gop2.found_existing == false
	hm.values[gop2.idx] = 42
	entry99 := hm.get_entry(99) or {
		assert false
		return
	}
	assert entry99.value == 42

	gop3 := hm.get_or_put_value(5, 5) or {
		assert false
		return
	}
	assert gop3.value == 77

	gop4 := hm.get_or_put_value(100, 41) or {
		assert false
		return
	}
	assert gop4.value == 41

	assert hm.contains(2)
	entry2 := hm.get_entry(2) or {
		assert false
		return
	}
	assert entry2.value == 22
	assert hm.get(2) or { 0 } == u64(22)

	rmv1 := hm.fetch_remove(2)
	if v := rmv1 {
		assert v.key == 2
		assert v.value == 22
	} else {
		assert false, 'expected entry'
	}
	assert hm.fetch_remove(2) == none
	assert hm.remove(2) == false
	assert hm.get_entry(2) == none
	assert hm.get(2) == none

	assert hm.remove(3) == true
}

fn test_hash_map_ensure_unused_capacity() {
	cap := u32(64)
	mut hm := HashMapUnmanaged.init(cap)

	hm.ensure_unused_capacity(32) or {
		assert false
		return
	}

	mut got_error := false
	hm.ensure_unused_capacity(cap + 1) or { got_error = true }
	assert got_error
}

fn test_hash_map_remove_by_index() {
	mut hm := HashMapUnmanaged.init(64)

	for i in 0 .. 10 {
		hm.put(u64(i), 0) or {
			assert false
			return
		}
	}
	assert hm.count() == 10

	for i in 0 .. 10 {
		key_idx := hm.get_key_index(u64(i))
		assert key_idx != none
		if idx := key_idx {
			hm.remove_by_index(idx)
		}
	}
	assert hm.count() == 0
}

fn test_hash_map_remove_by_index_zero_sized_key() {
	// Translated from ghostty "HashMap removeByPtr 0 sized key". In Zig this
	// exercises a zero-sized key type; witty keys are always u64, so this is
	// a single-entry remove-by-index round-trip on key 0.
	mut hm := HashMapUnmanaged.init(64)

	hm.put(0, 0) or {
		assert false
		return
	}
	assert hm.count() == 1

	key_idx := hm.get_key_index(0)
	assert key_idx != none
	if idx := key_idx {
		hm.remove_by_index(idx)
	}

	assert hm.count() == 0
}

fn test_hash_map_repeat_fetch_remove() {
	mut hm := HashMapUnmanaged.init(64)

	hm.put_assume_capacity(0, 0)
	hm.put_assume_capacity(1, 0)
	hm.put_assume_capacity(2, 0)
	hm.put_assume_capacity(3, 0)

	// fetch_remove() should make slots available.
	for _ in 0 .. 10 {
		assert hm.fetch_remove(3) != none
		hm.put_assume_capacity(3, 0)
	}

	assert hm.get(0) != none
	assert hm.get(1) != none
	assert hm.get(2) != none
	assert hm.get(3) != none
}

fn test_hash_map_offset_basic_usage() {
	layout := OffsetHashMap.layout(16)
	mut backing := []u8{len: int(layout.total_size)}
	base := unsafe { &backing[0] }
	offset_map := OffsetHashMap.init(OffsetBuf.init(base), layout)
	assert offset_map.metadata_offset.offset == 16

	mut hashmap := offset_map.map(base)
	for i in u64(0) .. u64(5) {
		hashmap.put(i, i * i)!
	}
	assert hashmap.count() == 5
	assert hashmap.get(3)? == 9

	// Recreating the view retains the same map contents, mirroring rebuilding
	// the pointer view from a moved page base in Ghostty.
	mut remade := offset_map.map(base)
	assert remade.get(4)? == 16
	assert remade.remove(2)
	assert hashmap.get(2) == none
}

fn test_hash_map_layout_for_capacity() {
	// Test layout computation for u32 keys and u32 values.
	layout := layout_for_capacity(16, 4, 4, 4, 4)
	assert layout.capacity == 16
	assert layout.total_size > 0
	assert layout.keys_start > 0
	assert layout.vals_start > layout.keys_start
}

fn test_hash_map_layout_for_capacity_zero() {
	layout := layout_for_capacity(0, 4, 4, 4, 4)
	assert layout.capacity == 0
}

fn test_hash_map_layout_no_overflow_large_capacity() {
	// Test that layout_for_capacity handles large capacities without overflow.
	// See: https://github.com/ghostty-org/ghostty/issues/9862
	large_cap := u32(1 << 30)
	layout := layout_for_capacity(large_cap, 8, 8, 8, 8)

	// total_size should be at least cap * (sizeof(K) + sizeof(V))
	min_expected := int(large_cap) * 16
	assert layout.total_size >= min_expected
	assert layout.keys_start > 0
	assert layout.vals_start > layout.keys_start
}

fn test_hash_slot_metadata_states() {
	// Test metadata state transitions.
	mut m := HashSlotMetadata{}
	assert m.is_free()
	assert !m.is_used()
	assert !m.is_tombstone()

	// Fill with a fingerprint.
	m.fill(42)
	assert m.is_used()
	assert !m.is_free()
	assert !m.is_tombstone()
	assert m.fingerprint() == 42

	// Remove (becomes tombstone).
	m.mark_removed()
	assert m.is_tombstone()
	assert !m.is_used()
	assert !m.is_free()
}

fn test_hash_slot_metadata_fingerprint() {
	// Fingerprint should use top 7 bits of hash.
	assert take_fingerprint(0) == 0
	assert take_fingerprint(u64(0xFFFFFFFFFFFFFFFF)) == 127
	assert take_fingerprint(u64(1) << 57) == 1
}
