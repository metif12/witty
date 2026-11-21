module terminal

import lib_allocator
import buildcfg

// Source terminal/ref_counted_set.zig's type factory. Item/ID/refcount/context
// types remain independent, with caller-owned storage and true-base offsets.
pub struct GenericRefSetItemMeta[I, R] {
pub mut:
	bucket    I
	psl       I
	ref_count R
}

pub struct GenericRefSetItem[T, I, R] {
pub mut:
	value T
	meta  GenericRefSetItemMeta[I, R]
}

pub struct GenericRefSetLayout[I] {
pub:
	cap         usize
	table_cap   usize
	table_mask  I
	table_start usize
	items_start usize
	total_size  usize
}

pub fn generic_ref_set_layout[T, I, R](capacity usize) GenericRefSetLayout[I] {
	assert capacity <= usize(I(~u64(0))) + 1
	if capacity == 0 { return GenericRefSetLayout[I]{} }
	table_capacity := rcs_ceil_power_of_two(capacity)
	item_capacity := table_capacity * 13 / 16
	start := rcs_align_forward(table_capacity * sizeof(I),
		usize(1) << lib_allocator.alignment_log[GenericRefSetItem[T, I, R]]())
	return GenericRefSetLayout[I]{
		cap:         item_capacity
		table_cap:   table_capacity
		table_mask:  I(table_capacity - 1)
		items_start: start
		total_size:  start + item_capacity * sizeof(GenericRefSetItem[T, I, R])
	}
}

pub struct GenericRefCountedSet[T, I, R, X] {
pub mut:
	table_offset Offset
	items_offset Offset
	max_psl      I
	psl_stats    [32]I
	living       usize
	next_id      I
	layout       GenericRefSetLayout[I]
	context      X
}

pub fn generic_ref_set_init[T, I, R, X](buf OffsetBuf, layout GenericRefSetLayout[I], context X) GenericRefCountedSet[T, I, R, X] {
	mut self := GenericRefCountedSet[T, I, R, X]{
		table_offset: buf.member(layout.table_start)
		items_offset: buf.member(layout.items_start)
		next_id:      I(1)
		layout:       layout
		context:      context
	}
	mut buckets := self.table_view(buf.base)
	for i in 0 .. buckets.len {
		buckets[i] = I(0)
	}
	mut items := self.items_view(buf.base)
	for i in 0 .. items.len {
		items[i] = GenericRefSetItem[T, I, R]{
			meta: GenericRefSetItemMeta[I, R]{
				bucket: I(~u64(0))
			}
		}
	}
	return self
}

fn (self &GenericRefCountedSet[T, I, R, X]) table_view(base &u8) []I {
	return lib_allocator.borrowed_array[I](self.table_offset.ptr(base), int(self.layout.table_cap),
		int(self.layout.table_cap))
}

fn (self &GenericRefCountedSet[T, I, R, X]) items_view(base &u8) []GenericRefSetItem[T, I, R] {
	return lib_allocator.borrowed_array[GenericRefSetItem[T, I, R]](self.items_offset.ptr(base),
		int(self.layout.cap), int(self.layout.cap))
}

fn (mut self GenericRefCountedSet[T, I, R, X]) deleted_value(value T) {
	$for method in X.methods {
		$if method.name == 'deleted' { self.context.deleted(value) }
	}
}

fn ref_set_add_checked[R](value R, amount R) R {
	if buildcfg.runtime_safety && value > R(~u64(0)) - amount {
		panic('integer overflow')
	}
	return value + amount
}

// Add an item to the set if not present and increment its ref count.
//
// Returns the item's ID.
//
// If the set has no more room, then an error is returned.
pub fn (mut self GenericRefCountedSet[T, I, R, X]) add(base &u8, value T) !I {
	saved_context := self.context
	defer { self.context = saved_context }
	mut items := self.items_view(base)
	// Trim dead items from the end of the list.
	for self.next_id > 1 && items[self.next_id - 1].meta.ref_count == 0 {
		self.next_id -= 1
		self.delete_item(base, self.next_id)
	}

	// If the item already exists, return it.
	if found := self.lookup(base, value) {
		// V 0.5.2 master keeps the generic ?I type on the unwrapped value.
		id := I(found)
		self.deleted_value(value)
		items[id].meta.ref_count = ref_set_add_checked(items[id].meta.ref_count, R(1))
		return id
	}

	// While it should be statistically impossible to exceed the
	// bounds of psl_stats, the hash function is not perfect and
	// in such a case we want to remain stable.
	if self.psl_stats[31] > 0 {
		return error('out of memory: psl_stats overflow')
	}

	// If the item doesn't exist, we need an available ID.
	if self.next_id >= I(self.layout.cap) {
		// Arbitrarily chosen, threshold for rehashing.
		// If less than 90% of currently allocated IDs
		// correspond to living items, we should rehash.
		rehash_threshold := 0.9
		if self.living < usize(f64(self.layout.cap) * rehash_threshold) {
			return error('needs rehash')
		}
		return error('out of memory')
	}

	id := self.insert(base, value, self.next_id)
	items[id].meta.ref_count = ref_set_add_checked(items[id].meta.ref_count, R(1))
	assert items[id].meta.ref_count == 1
	self.living += 1

	// It's possible insert returns a different ID by reusing a
	// dead item so we only need to update next id if we used it.
	if id == self.next_id {
		self.next_id += 1
	}

	return id
}

// GenericAddWithIdResult[I] is V's explicit representation of Zig's optional ID return.
pub struct GenericAddWithIdResult[I] {
pub:
	used_requested bool
	id             I
}

// Add an item and, when possible, reuse the caller-provided ID.
pub fn (mut self GenericRefCountedSet[T, I, R, X]) add_with_id(base &u8, value T, id I) !GenericAddWithIdResult[I] {
	saved_context := self.context
	defer { self.context = saved_context }
	mut items := self.items_view(base)
	assert id > 0, 'ID must be > 0'

	if id < self.next_id {
		if items[id].meta.ref_count == 0 {
			if self.psl_stats[31] > 0 {
				return error('out of memory: psl_stats overflow')
			}

			self.delete_item(base, id)
			added_id := self.upsert(base, value, id)
			items[added_id].meta.ref_count =
				ref_set_add_checked(items[added_id].meta.ref_count, R(1))
			self.living += 1
			if added_id == id {
				return GenericAddWithIdResult[I]{
					used_requested: true
					id:             id
				}
			}
			return GenericAddWithIdResult[I]{
				id: added_id
			}
		}

		if self.context.eql(value, items[id].value) {
			self.deleted_value(value)
			items[id].meta.ref_count = ref_set_add_checked(items[id].meta.ref_count, R(1))
			return GenericAddWithIdResult[I]{
				used_requested: true
				id:             id
			}
		}
	}

	return GenericAddWithIdResult[I]{
		id: self.add(base, value)!
	}
}

// Increment an item's reference count by 1.
pub fn (mut self GenericRefCountedSet[T, I, R, X]) use_item(base &u8, id I) {
	mut items := self.items_view(base)
	assert id > 0, 'ID must be > 0'
	assert id < I(self.layout.cap), 'ID out of bounds'
	assert items[id].meta.ref_count > 0, 'use called on item with 0 refs'
	items[id].meta.ref_count = ref_set_add_checked(items[id].meta.ref_count, R(1))
}

// Increment an item's reference count by a specified number.
pub fn (mut self GenericRefCountedSet[T, I, R, X]) use_multiple(base &u8, id I, n R) {
	mut items := self.items_view(base)
	assert id > 0, 'ID must be > 0'
	assert id < I(self.layout.cap), 'ID out of bounds'
	assert items[id].meta.ref_count > 0, 'use_multiple called on item with 0 refs'
	items[id].meta.ref_count = ref_set_add_checked(items[id].meta.ref_count, R(n))
}

// Get an item by its ID without incrementing its reference count.
pub fn (self &GenericRefCountedSet[T, I, R, X]) get(base &u8, id I) &T {
	mut items := self.items_view(base)
	assert id > 0, 'ID must be > 0'
	assert id < I(self.layout.cap), 'ID out of bounds'
	assert items[id].meta.ref_count > 0, 'get called on item with 0 refs'
	return &items[id].value
}

// Releases a reference to an item by its ID.
pub fn (mut self GenericRefCountedSet[T, I, R, X]) release(base &u8, id I) {
	mut items := self.items_view(base)
	assert id > 0, 'ID must be > 0'
	assert id < I(self.layout.cap), 'ID out of bounds'
	assert items[id].meta.ref_count > 0, 'release called on item with 0 refs'
	items[id].meta.ref_count -= 1
	if items[id].meta.ref_count == 0 {
		self.living -= 1
	}
}

// Release a specified number of references to an item by its ID.
pub fn (mut self GenericRefCountedSet[T, I, R, X]) release_multiple(base &u8, id I, n I) {
	mut items := self.items_view(base)
	assert id > 0, 'ID must be > 0'
	assert id < I(self.layout.cap), 'ID out of bounds'
	assert items[id].meta.ref_count >= n, 'release_multiple: not enough refs'
	items[id].meta.ref_count -= n
	if items[id].meta.ref_count == 0 {
		self.living -= 1
	}
}

// Get the ref count for an item by its ID.
pub fn (self &GenericRefCountedSet[T, I, R, X]) ref_count(base &u8, id I) R {
	mut items := self.items_view(base)
	assert id > 0, 'ID must be > 0'
	assert id < I(self.layout.cap), 'ID out of bounds'
	return items[id].meta.ref_count
}

// Get the current number of non-dead items in the set.
pub fn (self &GenericRefCountedSet[T, I, R, X]) count() usize {
	return self.living
}

// Find an item in the buckets and return its ID.
// If the item does not exist in the buckets, none is returned.
pub fn (self &GenericRefCountedSet[T, I, R, X]) lookup(base &u8, value T) ?I {
	mut items := self.items_view(base)
	mut buckets := self.table_view(base)
	// A zero-capacity set is valid. Zig's offset-backed empty buckets aliases
	// zeroed page memory, while V represents it as a genuinely empty slice.
	// Either representation must report that no value is present.
	if self.layout.table_cap == 0 {
		return none
	}
	hash := self.context.hash(value)

	for i in 0 .. int(self.max_psl) + 1 {
		p := int((hash + u64(i)) & u64(self.layout.table_mask))
		id := buckets[p]

		// Empty bucket, our item cannot have probed to
		// any point after this, meaning it's not present.
		if id == 0 {
			return none
		}

		item := items[id]

		// An item with a shorter probe sequence length would never
		// end up in the middle of another sequence, since it would
		// be swapped out if inserted before the new sequence, and
		// would not be swapped in if inserted afterwards.
		//
		// As such, our item cannot be present.
		if item.meta.psl < I(i) {
			return none
		}

		// If the item is a part of the same probe sequence,
		// we make sure it's not dead and then check to see
		// if it matches the value we're looking for.
		if item.meta.psl == I(i) && item.meta.ref_count > 0 && self.context.eql(value, item.value) {
			return id
		}
	}

	return none
}

// ============================================================
// Internal methods
// ============================================================

// Delete an item, removing any references from the buckets,
// and freeing its ID to be reused.
fn (mut self GenericRefCountedSet[T, I, R, X]) delete_item(base &u8, id I) {
	mut items := self.items_view(base)
	mut buckets := self.table_view(base)
	item := items[id]

	if usize(item.meta.bucket) > self.layout.table_cap {
		return
	}
	assert buckets[item.meta.bucket] == id

	self.deleted_value(item.value)
	self.psl_stats[item.meta.psl] -= 1
	buckets[item.meta.bucket] = 0
	items[id] = GenericRefSetItem[T, I, R]{
		meta: GenericRefSetItemMeta[I, R]{
			bucket: I(~u64(0))
		}
	}

	// Backward shift deletion: shift items back to fill the gap
	mut p := int(item.meta.bucket)
	mut n := (p + 1) & int(self.layout.table_mask)

	for buckets[n] != 0 && items[buckets[n]].meta.psl > 0 {
		nid := buckets[n]
		items[nid].meta.bucket = I(p)
		self.psl_stats[items[nid].meta.psl] -= 1
		items[nid].meta.psl -= 1
		self.psl_stats[items[nid].meta.psl] += 1
		buckets[p] = buckets[n]
		p = n
		n = (p + 1) & int(self.layout.table_mask)
	}

	for self.max_psl > 0 && self.psl_stats[self.max_psl] == 0 {
		self.max_psl -= 1
	}

	buckets[p] = 0
}

// Find a value in the buckets or insert it using new_id.
fn (mut self GenericRefCountedSet[T, I, R, X]) upsert(base &u8, value T, new_id I) I {
	if id := self.lookup(base, value) {
		self.deleted_value(value)
		return id
	}
	return self.insert(base, value, new_id)
}

// Insert the given value into the hash buckets with the given ID.
fn (mut self GenericRefCountedSet[T, I, R, X]) insert(base &u8, value T, new_id I) I {
	mut items := self.items_view(base)
	mut buckets := self.table_view(base)
	$if !prod {
		assert self.lookup(base, value) == none
	}

	hash := self.context.hash(value)

	mut held_id := new_id
	mut held_psl := I(0)
	mut held_ref := R(0)
	mut chosen_id := new_id

	// We'll track the bucket where the new item ends up.
	mut new_bucket := I(0)
	mut new_psl := I(0)

	for i in 0 .. int(self.layout.table_cap) - 1 {
		p := I((hash + u64(i)) & u64(self.layout.table_mask))
		id := buckets[p]

		// Empty bucket, put our held item in to it and break.
		if id == 0 {
			buckets[p] = held_id
			if held_id == new_id {
				new_bucket = p
				new_psl = held_psl
			} else {
				items[held_id].meta.bucket = p
				items[held_id].meta.psl = held_psl
			}
			self.psl_stats[held_psl] += 1
			if held_psl > self.max_psl {
				self.max_psl = held_psl
			}
			break
		}

		item_ref := items[id].meta.ref_count
		item_psl := items[id].meta.psl

		// If there's a dead item then we resurrect it
		// for our value so that we can reuse its ID,
		// unless its ID is greater than the one we're
		// given (i.e. prefer smaller IDs).
		if item_ref == 0 {
			// Reap the dead item.
			self.deleted_value(items[id].value)
			self.psl_stats[item_psl] -= 1
			items[id] = GenericRefSetItem[T, I, R]{
				meta: GenericRefSetItemMeta[I, R]{
					bucket: I(~u64(0))
				}
			}

			// Only resurrect this item if it has a
			// smaller id than the one we were given.
			if id < new_id {
				chosen_id = id
			}

			// Put the currently held item in to the
			// bucket of the item that we just reaped.
			buckets[p] = held_id
			if held_id == new_id {
				new_bucket = p
				new_psl = held_psl
			} else {
				items[held_id].meta.bucket = p
				items[held_id].meta.psl = held_psl
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
		if item_psl < held_psl || (item_psl == held_psl && item_ref < held_ref) {
			// Put our held item in the bucket.
			buckets[p] = held_id
			if held_id == new_id {
				new_bucket = p
				new_psl = held_psl
			} else {
				items[held_id].meta.bucket = p
				items[held_id].meta.psl = held_psl
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
	buckets[new_bucket] = chosen_id

	// Finally place our new item in to our array.
	items[chosen_id] = GenericRefSetItem[T, I, R]{
		value: value
		meta:  GenericRefSetItemMeta[I, R]{
			bucket:    new_bucket
			psl:       new_psl
			ref_count: 0
		}
	}

	return chosen_id
}

// Explicit-context variants retain the source context-by-value contract.
pub fn (mut self GenericRefCountedSet[T, I, R, X]) add_context(base &u8, value T, context X) !I {
	saved := self.context
	self.context = context
	defer { self.context = saved }
	return self.add(base, value)!
}

pub fn (mut self GenericRefCountedSet[T, I, R, X]) add_with_id_context(base &u8, value T, id I, context X) !GenericAddWithIdResult[I] {
	saved := self.context
	self.context = context
	defer { self.context = saved }
	return self.add_with_id(base, value, id)!
}

pub fn (self &GenericRefCountedSet[T, I, R, X]) lookup_context(base &u8, value T, context X) ?I {
	mut view := *self
	view.context = context
	return view.lookup(base, value)
}
