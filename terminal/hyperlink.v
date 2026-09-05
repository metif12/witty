module terminal

import internal_hash

// Hyperlink types translated from Ghostty's terminal/hyperlink.zig.
//
// Ghostty stores page-entry strings as offsets into a page-owned allocation.
// Witty's Page is made from GC-owned V arrays, so the corresponding V page
// entry owns ordinary strings. The identity, deduplication, ref-counting, and
// lifetime semantics remain the same without manufacturing pointer offsets.

// HyperlinkId is the unique identifier for a hyperlink within one page.
// ID zero is reserved for cells without a hyperlink.
pub type HyperlinkId = u16

// HyperlinkIdKind represents an explicit OSC 8 ID or an implicit screen ID.
pub type HyperlinkIdKind = HyperlinkExplicitId | HyperlinkImplicitId

pub struct HyperlinkExplicitId {
pub:
	value string
}

pub struct HyperlinkImplicitId {
pub:
	offset u32
}

// Hyperlink is the decoded form used by the terminal and public APIs.
pub struct Hyperlink {
pub mut:
	id  HyperlinkIdKind
	uri string
}

// V strings are reference counted by the runtime, so deinit has no explicit
// allocation to release. It is retained to mirror Ghostty's API.
pub fn (self &Hyperlink) deinit() {}

pub fn (self &Hyperlink) dupe() Hyperlink {
	return Hyperlink{
		id: hyperlink_id_dupe(self.id)
		uri: self.uri.clone()
	}
}

pub fn (self &Hyperlink) eql(other &Hyperlink) bool {
	return self.uri == other.uri && hyperlink_ids_equal(self.id, other.id)
}

fn hyperlink_id_dupe(id HyperlinkIdKind) HyperlinkIdKind {
	return match id {
		HyperlinkImplicitId { HyperlinkIdKind(HyperlinkImplicitId{ offset: id.offset }) }
		HyperlinkExplicitId {
			HyperlinkIdKind(HyperlinkExplicitId{ value: id.value.clone() })
		}
	}
}

fn hyperlink_ids_equal(a HyperlinkIdKind, b HyperlinkIdKind) bool {
	return match a {
		HyperlinkImplicitId {
			match b {
				HyperlinkImplicitId { a.offset == b.offset }
				else { false }
			}
		}
		HyperlinkExplicitId {
			match b {
				HyperlinkExplicitId { a.value == b.value }
				else { false }
			}
		}
	}
}

// HyperlinkPageEntry is the page-resident representation. In Ghostty the
// strings below are offset slices; in Witty they are owned strings because a
// Page itself is not a relocatable contiguous allocation.
pub type HyperlinkPageEntryIdKind = HyperlinkPageEntryExplicitId | HyperlinkPageEntryImplicitId

pub struct HyperlinkPageEntryExplicitId {
pub:
	value string
}

pub struct HyperlinkPageEntryImplicitId {
pub:
	offset u32
}

pub struct HyperlinkPageEntry {
pub:
	id  HyperlinkPageEntryIdKind
	uri string
}

pub fn HyperlinkPageEntry.from_hyperlink(link &Hyperlink) HyperlinkPageEntry {
	id := match link.id {
		HyperlinkImplicitId {
			HyperlinkPageEntryIdKind(HyperlinkPageEntryImplicitId{ offset: link.id.offset })
		}
		HyperlinkExplicitId {
			HyperlinkPageEntryIdKind(HyperlinkPageEntryExplicitId{ value: link.id.value.clone() })
		}
	}
	return HyperlinkPageEntry{
		id: id
		uri: link.uri.clone()
	}
}

pub fn (self &HyperlinkPageEntry) hyperlink() Hyperlink {
	id := match self.id {
		HyperlinkPageEntryImplicitId {
			HyperlinkIdKind(HyperlinkImplicitId{ offset: self.id.offset })
		}
		HyperlinkPageEntryExplicitId {
			HyperlinkIdKind(HyperlinkExplicitId{ value: self.id.value.clone() })
		}
	}
	return Hyperlink{
		id: id
		uri: self.uri.clone()
	}
}

pub fn (self &HyperlinkPageEntry) dupe() HyperlinkPageEntry {
	link := self.hyperlink()
	return HyperlinkPageEntry.from_hyperlink(&link)
}

// hash mirrors PageEntry.hash: active union tag, active payload, and URI are
// serialized exactly as Zig 0.15.2's autoHash/autoHashStrat(.Deep), then
// finalized with that Zig release's Wyhash implementation.
pub fn (self &HyperlinkPageEntry) hash() u64 {
	mut data := []u8{}
	match self.id {
		HyperlinkPageEntryImplicitId {
			// PageEntry.Id declares explicit first and implicit second, so the
			// synthesized u1 enum tag for implicit is one.
			data << u8(1)
			hyperlink_hash_put_u32(mut data, self.id.offset)
		}
		HyperlinkPageEntryExplicitId {
			data << u8(0)
			hyperlink_hash_put_slice(mut data, self.id.value)
		}
	}
	hyperlink_hash_put_slice(mut data, self.uri)
	return internal_hash.wyhash(data, 0)
}

pub fn (self &HyperlinkPageEntry) eql(other &HyperlinkPageEntry) bool {
	if self.uri != other.uri {
		return false
	}
	return match self.id {
		HyperlinkPageEntryImplicitId {
			match other.id {
				HyperlinkPageEntryImplicitId { self.id.offset == other.id.offset }
				else { false }
			}
		}
		HyperlinkPageEntryExplicitId {
			match other.id {
				HyperlinkPageEntryExplicitId { self.id.value == other.id.value }
				else { false }
			}
		}
	}
}

// V owns entry strings, so dropping the last reference is sufficient.
pub fn (self &HyperlinkPageEntry) free() {}

fn hyperlink_hash_put_u32(mut data []u8, value u32) {
	for shift in [u32(0), 8, 16, 24] {
		data << u8(value >> shift)
	}
}

fn hyperlink_hash_put_slice(mut data []u8, value string) {
	data << value.bytes()
	length := u64(value.len)
	for shift in [u32(0), 8, 16, 24, 32, 40, 48, 56] {
		data << u8(length >> shift)
	}
}

struct HyperlinkSetEntry {
mut:
	link            Hyperlink
	uri_offset      int = -1
	explicit_offset int = -1
	bucket          u16 = max_u16
	psl             u16
	ref_count       int
}

// HyperlinkSet is the page-local ref-counted set. Dead slots are reused and
// ID zero remains reserved, matching Ghostty's RefCountedSet specialization.
pub struct HyperlinkSet {
pub mut:
	entries      []HyperlinkSetEntry
	hash_table   []u16
	max_psl      u16
	psl_stats    [32]u16
	living       int
	next_id      u16 = 1
	layout       PageSetLayout
	string_alloc BitmapAllocator
}

pub fn HyperlinkSet.init() HyperlinkSet {
	return HyperlinkSet.init_bounded(page_set_layout(16, hyperlink_set_item_size, 8), bitmap_allocator_layout(int(string_bytes_default), string_chunk))
}

fn HyperlinkSet.init_bounded(set_layout PageSetLayout, string_layout BitmapAllocatorLayout) HyperlinkSet {
	return HyperlinkSet{
		entries: []HyperlinkSetEntry{len: int(set_layout.cap), init: HyperlinkSetEntry{}}
		hash_table: []u16{len: int(set_layout.table_cap)}
		layout: set_layout
		string_alloc: BitmapAllocator.init(string_chunk, string_layout)
	}
}

pub fn (self &HyperlinkSet) clone() HyperlinkSet {
	return HyperlinkSet{
		entries: self.entries.clone()
		hash_table: self.hash_table.clone()
		max_psl: self.max_psl
		psl_stats: self.psl_stats
		living: self.living
		next_id: self.next_id
		layout: self.layout
		string_alloc: BitmapAllocator{
			chunk_size: self.string_alloc.chunk_size
			bitmaps: self.string_alloc.bitmaps.clone()
			chunks: self.string_alloc.chunks.clone()
		}
	}
}

// add allocates the page-owned strings and adds the semantic hyperlink to the
// bounded ref-counted set. The returned ID owns one reference.
pub fn (mut self HyperlinkSet) add(link Hyperlink) !u32 {
	mut entry := self.allocate_entry(link)!
	for self.next_id > 1 && self.entries[int(self.next_id) - 1].ref_count == 0 {
		self.next_id--
		self.delete_item(self.next_id)
	}

	if id := self.lookup(&entry.link) {
		self.free_entry_strings(mut entry)
		self.entries[int(id)].ref_count++
		return id
	}

	if self.psl_stats[31] > 0 {
		self.free_entry_strings(mut entry)
		return error('set out of memory')
	}
	if int(self.next_id) >= int(self.layout.cap) {
		self.free_entry_strings(mut entry)
		if self.living < int(f64(self.layout.cap) * 0.9) {
			return error('set needs rehash')
		}
		return error('set out of memory')
	}

	id := self.insert(entry, self.next_id)
	self.entries[int(id)].ref_count++
	self.living++
	if id == self.next_id {
		self.next_id++
	}
	return u32(id)
}

// add_with_id adds a hyperlink while preferring the source page's ID. This is
// used when cloning/reflowing pages so the common case keeps stable IDs. If
// the requested slot is occupied by a different live link, normal allocation
// and deduplication determine the returned ID.
pub fn (mut self HyperlinkSet) add_with_id(link Hyperlink, preferred_id u32) !u32 {
	assert preferred_id > 0
	mut entry := self.allocate_entry(link)!

	if preferred_id < u32(self.next_id) {
		if self.entries[int(preferred_id)].ref_count == 0 {
			if self.psl_stats[31] > 0 {
				self.free_entry_strings(mut entry)
				return error('set out of memory')
			}
			self.delete_item(u16(preferred_id))
			added_id := self.upsert(entry, u16(preferred_id))
			self.entries[int(added_id)].ref_count++
			self.living++
			return u32(added_id)
		}
		if self.entries[int(preferred_id)].link.eql(&entry.link) {
			self.free_entry_strings(mut entry)
			self.entries[int(preferred_id)].ref_count++
			return preferred_id
		}
	}

	self.free_entry_strings(mut entry)
	return self.add(link)
}

pub fn (self &HyperlinkSet) lookup(link &Hyperlink) ?u32 {
	if self.layout.table_cap == 0 {
		return none
	}
	hash := HyperlinkPageEntry.from_hyperlink(link).hash()
	for i in 0 .. int(self.max_psl) + 1 {
		p := int((hash + u64(i)) & u64(self.layout.table_mask))
		id := self.hash_table[p]
		if id == 0 {
			return none
		}
		entry := self.entries[int(id)]
		if entry.psl < u16(i) {
			return none
		}
		if entry.psl == u16(i) && entry.ref_count > 0 && entry.link.eql(link) {
			return u32(id)
		}
	}
	return none
}

pub fn (mut self HyperlinkSet) use_link(id u32) {
	assert id > 0 && int(id) < self.entries.len
	assert self.entries[int(id)].ref_count > 0
	self.entries[int(id)].ref_count++
}

pub fn (mut self HyperlinkSet) release(id u32) {
	assert id > 0 && int(id) < self.entries.len
	mut entry := &self.entries[int(id)]
	assert entry.ref_count > 0
	entry.ref_count--
	if entry.ref_count == 0 {
		self.living--
	}
}

pub fn (self &HyperlinkSet) get(id u32) Hyperlink {
	assert id > 0 && int(id) < self.entries.len
	assert self.entries[int(id)].ref_count > 0
	return self.entries[int(id)].link
}

pub fn (self &HyperlinkSet) ref_count(id u32) int {
	if id == 0 || int(id) >= self.entries.len {
		return 0
	}
	return self.entries[int(id)].ref_count
}

pub fn (self &HyperlinkSet) count() int {
	return self.living
}

pub fn (self &HyperlinkSet) capacity() int {
	if self.layout.cap == 0 {
		return 0
	}
	return int(self.layout.cap) - 1
}

pub fn (self &HyperlinkSet) string_capacity() int {
	return self.string_alloc.capacity_bytes()
}

pub fn (self &HyperlinkSet) string_used() int {
	return self.string_alloc.used_bytes()
}

fn (mut self HyperlinkSet) can_allocate_string_bytes(byte_count int) bool {
	if byte_count == 0 {
		return true
	}
	offset := self.string_alloc.alloc(byte_count) or { return false }
	self.string_alloc.release(offset, byte_count)
	return true
}

fn (mut self HyperlinkSet) allocate_entry(link Hyperlink) !HyperlinkSetEntry {
	mut entry := HyperlinkSetEntry{
		link: link.dupe()
	}
	if link.uri.len > 0 {
		entry.uri_offset = self.string_alloc.alloc(link.uri.len) or {
			return error('strings out of memory')
		}
	}
	match link.id {
		HyperlinkExplicitId {
			if link.id.value.len > 0 {
				entry.explicit_offset = self.string_alloc.alloc(link.id.value.len) or {
					self.free_entry_strings(mut entry)
					return error('strings out of memory')
				}
			}
		}
		else {}
	}
	return entry
}

fn (mut self HyperlinkSet) free_entry_strings(mut entry HyperlinkSetEntry) {
	if entry.uri_offset >= 0 && entry.link.uri.len > 0 {
		self.string_alloc.release(entry.uri_offset, entry.link.uri.len)
		entry.uri_offset = -1
	}
	match entry.link.id {
		HyperlinkExplicitId {
			if entry.explicit_offset >= 0 && entry.link.id.value.len > 0 {
				self.string_alloc.release(entry.explicit_offset, entry.link.id.value.len)
				entry.explicit_offset = -1
			}
		}
		else {}
	}
}

fn (mut self HyperlinkSet) delete_item(id u16) {
	entry := self.entries[int(id)]
	if int(entry.bucket) >= int(self.layout.table_cap) {
		return
	}
	assert self.hash_table[int(entry.bucket)] == id
	mut removed := entry
	self.free_entry_strings(mut removed)
	self.psl_stats[int(entry.psl)]--
	self.hash_table[int(entry.bucket)] = 0
	self.entries[int(id)] = HyperlinkSetEntry{}

	mut p := int(entry.bucket)
	mut n := (p + 1) & int(self.layout.table_mask)
	for self.hash_table[n] != 0 && self.entries[int(self.hash_table[n])].psl > 0 {
		next_id := self.hash_table[n]
		self.entries[int(next_id)].bucket = u16(p)
		self.psl_stats[int(self.entries[int(next_id)].psl)]--
		self.entries[int(next_id)].psl--
		self.psl_stats[int(self.entries[int(next_id)].psl)]++
		self.hash_table[p] = next_id
		p = n
		n = (p + 1) & int(self.layout.table_mask)
	}
	for self.max_psl > 0 && self.psl_stats[int(self.max_psl)] == 0 {
		self.max_psl--
	}
	self.hash_table[p] = 0
}

fn (mut self HyperlinkSet) upsert(entry HyperlinkSetEntry, new_id u16) u16 {
	if id := self.lookup(&entry.link) {
		mut duplicate := entry
		self.free_entry_strings(mut duplicate)
		return u16(id)
	}
	return self.insert(entry, new_id)
}

fn (mut self HyperlinkSet) insert(entry HyperlinkSetEntry, new_id u16) u16 {
	hash := HyperlinkPageEntry.from_hyperlink(&entry.link).hash()
	mut held_id := new_id
	mut held_psl := u16(0)
	mut held_ref := 0
	mut chosen_id := new_id
	mut new_bucket := u16(0)
	mut new_psl := u16(0)

	for i in 0 .. int(self.layout.table_cap) - 1 {
		p := u16((hash + u64(i)) & u64(self.layout.table_mask))
		id := self.hash_table[int(p)]
		if id == 0 {
			self.hash_table[int(p)] = held_id
			if held_id == new_id {
				new_bucket = p
				new_psl = held_psl
			} else {
				self.entries[int(held_id)].bucket = p
			}
			self.psl_stats[int(held_psl)]++
			if held_psl > self.max_psl {
				self.max_psl = held_psl
			}
			break
		}

		item_ref := self.entries[int(id)].ref_count
		item_psl := self.entries[int(id)].psl
		if item_ref == 0 {
			mut dead := self.entries[int(id)]
			self.free_entry_strings(mut dead)
			self.psl_stats[int(item_psl)]--
			self.entries[int(id)] = HyperlinkSetEntry{}
			if id < new_id {
				chosen_id = id
			}
			self.hash_table[int(p)] = held_id
			if held_id == new_id {
				new_bucket = p
				new_psl = held_psl
			} else {
				self.entries[int(held_id)].bucket = p
			}
			self.psl_stats[int(held_psl)]++
			if held_psl > self.max_psl {
				self.max_psl = held_psl
			}
			break
		}

		if item_psl < held_psl || (item_psl == held_psl && item_ref < held_ref) {
			self.hash_table[int(p)] = held_id
			if held_id == new_id {
				new_bucket = p
				new_psl = held_psl
			} else {
				self.entries[int(held_id)].bucket = p
			}
			self.psl_stats[int(held_psl)]++
			if held_psl > self.max_psl {
				self.max_psl = held_psl
			}
			held_id = id
			held_ref = item_ref
			self.psl_stats[int(item_psl)]--
			held_psl = item_psl
		}
		held_psl++
	}

	self.hash_table[int(new_bucket)] = chosen_id
	mut placed := entry
	placed.bucket = new_bucket
	placed.psl = new_psl
	placed.ref_count = 0
	self.entries[int(chosen_id)] = placed
	return chosen_id
}

pub fn HyperlinkSet.capacity_for_count(count int) int {
	return rcs_capacity_for_count(count)
}

// Pages use a sparse mapping from a cell offset to the page-local link ID.
pub type HyperlinkMap = map[u64]HyperlinkId
