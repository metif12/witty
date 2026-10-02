module terminal

import lib_allocator
import internal_hash

pub struct AutoHashContext[K] {}

pub fn (_ AutoHashContext[K]) hash(key K) u64 {
	return internal_hash.wyhash(auto_hash_bytes(key), 0)
}

pub fn (_ AutoHashContext[K]) eql(a K, b K) bool {
	return a == b
}

// std.hash.autoHash visits struct fields individually, excluding padding.
// Slices/strings require an explicit context, just as in the source factory.
fn auto_hash_bytes[K](key K) []u8 {
	$if K is $struct {
		mut bytes := []u8{}
		$for field in K.fields {
			bytes << auto_hash_bytes(key.$(field.name))
		}
		return bytes
	} $else $if K is $int || K is $float || K is $enum || K is bool {
		return unsafe { (&u8(&key)).vbytes(int(sizeof(K))).clone() }
	} $else {
		$compile_error('AutoOffsetHashMap requires an explicit context for pointer/slice/union keys')
		return []u8{}
	}
}

pub fn auto_offset_hash_map_init[K, V](buf OffsetBuf, layout HashMapLayout) GenericOffsetHashMap[K, V, AutoHashContext[K]] {
	return generic_offset_hash_map_init[K, V, AutoHashContext[K]](buf, layout, AutoHashContext[K]{})
}

// Source terminal/hash_map.zig: type-parametric caller-backed map. All
// persistent pointers are offsets; a view can be reconstructed at a new base.
struct OffsetMapHeader {
mut:
	values_offset u32
	keys_offset   u32
	capacity      u32
	size          u32
}

pub struct GenericOffsetHashMap[K, V, X] {
pub:
	metadata_offset Offset
}

pub fn generic_hash_map_align[K, V]() usize {
	return hash_max(usize(4), hash_max(usize(1) << lib_allocator.alignment_log[K](),
		usize(1) << lib_allocator.alignment_log[V]()))
}

pub fn generic_hash_map_layout[K, V](capacity u32) HashMapLayout {
	return layout_for_capacity(capacity, sizeof(K), sizeof(V),
		usize(1) << lib_allocator.alignment_log[K](), usize(1) << lib_allocator.alignment_log[V]())
}

pub fn generic_offset_hash_map_init[K, V, X](buf OffsetBuf, layout HashMapLayout, context X) GenericOffsetHashMap[K, V, X] {
	_ = generic_hash_map_init[K, V, X](buf, layout, context)
	return GenericOffsetHashMap[K, V, X]{
		metadata_offset: buf.member(sizeof(OffsetMapHeader))
	}
}

pub fn (self GenericOffsetHashMap[K, V, X]) map(base &u8, context X) GenericHashMap[K, V, X] {
	return generic_hash_map_view[K, V, X](self.metadata_offset.ptr(base), context)
}

fn generic_hash_map_view[K, V, X](metadata &u8, context X) GenericHashMap[K, V, X] {
	header := unsafe { &OffsetMapHeader(metadata - sizeof(OffsetMapHeader)) }
	return GenericHashMap[K, V, X]{
		header:   header
		metadata: lib_allocator.borrowed_array[HashSlotMetadata](metadata, int(header.capacity),
			int(header.capacity))
		keys:     lib_allocator.borrowed_array[K](unsafe { metadata + header.keys_offset },
			int(header.capacity), int(header.capacity))
		values:   lib_allocator.borrowed_array[V](unsafe { metadata + header.values_offset },
			int(header.capacity), int(header.capacity))
		context:  context
	}
}

pub struct GenericHashKV[K, V] {
pub:
	key   K
	value V
}

// GenericFetchPutResult[K, V] is the result of a fetch_put operation.
pub struct GenericFetchPutResult[K, V] {
pub:
	had_previous bool
	previous     GenericHashKV[K, V]
}

// GenericGetOrPutResult[K, V] from get_or_put operations. Contains the slot index
// and whether the key already existed. Use map.keys[idx] and
// map.values[idx] to access/modify the entry.
pub struct GenericGetOrPutResult[K, V] {
pub mut:
	idx            usize
	key_ptr        &K = unsafe { nil }
	value_ptr      &V = unsafe { nil }
	found_existing bool
}

// GenericHashMapIterEntry[K, V] is a key-value pair returned by the iterator.
pub struct GenericHashMapIterEntry[K, V] {
pub mut:
	key       K
	value     V
	key_ptr   &K = unsafe { nil }
	value_ptr &V = unsafe { nil }
}

// GenericHashMapIter[K, V] iterates over used entries in a GenericHashMap[K, V, X].
pub struct GenericHashMapIter[K, V] {
	metadata []HashSlotMetadata
	keys     []K
	values   []V
	cap_     u32
mut:
	index u32
}

// next returns the next used entry, or none if iteration is complete.
pub fn (mut it GenericHashMapIter[K, V]) next() ?GenericHashMapIterEntry[K, V] {
	assert it.index <= it.cap_
	for it.index < it.cap_ {
		idx := it.index
		it.index++
		if it.metadata[idx].is_used() {
			return GenericHashMapIterEntry[K, V]{
				key:       it.keys[idx]
				value:     it.values[idx]
				key_ptr:   &it.keys[idx]
				value_ptr: &it.values[idx]
			}
		}
	}
	return none
}

// GenericHashMapKeyIter[K, V] iterates over the keys in used slots.
pub struct GenericHashMapKeyIter[K, V] {
	metadata []HashSlotMetadata
	keys     []K
mut:
	len   usize
	index usize
}

// next returns the next key, or none if iteration is complete.
pub fn (mut it GenericHashMapKeyIter[K, V]) next() ?&K {
	for it.len > 0 {
		it.len--
		idx := it.index
		it.index++
		if it.metadata[idx].is_used() {
			return &it.keys[idx]
		}
	}
	return none
}

// GenericHashMapValueIter[K, V] iterates over the values in used slots.
pub struct GenericHashMapValueIter[K, V] {
	metadata []HashSlotMetadata
	values   []V
mut:
	len   usize
	index usize
}

// next returns the next value, or none if iteration is complete.
pub fn (mut it GenericHashMapValueIter[K, V]) next() ?&V {
	for it.len > 0 {
		it.len--
		idx := it.index
		it.index++
		if it.metadata[idx].is_used() {
			return &it.values[idx]
		}
	}
	return none
}

// GenericHashMap[K, V, X] is an open-addressing hash map with linear probing
// and 7-bit fingerprint-based collision resolution.
//
// K, V, and X retain the source type/context parameters. All array views
// borrow the contiguous Header/metadata/keys/values buffer; size is stored in
// the buffer's header so independently reconstructed views stay coherent.
pub struct GenericHashMap[K, V, X] {
pub mut:
	metadata []HashSlotMetadata
	keys     []K
	values   []V
	header   &OffsetMapHeader = unsafe { nil }
	context  X
}

// init creates a new hash map with the given capacity.
// Capacity should be a power of two (or zero).
pub fn generic_hash_map_init[K, V, X](buf OffsetBuf, layout HashMapLayout, context X) GenericHashMap[K, V, X] {
	assert usize(buf.start()) % generic_hash_map_align[K, V]() == 0
	metadata := unsafe { buf.start() + sizeof(OffsetMapHeader) }
	mut header := unsafe { &OffsetMapHeader(buf.start()) }
	header.keys_offset = u32(layout.keys_start)
	header.values_offset = u32(layout.vals_start)
	header.capacity = layout.capacity
	header.size = 0
	mut result := generic_hash_map_view[K, V, X](metadata, context)
	result.init_metadatas()
	return result
}

// count returns the number of entries in the map.
pub fn (self &GenericHashMap[K, V, X]) count() u32 {
	return self.header.size
}

// capacity returns the total capacity of the map.
pub fn (self &GenericHashMap[K, V, X]) capacity() u32 {
	return self.header.capacity
}

// put inserts a key-value pair, updating the value if the key exists.
pub fn (mut self GenericHashMap[K, V, X]) put(key K, value V) ! {
	gop := self.get_or_put_internal(key)!
	self.values[gop.idx] = value
}

// put_no_clobber inserts a key-value pair. Asserts the key doesn't exist.
pub fn (mut self GenericHashMap[K, V, X]) put_no_clobber(key K, value V) ! {
	assert !self.contains(key)
	self.grow_if_needed(1)!
	self.put_assume_capacity_no_clobber(key, value)
}

// put_assume_capacity inserts or updates without checking capacity.
pub fn (mut self GenericHashMap[K, V, X]) put_assume_capacity(key K, value V) {
	gop := self.get_or_put_assume_capacity(key)
	self.values[gop.idx] = value
}

// put_assume_capacity_no_clobber inserts without checking capacity.
// The key must not already exist.
pub fn (mut self GenericHashMap[K, V, X]) put_assume_capacity_no_clobber(key K, value V) {
	assert !self.contains(key)
	hash := self.context.hash(key)
	mask := u64(self.header.capacity - 1)
	mut idx := usize(hash & mask)

	for self.metadata[idx].is_used() {
		idx = (idx + 1) & usize(mask)
	}

	fp := take_fingerprint(hash)
	self.metadata[idx].fill(fp)
	self.keys[idx] = key
	self.values[idx] = value
	self.header.size++
}

// get returns a copy of the value for key, or none.
pub fn (self &GenericHashMap[K, V, X]) get(key K) ?V {
	idx := self.get_index(key) or { return none }
	return self.values[idx]
}

// get_key returns a copy of the stored key, or none.
pub fn (self &GenericHashMap[K, V, X]) get_key(key K) ?K {
	idx := self.get_index(key) or { return none }
	return self.keys[idx]
}

// get_key_ptr returns the slot index for the stored key, or none. Slot indices
// are the stable V representation used in place of pointers into backing arrays.
pub fn (self &GenericHashMap[K, V, X]) get_key_ptr(key K) ?&K {
	idx := self.get_index(key) or { return none }
	return &self.keys[idx]
}

// get_key_index returns the slot index for a key, or none.
pub fn (self &GenericHashMap[K, V, X]) get_key_index(key K) ?usize {
	return self.get_index(key)
}

// get_ptr returns the slot index for a key's value, or none.
// Use map.values[idx] to read/write the value.
pub fn (self &GenericHashMap[K, V, X]) get_ptr(key K) ?&V {
	idx := self.get_index(key) or { return none }
	return &self.values[idx]
}

// get_entry returns a copy of the key-value pair, or none.
pub fn (self &GenericHashMap[K, V, X]) get_entry(key K) ?GenericHashMapIterEntry[K, V] {
	idx := self.get_index(key) or { return none }
	return GenericHashMapIterEntry[K, V]{
		key:       self.keys[idx]
		value:     self.values[idx]
		key_ptr:   &self.keys[idx]
		value_ptr: &self.values[idx]
	}
}

// contains returns true if key exists in the map.
pub fn (self &GenericHashMap[K, V, X]) contains(key K) bool {
	if _ := self.get_index(key) {
		return true
	}
	return false
}

// get_or_put finds existing entry or creates a new slot.
// Returns the slot index and whether the key already existed.
pub fn (mut self GenericHashMap[K, V, X]) get_or_put(key K) !GenericGetOrPutResult[K, V] {
	gop := self.get_or_put_internal(key)!
	if !gop.found_existing {
		self.keys[gop.idx] = key
	}
	return gop
}

// get_or_put_value gets existing entry or inserts with the given value.
pub fn (mut self GenericHashMap[K, V, X]) get_or_put_value(key K, value V) !GenericHashMapIterEntry[K, V] {
	gop := self.get_or_put_internal(key)!
	if !gop.found_existing {
		self.keys[gop.idx] = key
		self.values[gop.idx] = value
	}
	return GenericHashMapIterEntry[K, V]{
		key:       self.keys[gop.idx]
		value:     self.values[gop.idx]
		key_ptr:   &self.keys[gop.idx]
		value_ptr: &self.values[gop.idx]
	}
}

// fetch_put inserts/updates and returns the previous entry if it existed.
// V cannot combine ! and ? return types, so we use GenericFetchPutResult[K, V].
pub fn (mut self GenericHashMap[K, V, X]) fetch_put(key K, value V) !GenericFetchPutResult[K, V] {
	gop := self.get_or_put_internal(key)!
	mut result := GenericFetchPutResult[K, V]{}
	if gop.found_existing {
		result = GenericFetchPutResult[K, V]{
			had_previous: true
			previous:     GenericHashKV[K, V]{
				key:   self.keys[gop.idx]
				value: self.values[gop.idx]
			}
		}
	}
	self.values[gop.idx] = value
	return result
}

// fetch_put_assume_capacity is like fetch_put but doesn't check capacity.
pub fn (mut self GenericHashMap[K, V, X]) fetch_put_assume_capacity(key K, value V) ?GenericHashKV[K, V] {
	gop := self.get_or_put_assume_capacity(key)
	if gop.found_existing {
		result := GenericHashKV[K, V]{
			key:   self.keys[gop.idx]
			value: self.values[gop.idx]
		}
		self.values[gop.idx] = value
		return result
	}
	self.values[gop.idx] = value
	return none
}

// fetch_remove removes and returns the entry for key, or none.
pub fn (mut self GenericHashMap[K, V, X]) fetch_remove(key K) ?GenericHashKV[K, V] {
	idx := self.get_index(key) or { return none }
	result := GenericHashKV[K, V]{
		key:   self.keys[idx]
		value: self.values[idx]
	}
	self.remove_by_index(idx)
	return result
}

// remove deletes the entry for key. Returns true if it existed.
pub fn (mut self GenericHashMap[K, V, X]) remove(key K) bool {
	idx := self.get_index(key) or { return false }
	self.remove_by_index(idx)
	return true
}

// remove_by_index removes the entry at the given slot index.
pub fn (mut self GenericHashMap[K, V, X]) remove_by_index(idx usize) {
	self.metadata[idx].mark_removed()
	self.keys[idx] = K{}
	self.values[idx] = V{}
	self.header.size--
}

// remove_by_ptr removes the key at a slot returned by get_key_ptr.
pub fn (mut self GenericHashMap[K, V, X]) remove_by_ptr(key_ptr &K) {
	index := (usize(key_ptr) - usize(self.keys.data)) / sizeof(K)
	assert index < usize(self.header.capacity)
	assert self.metadata[index].is_used()
	self.remove_by_index(index)
}

// clear_retaining_capacity removes all entries but keeps allocated capacity.
pub fn (mut self GenericHashMap[K, V, X]) clear_retaining_capacity() {
	if self.header.capacity > 0 {
		self.init_metadatas()
		self.header.size = 0
	}
}

// ensure_total_capacity checks that the map can hold at least new_size entries.
pub fn (mut self GenericHashMap[K, V, X]) ensure_total_capacity(new_size u32) ! {
	if new_size > self.header.size {
		self.grow_if_needed(new_size - self.header.size)!
	}
}

// ensure_unused_capacity checks that the map has room for additional entries.
pub fn (mut self GenericHashMap[K, V, X]) ensure_unused_capacity(additional u32) ! {
	self.ensure_total_capacity(self.count() + additional)!
}

// iterator returns an iterator over all used entries.
pub fn (self &GenericHashMap[K, V, X]) iterator() GenericHashMapIter[K, V] {
	return GenericHashMapIter[K, V]{
		metadata: self.metadata
		keys:     self.keys
		values:   self.values
		cap_:     self.header.capacity
	}
}

// key_iterator returns an iterator over all stored keys.
pub fn (self &GenericHashMap[K, V, X]) key_iterator() GenericHashMapKeyIter[K, V] {
	return GenericHashMapKeyIter[K, V]{
		metadata: self.metadata
		keys:     self.keys
		len:      usize(self.header.capacity)
	}
}

// value_iterator returns an iterator over all stored values.
pub fn (self &GenericHashMap[K, V, X]) value_iterator() GenericHashMapValueIter[K, V] {
	return GenericHashMapValueIter[K, V]{
		metadata: self.metadata
		values:   self.values
		len:      usize(self.header.capacity)
	}
}

// ============================================================
// Internal methods
// ============================================================

// get_index finds the slot index for a key, or returns none.
fn (self &GenericHashMap[K, V, X]) get_index(key K) ?usize {
	if self.header.size == 0 {
		return none
	}

	hash := self.context.hash(key)
	mask := u64(self.header.capacity - 1)
	fp := take_fingerprint(hash)
	mut limit := self.header.capacity
	mut idx := usize(hash & mask)

	for !self.metadata[idx].is_free() && limit > 0 {
		if self.metadata[idx].is_used() && self.metadata[idx].fingerprint() == fp {
			if self.context.eql(key, self.keys[idx]) {
				return idx
			}
		}
		limit--
		idx = (idx + 1) & usize(mask)
	}
	return none
}

// get_or_put_internal is the core get-or-put with capacity check.
fn (mut self GenericHashMap[K, V, X]) get_or_put_internal(key K) !GenericGetOrPutResult[K, V] {
	self.grow_if_needed(1) or {
		// Map is full. Try to find existing key.
		if idx := self.get_index(key) {
			return GenericGetOrPutResult[K, V]{
				idx:            idx
				key_ptr:        &self.keys[idx]
				value_ptr:      &self.values[idx]
				found_existing: true
			}
		}
		// Key not found and no capacity.
		return err
	}
	return self.get_or_put_assume_capacity(key)
}

// get_or_put_assume_capacity finds or creates a slot for key.
pub fn (mut self GenericHashMap[K, V, X]) get_or_put_assume_capacity(key K) GenericGetOrPutResult[K, V] {
	hash := self.context.hash(key)
	mask := u64(self.header.capacity - 1)
	fp := take_fingerprint(hash)
	mut limit := self.header.capacity
	mut idx := usize(hash & mask)
	mut first_tombstone := usize(self.header.capacity) // invalid sentinel

	for !self.metadata[idx].is_free() && limit > 0 {
		if self.metadata[idx].is_used() && self.metadata[idx].fingerprint() == fp {
			if self.context.eql(key, self.keys[idx]) {
				return GenericGetOrPutResult[K, V]{
					idx:            idx
					key_ptr:        &self.keys[idx]
					value_ptr:      &self.values[idx]
					found_existing: true
				}
			}
		} else if first_tombstone == usize(self.header.capacity)
			&& self.metadata[idx].is_tombstone() {
			first_tombstone = idx
		}
		limit--
		idx = (idx + 1) & usize(mask)
	}

	// Reuse tombstone slot if available (reduces probing lengths after deletions).
	if first_tombstone < usize(self.header.capacity) {
		idx = first_tombstone
	}

	self.metadata[idx].fill(fp)
	self.keys[idx] = key
	self.values[idx] = V{}
	self.header.size++

	return GenericGetOrPutResult[K, V]{
		idx:            idx
		key_ptr:        &self.keys[idx]
		value_ptr:      &self.values[idx]
		found_existing: false
	}
}

// grow_if_needed checks if there's room for new_count more entries.
// This map has fixed capacity and never resizes.
fn (mut self GenericHashMap[K, V, X]) grow_if_needed(new_count u32) ! {
	available := self.header.capacity - self.header.size
	if new_count > available {
		return error('OutOfMemory')
	}
}

// init_metadatas resets all metadata slots to free state.
fn (mut self GenericHashMap[K, V, X]) init_metadatas() {
	for i in 0 .. int(self.header.capacity) {
		self.metadata[i] = HashSlotMetadata{}
	}
}

pub fn (mut self GenericHashMap[K, V, X]) put_context(key K, value V, context X) ! {
	saved := self.context
	self.context = context
	defer { self.context = saved }
	self.put(key, value)!
}

pub fn (mut self GenericHashMap[K, V, X]) put_no_clobber_context(key K, value V, context X) ! {
	saved := self.context
	self.context = context
	defer { self.context = saved }
	self.put_no_clobber(key, value)!
}

pub fn (mut self GenericHashMap[K, V, X]) put_assume_capacity_context(key K, value V, context X) {
	saved := self.context
	self.context = context
	defer { self.context = saved }
	self.put_assume_capacity(key, value)
}

pub fn (mut self GenericHashMap[K, V, X]) put_assume_capacity_no_clobber_context(key K, value V, context X) {
	saved := self.context
	self.context = context
	defer { self.context = saved }
	self.put_assume_capacity_no_clobber(key, value)
}

pub fn (mut self GenericHashMap[K, V, X]) fetch_put_context(key K, value V, context X) !GenericFetchPutResult[K, V] {
	saved := self.context
	self.context = context
	defer { self.context = saved }
	return self.fetch_put(key, value)!
}

pub fn (mut self GenericHashMap[K, V, X]) fetch_put_assume_capacity_context(key K, value V, context X) ?GenericHashKV[K, V] {
	saved := self.context
	self.context = context
	defer { self.context = saved }
	return self.fetch_put_assume_capacity(key, value)
}

pub fn (mut self GenericHashMap[K, V, X]) fetch_remove_context(key K, context X) ?GenericHashKV[K, V] {
	saved := self.context
	self.context = context
	defer { self.context = saved }
	return self.fetch_remove(key)
}

pub fn (mut self GenericHashMap[K, V, X]) remove_context(key K, context X) bool {
	saved := self.context
	self.context = context
	defer { self.context = saved }
	return self.remove(key)
}

pub fn (mut self GenericHashMap[K, V, X]) get_or_put_context(key K, context X) !GenericGetOrPutResult[K, V] {
	saved := self.context
	self.context = context
	defer { self.context = saved }
	return self.get_or_put(key)!
}

pub fn (mut self GenericHashMap[K, V, X]) get_or_put_value_context(key K, value V, context X) !GenericHashMapIterEntry[K, V] {
	saved := self.context
	self.context = context
	defer { self.context = saved }
	return self.get_or_put_value(key, value)!
}

pub fn (self &GenericHashMap[K, V, X]) get_context(key K, context X) ?V {
	mut view := *self
	view.context = context
	return view.get(key)
}

pub fn (self &GenericHashMap[K, V, X]) get_key_context(key K, context X) ?K {
	mut view := *self
	view.context = context
	return view.get_key(key)
}

pub fn (self &GenericHashMap[K, V, X]) get_ptr_context(key K, context X) ?&V {
	mut view := *self
	view.context = context
	return view.get_ptr(key)
}

pub fn (self &GenericHashMap[K, V, X]) get_key_ptr_context(key K, context X) ?&K {
	mut view := *self
	view.context = context
	return view.get_key_ptr(key)
}

pub fn (self &GenericHashMap[K, V, X]) get_entry_context(key K, context X) ?GenericHashMapIterEntry[K, V] {
	mut view := *self
	view.context = context
	return view.get_entry(key)
}

pub fn (self &GenericHashMap[K, V, X]) contains_context(key K, context X) bool {
	mut view := *self
	view.context = context
	return view.contains(key)
}

pub fn (self &GenericHashMap[K, V, X]) get_index_adapted[A, Y](key A, context Y) ?usize {
	if self.header.size == 0 { return none }
	hash := context.hash(key)
	mask := u64(self.header.capacity - 1)
	fingerprint := take_fingerprint(hash)
	mut index := usize(hash & mask)
	mut limit := self.header.capacity
	for !self.metadata[index].is_free() && limit > 0 {
		if self.metadata[index].is_used() && self.metadata[index].fingerprint() == fingerprint
			&& context.eql(key, self.keys[index]) {
			return index
		}
		index = (index + 1) & usize(mask)
		limit--
	}
	return none
}

pub fn (mut self GenericHashMap[K, V, X]) get_or_put_context_adapted[A, Y](key A, context Y) !GenericGetOrPutResult[K, V] {
	self.grow_if_needed(1) or {
		if index := self.get_index_adapted[A, Y](key, context) {
			return GenericGetOrPutResult[K, V]{
				idx:            index
				key_ptr:        &self.keys[index]
				value_ptr:      &self.values[index]
				found_existing: true
			}
		}
		return err
	}
	return self.get_or_put_assume_capacity_context_adapted[A, Y](key, context)
}

pub fn (mut self GenericHashMap[K, V, X]) get_or_put_assume_capacity_context_adapted[A, Y](key A, context Y) GenericGetOrPutResult[K, V] {
	hash := context.hash(key)
	mask := u64(self.header.capacity - 1)
	fingerprint := take_fingerprint(hash)
	mut index := usize(hash & mask)
	mut limit := self.header.capacity
	mut tombstone := usize(self.header.capacity)
	for !self.metadata[index].is_free() && limit > 0 {
		if self.metadata[index].is_used() && self.metadata[index].fingerprint() == fingerprint {
			if context.eql(key, self.keys[index]) {
				return GenericGetOrPutResult[K, V]{
					idx:            index
					key_ptr:        &self.keys[index]
					value_ptr:      &self.values[index]
					found_existing: true
				}
			}
		} else if tombstone == usize(self.header.capacity) && self.metadata[index].is_tombstone() {
			tombstone = index
		}
		index = (index + 1) & usize(mask)
		limit--
	}
	if tombstone < usize(self.header.capacity) { index = tombstone }
	self.metadata[index].fill(fingerprint)
	self.header.size++
	return GenericGetOrPutResult[K, V]{
		idx:       index
		key_ptr:   &self.keys[index]
		value_ptr: &self.values[index]
	}
}
