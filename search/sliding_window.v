module search

// Searches page nodes via a sliding window. The sliding window maintains
// the invariant that data isn't pruned until (1) we've searched it and
// (2) we've accounted for overlaps across pages to fit the needle.
//
// The sliding window is first initialized empty. Pages are then appended
// in the order to search them. The sliding window supports both a forward
// and reverse order specified via init. The pages should be appended
// in the correct order matching the search direction.
//
// All appends grow the window. The window is only pruned when a search
// is done (positive or negative match) via next().
//
// To avoid unnecessary memory growth, the recommended usage is to
// call next() until it returns null and then append the next page
// and repeat the process. This will always maintain the minimum
// required memory to search for the needle.
//
// The caller is responsible for providing the pages and ensuring they're
// in the proper order. The SlidingWindow itself doesn't own the pages, but
// it will contain pointers to them in order to return selections. If any
// pages become invalid, the caller should clear the sliding window and
// start over.
//
// Source: terminal/search/sliding_window.zig (1677 lines)

import terminal
import highlight

// ============================================================
// Direction
// ============================================================

// The search direction. If the direction is forward then pages should
// be appended in forward linked list order from the PageList. If the
// direction is reverse then pages should be appended in reverse order.
//
// This is important because in most cases, a reverse search is going
// to be more desirable to search from the end of the active area
// backwards so more recent data is found first. Supporting both is
// trivial though and will let us do more complex optimizations in the
// future (e.g. starting from the viewport and doing a forward/reverse
// concurrently from that point).
pub enum Direction {
	forward
	reverse
}

// ============================================================
// SlidingWindow
// ============================================================

pub struct SlidingWindow {
pub mut:
	// The data buffer is a circular buffer of u8 that contains the
	// encoded page text that we can use to search for the needle.
	data DataBuf

	// The meta buffer is a circular buffer that contains the metadata
	// about the pages we're searching. This usually isn't that large
	// so callers must iterate through it to find the offset to map
	// data to meta.
	meta MetaBuf

	// Buffer of chunks for the current highlight result. Reused
	// across calls to next() to avoid repeated allocation.
	chunk_buf []highlight.Chunk

	// Offset into data for our current state. This handles the
	// situation where our search moved through meta[0] but didn't
	// do enough to prune it.
	data_offset int

	// The needle we're searching for.
	needle []u8

	// The search direction.
	direction Direction

	// A buffer to store the overlap search data. This is used to search
	// overlaps between pages where the match starts on one page and
	// ends on another. The length is always needle.len * 2.
	overlap_buf []u8
}

// Initialize a new SlidingWindow for searching.
pub fn SlidingWindow.init(direction Direction, needle_unowned []u8) SlidingWindow {
	mut needle := needle_unowned.clone()
	if direction == .reverse {
		// Reverse the needle for reverse searching.
		reverse_bytes(mut needle)
	}

	return SlidingWindow{
		data: DataBuf.new()
		meta: MetaBuf.new()
		data_offset: 0
		needle: needle
		direction: direction
		overlap_buf: []u8{len: needle.len * 2}
	}
}

// Free resources.
pub fn (mut self SlidingWindow) deinit() {
	self.needle = []
	self.overlap_buf = []
	self.chunk_buf = []
	self.data = DataBuf.new()
	self.meta = MetaBuf.new()
}

// Clear all data but retain allocated capacity.
pub fn (mut self SlidingWindow) clear_and_retain_capacity() {
	self.meta.clear()
	self.data.clear()
	self.data_offset = 0
}

// Search the window for the next occurrence of the needle. As
// the window moves, the window will prune itself while maintaining
// the invariant that the window is always big enough to contain
// the needle.
//
// This returns a flattened highlight on a match. The
// flattened highlight requires allocation and is therefore more expensive
// than a normal selection, but it is more efficient to render since it
// has all the information without having to dereference pointers into
// the terminal state.
//
// The flattened highlight chunks reference internal memory for this
// sliding window and are only valid until the next call to next()
// or append(). If the caller wants to retain the flattened highlight
// then they should clone it.
pub fn (mut self SlidingWindow) next() ?highlight.FlattenedHighlight {
	// If we have less data than the needle then we can't possibly match.
	data_len := self.data.len()
	if data_len < self.needle.len {
		return none
	}

	slices := self.data.get_ptr_slice(self.data_offset, data_len - self.data_offset)

	// Search the first slice for the needle.
	if idx := index_of_ignore_case(slices.first, self.needle) {
		return self.build_highlight(idx, self.needle.len)
	}

	// Search the overlap buffer for the needle.
	if slices.first.len > 0 && slices.second.len > 0 {
		// Get up to needle.len - 1 bytes from each side (as much as
		// we can) and store it in the overlap buffer.
		prefix_len := min(slices.first.len, self.needle.len - 1)
		prefix_start := slices.first.len - prefix_len
		prefix := slices.first[prefix_start..]

		suffix_len := min(slices.second.len, self.needle.len - 1)
		suffix := slices.second[..suffix_len]

		overlap_len := prefix_len + suffix_len
		assert overlap_len <= self.overlap_buf.len, 'overlap exceeds buffer'

		// Copy prefix and suffix into the overlap buffer.
		for i, b in prefix {
			self.overlap_buf[i] = b
		}
		for i, b in suffix {
			self.overlap_buf[prefix_len + i] = b
		}

		// Search the overlap.
		if idx := index_of_ignore_case(self.overlap_buf[..overlap_len], self.needle) {
			// We found a match in the overlap buffer. Map the index
			// back to the data buffer to get our selection.
			return self.build_highlight(slices.first.len - prefix_len + idx, self.needle.len)
		}
	}

	// Search the last slice for the needle.
	if idx := index_of_ignore_case(slices.second, self.needle) {
		return self.build_highlight(slices.first.len + idx, self.needle.len)
	}

	// Special case 1-length needles: delete the entire buffer since
	// a single char can't overlap across pages.
	if self.needle.len == 1 {
		self.clear_and_retain_capacity()
		self.assert_integrity()
		return none
	}

	// No match. We keep needle.len - 1 bytes available to
	// handle the future overlap case.
	prune_success := self.prune_after_miss()
	if prune_success {
		// Our data offset now moves to needle.len - 1 from the end so
		// that we can handle the overlap case.
		self.data_offset = self.data.len() - self.needle.len + 1
	}

	self.assert_integrity()
	return none
}

// Prune data after a miss. Returns true if pruning happened or
// the data_offset was updated; false if pruning was skipped
// (not enough data to save needle.len - 1 bytes).
fn (mut self SlidingWindow) prune_after_miss() bool {
	mut saved := 0
	mut found := false
	mut found_idx := 0

	// Iterate meta in reverse to find the point where we have
	// enough saved bytes for the overlap window.
	for i := self.meta.len() - 1; i >= 0; i-- {
		meta := self.meta.get(i)
		needed := self.needle.len - 1 - saved
		if meta.cell_map.len >= needed {
			// We save up to this meta. Set our data offset
			// to exactly where it needs to be to continue searching.
			self.data_offset = meta.cell_map.len - needed
			found = true
			found_idx = i
			break
		}
		saved += meta.cell_map.len
	}

	if !found {
		// Never got the amount we needed, nothing to prune.
		assert saved < self.needle.len - 1, 'unexpected saved amount'
		return false
	}

	prune_count := found_idx
	if prune_count == 0 {
		// This can happen if we need to save up to the first
		// meta value to retain our window.
		return true
	}

	// Delete all the metas before the found index and their data.
	mut prune_data_len := 0
	for j in 0 .. prune_count {
		meta := self.meta.get(j)
		prune_data_len += meta.cell_map.len
	}
	self.meta.delete_oldest(prune_count)
	self.data.delete_oldest(prune_data_len)

	return true
}

// Return a flattened highlight for the given start offset and length.
//
// The start index is relative to the data_offset. i.e. index zero
// is actually at self.data[self.data_offset]. The highlight accounts
// for the offset internally.
fn (mut self SlidingWindow) build_highlight(start_offset int, length int) highlight.FlattenedHighlight {
	start := start_offset + self.data_offset
	end_pos := start + length - 1
	assert start < self.data.len(), 'highlight start out of bounds'
	assert start + length <= self.data.len(), 'highlight end out of bounds'

	// Clear our previous chunk buffer to store this result.
	self.chunk_buf = []
	mut result := highlight.FlattenedHighlight.empty()

	// Go through the meta nodes to find our start and build chunks.
	mut meta_consumed := 0
	mut br_continue_from := -1 // -1 means no continuation needed
	mut br_consumed := 0
	mut prune_meta_count := 0
	mut prune_data_len := 0

	for i in 0 .. self.meta.len() {
		meta := self.meta.get(i)
		prior_meta_consumed := meta_consumed
		meta_consumed += meta.cell_map.len

		// meta_i is the index we expect to find the match in the
		// cell map within this meta if it contains it.
		meta_i := start - prior_meta_consumed

		// This meta doesn't contain the match. This means we
		// can also prune this set of data because we only look forward.
		if meta_i >= meta.cell_map.len {
			continue
		}

		// Now we look for the end. In MOST cases it is the same as
		// our starting chunk because highlights are usually small and
		// not on a boundary, so let's optimize for that.
		end_i := end_pos - prior_meta_consumed
		if end_i < meta.cell_map.len {
			// The entire highlight is within this meta.
			start_map := meta.cell_map[meta_i]
			end_map := meta.cell_map[end_i]
			result.top_x = start_map.x
			result.bot_x = end_map.x
			self.chunk_buf << highlight.Chunk{
				node: meta.node
				serial: meta.serial
				start: u16(start_map.y)
				end: u16(end_map.y + 1)
			}
			prune_meta_count = i
			prune_data_len = prior_meta_consumed
			br_continue_from = -1 // no continuation
			break
		} else {
			// We found the meta that contains the start of the match
			// only. Consume this entire node from our start offset.
			map_entry := meta.cell_map[meta_i]
			result.top_x = map_entry.x
			self.chunk_buf << highlight.Chunk{
				node: meta.node
				serial: meta.serial
				start: u16(map_entry.y)
				end: meta.node.data.size.rows
			}
			prune_meta_count = i
			prune_data_len = prior_meta_consumed
			br_continue_from = i + 1
			br_consumed = meta_consumed
			break
		}
	}

	// Search for our end if the match spans multiple meta nodes.
	if br_continue_from >= 0 {
		mut mc := br_consumed
		for j := br_continue_from; j < self.meta.len(); j++ {
			meta := self.meta.get(j)

			// meta_i is the index we expect to find the match in the
			// cell map within this meta if it contains it.
			meta_i := end_pos - mc
			if meta_i >= meta.cell_map.len {
				// This meta doesn't contain the match. We still add it
				// to our results because we want the full flattened list.
				self.chunk_buf << highlight.Chunk{
					node: meta.node
					serial: meta.serial
					start: 0
					end: meta.node.data.size.rows
				}
				mc += meta.cell_map.len
				continue
			}

			// We found it.
			map_entry := meta.cell_map[meta_i]
			result.bot_x = map_entry.x
			self.chunk_buf << highlight.Chunk{
				node: meta.node
				serial: meta.serial
				start: 0
				end: u16(map_entry.y + 1)
			}
			break
		}
	}

	// Our offset into the current meta block is the start index
	// minus the amount of data fully consumed. We then add one
	// to move one past the match so we don't repeat it.
	self.data_offset = start - prune_data_len + 1

	// If we went beyond our initial meta node we can prune.
	if prune_meta_count > 0 {
		self.meta.delete_oldest(prune_meta_count)

		// Delete all the data up to our current index.
		assert prune_data_len > 0, 'expected positive prune data'
		self.data.delete_oldest(prune_data_len)
	}

	// Handle reverse direction: swap chunk order and fix coordinates.
	if self.direction == .reverse {
		if self.chunk_buf.len > 1 {
			// Reverse all our chunks.
			reverse_chunks(mut self.chunk_buf)

			// Now normally with forward traversal with multiple pages,
			// the suffix of the first page and the prefix of the last
			// page are used.
			//
			// For a reverse traversal, this is inverted (since the
			// pages are in reverse order we get the suffix of the last
			// page and the prefix of the first page). So we need to
			// invert this.
			//
			// We DON'T need to do this for any middle pages because
			// they always use the full page.
			//
			// This is a fixup that makes our start/end match the
			// same logic as the loops above if they were in forward order.
			assert self.chunk_buf.len >= 2, 'expected at least 2 chunks for multi-page reverse'
			self.chunk_buf[0].start = self.chunk_buf[0].end - 1
			self.chunk_buf[0].end = self.chunk_buf[0].node.data.size.rows

			last := self.chunk_buf.len - 1
			self.chunk_buf[last].end = self.chunk_buf[last].start + 1
			self.chunk_buf[last].start = 0
		} else if self.chunk_buf.len == 1 {
			// For a single chunk, the y values are in reverse order
			// (start is the screen-end, end is the screen-start).
			// Swap them to get proper top-to-bottom order.
			start_y := self.chunk_buf[0].start
			self.chunk_buf[0].start = self.chunk_buf[0].end - 1
			self.chunk_buf[0].end = start_y + 1
		}

		// X values also need to be reversed since the top/bottom
		// are swapped for the nodes.
		top_x := result.top_x
		result.top_x = result.bot_x
		result.bot_x = top_x
	}

	// Copy our chunks so they're independent of the internal buffer.
	result.chunks = self.chunk_buf.clone()
	return result
}

// Add a new node to the sliding window. This will always grow
// the sliding window; data isn't pruned until it is consumed
// via a search (via next()).
//
// Returns the number of bytes of content added to the sliding window.
// The total bytes will be larger since this omits metadata, but it is
// an accurate measure of the text content size added.
pub fn (mut self SlidingWindow) append(node &terminal.PageNode) int {
	// XTODO: Requires PageFormatter with point_map support.
	// The V PageFormatter doesn't currently support the point_map feature
	// needed to build the cell_map that maps encoded bytes back to cell
	// coordinates. This is needed for highlight() to translate byte
	// positions into screen positions.
	//
	// When PageFormatter gains point_map support, this method should:
	// 1. Create a Meta entry for the node
	// 2. Use PageFormatter with point_map to encode the page text
	// 3. If the last row isn't soft-wrapped, append a trailing newline
	// 4. Reverse the encoded data and cell_map for reverse searches
	// 5. Append the encoded bytes to self.data
	// 6. Append the Meta entry to self.meta
	// 7. Ensure chunk_buf has enough capacity
	_ = node
	return 0
}

// Only for tests! Change the needle (must be same length).
fn (mut self SlidingWindow) test_change_needle(new_needle []u8) {
	assert new_needle.len == self.needle.len, 'test_change_needle: length mismatch'
	self.needle = new_needle.clone()
}

// Verify internal invariants (debug only).
fn (self &SlidingWindow) assert_integrity() {
	// Verify data matches metadata exactly.
	mut data_len := 0
	for i in 0 .. self.meta.len() {
		m := self.meta.get(i)
		data_len += m.cell_map.len
	}
	assert data_len == self.data.len(), 'integrity: data_len=${data_len} != buf.len=${self.data.len()}'

	// Verify data offset is within bounds.
	assert self.data.len() == 0
		|| self.data_offset < self.data.len(), 'integrity: data_offset=${self.data_offset} >= data.len=${self.data.len()}'
}

// ============================================================
// Helper functions
// ============================================================

// Case-insensitive search for needle in haystack.
// Returns the index of the first match, or none if not found.
fn index_of_ignore_case(haystack []u8, needle []u8) ?int {
	if needle.len == 0 {
		return 0
	}
	if needle.len > haystack.len {
		return none
	}
	for i in 0 .. haystack.len - needle.len + 1 {
		mut matched := true
		for j in 0 .. needle.len {
			if to_lower_ascii(haystack[i + j]) != to_lower_ascii(needle[j]) {
				matched = false
				break
			}
		}
		if matched {
			return i
		}
	}
	return none
}

// Convert an ASCII byte to lowercase.
fn to_lower_ascii(c u8) u8 {
	if c >= u8(`A`) && c <= u8(`Z`) {
		return c + 32
	}
	return c
}

// Reverse a byte array in place.
fn reverse_bytes(mut arr []u8) {
	mut i := 0
	mut j := arr.len - 1
	for i < j {
		arr[i], arr[j] = arr[j], arr[i]
		i += 1
		j -= 1
	}
}

// Reverse a chunk array in place.
fn reverse_chunks(mut arr []highlight.Chunk) {
	mut i := 0
	mut j := arr.len - 1
	for i < j {
		arr[i], arr[j] = arr[j], arr[i]
		i += 1
		j -= 1
	}
}

// Return the smaller of two ints.
fn min(a int, b int) int {
	return if a < b { a } else { b }
}
