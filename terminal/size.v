module terminal

// Fundamental integer type aliases and offset-based memory types.
// Translated from Ghostty's terminal/size.zig.
//
// These types define the maximum sizes of various terminal data structures
// and provide offset-based memory addressing for page-level storage.

// ============================================================
// Maximum page size and derived types
// ============================================================

// The maximum size of a page in bytes. We use u32 here because
// 4GB is a reasonable page size limit. To support better
// configurability, we derive everything from this.
pub const max_page_size = u32(0xFFFFFFFF)

// The int type that can contain the maximum memory offset in bytes,
// derived from the maximum terminal page size.
// In Zig this is OffsetInt = IntFittingRange(0, max_page_size - 1) = u32.
// We represent this as a type alias concept via constants.
pub const offset_int_max = u32(0xFFFFFFFF)

// ============================================================
// Int types for maximum values
// ============================================================

// Total number of cells that are possible in each dimension (row/col).
// Based on 2^16 being enough for any reasonable terminal size and allowing
// IDs to remain 16-bit.
// In Zig: CellCountInt = u16.
pub const cell_count_int_max = u16(65535)

// Total number of styles that are possible in a page.
// We match CellCountInt here because each cell in a single row can have at
// most one style, making it simple to split a page by splitting rows.
//
// Note due to the way RefCountedSet works, we are short one value, but
// this is a theoretical limit we accept. A page with a single row max
// columns wide would be one short of having every cell have a unique style.
// In Zig: StyleCountInt = CellCountInt = u16.
pub const style_count_int_max = u16(65535)

// Total number of hyperlinks that are possible in a page.
// In Zig: HyperlinkCountInt = CellCountInt = u16.
pub const hyperlink_count_int_max = u16(65535)

// Total number of bytes that can be taken up by grapheme data.
// Technically unlimited with malicious input, but we choose a
// reasonable limit of 2^32 (4GB).
// In Zig: GraphemeBytesInt = u32.
pub const grapheme_bytes_int_max = u32(0xFFFFFFFF)

// Total number of bytes that can be taken up by string data.
// In Zig: StringBytesInt = u32.
pub const string_bytes_int_max = u32(0xFFFFFFFF)

// ============================================================
// Offset - typed offset from a base address
// ============================================================

// Offset represents a typed offset from the base address of a page
// to the start of some data. In Zig this is a generic packed struct
// parameterized by type T; in V we use a simple struct since V does
// not have generics over types in the same way.
//
// The offset is always in bytes from the "true base" of the allocation.
pub struct Offset {
pub mut:
	offset u32
}

// OffsetSlice represents a slice of data stored via a base offset and
// length. In Zig this is Offset(T).Slice; here we simplify since V
// does not have the same pointer arithmetic model.
pub struct OffsetSlice {
pub mut:
	offset Offset
	len    int
}

// ============================================================
// OffsetBuf - a buffer that is offset from some base pointer
// ============================================================

// OffsetBuf represents a buffer that is offset from some base pointer.
// Offset-based structures should use this as their initialization
// parameter so that they can know what segment of memory they own
// while at the same time initializing their offset fields to be
// against the true base.
//
// The term "true base" is used to describe the base address of
// the allocation, which i.e. can include memory that you do NOT
// own and is used by some other structures. All offsets are against
// this "true base" so that to determine addresses structures don't
// need to add up all the intermediary offsets.
pub struct OffsetBuf {
pub mut:
	// The true base pointer to the backing memory. This is
	// "byte zero" of the allocation. This plus the offset make
	// it easy to pass in the base pointer in all usage to this
	// structure and the offsets are correct.
	base &u8 = unsafe { nil }

	// Offset from base where the beginning of /this/ data
	// structure is located. We use this so that we can slowly
	// build up a chain of offset-based structures but always
	// have the base pointer sent into functions be the true base.
	offset int
}

// Initialize a zero-offset buffer from a base pointer.
pub fn OffsetBuf.init(base &u8) OffsetBuf {
	return OffsetBuf{
		base: base
		offset: 0
	}
}

// Initialize from some base pointer and offset.
pub fn OffsetBuf.init_offset(base &u8, offset int) OffsetBuf {
	return OffsetBuf{
		base: base
		offset: offset
	}
}

// The base address for the start of the data for the user
// of this OffsetBuf. This is where your data structure should
// begin; anything before this is NOT your memory.
// XTODO: Returns a raw pointer. In V, pointer arithmetic is unsafe
// and not idiomatic. This is a low-level memory layout helper.
pub fn (self OffsetBuf) start() &u8 {
	return unsafe { self.base + self.offset }
}

// Returns an Offset calculation for some child member of
// your struct. The offset is against the true base pointer
// so that future callers can pass that in as the base.
pub fn (self OffsetBuf) member(len int) Offset {
	return Offset{
		offset: u32(self.offset + len)
	}
}

// Add an offset to the current offset.
pub fn (self OffsetBuf) add(extra int) OffsetBuf {
	return OffsetBuf{
		base: self.base
		offset: self.offset + extra
	}
}

// Rebase the offset to have a zero offset by rebasing onto start.
// This is similar to `add` but all of the offsets are merged into base.
pub fn (self OffsetBuf) rebase(extra int) OffsetBuf {
	return OffsetBuf{
		base: unsafe { self.start() + extra }
		offset: 0
	}
}

// ============================================================
// getOffset - compute the offset between a base and a pointer
// ============================================================

// Get the offset for a given type from some base pointer to the
// actual pointer to the type.
// XTODO: This requires pointer arithmetic which is unsafe in V.
// In practice, this is used internally by page-level memory management.
pub fn get_offset(base &u8, ptr &u8) Offset {
	base_int := u64(base)
	ptr_int := u64(ptr)
	return Offset{
		offset: u32(ptr_int - base_int)
	}
}
