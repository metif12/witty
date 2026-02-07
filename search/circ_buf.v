module search

// Circular buffer implementations for the search sliding window.
//
// DataBuf stores encoded page text (bytes) and MetaBuf stores page
// metadata entries. Both support efficient O(1) append-at-end and
// delete-from-front operations.

import terminal
import highlight

// ============================================================
// ByteSlices - return type for DataBuf.get_ptr_slice
// ============================================================

// ByteSlices holds two contiguous slices from a circular buffer.
// The first slice covers data before the wrap point, the second
// covers data after the wrap (empty if no wrap occurs).
struct ByteSlices {
	first  []u8
	second []u8
}

// ============================================================
// Meta - metadata for a page node in the sliding window
// ============================================================

// Meta stores metadata about a single page node that has been
// added to the sliding window. The cell_map maps each byte position
// in the encoded text back to a cell coordinate in the page.
struct Meta {
mut:
	// The page node this metadata is for.
	node &terminal.PageNode = unsafe { nil }
	// The serial number of the node at append time.
	serial u64
	// Maps each byte in the encoded text to its cell coordinate.
	// cell_map[i] gives the (x, y) position of the i-th encoded byte.
	cell_map []highlight.Coordinate
}

// ============================================================
// DataBuf - circular buffer of bytes
// ============================================================

// DataBuf is a circular buffer of u8 that contains the encoded page
// text that we can use to search for the needle.
struct DataBuf {
mut:
	storage []u8
	head    int
	count   int
}

fn DataBuf.new() DataBuf {
	return DataBuf{}
}

fn (self &DataBuf) len() int {
	return self.count
}

fn (self &DataBuf) capacity() int {
	return self.storage.len
}

fn (mut self DataBuf) clear() {
	self.head = 0
	self.count = 0
}

// Ensure there is unused capacity for at least `additional` more bytes.
fn (mut self DataBuf) ensure_unused_capacity(additional int) {
	needed := self.count + additional
	if needed <= self.storage.len {
		return
	}
	self.grow(needed)
}

// Append a slice of bytes, assuming capacity is sufficient.
fn (mut self DataBuf) append_slice_assume_capacity(items []u8) {
	for item in items {
		idx := (self.head + self.count) % self.storage.len
		self.storage[idx] = item
		self.count += 1
	}
}

// Delete the oldest n bytes from the front of the buffer.
fn (mut self DataBuf) delete_oldest(n int) {
	assert n <= self.count, 'DataBuf.delete_oldest: n=${n} > count=${self.count}'
	self.head = (self.head + n) % self.storage.len
	self.count -= n
}

// Get the byte at position i (0-based from the logical start).
fn (self &DataBuf) get(i int) u8 {
	idx := (self.head + i) % self.storage.len
	return self.storage[idx]
}

// Get two contiguous slices covering the range [offset, offset+length).
// The first slice is before any wrap point, the second is after the wrap.
// If no wrap occurs, the second slice is empty.
fn (self &DataBuf) get_ptr_slice(offset int, length int) ByteSlices {
	if length == 0 || self.storage.len == 0 {
		return ByteSlices{}
	}
	cap := self.storage.len
	start := (self.head + offset) % cap
	if start + length <= cap {
		// No wrap
		return ByteSlices{
			first: self.storage[start..start + length]
		}
	}
	// Wraps around
	first_len := cap - start
	return ByteSlices{
		first: self.storage[start..cap]
		second: self.storage[0..length - first_len]
	}
}

// Grow internal storage to at least the given capacity.
fn (mut self DataBuf) grow(min_cap int) {
	new_cap := if self.storage.len == 0 {
		if min_cap > 8 { min_cap } else { 8 }
	} else {
		mut c := self.storage.len * 2
		for c < min_cap {
			c *= 2
		}
		c
	}
	mut new_storage := []u8{len: new_cap}
	for i in 0 .. self.count {
		old_idx := (self.head + i) % self.storage.len
		new_storage[i] = self.storage[old_idx]
	}
	self.storage = new_storage
	self.head = 0
}

// ============================================================
// MetaBuf - circular buffer of Meta entries
// ============================================================

// MetaBuf is a circular buffer that contains metadata about the
// pages being searched. This usually isn't that large so callers
// must iterate through it to find the offset to map data to meta.
struct MetaBuf {
mut:
	storage []Meta
	head    int
	count   int
}

fn MetaBuf.new() MetaBuf {
	return MetaBuf{}
}

fn (self &MetaBuf) len() int {
	return self.count
}

fn (self &MetaBuf) capacity() int {
	return self.storage.len
}

fn (mut self MetaBuf) clear() {
	self.head = 0
	self.count = 0
}

// Ensure there is unused capacity for at least `additional` more entries.
fn (mut self MetaBuf) ensure_unused_capacity(additional int) {
	needed := self.count + additional
	if needed <= self.storage.len {
		return
	}
	self.grow(needed)
}

// Append a Meta entry, assuming capacity is sufficient.
fn (mut self MetaBuf) append_assume_capacity(val Meta) {
	idx := (self.head + self.count) % self.storage.len
	self.storage[idx] = val
	self.count += 1
}

// Delete the oldest n entries from the front.
fn (mut self MetaBuf) delete_oldest(n int) {
	assert n <= self.count, 'MetaBuf.delete_oldest: n=${n} > count=${self.count}'
	self.head = (self.head + n) % self.storage.len
	self.count -= n
}

// Get the Meta entry at position i (0-based from logical start).
fn (self &MetaBuf) get(i int) Meta {
	idx := (self.head + i) % self.storage.len
	return self.storage[idx]
}

// Grow internal storage to at least the given capacity.
fn (mut self MetaBuf) grow(min_cap int) {
	new_cap := if self.storage.len == 0 {
		if min_cap > 8 { min_cap } else { 8 }
	} else {
		mut c := self.storage.len * 2
		for c < min_cap {
			c *= 2
		}
		c
	}
	mut new_storage := []Meta{len: new_cap}
	for i in 0 .. self.count {
		old_idx := (self.head + i) % self.storage.len
		new_storage[i] = self.storage[old_idx]
	}
	self.storage = new_storage
	self.head = 0
}
