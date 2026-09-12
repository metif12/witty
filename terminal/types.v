module terminal

// Fundamental types for the terminal module.
// These types are used by both Screen and Terminal.

// ============================================================
// Constants
// ============================================================

// The default style ID (no style applied).
pub const default_style_id = u32(0)

// ============================================================
// Cell types
// ============================================================

// CellWide describes the width behavior of a cell.
pub enum CellWide {
	narrow
	wide
	spacer_tail
	spacer_head
}

// ContentTag describes what kind of content a cell holds.
// The content tag dictates the active field in CellData and possibly
// some other behaviors.
pub enum ContentTag {
	// A single codepoint, could be zero to be empty cell.
	codepoint
	// A codepoint that is part of a multi-codepoint grapheme cluster.
	// The codepoint field is active, but also expect more
	// codepoints in the graphemes data.
	codepoint_grapheme
	// The cell has no text but only a background color. This is an
	// optimization so that cells with only backgrounds don't take up
	// style map space and also don't require a style map lookup.
	bg_color_palette
	bg_color_rgb
}

// SemanticContent describes what the cell content semantically represents.
pub enum SemanticContent {
	output
	input
	prompt
}

// CellData is the data for a single cell in the terminal grid.
//
// The zero value of this struct must be a valid cell representing empty,
// since we zero initialize cells by default.
pub struct CellData {
pub mut:
	// The codepoint that this cell contains. If has_grapheme is false,
	// then this is the only codepoint in the cell. If has_grapheme is
	// true, then this is the first codepoint in the grapheme cluster.
	codepoint u32
	// The content tag dictates what kind of content this cell holds.
	content_tag ContentTag = .codepoint
	// The style ID to use for this cell within the style map. Zero
	// is always the default style so no lookup is required.
	style_id u32
	// The wide property of this cell, for wide characters.
	wide CellWide = .narrow
	// Whether this was written with the protection flag set.
	is_protected bool
	// Whether this cell has grapheme cluster data.
	has_grapheme bool
	// Whether this cell is a hyperlink.
	has_hyperlink bool
	// The resolved OSC 8 hyperlink. The Zig page stores this indirectly in a
	// ref-counted page table; the flat V Pages representation stores the same
	// value inline so copied render cells remain self-contained.
	hyperlink Hyperlink
	// The semantic type of the content of this cell.
	semantic_content SemanticContent = .output
	// Additional codepoints for grapheme clusters. These are the
	// codepoints in addition to the first codepoint. The first
	// codepoint is NOT included since it is on the cell itself.
	graphemes []u32
	// For bg_color content variants.
	color_palette u8
	color_rgb_r   u8
	color_rgb_g   u8
	color_rgb_b   u8
	// The actual style for this cell. Stored directly to avoid needing
	// a ref-counted style map for lookups.
	style CellStyle
}

// Helper to make a cell that just has a codepoint.
pub fn CellData.init(cp u32) CellData {
	return CellData{
		content_tag: .codepoint
		codepoint: cp
	}
}

// Returns true if this cell represents all zeroes.
pub fn (self &CellData) is_zero() bool {
	return self.codepoint == 0 && self.content_tag == .codepoint && self.style_id == 0
		&& self.wide == .narrow && !self.is_protected && !self.has_grapheme
		&& !self.has_hyperlink && self.semantic_content == .output
		&& self.graphemes.len == 0
}

// Returns true if the cell has displayable text.
//
// Cases this returns false:
//   - Cell text is blank
//   - Cell is styled but only with a background color and no text
pub fn (self &CellData) has_text() bool {
	return match self.content_tag {
		.codepoint, .codepoint_grapheme { self.codepoint != 0 }
		.bg_color_palette, .bg_color_rgb { false }
	}
}

// Returns the codepoint for this cell, or 0 for bg-only cells.
pub fn (self &CellData) codepoint_val() u32 {
	return match self.content_tag {
		.codepoint, .codepoint_grapheme { self.codepoint }
		.bg_color_palette, .bg_color_rgb { 0 }
	}
}

// The width in grid cells that this cell takes up.
pub fn (self &CellData) grid_width() int {
	return match self.wide {
		.narrow, .spacer_head, .spacer_tail { 1 }
		.wide { 2 }
	}
}

// Returns true if the cell has a non-default style.
pub fn (self &CellData) has_styling() bool {
	return self.style_id != default_style_id
}

// Returns true if the cell has no text or styling.
pub fn (self &CellData) is_empty() bool {
	return match self.content_tag {
		// Textual cells are empty if they have no text and are narrow.
		// The "narrow" requirement is because wide spacers are meaningful.
		.codepoint, .codepoint_grapheme {
			!self.has_text() && self.wide == .narrow
		}
		.bg_color_palette, .bg_color_rgb {
			false
		}
	}
}

// Returns true if the set of cells has text in any cell.
pub fn has_text_any(cells []CellData) bool {
	for cell in cells {
		if cell.has_text() {
			return true
		}
	}
	return false
}

// ============================================================
// Row types
// ============================================================

// SemanticPromptType tracks what kind of semantic prompt a row has.
pub enum SemanticPromptType {
	unknown
	prompt
	prompt_continuation
}

// RowData is the data for a single row in the terminal grid.
pub struct RowData {
pub mut:
	cells []CellData
	// True if this row is soft-wrapped. The first cell of the next
	// row is a continuation of this row.
	wrap bool
	// True if the previous row to this one is soft-wrapped and
	// this row is a continuation of that row.
	wrap_continuation bool
	// True if any of the cells in this row have multi-codepoint
	// grapheme clusters. If this is true, some fast paths are not
	// possible because erasing for example may need to clear existing
	// grapheme data.
	grapheme bool
	// True if any of the cells in this row have a ref-counted style.
	// This can have false positives but never a false negative.
	styled bool
	// True if any of the cells in this row are part of a hyperlink.
	// Similar to styled: can have false positives but never false negatives.
	hyperlink bool
	// The semantic prompt state for this row.
	semantic_prompt SemanticPromptType = .unknown
	// True if this row contains a virtual placeholder for the Kitty
	// graphics protocol. (U+10EEEE)
	kitty_virtual_placeholder bool
	// True if this row is dirty and requires a redraw.
	dirty bool
}

// Initialize a new row with the given number of columns.
pub fn RowData.init(cols u32) RowData {
	return RowData{
		cells: []CellData{len: int(cols)}
	}
}

// Returns true if this row has any managed memory outside of the
// row structure (graphemes, styles, hyperlinks).
pub fn (self &RowData) managed_memory() bool {
	// Ordered on purpose for likelihood.
	return self.styled || self.hyperlink || self.grapheme
}

// ============================================================
// Pin - a position in the terminal grid
// ============================================================

pub struct Pin {
pub mut:
	x u32
	y u32
}

// Returns true if this pin is before the other pin.
pub fn (self Pin) before(other Pin) bool {
	if self.y < other.y {
		return true
	}
	if self.y == other.y {
		return self.x < other.x
	}
	return false
}

// Returns true if the pins are equal.
pub fn (self Pin) eql(other Pin) bool {
	return self.x == other.x && self.y == other.y
}

// Move down by n rows, returning none if out of bounds.
pub fn (self Pin) down(n u32) ?Pin {
	return Pin{
		x: self.x
		y: self.y + n
	}
}

// Move up by n rows, returning none if would go negative.
pub fn (self Pin) up(n u32) ?Pin {
	if self.y < n {
		return none
	}
	return Pin{
		x: self.x
		y: self.y - n
	}
}

// ============================================================
// Selection
// ============================================================

pub struct Selection {
pub mut:
	start_pin Pin
	end_pin   Pin
	rectangle bool
}

pub fn Selection.init(start Pin, end Pin, rectangle bool) Selection {
	return Selection{
		start_pin: start
		end_pin: end
		rectangle: rectangle
	}
}

// The starting pin of the selection. This is NOT ordered.
pub fn (self &Selection) start() Pin {
	return self.start_pin
}

// The ending pin of the selection. This is NOT ordered.
pub fn (self &Selection) end() Pin {
	return self.end_pin
}

// ============================================================
// PinOpts - options for pin-based operations
// ============================================================

pub struct PinOpts {
pub:
	tag PointTag = .active
	x   u32
	y   u32
}

// ============================================================
// Pages - simplified page storage for the terminal grid
// ============================================================

@[heap]
pub struct Pages {
pub mut:
	screen_rows    []RowData
	active_start   int
	cols           u32
	rows           u32
	max_scrollback u32
	viewport       ViewportState = .active
	// Absolute row at the top of a pinned viewport.
	viewport_start int
	// After a resize, these hold the active-relative cursor position that
	// the caller (Screen) should apply to its cursor. Reflow moves the
	// cursor because soft-wrapped content is re-laid-out.
	reflow_cursor_x   u32
	reflow_cursor_y   u32
	reflow_cursor_abs int
	reflow_did_reflow bool
}

// ViewportState tracks where the viewport is positioned.
pub enum ViewportState {
	active
	top
	pinned
}

pub fn Pages.init(cols u32, rows u32, max_scrollback u32) Pages {
	mut screen_rows := []RowData{cap: int(rows)}
	for _ in 0 .. int(rows) {
		screen_rows << RowData.init(cols)
	}
	return Pages{
		screen_rows: screen_rows
		active_start: 0
		cols: cols
		rows: rows
		max_scrollback: max_scrollback
	}
}

pub fn (mut self Pages) deinit() {
	self.screen_rows = []
}

// scrollbar reports the total row count, viewport offset, and visible row
// count. This is the flat-storage equivalent of PageList.scrollbar.
pub fn (self &Pages) scrollbar() Scrollbar {
	if self.max_scrollback == 0 {
		return Scrollbar{
			total: usize(self.rows)
			offset: 0
			len: usize(self.rows)
		}
	}
	return Scrollbar{
		total: usize(self.screen_rows.len)
		offset: usize(clamp_int(self.viewport_start, 0, self.active_start))
		len: usize(self.rows)
	}
}

// Reset the pages: clear all rows, reset active_start.
pub fn (mut self Pages) reset() {
	self.screen_rows = []RowData{cap: int(self.rows)}
	for _ in 0 .. int(self.rows) {
		self.screen_rows << RowData.init(self.cols)
	}
	self.active_start = 0
	self.viewport = .active
	self.viewport_start = 0
}

// Get an active row (read-only).
pub fn (self &Pages) get_active_row(y u32) RowData {
	idx := self.active_start + int(y)
	if idx < self.screen_rows.len {
		return self.screen_rows[idx]
	}
	return RowData.init(self.cols)
}

// Get an active row (mutable).
pub fn (mut self Pages) get_active_row_mut(y u32) &RowData {
	idx := self.active_start + int(y)
	return unsafe { &self.screen_rows[idx] }
}

// Scroll the viewport.
pub fn (mut self Pages) scroll(behavior ViewportState) {
	self.viewport = behavior
	self.viewport_start = match behavior {
		.active { self.active_start }
		.top { 0 }
		.pinned { self.viewport_start }
	}
}

// Scroll the viewport by physical rows and clamp it between the top of
// scrollback and the active area.
pub fn (mut self Pages) scroll_delta(delta int) {
	base := match self.viewport {
		.active { self.active_start }
		.top { 0 }
		.pinned { self.viewport_start }
	}
	self.viewport_start = clamp_int(base + delta, 0, self.active_start)
	self.viewport = if self.viewport_start == 0 {
		.top
	} else if self.viewport_start == self.active_start {
		.active
	} else {
		.pinned
	}
}

fn clamp_int(value int, lower int, upper int) int {
	return if value < lower {
		lower
	} else if value > upper { upper } else { value }
}

// Scroll and clear - move all active content to scrollback.
pub fn (mut self Pages) scroll_clear() !int {
	// Only scroll through the final non-empty active row. Trailing blank rows
	// stay out of history, matching PageList.scrollClear.
	non_empty := self.count_non_empty_active_rows()
	mut pruned := 0
	for _ in 0 .. non_empty {
		pruned += self.grow()!
		self.active_start++
	}
	if self.viewport == .active {
		self.viewport_start = self.active_start
	}
	return pruned
}

fn (self &Pages) count_non_empty_active_rows() int {
	for offset in 0 .. int(self.rows) {
		active_y := int(self.rows) - offset - 1
		absolute_y := self.active_start + active_y
		if absolute_y < 0 || absolute_y >= self.screen_rows.len {
			continue
		}
		for cell in self.screen_rows[absolute_y].cells {
			if !cell.is_empty() {
				return active_y + 1
			}
		}
	}
	return 0
}

// Grow the screen by one row (for scrollback).
pub fn (mut self Pages) grow() !int {
	self.screen_rows << RowData.init(self.cols)
	return self.trim_scrollback()
}

// Trim scrollback to max_scrollback limit.
fn (mut self Pages) trim_scrollback() int {
	max := int(self.max_scrollback) + int(self.rows)
	mut pruned := 0
	for self.screen_rows.len > max && self.active_start > 0 {
		self.screen_rows.delete(0)
		self.active_start -= 1
		pruned++
		if self.viewport == .pinned && self.viewport_start > 0 {
			self.viewport_start -= 1
		}
	}
	if self.viewport == .active {
		self.viewport_start = self.active_start
	}
	return pruned
}

// Erase a specific row.
pub fn (mut self Pages) erase_row(opts PinOpts) ! {
	idx := match opts.tag {
		.active { self.active_start + int(opts.y) }
		else { int(opts.y) }
	}
	if idx < self.screen_rows.len {
		self.screen_rows.delete(idx)
		if self.active_start > idx {
			self.active_start -= 1
		}
		// Add blank row at end of active area
		active_end := self.active_start + int(self.rows)
		for self.screen_rows.len < active_end {
			self.screen_rows << RowData.init(self.cols)
		}
		if self.viewport == .active {
			self.viewport_start = self.active_start
		}
	}
}

// Erase an inclusive range of physical rows. Active rows are regrown at the
// bottom so the addressable terminal area always remains exactly `rows` tall.
pub fn (mut self Pages) erase_rows(tl Point, bl ?Point) {
	top := self.pin_point(tl) or { return }
	bottom := if point := bl {
		self.pin_point(point) or { return }
	} else {
		self.get_bottom_right(tl.tag) or { return }
	}
	if top.y > bottom.y {
		return
	}

	start := int(top.y)
	end := int(bottom.y)
	erased := end - start + 1
	old_active_start := self.active_start
	for _ in 0 .. erased {
		self.screen_rows.delete(start)
	}

	// Only deleted history rows move the active-area origin. Deleting active
	// rows shifts later active rows upward and the regrowth below fills the
	// vacated tail.
	if start < old_active_start {
		history_end := if end < old_active_start { end } else { old_active_start - 1 }
		self.active_start -= history_end - start + 1
	}
	if tl.tag == .active {
		for _ in 0 .. erased {
			self.screen_rows << RowData.init(self.cols)
		}
	}

	match self.viewport {
		.active {
			self.viewport_start = self.active_start
		}
		.top {
			self.viewport_start = 0
		}
		.pinned {
			if self.viewport_start > end {
				self.viewport_start -= erased
			} else if self.viewport_start >= start {
				self.viewport_start = start
			}
			self.viewport_start = clamp_int(self.viewport_start, 0, self.active_start)
		}
	}
}

// Get the top-left pin for a point tag.
pub fn (self &Pages) get_top_left(tag PointTag) Pin {
	return match tag {
		.screen { Pin{ x: 0, y: 0 } }
		.active { Pin{ x: 0, y: u32(self.active_start) } }
		.viewport { Pin{ x: 0, y: u32(self.viewport_start) } }
		.history { Pin{ x: 0, y: 0 } }
	}
}

// Get the bottom-right pin for a point tag.
pub fn (self &Pages) get_bottom_right(tag PointTag) ?Pin {
	return match tag {
		.screen { Pin{ x: self.cols - 1, y: u32(self.screen_rows.len - 1) } }
		.active { Pin{ x: self.cols - 1, y: u32(self.active_start + int(self.rows) - 1) } }
		.viewport {
			Pin{
				x: self.cols - 1
				y: u32(clamp_int(self.viewport_start + int(self.rows) - 1, 0, self.screen_rows.len - 1))
			}
		}
		.history {
			if self.active_start > 0 {
				Pin{ x: self.cols - 1, y: u32(self.active_start - 1) }
			} else {
				return none
			}
		}
	}
}

pub struct FlatCellIterator {
pub mut:
	pages     &Pages = unsafe { nil }
	cell      ?Pin
	limit     ?Pin
	direction IterDirection = .right_down
}

pub fn (self &Pages) cell_iterator(at Pin, direction IterDirection, limit ?Pin) FlatCellIterator {
	if int(at.y) >= self.screen_rows.len || at.x >= self.cols {
		return FlatCellIterator{}
	}
	return FlatCellIterator{
		pages: self
		cell: at
		limit: limit
		direction: direction
	}
}

pub fn (mut self FlatCellIterator) next() ?Pin {
	cell := self.cell or { return none }
	if limit := self.limit {
		if cell.eql(limit) {
			self.cell = none
			return cell
		}
	}

	match self.direction {
		.right_down {
			if cell.x + 1 < self.pages.cols {
				self.cell = Pin{ x: cell.x + 1, y: cell.y }
			} else if int(cell.y) + 1 < self.pages.screen_rows.len {
				self.cell = Pin{ x: 0, y: cell.y + 1 }
			} else {
				self.cell = none
			}
		}
		.left_up {
			if cell.x > 0 {
				self.cell = Pin{ x: cell.x - 1, y: cell.y }
			} else if cell.y > 0 {
				self.cell = Pin{ x: self.pages.cols - 1, y: cell.y - 1 }
			} else {
				self.cell = none
			}
		}
	}
	return cell
}

pub struct FlatPromptIterator {
pub mut:
	pages     &Pages = unsafe { nil }
	current   ?Pin
	limit     ?Pin
	direction IterDirection = .left_up
}

pub fn (self &Pages) prompt_iterator(at Pin, direction IterDirection, limit ?Pin) FlatPromptIterator {
	if int(at.y) >= self.screen_rows.len {
		return FlatPromptIterator{}
	}
	return FlatPromptIterator{
		pages: self
		current: at
		limit: limit
		direction: direction
	}
}

fn (self &Pages) pin_down(pin Pin) ?Pin {
	if int(pin.y) + 1 >= self.screen_rows.len {
		return none
	}
	return Pin{ x: pin.x, y: pin.y + 1 }
}

fn (self &Pages) pin_up(pin Pin) ?Pin {
	if pin.y == 0 {
		return none
	}
	return Pin{ x: pin.x, y: pin.y - 1 }
}

pub fn (mut self FlatPromptIterator) next() ?Pin {
	return match self.direction {
		.right_down { self.next_right_down() }
		.left_up { self.next_left_up() }
	}
}

fn (mut self FlatPromptIterator) next_right_down() ?Pin {
	start := self.current or { return none }
	mut current := ?Pin(start)
	for {
		p := current or { break }
		at_limit := if limit := self.limit { limit.eql(p) } else { false }
		match self.pages.screen_rows[int(p.y)].semantic_prompt {
			.unknown {
				if at_limit {
					break
				}
			}
			.prompt, .prompt_continuation {
				if at_limit {
					self.current = none
					return Pin{ x: 0, y: p.y }
				}

				mut end_pin := p
				for {
					next_pin := self.pages.pin_down(end_pin) or { break }
					match self.pages.screen_rows[int(next_pin.y)].semantic_prompt {
						.prompt_continuation {
							if limit := self.limit {
								if limit.eql(next_pin) {
									break
								}
							}
						}
						.prompt, .unknown {
							self.current = next_pin
							return Pin{ x: 0, y: p.y }
						}
					}
					end_pin = next_pin
				}

				self.current = none
				return Pin{ x: 0, y: p.y }
			}
		}
		current = self.pages.pin_down(p)
	}
	self.current = none
	return none
}

fn (mut self FlatPromptIterator) next_left_up() ?Pin {
	start := self.current or { return none }
	mut current := ?Pin(start)
	for {
		p := current or { break }
		at_limit := if limit := self.limit { limit.eql(p) } else { false }
		match self.pages.screen_rows[int(p.y)].semantic_prompt {
			.unknown {
				if at_limit {
					break
				}
			}
			.prompt {
				self.current = if at_limit { none } else { self.pages.pin_up(p) }
				return Pin{ x: 0, y: p.y }
			}
			.prompt_continuation {
				if at_limit {
					self.current = none
					return Pin{ x: 0, y: p.y }
				}

				mut end_pin := p
				for {
					prior := self.pages.pin_up(end_pin) or { break }
					if limit := self.limit {
						if limit.eql(prior) {
							break
						}
					}
					match self.pages.screen_rows[int(prior.y)].semantic_prompt {
						.unknown {
							self.current = prior
							return Pin{ x: 0, y: end_pin.y }
						}
						.prompt_continuation {}
						.prompt {
							self.current = self.pages.pin_up(prior)
							return Pin{ x: 0, y: prior.y }
						}
					}
					end_pin = prior
				}

				self.current = none
				return Pin{ x: 0, y: p.y }
			}
		}
		current = self.pages.pin_up(p)
	}
	self.current = none
	return none
}

pub struct SemanticHighlight {
pub mut:
	start Pin
	end   Pin
}

// Returns the boundaries of semantic content belonging to the prompt at `at`.
// This is the flat-storage translation of PageList.highlightSemanticContent.
pub fn (self &Pages) highlight_semantic_content(at Pin, content SemanticContent) ?SemanticHighlight {
	mut prompt_it := self.prompt_iterator(at, .right_down, none)
	first := prompt_it.next() or { return none }
	assert first.y == at.y
	zone_end := if next := prompt_it.next() {
		Pin{ x: self.cols - 1, y: next.y - 1 }
	} else {
		self.get_bottom_right(.screen) or { return none }
	}

	match content {
		.prompt {
			mut result := SemanticHighlight{
				start: Pin{ x: 0, y: at.y }
				end: at
			}
			mut it := self.cell_iterator(at, .right_down, zone_end)
			for {
				p := it.next() or { break }
				match self.screen_rows[int(p.y)].cells[int(p.x)].semantic_content {
					.prompt, .input {
						result.end = p
					}
					.output {
						break
					}
				}
			}
			return result
		}
		.input {
			mut result_start := ?Pin(none)
			mut result_end := Pin{}
			mut it := self.cell_iterator(at, .right_down, zone_end)
			for {
				p := it.next() or { return none }
				match self.screen_rows[int(p.y)].cells[int(p.x)].semantic_content {
					.prompt {}
					.input {
						result_start = p
						result_end = p
						break
					}
					.output {
						return none
					}
				}
			}
			for {
				p := it.next() or { break }
				match self.screen_rows[int(p.y)].cells[int(p.x)].semantic_content {
					.prompt {}
					.output {
						break
					}
					.input {
						result_end = p
					}
				}
			}
			return SemanticHighlight{
				start: result_start or { return none }
				end: result_end
			}
		}
		.output {
			mut result_start := ?Pin(none)
			mut result_end := Pin{}
			mut it := self.cell_iterator(at, .right_down, zone_end)
			for {
				p := it.next() or { return none }
				cell := self.screen_rows[int(p.y)].cells[int(p.x)]
				match cell.semantic_content {
					.prompt, .input {}
					.output {
						if !cell.has_text() {
							continue
						}
						result_start = p
						result_end = p
						break
					}
				}
			}
			for {
				p := it.next() or { break }
				cell := self.screen_rows[int(p.y)].cells[int(p.x)]
				match cell.semantic_content {
					.prompt, .input {
						break
					}
					.output {
						if cell.has_text() {
							result_end = p
						}
					}
				}
			}
			return SemanticHighlight{
				start: result_start or { return none }
				end: result_end
			}
		}
	}
}

// Resize the pages.
//
// The ordering of the column reflow and the row-count change matters and
// mirrors PageList.resize: when growing columns we reflow first (unwrap) then
// grow rows; when shrinking columns we change rows first (so more active rows
// are available) then reflow. This is what lets "more rows + less cols" pull
// the newly-unwrapped rows up into the enlarged active area.
pub fn (mut self Pages) resize(opts ResizeOpts) ! {
	self.reflow_did_reflow = false
	old_cols := self.cols
	cursor_abs := self.active_start + int(opts.cursor.y)

	// The PageList viewport pin is permanently tracked. The flat storage
	// model represents it as an absolute row, so include a temporary pin in
	// the same resize remapper used by Screen-owned tracked state.
	mut viewport_pin := Pin{}
	track_viewport := self.viewport == .pinned
	mut tracked_pins := opts.tracked_pins.clone()
	if track_viewport {
		viewport_pin = Pin{
			x: 0
			y: u32(clamp_int(self.viewport_start, 0, self.screen_rows.len - 1))
		}
		tracked_pins << &viewport_pin
	}

	if !opts.reflow || opts.cols == old_cols {
		// No reflow: columns (if any) change in place, then rows.
		if opts.cols != old_cols {
			self.resize_cols_no_reflow(opts.cols, mut tracked_pins)
		}
		self.resize_rows(opts.rows, opts.cursor.y, true, cursor_abs, tracked_pins)
	} else if opts.cols > old_cols {
		// Growing columns: reflow (unwrap) first, then grow rows.
		self.reflow_cols(opts.cols, opts.cursor.x, opts.cursor.y, mut tracked_pins)
		self.reflow_did_reflow = true
		self.resize_rows(opts.rows, opts.cursor.y, false, self.reflow_cursor_abs, tracked_pins)
	} else {
		// Shrinking columns: change rows first so the reflow has the proper
		// number of active rows to wrap into, then reflow.
		self.resize_rows(opts.rows, opts.cursor.y, true, cursor_abs, tracked_pins)
		self.reflow_cols(opts.cols, opts.cursor.x, opts.cursor.y, mut tracked_pins)
		self.reflow_did_reflow = true
	}

	// Finalize the reflowed cursor position (active-relative) now that the
	// active area is settled.
	if self.reflow_did_reflow {
		mut cy := self.reflow_cursor_abs - self.active_start
		if cy < 0 {
			cy = 0
		}
		if cy >= int(self.rows) {
			cy = int(self.rows) - 1
		}
		self.reflow_cursor_y = u32(cy)
		if self.reflow_cursor_x >= self.cols {
			self.reflow_cursor_x = self.cols - 1
		}
	}

	// An active viewport follows the active area's new top through row and
	// column reflow. Top remains anchored at zero; pinned viewports retain
	// their independently tracked absolute row.
	if self.viewport == .active {
		self.viewport_start = self.active_start
	} else if self.viewport == .top {
		self.viewport_start = 0
	} else if track_viewport {
		self.viewport_start = int(viewport_pin.y)
		if self.viewport_start >= self.active_start {
			self.viewport = .active
			self.viewport_start = self.active_start
		}
	}
}

// Change columns in place without reflow: truncate/pad each row.
fn (mut self Pages) resize_cols_no_reflow(new_cols u32, mut tracked_pins []&Pin) {
	self.cols = new_cols
	for mut row in self.screen_rows {
		if row.cells.len < int(new_cols) {
			for _ in row.cells.len .. int(new_cols) {
				row.cells << CellData{}
			}
		} else if row.cells.len > int(new_cols) {
			row.cells = row.cells[..int(new_cols)]
		}
	}
	for mut pin in tracked_pins {
		if pin.x >= new_cols {
			pin.x = new_cols - 1
		}
	}
}

// Change the active row count. Mirrors PageList.resizeWithoutReflow's row
// handling:
//   - Shrinking: prefer trimming trailing blank active rows over creating
//     history; any remainder just becomes history.
//   - Growing: if the cursor is at (or below) the bottom of the active area,
//     "pull down" scrollback (the active top moves up to include history),
//     growing blank rows only if there isn't enough history. If the cursor is
//     NOT at the bottom, just append blank rows so we don't drag scrollback
//     down. `has_cursor` distinguishes the "no cursor" case (always pull down).
fn (mut self Pages) resize_rows(new_rows u32, cursor_y u32, has_cursor bool, cursor_abs int, tracked_pins []&Pin) {
	old_rows := self.rows
	if old_rows == new_rows {
		self.rows = new_rows
		// Column reflow can unwrap several physical rows even when the visible
		// row count itself is unchanged. PageList.resizeWithoutReflow grows
		// fresh rows until the active area is full in this case; the flat model
		// must do the same or active-row lookups fall beyond screen_rows.
		required := self.active_start + int(new_rows)
		for self.screen_rows.len < required {
			self.screen_rows << RowData.init(self.cols)
		}
		return
	}

	if new_rows < old_rows {
		// Shrinking: trim trailing blank rows from the active area first.
		mut want_trim := int(old_rows - new_rows)
		for want_trim > 0 {
			last := self.screen_rows.len - 1
			// Only trim rows that are within the active area and blank.
			if last < self.active_start + int(new_rows) {
				break
			}
			if !has_text_any(self.screen_rows[last].cells) {
				// Ghostty never trims a row containing a tracked pin. The live
				// cursor is always tracked, as are the saved cursor, viewport,
				// and selection supplied by Screen.
				if last == cursor_abs {
					break
				}
				mut tracked := false
				for pin in tracked_pins {
					if int(pin.y) == last {
						tracked = true
						break
					}
				}
				if tracked {
					break
				}
				self.screen_rows.delete(last)
				want_trim--
			} else {
				break
			}
		}
		self.rows = new_rows
		// Any non-trimmed rows displaced by the smaller active area become
		// history. Keep the active area bottom-anchored, just as PageList's
		// active pin is derived from the final total row count.
		mut new_active := self.screen_rows.len - int(new_rows)
		if new_active < 0 {
			new_active = 0
		}
		self.active_start = new_active
		// Reflow may already have unwrapped more rows than the height shrink
		// removes. PageList still guarantees a complete active area by growing
		// blank rows after the rewritten content.
		for self.screen_rows.len < self.active_start + int(new_rows) {
			self.screen_rows << RowData.init(self.cols)
		}
		return
	}

	// Growing.
	// If the cursor is not at the bottom, just append blanks (no pull-down).
	if has_cursor && cursor_y < old_rows - 1 {
		delta := int(new_rows) - int(old_rows)
		self.rows = new_rows
		for _ in 0 .. delta {
			self.screen_rows << RowData.init(self.cols)
		}
		return
	}

	// Cursor at the bottom (or no cursor): pull down scrollback. The active
	// area top moves up to include history; only grow blanks if there isn't
	// enough total content.
	self.rows = new_rows
	if self.screen_rows.len < int(new_rows) {
		for _ in self.screen_rows.len .. int(new_rows) {
			self.screen_rows << RowData.init(self.cols)
		}
	}
	// Bottom-anchor the active area to the last `new_rows` rows.
	mut new_active := self.screen_rows.len - int(new_rows)
	if new_active < 0 {
		new_active = 0
	}
	self.active_start = new_active
}

// A tracked point during reflow: a source cell position we want remapped to
// its new position after re-wrapping. Used to follow the cursor and the
// active-area start across a column reflow.
struct FlatReflowPin {
mut:
	src_row int
	src_col int
	new_row int = -1
	new_col int
}

// FlatReflowCursor re-lays-out cells into a new column width. It is a
// faithful port of PageList's ReflowCursor to the flat `Pages` row array:
// it trims trailing blanks on non-wrapped rows, defers fully-blank trailing
// rows, and preserves wrap/wrap_continuation flags.
enum ReflowWriteResult {
	success
	repeat
	skip_next
	out_of_space
}

struct FlatReflowCursor {
mut:
	cols         int
	out          []RowData
	x            int
	pending_wrap bool
	new_rows     int
	pins         []&FlatReflowPin
}

fn (mut c FlatReflowCursor) y() int {
	return c.out.len - 1
}

fn (mut c FlatReflowCursor) append_row() {
	c.out << RowData.init(u32(c.cols))
	c.x = 0
	c.pending_wrap = false
}

fn (mut c FlatReflowCursor) cursor_forward() {
	if c.x == c.cols - 1 {
		c.pending_wrap = true
	} else {
		c.x += 1
	}
}

fn (mut c FlatReflowCursor) write_cell(cell CellData) ReflowWriteResult {
	dst_cols := c.cols
	match cell.content_tag {
		.codepoint, .codepoint_grapheme {
			match cell.wide {
				.narrow {
					c.out[c.y()].cells[c.x] = cell
				}
				.wide {
					if dst_cols > 1 {
						if c.x == dst_cols - 1 {
							// A wide char in the last column: insert a spacer
							// head and wrap before handling it.
							c.out[c.y()].cells[c.x] = CellData{
								content_tag: .codepoint
								codepoint: 0
								wide: .spacer_head
							}
							c.cursor_forward()
							return .repeat
						} else {
							c.out[c.y()].cells[c.x] = cell
						}
					} else {
						// Resizing to 1 column: wide chars become empty narrow
						// cells and their spacer tail is skipped.
						c.out[c.y()].cells[c.x] = CellData{
							content_tag: .codepoint
							codepoint: 0
							wide: .narrow
						}
						c.cursor_forward()
						return .skip_next
					}
				}
				.spacer_tail {
					if dst_cols > 1 {
						c.out[c.y()].cells[c.x] = cell
					} else {
						return .success
					}
				}
				.spacer_head {
					// Spacer heads are re-created when processing the wide
					// cell they belong to, so ignore the source one.
					return .success
				}
			}
		}
		.bg_color_palette, .bg_color_rgb {
			c.out[c.y()].cells[c.x] = cell
			c.cursor_forward()
			return .success
		}
	}

	// Propagate row-level flags for managed content on the copied cell.
	mut row := &c.out[c.y()]
	if cell.has_grapheme {
		row.grapheme = true
	}
	if cell.has_hyperlink {
		row.hyperlink = true
	}
	if cell.style_id != default_style_id {
		row.styled = true
	}
	if cell.codepoint_val() == kitty_unicode_placeholder {
		row.kitty_virtual_placeholder = true
	}
	c.cursor_forward()
	return .success
}

fn (mut c FlatReflowCursor) reflow_row(src RowData, src_abs int) {
	cells := src.cells
	mut cols_len := cells.len

	// Trim non-semantic rightmost blanks on non-wrapped rows.
	if !src.wrap {
		for cols_len > 0 {
			if !cells[cols_len - 1].is_empty() {
				break
			}
			cols_len--
		}
		// A blank row with a semantic prompt is meaningful; keep one cell.
		if cols_len == 0 && src.semantic_prompt != .unknown {
			cols_len = 1
		}
	}

	// Handle tracked pins: keep a pin in trailing blanks within the new
	// width, and make sure its row is processed so it can be remapped.
	for mut p in c.pins {
		if p.src_row != src_abs {
			continue
		}
		if p.src_col >= cols_len {
			limit := c.cols - 1 - c.x
			cl := if limit < 0 { 0 } else { limit }
			if p.src_col > cl {
				p.src_col = cl
			}
		}
		if p.src_col + 1 > cols_len {
			cols_len = p.src_col + 1
		}
	}

	// Defer blank rows so trailing blank rows are never written.
	if cols_len == 0 {
		if !src.wrap_continuation {
			c.new_rows++
		}
		return
	}

	// Our row isn't blank; write any deferred rows first.
	for c.new_rows > 0 {
		c.append_row()
		c.new_rows--
	}

	c.out[c.y()].semantic_prompt = src.semantic_prompt

	mut x := 0
	for x < cols_len {
		if c.pending_wrap {
			c.out[c.y()].wrap = true
			c.append_row()
			c.out[c.y()].semantic_prompt = src.semantic_prompt
			c.out[c.y()].wrap_continuation = true
		}

		// Remap any pins at this source position to the current dst.
		for mut p in c.pins {
			if p.src_row == src_abs && p.src_col == x {
				p.new_row = c.y()
				p.new_col = c.x
			}
		}

		result := c.write_cell(cells[x])
		match result {
			.success {
				x++
			}
			.skip_next {
				for mut p in c.pins {
					if p.src_row == src_abs && p.src_col == x + 1 {
						p.new_row = c.y()
						p.new_col = c.x
					}
				}
				x += 2
			}
			.repeat {}
			.out_of_space {
				// Cannot happen in the flat model (rows grow dynamically).
				x++
				c.cursor_forward()
			}
		}
	}

	// If the source row wasn't wrapped, the logical line ends here; defer a
	// scroll so the next row starts fresh.
	if !src.wrap {
		c.new_rows++
	}
}

// reflow_cols re-wraps all screen rows into new_cols columns, following the
// cursor (in active coordinates) to its new position. Updates screen_rows,
// cols, active_start, reflow_cursor_x and reflow_cursor_abs.
fn (mut self Pages) reflow_cols(new_cols u32, cur_x u32, cur_y u32, mut tracked_pins []&Pin) {
	old_active_start := self.active_start
	old_rows := int(self.rows)
	cursor_abs := self.active_start + int(cur_y)

	// Preserve the same number of active rows beneath the cursor (mirrors
	// PageList.resize_cols preserved_pin logic). This is what keeps a cleared
	// (scrollClear) active area from jumping to the bottom and pulling down
	// scrollback: we grow blank rows after the cursor so its distance from the
	// bottom is preserved.
	preserved_remaining := if int(cur_y) < old_rows { old_rows - int(cur_y) - 1 } else { 0 }

	// Count how many wrap-continuation rows precede the cursor within the old
	// active area, so we can offset any *additional* wraps introduced by the
	// reflow and avoid pushing the cursor's own logical line into scrollback.
	mut preserved_wrapped := 0
	for r := cursor_abs; r > old_active_start; r-- {
		if r < self.screen_rows.len && self.screen_rows[r].wrap_continuation {
			preserved_wrapped++
		}
	}

	mut cursor_pin := &FlatReflowPin{
		src_row: cursor_abs
		src_col: int(cur_x)
	}

	mut rc := FlatReflowCursor{
		cols: int(new_cols)
	}
	rc.pins << cursor_pin
	mut extra_pins := []&FlatReflowPin{cap: tracked_pins.len}
	for pin in tracked_pins {
		mapped := &FlatReflowPin{
			src_row: int(pin.y)
			src_col: int(pin.x)
		}
		extra_pins << mapped
		rc.pins << mapped
	}
	// Start with a single row, mirroring PageList's first rewritten node.
	rc.append_row()

	for i, row in self.screen_rows {
		rc.reflow_row(row, i)
	}

	self.cols = new_cols
	self.screen_rows = rc.out

	// Remapped cursor absolute row (falls back to bottom if it was never hit).
	mut cur_abs_new := if cursor_pin.new_row >= 0 {
		cursor_pin.new_row
	} else {
		if self.screen_rows.len > 0 { self.screen_rows.len - 1 } else { 0 }
	}

	// Grow blank rows beneath the cursor so it keeps the same number of rows
	// below it (adjusted for any extra wrapping of its own logical line). This
	// bottom-anchors the active area without dragging scrollback up.
	new_active_top := if self.screen_rows.len > old_rows {
		self.screen_rows.len - old_rows
	} else {
		0
	}
	mut wrapped := 0
	for r := cur_abs_new; r > new_active_top; r-- {
		if r < self.screen_rows.len && self.screen_rows[r].wrap_continuation {
			wrapped++
		}
	}
	wrap_delta := if wrapped > preserved_wrapped { wrapped - preserved_wrapped } else { 0 }
	current := self.screen_rows.len - cur_abs_new - 1

	mut req_rows := preserved_remaining
	req_rows = if req_rows > wrap_delta { req_rows - wrap_delta } else { 0 }
	req_rows = if req_rows > current { req_rows - current } else { 0 }
	for _ in 0 .. req_rows {
		self.screen_rows << RowData.init(new_cols)
	}

	// Anchor the active area to the bottom of the (grown) total rows.
	mut new_active := self.screen_rows.len - old_rows
	if new_active < 0 {
		new_active = 0
	}
	self.active_start = new_active

	self.reflow_cursor_abs = cur_abs_new
	self.reflow_cursor_x = if cursor_pin.new_row >= 0 {
		u32(cursor_pin.new_col)
	} else {
		cur_x
	}

	// Update every caller-owned pin in place. A valid tracked source pin is
	// forced into the reflow stream even when it points into trailing blanks,
	// so the fallback is only for defensive handling of an invalid input.
	for i, mapped in extra_pins {
		mut pin := tracked_pins[i]
		if mapped.new_row >= 0 {
			pin.x = u32(mapped.new_col)
			pin.y = u32(mapped.new_row)
		} else {
			pin.x = 0
			pin.y = u32(cur_abs_new)
		}
	}
}

// Convert a point tag + coordinates to a Pin.
pub fn (self &Pages) pin(opts PinOpts) ?Pin {
	y := match opts.tag {
		.screen { opts.y }
		.active { u32(self.active_start) + opts.y }
		.viewport { u32(self.viewport_start) + opts.y }
		.history { opts.y }
	}
	if y >= u32(self.screen_rows.len) {
		return none
	}
	if opts.x >= self.cols {
		return none
	}
	return Pin{
		x: opts.x
		y: y
	}
}

// Convert Ghostty's tagged Point representation to a flat-storage pin.
pub fn (self &Pages) pin_point(point Point) ?Pin {
	return self.pin(PinOpts{
		tag: point.tag
		x: u32(point.coord.x)
		y: point.coord.y
	})
}

// ============================================================
// ResizeOpts
// ============================================================

pub struct ResizeOpts {
pub:
	cols         u32
	rows         u32
	reflow       bool = true
	tracked_pins []&Pin
	cursor       struct {
	pub:
		x u32
		y u32
	}
}

// ============================================================
// Style types
// ============================================================

// CursorStyle describes the cursor appearance.
pub enum CursorStyle {
	block
	underline
	bar
	block_hollow
}

// UnderlineStyle for cell underline decoration.
pub enum UnderlineStyle {
	none
	single
	double
	curly
	dotted
	dashed
}

// StyleFlags contains boolean style attributes.
pub struct StyleFlags {
pub mut:
	bold          bool
	faint         bool
	italic        bool
	underline     UnderlineStyle = .none
	overline      bool
	blink         bool
	inverse       bool
	invisible     bool
	strikethrough bool
}

// ColorType describes what type of color is set.
pub enum ColorType {
	none
	palette
	rgb
}

// CellStyle holds the complete style for a cell.
pub struct CellStyle {
pub mut:
	flags           StyleFlags
	fg_color        ColorType = .none
	bg_color        ColorType = .none
	underline_color ColorType = .none
	fg_r            u8
	fg_g            u8
	fg_b            u8
	bg_r            u8
	bg_g            u8
	bg_b            u8
	fg_palette      u8
	bg_palette      u8
	// Dedicated underline-color storage, independent of the fg color.
	// Ghostty stores this in a separate Style.underline_color Color union.
	underline_r       u8
	underline_g       u8
	underline_b       u8
	underline_palette u8
}

// Returns true if this is the default (empty) style.
pub fn (self &CellStyle) default() bool {
	return !self.flags.bold && !self.flags.faint && !self.flags.italic
		&& self.flags.underline == .none && !self.flags.overline && !self.flags.blink
		&& !self.flags.inverse && !self.flags.invisible && !self.flags.strikethrough
		&& self.fg_color == .none && self.bg_color == .none
		&& self.underline_color == .none
}

// Returns a blank cell with the background color of this style.
//
// If no background color is set this returns none. Otherwise it returns a
// cell tagged as background-only content, so no style-map lookup is needed.
pub fn (self &CellStyle) bg_cell() ?CellData {
	return match self.bg_color {
		.none {
			none
		}
		.palette {
			CellData{
				content_tag: .bg_color_palette
				color_palette: self.bg_palette
			}
		}
		.rgb {
			CellData{
				content_tag: .bg_color_rgb
				color_rgb_r: self.bg_r
				color_rgb_g: self.bg_g
				color_rgb_b: self.bg_b
			}
		}
	}
}

// ============================================================
// SgrAttribute - SGR (Select Graphic Rendition) attribute
// ============================================================

pub enum SgrAttributeKind {
	unset
	bold
	reset_bold
	faint
	italic
	reset_italic
	underline_set
	overline
	reset_overline
	blink
	reset_blink
	inverse
	reset_inverse
	invisible
	reset_invisible
	strikethrough
	reset_strikethrough
	direct_color_fg
	direct_color_bg
	fg_8
	bright_fg_8
	fg_256
	bg_8
	bright_bg_8
	bg_256
	reset_fg
	reset_bg
	underline_color
	underline_color_256
	reset_underline_color
	unknown
}

pub struct SgrAttribute {
pub:
	kind      SgrAttributeKind
	underline UnderlineStyle = .none
	r         u8
	g         u8
	b         u8
	index     u8
	// Populated for unknown attributes. full is the complete SGR parameter
	// list and partial begins at the parameter that could not be parsed.
	unknown_full    []u16
	unknown_partial []u16
}

// ============================================================
// ProtectedMode
// ============================================================

pub enum ProtectedMode {
	off
	iso
	dec
}

// ============================================================
// Charset types
// ============================================================

pub enum Charset {
	utf8
	ascii
	british
	dec_special
}

pub enum CharsetSlot {
	g0
	g1
	g2
	g3
}

// Hyperlink is defined in hyperlink.v.

// ============================================================
// KeyFlagStack (Kitty keyboard protocol)
// ============================================================

pub struct KeyFlagStack {
pub mut:
	flags [8]u32
	idx   u8
}

// Push a new set of flags onto the stack.
pub fn (mut self KeyFlagStack) push(new_flags u32) {
	// Overflow and wrap around if we're full, which evicts
	// the oldest entry.
	self.idx = (self.idx + 1) % 8
	self.flags[self.idx] = new_flags
}

// Pop `n` entries from the stack. This will just wrap around
// if `n` is greater than the amount in the stack.
pub fn (mut self KeyFlagStack) pop(n usize) {
	// If n is more than our length then we just reset the stack.
	// This also avoids a DoS vector where a malicious client
	// could send a huge number of pop commands to waste cpu.
	if n >= 8 {
		self.idx = 0
		self.flags = [8]u32{}
		return
	}

	for _ in 0 .. n {
		self.flags[self.idx] = 0
		self.idx = if self.idx == 0 { u8(7) } else { self.idx - 1 }
	}
}

// Get the current (top) flags value.
pub fn (self &KeyFlagStack) current() u32 {
	return self.flags[self.idx]
}

// Set flags using a merge operation.
pub enum KeyFlagSetOp {
	set_
	or_
	not_
}

pub fn (mut self KeyFlagStack) set(op KeyFlagSetOp, new_flags u32) {
	match op {
		.set_ {
			self.flags[self.idx] = new_flags
		}
		.or_ {
			self.flags[self.idx] |= new_flags
		}
		.not_ {
			self.flags[self.idx] &= ~new_flags
		}
	}
}

// ============================================================
// PromptKind - for semantic prompt operations
// ============================================================

pub enum PromptKind {
	initial
	right
	continuation
	secondary
}

// ============================================================
// Direction
// ============================================================

pub enum Direction {
	left_to_right
	right_to_left
}
