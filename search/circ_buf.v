module search

// --- Original Ghostty Comments Start: src/datastruct/circ_buf.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/datastruct/circ_buf.zig
//
// Returns a circular buffer containing type T.
// Implementation note: there's a lot of unsafe addition of usize
// here in this implementation that can technically overflow. If someone
// wants to fix this and make it overflow safe (use subtractions for
// checks prior to additions) then I welcome it. In reality, we'd
// have to be a really, really large terminal screen to even worry
// about this so I'm punting it.
// We could remove this and just use math with head/tail to figure
// it out, but our usage of circular buffers stores so much data that
// this minor overhead is not worth optimizing out.
// Get our index from the tail
// Translate the tail index to a storage index
// Seek the iterator by a given amount. This will clamp
// the values to the bounds of the buffer so overflows are
// not possible.
// Reset the iterator back to the first value.
// Initialize a new circular buffer that can store size elements.
// Append a single value to the buffer. If the buffer is full,
// an error will be returned.
// Append a single value to the buffer, assuming there is capacity.
// Append a slice to the buffer.
// Clear the buffer.
// Iterate over the circular buffer.
// Get the first (oldest) value in the buffer.
// Note: this can be more efficient by not using the
// iterator, but this was an easy way to implement it.
// Get the last (newest) value in the buffer.
// Note: this can be more efficient by not using the
// iterator, but this was an easy way to implement it.
// Ensures that there is enough capacity to store amount more
// items via append.
// Resize the buffer to the given size (larger or smaller).
// If larger, new values will be set to the default value.
// Rotate to zero so it is aligned.
// Reallocate, this adds to the end so we're ready to go.
// If we grew, we need to set our new defaults. We can add it
// at the end since we rotated to start.
// Fix up our head/tail
// Rotate the data so that it is zero-aligned.
// If we're already at zero then do nothing.
// We use std.mem.rotate to rotate our storage in-place.
// Then fix up our head and tail.
// Returns if the buffer is currently empty. To check if its
// full, just check the "full" attribute.
// Returns the total capacity allocated for this buffer.
// Returns the length in elements that are used.
// Delete the oldest n values from the buffer. If there are less
// than n values in the buffer, it'll delete everything.
// Special case n == 0 otherwise we will accidentally break
// our circular buffer.
// Clear the values back to default
// If we're not full, we can just advance the tail. We know
// it'll be less than the length because otherwise we'd be full.
// Returns a pointer to the value at offset with the given length,
// and considers this full amount of data "written" if it is beyond
// the end of our buffer. This never "rotates" the buffer because
// the offset can only be within the size of the buffer.
// Special case the empty slice fast-path.
// Note: this assertion is very important, it hints the compiler
// which generates ~10% faster code than without it.
// End offset is the last offset (exclusive) for our slice.
// We use exclusive because it makes the math easier and it
// matches Zigs slicing parameterization.
// If our slice can't fit it in our length, then we need to advance.
// Our start and end indexes into the storage buffer
// std.log.warn("A={} B={}", .{ start_idx, end_idx });
// Optimistically, our data fits in one slice
// Advances the head/tail so that we can store amount.
// Optimistically add our amount
// If we exceeded the length of the buffer, wrap around.
// If we're full, we have to keep tail lined up.
// We're full if the head reached the tail. The head can never
// pass the tail because advance asserts amount is only in
// available space left
// For a given offset from zero, this returns the offset in the
// storage buffer where this data can be found.
// This should be subtraction ideally to avoid overflows but
// it would take a really, really, huge buffer to overflow.
// Empty
// Partially full
// Full
// Delete and add
// Empty
// Partially full
// Full
// Delete and add
// Fill the buffer
// Delete
// Fill the buffer
// Delete
// Get a slice that doesn't grow
// Get a slice that does grow, and forces wrap
// should be empty
// Get a slice across boundaries
// Fill the buffer
// Delete
// Rotate to zero
// Fill the buffer
// Delete all
// Refill to force a wrap
// Rotate to zero
// Fill the buffer
// Delete all
// Refill to force a wrap
// Rotate to zero
// Resize
// Fill and write
// Resize
// Fill and write
// Resize
// Appending an empty slice to empty buffer should be a no-op
// Buffer should still work normally after appending empty slice
// Appending an empty slice to non-empty buffer should also be a no-op
// getPtrSlice with zero length on empty buffer should return empty slices
// Fill buffer partially
// getPtrSlice with zero length on non-empty buffer should also work
// deleteOldest(0) on empty buffer should be a no-op
// Fill buffer
// deleteOldest(0) on non-empty buffer should be a no-op
// Verify data is unchanged
//
// --- Original Ghostty Comments End: src/datastruct/circ_buf.zig


// Circular buffer implementations for the search sliding window.
//
// DataBuf stores encoded page text (bytes) and MetaBuf stores page
// metadata entries. Both support efficient O(1) append-at-end and
// delete-from-front operations.
//
// Relative to the generic Zig `CircBuf(T, default)` in
// datastruct/circ_buf.zig, this is a purpose-built rewrite using
// head/count bookkeeping instead of head/tail/full. The Zig-parity
// pieces added here are: the forward/reverse `Iterator` (next / seek_by
// / reset, plus first/last helpers), `resize`, and `rotate_to_zero`.
//
// Intentionally omitted (not required by SlidingWindow, the only consumer):
//   - The `full` flag and the `append`-that-can-error path: our bufs grow
//     on demand via ensure_unused_capacity, so a "full" state never occurs.
//   - `getPtrSlice`'s auto-advance/wrap-write behavior: DataBuf.get_ptr_slice
//     is read-only here; SlidingWindow reserves capacity before writing.
//   - The `default` value memset on delete: unused slots are logically dead
//     (guarded by `count`), so we skip zeroing for speed.

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

// Rotate the data so that it is zero-aligned (head == 0). After this the
// logical data occupies storage[0..count]. This mirrors the Zig
// `rotateToZero` used prior to a resize/realloc.
//
// Source: datastruct/circ_buf.zig rotateToZero
fn (mut self DataBuf) rotate_to_zero() {
	// If we're already at zero then do nothing.
	if self.head == 0 {
		return
	}
	// Reuse grow's compaction: copy into a fresh, head-aligned buffer of
	// the same capacity. (Zig rotates in-place via std.mem.rotate; we
	// don't have that primitive here, so a copy is the simplest faithful
	// equivalent that leaves storage zero-aligned.)
	if self.storage.len == 0 {
		self.head = 0
		return
	}
	mut new_storage := []u8{len: self.storage.len}
	for i in 0 .. self.count {
		old_idx := (self.head + i) % self.storage.len
		new_storage[i] = self.storage[old_idx]
	}
	self.storage = new_storage
	self.head = 0
}

// Resize the buffer to the given capacity (larger or smaller). If larger,
// the tail is unaffected; new slots default to zero. If smaller than the
// current count, the buffer is truncated to hold at most `size` bytes.
//
// Source: datastruct/circ_buf.zig resize
fn (mut self DataBuf) resize(size int) {
	// Rotate to zero so it is aligned, then reallocate at the end.
	self.rotate_to_zero()
	mut new_storage := []u8{len: size}
	keep := if self.count < size { self.count } else { size }
	for i in 0 .. keep {
		new_storage[i] = self.storage[i]
	}
	self.storage = new_storage
	if self.count > size {
		self.count = size
	}
	self.head = 0
}

// ============================================================
// DataBufIterator - forward/reverse iteration over DataBuf
// ============================================================

// DataBufIterator iterates over the logical contents of a DataBuf in
// either forward (oldest to newest) or reverse (newest to oldest) order,
// with clamped seeking and reset support.
//
// Source: datastruct/circ_buf.zig CircBuf.Iterator
struct DataBufIterator {
	buf       &DataBuf = unsafe { nil }
	direction Direction
mut:
	idx int
}

// Return an iterator over the buffer in the given direction.
fn (b &DataBuf) iterator(direction Direction) DataBufIterator {
	return DataBufIterator{
		buf: unsafe { b }
		idx: 0
		direction: direction
	}
}

// Advance the iterator, returning the next byte or none when exhausted.
fn (mut it DataBufIterator) next() ?u8 {
	if it.idx >= it.buf.len() {
		return none
	}
	// Get our logical index depending on direction.
	logical_idx := match it.direction {
		.forward { it.idx }
		.reverse { it.buf.len() - it.idx - 1 }
	}
	it.idx += 1
	return it.buf.get(logical_idx)
}

// Seek the iterator by a given (possibly negative) amount, clamped to the
// bounds of the buffer so overflow/underflow are not possible.
fn (mut it DataBufIterator) seek_by(amount int) {
	if amount > 0 {
		it.idx += amount
	} else {
		dec := -amount
		if dec > it.idx {
			it.idx = 0
		} else {
			it.idx -= dec
		}
	}
}

// Reset the iterator back to the first value.
fn (mut it DataBufIterator) reset() {
	it.idx = 0
}

// Get the first (oldest) byte, or none if empty.
fn (b &DataBuf) first() ?u8 {
	mut it := b.iterator(.forward)
	return it.next()
}

// Get the last (newest) byte, or none if empty.
fn (b &DataBuf) last() ?u8 {
	mut it := b.iterator(.reverse)
	return it.next()
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

// Rotate the data so that it is zero-aligned (head == 0).
//
// Source: datastruct/circ_buf.zig rotateToZero
fn (mut self MetaBuf) rotate_to_zero() {
	if self.head == 0 {
		return
	}
	if self.storage.len == 0 {
		self.head = 0
		return
	}
	mut new_storage := []Meta{len: self.storage.len}
	for i in 0 .. self.count {
		old_idx := (self.head + i) % self.storage.len
		new_storage[i] = self.storage[old_idx]
	}
	self.storage = new_storage
	self.head = 0
}

// Resize the buffer to the given capacity (larger or smaller).
//
// Source: datastruct/circ_buf.zig resize
fn (mut self MetaBuf) resize(size int) {
	self.rotate_to_zero()
	mut new_storage := []Meta{len: size}
	keep := if self.count < size { self.count } else { size }
	for i in 0 .. keep {
		new_storage[i] = self.storage[i]
	}
	self.storage = new_storage
	if self.count > size {
		self.count = size
	}
	self.head = 0
}

// ============================================================
// MetaBufIterator - forward/reverse iteration over MetaBuf
// ============================================================

// MetaBufIterator iterates over the logical contents of a MetaBuf in
// either forward or reverse order.
//
// Source: datastruct/circ_buf.zig CircBuf.Iterator
struct MetaBufIterator {
	buf       &MetaBuf = unsafe { nil }
	direction Direction
mut:
	idx int
}

// Return an iterator over the buffer in the given direction.
fn (b &MetaBuf) iterator(direction Direction) MetaBufIterator {
	return MetaBufIterator{
		buf: unsafe { b }
		idx: 0
		direction: direction
	}
}

// Advance the iterator, returning the next Meta or none when exhausted.
fn (mut it MetaBufIterator) next() ?Meta {
	if it.idx >= it.buf.len() {
		return none
	}
	logical_idx := match it.direction {
		.forward { it.idx }
		.reverse { it.buf.len() - it.idx - 1 }
	}
	it.idx += 1
	return it.buf.get(logical_idx)
}

// Seek the iterator by a given (possibly negative) amount, clamped.
fn (mut it MetaBufIterator) seek_by(amount int) {
	if amount > 0 {
		it.idx += amount
	} else {
		dec := -amount
		if dec > it.idx {
			it.idx = 0
		} else {
			it.idx -= dec
		}
	}
}

// Reset the iterator back to the first value.
fn (mut it MetaBufIterator) reset() {
	it.idx = 0
}

// Get the first (oldest) Meta, or none if empty.
fn (b &MetaBuf) first() ?Meta {
	mut it := b.iterator(.forward)
	return it.next()
}

// Get the last (newest) Meta, or none if empty.
fn (b &MetaBuf) last() ?Meta {
	mut it := b.iterator(.reverse)
	return it.next()
}
