module terminal

// A reference counted set.
//
// Source: ref_counted_set.zig (714 lines)
//
// This set is created with some capacity in mind. You can determine
// the exact memory requirement of a given capacity by calling `layout`
// and checking the total size.
//
// When the set exceeds capacity, an error is returned from any
// memory-using methods. The caller is responsible for determining
// a path forward.
//
// This set is reference counted. Each item in the set has an associated
// reference count. The caller is responsible for calling release for an
// item when it is no longer being used. Items with 0 references will be
// kept until another item is written to their bucket. This allows items
// to be resurrected if they are re-added before they get overwritten.
//
// The backing data structure of this set is an open addressed hash table
// with linear probing and Robin Hood hashing, and a flat array of items.
//
// The table maps values to item IDs, which are indices in the item array
// which contain the item's value and its reference count. Item IDs can be
// used to efficiently access an item and update its reference count after
// it has been added to the table, to avoid having to use the hash map to
// look the value back up.
//
// ID 0 is reserved and will never be assigned.
//
// In Zig, this is a comptime-generic type parameterized by:
//   T          - the value type
//   IdT        - the ID integer type (typically u16)
//   RefCountInt - the reference count integer type
//   ContextT   - a context type providing hash/eql/deleted methods
//
// In V, we provide a concrete implementation for CellStyle (the primary
// use case in the terminal) and stub interfaces for generalization.
// XTODO: Full generics, offset-based addressing, page memory integration.

// ============================================================
// RefCountedSetError - possible errors from set operations
// ============================================================

// RefCountedSetError represents errors that can occur during set operations.
pub enum RefCountedSetError {
	// There is not enough memory to add a new item.
	// Remove items or grow and reinitialize.
	out_of_memory
	// The set needs to be rehashed, as there are many dead
	// items with lower IDs which are inaccessible for reuse.
	needs_rehash
}

// ============================================================
// RefCountedSetItem - an item in the set with metadata
// ============================================================

// RefCountedSetItemMeta holds metadata for a set item.
pub struct RefCountedSetItemMeta {
pub mut:
	// The bucket in the hash table where this item is referenced.
	bucket u16 = 65535
	// The length of the probe sequence between this item's starting
	// bucket and the bucket it's in, used for Robin Hood hashing.
	psl u16
	// The reference count for this item.
	ref_count u16
}

// RefCountedSetItem is a set item containing a value and its metadata.
// Parameterized by the value type T. In this concrete implementation
// we use CellStyle as the value type.
pub struct RefCountedSetItem {
pub mut:
	// The value this item represents.
	value CellStyle
	// Metadata for this item.
	meta RefCountedSetItemMeta
}

// ============================================================
// RefCountedSetLayout - memory layout for the set
// ============================================================

// RefCountedSetLayout describes the memory layout of a RefCountedSet
// for a given capacity. The layout can be used by the caller to
// determine how much memory to allocate.
//
// The capacity passed for cap will be used for the hash table,
// which has a load factor of 0.8125 (13/16), so the number of
// items which can actually be stored in the set will be smaller.
//
// The laid out capacity will be at least cap, but may be higher,
// since it is rounded up to the next power of 2 for efficiency.
//
// The returned layout cap property will be 1 more than the number
// of items that the set can actually store, since ID 0 is reserved.
pub struct RefCountedSetLayout {
pub:
	// The number of items that can be stored (including reserved ID 0).
	cap int
	// The capacity of the hash table (power of 2).
	table_cap int
	// Bitmask for fast modulo on the table (table_cap - 1).
	table_mask u16
	// Byte offset of the hash table from the base.
	table_start int
	// Byte offset of the items array from the base.
	items_start int
	// Total size in bytes needed for the set.
	total_size int
}

// This is the max load until the set returns out_of_memory and
// requires more capacity.
//
// Experimentally, this load factor works quite well.
pub const rcs_load_factor = 0.8125

// Returns the minimum capacity needed to store n items,
// accounting for the load factor and the reserved ID 0.
pub fn rcs_capacity_for_count(n int) int {
	if n == 0 {
		return 0
	}
	// +1 because ID 0 is reserved, so we need at least n+1 slots.
	return int(f64(n + 1) / rcs_load_factor + 0.999999)
}

// Returns the memory layout for a desired capacity.
// The capacity is rounded up to the next power of 2.
pub fn RefCountedSetLayout.init(cap int) RefCountedSetLayout {
	// Zero-cap set is valid, return special case
	if cap == 0 {
		return RefCountedSetLayout{}
	}

	// Round up to next power of 2
	table_cap := rcs_ceil_power_of_two(cap)
	items_cap := int(rcs_load_factor * f64(table_cap))

	table_mask := u16(table_cap - 1)

	table_start := 0
	table_end := table_start + table_cap * 2 // sizeof(u16) = 2

	// Align items_start to alignment of RefCountedSetItem
	items_start := rcs_align_forward(table_end, 8) // 8-byte alignment
	items_end := items_start + items_cap * int(sizeof(RefCountedSetItem))

	total_size := items_end

	return RefCountedSetLayout{
		cap: items_cap
		table_cap: table_cap
		table_mask: table_mask
		table_start: table_start
		items_start: items_start
		total_size: total_size
	}
}

// ============================================================
// RefCountedSet - the main set structure
// ============================================================

// RefCountedSet is a reference-counted set for CellStyle values.
// It uses an open-addressed hash table with Robin Hood hashing
// and a flat array of items.
//
// XTODO: In Ghostty, this uses offset-based addressing within
// page memory. This V implementation uses heap-allocated arrays
// instead. Full page-memory integration requires the offset-based
// approach from size.zig.
pub struct RefCountedSet {
pub mut:
	// The hash table mapping hash buckets to item IDs.
	hash_table []u16
	// The backing store of items.
	items []RefCountedSetItem
	// By keeping track of the max probe sequence length
	// we can bail out early when looking up values that
	// aren't present.
	max_psl u16
	// We keep track of how many items have a PSL of any
	// given length, so that we can shrink max_psl when
	// we delete items.
	//
	// A probe sequence of length 32 or more is astronomically
	// unlikely. Roughly a (1/table_cap)^32 -- with any normal
	// table capacity that is so unlikely that it's not worth
	// handling.
	//
	// However, that assumes a uniform hash function, which
	// is not guaranteed and can be subverted with a crafted
	// input. We handle this gracefully by returning an error
	// anywhere where we're about to insert if there's any
	// item with a PSL in the last slot of the stats array.
	psl_stats [32]u16
	// The number of living items currently stored in the set.
	living int
	// The next index to store an item at.
	// Id 0 is reserved for unused items.
	next_id u16 = 1
	// The layout of this set.
	layout RefCountedSetLayout
}

// init creates a new RefCountedSet with the given layout.
pub fn RefCountedSet.init(l RefCountedSetLayout) RefCountedSet {
	mut hash_table := []u16{len: l.table_cap}
	mut items := []RefCountedSetItem{len: l.cap}
	return RefCountedSet{
		hash_table: hash_table
		items: items
		layout: l
	}
}

// Add an item to the set if not present and increment its ref count.
//
// Returns the item's ID.
//
// If the set has no more room, then an error is returned.
// XTODO: Full Robin Hood hashing with dead-item resurrection.
// This is a simplified implementation.
pub fn (mut self RefCountedSet) add(value CellStyle) !u16 {
	// Trim dead items from the end of the list.
	for self.next_id > 1 && self.items[self.next_id - 1].meta.ref_count == 0 {
		self.next_id -= 1
		self.delete_item(self.next_id)
	}

	// If the item already exists, return it.
	if id := self.lookup(value) {
		self.items[id].meta.ref_count += 1
		return id
	}

	// While it should be statistically impossible to exceed the
	// bounds of psl_stats, the hash function is not perfect and
	// in such a case we want to remain stable.
	if self.psl_stats[31] > 0 {
		return error('out of memory: psl_stats overflow')
	}

	// If the item doesn't exist, we need an available ID.
	if self.next_id >= u16(self.layout.cap) {
		// Arbitrarily chosen, threshold for rehashing.
		// If less than 90% of currently allocated IDs
		// correspond to living items, we should rehash.
		rehash_threshold := 0.9
		if self.living < int(f64(self.layout.cap) * rehash_threshold) {
			return error('needs rehash')
		}
		return error('out of memory')
	}

	id := self.insert(value, self.next_id)
	self.items[id].meta.ref_count += 1
	self.living += 1

	// It's possible insert returns a different ID by reusing a
	// dead item so we only need to update next id if we used it.
	if id == self.next_id {
		self.next_id += 1
	}

	return id
}

// Increment an item's reference count by 1.
pub fn (mut self RefCountedSet) use_item(id u16) {
	assert id > 0, 'ID must be > 0'
	assert id < u16(self.layout.cap), 'ID out of bounds'
	assert self.items[id].meta.ref_count > 0, 'use called on item with 0 refs'
	self.items[id].meta.ref_count += 1
}

// Increment an item's reference count by a specified number.
pub fn (mut self RefCountedSet) use_multiple(id u16, n u16) {
	assert id > 0, 'ID must be > 0'
	assert id < u16(self.layout.cap), 'ID out of bounds'
	assert self.items[id].meta.ref_count > 0, 'use_multiple called on item with 0 refs'
	self.items[id].meta.ref_count += n
}

// Get an item by its ID without incrementing its reference count.
pub fn (self &RefCountedSet) get(id u16) &CellStyle {
	assert id > 0, 'ID must be > 0'
	assert id < u16(self.layout.cap), 'ID out of bounds'
	assert self.items[id].meta.ref_count > 0, 'get called on item with 0 refs'
	return &self.items[id].value
}

// Releases a reference to an item by its ID.
pub fn (mut self RefCountedSet) release(id u16) {
	assert id > 0, 'ID must be > 0'
	assert id < u16(self.layout.cap), 'ID out of bounds'
	assert self.items[id].meta.ref_count > 0, 'release called on item with 0 refs'
	self.items[id].meta.ref_count -= 1
	if self.items[id].meta.ref_count == 0 {
		self.living -= 1
	}
}

// Release a specified number of references to an item by its ID.
pub fn (mut self RefCountedSet) release_multiple(id u16, n u16) {
	assert id > 0, 'ID must be > 0'
	assert id < u16(self.layout.cap), 'ID out of bounds'
	assert self.items[id].meta.ref_count >= n, 'release_multiple: not enough refs'
	self.items[id].meta.ref_count -= n
	if self.items[id].meta.ref_count == 0 {
		self.living -= 1
	}
}

// Get the ref count for an item by its ID.
pub fn (self &RefCountedSet) ref_count(id u16) u16 {
	assert id > 0, 'ID must be > 0'
	assert id < u16(self.layout.cap), 'ID out of bounds'
	return self.items[id].meta.ref_count
}

// Get the current number of non-dead items in the set.
pub fn (self &RefCountedSet) count() int {
	return self.living
}

// Find an item in the table and return its ID.
// If the item does not exist in the table, none is returned.
pub fn (self &RefCountedSet) lookup(value CellStyle) ?u16 {
	hash := rcs_hash_style(value)

	for i in 0 .. int(self.max_psl) + 1 {
		p := int((hash + u64(i)) & u64(self.layout.table_mask))
		id := self.hash_table[p]

		// Empty bucket, our item cannot have probed to
		// any point after this, meaning it's not present.
		if id == 0 {
			return none
		}

		item := self.items[id]

		// An item with a shorter probe sequence length would never
		// end up in the middle of another sequence, since it would
		// be swapped out if inserted before the new sequence, and
		// would not be swapped in if inserted afterwards.
		//
		// As such, our item cannot be present.
		if item.meta.psl < u16(i) {
			return none
		}

		// If the item is a part of the same probe sequence,
		// we make sure it's not dead and then check to see
		// if it matches the value we're looking for.
		if item.meta.psl == u16(i) && item.meta.ref_count > 0
			&& item.value.eql(&value) {
			return id
		}
	}

	return none
}

// ============================================================
// Internal methods
// ============================================================

// Delete an item, removing any references from the table,
// and freeing its ID to be reused.
fn (mut self RefCountedSet) delete_item(id u16) {
	item := self.items[id]

	if item.meta.bucket >= u16(self.layout.table_cap) {
		return
	}

	self.psl_stats[item.meta.psl] -= 1
	self.hash_table[item.meta.bucket] = 0
	self.items[id] = RefCountedSetItem{}

	// Backward shift deletion: shift items back to fill the gap
	mut p := int(item.meta.bucket)
	mut n := (p + 1) & int(self.layout.table_mask)

	for self.hash_table[n] != 0 && self.items[self.hash_table[n]].meta.psl > 0 {
		nid := self.hash_table[n]
		self.items[nid].meta.bucket = u16(p)
		self.psl_stats[self.items[nid].meta.psl] -= 1
		self.items[nid].meta.psl -= 1
		self.psl_stats[self.items[nid].meta.psl] += 1
		self.hash_table[p] = self.hash_table[n]
		p = n
		n = (p + 1) & int(self.layout.table_mask)
	}

	for self.max_psl > 0 && self.psl_stats[self.max_psl] == 0 {
		self.max_psl -= 1
	}

	self.hash_table[p] = 0
}

// Insert the given value into the hash table with the given ID.
fn (mut self RefCountedSet) insert(value CellStyle, new_id u16) u16 {
	hash := rcs_hash_style(value)

	mut held_id := new_id
	mut held_psl := u16(0)
	mut held_ref := u16(0)
	mut chosen_id := new_id

	// We'll track the bucket where the new item ends up.
	mut new_bucket := u16(0)
	mut new_psl := u16(0)

	for i in 0 .. self.layout.table_cap - 1 {
		p := u16((hash + u64(i)) & u64(self.layout.table_mask))
		id := self.hash_table[p]

		// Empty bucket, put our held item in to it and break.
		if id == 0 {
			self.hash_table[p] = held_id
			if held_id == new_id {
				new_bucket = p
				new_psl = held_psl
			} else {
				self.items[held_id].meta.bucket = p
			}
			self.psl_stats[held_psl] += 1
			if held_psl > self.max_psl {
				self.max_psl = held_psl
			}
			break
		}

		item_ref := self.items[id].meta.ref_count
		item_psl := self.items[id].meta.psl

		// If there's a dead item then we resurrect it
		// for our value so that we can reuse its ID,
		// unless its ID is greater than the one we're
		// given (i.e. prefer smaller IDs).
		if item_ref == 0 {
			// Reap the dead item.
			self.psl_stats[item_psl] -= 1
			self.items[id] = RefCountedSetItem{}

			// Only resurrect this item if it has a
			// smaller id than the one we were given.
			if id < new_id {
				chosen_id = id
			}

			// Put the currently held item in to the
			// bucket of the item that we just reaped.
			self.hash_table[p] = held_id
			if held_id == new_id {
				new_bucket = p
				new_psl = held_psl
			} else {
				self.items[held_id].meta.bucket = p
			}
			self.psl_stats[held_psl] += 1
			if held_psl > self.max_psl {
				self.max_psl = held_psl
			}
			break
		}

		// If this item has a lower PSL, or has equal PSL and lower ref
		// count, then we swap it out with our held item. By doing this,
		// items with high reference counts are prioritized for earlier
		// placement.
		if item_psl < held_psl
			|| (item_psl == held_psl && item_ref < held_ref) {
			// Put our held item in the bucket.
			self.hash_table[p] = held_id
			if held_id == new_id {
				new_bucket = p
				new_psl = held_psl
			} else {
				self.items[held_id].meta.bucket = p
			}
			self.psl_stats[held_psl] += 1
			if held_psl > self.max_psl {
				self.max_psl = held_psl
			}

			// Pick up the item that has a lower PSL.
			held_id = id
			held_ref = item_ref
			self.psl_stats[item_psl] -= 1
			held_psl = item_psl
		}

		// Advance to the next probe position for our held item.
		held_psl += 1
	}

	// Our chosen ID may have changed if we decided
	// to reuse a dead item's ID, so we make sure
	// the chosen bucket contains the correct ID.
	self.hash_table[new_bucket] = chosen_id

	// Finally place our new item in to our array.
	self.items[chosen_id] = RefCountedSetItem{
		value: value
		meta: RefCountedSetItemMeta{
			bucket: new_bucket
			psl: new_psl
			ref_count: 0
		}
	}

	return chosen_id
}

// ============================================================
// Helper functions
// ============================================================

// rcs_hash_style computes a hash for a CellStyle value.
// XTODO: Use a proper hash function matching Ghostty's.
// For now we use a simple FNV-1a-like hash over the style fields.
fn rcs_hash_style(s CellStyle) u64 {
	mut h := u64(14695981039346656037)
	// Hash the flags
	h = rcs_fnv_mix(h, if s.flags.bold { u64(1) } else { u64(0) })
	h = rcs_fnv_mix(h, if s.flags.italic { u64(1) } else { u64(0) })
	h = rcs_fnv_mix(h, u64(s.flags.underline))
	h = rcs_fnv_mix(h, if s.flags.strikethrough { u64(1) } else { u64(0) })
	h = rcs_fnv_mix(h, if s.flags.overline { u64(1) } else { u64(0) })
	h = rcs_fnv_mix(h, if s.flags.inverse { u64(1) } else { u64(0) })
	h = rcs_fnv_mix(h, if s.flags.invisible { u64(1) } else { u64(0) })
	h = rcs_fnv_mix(h, if s.flags.faint { u64(1) } else { u64(0) })
	h = rcs_fnv_mix(h, if s.flags.blink { u64(1) } else { u64(0) })
	// Hash the colors: type discriminant + color data
	h = rcs_fnv_mix(h, rcs_hash_cell_color(s.fg_color, s.fg_r, s.fg_g, s.fg_b, s.fg_palette))
	h = rcs_fnv_mix(h, rcs_hash_cell_color(s.bg_color, s.bg_r, s.bg_g, s.bg_b, s.bg_palette))
	h = rcs_fnv_mix(h, u64(s.underline_color))
	return h
}

// rcs_hash_cell_color computes a hash for a cell color (ColorType + components).
fn rcs_hash_cell_color(ct ColorType, r u8, g u8, b u8, palette u8) u64 {
	return match ct {
		.none { u64(0) }
		.palette { u64(palette) + 256 }
		.rgb { u64(r) << 16 | u64(g) << 8 | u64(b) | u64(0x10000000) }
	}
}

// rcs_fnv_mix performs one round of FNV-1a mixing.
fn rcs_fnv_mix(h u64, val u64) u64 {
	return (h ^ val) * u64(1099511628211)
}

// rcs_ceil_power_of_two rounds up to the next power of 2.
fn rcs_ceil_power_of_two(v int) int {
	if v <= 1 {
		return 1
	}
	mut p := 1
	for p < v {
		p *= 2
	}
	return p
}

// rcs_align_forward aligns a value forward to the given alignment.
fn rcs_align_forward(v int, alignment int) int {
	if alignment == 0 {
		return v
	}
	remainder := v % alignment
	if remainder == 0 {
		return v
	}
	return v + alignment - remainder
}
