module terminal

// hash_map.v - Offset-based hash map for terminal page representation.
// Translated from Ghostty's terminal/hash_map.zig (1,540 lines).
//
// This is a fork of Zig's stdlib HashMap using offsets rather than pointers
// so that backing memory can be copied/moved without invalidating the map.
// The map is backed by a single contiguous allocation with metadata, keys,
// and values laid out sequentially.
//
// The main differences from the Zig version:
// - Uses V arrays instead of a single contiguous buffer with pointer arithmetic
// - Concrete u64 key/value types instead of comptime generics
// - XTODO for offset-based memory layout (needed for terminal page integration)
//
// The core algorithm is preserved: open addressing with linear probing,
// 7-bit fingerprinting for fast collision resolution, and tombstone-based
// deletion.

// ============================================================
// Hash function
// ============================================================

// hash_key computes a 64-bit hash for integer keys using splitmix64 mixing.
fn hash_key(key u64) u64 {
	mut h := key
	h ^= h >> 30
	h *= u64(0xbf58476d1ce4e5b9)
	h ^= h >> 27
	h *= u64(0x94d049bb133111eb)
	h ^= h >> 31
	return h
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
	total_size i64
	// Byte offset from metadata start to keys array.
	keys_start i64
	// Byte offset from metadata start to values array.
	vals_start i64
	// The capacity (always a power of two).
	capacity u32
}

// layout_for_capacity computes the memory layout for a hash map.
// Capacity must be 0 or a power of two.
// key_size/val_size are element sizes in bytes; key_align/val_align are alignments.
// Uses i64 internally to avoid overflow with large capacities (>2^30).
pub fn layout_for_capacity(new_capacity u32, key_size i64, val_size i64, key_align i64, val_align i64) HashMapLayout {
	header_size := i64(16) // two Offsets (u32 each) + two u32 (capacity, size)
	cap := i64(new_capacity)

	meta_end := header_size + cap
	ka := if key_align > 0 { key_align } else { i64(1) }
	va := if val_align > 0 { val_align } else { i64(1) }
	keys_start := hash_align_forward(meta_end, ka)
	keys_end := keys_start + cap * key_size
	vals_start := hash_align_forward(keys_end, va)
	vals_end := vals_start + cap * val_size

	base_align := hash_max(i64(8), hash_max(ka, va))
	total_size := hash_align_forward(vals_end, base_align)

	// Offsets are from metadata pointer, so subtract header size.
	return HashMapLayout{
		total_size: total_size
		keys_start: keys_start - header_size
		vals_start: vals_start - header_size
		capacity: new_capacity
	}
}

fn hash_align_forward(addr i64, alignment i64) i64 {
	if alignment <= 0 {
		return addr
	}
	return (addr + alignment - 1) & ~(alignment - 1)
}

fn hash_max(a i64, b i64) i64 {
	if a > b {
		return a
	}
	return b
}

// ============================================================
// OffsetHashMap - offset-based wrapper
// ============================================================

// OffsetHashMap stores an offset to the hash map metadata within a
// page's contiguous memory buffer. This allows the entire page
// (including the hash map) to be moved/copied without invalidating
// the map's internal pointers.
//
// XTODO: Full offset-based implementation requires V pointer arithmetic
// and the ability to reconstruct a HashMapUnmanaged from a base pointer
// and metadata offset. Currently stubbed - use HashMapUnmanaged directly.
pub struct OffsetHashMap {
pub mut:
	metadata_offset Offset
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
	idx            int
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
	cap_     int
mut:
	index int
}

// next returns the next used entry, or none if iteration is complete.
pub fn (mut it HashMapIter) next() ?HashMapIterEntry {
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
// XTODO: Generic type parameters, offset-based single-buffer layout,
// custom hash/equality contexts.
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
	hash := hash_key(key)
	mask := u64(self.cap_ - 1)
	mut idx := int(hash & mask)

	for self.metadata[idx].is_used() {
		idx = (idx + 1) & int(mask)
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

// get_key_index returns the slot index for a key, or none.
pub fn (self &HashMapUnmanaged) get_key_index(key u64) ?int {
	return self.get_index(key)
}

// get_ptr returns the slot index for a key's value, or none.
// Use map.values[idx] to read/write the value.
pub fn (self &HashMapUnmanaged) get_ptr(key u64) ?int {
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
pub fn (mut self HashMapUnmanaged) remove_by_index(idx int) {
	self.metadata[idx].mark_removed()
	self.keys[idx] = 0
	self.values[idx] = 0
	self.size_--
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
		cap_: int(self.cap_)
	}
}

// ============================================================
// Internal methods
// ============================================================

// get_index finds the slot index for a key, or returns none.
fn (self &HashMapUnmanaged) get_index(key u64) ?int {
	if self.size_ == 0 {
		return none
	}

	hash := hash_key(key)
	mask := u64(self.cap_ - 1)
	fp := take_fingerprint(hash)
	mut limit := int(self.cap_)
	mut idx := int(hash & mask)

	for !self.metadata[idx].is_free() && limit > 0 {
		if self.metadata[idx].is_used() && self.metadata[idx].fingerprint() == fp {
			if self.keys[idx] == key {
				return idx
			}
		}
		limit--
		idx = (idx + 1) & int(mask)
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
fn (mut self HashMapUnmanaged) get_or_put_assume_capacity(key u64) GetOrPutResult {
	hash := hash_key(key)
	mask := u64(self.cap_ - 1)
	fp := take_fingerprint(hash)
	mut limit := int(self.cap_)
	mut idx := int(hash & mask)
	mut first_tombstone := int(self.cap_) // invalid sentinel

	for !self.metadata[idx].is_free() && limit > 0 {
		if self.metadata[idx].is_used() && self.metadata[idx].fingerprint() == fp {
			if self.keys[idx] == key {
				return GetOrPutResult{
					idx: idx
					found_existing: true
				}
			}
		} else if first_tombstone == int(self.cap_) && self.metadata[idx].is_tombstone() {
			first_tombstone = idx
		}
		limit--
		idx = (idx + 1) & int(mask)
	}

	// Reuse tombstone slot if available (reduces probing lengths after deletions).
	if first_tombstone < int(self.cap_) {
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
