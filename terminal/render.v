module terminal

import strings

// Developer note: this is in src/terminal and not src/renderer because
// the goal is that this remains generic to multiple renderers. This can
// aid specifically with libghostty-vt with converting terminal state to
// a renderable form.
//
// Translated from Ghostty's render.zig.

// Contains the state required to render the screen, including optimizing
// for repeated render calls and only rendering dirty regions.
//
// Previously, our renderer would use `clone` to clone the screen within
// the viewport to perform rendering. This worked well enough that we kept
// it all the way up through the Ghostty 1.2.x series, but the clone time
// was repeatedly a bottleneck blocking IO.
//
// Rather than a generic clone that tries to clone all screen state per call
// (within a region), a stateful approach that optimizes for only what a
// renderer needs to do makes more sense.
//
// To use this, initialize the render state to empty, then call `update`
// on each frame to update the state to the latest terminal state.
//
//     mut state := RenderState.empty()
//     defer { state.deinit() }
//     state.update(&t)
//
// Note: the render state retains as much memory as possible between updates
// to prevent future allocations. If a very large frame is rendered once,
// the render state will retain that much memory until deinit. To avoid
// waste, it is recommended that the caller `deinit` and start with an
// empty render state every so often.
pub struct RenderState {
pub mut:
	// The current screen dimensions. It is possible that these don't match
	// the renderer's current dimensions in grid cells because resizing
	// can happen asynchronously. For example, for Metal, our NSView resizes
	// at a different time than when our internal terminal state resizes.
	// This can lead to a one or two frame mismatch a renderer needs to
	// handle.
	//
	// The viewport is always exactly equal to the active area size so this
	// is also the viewport size.
	rows u16
	cols u16

	// The color state for the terminal.
	colors RenderColors

	// Cursor state within the viewport.
	cursor RenderCursor

	// The rows (y=0 is top) of the viewport.
	row_data []RenderRow

	// The dirty state of the render state. This is set by the update method.
	// The renderer/caller should set this to false when it has handled
	// the dirty state.
	dirty RenderDirty

	// The screen type that this state represents. This is used primarily
	// to detect changes.
	screen ScreenKey

	// The last viewport pin used to generate this state. This is NOT
	// a tracked pin and is generally NOT safe to read other than the direct
	// values for comparison.
	viewport_pin ?Pin

	// The cached selection so we can avoid expensive selection calculations
	// if possible.
	selection_cache ?RenderSelectionCache
}

// The color state for the terminal.
//
// The background/foreground will be reversed if the terminal reverse
// color mode is on! You do not need to handle that manually!
pub struct RenderColors {
pub mut:
	background RGB
	foreground RGB
	cursor     ?RGB
	palette    [256]RGB
}

// Cursor state within the viewport.
pub struct RenderCursor {
pub mut:
	// The x/y position of the cursor within the active area.
	active Pin

	// The x/y position of the cursor within the viewport. This
	// may be null if the cursor is not visible within the viewport.
	viewport ?ViewportPoint

	// The cell data for the cursor position. Managed memory is not
	// safe to access from this.
	cell CellData

	// The style, always valid even if the cell is default style.
	style CellStyle

	// The visual style of the cursor itself, such as a block or
	// bar.
	visual_style CursorStyle

	// True if the cursor is detected to be at a password input field.
	password_input bool

	// Cursor visibility state determined by the terminal mode.
	visible bool

	// Cursor blink state determined by the terminal mode.
	blinking bool
}

// ViewportPoint represents a position within the viewport.
// This is used by both RenderCursor and the renderer.
pub struct ViewportPoint {
pub mut:
	// The x/y position within the viewport.
	x u16
	y u16

	// Whether the cursor is part of a wide character and
	// on the tail of it. If so, some renderers may use this
	// to move the cursor back one.
	wide_tail bool
}

// A row within the viewport.
pub struct RenderRow {
pub mut:
	// The page pin. This is not safe to read unless you can guarantee
	// the terminal state hasn't changed since the last `update` call.
	pin Pin

	// Raw row data.
	raw RowData

	// The cells in this row.
	cells []RenderCell

	// A dirty flag that can be used by the renderer to track
	// its own draw state. `update` will mark this true whenever
	// this row is changed, too.
	dirty bool

	// The x range of the selection within this row.
	selection ?[2]u16

	// The highlights within this row.
	highlights []RenderHighlight
}

// A highlight within a row.
pub struct RenderHighlight {
pub:
	// A special tag that can be used by the caller to differentiate
	// different highlight types. The value is opaque to the RenderState.
	tag u8

	// The x ranges of highlights within this row.
	range [2]u16
}

// A cell within a rendered row.
pub struct RenderCell {
pub mut:
	// Always set, this is the raw copied cell data from CellData.
	// The managed memory (hyperlinks, graphemes, etc.) is NOT safe
	// to access from here. It is duplicated into the other fields if
	// it exists.
	raw CellData

	// Grapheme data for the cell. This is undefined unless the
	// raw cell's content_tag is `codepoint_grapheme`.
	grapheme []u32

	// The style data for the cell. This is undefined unless
	// the style_id is non-default on raw.
	style CellStyle
}

// Dirty state
pub enum RenderDirty {
	// Not dirty at all. Can skip rendering if prior state was
	// already rendered.
	false_
	// Partially dirty. Some rows changed but not all. None of the
	// global state changed such as colors.
	partial
	// Fully dirty. Global state changed or dimensions changed. All rows
	// should be redrawn.
	full
}

// Cached selection data for render optimization.
struct RenderSelectionCache {
	selection Selection
	tl_pin    Pin
	br_pin    Pin
}

// Initial state.
pub fn RenderState.empty() RenderState {
	return RenderState{
		rows: 0
		cols: 0
		colors: RenderColors{
			cursor: none
		}
		cursor: RenderCursor{
			active: Pin{ x: 0, y: 0 }
			viewport: none
			cell: CellData{}
			style: CellStyle{}
			visual_style: .block
			password_input: false
			visible: true
			blinking: false
		}
		row_data: []
		dirty: .false_
		screen: .primary
	}
}

// Clean up render state resources.
pub fn (mut self RenderState) deinit() {
	self.row_data = []
}

// Update the render state to the latest terminal state.
//
// This will reset the terminal dirty state since it is consumed
// by this render state update.
pub fn (mut self RenderState) update(mut t Terminal) {
	// This is a translation of Ghostty's render.zig RenderState.update with
	// row-level dirty tracking. The simplified Pages model uses a flat row
	// array (screen_rows) with an active_start offset, so we iterate the
	// active viewport rows directly instead of a PageList row iterator.
	// Style is stored inline on cells so no page style map lookups are
	// needed, and there is no per-row arena.
	mut s := t.screens.active

	// Compute the absolute row index of the top of the viewport. The
	// simplified Pages model keeps a flat row array (screen_rows). The
	// active area starts at `active_start`, but the viewport can be
	// scrolled independently (e.g. to the top of scrollback). We resolve
	// the viewport top based on the current viewport state so that a
	// scrolled viewport renders scrollback rows and the cursor (which is
	// always in the active area) can correctly fall out of view.
	viewport_top := match s.pages.viewport {
		.active { s.pages.active_start }
		.top { 0 }
		.pinned { s.pages.viewport_start }
	}

	// The absolute cursor row within screen_rows.
	cursor_abs_y := u32(s.pages.active_start) + s.cursor.y

	// The viewport pin: top-left of the viewport, in absolute rows.
	viewport_pin := Pin{ x: 0, y: u32(viewport_top) }

	// Determine if we need a full redraw.
	//
	//   - screen key changed (render state is viewport-specific)
	//   - the terminal is dirty at all (full-terminal dirty tracker)
	//   - the screen is dirty at all (full-screen dirty tracker)
	//   - our dimensions changed
	//   - our viewport pin changed
	mut redraw := false
	if t.screens.active_key != self.screen {
		redraw = true
	} else if t.flags.dirty.clear || t.flags.dirty.palette || t.flags.dirty.reverse_colors
		|| t.flags.dirty.preedit {
		redraw = true
	} else if s.dirty.selection || s.dirty.hyperlink_hover {
		redraw = true
	} else if self.rows != u16(s.pages.rows) || self.cols != u16(s.pages.cols) {
		redraw = true
	} else if old := self.viewport_pin {
		if !old.eql(viewport_pin) {
			redraw = true
		}
	}

	// Always set our cheap fields.
	self.rows = u16(s.pages.rows)
	self.cols = u16(s.pages.cols)
	self.viewport_pin = viewport_pin
	self.cursor.active = Pin{ x: s.cursor.x, y: s.cursor.y }
	self.cursor.style = s.cursor.style
	self.cursor.visual_style = s.cursor.cursor_style
	self.cursor.password_input = t.flags.password_input
	self.cursor.visible = t.modes.get(.cursor_visible)
	self.cursor.blinking = t.modes.get(.cursor_blinking)

	// Always reset the cursor viewport position; recomputed below.
	self.cursor.viewport = none

	// Colors.
	self.colors.cursor = t.colors.cursor.get()
	self.colors.palette = t.colors.palette.entries
	if bg := t.colors.background.get() {
		if fg := t.colors.foreground.get() {
			if t.modes.get(.reverse_colors) {
				self.colors.background = fg
				self.colors.foreground = bg
			} else {
				self.colors.background = bg
				self.colors.foreground = fg
			}
		}
	}

	// Ensure our row_data length is exactly our height. Newly added rows are
	// marked dirty so they get rebuilt below.
	if self.row_data.len != int(self.rows) {
		if self.row_data.len < int(self.rows) {
			for _ in self.row_data.len .. int(self.rows) {
				self.row_data << RenderRow{
					pin: Pin{ x: 0, y: 0 }
					raw: RowData{}
					cells: []
					dirty: true
					selection: none
					highlights: []
				}
			}
		} else {
			self.row_data = self.row_data[..int(self.rows)]
		}
	}

	// Go through and setup our rows, only rebuilding dirty ones.
	mut any_dirty := false
	for y in 0 .. int(self.rows) {
		abs_y := viewport_top + y
		if abs_y < 0 || abs_y >= s.pages.screen_rows.len {
			continue
		}

		// Find our cursor if we haven't found it yet. We do this even if the
		// row is not dirty because the cursor is unrelated to row dirtiness.
		// We compare against the cursor's absolute row so that a scrolled
		// viewport correctly reports the cursor as out of view (none).
		if self.cursor.viewport == none && u32(abs_y) == cursor_abs_y {
			row := s.pages.screen_rows[abs_y]
			mut wide_tail := false
			if s.cursor.x > 0 {
				lx := int(s.cursor.x) - 1
				if lx < row.cells.len && row.cells[lx].wide == .wide {
					wide_tail = true
				}
			}
			self.cursor.viewport = ViewportPoint{
				y: u16(y)
				x: u16(s.cursor.x)
				wide_tail: wide_tail
			}
			if int(s.cursor.x) < row.cells.len {
				self.cursor.cell = row.cells[int(s.cursor.x)]
			}
		}

		// Store our pin. We store this even if we're not dirty because it
		// lets us remap cells back to the correct render row.
		self.row_data[y].pin = Pin{ x: 0, y: u32(abs_y) }

		// Determine if this row is dirty. If we're redrawing, everything is
		// dirty; otherwise consult the row's dirty flag.
		row_dirty := redraw || s.pages.screen_rows[abs_y].dirty
		if !row_dirty {
			continue
		}

		any_dirty = true

		// Clear the source row dirty flag now that we're rebuilding it.
		unsafe {
			mut src_row := &s.pages.screen_rows[abs_y]
			src_row.dirty = false
		}

		src := s.pages.screen_rows[abs_y]

		// Rebuild the cells for this row.
		mut cells := []RenderCell{cap: int(self.cols)}
		for x in 0 .. int(self.cols) {
			if x < src.cells.len {
				pc := src.cells[x]
				mut rc := RenderCell{
					raw: pc
					grapheme: []
					style: pc.style
				}
				// If we have a multi-codepoint grapheme, copy the codepoints.
				if pc.content_tag == .codepoint_grapheme && pc.graphemes.len > 0 {
					rc.grapheme = pc.graphemes.clone()
				}
				cells << rc
			} else {
				cells << RenderCell{
					raw: CellData{}
					grapheme: []
					style: CellStyle{}
				}
			}
		}

		self.row_data[y].raw = src
		self.row_data[y].cells = cells
		self.row_data[y].dirty = true
		self.row_data[y].selection = none
		self.row_data[y].highlights = []
	}

	// If our screen has a selection, mark the rows within it. We do this
	// outside the loop above because a selection is unlikely and its
	// current representation is inefficient.
	if sel := s.selection {
		tl := if sel.start_pin.before(sel.end_pin) { sel.start_pin } else { sel.end_pin }
		br := if sel.start_pin.before(sel.end_pin) { sel.end_pin } else { sel.start_pin }
		for y in 0 .. int(self.rows) {
			screen_y := u32(viewport_top) + u32(y)
			if screen_y >= tl.y && screen_y <= br.y {
				start_x := if screen_y == tl.y { u16(tl.x) } else { u16(0) }
				end_x := if screen_y == br.y {
					u16(br.x)
				} else {
					u16(s.pages.cols - 1)
				}
				self.row_data[y].selection = [start_x, end_x]!
			}
		}
	}

	// Handle dirty state.
	if redraw {
		self.screen = t.screens.active_key
		self.dirty = .full
	} else if any_dirty && self.dirty == .false_ {
		self.dirty = .partial
	}

	// Clear our terminal/screen dirty flags now that they're consumed.
	t.flags.dirty = Dirty{}
	s.dirty = ScreenDirty{}
}

// Update the highlights in the render state from the given flattened
// highlights. Because this uses flattened highlights, it does not require
// reading from the terminal state so it should be done outside of
// any critical sections.
//
// This will not clear any previous highlights, so the caller must
// manually clear them if desired.
pub fn (mut self RenderState) update_highlights_flattened(tag u8, ranges []RenderHighlight) {
	// XTODO: Full highlight update requires flattened highlight chunks
	// with page node references and row range matching.
	// Simplified: just append highlights to matching rows.
	for hl in ranges {
		y := int(hl.range[1]) // Use range as y index for simplified model
		if y < self.row_data.len {
			self.row_data[y].highlights << RenderHighlight{
				tag: tag
				range: hl.range
			}
			self.row_data[y].dirty = true
		}
	}
}

// A set of coordinates representing cells.
pub type CellSet = map[u64]bool

// Helper to make a coordinate key for CellSet.
fn cell_set_key(x u32, y u32) u64 {
	return u64(y) << 32 | u64(x)
}

// Returns a map of the cells that match to an OSC8 hyperlink over the
// given point in the render state.
//
// IMPORTANT: The terminal must not have updated since the last call to
// `update`. If there is any chance the terminal has updated, the caller
// must first call `update` again to refresh the render state.
//
// For example, you may want to hold a lock for the duration of the
// update and hyperlink lookup to ensure no updates happen in between.
pub fn (self &RenderState) link_cells(viewport_point Pin) CellSet {
	mut result := CellSet{}

	// Our viewport point is sent in by the caller and can't be trusted.
	// If it is outside the valid area then just return empty because
	// we can't possibly have a link there.
	if viewport_point.x >= u32(self.cols) || viewport_point.y >= u32(self.row_data.len) {
		return result
	}

	// Check if the cell has a hyperlink
	row := self.row_data[int(viewport_point.y)]
	if int(viewport_point.x) < row.cells.len {
		cell := row.cells[int(viewport_point.x)]
		if cell.raw.has_hyperlink {
			for ry, r in self.row_data {
				for rx, c in r.cells {
					if c.raw.has_hyperlink && cell.raw.hyperlink.eql(&c.raw.hyperlink) {
						result[cell_set_key(u32(rx), u32(ry))] = true
					}
				}
			}
		}
	}

	return result
}

// Convert the current render state contents to a UTF-8 encoded
// string. This will unwrap all the wrapped rows. This is useful
// for a minimal viewport search.
//
// This currently writes empty cell contents as \x00 and writes all
// blank lines. This is fine for our current usage (link search) but
// we can adjust this later.
//
// NOTE: There is a limitation in that wrapped lines before/after
// the the top/bottom line of the viewport are not included, since
// the render state cuts them off.
pub fn (self &RenderState) to_string() string {
	mut sb := strings.new_builder(int(self.rows) * int(self.cols))
	for row in self.row_data {
		for cell in row.cells {
			cp := cell.raw.codepoint_val()
			if cp == 0 {
				sb.write_u8(0) // null byte for empty cells
			} else {
				write_utf8(mut sb, cp)
				if cell.raw.has_grapheme {
					for grapheme_cp in cell.grapheme {
						write_utf8(mut sb, grapheme_cp)
					}
				}
			}
		}
		if !row.raw.wrap {
			sb.write_u8(u8(`\n`))
		}
	}
	return sb.str()
}
