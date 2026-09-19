module font

// Tests for CodepointMap (translated from ghostty/src/font/CodepointMap.zig)

fn test_codepointmap_exact_range() {
	mut m := CodepointMap{}
	defer {
		m.deinit()
	}

	// Initially empty - should return none.
	assert m.get(1) == none

	// Add an exact single-codepoint range.
	m.add(CodepointMapEntry{
		range: [u32(1), 1]!
		descriptor: Descriptor{ family: 'A' }
	})

	d := m.get(1) or {
		assert false, 'expected to find codepoint 1'
		return
	}
	assert d.family or { '' } == 'A'
}

fn test_codepointmap_later_entry_priority() {
	mut m := CodepointMap{}
	defer {
		m.deinit()
	}

	// Add first entry.
	m.add(CodepointMapEntry{
		range: [u32(1), 1]!
		descriptor: Descriptor{ family: 'A' }
	})

	// Later entry takes priority for overlapping range.
	m.add(CodepointMapEntry{
		range: [u32(1), 2]!
		descriptor: Descriptor{ family: 'B' }
	})

	d := m.get(1) or {
		assert false, 'expected to find codepoint 1'
		return
	}
	assert d.family or { '' } == 'B'
}

fn test_codepointmap_non_matching() {
	mut m := CodepointMap{}
	defer {
		m.deinit()
	}

	m.add(CodepointMapEntry{
		range: [u32(1), 2]!
		descriptor: Descriptor{ family: 'B' }
	})

	// Non-matching codepoints should return none.
	assert m.get(0) == none
	assert m.get(3) == none
}

fn test_codepointmap_multiple_ranges() {
	mut m := CodepointMap{}
	defer {
		m.deinit()
	}

	m.add(CodepointMapEntry{
		range: [u32(1), 1]!
		descriptor: Descriptor{ family: 'A' }
	})
	m.add(CodepointMapEntry{
		range: [u32(1), 2]!
		descriptor: Descriptor{ family: 'B' }
	})
	m.add(CodepointMapEntry{
		range: [u32(3), 4]!
		descriptor: Descriptor{ family: 'C' }
	})
	m.add(CodepointMapEntry{
		range: [u32(5), 6]!
		descriptor: Descriptor{ family: 'D' }
	})

	// Codepoint 3 should match range [3,4] -> 'C'.
	d3 := m.get(3) or {
		assert false, 'expected to find codepoint 3'
		return
	}
	assert d3.family or { '' } == 'C'

	// Codepoint 1 should still match later entry [1,2] -> 'B'.
	d1 := m.get(1) or {
		assert false, 'expected to find codepoint 1'
		return
	}
	assert d1.family or { '' } == 'B'
}

fn test_codepointmap_clone() {
	mut m := CodepointMap{}
	defer {
		m.deinit()
	}

	m.add(CodepointMapEntry{
		range: [u32(1), 1]!
		descriptor: Descriptor{ family: 'A' }
	})
	m.add(CodepointMapEntry{
		range: [u32(10), 20]!
		descriptor: Descriptor{ family: 'B' }
	})

	mut c := m.clone()
	defer {
		c.deinit()
	}

	// Clone should have the same entries.
	assert c.entries.len == 2

	d1 := c.get(1) or {
		assert false, 'expected to find codepoint 1 in clone'
		return
	}
	assert d1.family or { '' } == 'A'

	d15 := c.get(15) or {
		assert false, 'expected to find codepoint 15 in clone'
		return
	}
	assert d15.family or { '' } == 'B'
}

fn test_codepointmap_hashcode() {
	mut m := CodepointMap{}
	defer {
		m.deinit()
	}

	m.add(CodepointMapEntry{
		range: [u32(1), 1]!
		descriptor: Descriptor{ family: 'A' }
	})

	// Hashcode should be deterministic.
	h1 := m.hashcode()
	h2 := m.hashcode()
	assert h1 == h2

	// Adding an entry should change the hashcode.
	m.add(CodepointMapEntry{
		range: [u32(2), 2]!
		descriptor: Descriptor{ family: 'B' }
	})
	h3 := m.hashcode()
	assert h1 != h3
}

fn test_codepointmap_hashcode_matches_source_u21_layout() {
	mut m := CodepointMap{}
	m.add(CodepointMapEntry{
		range: [u32(1), 0x10ffff]!
		descriptor: Descriptor{ family: 'A' }
	})
	// Reference value from CodepointMap.hash under Zig 0.15.2. In
	// particular, each u21 range endpoint occupies three bytes.
	assert m.hashcode() == u64(0xcf23075fb01be901)
	mut hasher := SourceHash{}
	m.hash(mut hasher)
	assert hasher.final() == m.hashcode()
	assert m.get(0x200000) == none
}
