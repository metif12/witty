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
		id:  hyperlink_id_dupe(self.id)
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
		id:  id
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
		id:  id
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

// PageEntry's source native representation: an offset slice/implicit ID
// union plus its u1 tag (24 bytes), followed by the URI offset slice.
struct StoredHyperlink {
mut:
	id_len      uint
	id_offset   u32
	id_padding  u32
	id_tag      u8
	padding     [7]u8
	uri_len     uint
	uri_offset  u32
	uri_padding u32
}

fn borrowed_string(base &u8, offset u32, len uint) string {
	return unsafe { string{ str: base + offset, len: int(len), is_lit: 1 } }
}

fn (entry StoredHyperlink) hyperlink(base &u8) Hyperlink {
	id := if entry.id_tag == 0 {
		HyperlinkIdKind(HyperlinkExplicitId{ value: borrowed_string(base, entry.id_offset, entry.id_len) })
	} else {
		HyperlinkIdKind(HyperlinkImplicitId{ offset: u32(entry.id_len) })
	}
	return Hyperlink{ id: id, uri: borrowed_string(base, entry.uri_offset, entry.uri_len) }
}

fn hyperlink_value_hash(link Hyperlink) u64 {
	id := match link.id {
		HyperlinkExplicitId {
			HyperlinkPageEntryIdKind(HyperlinkPageEntryExplicitId{ value: link.id.value })
		}
		HyperlinkImplicitId {
			HyperlinkPageEntryIdKind(HyperlinkPageEntryImplicitId{ offset: link.id.offset })
		}
	}
	return HyperlinkPageEntry{ id: id, uri: link.uri }.hash()
}

struct StoredHyperlinkContext {
	base        &u8 = unsafe { nil }
	strings     BitmapAllocator
	lookup_link ?Hyperlink
}

fn (context StoredHyperlinkContext) hash(entry StoredHyperlink) u64 {
	link := context.lookup_link or { entry.hyperlink(context.base) }
	return hyperlink_value_hash(link)
}

fn (context StoredHyperlinkContext) eql(a StoredHyperlink, b StoredHyperlink) bool {
	left := context.lookup_link or { a.hyperlink(context.base) }
	right := b.hyperlink(context.base)
	return left.eql(&right)
}

fn (context StoredHyperlinkContext) deleted(entry StoredHyperlink) {
	mut strings := context.strings
	if entry.id_tag == 0 && entry.id_len > 0 {
		strings.release(uint(entry.id_offset) - uint(strings.chunks_offset.offset), entry.id_len)
	}
	if entry.uri_len > 0 {
		strings.release(uint(entry.uri_offset) - uint(strings.chunks_offset.offset), entry.uri_len)
	}
}

pub struct HyperlinkSet {
pub mut:
	set          GenericRefCountedSet[StoredHyperlink, u16, u16, StoredHyperlinkContext]
	layout       PageSetLayout
	string_alloc BitmapAllocator
	base         &u8 = unsafe { nil }
	// Compatibility standalone test initialization retains its backing owner.
	owned []u64
}

pub fn HyperlinkSet.init() HyperlinkSet {
	return HyperlinkSet.init_bounded(page_set_layout(16, hyperlink_set_item_size, 8), bitmap_allocator_layout(uint(string_bytes_default), string_chunk))
}

fn HyperlinkSet.init_bounded(layout PageSetLayout, strings BitmapAllocatorLayout) HyperlinkSet {
	start := page_align_forward(layout.total_size, 8)
	owned := []u64{len: int((start + strings.total_size + 7) / 8)}
	buf := OffsetBuf.init(unsafe { &u8(owned.data) })
	mut result := hyperlink_set_init_buf(buf, layout, buf.add(start), strings)
	result.owned = owned
	return result
}

fn hyperlink_set_init_buf(buf OffsetBuf, layout PageSetLayout, string_buf OffsetBuf, strings BitmapAllocatorLayout) HyperlinkSet {
	assert sizeof(GenericRefSetItem[StoredHyperlink, u16, u16]) == hyperlink_set_item_size
	allocator := BitmapAllocator.init_buf(string_chunk, string_buf, strings)
	context := StoredHyperlinkContext{ base: buf.base, strings: allocator }
	native := GenericRefSetLayout[u16]{ cap: layout.cap, table_cap: layout.table_cap, table_mask: u16(layout.table_mask), table_start: layout.table_start, items_start: layout.items_start, total_size: layout.total_size }
	return HyperlinkSet{ set: generic_ref_set_init[StoredHyperlink, u16, u16, StoredHyperlinkContext](buf, native, context), layout: layout, string_alloc: allocator, base: buf.base }
}

fn (mut self HyperlinkSet) rebind(base &u8) {
	self.base = unsafe { base }
	self.string_alloc.rebind(base)
	self.set.context = StoredHyperlinkContext{ base: unsafe { base }, strings: self.string_alloc }
}

fn (mut self HyperlinkSet) allocate_entry(link Hyperlink) !StoredHyperlink {
	mut entry := StoredHyperlink{ id_tag: 1 }
	if link.uri.len > 0 {
		offset := self.string_alloc.alloc(uint(link.uri.len)) or { return error('strings out of memory') }
		unsafe { vmemcpy(&self.string_alloc.chunks[offset], link.uri.str, link.uri.len) }
		entry.uri_offset = u32(self.string_alloc.chunks_offset.offset) + u32(offset)
		entry.uri_len = uint(link.uri.len)
	}
	match link.id {
		HyperlinkImplicitId { entry.id_len = uint(link.id.offset) }
		HyperlinkExplicitId {
			entry.id_tag = 0
			if link.id.value.len > 0 {
				offset := self.string_alloc.alloc(uint(link.id.value.len)) or {
					self.set.context.deleted(entry)
					return error('strings out of memory')
				}
				unsafe { vmemcpy(&self.string_alloc.chunks[offset], link.id.value.str, link.id.value.len) }
				entry.id_offset = u32(self.string_alloc.chunks_offset.offset) + u32(offset)
				entry.id_len = uint(link.id.value.len)
			}
		}
	}
	return entry
}

fn hyperlink_set_error(err IError) IError {
	return if err.msg() == 'needs rehash' {
		error('set needs rehash')
	} else {
		error('set out of memory')
	}
}

pub fn (mut self HyperlinkSet) add(link Hyperlink) !HyperlinkId {
	entry := self.allocate_entry(link)!
	return HyperlinkId(self.set.add(self.base, entry) or {
		self.set.context.deleted(entry)
		return hyperlink_set_error(err)
	})
}

pub fn (mut self HyperlinkSet) add_with_id(link Hyperlink, id HyperlinkId) !HyperlinkId {
	assert id > 0
	entry := self.allocate_entry(link)!
	result := self.set.add_with_id(self.base, entry, u16(id)) or {
		self.set.context.deleted(entry)
		return hyperlink_set_error(err)
	}
	return HyperlinkId(result.id)
}

pub fn (self &HyperlinkSet) lookup(link &Hyperlink) ?HyperlinkId {
	context := StoredHyperlinkContext{ base: self.base, strings: self.string_alloc, lookup_link: *link }
	id := self.set.lookup_context(self.base, StoredHyperlink{}, context) or { return none }
	return HyperlinkId(id)
}

pub fn (mut self HyperlinkSet) use_link(id HyperlinkId) { self.set.use_item(self.base, u16(id)) }

pub fn (mut self HyperlinkSet) release(id HyperlinkId) { self.set.release(self.base, u16(id)) }

pub fn (self &HyperlinkSet) get(id HyperlinkId) Hyperlink {
	return self.set.get(self.base, u16(id)).hyperlink(self.base)
}

pub fn (self &HyperlinkSet) ref_count(id HyperlinkId) u16 {
	return self.set.ref_count(self.base, u16(id))
}

pub fn (self &HyperlinkSet) live_ids() []HyperlinkId {
	mut ids := []HyperlinkId{}
	for id, item in self.set.items_view(self.base) {
		if id > 0 && item.meta.ref_count > 0 { ids << HyperlinkId(id) }
	}
	return ids
}

pub fn (self &HyperlinkSet) count() uint { return self.set.count() }

pub fn (self &HyperlinkSet) capacity() uint { return self.layout.cap - 1 }

pub fn (self &HyperlinkSet) string_capacity() uint { return self.string_alloc.capacity_bytes() }

pub fn (self &HyperlinkSet) string_used() uint { return self.string_alloc.used_bytes() }

pub fn HyperlinkSet.capacity_for_count(count uint) uint { return rcs_capacity_for_count(count) }

fn (mut self HyperlinkSet) can_allocate_string_bytes(bytes uint) bool {
	if bytes == 0 { return true }
	offset := self.string_alloc.alloc(bytes) or { return false }
	self.string_alloc.release(offset, bytes)
	return true
}
