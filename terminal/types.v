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
pub enum ContentTag {
	bg_color_only // No codepoint, just background color
	codepoint     // A single codepoint
}

// SemanticContent describes what the cell content semantically represents.
pub enum SemanticContent {
	output
	input
	prompt
}

// CellData is the data for a single cell in the terminal grid.
pub struct CellData {
pub mut:
	codepoint        u32
	content_tag      ContentTag = .bg_color_only
	style_id         u32
	wide             CellWide         = .narrow
	is_protected     bool
	has_grapheme     bool
	has_hyperlink    bool
	semantic_content SemanticContent   = .output
	graphemes        []u32
}

// Returns true if the cell has displayable text.
pub fn (self &CellData) has_text() bool {
	return self.content_tag == .codepoint && self.codepoint != 0
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
	cells             []CellData
	wrap              bool
	wrap_continuation bool
	dirty             bool
	styled            bool
	grapheme          bool
	hyperlink         bool
	semantic_prompt   SemanticPromptType = .unknown
}

// Initialize a new row with the given number of columns.
pub fn RowData.init(cols u32) RowData {
	return RowData{
		cells: []CellData{len: int(cols)}
	}
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

// Returns the topmost/leftmost pin.
pub fn (self &Selection) start() Pin {
	if self.start_pin.before(self.end_pin) {
		return self.start_pin
	}
	return self.end_pin
}

// Returns the bottommost/rightmost pin.
pub fn (self &Selection) end() Pin {
	if self.start_pin.before(self.end_pin) {
		return self.end_pin
	}
	return self.start_pin
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
