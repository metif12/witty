module terminal

// hyperlink.v - Hyperlink types for the terminal emulator.
//
// Translated from Ghostty's terminal/hyperlink.zig.
//
// Contains:
// - HyperlinkId type alias (u16)
// - Hyperlink struct with id (explicit string / implicit offset) and uri string
// - HyperlinkPageEntry struct - page-resident hyperlink with offset-based storage
// - HyperlinkSet type - ref-counted set of hyperlinks
//
// The complex offset-based storage and RefCountedSet parts are stubbed
// as XTODO since they require the full page memory management system.

// ============================================================
// HyperlinkId - the unique identifier for a hyperlink.
// ============================================================

// HyperlinkId is the unique identifier for a hyperlink. This is at most
// the number of cells that can fit in a single terminal page, since each
// cell can only contain at most one hyperlink.
pub type HyperlinkId = u16

// ============================================================
// HyperlinkIdKind - the kind of hyperlink id (explicit or implicit).
// ============================================================

// HyperlinkIdKind represents whether a hyperlink ID was explicitly
// provided via the OSC 8 sequence or implicitly generated.
pub type HyperlinkIdKind = HyperlinkExplicitId | HyperlinkImplicitId

// HyperlinkExplicitId is an explicitly provided ID via the OSC8 sequence.
pub struct HyperlinkExplicitId {
pub:
	value string
}

// HyperlinkImplicitId is an auto-generated ID based on an incrementing
// counter attached to the screen. No ID was provided so we auto-generate
// the ID based on an incrementing counter.
pub struct HyperlinkImplicitId {
pub:
	offset u32
}

// ============================================================
// Hyperlink - a fully decoded hyperlink that may or may not have
// its memory within a page.
// ============================================================

// Hyperlink is a fully decoded hyperlink that may or may not have its
// memory within a page. The memory location of this is dependent
// on the context so users should check with the source of the
// hyperlink.
pub struct Hyperlink {
pub mut:
	id  HyperlinkIdKind
	uri string
}

// deinit deallocates all the pointers in the hyperlink.
//
// WARNING: This should only be called if the hyperlink was
// heap-allocated. This DOES NOT need to be unconditionally called.
pub fn (self &Hyperlink) deinit() {
	// In V, strings are managed by the GC, so there's nothing
	// explicit to free here. This method exists for API compatibility.
	// The GC will handle deallocation.
}

// dupe duplicates a hyperlink by cloning all values.
// The returned hyperlink should have deinit called when done.
pub fn (self &Hyperlink) dupe() Hyperlink {
	new_id := match self.id {
		HyperlinkImplicitId {
			HyperlinkIdKind(self.id)
		}
		HyperlinkExplicitId {
			HyperlinkIdKind(HyperlinkExplicitId{
				value: self.id.value.clone()
			})
		}
	}
	return Hyperlink{
		id: new_id
		uri: self.uri.clone()
	}
}

// eql compares the logical hyperlink identity and target.
pub fn (self &Hyperlink) eql(other &Hyperlink) bool {
	if self.uri != other.uri {
		return false
	}
	return match self.id {
		HyperlinkImplicitId {
			match other.id {
				HyperlinkImplicitId { self.id.offset == other.id.offset }
				else { false }
			}
		}
		HyperlinkExplicitId {
			match other.id {
				HyperlinkExplicitId { self.id.value == other.id.value }
				else { false }
			}
		}
	}
}

// ============================================================
// HyperlinkPageEntry - a hyperlink that has been committed to
// page memory. This is a "page entry" because while it represents
// a hyperlink, some decoding (pointer chasing) is still necessary
// to get the fully realized ID, URI, etc.
// ============================================================

// HyperlinkPageEntryIdKind represents the kind of page-entry hyperlink id.
pub type HyperlinkPageEntryIdKind = HyperlinkPageEntryExplicitId | HyperlinkPageEntryImplicitId

// HyperlinkPageEntryExplicitId is an explicitly provided ID via the OSC8 sequence,
// stored as an offset/length slice into page memory.
pub struct HyperlinkPageEntryExplicitId {
pub:
	offset u32
	len    u32
}

// HyperlinkPageEntryImplicitId is an auto-generated ID based on an incrementing
// counter. No ID was provided so we auto-generate it.
pub struct HyperlinkPageEntryImplicitId {
pub:
	offset u32
}

// HyperlinkPageEntry is a hyperlink that has been committed to page memory.
// While it represents a hyperlink, some decoding (pointer chasing) is still
// necessary to get the fully realized ID, URI, etc.
pub struct HyperlinkPageEntry {
pub mut:
	id         HyperlinkPageEntryIdKind
	uri_offset u32
	uri_len    u32
}

// dupe duplicates this hyperlink from one page to another.
// XTODO: Full page-to-page duplication requires page memory management.
pub fn (self &HyperlinkPageEntry) dupe() HyperlinkPageEntry {
	// Shallow copy for now since we don't have page memory management.
	return HyperlinkPageEntry{
		id: self.id
		uri_offset: self.uri_offset
		uri_len: self.uri_len
	}
}

// hash computes a hash of this page entry.
// XTODO: Full implementation requires page memory base pointer
// for resolving offset-based strings.
pub fn (self &HyperlinkPageEntry) hash() u64 {
	// Simplified hash using the raw offset/length values.
	mut h := u64(0)
	match self.id {
		HyperlinkPageEntryImplicitId {
			h = u64(self.id.offset) * 31
		}
		HyperlinkPageEntryExplicitId {
			h = (u64(self.id.offset) * 31 + u64(self.id.len)) * 31
		}
	}
	h = h * 31 + u64(self.uri_offset)
	h = h * 31 + u64(self.uri_len)
	return h
}

// eql checks equality between two page entries.
// XTODO: Full implementation requires page memory base pointers
// for resolving offset-based strings.
pub fn (self &HyperlinkPageEntry) eql(other &HyperlinkPageEntry) bool {
	// Check that the id kinds match
	match self.id {
		HyperlinkPageEntryImplicitId {
			match other.id {
				HyperlinkPageEntryImplicitId {
					if self.id.offset != other.id.offset {
						return false
					}
				}
				else {
					return false
				}
			}
		}
		HyperlinkPageEntryExplicitId {
			match other.id {
				HyperlinkPageEntryExplicitId {
					if self.id.offset != other.id.offset || self.id.len != other.id.len {
						return false
					}
				}
				else {
					return false
				}
			}
		}
	}
	return self.uri_offset == other.uri_offset && self.uri_len == other.uri_len
}

// free frees the memory for this entry from its page.
// XTODO: Full implementation requires page string allocator.
pub fn (self &HyperlinkPageEntry) free() {
	// In V with GC, nothing to free explicitly.
	// XTODO: When page memory management is implemented,
	// this should free the string allocator entries.
}

// ============================================================
// HyperlinkSet - the set of hyperlinks. This is ref-counted so
// that a set of cells can share the same hyperlink without
// duplicating the data.
// ============================================================

// HyperlinkSet is a ref-counted set of hyperlinks for a page.
// XTODO: Full implementation requires RefCountedSet which is
// a complex data structure with offset-based storage.
pub struct HyperlinkSet {
pub mut:
	// XTODO: The actual storage would be a RefCountedSet(HyperlinkPageEntry, ...)
	// For now this is a stub.
	entries []HyperlinkPageEntry
}

// HyperlinkMap is the mapping of cell to hyperlink. We use a map to save space
// since it's very unlikely a cell is a hyperlink, so it's a waste to store
// the hyperlink ID in the cell itself.
// XTODO: In the Zig version this is an AutoOffsetHashMap(Offset(Cell), Id).
pub type HyperlinkMap = map[u32]HyperlinkId
