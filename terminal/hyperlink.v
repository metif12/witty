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
	link      Hyperlink
	ref_count int
	in_use    bool
}

// HyperlinkSet is the page-local ref-counted set. Dead slots are reused and
// ID zero remains reserved, matching Ghostty's RefCountedSet specialization.
pub struct HyperlinkSet {
pub mut:
	entries []HyperlinkSetEntry
}

pub fn HyperlinkSet.init() HyperlinkSet {
	return HyperlinkSet{
		entries: [HyperlinkSetEntry{}]
	}
}

// add returns an existing semantic link ID or stores a duplicate in a free
// slot. The returned ID owns one reference.
pub fn (mut self HyperlinkSet) add(link Hyperlink) u32 {
	for i := 1; i < self.entries.len; i++ {
		if self.entries[i].in_use && self.entries[i].link.eql(&link) {
			self.entries[i].ref_count++
			return u32(i)
		}
	}

	for i := 1; i < self.entries.len; i++ {
		if !self.entries[i].in_use {
			self.entries[i] = HyperlinkSetEntry{
				link: link.dupe()
				ref_count: 1
				in_use: true
			}
			return u32(i)
		}
	}

	self.entries << HyperlinkSetEntry{
		link: link.dupe()
		ref_count: 1
		in_use: true
	}
	return u32(self.entries.len - 1)
}

// add_with_id adds a hyperlink while preferring the source page's ID. This is
// used when cloning/reflowing pages so the common case keeps stable IDs. If
// the requested slot is occupied by a different live link, normal allocation
// and deduplication determine the returned ID.
pub fn (mut self HyperlinkSet) add_with_id(link Hyperlink, preferred_id u32) u32 {
	assert preferred_id > 0

	// Upsert semantics take precedence over the preferred slot: if the same
	// hyperlink is already live under another ID, reuse it and increment its
	// reference count instead of creating a duplicate entry.
	if existing := self.lookup(&link) {
		self.use_link(existing)
		return existing
	}

	if int(preferred_id) < self.entries.len {
		mut entry := &self.entries[int(preferred_id)]
		if !entry.in_use {
			entry.link = link.dupe()
			entry.ref_count = 1
			entry.in_use = true
			return preferred_id
		}
	}

	return self.add(link)
}

pub fn (self &HyperlinkSet) lookup(link &Hyperlink) ?u32 {
	for i := 1; i < self.entries.len; i++ {
		if self.entries[i].in_use && self.entries[i].link.eql(link) {
			return u32(i)
		}
	}
	return none
}

pub fn (mut self HyperlinkSet) use_link(id u32) {
	assert id > 0 && int(id) < self.entries.len
	assert self.entries[int(id)].in_use
	self.entries[int(id)].ref_count++
}

pub fn (mut self HyperlinkSet) release(id u32) {
	assert id > 0 && int(id) < self.entries.len
	mut entry := &self.entries[int(id)]
	assert entry.in_use && entry.ref_count > 0
	entry.ref_count--
	if entry.ref_count == 0 {
		entry.link.deinit()
		entry.link = Hyperlink{}
		entry.in_use = false
	}
}

pub fn (self &HyperlinkSet) get(id u32) Hyperlink {
	assert id > 0 && int(id) < self.entries.len
	assert self.entries[int(id)].in_use
	return self.entries[int(id)].link
}

pub fn (self &HyperlinkSet) ref_count(id u32) int {
	if id == 0 || int(id) >= self.entries.len || !self.entries[int(id)].in_use {
		return 0
	}
	return self.entries[int(id)].ref_count
}

pub fn (self &HyperlinkSet) count() int {
	mut result := 0
	for i := 1; i < self.entries.len; i++ {
		if self.entries[i].in_use {
			result++
		}
	}
	return result
}

pub fn HyperlinkSet.capacity_for_count(count int) int {
	return rcs_capacity_for_count(count)
}

// Pages use a sparse mapping from a cell offset to the page-local link ID.
pub type HyperlinkMap = map[u64]HyperlinkId
