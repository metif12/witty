module terminal

import internal_hash

// --- Original Ghostty Comments Start: src/terminal/hash_map.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/terminal/hash_map.zig
//
// This file contains a fork of the Zig stdlib HashMap implementation tuned
// for use with our terminal page representation.
//
// The main goal we need to achieve that wasn't possible with the stdlib
// HashMap is to utilize offsets rather than full pointers so that we can
// copy around the entire backing memory and keep the hash map working.
//
// Additionally, for serialization/deserialization purposes, we need to be
// able to create a HashMap instance and manually set the offsets up. The
// stdlib HashMap does not export Metadata so this isn't possible.
//
// Also, I want to be able to understand possible capacity for a given K,V
// type and fixed memory amount. The stdlib HashMap doesn't publish its
// internal allocation size calculation.
//
// Finally, I removed many of the APIs that we'll never require for our
// usage just so that this file is smaller, easier to understand, and has
// less opportunity for bugs.
//
// Besides these shortcomings, the stdlib HashMap has some great qualities
// that we want to keep, namely the fact that it is backed by a single large
// allocation rather than pointers to separate allocations. This is important
// because our terminal page representation is backed by a single large
// allocation so we can give the HashMap a slice of memory to operate in.
//
// I haven't carefully benchmarked this implementation against other hash
// map implementations. It's possible using some of the newer variants out
// there would be better. However, I trust the built-in version is pretty good
// and its more important to get the terminal page representation working
// first then we can measure and improve this later if we find it to be a
// bottleneck.
// A HashMap type that uses offsets rather than pointers, making it
// possible to efficiently move around the backing memory without
// invalidating the HashMap.
// This is the pointer-based map that we're wrapping.
// This is the alignment that the base pointer must have.
// Returns the total size of the backing memory required for a
// HashMap with the given capacity. The base ptr must also be
// aligned to base_align.
// Initialize a new HashMap with the given capacity and backing
// memory. The backing memory must be aligned to base_align.
// Returns the pointer-based map from a base pointer.
// Fork of stdlib.HashMap as of Zig 0.12 modified to to use offsets
// for the key/values pointer. The metadata is still a pointer to limit
// the amount of arithmetic required to access it. See the file comment
// for full details.
// This is actually a midway pointer to the single buffer containing
// a `Header` field, the `Metadata`s and `Entry`s.
// At `-@sizeOf(Header)` is the Header field.
// At `sizeOf(Metadata) * capacity + offset`, which is pointed to by
// self.header().entries, is the array of entries.
// This means that the hashmap only holds one live allocation, to
// reduce memory fragmentation and struct size.
// Pointer to the metadata.
// This is purely empirical and not a /very smart magic constant™/.
// Capacity of the first grow when bootstrapping the hashmap.
// This hashmap is specially designed for sizes that fit in a u32.
// u64 hashes guarantee us that the fingerprint bits will never be used
// to compute the index of a slot, maximizing the use of entropy.
// The keys/values offset are relative to the metadata
// Metadata for a slot. It can be in three states: empty, used or
// tombstone. Tombstones indicate that an entry was previously used,
// they are a simple way to handle removal.
// To this state, we add 7 bits from the slot's key hash. These are
// used as a fast way to disambiguate between entries without
// having to use the equality function. If two fingerprints are
// different, we know that we don't have to compare the keys at all.
// The 7 bits are the highest ones from a 64 bit hash. This way, not
// only we use the `log2(capacity)` lowest bits from the hash to determine
// a slot index, but we use 7 more bits to quickly resolve collisions
// when multiple elements with different hashes end up wanting to be in the same slot.
// Not using the equality function means we don't have to read into
// the entries array, likely avoiding a cache miss and a potentially
// costly function call.
// Initialize a hash map with a given capacity and a buffer. The
// buffer must fit within the size defined by `layoutForCapacity`.
// Get all our main pointers
// Build our map
// Insert an entry in the map. Assumes it is not already present.
// Asserts there is enough capacity to store the new key-value pair.
// Clobbers any existing data. To detect if a put would clobber
// existing data, see `getOrPutAssumeCapacity`.
// Insert an entry in the map. Assumes it is not already present,
// and that no allocation is needed.
// Inserts a new `Entry` into the hash map, returning the previous one, if any.
// Inserts a new `Entry` into the hash map, returning the previous one, if any.
// If insertion happens, asserts there is enough capacity without allocating.
// If there is an `Entry` with a matching key, it is deleted from
// the hash map, and then returned from this function.
// Find the index containing the data for the given key.
// Whether this function returns null is almost always
// branched on after this function returns, and this function
// returns null/not null from separate code paths.  We
// want the optimizer to remove that branch and instead directly
// fuse the basic blocks after the branch to the basic blocks
// from this function.  To encourage that, this function is
// marked as inline.
// If you get a compile error on this line, it means that your generic hash
// function is invalid for these parameters.
// Don't loop indefinitely when there are no empty slots.
// If you get a compile error on this line, it means that your generic eql
// function is invalid for these parameters.
// verifyContext can't verify the return type of generic eql functions,
// so we need to double-check it here.
// Insert an entry if the associated key is not already present, otherwise update preexisting value.
// Get an optional pointer to the actual key associated with adapted key, if present.
// Get a copy of the actual key associated with adapted key, if present.
// Get an optional pointer to the value associated with key, if present.
// Get a copy of the value associated with key, if present.
// If allocation fails, try to do the lookup anyway.
// If we find an existing item, we can return it.
// Otherwise return the error, we could not add another.
// If you get a compile error on this line, it means that your generic hash
// function is invalid for these parameters.
// verifyContext can't verify the return type of generic hash functions,
// so we need to double-check it here.
// If you get a compile error on this line, it means that your generic eql
// function is invalid for these parameters.
// verifyContext can't verify the return type of generic eql functions,
// so we need to double-check it here.
// Cheap try to lower probing lengths after deletions. Recycle a tombstone.
// Return true if there is a value associated with key in the map.
// If there is an `Entry` with a matching key, it is deleted from
// the hash map, and this function returns true.  Otherwise this
// function returns false.
// Delete the entry with key pointed to by key_ptr from the hash map.
// key_ptr is assumed to be a valid pointer to a key that is present
// in the hash map.
// TODO: replace with pointer subtraction once supported by zig
// if @sizeOf(K) == 0 then there is at most one item in the hash
// map, which is assumed to exist as key_ptr must be valid.  This
// item must be at index 0.
// The memory layout for the underlying buffer for a given capacity.
// The total size of the buffer required. The buffer is expected
// to be aligned to `base_align`.
// The offset to the start of the keys data.
// The offset to the start of the values data.
// The capacity that was used to calculate this layout.
// Returns the memory layout for the buffer for a given capacity.
// The actual size may be able to fit more than the given capacity
// because capacity is rounded up to the next power of two. This is
// a design requirement for this hash map implementation.
// Cast to usize to prevent overflow in size calculations.
// See: https://github.com/ziglang/zig/pull/19048
// Pack our metadata, keys, and values.
// Our total memory size required is the end of our values
// aligned to the base required alignment.
// The offsets we actually store in the map are from the
// metadata pointer so that we can use self.metadata as
// the base.
// shouldn't resize from putAssumeCapacity
// Repeatedly delete/insert an entry without resizing the map.
// Put to different keys so entries don't land in the just-freed slot.
// fetchRemove() should make slots available.
// Test that layoutForCapacity correctly handles large capacities without overflow.
// Prior to the fix, new_capacity (u32) was multiplied before widening to usize,
// causing overflow when new_capacity * @sizeOf(K) exceeded 2^32.
// See: https://github.com/ghostty-org/ghostty/issues/9862
// Use 2^30 capacity - this would overflow in u32 when multiplied by @sizeOf(u64)=8
// 0x40000000 * 8 = 0x2_0000_0000 which wraps to 0 in u32
// With the fix, total_size should be at least cap * (sizeof(K) + sizeof(V))
// = 2^30 * 16 = 2^34 bytes = 16 GiB
// Without the fix, this would wrap and produce a much smaller value.
// Also verify the individual offsets don't wrap
//
// --- Original Ghostty Comments End: src/terminal/hash_map.zig

// hash_map.v - Offset-based hash map for terminal page representation.
// Translated from Ghostty's terminal/hash_map.zig (1,540 lines).
//
// This is a fork of Zig's stdlib HashMap using offsets rather than pointers
// so that backing memory can be copied/moved without invalidating the map.
// The map is backed by a single contiguous allocation with metadata, keys,
// and values laid out sequentially.
//
// The main differences from the Zig version are the use of V arrays in place
// of raw allocation slices and a concrete u64 key/value specialization.
//
// The core algorithm is preserved: open addressing with linear probing,
// 7-bit fingerprinting for fast collision resolution, and tombstone-based
// deletion.

// ============================================================
// Hash function
// ============================================================

// hash_key reproduces the AutoContext(u64) hash used by the source map.
fn hash_key(key u64) u64 {
	return internal_hash.auto_hash_u64(key)
}

// ============================================================
// HashSlotMetadata - per-slot metadata byte
// ============================================================

// HashSlotMetadata represents metadata for a single hash map slot.
// It packs a 7-bit fingerprint (from the key's hash) and a 1-bit used flag
// into a single byte. This allows fast slot state checks and collision
// disambiguation without reading the actual keys.
//
// States:
//   - free:      value = 0x00 (fingerprint=0, used=0)
//   - tombstone: value = 0x01 (fingerprint=1, used=0)
//   - used:      value = fp | 0x80 (fingerprint=fp, used=1)
pub struct HashSlotMetadata {
pub mut:
	value u8
}

const hash_meta_free = u8(0x00)
const hash_meta_tombstone = u8(0x01)

// is_used returns true if this slot contains a live entry.
pub fn (m HashSlotMetadata) is_used() bool {
	return (m.value & 0x80) != 0
}

// is_tombstone returns true if this slot previously held a removed entry.
pub fn (m HashSlotMetadata) is_tombstone() bool {
	return m.value == hash_meta_tombstone
}

// is_free returns true if this slot has never been used.
pub fn (m HashSlotMetadata) is_free() bool {
	return m.value == hash_meta_free
}

// fingerprint returns the 7-bit fingerprint stored in this metadata.
pub fn (m HashSlotMetadata) fingerprint() u8 {
	return m.value & 0x7F
}

// take_fingerprint extracts the top 7 bits of a 64-bit hash as a fingerprint.
pub fn take_fingerprint(hash u64) u8 {
	return u8(hash >> 57)
}

// fill marks this slot as used with the given fingerprint.
pub fn (mut m HashSlotMetadata) fill(fp u8) {
	assert fp <= 0x7f
	m.value = fp | 0x80
}

// mark_removed marks this slot as a tombstone.
pub fn (mut m HashSlotMetadata) mark_removed() {
	m.value = hash_meta_tombstone
}

// ============================================================
// HashMapLayout - memory layout computation
// ============================================================

// HashMapLayout describes the memory layout for a hash map with a given
// capacity. Used for computing buffer sizes when the hash map is backed
// by a single contiguous allocation (the offset-based version).
pub struct HashMapLayout {
pub:
	// Total buffer size in bytes (aligned to base alignment).
	total_size uint
	// Byte offset from metadata start to keys array.
	keys_start uint
	// Byte offset from metadata start to values array.
	vals_start uint
	// The capacity (always a power of two).
	capacity u32
}

// layout_for_capacity computes the memory layout for a hash map.
// Capacity must be 0 or a power of two.
// key_size/val_size are element sizes in bytes; key_align/val_align are alignments.
pub fn layout_for_capacity(new_capacity u32, key_size uint, val_size uint, key_align uint, val_align uint) HashMapLayout {
	assert new_capacity == 0 || (new_capacity & (new_capacity - 1)) == 0

	header_size := uint(16) // two Offsets (u32 each) + two u32 (capacity, size)
	cap := uint(new_capacity)

	meta_end := header_size + cap
	ka := if key_size == 0 { uint(1) } else { key_align }
	va := if val_size == 0 { uint(1) } else { val_align }
	keys_start := hash_align_forward(meta_end, ka)
	keys_end := keys_start + cap * key_size
	vals_start := hash_align_forward(keys_end, va)
	vals_end := vals_start + cap * val_size

	base_align := hash_max(uint(4), hash_max(ka, va))
	total_size := hash_align_forward(vals_end, base_align)

	// Offsets are from metadata pointer, so subtract header size.
	return HashMapLayout{
		total_size: total_size
		keys_start: keys_start - header_size
		vals_start: vals_start - header_size
		capacity: new_capacity
	}
}

fn hash_align_forward(addr uint, alignment uint) uint {
	if alignment == 0 {
		return addr
	}
	return (addr + alignment - 1) & ~(alignment - 1)
}

fn hash_max(a uint, b uint) uint {
	if a > b {
		return a
	}
	return b
}

// ============================================================
// OffsetHashMap - offset-based wrapper
// ============================================================

pub struct U64HashContext {}

pub fn (_ U64HashContext) hash(key u64) u64 { return hash_key(key) }
pub fn (_ U64HashContext) eql(a u64, b u64) bool { return a == b }

// OffsetHashMap is the source's AutoOffsetHashMap(u64, u64) specialization.
// Only its metadata byte offset persists; every map view resolves the supplied
// base, including after the entire caller-owned buffer is moved.
pub struct OffsetHashMap {
pub mut:
	metadata_offset Offset
}

pub fn OffsetHashMap.layout(cap u32) HashMapLayout {
	return layout_for_capacity(cap, uint(sizeof(u64)), uint(sizeof(u64)), uint(sizeof(u64)), uint(sizeof(u64)))
}

pub fn OffsetHashMap.init(buf OffsetBuf, layout HashMapLayout) OffsetHashMap {
	offsets := generic_offset_hash_map_init[u64, u64, U64HashContext](buf, layout, U64HashContext{})
	return OffsetHashMap{
		metadata_offset: offsets.metadata_offset
	}
}

pub fn (self &OffsetHashMap) map(base &u8) GenericHashMap[u64, u64, U64HashContext] {
	return generic_hash_map_view[u64, u64, U64HashContext](self.metadata_offset.ptr(base), U64HashContext{})
}

// ============================================================
// HashMapUnmanaged - core open-addressing hash map
// ============================================================

// Minimal capacity for the first allocation.
pub const hash_map_minimal_capacity = u32(8)

// HashKV is a key-value pair returned by fetch operations.
pub struct HashKV {
pub:
	key   u64
	value u64
}

// FetchPutResult is the result of a fetch_put operation.
pub struct FetchPutResult {
pub:
	had_previous bool
	previous     HashKV
}

// GetOrPutResult from get_or_put operations. Contains the slot index
// and whether the key already existed. Use map.keys[idx] and
// map.values[idx] to access/modify the entry.
pub struct GetOrPutResult {
pub:
	idx            uint
	found_existing bool
}

// HashMapIterEntry is a key-value pair returned by the iterator.
pub struct HashMapIterEntry {
pub:
	key   u64
	value u64
}

// HashMapIter iterates over used entries in a HashMapUnmanaged.
pub struct HashMapIter {
	metadata []HashSlotMetadata
	keys     []u64
	values   []u64
	cap_     u32
mut:
	index u32
}

// next returns the next used entry, or none if iteration is complete.
pub fn (mut it HashMapIter) next() ?HashMapIterEntry {
	assert it.index <= it.cap_
	for it.index < it.cap_ {
		idx := it.index
		it.index++
		if it.metadata[idx].is_used() {
			return HashMapIterEntry{
				key: it.keys[idx]
				value: it.values[idx]
			}
		}
	}
	return none
}

// HashMapKeyIter iterates over the keys in used slots.
pub struct HashMapKeyIter {
	metadata []HashSlotMetadata
	keys     []u64
mut:
	len   uint
	index uint
}

// next returns the next key, or none if iteration is complete.
pub fn (mut it HashMapKeyIter) next() ?u64 {
	for it.len > 0 {
		it.len--
		idx := it.index
		it.index++
		if it.metadata[idx].is_used() {
			return it.keys[idx]
		}
	}
	return none
}

// HashMapValueIter iterates over the values in used slots.
pub struct HashMapValueIter {
	metadata []HashSlotMetadata
	values   []u64
mut:
	len   uint
	index uint
}

// next returns the next value, or none if iteration is complete.
pub fn (mut it HashMapValueIter) next() ?u64 {
	for it.len > 0 {
		it.len--
		idx := it.index
		it.index++
		if it.metadata[idx].is_used() {
			return it.values[idx]
		}
	}
	return none
}

// HashMapUnmanaged is an open-addressing hash map with linear probing
// and 7-bit fingerprint-based collision resolution.
//
// In the original Zig implementation, this is a comptime-generic type
// parameterized by K, V, and Context, backed by a single contiguous
// buffer with offset-based addressing. Here we use concrete u64 types
// for keys and values (which can hold any integer type) and separate
// V arrays for storage.
//
// The map has a fixed capacity set at initialization and does not
// resize. Exceeding capacity returns an error.
//
// V specializes this implementation to u64 keys and values; typed page maps
// encode their compact integer keys into this representation.
pub struct HashMapUnmanaged {
pub mut:
	metadata []HashSlotMetadata
	keys     []u64
	values   []u64
	cap_     u32
	size_    u32
}

// init creates a new hash map with the given capacity.
// Capacity should be a power of two (or zero).
pub fn HashMapUnmanaged.init(cap u32) HashMapUnmanaged {
	// Ghostty receives a private Layout whose constructor guarantees this.
	assert cap == 0 || (cap & (cap - 1)) == 0
	return HashMapUnmanaged{
		metadata: []HashSlotMetadata{len: int(cap)}
		keys: []u64{len: int(cap)}
		values: []u64{len: int(cap)}
		cap_: cap
		size_: 0
	}
}

// count returns the number of entries in the map.
pub fn (self &HashMapUnmanaged) count() u32 {
	return self.size_
}

// capacity returns the total capacity of the map.
pub fn (self &HashMapUnmanaged) capacity() u32 {
	return self.cap_
}

// put inserts a key-value pair, updating the value if the key exists.
pub fn (mut self HashMapUnmanaged) put(key u64, value u64) ! {
	gop := self.get_or_put_internal(key)!
	self.values[gop.idx] = value
}

// put_no_clobber inserts a key-value pair. Asserts the key doesn't exist.
pub fn (mut self HashMapUnmanaged) put_no_clobber(key u64, value u64) ! {
	assert !self.contains(key)
	self.grow_if_needed(1)!
	self.put_assume_capacity_no_clobber(key, value)
}

// put_assume_capacity inserts or updates without checking capacity.
pub fn (mut self HashMapUnmanaged) put_assume_capacity(key u64, value u64) {
	gop := self.get_or_put_assume_capacity(key)
	self.values[gop.idx] = value
}

// put_assume_capacity_no_clobber inserts without checking capacity.
// The key must not already exist.
pub fn (mut self HashMapUnmanaged) put_assume_capacity_no_clobber(key u64, value u64) {
	assert !self.contains(key)
	hash := hash_key(key)
	mask := u64(self.cap_ - 1)
	mut idx := uint(hash & mask)

	for self.metadata[idx].is_used() {
		idx = (idx + 1) & uint(mask)
	}

	fp := take_fingerprint(hash)
	self.metadata[idx].fill(fp)
	self.keys[idx] = key
	self.values[idx] = value
	self.size_++
}

// get returns a copy of the value for key, or none.
pub fn (self &HashMapUnmanaged) get(key u64) ?u64 {
	idx := self.get_index(key) or { return none }
	return self.values[idx]
}

// get_key returns a copy of the stored key, or none.
pub fn (self &HashMapUnmanaged) get_key(key u64) ?u64 {
	idx := self.get_index(key) or { return none }
	return self.keys[idx]
}

// get_key_ptr returns the slot index for the stored key, or none. Slot indices
// are the stable V representation used in place of pointers into backing arrays.
pub fn (self &HashMapUnmanaged) get_key_ptr(key u64) ?uint {
	return self.get_index(key)
}

// get_key_index returns the slot index for a key, or none.
pub fn (self &HashMapUnmanaged) get_key_index(key u64) ?uint {
	return self.get_index(key)
}

// get_ptr returns the slot index for a key's value, or none.
// Use map.values[idx] to read/write the value.
pub fn (self &HashMapUnmanaged) get_ptr(key u64) ?uint {
	return self.get_index(key)
}

// get_entry returns a copy of the key-value pair, or none.
pub fn (self &HashMapUnmanaged) get_entry(key u64) ?HashKV {
	idx := self.get_index(key) or { return none }
	return HashKV{
		key: self.keys[idx]
		value: self.values[idx]
	}
}

// contains returns true if key exists in the map.
pub fn (self &HashMapUnmanaged) contains(key u64) bool {
	if _ := self.get_index(key) {
		return true
	}
	return false
}

// get_or_put finds existing entry or creates a new slot.
// Returns the slot index and whether the key already existed.
pub fn (mut self HashMapUnmanaged) get_or_put(key u64) !GetOrPutResult {
	gop := self.get_or_put_internal(key)!
	if !gop.found_existing {
		self.keys[gop.idx] = key
	}
	return gop
}

// get_or_put_value gets existing entry or inserts with the given value.
pub fn (mut self HashMapUnmanaged) get_or_put_value(key u64, value u64) !HashKV {
	gop := self.get_or_put_internal(key)!
	if !gop.found_existing {
		self.keys[gop.idx] = key
		self.values[gop.idx] = value
	}
	return HashKV{
		key: self.keys[gop.idx]
		value: self.values[gop.idx]
	}
}

// fetch_put inserts/updates and returns the previous entry if it existed.
// V cannot combine ! and ? return types, so we use FetchPutResult.
pub fn (mut self HashMapUnmanaged) fetch_put(key u64, value u64) !FetchPutResult {
	gop := self.get_or_put_internal(key)!
	mut result := FetchPutResult{}
	if gop.found_existing {
		result = FetchPutResult{
			had_previous: true
			previous: HashKV{
				key: self.keys[gop.idx]
				value: self.values[gop.idx]
			}
		}
	}
	self.values[gop.idx] = value
	return result
}

// fetch_put_assume_capacity is like fetch_put but doesn't check capacity.
pub fn (mut self HashMapUnmanaged) fetch_put_assume_capacity(key u64, value u64) ?HashKV {
	gop := self.get_or_put_assume_capacity(key)
	mut result := ?HashKV(none)
	if gop.found_existing {
		result = HashKV{
			key: self.keys[gop.idx]
			value: self.values[gop.idx]
		}
	}
	self.values[gop.idx] = value
	return result
}

// fetch_remove removes and returns the entry for key, or none.
pub fn (mut self HashMapUnmanaged) fetch_remove(key u64) ?HashKV {
	idx := self.get_index(key) or { return none }
	result := HashKV{
		key: self.keys[idx]
		value: self.values[idx]
	}
	self.remove_by_index(idx)
	return result
}

// remove deletes the entry for key. Returns true if it existed.
pub fn (mut self HashMapUnmanaged) remove(key u64) bool {
	idx := self.get_index(key) or { return false }
	self.remove_by_index(idx)
	return true
}

// remove_by_index removes the entry at the given slot index.
pub fn (mut self HashMapUnmanaged) remove_by_index(idx uint) {
	self.metadata[idx].mark_removed()
	self.keys[idx] = 0
	self.values[idx] = 0
	self.size_--
}

// remove_by_ptr removes the key at a slot returned by get_key_ptr.
pub fn (mut self HashMapUnmanaged) remove_by_ptr(key_ptr uint) {
	assert key_ptr < uint(self.cap_)
	assert self.metadata[key_ptr].is_used()
	self.remove_by_index(key_ptr)
}

// clear_retaining_capacity removes all entries but keeps allocated capacity.
pub fn (mut self HashMapUnmanaged) clear_retaining_capacity() {
	if self.cap_ > 0 {
		self.init_metadatas()
		self.size_ = 0
	}
}

// ensure_total_capacity checks that the map can hold at least new_size entries.
pub fn (mut self HashMapUnmanaged) ensure_total_capacity(new_size u32) ! {
	if new_size > self.size_ {
		self.grow_if_needed(new_size - self.size_)!
	}
}

// ensure_unused_capacity checks that the map has room for additional entries.
pub fn (mut self HashMapUnmanaged) ensure_unused_capacity(additional u32) ! {
	self.ensure_total_capacity(self.count() + additional)!
}

// iterator returns an iterator over all used entries.
pub fn (self &HashMapUnmanaged) iterator() HashMapIter {
	return HashMapIter{
		metadata: self.metadata
		keys: self.keys
		values: self.values
		cap_: self.cap_
	}
}

// key_iterator returns an iterator over all stored keys.
pub fn (self &HashMapUnmanaged) key_iterator() HashMapKeyIter {
	return HashMapKeyIter{
		metadata: self.metadata
		keys: self.keys
		len: uint(self.cap_)
	}
}

// value_iterator returns an iterator over all stored values.
pub fn (self &HashMapUnmanaged) value_iterator() HashMapValueIter {
	return HashMapValueIter{
		metadata: self.metadata
		values: self.values
		len: uint(self.cap_)
	}
}

// ============================================================
// Internal methods
// ============================================================

// get_index finds the slot index for a key, or returns none.
fn (self &HashMapUnmanaged) get_index(key u64) ?uint {
	if self.size_ == 0 {
		return none
	}

	hash := hash_key(key)
	mask := u64(self.cap_ - 1)
	fp := take_fingerprint(hash)
	mut limit := self.cap_
	mut idx := uint(hash & mask)

	for !self.metadata[idx].is_free() && limit > 0 {
		if self.metadata[idx].is_used() && self.metadata[idx].fingerprint() == fp {
			if self.keys[idx] == key {
				return idx
			}
		}
		limit--
		idx = (idx + 1) & uint(mask)
	}
	return none
}

// get_or_put_internal is the core get-or-put with capacity check.
fn (mut self HashMapUnmanaged) get_or_put_internal(key u64) !GetOrPutResult {
	self.grow_if_needed(1) or {
		// Map is full. Try to find existing key.
		if idx := self.get_index(key) {
			return GetOrPutResult{
				idx: idx
				found_existing: true
			}
		}
		// Key not found and no capacity.
		return err
	}
	return self.get_or_put_assume_capacity(key)
}

// get_or_put_assume_capacity finds or creates a slot for key.
pub fn (mut self HashMapUnmanaged) get_or_put_assume_capacity(key u64) GetOrPutResult {
	hash := hash_key(key)
	mask := u64(self.cap_ - 1)
	fp := take_fingerprint(hash)
	mut limit := self.cap_
	mut idx := uint(hash & mask)
	mut first_tombstone := uint(self.cap_) // invalid sentinel

	for !self.metadata[idx].is_free() && limit > 0 {
		if self.metadata[idx].is_used() && self.metadata[idx].fingerprint() == fp {
			if self.keys[idx] == key {
				return GetOrPutResult{
					idx: idx
					found_existing: true
				}
			}
		} else if first_tombstone == uint(self.cap_) && self.metadata[idx].is_tombstone() {
			first_tombstone = idx
		}
		limit--
		idx = (idx + 1) & uint(mask)
	}

	// Reuse tombstone slot if available (reduces probing lengths after deletions).
	if first_tombstone < uint(self.cap_) {
		idx = first_tombstone
	}

	self.metadata[idx].fill(fp)
	self.keys[idx] = key
	self.values[idx] = 0
	self.size_++

	return GetOrPutResult{
		idx: idx
		found_existing: false
	}
}

// grow_if_needed checks if there's room for new_count more entries.
// This map has fixed capacity and never resizes.
fn (mut self HashMapUnmanaged) grow_if_needed(new_count u32) ! {
	available := self.cap_ - self.size_
	if new_count > available {
		return error('OutOfMemory')
	}
}

// init_metadatas resets all metadata slots to free state.
fn (mut self HashMapUnmanaged) init_metadatas() {
	for i in 0 .. int(self.cap_) {
		self.metadata[i] = HashSlotMetadata{}
	}
}
