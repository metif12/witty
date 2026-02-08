module terminal

// PageList manages a doubly-linked list of Pages forming the terminal
// screen buffer with scrollback, viewport management, and text reflow.
// Translated from Ghostty's PageList.zig.

// ============================================================
// Direction for iterators
// ============================================================

pub enum IterDirection {
	right_down
	left_up
}

// ============================================================
// PageViewport - where the viewport is positioned
// ============================================================

pub enum PageViewport {
	active // Pinned to active area (bottom)
	top    // Pinned to top of scrollback
	pin    // Pinned to a tracked pin
}

// ============================================================
// PagePin - a position within the PageList
// ============================================================

@[heap]
pub struct PagePin {
pub mut:
	node    &PageNode = unsafe { nil }
	y       u16 // Row index within the page
	x       u16 // Column index within the row
	garbage bool // Set true if tracked pin was pruned
}

// Returns the row data at this pin's position.
pub fn (self &PagePin) row_data() &RowData {
	return &self.node.data.rows[int(self.y)]
}

// Returns the cell data at this pin's position.
pub fn (self &PagePin) cell_data() &CellData {
	row := self.node.data.rows[int(self.y)]
	return &row.cells[int(self.x)]
}

// Returns true if the row at this pin is dirty.
pub fn (self &PagePin) is_dirty() bool {
	return self.node.data.dirty || self.node.data.rows[int(self.y)].dirty
}

// Mark the row at this pin as dirty.
pub fn (mut self PagePin) mark_dirty() {
	self.node.data.rows[int(self.y)].dirty = true
}

// Returns true if pins reference the same position.
pub fn (self &PagePin) eql(other PagePin) bool {
	p := voidptr(self.node)
	q := voidptr(other.node)
	return p == q && self.y == other.y && self.x == other.x
}

// Returns true if self is before other in the linked list.
// This is O(N) - must traverse the linked list.
pub fn (self &PagePin) before(other PagePin) bool {
	p := voidptr(self.node)
	q := voidptr(other.node)
	if p == q {
		if self.y < other.y {
			return true
		}
		if self.y == other.y {
			return self.x < other.x
		}
		return false
	}
	// Traverse forward from self to see if we find other
	mut node := self.node.next
	for {
		n := node or { return false }
		if voidptr(n) == q {
			return true
		}
		node = n.next
	}
	return false
}

// Returns true if self is between top and bottom (inclusive).
pub fn (self &PagePin) is_between(top_pin PagePin, bottom_pin PagePin) bool {
	return (self.eql(top_pin) || top_pin.before(PagePin{
		node: self.node
		y: self.y
		x: self.x
	})) && (self.eql(bottom_pin) || PagePin{
		node: self.node
		y: self.y
		x: self.x
	}.before(bottom_pin))
}

// ---- Movement methods ----

// Move left by n columns (asserts n <= x).
pub fn (self &PagePin) left(n u16) PagePin {
	assert self.x >= n, 'PagePin.left: n=${n} > x=${self.x}'
	return PagePin{
		node: self.node
		y: self.y
		x: self.x - n
	}
}

// Move right by n columns (asserts fits in row).
pub fn (self &PagePin) right(n u16) PagePin {
	assert self.x + n < self.node.data.size.cols, 'PagePin.right: overflow'
	return PagePin{
		node: self.node
		y: self.y
		x: self.x + n
	}
}

// Move left, clamping at 0.
pub fn (self &PagePin) left_clamp(n u16) PagePin {
	new_x := if n > self.x { u16(0) } else { self.x - n }
	return PagePin{
		node: self.node
		y: self.y
		x: new_x
	}
}

// Move right, clamping at end of row.
pub fn (self &PagePin) right_clamp(n u16) PagePin {
	max_x := self.node.data.size.cols - 1
	new_x := if self.x + n > max_x { max_x } else { self.x + n }
	return PagePin{
		node: self.node
		y: self.y
		x: new_x
	}
}

// Move down by n rows, crossing page boundaries. Returns none if overflow.
pub fn (self &PagePin) down(n u32) ?PagePin {
	mut rem := n
	mut node := self.node
	mut y := u32(self.y)

	// First try within current page
	avail := u32(node.data.size.rows) - y - 1
	if rem <= avail {
		return PagePin{
			node: node
			y: u16(y + rem)
			x: self.x
		}
	}
	rem -= avail

	// Move to next pages
	mut next := node.next
	for {
		nd := next or { return none }
		if rem <= u32(nd.data.size.rows) {
			return PagePin{
				node: nd
				y: u16(rem - 1)
				x: self.x
			}
		}
		rem -= u32(nd.data.size.rows)
		next = nd.next
	}
	return none
}

// Move up by n rows, crossing page boundaries. Returns none if overflow.
pub fn (self &PagePin) up(n u32) ?PagePin {
	mut rem := n
	mut node := self.node
	mut y := u32(self.y)

	// First try within current page
	if rem <= y {
		return PagePin{
			node: node
			y: u16(y - rem)
			x: self.x
		}
	}
	rem -= y

	// Move to previous pages
	mut prev := node.prev
	for {
		nd := prev or { return none }
		if rem <= u32(nd.data.size.rows) {
			return PagePin{
				node: nd
				y: u16(u32(nd.data.size.rows) - rem)
				x: self.x
			}
		}
		rem -= u32(nd.data.size.rows)
		prev = nd.prev
	}
	return none
}

// DownOverflow result
pub struct DownOverflowOffset {
pub:
	pin PagePin
}

pub struct DownOverflowOverflow {
pub:
	end       PagePin
	remaining u32
}

pub type DownOverflowResult = DownOverflowOffset | DownOverflowOverflow

// Move down by n, returning overflow info if past end.
pub fn (self &PagePin) down_overflow(n u32) DownOverflowResult {
	mut rem := n
	mut node := self.node
	mut y := u32(self.y)

	// Try within current page
	avail := u32(node.data.size.rows) - y - 1
	if rem <= avail {
		return DownOverflowOffset{
			pin: PagePin{
				node: node
				y: u16(y + rem)
				x: self.x
			}
		}
	}
	rem -= avail

	// Traverse forward
	mut last_node := node
	mut next := node.next
	for {
		nd := next or {
			return DownOverflowOverflow{
				end: PagePin{
					node: last_node
					y: u16(last_node.data.size.rows - 1)
					x: self.x
				}
				remaining: rem
			}
		}
		if rem <= u32(nd.data.size.rows) {
			return DownOverflowOffset{
				pin: PagePin{
					node: nd
					y: u16(rem - 1)
					x: self.x
				}
			}
		}
		rem -= u32(nd.data.size.rows)
		unsafe {
			last_node = nd
		}
		next = nd.next
	}
	// unreachable
	return DownOverflowOverflow{
		end: PagePin{
			node: last_node
			y: u16(last_node.data.size.rows - 1)
			x: self.x
		}
		remaining: rem
	}
}

// UpOverflow result
pub struct UpOverflowOffset {
pub:
	pin PagePin
}

pub struct UpOverflowOverflow {
pub:
	end       PagePin
	remaining u32
}

pub type UpOverflowResult = UpOverflowOffset | UpOverflowOverflow

// Move up by n, returning overflow info if past beginning.
pub fn (self &PagePin) up_overflow(n u32) UpOverflowResult {
	mut rem := n
	mut y := u32(self.y)

	// Try within current page
	if rem <= y {
		return UpOverflowOffset{
			pin: PagePin{
				node: self.node
				y: u16(y - rem)
				x: self.x
			}
		}
	}
	rem -= y

	// Traverse backward
	mut first_node := self.node
	mut prev := self.node.prev
	for {
		nd := prev or {
			return UpOverflowOverflow{
				end: PagePin{
					node: first_node
					y: 0
					x: self.x
				}
				remaining: rem
			}
		}
		if rem <= u32(nd.data.size.rows) {
			return UpOverflowOffset{
				pin: PagePin{
					node: nd
					y: u16(u32(nd.data.size.rows) - rem)
					x: self.x
				}
			}
		}
		rem -= u32(nd.data.size.rows)
		unsafe {
			first_node = nd
		}
		prev = nd.prev
	}
	return UpOverflowOverflow{
		end: PagePin{
			node: first_node
			y: 0
			x: self.x
		}
		remaining: rem
	}
}

// ---- Pin iterator factories ----

pub fn (self &PagePin) page_iterator(direction IterDirection, limit ?PagePin) PageIterator {
	return PageIterator{
		row: PagePin{
			node: self.node
			y: self.y
			x: self.x
		}
		direction: direction
		limit: if lim := limit {
			PageIteratorLimit(PageIteratorLimitRow{
				pin: lim
			})
		} else {
			PageIteratorLimit(PageIteratorLimitNone{})
		}
	}
}

pub fn (self &PagePin) row_iterator(direction IterDirection, limit ?PagePin) RowIterator {
	return RowIterator{
		page_it: self.page_iterator(direction, limit)
	}
}

pub fn (self &PagePin) cell_iterator(direction IterDirection, limit ?PagePin) CellIterator {
	return CellIterator{
		row_it: self.row_iterator(direction, limit)
	}
}

pub fn (self &PagePin) prompt_iterator(direction IterDirection, limit ?PagePin) PromptIterator {
	return PromptIterator{
		row_it: self.row_iterator(direction, limit)
	}
}

// ============================================================
// PageCell - return type for get_cell
// ============================================================

pub struct PageCell {
pub:
	node &PageNode = unsafe { nil }
	row  &RowData  = unsafe { nil }
	cell &CellData = unsafe { nil }
	row_idx u16
	col_idx u16
}

// Convert to screen point (absolute row from top of page list).
// Traverses backward through the page list to compute the absolute y
// coordinate from the top of the entire page list.
pub fn (self &PageCell) screen_point() Pin {
	mut abs_y := u32(self.row_idx)

	// Traverse backward through the linked list to accumulate rows
	// from all preceding pages.
	mut prev := self.node.prev
	for {
		nd := prev or { break }
		abs_y += u32(nd.data.size.rows)
		prev = nd.prev
	}

	return Pin{
		x: u32(self.col_idx)
		y: abs_y
	}
}

// ============================================================
// PageScroll - scroll behavior
// ============================================================

pub struct PageScrollActive {}

pub struct PageScrollTop {}

pub struct PageScrollRow {
pub:
	n usize
}

pub struct PageScrollDeltaRow {
pub:
	delta int
}

pub struct PageScrollDeltaPrompt {
pub:
	delta int
}

pub struct PageScrollPin {
pub:
	pin PagePin
}

pub type PageScroll = PageScrollActive | PageScrollTop | PageScrollRow | PageScrollDeltaRow | PageScrollDeltaPrompt | PageScrollPin

// ============================================================
// Scrollbar
// ============================================================

pub struct Scrollbar {
pub:
	total  usize
	offset usize
	len    usize
}

pub const scrollbar_zero = Scrollbar{
	total: 0
	offset: 0
	len: 0
}

pub fn (self Scrollbar) eql(other Scrollbar) bool {
	return self.total == other.total && self.offset == other.offset && self.len == other.len
}

// ============================================================
// PageCloneOpts
// ============================================================

pub struct PageCloneOpts {
pub:
	top PointTag = .screen
	bot ?PointTag
}

// ============================================================
// PageResizeOpts
// ============================================================

pub struct PageResizeOpts {
pub:
	cols    ?u16
	rows    ?u16
	reflow  bool = true
	cursor  ?PageResizeCursor
}

pub struct PageResizeCursor {
pub:
	x u16
	y u16
}

// ============================================================
// Iterator types
// ============================================================

// ---- PageIterator ----

pub struct PageIteratorLimitNone {}

pub struct PageIteratorLimitCount {
pub mut:
	count usize
}

pub struct PageIteratorLimitRow {
pub:
	pin PagePin
}

pub type PageIteratorLimit = PageIteratorLimitNone | PageIteratorLimitCount | PageIteratorLimitRow

pub struct PageIterator {
pub mut:
	row       ?PagePin
	direction IterDirection = .right_down
	limit     PageIteratorLimit = PageIteratorLimit(PageIteratorLimitNone{})
}

pub struct PageChunk {
pub:
	node  &PageNode = unsafe { nil }
	start u16 // Inclusive
	end   u16 // Exclusive
}

pub fn (self &PageChunk) is_full_page() bool {
	return self.start == 0 && self.end == self.node.data.size.rows
}

pub fn (mut self PageIterator) next() ?PageChunk {
	return match self.direction {
		.right_down { self.next_down() }
		.left_up { self.next_up() }
	}
}

fn (mut self PageIterator) next_down() ?PageChunk {
	cur := self.row or { return none }

	node := cur.node
	page_rows := node.data.size.rows

	start := cur.y

	match mut self.limit {
		PageIteratorLimitNone {
			// Consume entire page from start
			self.row = if next := node.next {
				PagePin{
					node: next
					y: 0
					x: 0
				}
			} else {
				none
			}
			return PageChunk{
				node: node
				start: start
				end: page_rows
			}
		}
		PageIteratorLimitCount {
			remaining_in_page := u32(page_rows) - u32(start)
			mut count := usize(remaining_in_page)
			if count > self.limit.count {
				count = self.limit.count
			}
			self.limit.count -= count
			end := u16(u32(start) + u32(count))
			if end < page_rows {
				self.row = PagePin{
					node: node
					y: end
					x: 0
				}
			} else {
				self.row = if next := node.next {
					PagePin{
						node: next
						y: 0
						x: 0
					}
				} else {
					none
				}
			}
			if self.limit.count == 0 {
				self.row = none
			}
			if count == 0 {
				return none
			}
			return PageChunk{
				node: node
				start: start
				end: end
			}
		}
		PageIteratorLimitRow {
			lim := self.limit as PageIteratorLimitRow
			lim_node := voidptr(lim.pin.node)
			cur_node := voidptr(node)
			if cur_node == lim_node {
				// Same page as limit
				end := lim.pin.y + 1 // inclusive
				self.row = none
				if end <= start {
					return none
				}
				return PageChunk{
					node: node
					start: start
					end: end
				}
			}
			// Different page, consume to end
			self.row = if next := node.next {
				PagePin{
					node: next
					y: 0
					x: 0
				}
			} else {
				none
			}
			return PageChunk{
				node: node
				start: start
				end: page_rows
			}
		}
	}
}

fn (mut self PageIterator) next_up() ?PageChunk {
	cur := self.row or { return none }

	node := cur.node
	end := cur.y + 1 // exclusive

	match mut self.limit {
		PageIteratorLimitNone {
			self.row = if prev := node.prev {
				PagePin{
					node: prev
					y: u16(prev.data.size.rows - 1)
					x: 0
				}
			} else {
				none
			}
			return PageChunk{
				node: node
				start: 0
				end: end
			}
		}
		PageIteratorLimitCount {
			mut count := usize(end)
			if count > self.limit.count {
				count = self.limit.count
			}
			self.limit.count -= count
			start := u16(u32(end) - u32(count))
			if start > 0 {
				self.row = PagePin{
					node: node
					y: start - 1
					x: 0
				}
			} else {
				self.row = if prev := node.prev {
					PagePin{
						node: prev
						y: u16(prev.data.size.rows - 1)
						x: 0
					}
				} else {
					none
				}
			}
			if self.limit.count == 0 {
				self.row = none
			}
			if count == 0 {
				return none
			}
			return PageChunk{
				node: node
				start: start
				end: end
			}
		}
		PageIteratorLimitRow {
			lim := self.limit as PageIteratorLimitRow
			lim_node := voidptr(lim.pin.node)
			cur_node := voidptr(node)
			if cur_node == lim_node {
				start := lim.pin.y
				self.row = none
				if start >= end {
					return none
				}
				return PageChunk{
					node: node
					start: start
					end: end
				}
			}
			self.row = if prev := node.prev {
				PagePin{
					node: prev
					y: u16(prev.data.size.rows - 1)
					x: 0
				}
			} else {
				none
			}
			return PageChunk{
				node: node
				start: 0
				end: end
			}
		}
	}
}

// ---- RowIterator ----

pub struct RowIterator {
pub mut:
	page_it PageIterator
	chunk   ?PageChunk
	offset  u16
}

pub fn (mut self RowIterator) next() ?PagePin {
	// If we have no chunk yet, get the first one
	if self.chunk == none {
		self.chunk = self.page_it.next() or { return none }
		ch := self.chunk or { return none }
		self.offset = match self.page_it.direction {
			.right_down { ch.start }
			.left_up { ch.end - 1 }
		}
	}

	ch := self.chunk or { return none }

	// Check bounds
	if self.page_it.direction == .right_down {
		if self.offset >= ch.end {
			self.chunk = self.page_it.next() or { return none }
			new_ch := self.chunk or { return none }
			self.offset = new_ch.start
			return self.next()
		}
	} else {
		if self.offset < ch.start {
			self.chunk = self.page_it.next() or { return none }
			new_ch := self.chunk or { return none }
			self.offset = new_ch.end - 1
			return self.next()
		}
	}

	result := PagePin{
		node: ch.node
		y: self.offset
		x: 0
	}

	match self.page_it.direction {
		.right_down { self.offset += 1 }
		.left_up {
			if self.offset == 0 {
				// Need next chunk
				self.chunk = self.page_it.next()
				if new_ch := self.chunk {
					self.offset = new_ch.end - 1
				}
				return result
			}
			self.offset -= 1
		}
	}

	return result
}

// ---- CellIterator ----

pub struct CellIterator {
pub mut:
	row_it RowIterator
	cell   ?PagePin
}

pub fn (mut self CellIterator) next() ?PagePin {
	if self.cell == none {
		row := self.row_it.next() or { return none }
		self.cell = PagePin{
			node: row.node
			y: row.y
			x: if self.row_it.page_it.direction == .right_down {
				u16(0)
			} else {
				row.node.data.size.cols - 1
			}
		}
	}

	c := self.cell or { return none }
	result := c

	match self.row_it.page_it.direction {
		.right_down {
			if c.x + 1 < c.node.data.size.cols {
				self.cell = PagePin{
					node: c.node
					y: c.y
					x: c.x + 1
				}
			} else {
				self.cell = none
			}
		}
		.left_up {
			if c.x > 0 {
				self.cell = PagePin{
					node: c.node
					y: c.y
					x: c.x - 1
				}
			} else {
				self.cell = none
			}
		}
	}

	return result
}

// ---- PromptIterator ----

pub struct PromptIterator {
pub mut:
	row_it RowIterator
}

pub fn (mut self PromptIterator) next() ?PagePin {
	for {
		row := self.row_it.next() or { return none }
		if int(row.y) < row.node.data.rows.len {
			rd := row.node.data.rows[int(row.y)]
			match rd.semantic_prompt {
				.prompt, .input, .command {
					return row
				}
				else {}
			}
		}
	}
	return none
}

// ============================================================
// PageList struct
// ============================================================

@[heap]
pub struct PageList {
pub mut:
	// The linked list of pages.
	pages PageNodeList

	// Monotonically increasing serial for page allocation.
	page_serial     u64
	page_serial_min u64

	// Byte size tracking (approximate).
	page_size usize

	// Max size for scrollback (0 = no scrollback).
	explicit_max_size usize
	min_max_size      usize

	// Total rows across all pages.
	total_rows usize

	// Tracked pins that auto-update during modifications.
	tracked_pins []&PagePin

	// Viewport state.
	viewport              PageViewport = .active
	viewport_pin          &PagePin     = unsafe { nil }
	viewport_pin_row_offset ?usize

	// Current desired screen dimensions.
	cols u16
	rows u16
}

// ============================================================
// Init / Deinit / Reset
// ============================================================

pub fn PageList.init(cols u16, rows u16, max_size ?usize) PageList {
	// Create initial pages to fit the viewport
	cap := initial_capacity(cols)
	mut page_list := PageNodeList{}
	mut page_serial := u64(0)
	mut page_size := usize(0)
	mut total_rows := usize(0)

	mut rem := u16(rows)
	for rem > 0 {
		mut node := &PageNode{
			data: Page.init(cap)
			serial: page_serial
		}
		use := if rem < cap.rows { rem } else { cap.rows }
		node.data.size.rows = use
		rem -= use
		page_list.append(node)
		page_size += usize(cap.cols) * usize(cap.rows) * 16 // approximate
		page_serial += 1
		total_rows += usize(use)
	}

	mms := min_max_size_calc(cols, rows)

	// Create viewport pin
	viewport_pin := &PagePin{
		node: page_list.first or { unsafe { &PageNode(nil) } }
	}

	return PageList{
		cols: cols
		rows: rows
		pages: page_list
		page_serial: page_serial
		page_serial_min: 0
		page_size: page_size
		explicit_max_size: max_size or { max_usize }
		min_max_size: mms
		total_rows: total_rows
		tracked_pins: [viewport_pin]
		viewport: .active
		viewport_pin: viewport_pin
		viewport_pin_row_offset: none
	}
}

pub fn (mut self PageList) deinit() {
	self.tracked_pins = []
	self.pages = PageNodeList{}
}

pub fn (mut self PageList) reset() {
	cap := initial_capacity(self.cols)

	// Rebuild page list
	mut page_list := PageNodeList{}
	mut page_serial := self.page_serial
	mut total_rows := usize(0)
	mut page_size := usize(0)

	mut rem := self.rows
	for rem > 0 {
		mut node := &PageNode{
			data: Page.init(cap)
			serial: page_serial
		}
		use := if rem < cap.rows { rem } else { cap.rows }
		node.data.size.rows = use
		rem -= use
		page_list.append(node)
		page_size += usize(cap.cols) * usize(cap.rows) * 16
		page_serial += 1
		total_rows += usize(use)
	}

	self.pages = page_list
	self.page_serial = page_serial
	self.page_size = page_size
	self.total_rows = total_rows

	// Update all tracked pins to point to first page top-left
	first := self.pages.first or { return }
	for mut p in self.tracked_pins {
		p.node = first
		p.y = 0
		p.x = 0
		p.garbage = true
	}
	self.viewport_pin.garbage = false
	self.viewport = .active
}

// ============================================================
// Helpers
// ============================================================

const max_usize = usize(0x7FFFFFFFFFFFFFFF)

fn initial_capacity(cols u16) PageCapacity {
	return std_capacity.adjust(cols)
}

fn min_max_size_calc(cols u16, rows u16) usize {
	cap := initial_capacity(cols)
	pages_for_active := if cap.rows >= rows {
		usize(1)
	} else {
		(usize(rows) + usize(cap.rows) - 1) / usize(cap.rows)
	}
	// Always need at least one extra page
	pages := pages_for_active + 1
	return pages * usize(cap.cols) * usize(cap.rows) * 16
}

fn (self &PageList) max_size() usize {
	if self.explicit_max_size > self.min_max_size {
		return self.explicit_max_size
	}
	return self.min_max_size
}

// ============================================================
// Page creation / destruction
// ============================================================

fn (mut self PageList) create_page(cap PageCapacity) &PageNode {
	mut node := &PageNode{
		data: Page.init(cap)
		serial: self.page_serial
	}
	self.page_serial += 1
	self.page_size += usize(cap.cols) * usize(cap.rows) * 16
	return node
}

fn (mut self PageList) destroy_node(node &PageNode) {
	self.page_size -= usize(node.data.capacity.cols) * usize(node.data.capacity.rows) * 16
	self.pages.remove(node)
}

// ============================================================
// Grow
// ============================================================

// Grow the active area by one row. Returns the new node if one was allocated.
pub fn (mut self PageList) grow() ?&PageNode {
	// Fast path: last page has capacity
	if mut last := self.pages.last {
		if last.data.capacity.rows > last.data.size.rows {
			last.data.size.rows += 1
			self.total_rows += 1
			return none
		}
	}

	// Need a new page
	cap := initial_capacity(self.cols)

	// Check if we need to prune for max size
	first := self.pages.first or { return none }
	last := self.pages.last or { return none }
	if voidptr(first) != voidptr(last)
		&& self.page_size + usize(cap.cols) * usize(cap.rows) * 16 > self.max_size() {
		// Prune the first page
		pruned := self.pages.pop_first() or { return none }

		self.total_rows -= usize(pruned.data.size.rows)

		// Check if pruning would violate minimum rows
		if self.total_rows + 1 < usize(self.rows) {
			// Can't prune, put it back
			self.pages.prepend(pruned)
			self.total_rows += usize(pruned.data.size.rows)
		} else {
			// Update viewport if needed
			if self.viewport == .pin {
				if v := self.viewport_pin_row_offset {
					if v < usize(pruned.data.size.rows) {
						self.viewport = .top
					} else {
						self.viewport_pin_row_offset = v - usize(pruned.data.size.rows)
					}
				}
			}

			// Update tracked pins pointing to pruned page
			new_first := self.pages.first or { return none }
			for mut p in self.tracked_pins {
				if voidptr(p.node) == voidptr(pruned) {
					p.node = new_first
					p.y = 0
					p.x = 0
					p.garbage = true
				}
			}
			self.viewport_pin.garbage = false

			// Reinit pruned page and reuse it
			unsafe {
				mut mp := pruned
				mp.data.reinit(cap)
				mp.data.size.rows = 1
				self.page_serial_min = mp.serial + 1
				mp.serial = self.page_serial
			}
			self.page_serial += 1
			self.pages.append(pruned)
			self.total_rows += 1

			return pruned
		}
	}

	// Allocate new page
	mut new_node := self.create_page(cap)
	new_node.data.size.rows = 1
	self.pages.append(new_node)
	self.total_rows += 1

	return new_node
}

// Grow by n rows (convenience for tests).
pub fn (mut self PageList) grow_rows(n usize) {
	for _ in 0 .. n {
		self.grow() or {}
	}
}

// ============================================================
// Get top-left / bottom-right
// ============================================================

pub fn (self &PageList) get_top_left(tag PointTag) PagePin {
	match tag {
		.screen, .history {
			node := self.pages.first or { return PagePin{} }
			return PagePin{
				node: node
				y: 0
				x: 0
			}
		}
		.viewport {
			return match self.viewport {
				.active { self.get_top_left(.active) }
				.top { self.get_top_left(.screen) }
				.pin {
					PagePin{
						node: self.viewport_pin.node
						y: self.viewport_pin.y
						x: 0
					}
				}
			}
		}
		.active {
			// Walk backward from last page to find active area start
			mut rem := usize(self.rows)
			mut node := self.pages.last
			for {
				n := node or { break }
				if usize(n.data.size.rows) >= rem {
					return PagePin{
						node: n
						y: u16(usize(n.data.size.rows) - rem)
						x: 0
					}
				}
				rem -= usize(n.data.size.rows)
				node = n.prev
			}
			// Fallback: first page
			first := self.pages.first or { return PagePin{} }
			return PagePin{
				node: first
				y: 0
				x: 0
			}
		}
	}
}

pub fn (self &PageList) get_bottom_right(tag PointTag) ?PagePin {
	match tag {
		.screen, .active {
			last := self.pages.last or { return none }
			if last.data.size.rows == 0 {
				return none
			}
			return PagePin{
				node: last
				y: u16(last.data.size.rows - 1)
				x: self.cols - 1
			}
		}
		.viewport {
			tl := self.get_top_left(.viewport)
			p := tl.down(u32(self.rows) - 1) or { return none }
			return PagePin{
				node: p.node
				y: p.y
				x: self.cols - 1
			}
		}
		.history {
			active_tl := self.get_top_left(.active)
			p := active_tl.up(1) or { return none }
			return PagePin{
				node: p.node
				y: p.y
				x: self.cols - 1
			}
		}
	}
}

// ============================================================
// Pin / Track Pin
// ============================================================

// Convert a point to a PagePin.
pub fn (self &PageList) get_pin(tag PointTag, x u16, y u16) ?PagePin {
	if x >= self.cols {
		return none
	}
	tl := self.get_top_left(tag)
	p := tl.down(u32(y)) or { return none }
	return PagePin{
		node: p.node
		y: p.y
		x: x
	}
}

// Track a pin so it auto-updates during modifications.
pub fn (mut self PageList) track_pin(p PagePin) &PagePin {
	tracked := &PagePin{
		node: p.node
		y: p.y
		x: p.x
		garbage: p.garbage
	}
	self.tracked_pins << tracked
	return tracked
}

// Untrack a pin.
pub fn (mut self PageList) untrack_pin(p &PagePin) {
	pp := voidptr(p)
	vp := voidptr(self.viewport_pin)
	assert pp != vp, 'cannot untrack viewport pin'
	for i, tp in self.tracked_pins {
		if voidptr(tp) == pp {
			self.tracked_pins.delete(i)
			return
		}
	}
}

// Returns true if pin points to a valid page in the list.
pub fn (self &PageList) pin_is_valid(p PagePin) bool {
	mut node := self.pages.first
	for {
		n := node or { return false }
		if voidptr(n) == voidptr(p.node) {
			return p.y < n.data.size.rows && p.x < self.cols
		}
		node = n.next
	}
	return false
}

// Convert a pin to a point in the given coordinate space.
pub fn (self &PageList) point_from_pin(tag PointTag, p PagePin) ?Pin {
	tl := self.get_top_left(tag)

	tl_ptr := voidptr(tl.node)
	p_ptr := voidptr(p.node)

	if tl_ptr == p_ptr {
		if tl.y > p.y {
			return none
		}
		return Pin{
			x: u32(p.x)
			y: u32(p.y - tl.y)
		}
	}

	// Traverse from tl forward to find p's node
	mut y := u32(tl.node.data.size.rows) - u32(tl.y)
	mut cur := tl.node.next
	for {
		node := cur or { return none }
		if voidptr(node) == p_ptr {
			return Pin{
				x: u32(p.x)
				y: y + u32(p.y)
			}
		}
		y += u32(node.data.size.rows)
		cur = node.next
	}
	return none
}

// Returns true if the pin is in the active area.
pub fn (self &PageList) pin_is_active(p PagePin) bool {
	active_tl := self.get_top_left(.active)
	active_ptr := voidptr(active_tl.node)
	p_ptr := voidptr(p.node)

	if active_ptr == p_ptr {
		return p.y >= active_tl.y
	}

	// Check if p.node is after active_tl.node
	mut cur := active_tl.node.next
	for {
		node := cur or { return false }
		if voidptr(node) == p_ptr {
			return true
		}
		cur = node.next
	}
	return false
}

// Returns true if the pin is at the very top.
fn (self &PageList) pin_is_top(p PagePin) bool {
	first := self.pages.first or { return false }
	return voidptr(p.node) == voidptr(first) && p.y == 0
}

// ============================================================
// Get Cell
// ============================================================

pub fn (self &PageList) get_cell(tag PointTag, x u16, y u16) ?PageCell {
	p := self.get_pin(tag, x, y) or { return none }
	if int(p.y) >= p.node.data.rows.len {
		return none
	}
	row := &p.node.data.rows[int(p.y)]
	if int(p.x) >= row.cells.len {
		return none
	}
	return PageCell{
		node: p.node
		row: row
		cell: &row.cells[int(p.x)]
		row_idx: p.y
		col_idx: p.x
	}
}

// ============================================================
// Total pages / rows
// ============================================================

pub fn (self &PageList) total_pages() usize {
	mut count := usize(0)
	mut node := self.pages.first
	for {
		_ := node or { break }
		count += 1
		node = (node or { break }).next
	}
	return count
}

// Count total rows by traversal (for testing).
pub fn (self &PageList) count_total_rows() usize {
	mut count := usize(0)
	mut node := self.pages.first
	for {
		n := node or { break }
		count += usize(n.data.size.rows)
		node = n.next
	}
	return count
}

// ============================================================
// Scroll
// ============================================================

pub fn (mut self PageList) scroll(behavior PageScroll) {
	// No-scrollback mode
	if self.explicit_max_size == 0 {
		self.viewport = .active
		return
	}

	match behavior {
		PageScrollActive {
			self.viewport = .active
		}
		PageScrollTop {
			self.viewport = .top
		}
		PageScrollPin {
			p := (behavior as PageScrollPin).pin
			if self.pin_is_active(p) {
				self.viewport = .active
				return
			}
			if self.pin_is_top(p) {
				self.viewport = .top
				return
			}
			self.viewport_pin.node = p.node
			self.viewport_pin.y = p.y
			self.viewport_pin.x = p.x
			self.viewport = .pin
			self.viewport_pin_row_offset = none
		}
		PageScrollRow {
			n := (behavior as PageScrollRow).n
			if n == 0 {
				self.viewport = .top
				return
			}
			if n >= self.total_rows - usize(self.rows) {
				self.viewport = .active
				return
			}
			self.viewport_pin_row_offset = n
			self.viewport = .pin
			// Traverse to find the pin
			mut rem := usize(n)
			mut node := self.pages.first
			for {
				nd := node or { break }
				if rem < usize(nd.data.size.rows) {
					self.viewport_pin.node = nd
					self.viewport_pin.y = u16(rem)
					self.viewport_pin.x = 0
					return
				}
				rem -= usize(nd.data.size.rows)
				node = nd.next
			}
			self.viewport = .active
		}
		PageScrollDeltaRow {
			delta := (behavior as PageScrollDeltaRow).delta
			if delta == 0 {
				return
			}

			match self.viewport {
				.top {
					if delta <= 0 {
						return
					}
				}
				.active {
					if delta >= 0 {
						return
					}
				}
				.pin {
					if delta < 0 {
						abs_delta := u32(-delta)
						match self.viewport_pin.up_overflow(abs_delta) {
							UpOverflowOffset {
								uo := self.viewport_pin.up_overflow(abs_delta) as UpOverflowOffset
								self.viewport_pin.node = uo.pin.node
								self.viewport_pin.y = uo.pin.y
								self.viewport_pin.x = uo.pin.x
								if v := self.viewport_pin_row_offset {
									self.viewport_pin_row_offset = v - usize(abs_delta)
								}
								return
							}
							UpOverflowOverflow {
								self.viewport = .top
								return
							}
						}
					} else if delta > 0 {
						abs_delta := u32(delta)
						match self.viewport_pin.down_overflow(abs_delta) {
							DownOverflowOffset {
								dof := self.viewport_pin.down_overflow(abs_delta) as DownOverflowOffset
								if self.pin_is_active(dof.pin) {
									self.viewport = .active
								} else {
									self.viewport_pin.node = dof.pin.node
									self.viewport_pin.y = dof.pin.y
									self.viewport_pin.x = dof.pin.x
									if v := self.viewport_pin_row_offset {
										self.viewport_pin_row_offset = v + usize(abs_delta)
									}
								}
								return
							}
							DownOverflowOverflow {
								self.viewport = .active
								return
							}
						}
					}
					return
				}
			}

			// Slow path: calculate from viewport top
			tl := self.get_top_left(.viewport)
			p := if delta < 0 {
				match tl.up_overflow(u32(-delta)) {
					UpOverflowOffset {
						(tl.up_overflow(u32(-delta)) as UpOverflowOffset).pin
					}
					UpOverflowOverflow {
						(tl.up_overflow(u32(-delta)) as UpOverflowOverflow).end
					}
				}
			} else {
				match tl.down_overflow(u32(delta)) {
					DownOverflowOffset {
						(tl.down_overflow(u32(delta)) as DownOverflowOffset).pin
					}
					DownOverflowOverflow {
						(tl.down_overflow(u32(delta)) as DownOverflowOverflow).end
					}
				}
			}

			if self.pin_is_active(p) {
				self.viewport = .active
				return
			}
			if self.pin_is_top(p) {
				self.viewport = .top
				return
			}
			self.viewport_pin.node = p.node
			self.viewport_pin.y = p.y
			self.viewport_pin.x = p.x
			self.viewport = .pin
			self.viewport_pin_row_offset = none
		}
		PageScrollDeltaPrompt {
			delta := (behavior as PageScrollDeltaPrompt).delta
			self.scroll_prompt(delta)
		}
	}
}

fn (mut self PageList) scroll_prompt(delta int) {
	if delta == 0 {
		return
	}
	abs_delta := if delta > 0 { usize(delta) } else { usize(-delta) }
	mut rem := abs_delta

	tl := self.get_top_left(.viewport)
	start_opt := if delta > 0 { tl.down(1) } else { tl.up(1) }
	start := start_opt or { return }

	mut it := start.prompt_iterator(if delta > 0 { .right_down } else { .left_up }, none)
	mut prompt_pin := ?PagePin(none)
	for {
		next := it.next() or { break }
		prompt_pin = next
		rem -= 1
		if rem == 0 {
			break
		}
	}

	if p := prompt_pin {
		if self.pin_is_active(p) {
			self.viewport = .active
		} else {
			self.viewport_pin.node = p.node
			self.viewport_pin.y = p.y
			self.viewport_pin.x = p.x
			self.viewport = .pin
			self.viewport_pin_row_offset = none
		}
	}
}

// ============================================================
// Scroll Clear
// ============================================================

// Scroll written content into scrollback. Does not update viewport.
pub fn (mut self PageList) scroll_clear() {
	// Find first non-empty row in active area, walking backward
	non_empty := self.count_non_empty_active_rows()
	if non_empty == 0 {
		return
	}
	for _ in 0 .. non_empty {
		self.grow() or {}
	}
}

fn (self &PageList) count_non_empty_active_rows() usize {
	tl := self.get_top_left(.active)
	mut count := usize(0)
	mut pin := ?PagePin(PagePin{
		node: tl.node
		y: tl.y
		x: 0
	})
	for {
		p := pin or { break }
		if int(p.y) < p.node.data.rows.len {
			row := p.node.data.rows[int(p.y)]
			for cell in row.cells {
				if cell.content_tag == .codepoint && cell.codepoint != 0 {
					count += 1
					break
				}
			}
		}
		pin = p.down(1)
	}
	return count
}

// ============================================================
// Scrollbar
// ============================================================

pub fn (self &PageList) scrollbar() Scrollbar {
	if self.explicit_max_size == 0 {
		return Scrollbar{
			total: usize(self.rows)
			offset: 0
			len: usize(self.rows)
		}
	}
	return Scrollbar{
		total: self.total_rows
		offset: self.viewport_row_offset()
		len: usize(self.rows)
	}
}

pub fn (self &PageList) viewport_row_offset() usize {
	return match self.viewport {
		.top { usize(0) }
		.active { self.total_rows - usize(self.rows) }
		.pin {
			if v := self.viewport_pin_row_offset {
				v
			} else {
				// Calculate by traversal
				mut offset := usize(0)
				mut node := self.pages.first
				for {
					n := node or { break }
					if voidptr(n) == voidptr(self.viewport_pin.node) {
						return offset + usize(self.viewport_pin.y)
					}
					offset += usize(n.data.size.rows)
					node = n.next
				}
				self.total_rows - usize(self.rows) // fallback
			}
		}
	}
}

// ============================================================
// Erase Row
// ============================================================

// Erase a single row, shifting subsequent rows up.
pub fn (mut self PageList) erase_row(p PagePin) {
	mut node := p.node
	mut page := &node.data
	y := int(p.y)

	// Shift rows up within the page
	for i in y .. int(page.size.rows) - 1 {
		if i + 1 < page.rows.len && i < page.rows.len {
			page.rows[i] = page.rows[i + 1].clone_row(u32(page.size.cols))
		}
	}

	// Clear the last row
	last_idx := int(page.size.rows) - 1
	if last_idx >= 0 && last_idx < page.rows.len {
		page.clear_row(u16(last_idx))
	}

	// Pull from next pages
	mut cur_node := node.next
	mut prev_node := node
	for {
		cn := cur_node or { break }
		mut cp := &cn.data
		if cp.size.rows == 0 {
			cur_node = cn.next
			continue
		}

		// Copy first row of next page to last row of previous page
		mut prev_page := unsafe { &prev_node.data }
		if int(prev_page.size.rows) - 1 >= 0 && int(prev_page.size.rows) - 1 < prev_page.rows.len
			&& cp.rows.len > 0 {
			prev_page.rows[int(prev_page.size.rows) - 1] = cp.rows[0].clone_row(u32(cp.size.cols))
		}

		// Shift rows in next page
		for i in 0 .. int(cp.size.rows) - 1 {
			if i + 1 < cp.rows.len && i < cp.rows.len {
				cp.rows[i] = cp.rows[i + 1].clone_row(u32(cp.size.cols))
			}
		}

		// Clear last row in this page
		li := int(cp.size.rows) - 1
		if li >= 0 && li < cp.rows.len {
			cp.clear_row(u16(li))
		}

		unsafe {
			prev_node = cn
		}
		cur_node = cn.next
	}

	// Update tracked pins
	for mut tp in self.tracked_pins {
		if voidptr(tp.node) == voidptr(node) && tp.y > p.y {
			if tp.y > 0 {
				tp.y -= 1
			}
		}
	}

	// Mark dirty
	page.dirty = true
}

// ============================================================
// Erase Rows
// ============================================================

// Erase a range of rows from tl to bl (inclusive).
pub fn (mut self PageList) erase_rows(tl PointTag, bl ?PointTag) {
	tl_pin := self.get_top_left(tl)
	bl_pin := if bt := bl {
		self.get_bottom_right(bt) or { return }
	} else {
		self.get_bottom_right(tl) or { return }
	}

	// Count rows to erase
	mut erased := usize(0)
	mut it := tl_pin.page_iterator(.right_down, bl_pin)
	for {
		chunk := it.next() or { break }
		rows_in_chunk := usize(chunk.end) - usize(chunk.start)

		if chunk.is_full_page() {
			// Can erase the whole page
			if (self.pages.first != none && voidptr(chunk.node) != voidptr(self.pages.first or {
				unsafe { &PageNode(nil) }
			})) || (self.pages.last != none && voidptr(chunk.node) != voidptr(self.pages.last or {
				unsafe { &PageNode(nil) }
			})) {
				// Move tracked pins away from this page
				next := chunk.node.next or { chunk.node.prev or { chunk.node } }
				for mut tp in self.tracked_pins {
					if voidptr(tp.node) == voidptr(chunk.node) {
						tp.node = next
						tp.y = 0
						tp.x = 0
						tp.garbage = true
					}
				}
				self.viewport_pin.garbage = false

				self.pages.remove(chunk.node)
			} else {
				// Single remaining page - just clear it
				mut page := &chunk.node.data
				page.size.rows = 0
			}
		} else {
			// Partial page erase - shift rows
			mut page := &chunk.node.data
			start := int(chunk.start)
			end := int(chunk.end)
			remaining := int(page.size.rows) - end

			// Shift remaining rows up
			for i in 0 .. remaining {
				if start + i < page.rows.len && end + i < page.rows.len {
					page.rows[start + i] = page.rows[end + i].clone_row(u32(page.size.cols))
				}
			}

			page.size.rows -= u16(end - start)

			// Update tracked pins
			for mut tp in self.tracked_pins {
				if voidptr(tp.node) == voidptr(chunk.node) {
					if tp.y >= u16(end) {
						tp.y -= u16(end - start)
					} else if tp.y >= u16(start) {
						tp.y = u16(start)
						tp.x = 0
						tp.garbage = true
					}
				}
			}
			self.viewport_pin.garbage = false
			page.dirty = true
		}

		erased += rows_in_chunk
	}

	self.total_rows -= erased

	// Regrow if needed to maintain active area
	for self.total_rows < usize(self.rows) {
		self.grow() or {}
		// Clear the new row
		if mut last := self.pages.last {
			last.data.clear_row(u16(last.data.size.rows - 1))
		}
	}
}

// ============================================================
// Split
// ============================================================

// Split a page at the given pin, creating a new page for rows from pin.y onwards.
pub fn (mut self PageList) split(p PagePin) ! {
	mut page := unsafe { &p.node.data }
	if page.size.rows <= 1 {
		return error('cannot split page with <= 1 row')
	}
	if p.y == 0 {
		return
	}

	// Create new page with same capacity
	new_node := self.create_page(page.capacity)
	mut new_page := &new_node.data

	y_start := p.y
	y_end := page.size.rows
	new_page.size.rows = y_end - y_start
	new_page.size.cols = page.size.cols
	new_page.clone_from(page, y_start, y_end)

	// Update tracked pins
	for mut tp in self.tracked_pins {
		if voidptr(tp.node) == voidptr(p.node) && tp.y >= p.y {
			tp.node = new_node
			tp.y -= p.y
		}
	}

	// Clear original page rows and reduce size
	for i in int(y_start) .. int(y_end) {
		if i < page.rows.len {
			page.clear_row(u16(i))
		}
	}
	unsafe {
		mut mp := p.node
		mp.data.size.rows = y_start
	}

	// Insert after original
	self.pages.insert_after(p.node, new_node)
}

// ============================================================
// Clone
// ============================================================

pub fn (self &PageList) clone(opts PageCloneOpts) PageList {
	tl_pin := self.get_top_left(opts.top)
	bl_pin := if bt := opts.bot {
		self.get_bottom_right(bt) or { return PageList.init(self.cols, self.rows, self.explicit_max_size) }
	} else {
		self.get_bottom_right(opts.top) or {
			return PageList.init(self.cols, self.rows, self.explicit_max_size)
		}
	}

	mut result := PageList.init(self.cols, self.rows, self.explicit_max_size)
	// Clear default pages
	result.pages = PageNodeList{}
	result.total_rows = 0
	result.page_size = 0

	mut it := tl_pin.page_iterator(.right_down, bl_pin)
	for {
		chunk := it.next() or { break }
		new_node := result.create_page(chunk.node.data.capacity)
		mut new_page := &new_node.data
		new_page.size.rows = chunk.end - chunk.start
		new_page.size.cols = chunk.node.data.size.cols
		new_page.clone_from(&chunk.node.data, chunk.start, chunk.end)
		new_page.dirty = chunk.node.data.dirty

		result.pages.append(new_node)
		result.total_rows += usize(new_page.size.rows)
	}

	// Ensure viewport pin points to valid node
	if first := result.pages.first {
		result.viewport_pin.node = first
		result.viewport_pin.y = 0
		result.viewport_pin.x = 0
	}

	// Ensure we have enough rows for active area
	for result.total_rows < usize(self.rows) {
		result.grow() or {}
		if mut last := result.pages.last {
			last.data.clear_row(u16(last.data.size.rows - 1))
		}
	}

	return result
}

// ============================================================
// Resize
// ============================================================

pub fn (mut self PageList) resize(opts PageResizeOpts) {
	self.viewport_pin_row_offset = none

	if !opts.reflow {
		self.resize_without_reflow(opts)
		return
	}

	cols := opts.cols or { self.cols }

	if cols == self.cols {
		self.resize_without_reflow(opts)
	} else if cols > self.cols {
		// Grow cols then rows
		self.resize_cols(cols, opts.cursor)
		self.resize_without_reflow(opts)
	} else {
		// Shrink: change rows first, then cols
		mut copy_opts := PageResizeOpts{
			cols: self.cols
			rows: opts.rows
			reflow: opts.reflow
			cursor: opts.cursor
		}
		self.resize_without_reflow(copy_opts)
		self.resize_cols(cols, opts.cursor)
	}

	// Fix up viewport if it's now in active area
	if self.viewport == .pin {
		vp := PagePin{
			node: self.viewport_pin.node
			y: self.viewport_pin.y
			x: self.viewport_pin.x
		}
		if self.pin_is_active(vp) {
			self.viewport = .active
		}
	}
}

fn (mut self PageList) resize_without_reflow(opts PageResizeOpts) {
	cols := opts.cols or { self.cols }
	rows := opts.rows or { self.rows }

	// Handle column changes
	if cols != self.cols {
		self.cols = cols
		// Adjust all page capacities and row widths
		mut node := self.pages.first
		for {
			n := node or { break }
			mut page := &n.data
			// Adjust row cells
			for mut row in page.rows {
				if row.cells.len < int(cols) {
					for _ in row.cells.len .. int(cols) {
						row.cells << CellData{}
					}
				} else if row.cells.len > int(cols) {
					row.cells = row.cells[..int(cols)]
				}
			}
			page.size.cols = cols
			page.capacity.cols = cols
			node = n.next
		}

		// Clamp tracked pins
		for mut tp in self.tracked_pins {
			if tp.x >= cols {
				tp.x = cols - 1
			}
		}
	}

	// Handle row changes
	if rows != self.rows {
		old_rows := self.rows
		self.rows = rows

		if rows > old_rows {
			// Need more rows
			diff := int(rows) - int(old_rows)
			for _ in 0 .. diff {
				self.grow() or {}
			}
		} else {
			// Fewer rows - trim from scrollback if possible
			// The active area shrinks; extra rows become scrollback
		}

		// Recalculate min_max_size
		self.min_max_size = min_max_size_calc(self.cols, self.rows)
	}
}

fn (mut self PageList) resize_cols(cols u16, cursor ?PageResizeCursor) {
	// TODO: Full reflow implementation.
	// For now, do a simple column adjustment without reflow.
	// Real reflow would unwrap/rewrap soft-wrapped lines.
	self.cols = cols

	// Create new pages with reflowed content
	// For simplicity, just adjust column counts in existing pages
	mut node := self.pages.first
	for {
		n := node or { break }
		mut page := &n.data
		for mut row in page.rows {
			if row.cells.len < int(cols) {
				for _ in row.cells.len .. int(cols) {
					row.cells << CellData{}
				}
			} else if row.cells.len > int(cols) {
				row.cells = row.cells[..int(cols)]
			}
		}
		page.size.cols = cols
		page.capacity.cols = cols
		node = n.next
	}

	// Clamp tracked pins
	for mut tp in self.tracked_pins {
		if tp.x >= cols {
			tp.x = cols - 1
		}
	}
}

// ============================================================
// Dirty tracking
// ============================================================

pub fn (mut self PageList) clear_dirty() {
	mut node := self.pages.first
	for {
		mut n := node or { break }
		n.data.dirty = false
		for mut row in n.data.rows {
			row.dirty = false
		}
		node = n.next
	}
}

pub fn (self &PageList) is_dirty() bool {
	mut node := self.pages.first
	for {
		n := node or { break }
		if n.data.dirty {
			return true
		}
		for row in n.data.rows {
			if row.dirty {
				return true
			}
		}
		node = n.next
	}
	return false
}

// ============================================================
// Iterator factory methods on PageList
// ============================================================

pub fn (self &PageList) page_iterator(direction IterDirection, tl PointTag, bl ?PointTag) PageIterator {
	tl_pin := self.get_top_left(tl)
	bl_pin := if bt := bl {
		self.get_bottom_right(bt) or { return PageIterator{} }
	} else {
		self.get_bottom_right(tl) or { return PageIterator{} }
	}

	return match direction {
		.right_down {
			tl_pin.page_iterator(.right_down, bl_pin)
		}
		.left_up {
			bl_pin.page_iterator(.left_up, tl_pin)
		}
	}
}

pub fn (self &PageList) row_iterator(direction IterDirection, tl PointTag, bl ?PointTag) RowIterator {
	tl_pin := self.get_top_left(tl)
	bl_pin := if bt := bl {
		self.get_bottom_right(bt) or { return RowIterator{} }
	} else {
		self.get_bottom_right(tl) or { return RowIterator{} }
	}

	return match direction {
		.right_down {
			tl_pin.row_iterator(.right_down, bl_pin)
		}
		.left_up {
			bl_pin.row_iterator(.left_up, tl_pin)
		}
	}
}

pub fn (self &PageList) cell_iterator(direction IterDirection, tl PointTag, bl ?PointTag) CellIterator {
	tl_pin := self.get_top_left(tl)
	bl_pin := if bt := bl {
		self.get_bottom_right(bt) or { return CellIterator{} }
	} else {
		self.get_bottom_right(tl) or { return CellIterator{} }
	}

	return match direction {
		.right_down {
			tl_pin.cell_iterator(.right_down, bl_pin)
		}
		.left_up {
			bl_pin.cell_iterator(.left_up, tl_pin)
		}
	}
}

// ============================================================
// Assert Integrity
// ============================================================

pub fn (self &PageList) assert_integrity() {
	// Verify total_rows cache
	actual := self.count_total_rows()
	assert actual == self.total_rows, 'total_rows mismatch: cached=${self.total_rows} actual=${actual}'
}

pub fn (self &PageList) verify_integrity() bool {
	actual := self.count_total_rows()
	if actual != self.total_rows {
		return false
	}
	// Verify tracked pins
	for p in self.tracked_pins {
		if !self.pin_is_valid(PagePin{
			node: p.node
			y: p.y
			x: p.x
		}) {
			return false
		}
	}
	return true
}

// ============================================================
// RowData helper for cloning
// ============================================================

fn (self &RowData) clone_row(cols u32) RowData {
	return RowData{
		cells: self.cells.clone()
		wrap: self.wrap
		wrap_continuation: self.wrap_continuation
		dirty: self.dirty
		styled: self.styled
		grapheme: self.grapheme
		hyperlink: self.hyperlink
		semantic_prompt: self.semantic_prompt
	}
}
