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
	input
	command
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
// PointTag - identifies which region of the screen to reference
// ============================================================

pub enum PointTag {
	screen
	active
	viewport
	history
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

pub struct Pages {
pub mut:
	screen_rows    []RowData
	active_start   int
	cols           u32
	rows           u32
	max_scrollback u32
	viewport       ViewportState = .active
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

// Reset the pages: clear all rows, reset active_start.
pub fn (mut self Pages) reset() {
	self.screen_rows = []RowData{cap: int(self.rows)}
	for _ in 0 .. int(self.rows) {
		self.screen_rows << RowData.init(self.cols)
	}
	self.active_start = 0
	self.viewport = .active
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
}

// Scroll and clear - move all active content to scrollback.
pub fn (mut self Pages) scroll_clear() ! {
	// Move active_start past all current rows
	self.active_start += int(self.rows)
	// Add new blank rows
	for _ in 0 .. int(self.rows) {
		self.screen_rows << RowData.init(self.cols)
	}
	// Enforce max scrollback
	self.trim_scrollback()
	self.viewport = .active
}

// Grow the screen by one row (for scrollback).
pub fn (mut self Pages) grow() ! {
	self.screen_rows << RowData.init(self.cols)
	self.trim_scrollback()
}

// Trim scrollback to max_scrollback limit.
fn (mut self Pages) trim_scrollback() {
	max := int(self.max_scrollback) + int(self.rows)
	for self.screen_rows.len > max && self.active_start > 0 {
		self.screen_rows.delete(0)
		self.active_start -= 1
	}
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
	}
}

// Erase rows in a region.
pub fn (mut self Pages) erase_rows(tl PointTag, bl ?PointTag) {
	match tl {
		.history {
			// Remove all history rows (before active_start)
			for self.active_start > 0 {
				self.screen_rows.delete(0)
				self.active_start -= 1
			}
		}
		else {}
	}
}

// Get the top-left pin for a point tag.
pub fn (self &Pages) get_top_left(tag PointTag) Pin {
	return match tag {
		.screen { Pin{ x: 0, y: 0 } }
		.active { Pin{ x: 0, y: u32(self.active_start) } }
		.viewport { Pin{ x: 0, y: u32(self.active_start) } }
		.history { Pin{ x: 0, y: 0 } }
	}
}

// Get the bottom-right pin for a point tag.
pub fn (self &Pages) get_bottom_right(tag PointTag) ?Pin {
	return match tag {
		.screen { Pin{ x: self.cols - 1, y: u32(self.screen_rows.len - 1) } }
		.active { Pin{ x: self.cols - 1, y: u32(self.active_start + int(self.rows) - 1) } }
		.viewport { Pin{ x: self.cols - 1, y: u32(self.active_start + int(self.rows) - 1) } }
		.history {
			if self.active_start > 0 {
				Pin{ x: self.cols - 1, y: u32(self.active_start - 1) }
			} else {
				return none
			}
		}
	}
}

// Resize the pages.
pub fn (mut self Pages) resize(opts ResizeOpts) ! {
	old_cols := self.cols
	old_rows := self.rows

	self.cols = opts.cols
	self.rows = opts.rows

	// Adjust row widths if cols changed
	if old_cols != opts.cols {
		for mut row in self.screen_rows {
			if row.cells.len < int(opts.cols) {
				// Expand: add cells
				for _ in row.cells.len .. int(opts.cols) {
					row.cells << CellData{}
				}
			} else if row.cells.len > int(opts.cols) {
				// Shrink: truncate cells
				row.cells = row.cells[..int(opts.cols)]
			}
		}
	}

	// Adjust number of active rows if rows changed
	if old_rows != opts.rows {
		active_end := self.active_start + int(opts.rows)
		// Ensure we have enough rows
		for self.screen_rows.len < active_end {
			self.screen_rows << RowData.init(opts.cols)
		}
		// If cursor was past new bottom, adjust active_start
		if self.active_start + int(opts.rows) > self.screen_rows.len {
			self.active_start = if self.screen_rows.len > int(opts.rows) {
				self.screen_rows.len - int(opts.rows)
			} else {
				0
			}
		}
	}
}

// Convert a point tag + coordinates to a Pin.
pub fn (self &Pages) pin(opts PinOpts) ?Pin {
	y := match opts.tag {
		.screen { opts.y }
		.active { u32(self.active_start) + opts.y }
		.viewport { u32(self.active_start) + opts.y }
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

// ============================================================
// ResizeOpts
// ============================================================

pub struct ResizeOpts {
pub:
	cols   u32
	rows   u32
	reflow bool = true
	cursor struct {
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
pub fn (self &CellStyle) bg_cell() !CellData {
	if self.bg_color == .none {
		return CellData{}
	}
	return CellData{
		style_id: 1 // non-default
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
	dec_special
	british
	dutch
	finnish
	french
	french_canadian
	german
	italian
	norwegian
	portuguese
	spanish
	swedish
	swiss
}

pub enum CharsetSlot {
	g0
	g1
	g2
	g3
}

// ============================================================
// Hyperlink
// ============================================================

pub struct Hyperlink {
pub mut:
	uri string
	id_ string
}

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
	if self.idx < 7 {
		self.idx += 1
	}
	self.flags[self.idx] = new_flags
}

// Pop n sets of flags from the stack (minimum 1 entry always remains).
pub fn (mut self KeyFlagStack) pop(n u8) {
	count := if n == 0 { u8(1) } else { n }
	for _ in 0 .. int(count) {
		if self.idx > 0 {
			self.idx -= 1
		}
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
		.set_ { self.flags[self.idx] = new_flags }
		.or_ { self.flags[self.idx] |= new_flags }
		.not_ { self.flags[self.idx] &= ~new_flags }
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
