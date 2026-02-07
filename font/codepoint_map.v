module font

// CodepointMap is a map of codepoints to a discovery descriptor of a font
// to use for that codepoint. If the descriptor doesn't return any matching
// font, the codepoint is rendered using the default font.
//
// Translated from ghostty/src/font/CodepointMap.zig

// Entry represents a single entry in the CodepointMap, mapping a range
// of Unicode codepoints to a font discovery descriptor.
pub struct CodepointMapEntry {
pub mut:
	// Unicode codepoint range. range[0] <= range[1] must hold.
	range [2]u32

	// The discovery descriptor of the font to use for this range.
	descriptor Descriptor
}

// CodepointMap maps codepoint ranges to font discovery descriptors.
//
// The list of entries uses a simple array. We just do a linear search
// because we expect to always have very few entries, so the overhead
// of a binary search is not worth it. This is possible to defeat with
// some pathological inputs, but there is no realistic scenario where
// this will be a problem except people trying to mess around.
//
// For conflicting codepoints, entries added later take priority over
// entries added earlier (the list is searched in reverse order).
pub struct CodepointMap {
pub mut:
	// The list of entries. We keep ranges and descriptors in the same
	// struct for simplicity. In the Zig version, a MultiArrayList is used
	// to pack ranges together for cache friendliness, but since we expect
	// very few entries this isn't critical.
	entries []CodepointMapEntry
}

// deinit releases the memory used by the CodepointMap.
pub fn (mut self CodepointMap) deinit() {
	self.entries = []
}

// clone creates a deep copy of the CodepointMap.
pub fn (self &CodepointMap) clone() CodepointMap {
	mut new_entries := []CodepointMapEntry{cap: self.entries.len}
	for entry in self.entries {
		new_entries << CodepointMapEntry{
			range:      entry.range
			descriptor: entry.descriptor.clone()
		}
	}
	return CodepointMap{
		entries: new_entries
	}
}

// add appends an entry to the map.
//
// For conflicting codepoints, entries added later take priority over
// entries added earlier.
pub fn (mut self CodepointMap) add(entry CodepointMapEntry) {
	assert entry.range[0] <= entry.range[1]
	self.entries << entry
}

// get returns the descriptor for a codepoint, or none if no entry
// matches. Entries added later take priority (searched in reverse).
pub fn (self &CodepointMap) get(cp u32) ?Descriptor {
	// Search in reverse order so that later entries take priority.
	for forward_i in 0 .. self.entries.len {
		i := self.entries.len - forward_i - 1
		range := self.entries[i].range
		if range[0] <= cp && cp <= range[1] {
			return self.entries[i].descriptor
		}
	}
	return none
}

// hashcode returns a hash code that can be used to uniquely identify
// this CodepointMap.
pub fn (self &CodepointMap) hashcode() u64 {
	// Hash with a simple multiplicative hash, feeding in length,
	// ranges, and descriptor hashes.
	mut state := u64(0)
	state = state * 31 + u64(self.entries.len)
	for entry in self.entries {
		state = state * 31 + u64(entry.range[0])
		state = state * 31 + u64(entry.range[1])
		state = state * 31 + entry.descriptor.hashcode()
	}
	return state
}
