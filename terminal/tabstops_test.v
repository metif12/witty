module terminal

// Tests for Tabstops (bitset-based tab stop tracking).
// Translated from Ghostty's Tabstops.zig tests.

fn test_tabstops_basic_entry_index() {
	// Verify the entry() and index() helper functions
	assert tabstop_entry(4) == 0
	assert tabstop_entry(8) == 1
	assert tabstop_index(0) == 0
	assert tabstop_index(1) == 1
	assert tabstop_index(9) == 1
}

fn test_tabstops_masks() {
	// Verify precomputed masks
	assert tabstop_masks[3] == u8(0b00001000)
	assert tabstop_masks[4] == u8(0b00010000)
}

fn test_tabstops_basic_get_set() {
	mut t := Tabstops{}

	assert !t.get(4)
	t.set(4)
	assert t.get(4)
	assert !t.get(3)

	t.reset(0)
	assert !t.get(4)

	t.set(4)
	assert t.get(4)
	t.unset(4)
	assert !t.get(4)
}

fn test_tabstops_dynamic_allocations() {
	mut t := Tabstops{}
	defer { t.deinit() }

	// Grow the capacity by 2.
	cap := t.capacity()
	t.resize(cap * 2) or {
		assert false
		return
	}

	// Set something that was out of range of the first
	t.set(cap + 5)
	assert t.get(cap + 5)
	assert !t.get(cap + 4)

	// Prealloc still works
	assert !t.get(5)
}

fn test_tabstops_interval() {
	t := Tabstops.init(80, 4) or {
		assert false
		return
	}
	assert !t.get(0)
	assert t.get(4)
	assert !t.get(5)
	assert t.get(8)
}

fn test_tabstops_count_on_80() {
	// https://superuser.com/questions/710019/why-there-are-11-tabstops-on-a-80-column-console

	t := Tabstops.init(80, 8) or {
		assert false
		return
	}

	// Count the tabstops
	mut count := 0
	for i in 0 .. 80 {
		if t.get(i) {
			count += 1
		}
	}

	assert count == 9
}
