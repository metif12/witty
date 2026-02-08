module terminal

import strings

// Screen represents a single terminal screen with cursor, selection,
// and cell data. Translated from ghostty's Screen.zig.

// ScreenDirty tracks what parts of the screen need redrawing.
pub struct ScreenDirty {
pub mut:
	selection       bool
	hyperlink_hover bool
}

// SemanticPrompt tracks OSC 133 semantic prompt state.
pub struct SemanticPrompt {
pub mut:
	seen  bool
	click SemanticClick
}

pub const semantic_prompt_disabled = SemanticPrompt{
	seen: false
	click: .none
}

pub enum SemanticClick {
	none
	click_events
	cl_line
	cl_multiple
	cl_conservative_vertical
	cl_smart_vertical
}

// Cursor holds the cursor position and associated state.
pub struct Cursor {
pub mut:
	x                        u32
	y                        u32
	cursor_style             CursorStyle    = .block
	pending_wrap             bool
	is_protected             bool
	style                    CellStyle
	style_id                 u32
	hyperlink_id             u32
	hyperlink_implicit_id    u32
	hyperlink_state          ?Hyperlink
	semantic_content         SemanticContent = .output
	semantic_content_clear_eol bool
}

// SavedCursor holds saved cursor state for save/restore operations.
pub struct SavedCursor {
pub mut:
	x            u32
	y            u32
	style        CellStyle
	is_protected bool
	pending_wrap bool
	origin       bool
	charset      CharsetState
}

// CharsetState holds the charset mapping state.
pub struct CharsetState {
pub mut:
	charsets CharsetArray
	gl       CharsetSlot = .g0
	gr       CharsetSlot = .g2
	single_shift ?CharsetSlot
}

// CharsetArray maps charset slots to charset tables.
pub struct CharsetArray {
pub mut:
	g0 Charset = .utf8
	g1 Charset = .utf8
	g2 Charset = .utf8
	g3 Charset = .utf8
}

pub fn (self CharsetArray) get(slot CharsetSlot) Charset {
	return match slot {
		.g0 { self.g0 }
		.g1 { self.g1 }
		.g2 { self.g2 }
		.g3 { self.g3 }
	}
}

pub fn (mut self CharsetArray) set(slot CharsetSlot, charset Charset) {
	match slot {
		.g0 { self.g0 = charset }
		.g1 { self.g1 = charset }
		.g2 { self.g2 = charset }
		.g3 { self.g3 = charset }
	}
}

// Options for creating a new Screen.
pub struct ScreenOptions {
pub:
	cols           u32 = 80
	rows           u32 = 24
	max_scrollback u32
}

// Scroll controls viewport scrolling behavior.
pub enum Scroll {
	active
	top
	pin_scroll
	row
	delta_row
	delta_prompt
}

// Resize options for resizing the screen.
pub struct ScreenResize {
pub:
	cols          u32
	rows          u32
	reflow        bool = true
	prompt_redraw PromptRedraw = .false_
}

// SelectionString options for converting selection to string.
pub struct SelectionString {
pub:
	sel  Selection
	trim bool = true
}

// SelectLine options for selecting a line.
pub struct SelectLine {
pub:
	pin                       Pin
	whitespace                ?[]u32
	semantic_prompt_boundary  bool = true
}

// LineIterator iterates over soft-wrapped lines.
pub struct LineIterator {
pub mut:
	screen  &Screen = unsafe { nil }
	current ?Pin
}

pub fn (mut self LineIterator) next() ?Selection {
	cur := self.current or { return none }
	result := self.screen.select_line(SelectLine{
		pin: cur
		whitespace: none
		semantic_prompt_boundary: false
	}) or { return none }
	self.current = result.end().down(1)
	return result
}

// PromptClickMove describes cursor movement needed for a click in a prompt.
pub struct PromptClickMove {
pub:
	left  int
	right int
}

pub const prompt_click_move_zero = PromptClickMove{
	left: 0
	right: 0
}

// ============================================================
// Screen struct
// ============================================================

@[heap]
pub struct Screen {
pub mut:
	pages           Pages
	no_scrollback   bool
	cursor          Cursor
	saved_cursor    ?SavedCursor
	selection       ?Selection
	charset         CharsetState
	protected_mode  ProtectedMode    = .off
	kitty_keyboard  KeyFlagStack
	semantic_prompt SemanticPrompt
	dirty           ScreenDirty
}

// Initialize a new screen with the given dimensions and scrollback.
pub fn Screen.init(cols u32, rows u32, max_scrollback u32) Screen {
	return Screen{
		pages: Pages.init(cols, rows, max_scrollback)
		no_scrollback: max_scrollback == 0
		cursor: Cursor{
			x: 0
			y: 0
		}
		semantic_prompt: terminal.semantic_prompt_disabled
	}
}

// Clean up screen resources.
pub fn (mut self Screen) deinit() {
	self.pages.deinit()
	self.selection = none
	self.saved_cursor = none
}

// Assert screen state integrity (simplified for V).
pub fn (self &Screen) assert_integrity() {
	assert self.cursor.x < self.pages.cols, 'cursor x ${self.cursor.x} >= cols ${self.pages.cols}'
	assert self.cursor.y < self.pages.rows, 'cursor y ${self.cursor.y} >= rows ${self.pages.rows}'
}

// ============================================================
// Reset
// ============================================================

// Reset the screen: clear content, move cursor to top-left, reset state.
pub fn (mut self Screen) reset() {
	self.pages.reset()
	self.cursor = Cursor{
		x: 0
		y: 0
	}
	self.saved_cursor = none
	self.charset = CharsetState{}
	self.kitty_keyboard = KeyFlagStack{}
	self.protected_mode = .off
	self.semantic_prompt = terminal.semantic_prompt_disabled
	self.clear_selection()
}

// ============================================================
// Clone
// ============================================================

// Clone the screen for a given region.
pub fn (self &Screen) clone(top PointTag, bot ?PointTag) !Screen {
	// XTODO: Full clone with page remapping is not implemented.
	// Requires PageList.clone with tracked pin remapping for selection
	// and cursor preservation across cloned regions.
	mut new_screen := Screen.init(self.pages.cols, self.pages.rows, self.pages.max_scrollback)
	new_screen.no_scrollback = self.no_scrollback
	new_screen.dirty = self.dirty

	// Copy active area content
	for y in 0 .. int(self.pages.rows) {
		src := self.pages.get_active_row(u32(y))
		unsafe {
			mut dst := new_screen.pages.get_active_row_mut(u32(y))
			dst.cells = src.cells.clone()
			dst.wrap = src.wrap
			dst.wrap_continuation = src.wrap_continuation
			dst.styled = src.styled
			dst.dirty = src.dirty
			dst.semantic_prompt = src.semantic_prompt
		}
	}

	// Copy cursor
	new_screen.cursor = self.cursor
	if new_screen.cursor.x >= new_screen.pages.cols {
		new_screen.cursor.x = 0
	}
	if new_screen.cursor.y >= new_screen.pages.rows {
		new_screen.cursor.y = 0
	}

	// Copy selection if within bounds
	if sel := self.selection {
		new_screen.selection = sel
	}

	return new_screen
}

// ============================================================
// Cursor movement
// ============================================================

// Move the cursor right by n positions.
pub fn (mut self Screen) cursor_right(n u32) {
	assert self.cursor.x + n < self.pages.cols
	self.cursor.x += n
}

// Move the cursor left by n positions.
pub fn (mut self Screen) cursor_left(n u32) {
	assert self.cursor.x >= n
	self.cursor.x -= n
}

// Move the cursor up by n rows.
pub fn (mut self Screen) cursor_up(n u32) {
	assert self.cursor.y >= n
	self.cursor.y -= n
	self.cursor_mark_dirty()
}

// Move the cursor down by n rows.
pub fn (mut self Screen) cursor_down(n u32) {
	assert self.cursor.y + n < self.pages.rows
	self.cursor.y += n
	self.cursor_mark_dirty()
}

// Move the cursor to the given absolute column.
pub fn (mut self Screen) cursor_horizontal_absolute(x u32) {
	assert x < self.pages.cols
	self.cursor.x = x
}

// Move the cursor to the given absolute position.
pub fn (mut self Screen) cursor_absolute(x u32, y u32) {
	assert x < self.pages.cols
	assert y < self.pages.rows
	if self.cursor.x != x || self.cursor.y != y {
		self.cursor_mark_dirty()
	}
	self.cursor.x = x
	self.cursor.y = y
	self.cursor_mark_dirty()
}

// Reload cursor state from the page pin.
pub fn (mut self Screen) cursor_reload() {
	// XTODO: Full cursor reload needs PageList.pointFromPin to
	// derive cursor x/y from the tracked page pin, plus style
	// migration if the cursor moved to a new page.
	// In this simplified version, we just clamp cursor bounds.
	if self.cursor.x >= self.pages.cols {
		self.cursor.x = 0
	}
	if self.cursor.y >= self.pages.rows {
		self.cursor.y = 0
	}
}

// Mark the cursor row as dirty for rendering.
pub fn (mut self Screen) cursor_mark_dirty() {
	idx := self.pages.active_start + int(self.cursor.y)
	if idx < self.pages.screen_rows.len {
		unsafe {
			mut row := &self.pages.screen_rows[idx]
			row.dirty = true
		}
	}
}

// Copy another cursor's state into this screen.
pub fn (mut self Screen) cursor_copy(other Cursor) ! {
	// XTODO: Full cursor copy needs style ref-counting across pages
	// and hyperlink migration. This simplified version copies the
	// basic cursor state.
	old_style_id := self.cursor.style_id
	self.cursor.x = other.x
	self.cursor.y = other.y
	self.cursor.cursor_style = other.cursor_style
	self.cursor.pending_wrap = other.pending_wrap
	self.cursor.is_protected = other.is_protected
	self.cursor.style = other.style
	self.cursor.semantic_content = other.semantic_content
	self.cursor.semantic_content_clear_eol = other.semantic_content_clear_eol

	// Update style
	if self.cursor.style.default() {
		self.cursor.style_id = default_style_id
	} else if old_style_id != default_style_id {
		// In full implementation, would release old and add new
		self.cursor.style_id = 1 // simplified
	}

	// Clamp cursor
	if self.cursor.x >= self.pages.cols {
		self.cursor.x = self.pages.cols - 1
	}
	if self.cursor.y >= self.pages.rows {
		self.cursor.y = self.pages.rows - 1
	}
	self.cursor_absolute(self.cursor.x, self.cursor.y)
}

// Reset the wrap state of the cursor row.
pub fn (mut self Screen) cursor_reset_wrap() {
	self.cursor.pending_wrap = false
	idx := self.pages.active_start + int(self.cursor.y)
	if idx < self.pages.screen_rows.len {
		unsafe {
			mut row := &self.pages.screen_rows[idx]
			row.wrap = false
		}
		// Also reset next row's wrap_continuation
		next_idx := idx + 1
		if next_idx < self.pages.screen_rows.len {
			unsafe {
				mut next_row := &self.pages.screen_rows[next_idx]
				next_row.wrap_continuation = false
			}
		}
	}
}

// ============================================================
// Scrolling
// ============================================================

// Scroll the viewport.
pub fn (mut self Screen) scroll(behavior Scroll) {
	match behavior {
		.active { self.pages.scroll(.active) }
		.top { self.pages.scroll(.top) }
		else { self.pages.scroll(.active) }
	}
}

// Scroll and clear the screen, moving content to scrollback.
pub fn (mut self Screen) scroll_clear() ! {
	self.pages.scroll_clear()!
	self.cursor_reload()
}

// Scroll down when cursor is at the bottom of the screen.
pub fn (mut self Screen) cursor_down_scroll() ! {
	assert self.cursor.y == self.pages.rows - 1

	if self.no_scrollback {
		if self.pages.rows == 1 {
			// Single-row: just clear the row
			self.clear_active_row(0)
			self.cursor_mark_dirty()
		} else {
			// Shift everything up: remove first active row, add blank at bottom
			self.pages.erase_row(PinOpts{ tag: .active, x: 0, y: 0 })!
		}
	} else {
		// With scrollback: grow by one row, moving old top row to scrollback
		self.pages.grow() or {}
		self.pages.active_start += 1
		// Ensure we have a row at the new bottom
		active_end := self.pages.active_start + int(self.pages.rows)
		for self.pages.screen_rows.len < active_end {
			self.pages.screen_rows << RowData.init(self.pages.cols)
		}
		// Clear the new bottom row
		self.clear_active_row(self.pages.rows - 1)
		self.cursor_mark_dirty()
	}
}

// Scroll above the cursor (insert line above).
pub fn (mut self Screen) cursor_scroll_above() ! {
	// XTODO: Full scroll-above with cross-page row rotation is not
	// implemented. Requires fastmem.rotateOnceR across page boundaries
	// and proper pin tracking. This delegates to cursor_down_scroll
	// when cursor is at the bottom.
	self.cursor_mark_dirty()
	if self.cursor.y == self.pages.rows - 1 {
		return self.cursor_down_scroll()
	}
	// Simplified: insert blank row at cursor, push rows below down
	idx := self.pages.active_start + int(self.cursor.y)
	active_end := self.pages.active_start + int(self.pages.rows)
	// Remove the last active row
	if active_end - 1 < self.pages.screen_rows.len {
		self.pages.screen_rows.delete(active_end - 1)
	}
	// Insert blank at cursor position
	self.pages.screen_rows.insert(idx, RowData.init(self.pages.cols))
	// Mark all as dirty
	for i in idx .. active_end {
		if i < self.pages.screen_rows.len {
			unsafe {
				mut row := &self.pages.screen_rows[i]
				row.dirty = true
			}
		}
	}
}

// Move cursor down or scroll if at the bottom.
fn (mut self Screen) cursor_down_or_scroll() ! {
	if self.cursor.y + 1 < self.pages.rows {
		self.cursor_down(1)
	} else {
		self.cursor_down_scroll()!
	}
}

// Returns true if the viewport is at the bottom.
pub fn (self &Screen) viewport_is_bottom() bool {
	return self.pages.viewport == .active
}

// ============================================================
// Row/Cell management
// ============================================================

// Clear a row in the active area, filling with blank cells.
fn (mut self Screen) clear_active_row(y u32) {
	idx := self.pages.active_start + int(y)
	if idx < self.pages.screen_rows.len {
		unsafe {
			mut row := &self.pages.screen_rows[idx]
			for i in 0 .. int(self.pages.cols) {
				if i < row.cells.len {
					row.cells[i] = CellData{}
				}
			}
			row.dirty = true
			row.styled = false
			row.grapheme = false
			row.hyperlink = false
		}
	}
}

// Erase rows physically (reclaim memory).
pub fn (mut self Screen) erase_rows(tl PointTag, bl ?PointTag) {
	self.pages.erase_rows(tl, bl)
	self.cursor_reload()
}

// Clear rows (set to blank, preserving the row slots).
pub fn (mut self Screen) clear_rows(tl PointTag, bl ?PointTag, protected bool) {
	tl_pin := self.pages.get_top_left(tl)
	bl_pin := if bt := bl {
		self.pages.get_bottom_right(bt) or { return }
	} else {
		self.pages.get_bottom_right(tl) or { return }
	}

	for y in int(tl_pin.y) .. int(bl_pin.y) + 1 {
		if y < self.pages.screen_rows.len {
			unsafe {
				mut row := &self.pages.screen_rows[y]
				if protected {
					// Only clear unprotected cells
					for mut cell in row.cells {
						if !cell.is_protected {
							cell = CellData{}
						}
					}
				} else {
					for mut cell in row.cells {
						cell = CellData{}
					}
					row.styled = false
					row.grapheme = false
					row.hyperlink = false
				}
				row.dirty = true
			}
		}
	}
}

// Clear specific cells in a row.
pub fn (mut self Screen) clear_cells(row_idx int, start int, end int) {
	if row_idx >= self.pages.screen_rows.len {
		return
	}
	unsafe {
		mut row := &self.pages.screen_rows[row_idx]
		for i in start .. end {
			if i < row.cells.len {
				row.cells[i] = CellData{}
			}
		}
		row.dirty = true
	}
}

// Returns a blank cell with the current cursor background color.
pub fn (self &Screen) blank_cell() CellData {
	if self.cursor.style_id == default_style_id {
		return CellData{}
	}
	return self.cursor.style.bg_cell() or { CellData{} }
}

// ============================================================
// Resize
// ============================================================

// Resize the screen to new dimensions.
pub fn (mut self Screen) resize(opts ScreenResize) ! {
	// XTODO: Full resize with reflow, prompt redraw, saved cursor
	// adjustment, and hyperlink migration is not implemented.
	// Requires PageList.resize with reflow support, which handles
	// soft-wrap reflow when columns change.

	self.pages.resize(ResizeOpts{
		cols: opts.cols
		rows: opts.rows
		reflow: opts.reflow
		cursor: struct {
			x: self.cursor.x
			y: self.cursor.y
		}
	})!

	// Erase history if no scrollback
	if self.no_scrollback {
		self.pages.erase_rows(.history, ?PointTag(none))
	}

	self.cursor_reload()

	// Update saved cursor if present
	if mut sc := self.saved_cursor {
		if sc.x >= opts.cols {
			sc.x = opts.cols - 1
		}
		if sc.y >= opts.rows {
			sc.y = opts.rows - 1
		}
	}
}

// ============================================================
// Style management (SGR attributes)
// ============================================================

// Set a style attribute on the current cursor.
pub fn (mut self Screen) set_attribute(attr SgrAttribute) ! {
	match attr.kind {
		.unset {
			self.cursor.style = CellStyle{}
		}
		.bold {
			self.cursor.style.flags.bold = true
		}
		.reset_bold {
			self.cursor.style.flags.bold = false
			self.cursor.style.flags.faint = false
		}
		.italic {
			self.cursor.style.flags.italic = true
		}
		.reset_italic {
			self.cursor.style.flags.italic = false
		}
		.faint {
			self.cursor.style.flags.faint = true
		}
		.underline_set {
			self.cursor.style.flags.underline = attr.underline
		}
		.overline {
			self.cursor.style.flags.overline = true
		}
		.reset_overline {
			self.cursor.style.flags.overline = false
		}
		.blink {
			self.cursor.style.flags.blink = true
		}
		.reset_blink {
			self.cursor.style.flags.blink = false
		}
		.inverse {
			self.cursor.style.flags.inverse = true
		}
		.reset_inverse {
			self.cursor.style.flags.inverse = false
		}
		.invisible {
			self.cursor.style.flags.invisible = true
		}
		.reset_invisible {
			self.cursor.style.flags.invisible = false
		}
		.strikethrough {
			self.cursor.style.flags.strikethrough = true
		}
		.reset_strikethrough {
			self.cursor.style.flags.strikethrough = false
		}
		.direct_color_fg {
			self.cursor.style.fg_color = .rgb
			self.cursor.style.fg_r = attr.r
			self.cursor.style.fg_g = attr.g
			self.cursor.style.fg_b = attr.b
		}
		.direct_color_bg {
			self.cursor.style.bg_color = .rgb
			self.cursor.style.bg_r = attr.r
			self.cursor.style.bg_g = attr.g
			self.cursor.style.bg_b = attr.b
		}
		.fg_8, .fg_256 {
			self.cursor.style.fg_color = .palette
			self.cursor.style.fg_palette = attr.index
		}
		.bright_fg_8 {
			self.cursor.style.fg_color = .palette
			self.cursor.style.fg_palette = attr.index + 8
		}
		.bg_8, .bg_256 {
			self.cursor.style.bg_color = .palette
			self.cursor.style.bg_palette = attr.index
		}
		.bright_bg_8 {
			self.cursor.style.bg_color = .palette
			self.cursor.style.bg_palette = attr.index + 8
		}
		.reset_fg {
			self.cursor.style.fg_color = .none
		}
		.reset_bg {
			self.cursor.style.bg_color = .none
		}
		.underline_color {
			self.cursor.style.underline_color = .rgb
			self.cursor.style.fg_r = attr.r
			self.cursor.style.fg_g = attr.g
			self.cursor.style.fg_b = attr.b
		}
		.underline_color_256 {
			self.cursor.style.underline_color = .palette
			self.cursor.style.fg_palette = attr.index
		}
		.reset_underline_color {
			self.cursor.style.underline_color = .none
		}
		.unknown {
			return
		}
	}
	self.manual_style_update()!
}

// Update the style ID after a manual style change.
pub fn (mut self Screen) manual_style_update() ! {
	// XTODO: Full style management with ref-counted style sets,
	// page capacity adjustment, and style migration is not implemented.
	// Requires Page.styles.add/release and page splitting for capacity.
	if self.cursor.style.default() {
		self.cursor.style_id = default_style_id
	} else {
		// Simplified: assign a non-zero style ID
		self.cursor.style_id = 1
	}
}

// ============================================================
// Hyperlink management
// ============================================================

// Start a hyperlink on the cursor.
pub fn (mut self Screen) start_hyperlink(uri string, id_ ?string) ! {
	// XTODO: Full hyperlink management needs page-level hyperlink
	// set insertion, ref counting, and capacity adjustment.
	// This is a simplified stub.
	self.end_hyperlink()
	self.cursor.hyperlink_id = self.cursor.hyperlink_implicit_id + 1
	self.cursor.hyperlink_implicit_id += 1
	self.cursor.hyperlink_state = Hyperlink{
		uri: uri
	}
}

// End the current hyperlink.
pub fn (mut self Screen) end_hyperlink() {
	if self.cursor.hyperlink_id == 0 {
		return
	}
	self.cursor.hyperlink_id = 0
	self.cursor.hyperlink_state = none
}

// Set the hyperlink on the current cell.
pub fn (mut self Screen) cursor_set_hyperlink() ! {
	// XTODO: Full implementation needs Page.setHyperlink with
	// ref counting and hyperlink_map capacity management.
	assert self.cursor.hyperlink_id != 0
	idx := self.pages.active_start + int(self.cursor.y)
	if idx < self.pages.screen_rows.len {
		unsafe {
			mut row := &self.pages.screen_rows[idx]
			if int(self.cursor.x) < row.cells.len {
				row.cells[int(self.cursor.x)].has_hyperlink = true
			}
			row.hyperlink = true
		}
	}
}

// ============================================================
// Semantic content
// ============================================================

// Set the semantic content type of the cursor.
pub fn (mut self Screen) cursor_set_semantic_content_prompt(kind PromptKind) {
	self.semantic_prompt.seen = true
	self.cursor.semantic_content = .prompt
	self.cursor.semantic_content_clear_eol = false
	idx := self.pages.active_start + int(self.cursor.y)
	if idx < self.pages.screen_rows.len {
		unsafe {
			mut row := &self.pages.screen_rows[idx]
			row.semantic_prompt = match kind {
				.initial, .right { SemanticPromptType.prompt }
				.continuation, .secondary { SemanticPromptType.prompt_continuation }
			}
		}
	}
}

pub fn (mut self Screen) cursor_set_semantic_content_output() {
	self.cursor.semantic_content = .output
	self.cursor.semantic_content_clear_eol = false
}

pub fn (mut self Screen) cursor_set_semantic_content_input(clear_eol bool) {
	self.cursor.semantic_content = .input
	self.cursor.semantic_content_clear_eol = clear_eol
}

// ============================================================
// Selection
// ============================================================

// Set the selection, replacing any previous selection.
pub fn (mut self Screen) select(sel ?Selection) ! {
	self.selection = sel
	self.dirty.selection = true
}

// Clear the current selection.
pub fn (mut self Screen) clear_selection() {
	if self.selection != none {
		self.dirty.selection = true
	}
	self.selection = none
}

// Get the string for a selection.
pub fn (mut self Screen) selection_string(opts SelectionString) !string {
	// XTODO: Full selection string extraction needs ScreenFormatter
	// with unwrap support, soft-wrap handling, and StringMap building.
	// This is a simplified version that reads cells directly.
	sel := opts.sel
	// Order the selection for iteration (start before end)
	start := if sel.start_pin.before(sel.end_pin) { sel.start_pin } else { sel.end_pin }
	end := if sel.start_pin.before(sel.end_pin) { sel.end_pin } else { sel.start_pin }

	mut result := strings.new_builder(256)
	mut first_row := true

	for y in int(start.y) .. int(end.y) + 1 {
		if y >= self.pages.screen_rows.len {
			break
		}
		row := self.pages.screen_rows[y]
		start_x := if y == int(start.y) { int(start.x) } else { 0 }
		end_x := if y == int(end.y) { int(end.x) + 1 } else { int(self.pages.cols) }

		if !first_row {
			// Check if previous row was soft-wrapped
			if y > 0 && self.pages.screen_rows[y - 1].wrap {
				// Soft wrap: no newline
			} else {
				result.write_string('\n')
			}
		}

		for x in start_x .. end_x {
			if x < row.cells.len {
				cp := row.cells[x].codepoint
				if cp == 0 {
					result.write_string(' ')
				} else {
					result.write_rune(rune(cp))
				}
			}
		}
		first_row = false
	}

	mut s := result.str()
	if opts.trim {
		// Trim trailing whitespace from each line
		lines := s.split('\n')
		mut trimmed := []string{}
		for line in lines {
			trimmed << line.trim_right(' \t')
		}
		s = trimmed.join('\n')
		// Trim trailing empty lines
		s = s.trim_right('\n')
	}
	return s
}

// Select a line around the given pin.
pub fn (self &Screen) select_line(opts SelectLine) ?Selection {
	if int(opts.pin.y) >= self.pages.screen_rows.len {
		return none
	}

	// Find the start of the soft-wrapped line
	mut start_y := int(opts.pin.y)
	for start_y > 0 {
		prev_row := self.pages.screen_rows[start_y - 1]
		if !prev_row.wrap {
			break
		}
		if opts.semantic_prompt_boundary {
			cur_row := self.pages.screen_rows[start_y]
			if cur_row.semantic_prompt != self.pages.screen_rows[start_y - 1].semantic_prompt {
				break
			}
		}
		start_y -= 1
	}

	// Find the end of the soft-wrapped line
	mut end_y := int(opts.pin.y)
	for end_y < self.pages.screen_rows.len - 1 {
		cur_row := self.pages.screen_rows[end_y]
		if !cur_row.wrap {
			break
		}
		if opts.semantic_prompt_boundary {
			next_row := self.pages.screen_rows[end_y + 1]
			if next_row.semantic_prompt != cur_row.semantic_prompt {
				break
			}
		}
		end_y += 1
	}

	start_pin := Pin{ x: 0, y: u32(start_y) }
	end_pin := Pin{ x: self.pages.cols - 1, y: u32(end_y) }

	// Trim whitespace if requested
	if ws := opts.whitespace {
		// Trim from start
		mut trimmed_start := start_pin
		mut found_start := false
		for y in start_y .. end_y + 1 {
			if y >= self.pages.screen_rows.len {
				break
			}
			row := self.pages.screen_rows[y]
			for x in 0 .. int(self.pages.cols) {
				if x < row.cells.len {
					cp := row.cells[x].codepoint
					is_ws := cp == 0 || is_codepoint_in(cp, ws)
					if !is_ws {
						trimmed_start = Pin{ x: u32(x), y: u32(y) }
						found_start = true
						break
					}
				}
			}
			if found_start {
				break
			}
		}
		if !found_start {
			return none
		}

		// Trim from end
		mut trimmed_end := end_pin
		mut found_end := false
		for rev_y := end_y; rev_y >= start_y; rev_y-- {
			if rev_y >= self.pages.screen_rows.len {
				continue
			}
			row := self.pages.screen_rows[rev_y]
			for rev_x := int(self.pages.cols) - 1; rev_x >= 0; rev_x-- {
				if rev_x < row.cells.len {
					cp := row.cells[rev_x].codepoint
					is_ws := cp == 0 || is_codepoint_in(cp, ws)
					if !is_ws {
						trimmed_end = Pin{ x: u32(rev_x), y: u32(rev_y) }
						found_end = true
						break
					}
				}
			}
			if found_end {
				break
			}
		}
		if !found_end {
			return none
		}

		return Selection.init(trimmed_start, trimmed_end, false)
	}

	return Selection.init(start_pin, end_pin, false)
}

fn is_codepoint_in(cp u32, list []u32) bool {
	for v in list {
		if cp == v {
			return true
		}
	}
	return false
}

// Select all content on the screen, trimming surrounding whitespace.
pub fn (mut self Screen) select_all() ?Selection {
	whitespace := [u32(0), u32(` `), u32(`\t`)]

	// Find start (first non-whitespace)
	mut start := ?Pin(none)
	for y in 0 .. self.pages.screen_rows.len {
		row := self.pages.screen_rows[y]
		for x in 0 .. int(self.pages.cols) {
			if x < row.cells.len {
				cp := row.cells[x].codepoint
				if cp != 0 && !is_codepoint_in(cp, whitespace) {
					start = Pin{ x: u32(x), y: u32(y) }
					break
				}
			}
		}
		if start != none {
			break
		}
	}

	s := start or { return none }

	// Find end (last non-whitespace)
	mut end := ?Pin(none)
	for rev_y := self.pages.screen_rows.len - 1; rev_y >= 0; rev_y-- {
		row := self.pages.screen_rows[rev_y]
		for rev_x := int(self.pages.cols) - 1; rev_x >= 0; rev_x-- {
			if rev_x < row.cells.len {
				cp := row.cells[rev_x].codepoint
				if cp != 0 && !is_codepoint_in(cp, whitespace) {
					end = Pin{ x: u32(rev_x), y: u32(rev_y) }
					break
				}
			}
		}
		if end != none {
			break
		}
	}

	e := end or { return none }
	return Selection.init(s, e, false)
}

// Select a word near start that is between start and end.
pub fn (self &Screen) select_word_between(start Pin, end_p Pin, boundary_codepoints []u32) ?Selection {
	if start.before(end_p) {
		// Iterate right_down from start to end
		mut pin := start
		for pin.y <= end_p.y {
			if pin.y == end_p.y && pin.x > end_p.x {
				break
			}
			if sel := self.select_word(pin, boundary_codepoints) {
				return sel
			}
			// Move to next cell
			pin.x += 1
			if pin.x >= self.pages.cols {
				pin.x = 0
				pin.y += 1
			}
		}
	} else {
		// Iterate left_up from start to end
		mut pin := start
		for {
			if sel := self.select_word(pin, boundary_codepoints) {
				return sel
			}
			if pin.eql(end_p) || pin.before(end_p) {
				break
			}
			if pin.x > 0 {
				pin.x -= 1
			} else if pin.y > 0 {
				pin.y -= 1
				pin.x = self.pages.cols - 1
			} else {
				break
			}
		}
	}
	return none
}

// Select the word under the given pin.
pub fn (self &Screen) select_word(pin Pin, boundary_codepoints []u32) ?Selection {
	if int(pin.y) >= self.pages.screen_rows.len {
		return none
	}

	row := self.pages.screen_rows[int(pin.y)]
	if int(pin.x) >= row.cells.len {
		return none
	}
	start_cell := row.cells[int(pin.x)]
	if !start_cell.has_text() {
		return none
	}

	expect_boundary := is_codepoint_in(start_cell.codepoint, boundary_codepoints)

	// Go forwards to find end
	mut end := pin
	mut fx := int(pin.x) + 1
	mut fy := int(pin.y)
	for {
		if fy >= self.pages.screen_rows.len {
			break
		}
		cur_row := self.pages.screen_rows[fy]
		if fx >= int(self.pages.cols) {
			if !cur_row.wrap {
				break
			}
			fx = 0
			fy += 1
			continue
		}
		if fx >= cur_row.cells.len {
			break
		}
		cell := cur_row.cells[fx]
		if !cell.has_text() {
			break
		}
		this_boundary := is_codepoint_in(cell.codepoint, boundary_codepoints)
		if this_boundary != expect_boundary {
			break
		}
		end = Pin{ x: u32(fx), y: u32(fy) }
		fx += 1
	}

	// Go backwards to find start
	mut start := pin
	mut bx := int(pin.x) - 1
	mut by := int(pin.y)
	for {
		if by < 0 {
			break
		}
		if bx < 0 {
			if by == 0 {
				break
			}
			prev_row := self.pages.screen_rows[by - 1]
			if !prev_row.wrap {
				break
			}
			by -= 1
			bx = int(self.pages.cols) - 1
			continue
		}
		if by >= self.pages.screen_rows.len {
			break
		}
		cur_row := self.pages.screen_rows[by]
		if bx >= cur_row.cells.len {
			break
		}
		cell := cur_row.cells[bx]
		if !cell.has_text() {
			break
		}
		this_boundary := is_codepoint_in(cell.codepoint, boundary_codepoints)
		if this_boundary != expect_boundary {
			break
		}
		start = Pin{ x: u32(bx), y: u32(by) }
		bx -= 1
	}

	return Selection.init(start, end, false)
}

// Select command output around the given pin.
pub fn (mut self Screen) select_output(pin Pin) ?Selection {
	// XTODO: Full output selection needs PageList.highlightSemanticContent
	// and prompt iteration. Requires shell integration (OSC 133) to
	// properly delimit command output regions.
	if int(pin.y) >= self.pages.screen_rows.len {
		return none
	}
	row := self.pages.screen_rows[int(pin.y)]
	if int(pin.x) >= row.cells.len {
		return none
	}
	cell := row.cells[int(pin.x)]
	if cell.semantic_content != .output {
		return none
	}
	// Simplified: select from pin to end of contiguous output
	start := pin
	mut end := pin
	for y in int(pin.y) .. self.pages.screen_rows.len {
		r := self.pages.screen_rows[y]
		start_x := if y == int(pin.y) { int(pin.x) } else { 0 }
		for x in start_x .. int(self.pages.cols) {
			if x < r.cells.len && r.cells[x].semantic_content == .output {
				end = Pin{ x: u32(x), y: u32(y) }
			} else {
				return Selection.init(start, end, false)
			}
		}
	}
	return Selection.init(start, end, false)
}

// Returns a line iterator starting from the given pin.
pub fn (self &Screen) line_iterator(start Pin) LineIterator {
	return LineIterator{
		screen: self
		current: start
	}
}

// ============================================================
// Prompt click movement
// ============================================================

// Determine cursor movement needed to move to a click location in a prompt.
pub fn (self &Screen) prompt_click_move(click_pin Pin) PromptClickMove {
	if self.cursor.semantic_content != .input {
		return prompt_click_move_zero
	}
	match self.semantic_prompt.click {
		.none, .click_events { return prompt_click_move_zero }
		.cl_line, .cl_multiple, .cl_conservative_vertical, .cl_smart_vertical {
			return self.prompt_click_line(click_pin)
		}
	}
}

fn (self &Screen) prompt_click_line(click_pin Pin) PromptClickMove {
	cursor_pin := Pin{ x: self.cursor.x, y: u32(self.pages.active_start) + self.cursor.y }
	if cursor_pin.eql(click_pin) {
		return prompt_click_move_zero
	}

	if cursor_pin.before(click_pin) {
		// Moving right
		mut count := 0
		mut y := int(cursor_pin.y)
		for y <= int(click_pin.y) && y < self.pages.screen_rows.len {
			row := self.pages.screen_rows[y]
			is_cursor_row := u32(y) == cursor_pin.y
			start_x := if is_cursor_row { int(cursor_pin.x) + 1 } else { 0 }
			for x in start_x .. int(self.pages.cols) {
				if x < row.cells.len && row.cells[x].semantic_content == .input {
					count += 1
					if u32(y) == click_pin.y && u32(x) == click_pin.x {
						return PromptClickMove{ left: 0, right: count }
					}
				}
			}
			if !row.wrap {
				break
			}
			y += 1
		}
		return PromptClickMove{ left: 0, right: count }
	} else {
		// Moving left
		mut count := 0
		mut y := int(cursor_pin.y)
		for y >= int(click_pin.y) && y >= 0 {
			if y >= self.pages.screen_rows.len {
				y -= 1
				continue
			}
			row := self.pages.screen_rows[y]
			is_cursor_row := u32(y) == cursor_pin.y
			end_x := if is_cursor_row { int(cursor_pin.x) } else { int(self.pages.cols) }
			for rev_x := end_x - 1; rev_x >= 0; rev_x-- {
				if rev_x < row.cells.len && row.cells[rev_x].semantic_content == .input {
					count += 1
					if u32(y) == click_pin.y && u32(rev_x) == click_pin.x {
						return PromptClickMove{ left: count, right: 0 }
					}
				}
			}
			if !row.wrap_continuation {
				break
			}
			y -= 1
		}
		return PromptClickMove{ left: count, right: 0 }
	}
}

// ============================================================
// Dump / Format
// ============================================================

// Dump screen contents to a string.
pub fn (self &Screen) dump_string_alloc(tag PointTag) !string {
	start_y, end_y := match tag {
		.screen {
			0, self.pages.screen_rows.len
		}
		.active {
			self.pages.active_start, self.pages.active_start + int(self.pages.rows)
		}
		.viewport {
			self.pages.active_start, self.pages.active_start + int(self.pages.rows)
		}
		.history {
			0, self.pages.active_start
		}
	}

	// Find the last row with content
	mut last_content_y := start_y - 1
	for y in start_y .. end_y {
		if y >= self.pages.screen_rows.len {
			break
		}
		row := self.pages.screen_rows[y]
		for x in 0 .. int(self.pages.cols) {
			if x < row.cells.len && row.cells[x].codepoint != 0 {
				last_content_y = y
				break
			}
		}
	}

	if last_content_y < start_y {
		return ''
	}

	mut result := strings.new_builder(256)
	for y in start_y .. last_content_y + 1 {
		if y >= self.pages.screen_rows.len {
			break
		}
		if y > start_y {
			result.write_string('\n')
		}
		row := self.pages.screen_rows[y]
		// Find last non-empty cell
		mut last_x := -1
		for x := int(self.pages.cols) - 1; x >= 0; x-- {
			if x < row.cells.len && row.cells[x].codepoint != 0 {
				last_x = x
				break
			}
		}
		for x in 0 .. last_x + 1 {
			if x < row.cells.len {
				cp := row.cells[x].codepoint
				if cp == 0 {
					result.write_string(' ')
				} else {
					result.write_rune(rune(cp))
				}
			}
		}
	}

	return result.str()
}

// Dump unwrapped (soft-wraps joined) contents to a string.
pub fn (self &Screen) dump_string_alloc_unwrapped(tag PointTag) !string {
	// XTODO: Full unwrapped dump needs ScreenFormatter with unwrap=true.
	// This simplified version joins soft-wrapped lines.
	start_y, end_y := match tag {
		.screen {
			0, self.pages.screen_rows.len
		}
		.active {
			self.pages.active_start, self.pages.active_start + int(self.pages.rows)
		}
		else {
			self.pages.active_start, self.pages.active_start + int(self.pages.rows)
		}
	}

	mut result := strings.new_builder(256)
	mut first_line := true

	mut y := start_y
	for y < end_y && y < self.pages.screen_rows.len {
		if !first_line {
			result.write_string('\n')
		}
		first_line = false

		// Collect all rows in this soft-wrapped line
		for {
			row := self.pages.screen_rows[y]
			mut last_x := -1
			for x := int(self.pages.cols) - 1; x >= 0; x-- {
				if x < row.cells.len && row.cells[x].codepoint != 0 {
					last_x = x
					break
				}
			}
			for x in 0 .. last_x + 1 {
				if x < row.cells.len {
					cp := row.cells[x].codepoint
					if cp == 0 {
						result.write_string(' ')
					} else {
						result.write_rune(rune(cp))
					}
				}
			}
			if !row.wrap || y + 1 >= end_y {
				y += 1
				break
			}
			y += 1
		}
	}

	return result.str()
}

// ============================================================
// Grapheme support
// ============================================================

// Append a grapheme codepoint to a cell.
pub fn (mut self Screen) append_grapheme(cell_x u32, cp u32) ! {
	// XTODO: Full grapheme append needs Page.appendGrapheme with
	// capacity management and grapheme byte storage.
	idx := self.pages.active_start + int(self.cursor.y)
	if idx < self.pages.screen_rows.len {
		unsafe {
			mut row := &self.pages.screen_rows[idx]
			if int(cell_x) < row.cells.len {
				row.cells[int(cell_x)].graphemes << cp
				row.cells[int(cell_x)].has_grapheme = true
				row.grapheme = true
			}
		}
	}
}

// ============================================================
// Increase capacity (page management)
// ============================================================

// Increase capacity of the page containing the given node.
pub fn (mut self Screen) increase_capacity() ! {
	// XTODO: Full page capacity management is not implemented.
	// Requires PageList.increaseCapacity which can reallocate pages,
	// adjust tracked pins, and migrate styles/hyperlinks.
}

// Split a page for capacity reasons.
fn (mut self Screen) split_for_capacity() ! {
	// XTODO: Page splitting needs PageList.split with capacity
	// calculation and cursor pin tracking.
}

// Split cell boundary (handle wide char boundaries).
pub fn (mut self Screen) split_cell_boundary(x u32) {
	// XTODO: Full boundary handling needs page cell pointer access
	// and spacer head/tail management for wide characters.
}

// ============================================================
// Test helper: write string to screen
// ============================================================

// Write a string to the screen at the cursor position.
// This is a simplified version of Terminal.printString for testing.
pub fn (mut self Screen) test_write_string(text string) ! {
	runes := text.runes()
	for c in runes {
		// Explicit newline
		if c == `\n` {
			self.cursor_down_or_scroll()!
			self.cursor_horizontal_absolute(0)
			self.cursor.pending_wrap = false
			if self.cursor.semantic_content_clear_eol {
				self.cursor_set_semantic_content_output()
			} else {
				match self.cursor.semantic_content {
					.output {}
					.prompt, .input {
						idx := self.pages.active_start + int(self.cursor.y)
						if idx < self.pages.screen_rows.len {
							unsafe {
								mut row := &self.pages.screen_rows[idx]
								row.semantic_prompt = .prompt_continuation
							}
						}
					}
				}
			}
			continue
		}

		// Determine character width (simplified: all non-control = width 1)
		width := u32(1)

		if self.cursor.pending_wrap {
			assert self.cursor.x == self.pages.cols - 1
			self.cursor.pending_wrap = false
			// Mark current row as wrapped
			cur_idx := self.pages.active_start + int(self.cursor.y)
			if cur_idx < self.pages.screen_rows.len {
				unsafe {
					mut row := &self.pages.screen_rows[cur_idx]
					row.wrap = true
				}
			}
			self.cursor_down_or_scroll()!
			self.cursor_horizontal_absolute(0)
			// Mark new row as continuation
			new_idx := self.pages.active_start + int(self.cursor.y)
			if new_idx < self.pages.screen_rows.len {
				unsafe {
					mut row := &self.pages.screen_rows[new_idx]
					row.wrap_continuation = true
				}
			}
			match self.cursor.semantic_content {
				.output {}
				.input, .prompt {
					idx2 := self.pages.active_start + int(self.cursor.y)
					if idx2 < self.pages.screen_rows.len {
						unsafe {
							mut row := &self.pages.screen_rows[idx2]
							row.semantic_prompt = .prompt_continuation
						}
					}
				}
			}
		}

		// Write the character
		assert width == 1

		row_idx := self.pages.active_start + int(self.cursor.y)
		if row_idx < self.pages.screen_rows.len {
			unsafe {
				mut row := &self.pages.screen_rows[row_idx]
				if int(self.cursor.x) < row.cells.len {
					row.cells[int(self.cursor.x)] = CellData{
						codepoint: u32(c)
						content_tag: .codepoint
						style_id: self.cursor.style_id
						is_protected: self.cursor.is_protected
						semantic_content: self.cursor.semantic_content
					}
					if self.cursor.style_id != default_style_id {
						row.styled = true
					}
				}
			}
		}

		if self.cursor.x + 1 < self.pages.cols {
			self.cursor.x += 1
		} else {
			self.cursor.pending_wrap = true
		}
	}
}
