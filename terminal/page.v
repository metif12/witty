module terminal

// Page represents a single page of terminal content.
// In Ghostty/Zig, pages use offset-based memory with a flat buffer.
// In V, we use V arrays and let the GC handle memory.

// ============================================================
// Constants
// ============================================================

// Standard capacity for a new page.
const std_capacity = PageCapacity{
	cols: 80
	rows: 128
}

// Number of pages to preheat the pool with.
const page_preheat = 4

// ============================================================
// PageCapacity - describes how many cols/rows a page can hold
// ============================================================

pub struct PageCapacity {
pub mut:
	cols u16 = 80
	rows u16 = 128
}

// Adjust capacity to fit the given column count, keeping the
// standard row count or reducing it if columns are very large.
pub fn (self PageCapacity) adjust(cols u16) PageCapacity {
	// Simple heuristic: if cols > 256, reduce rows proportionally
	// to keep approximate memory usage similar.
	mut new_rows := self.rows
	if cols > 256 {
		// Reduce rows proportionally
		new_rows = u16(u32(self.rows) * 256 / u32(cols))
		if new_rows < 1 {
			new_rows = 1
		}
	}
	return PageCapacity{
		cols: cols
		rows: new_rows
	}
}

// ============================================================
// PageSize - actual used size within a page
// ============================================================

pub struct PageSize {
pub mut:
	cols u16
	rows u16
}

// ============================================================
// Page - a page of terminal rows
// ============================================================

@[heap]
pub struct Page {
pub mut:
	rows     []RowData
	capacity PageCapacity
	size     PageSize
	dirty    bool
}

// Create a new page with the given capacity.
pub fn Page.init(cap PageCapacity) Page {
	mut rows := []RowData{cap: int(cap.rows)}
	for _ in 0 .. int(cap.rows) {
		rows << RowData.init(u32(cap.cols))
	}
	return Page{
		rows: rows
		capacity: cap
		size: PageSize{
			cols: cap.cols
			rows: 0
		}
	}
}

// Clear all cells in a row range.
pub fn (mut self Page) clear_cells(row_idx u16, start_col u16, end_col u16) {
	if int(row_idx) >= self.rows.len {
		return
	}
	mut row := &self.rows[int(row_idx)]
	for x in int(start_col) .. int(end_col) {
		if x < row.cells.len {
			row.cells[x] = CellData{}
		}
	}
	row.dirty = true
}

// Clear an entire row.
pub fn (mut self Page) clear_row(row_idx u16) {
	self.clear_cells(row_idx, 0, self.size.cols)
	if int(row_idx) < self.rows.len {
		mut row := &self.rows[int(row_idx)]
		row.wrap = false
		row.wrap_continuation = false
		row.styled = false
		row.grapheme = false
		row.hyperlink = false
		row.semantic_prompt = .unknown
	}
}

// Clone row data from another page. Copies rows [start..end) from src
// into this page starting at row 0.
pub fn (mut self Page) clone_from(src &Page, start u16, end u16) {
	count := int(end) - int(start)
	for i in 0 .. count {
		src_idx := int(start) + i
		if src_idx >= src.rows.len || i >= self.rows.len {
			break
		}
		src_row := src.rows[src_idx]
		mut dst_row := &self.rows[i]
		dst_row.cells = src_row.cells.clone()
		dst_row.wrap = src_row.wrap
		dst_row.wrap_continuation = src_row.wrap_continuation
		dst_row.dirty = src_row.dirty
		dst_row.styled = src_row.styled
		dst_row.grapheme = src_row.grapheme
		dst_row.hyperlink = src_row.hyperlink
		dst_row.semantic_prompt = src_row.semantic_prompt
	}
}

// Clone a single row from another page.
pub fn (mut self Page) clone_row_from(src &Page, dst_row_idx u16, src_row_idx u16) {
	if int(src_row_idx) >= src.rows.len || int(dst_row_idx) >= self.rows.len {
		return
	}
	src_row := src.rows[int(src_row_idx)]
	mut dst_row := &self.rows[int(dst_row_idx)]
	dst_row.cells = src_row.cells.clone()
	dst_row.wrap = src_row.wrap
	dst_row.wrap_continuation = src_row.wrap_continuation
	dst_row.dirty = src_row.dirty
	dst_row.styled = src_row.styled
	dst_row.grapheme = src_row.grapheme
	dst_row.hyperlink = src_row.hyperlink
	dst_row.semantic_prompt = src_row.semantic_prompt
}

// Reinitialize the page with new capacity, clearing all content.
pub fn (mut self Page) reinit(cap PageCapacity) {
	self.capacity = cap
	self.size = PageSize{
		cols: cap.cols
		rows: 0
	}
	self.rows = []RowData{cap: int(cap.rows)}
	for _ in 0 .. int(cap.rows) {
		self.rows << RowData.init(u32(cap.cols))
	}
	self.dirty = false
}

// Returns true if a row is entirely blank (no codepoints).
pub fn (self &Page) row_is_blank(row_idx u16) bool {
	if int(row_idx) >= self.rows.len {
		return true
	}
	row := self.rows[int(row_idx)]
	for cell in row.cells {
		if cell.content_tag == .codepoint && cell.codepoint != 0 {
			return false
		}
	}
	return true
}

// ============================================================
// PageNode - a node in the doubly-linked list of pages
// ============================================================

@[heap]
pub struct PageNode {
pub mut:
	prev   ?&PageNode
	next   ?&PageNode
	data   Page
	serial u64
}

// ============================================================
// PageNodeList - doubly-linked list of PageNode
// ============================================================

pub struct PageNodeList {
pub mut:
	first ?&PageNode
	last  ?&PageNode
}

// Append a node to the end of the list.
pub fn (mut self PageNodeList) append(node &PageNode) {
	unsafe {
		mut n := node
		n.prev = self.last
		n.next = none
	}
	if mut l := self.last {
		l.next = node
	}
	self.last = node
	if self.first == none {
		self.first = node
	}
}

// Prepend a node to the beginning of the list.
pub fn (mut self PageNodeList) prepend(node &PageNode) {
	unsafe {
		mut n := node
		n.next = self.first
		n.prev = none
	}
	if mut f := self.first {
		f.prev = node
	}
	self.first = node
	if self.last == none {
		self.last = node
	}
}

// Remove a node from the list.
pub fn (mut self PageNodeList) remove(node &PageNode) {
	if p := node.prev {
		unsafe {
			mut mp := p
			mp.next = node.next
		}
	} else {
		self.first = node.next
	}
	if n := node.next {
		unsafe {
			mut mn := n
			mn.prev = node.prev
		}
	} else {
		self.last = node.prev
	}
	unsafe {
		mut mnode := node
		mnode.prev = none
		mnode.next = none
	}
}

// Insert a node after an existing node.
pub fn (mut self PageNodeList) insert_after(existing &PageNode, node &PageNode) {
	unsafe {
		mut n := node
		n.prev = existing
		n.next = existing.next
	}
	if next := existing.next {
		unsafe {
			mut mn := next
			mn.prev = node
		}
	} else {
		self.last = node
	}
	unsafe {
		mut me := existing
		me.next = node
	}
}

// Insert a node before an existing node.
pub fn (mut self PageNodeList) insert_before(existing &PageNode, node &PageNode) {
	unsafe {
		mut n := node
		n.next = existing
		n.prev = existing.prev
	}
	if prev := existing.prev {
		unsafe {
			mut mp := prev
			mp.next = node
		}
	} else {
		self.first = node
	}
	unsafe {
		mut me := existing
		me.prev = node
	}
}

// Pop and return the first node.
pub fn (mut self PageNodeList) pop_first() ?&PageNode {
	f := self.first or { return none }
	self.remove(f)
	return f
}

// Pop and return the last node.
pub fn (mut self PageNodeList) pop_last() ?&PageNode {
	l := self.last or { return none }
	self.remove(l)
	return l
}
