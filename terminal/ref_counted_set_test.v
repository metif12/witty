module terminal

// Tests for RefCountedSet.
//
// Source: ref_counted_set.zig tests (implicit via main.zig test block)
//
// These tests verify the basic operations of the reference-counted set:
// add, lookup, use, release, and ref counting behavior.

// Test creating a layout with zero capacity.
fn test_rcs_layout_zero() {
	l := RefCountedSetLayout.init(0)
	assert l.cap == 0
	assert l.table_cap == 0
	assert l.total_size == 0
}

// Test creating a layout with a small capacity.
fn test_rcs_layout_small() {
	l := RefCountedSetLayout.init(8)
	// table_cap should be rounded up to next power of 2 (8)
	assert l.table_cap == 8
	// items cap should be load_factor * table_cap
	assert l.cap > 0
	assert l.total_size > 0
}

// Test creating an empty set.
fn test_rcs_init_empty() {
	l := RefCountedSetLayout.init(16)
	s := RefCountedSet.init(l)
	assert s.count() == 0
	assert s.next_id == 1
}

// Test adding an item to the set.
fn test_rcs_add() {
	l := RefCountedSetLayout.init(32)
	mut s := RefCountedSet.init(l)

	style := CellStyle{}
	id := s.add(style) or {
		assert false, 'add failed: ${err}'
		return
	}
	assert id > 0
	assert s.count() == 1
	assert s.ref_count(id) == 1
}

// Test that adding the same item returns the same ID with incremented ref count.
fn test_rcs_add_duplicate() {
	l := RefCountedSetLayout.init(32)
	mut s := RefCountedSet.init(l)

	style := CellStyle{}
	id1 := s.add(style) or {
		assert false, 'add failed'
		return
	}
	id2 := s.add(style) or {
		assert false, 'add failed'
		return
	}
	assert id1 == id2
	assert s.ref_count(id1) == 2
	assert s.count() == 1
}

// Test adding different items gets different IDs.
fn test_rcs_add_different() {
	l := RefCountedSetLayout.init(32)
	mut s := RefCountedSet.init(l)

	style1 := CellStyle{}
	style2 := CellStyle{
		flags: StyleFlags{
			bold: true
		}
	}

	id1 := s.add(style1) or {
		assert false, 'add failed'
		return
	}
	id2 := s.add(style2) or {
		assert false, 'add failed'
		return
	}
	assert id1 != id2
	assert s.count() == 2
}

// Test lookup finds existing items.
fn test_rcs_lookup() {
	l := RefCountedSetLayout.init(32)
	mut s := RefCountedSet.init(l)

	style := CellStyle{
		flags: StyleFlags{
			italic: true
		}
	}
	id := s.add(style) or {
		assert false, 'add failed'
		return
	}

	found := s.lookup(style) or {
		assert false, 'lookup should find the item'
		return
	}
	assert found == id
}

// Test lookup returns none for missing items.
fn test_rcs_lookup_missing() {
	l := RefCountedSetLayout.init(32)
	mut s := RefCountedSet.init(l)

	style := CellStyle{}
	result := s.lookup(style)
	assert result == none
}

// Test use_item increments the ref count.
fn test_rcs_use() {
	l := RefCountedSetLayout.init(32)
	mut s := RefCountedSet.init(l)

	style := CellStyle{}
	id := s.add(style) or {
		assert false, 'add failed'
		return
	}
	assert s.ref_count(id) == 1

	s.use_item(id)
	assert s.ref_count(id) == 2
}

// Test release decrements the ref count.
fn test_rcs_release() {
	l := RefCountedSetLayout.init(32)
	mut s := RefCountedSet.init(l)

	style := CellStyle{}
	id := s.add(style) or {
		assert false, 'add failed'
		return
	}
	assert s.ref_count(id) == 1
	assert s.count() == 1

	s.release(id)
	assert s.ref_count(id) == 0
	assert s.count() == 0
}

// Test get returns the stored value.
fn test_rcs_get() {
	l := RefCountedSetLayout.init(32)
	mut s := RefCountedSet.init(l)

	style := CellStyle{
		flags: StyleFlags{
			bold: true
			underline: true
		}
	}
	id := s.add(style) or {
		assert false, 'add failed'
		return
	}

	got := s.get(id)
	assert got.flags.bold == true
	assert got.flags.underline == true
}

// Test capacity_for_count calculation.
fn test_rcs_capacity_for_count() {
	assert rcs_capacity_for_count(0) == 0
	// For n items we need at least (n+1)/load_factor capacity
	c := rcs_capacity_for_count(10)
	assert c >= 11 // at least n+1
}

// Test ceil_power_of_two helper.
fn test_rcs_ceil_power_of_two() {
	assert rcs_ceil_power_of_two(1) == 1
	assert rcs_ceil_power_of_two(2) == 2
	assert rcs_ceil_power_of_two(3) == 4
	assert rcs_ceil_power_of_two(5) == 8
	assert rcs_ceil_power_of_two(8) == 8
	assert rcs_ceil_power_of_two(9) == 16
}

// Test use_multiple increments by n.
fn test_rcs_use_multiple() {
	l := RefCountedSetLayout.init(32)
	mut s := RefCountedSet.init(l)

	style := CellStyle{}
	id := s.add(style) or {
		assert false, 'add failed'
		return
	}
	s.use_multiple(id, 5)
	assert s.ref_count(id) == 6 // 1 from add + 5 from use_multiple
}

// Test release_multiple decrements by n.
fn test_rcs_release_multiple() {
	l := RefCountedSetLayout.init(32)
	mut s := RefCountedSet.init(l)

	style := CellStyle{}
	id := s.add(style) or {
		assert false, 'add failed'
		return
	}
	s.use_multiple(id, 4) // ref = 5
	s.release_multiple(id, 3) // ref = 2
	assert s.ref_count(id) == 2
	assert s.count() == 1

	s.release_multiple(id, 2) // ref = 0
	assert s.ref_count(id) == 0
	assert s.count() == 0
}
