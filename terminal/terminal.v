module terminal

// The primary terminal emulation structure. This represents a single
// "terminal" containing a grid of characters and exposes various operations
// on that grid. This also maintains the scrollback buffer.

import strings

// Default tabstop interval
const tabstop_interval = 8

// ============================================================
// Terminal struct
// ============================================================

pub struct Terminal {
pub mut:
	// The set of screens behind this terminal (e.g. primary vs alternate).
	screens ScreenSet

	// Whether we're currently writing to the status line (DECSASD and DECSSDT).
	// We don't support a status line currently so we just black hole this
	// data so that it doesn't mess up our main display.
	status_display StatusDisplay = .main

	// Where the tabstops are.
	tabstops Tabstops

	// The size of the terminal.
	rows u16
	cols u16

	// The size of the screen in pixels. This is used for pty events and images.
	width_px u32
	height_px u32

	// The current scrolling region.
	scrolling_region ScrollingRegion

	// The last reported pwd, if any.
	pwd string

	// The color state for this terminal.
	colors Colors

	// The previous printed character. This is used for the repeat previous
	// char CSI (ESC [ <n> b).
	previous_char ?u32

	// The modes that this terminal currently has active.
	modes ModeState

	// The most recently set mouse shape for the terminal.
	mouse_shape MouseShape = .text

	// These are just a packed set of flags we may set on the terminal.
	flags TerminalFlags
}

// ============================================================
// Nested types
// ============================================================

pub enum StatusDisplay {
	main
	status_line
}

// The various color configurations a terminal maintains and that can
// be set dynamically via OSC, with defaults usually coming from a
// configuration.
pub struct Colors {
pub mut:
	background DynamicRGB
	foreground DynamicRGB
	cursor     DynamicRGB
	palette    DynamicPalette
}

pub const colors_default = Colors{
	background: DynamicRGB(Unset{})
	foreground: DynamicRGB(Unset{})
	cursor: DynamicRGB(Unset{})
	palette: dynamic_palette_default
}

// DynamicRGB can be either unset or an RGB value.
pub struct Unset {}

pub type DynamicRGB = Unset | RGB

pub struct RGB {
pub:
	r u8
	g u8
	b u8
}

pub struct DynamicPalette {
pub mut:
	entries [256]RGB
}

pub const dynamic_palette_default = DynamicPalette{}

// This is a set of dirty flags the renderer can use to determine
// what parts of the screen need to be redrawn. It is up to the renderer
// to clear these flags.
//
// This only contains dirty flags for terminal state, not for the screen
// state. The screen state has its own dirty flags.
pub struct Dirty {
pub mut:
	// Set when the color palette is modified in any way.
	palette bool

	// Set when the reverse colors mode is modified.
	reverse_colors bool

	// Screen clear of some kind. This can be due to a screen change,
	// erase display, etc.
	clear bool

	// Set when the pre-edit is modified.
	preedit bool
}

// The event types that can be reported for mouse-related activities.
// These are all mutually exclusive (hence in a single enum).
pub enum MouseEvents {
	none
	x10      // 9
	normal   // 1000
	button   // 1002
	any      // 1003
}

// Returns true if this event sends motion events.
pub fn (self MouseEvents) motion() bool {
	return self == .button || self == .any
}

// The format of mouse events when enabled.
// These are all mutually exclusive (hence in a single enum).
pub enum MouseFormat {
	x10
	utf8       // 1005
	sgr        // 1006
	urxvt      // 1015
	sgr_pixels // 1016
}

// Scrolling region is the area of the screen designated where scrolling
// occurs. When scrolling the screen, only this viewport is scrolled.
pub struct ScrollingRegion {
pub mut:
	// Top and bottom of the scroll region (0-indexed)
	// Precondition: top < bottom
	top    u16
	bottom u16

	// Left/right scroll regions.
	// Precondition: right > left
	// Precondition: right <= cols - 1
	left  u16
	right u16
}

pub struct Options {
pub:
	cols           u16
	rows           u16
	max_scrollback int = 10_000
	colors         Colors = terminal.colors_default

	// The default mode state. When the terminal gets a reset, it
	// will revert back to this state.
	default_modes ModePacked
}

pub struct ModePacked {
pub mut:
	data u32
}

pub struct TerminalFlags {
pub mut:
	// This supports a Kitty extension where programs using semantic
	// prompts (OSC133) can annotate their new prompts with `redraw=0` to
	// disable clearing the prompt on resize.
	shell_redraws_prompt PromptRedraw = .true_

	// This is set via ESC[4;2m. Any other modify key mode just sets
	// this to false and we act in mode 1 by default.
	modify_other_keys_2 bool

	// The mouse event mode and format. These are set to the last
	// set mode in modes. You can't get the right event/format to use
	// based on modes alone because modes don't show you what order
	// this was called so we have to track it separately.
	mouse_event  MouseEvents = .none
	mouse_format MouseFormat = .x10

	// Set via the XTSHIFTESCAPE sequence. If true (XTSHIFTESCAPE = 1)
	// then we want to capture the shift key for the mouse protocol
	// if the configuration allows it.
	mouse_shift_capture MouseShiftCaptureState = .null_

	// True if the window is focused.
	focused bool = true

	// True if the terminal is in a password entry mode. This is set
	// to true based on termios state.
	password_input bool

	// True if the terminal should perform selection scrolling.
	selection_scroll bool

	// Dirty flag used only by the search thread. The renderer is expected
	// to set this to true if the viewport was dirty as it was rendering.
	// This is used by the search thread to more efficiently re-search the
	// viewport and active area.
	//
	// Since the renderer is going to inspect the viewport/active area ANYWAYS,
	// this lets our search thread do less work and hold the lock less time,
	// resulting in more throughput for everything.
	search_viewport_dirty bool

	// Dirty flags for the renderer.
	dirty Dirty
}

pub enum MouseShiftCaptureState {
	null_
	false_
	true_
}

// Options for scrolling the viewport of the terminal grid.
pub enum ScrollViewport {
	// Scroll to the top of the scrollback
	top
	// Scroll to the bottom, i.e. the top of the active area
	bottom
	// Scroll by some delta amount, up is negative.
	delta
}

// The modes for DECCOLM.
pub enum DeccolmMode as u8 {
	cols_80  = 0
	cols_132 = 1
}

// Modal screen changes. These map to the literal terminal
// modes to enable or disable alternate screen modes.
pub enum SwitchScreenMode {
	// Legacy alternate screen mode. This goes to the alternate
	// screen or primary screen and only copies the cursor. The
	// screen is not erased.
	mode_47

	// Alternate screen mode where the alternate screen is cleared
	// on exit. The primary screen is never cleared. The cursor is
	// copied.
	mode_1047

	// Save primary screen cursor, switch to alternate screen,
	// and clear the alternate screen on entry. On exit,
	// do not clear the screen, and restore the cursor on the
	// primary screen.
	mode_1049
}

// ============================================================
// ScreenSet: manages primary and alternate screens
// ============================================================

pub struct ScreenSet {
pub mut:
	primary   Screen
	alternate ?Screen
	active    &Screen = unsafe { nil }
	active_key ScreenKey = .primary
}

pub enum ScreenKey {
	primary
	alternate
}

pub fn ScreenSet.init(cols u16, rows u16, max_scrollback int) !ScreenSet {
	mut ss := ScreenSet{
		primary: Screen.init(u32(cols), u32(rows), u32(max_scrollback))
	}
	ss.active = &ss.primary
	return ss
}

pub fn (mut self ScreenSet) deinit() {
	self.primary.deinit()
	if mut alt := self.alternate {
		alt.deinit()
	}
}

pub fn (mut self ScreenSet) get(key ScreenKey) ?&Screen {
	match key {
		.primary { return &self.primary }
		.alternate {
			if mut alt := self.alternate {
				return &alt
			}
			return none
		}
	}
}

pub fn (mut self ScreenSet) switch_to(key ScreenKey) {
	match key {
		.primary {
			self.active = &self.primary
			self.active_key = .primary
		}
		.alternate {
			if mut alt := self.alternate {
				self.active = &alt
				self.active_key = .alternate
			}
		}
	}
}

pub fn (mut self ScreenSet) remove(key ScreenKey) {
	match key {
		.alternate { self.alternate = none }
		.primary {} // never remove primary
	}
}

// ============================================================
// Tabstops
// ============================================================

pub struct Tabstops {
mut:
	stops []bool
}

pub fn Tabstops.init(cols int, interval int) !Tabstops {
	mut stops := []bool{len: cols}
	for i in 0 .. cols {
		stops[i] = interval > 0 && (i % interval) == 0
	}
	return Tabstops{
		stops: stops
	}
}

pub fn (mut self Tabstops) deinit() {
	self.stops = []
}

pub fn (self Tabstops) get(x u32) bool {
	if int(x) < self.stops.len {
		return self.stops[int(x)]
	}
	return false
}

pub fn (mut self Tabstops) set(x u32) {
	if int(x) < self.stops.len {
		self.stops[int(x)] = true
	}
}

pub fn (mut self Tabstops) unset(x u32) {
	if int(x) < self.stops.len {
		self.stops[int(x)] = false
	}
}

pub fn (mut self Tabstops) reset(interval int) {
	for i in 0 .. self.stops.len {
		self.stops[i] = interval > 0 && (i % interval) == 0
	}
}

// ============================================================
// ModeState: terminal modes
// ============================================================

pub struct ModeState {
pub mut:
	values  ModePacked
	default ModePacked
}

pub fn (self ModeState) get(mode Mode) bool {
	bit := u32(1) << (int(mode) & 31)
	return (self.values.data & bit) != 0
}

pub fn (mut self ModeState) set(mode Mode, val bool) {
	bit := u32(1) << (int(mode) & 31)
	if val {
		self.values.data |= bit
	} else {
		self.values.data &= ~bit
	}
}

pub fn (mut self ModeState) reset() {
	self.values = self.default
}

pub enum Mode {
	wraparound             // = 0
	origin                 // = 1
	cursor_visible         // = 2
	insert                 // = 3
	linefeed               // = 4
	grapheme_cluster       // = 5 (mode 2027)
	reverse_wrap           // = 6
	reverse_wrap_extended  // = 7
	enable_left_and_right_margin // = 8
	enable_mode_3          // = 9 (DECCOLM support)
	column_132             // = 10
	bracketed_paste        // = 11
	focus_event            // = 12
}

// ============================================================
// Mouse shape
// ============================================================

pub enum MouseShape {
	default_
	text
	pointer
	crosshair
	help
	progress
}

// ============================================================
// Prompt redraw
// ============================================================

pub enum PromptRedraw {
	false_
	true_
	last
}

// ============================================================
// Initialize a new terminal.
// ============================================================

pub fn Terminal.init(opts Options) !Terminal {
	cols := opts.cols
	rows := opts.rows

	mut screen_set := ScreenSet.init(cols, rows, opts.max_scrollback)!

	return Terminal{
		cols: cols
		rows: rows
		screens: screen_set
		tabstops: Tabstops.init(int(cols), terminal.tabstop_interval)!
		scrolling_region: ScrollingRegion{
			top: 0
			bottom: rows - 1
			left: 0
			right: cols - 1
		}
		colors: opts.colors
		modes: ModeState{
			values: opts.default_modes
			default: opts.default_modes
		}
	}
}

pub fn (mut self Terminal) deinit() {
	self.tabstops.deinit()
	self.screens.deinit()
}

// Return a terminal.Stream that can process VT streams and update this
// terminal state. The streams will only process read-only data that
// modifies terminal state. Sequences that query or otherwise require
// output will be ignored.
pub fn (mut self Terminal) vt_stream() ReadonlyStream {
	// XTODO
	// Requires ReadonlyStream/ReadonlyHandler from stream_readonly.zig.
	// Those types parse VT sequences and call back into the terminal.
	return ReadonlyStream{}
}

// This is the handler-side only for vt_stream.
pub fn (mut self Terminal) vt_handler() ReadonlyHandler {
	// XTODO
	// Requires ReadonlyHandler from stream_readonly.zig.
	return ReadonlyHandler{}
}

pub struct ReadonlyStream {}

pub struct ReadonlyHandler {}

// ============================================================
// Print functions
// ============================================================

// Print UTF-8 encoded string to the terminal.
pub fn (mut self Terminal) print_string(str string) ! {
	for c in str.runes() {
		if c == `\n` {
			self.carriage_return()
			self.linefeed()!
		} else {
			self.print(u32(c))!
		}
	}
}

// Print the previous printed character a repeated amount of times.
pub fn (mut self Terminal) print_repeat(count_req int) ! {
	if c := self.previous_char {
		count := if count_req < 1 { 1 } else { count_req }
		for _ in 0 .. count {
			self.print(c)!
		}
	}
}

// Print a single codepoint to the terminal.
pub fn (mut self Terminal) print(c u32) ! {
	// If we're not on the main display, do nothing for now
	if self.status_display != .main {
		return
	}

	// After doing any printing, wrapping, scrolling, etc. we want to ensure
	// that our screen remains in a consistent state.
	defer { self.screens.active.assert_integrity() }

	// Our right margin depends where our cursor is now.
	right_limit := if self.screens.active.cursor.x > self.scrolling_region.right {
		self.cols
	} else {
		self.scrolling_region.right + 1
	}

	// Perform grapheme clustering if grapheme support is enabled (mode 2027).
	// This is MUCH slower than the normal path so the conditional below is
	// purposely ordered in least-likely to most-likely so we can drop out
	// as quickly as possible.
	if c > 255 && self.modes.get(.grapheme_cluster) && self.screens.active.cursor.x > 0 {
		// XTODO
		// Full grapheme clustering requires uucode.grapheme.BreakState,
		// unicode.graphemeBreak, and cell grapheme storage on pages.
		// The VS15/VS16 emoji variation selector handling and grapheme
		// attachment logic cannot be translated without the unicode tables.
	}

	// Determine the width of this character so we can handle
	// non-single-width characters properly. We have a fast-path for
	// byte-sized characters since they're so common. We can ignore
	// control characters because they're always filtered prior.
	width := if c <= 0xFF { u16(1) } else { u16(1) } // simplified: full width detection needs unicode tables

	// Attach zero-width characters to our cell as grapheme data.
	if width == 0 {
		// XTODO
		// Zero-width character attachment needs page-level grapheme
		// storage and cell grapheme append. Cannot translate without
		// the Page.appendGrapheme infrastructure.
		return
	}

	// We have a printable character, save it
	self.previous_char = c

	// If we're soft-wrapping, then handle that first.
	if self.screens.active.cursor.pending_wrap && self.modes.get(.wraparound) {
		self.print_wrap()!
	}

	// If we have insert mode enabled then we need to handle that. We
	// only do insert mode if we're not at the end of the line.
	if self.modes.get(.insert) && self.screens.active.cursor.x + width < self.cols {
		self.insert_blanks(int(width))
	}

	if width == 1 {
		// Single cell is very easy: just write in the cell
		self.screens.active.cursor_mark_dirty()
		self.print_cell(c, .narrow)
	} else if width == 2 {
		if (right_limit - self.scrolling_region.left) > 1 {
			// Wide character requires a spacer. We print this by
			// using two cells: the first is flagged "wide" and has the
			// wide char. The second is guaranteed to be a spacer if
			// we're not at the end of the line.
			if self.screens.active.cursor.x == right_limit - 1 {
				// If we don't have wraparound enabled then we don't print
				// this character at all and don't move the cursor.
				if !self.modes.get(.wraparound) {
					return
				}

				// We only create a spacer head if we're at the real edge
				// of the screen.
				spacer_wide := if right_limit == self.cols {
					CellWide.spacer_head
				} else {
					CellWide.narrow
				}
				self.print_cell(0, spacer_wide)
				self.print_wrap()!
			}

			self.screens.active.cursor_mark_dirty()
			self.print_cell(c, .wide)
			self.screens.active.cursor_right(1)
			self.print_cell(0, .spacer_tail)
		} else {
			// This is pretty broken, terminals should never be only 1-wide.
			self.screens.active.cursor_mark_dirty()
			self.print_cell(0, .narrow)
		}
	}

	// If we're at the column limit, then we need to wrap the next time.
	// In this case, we don't move the cursor.
	if self.screens.active.cursor.x == right_limit - 1 {
		self.screens.active.cursor.pending_wrap = true
		return
	}

	// Move the cursor
	self.screens.active.cursor_right(1)
}

fn (mut self Terminal) print_cell(unmapped_c u32, wide CellWide) {
	defer { self.screens.active.assert_integrity() }

	// Map through charset
	c := self.map_charset(unmapped_c)

	row_idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
	if row_idx >= self.screens.active.pages.screen_rows.len {
		return
	}

	cell_x := int(self.screens.active.cursor.x)
	unsafe {
		mut row := &self.screens.active.pages.screen_rows[row_idx]
		if cell_x >= row.cells.len {
			return
		}

		old_cell := row.cells[cell_x]

		// If the wide property of this cell is different, we may need to
		// clear some cells.
		if old_cell.wide != wide {
			match old_cell.wide {
				.narrow {} // Do nothing
				.wide {
					// Previous cell was wide. Clear the tail.
					if cell_x + 1 < row.cells.len {
						row.cells[cell_x + 1] = CellData{}
					}
				}
				.spacer_tail {
					// Previous cell was spacer_tail. Clear the wide cell before it.
					if cell_x > 0 {
						row.cells[cell_x - 1] = CellData{}
					}
				}
				.spacer_head {} // TODO: investigate
			}
		}

		// If the prior value had graphemes, clear those
		if old_cell.has_grapheme {
			row.cells[cell_x].graphemes = []
			row.cells[cell_x].has_grapheme = false
			// Update row grapheme flag
			mut has_any := false
			for cell in row.cells {
				if cell.has_grapheme {
					has_any = true
					break
				}
			}
			row.grapheme = has_any
		}

		// Write the cell
		row.cells[cell_x] = CellData{
			codepoint: u32(c)
			content_tag: .codepoint
			style_id: self.screens.active.cursor.style_id
			wide: wide
			is_protected: self.screens.active.cursor.is_protected
			semantic_content: self.screens.active.cursor.semantic_content
		}

		// Update row flags
		if self.screens.active.cursor.style_id != terminal.default_style_id {
			row.styled = true
		}

		// Handle hyperlink
		if self.screens.active.cursor.hyperlink_id > 0 {
			self.screens.active.cursor_set_hyperlink() or {}
		} else if old_cell.has_hyperlink {
			row.cells[cell_x].has_hyperlink = false
			// Update row hyperlink flag
			mut has_hl := false
			for cell in row.cells {
				if cell.has_hyperlink {
					has_hl = true
					break
				}
			}
			row.hyperlink = has_hl
		}
	}
}

fn (self &Terminal) map_charset(unmapped_c u32) u32 {
	// XTODO
	// Full charset mapping requires charsets.table() lookup for
	// non-UTF8/ASCII character sets. Single-shift handling also
	// needs charset.single_shift state.
	// For now, return as-is (UTF-8/ASCII passthrough).
	return unmapped_c
}

fn (mut self Terminal) print_wrap() ! {
	// We only mark that we soft-wrapped if we're at the edge of our
	// full screen. We don't mark the row as wrapped if we're in the
	// middle due to a right margin.
	cursor := &self.screens.active.cursor
	mark_wrap := cursor.x == self.cols - 1
	if mark_wrap {
		row_idx := self.screens.active.pages.active_start + int(cursor.y)
		if row_idx < self.screens.active.pages.screen_rows.len {
			unsafe {
				mut row := &self.screens.active.pages.screen_rows[row_idx]
				row.wrap = true
			}
		}
	}

	// Get the old semantic prompt so we can extend it to the next line.
	old_semantic := cursor.semantic_content
	old_semantic_clear := cursor.semantic_content_clear_eol

	// Move to the next line
	self.index()!
	self.screens.active.cursor_horizontal_absolute(self.scrolling_region.left)

	// We always reset our semantic prompt state
	self.screens.active.cursor.semantic_content = old_semantic
	self.screens.active.cursor.semantic_content_clear_eol = old_semantic_clear
	match old_semantic {
		.output, .input {}
		.prompt {
			idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
			if idx < self.screens.active.pages.screen_rows.len {
				unsafe {
					mut row := &self.screens.active.pages.screen_rows[idx]
					row.semantic_prompt = .prompt_continuation
				}
			}
		}
	}

	if mark_wrap {
		idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
		if idx < self.screens.active.pages.screen_rows.len {
			unsafe {
				mut row := &self.screens.active.pages.screen_rows[idx]
				// Always mark the row as a continuation
				row.wrap_continuation = true
			}
		}
	}

	// Assure that our screen is consistent
	self.screens.active.assert_integrity()
}

// ============================================================
// Charset functions
// ============================================================

// Set the charset into the given slot.
pub fn (mut self Terminal) configure_charset(slot CharsetSlot, set Charset) {
	self.screens.active.charset.charsets.set(slot, set)
}

// Invoke the charset in slot into the active slot. If single is true,
// then this will only be invoked for a single character.
pub fn (mut self Terminal) invoke_charset(active ActiveSlot, slot CharsetSlot, single bool) {
	if single {
		self.screens.active.charset.single_shift = slot
		return
	}
	match active {
		.gl { self.screens.active.charset.gl = slot }
		.gr { self.screens.active.charset.gr = slot }
	}
}

pub enum ActiveSlot {
	gl
	gr
}

// ============================================================
// Basic cursor movement
// ============================================================

// Carriage return moves the cursor to the first column.
pub fn (mut self Terminal) carriage_return() {
	// Always reset pending wrap state
	self.screens.active.cursor.pending_wrap = false

	// In origin mode we always move to the left margin
	target := if self.modes.get(.origin) {
		self.scrolling_region.left
	} else if self.screens.active.cursor.x >= self.scrolling_region.left {
		self.scrolling_region.left
	} else {
		u16(0)
	}
	self.screens.active.cursor_horizontal_absolute(target)
}

// Linefeed moves the cursor to the next line.
pub fn (mut self Terminal) linefeed() ! {
	self.index()!
	if self.modes.get(.linefeed) {
		self.carriage_return()
	}
}

// Backspace moves the cursor back a column (but not less than 0).
pub fn (mut self Terminal) backspace() {
	self.cursor_left(1)
}

// Move the cursor up amount lines. If amount is greater than the maximum
// move distance then it is internally adjusted to the maximum. If amount is
// 0, adjust it to 1.
pub fn (mut self Terminal) cursor_up(count_req int) {
	// Always resets pending wrap
	self.screens.active.cursor.pending_wrap = false

	// The maximum amount the cursor can move up depends on scrolling regions
	max := if self.screens.active.cursor.y >= self.scrolling_region.top {
		self.screens.active.cursor.y - self.scrolling_region.top
	} else {
		self.screens.active.cursor.y
	}
	count_clamped := if count_req < 1 { u16(1) } else { u16(count_req) }
	count := if max < count_clamped { max } else { count_clamped }

	if count > 0 {
		self.screens.active.cursor_up(u32(count))
	}
}

// Move the cursor down amount lines. If amount is greater than the maximum
// move distance then it is internally adjusted to the maximum. This sequence
// will not scroll the screen or scroll region. If amount is 0, adjust it to 1.
pub fn (mut self Terminal) cursor_down(count_req int) {
	// Always resets pending wrap
	self.screens.active.cursor.pending_wrap = false

	// The max the cursor can move to depends where the cursor currently is
	max := if self.screens.active.cursor.y <= self.scrolling_region.bottom {
		self.scrolling_region.bottom - self.screens.active.cursor.y
	} else {
		u16(self.rows - self.screens.active.cursor.y - 1)
	}
	count_clamped := if count_req < 1 { u16(1) } else { u16(count_req) }
	count := if max < count_clamped { max } else { count_clamped }

	if count > 0 {
		self.screens.active.cursor_down(u32(count))
	}
}

// Move the cursor right amount columns. If amount is greater than the
// maximum move distance then it is internally adjusted to the maximum.
// This sequence will not scroll the screen or scroll region. If amount is
// 0, adjust it to 1.
pub fn (mut self Terminal) cursor_right(count_req int) {
	// Always resets pending wrap
	self.screens.active.cursor.pending_wrap = false

	// The max the cursor can move to depends where the cursor currently is
	max := if self.screens.active.cursor.x <= self.scrolling_region.right {
		self.scrolling_region.right - self.screens.active.cursor.x
	} else {
		u16(self.cols - self.screens.active.cursor.x - 1)
	}
	count_clamped := if count_req < 1 { u16(1) } else { u16(count_req) }
	count := if max < count_clamped { max } else { count_clamped }

	if count > 0 {
		self.screens.active.cursor_right(u32(count))
	}
}

// Move the cursor to the left amount cells. If amount is 0, adjust it to 1.
pub fn (mut self Terminal) cursor_left(count_req int) {
	// Wrapping behavior depends on various terminal modes
	wrap_mode := if !self.modes.get(.wraparound) {
		WrapMode.none
	} else if self.modes.get(.reverse_wrap_extended) {
		WrapMode.reverse_extended
	} else if self.modes.get(.reverse_wrap) {
		WrapMode.reverse
	} else {
		WrapMode.none
	}

	mut count := if count_req < 1 { 1 } else { count_req }

	// If we are in no wrap mode, then we move the cursor left and exit
	// since this is the fastest and most typical path.
	if wrap_mode == .none {
		move_amt := if u16(count) < self.screens.active.cursor.x {
			u32(count)
		} else {
			u32(self.screens.active.cursor.x)
		}
		if move_amt > 0 {
			self.screens.active.cursor_left(move_amt)
		}
		self.screens.active.cursor.pending_wrap = false
		return
	}

	// If we have a pending wrap state and we are in either reverse wrap
	// modes then we decrement the amount we move by one to match xterm.
	if self.screens.active.cursor.pending_wrap {
		count -= 1
		self.screens.active.cursor.pending_wrap = false
	}

	// The margins we can move to.
	top := self.scrolling_region.top
	bottom := self.scrolling_region.bottom
	right_margin := self.scrolling_region.right
	left_margin := if self.screens.active.cursor.x < self.scrolling_region.left {
		u16(0)
	} else {
		self.scrolling_region.left
	}

	// Handle some edge cases when our cursor is already on the left margin.
	if self.screens.active.cursor.x == left_margin {
		match wrap_mode {
			// In reverse mode, if we're already before the top margin
			// then we just set our cursor to the top-left and we're done.
			.reverse {
				if self.screens.active.cursor.y <= top {
					self.screens.active.cursor_absolute(u32(left_margin), u32(top))
					return
				}
			}
			// Handled in while loop
			.reverse_extended {}
			// Handled above
			.none {} // unreachable
		}
	}

	for {
		// We can move at most to the left margin.
		max := int(self.screens.active.cursor.x) - int(left_margin)

		// We want to move at most the number of columns we have left
		// or our remaining count.
		amount := if max < count { max } else { count }
		count -= amount
		if amount > 0 {
			self.screens.active.cursor_left(u32(amount))
		}

		// If we have no more to move, then we're done.
		if count == 0 {
			break
		}

		// If we are at the top, then we are done.
		if self.screens.active.cursor.y == top {
			if wrap_mode != .reverse_extended {
				break
			}
			self.screens.active.cursor_absolute(u32(right_margin), u32(bottom))
			count -= 1
			continue
		}

		// UNDEFINED TERMINAL BEHAVIOR - wrap up to (0, 0) and stop
		if self.screens.active.cursor.y == 0 {
			break
		}

		// If our previous line is not wrapped then we are done.
		if wrap_mode != .reverse_extended {
			prev_idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y) - 1
			if prev_idx >= 0 && prev_idx < self.screens.active.pages.screen_rows.len {
				prev_row := self.screens.active.pages.screen_rows[prev_idx]
				if !prev_row.wrap {
					break
				}
			}
		}

		self.screens.active.cursor_absolute(u32(right_margin), u32(self.screens.active.cursor.y - 1))
		count -= 1
	}
}

enum WrapMode {
	none
	reverse
	reverse_extended
}

// ============================================================
// Cursor save/restore
// ============================================================

// Save cursor position and further state.
//
// The primary and alternate screen have distinct save state. One saved state
// is kept per screen (main / alternative). If for the current screen state
// was already saved it is overwritten.
pub fn (mut self Terminal) save_cursor() {
	self.screens.active.saved_cursor = SavedCursor{
		x: self.screens.active.cursor.x
		y: self.screens.active.cursor.y
		style: self.screens.active.cursor.style
		is_protected: self.screens.active.cursor.is_protected
		pending_wrap: self.screens.active.cursor.pending_wrap
		origin: self.modes.get(.origin)
		charset: self.screens.active.charset
	}
}

// Restore cursor position and other state.
//
// The primary and alternate screen have distinct save state.
// If no save was done before values are reset to their initial values.
pub fn (mut self Terminal) restore_cursor() {
	saved := self.screens.active.saved_cursor or {
		SavedCursor{
			x: 0
			y: 0
		}
	}

	// Set the style first because it can fail
	self.screens.active.cursor.style = saved.style
	self.screens.active.manual_style_update() or {
		self.screens.active.cursor.style = CellStyle{}
		self.screens.active.manual_style_update() or {}
	}

	self.screens.active.charset = saved.charset
	self.modes.set(.origin, saved.origin)
	self.screens.active.cursor.pending_wrap = saved.pending_wrap
	self.screens.active.cursor.is_protected = saved.is_protected

	x := if saved.x < self.cols { saved.x } else { self.cols - 1 }
	y := if saved.y < self.rows { saved.y } else { self.rows - 1 }
	self.screens.active.cursor_absolute(u32(x), u32(y))

	// Ensure our screen is consistent
	self.screens.active.assert_integrity()
}

// ============================================================
// Protection mode
// ============================================================

// Set the character protection mode for the terminal.
pub fn (mut self Terminal) set_protected_mode(mode ProtectedMode) {
	match mode {
		.off {
			self.screens.active.cursor.is_protected = false
			// screen.protected_mode is NEVER reset to ".off" because
			// logic such as eraseChars depends on knowing what the
			// _most recent_ mode was.
		}
		.iso {
			self.screens.active.cursor.is_protected = true
			self.screens.active.protected_mode = .iso
		}
		.dec {
			self.screens.active.cursor.is_protected = true
			self.screens.active.protected_mode = .dec
		}
	}
}

// ============================================================
// Semantic prompt
// ============================================================

// Returns true if the cursor is currently at a prompt. Another way to look
// at this is it returns false if the shell is currently outputting something.
// This requires shell integration (semantic prompt integration).
//
// If the shell integration doesn't exist, this will always return false.
pub fn (self &Terminal) cursor_is_at_prompt() bool {
	// If we're on the secondary screen, we're never at a prompt.
	if self.screens.active_key == .alternate {
		return false
	}

	// If our page row is a prompt then we're always at a prompt
	row_idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
	if row_idx < self.screens.active.pages.screen_rows.len {
		row := self.screens.active.pages.screen_rows[row_idx]
		if row.semantic_prompt != .unknown {
			return true
		}
	}

	// Otherwise, determine our cursor state
	return match self.screens.active.cursor.semantic_content {
		.input, .prompt { true }
		.output { false }
	}
}

// ============================================================
// Tab functions
// ============================================================

// Horizontal tab moves the cursor to the next tabstop.
pub fn (mut self Terminal) horizontal_tab() {
	for self.screens.active.cursor.x < self.scrolling_region.right {
		// Move the cursor right
		self.screens.active.cursor_right(1)

		// If the last cursor position was a tabstop we return.
		if self.tabstops.get(self.screens.active.cursor.x) {
			return
		}
	}
}

// Same as horizontal_tab but moves to the previous tabstop instead of the next.
pub fn (mut self Terminal) horizontal_tab_back() {
	// With origin mode enabled, our leftmost limit is the left margin.
	left_limit := if self.modes.get(.origin) {
		self.scrolling_region.left
	} else {
		u16(0)
	}

	for {
		// If we're already at the edge of the screen, then we're done.
		if self.screens.active.cursor.x <= left_limit {
			return
		}

		// Move the cursor left
		self.screens.active.cursor_left(1)
		if self.tabstops.get(self.screens.active.cursor.x) {
			return
		}
	}
}

// Clear tab stops.
pub fn (mut self Terminal) tab_clear(cmd TabClear) {
	match cmd {
		.current { self.tabstops.unset(self.screens.active.cursor.x) }
		.all { self.tabstops.reset(0) }
	}
}

pub enum TabClear {
	current
	all
}

// Set a tab stop on the current cursor.
pub fn (mut self Terminal) tab_set() {
	self.tabstops.set(self.screens.active.cursor.x)
}

// Reset tab stops to default interval.
pub fn (mut self Terminal) tab_reset() {
	self.tabstops.reset(terminal.tabstop_interval)
}

// ============================================================
// Index / Reverse Index
// ============================================================

// Move the cursor to the next line in the scrolling region, possibly scrolling.
//
// If the cursor is outside of the scrolling region: move the cursor one line
// down if it is not on the bottom-most line of the screen.
//
// If the cursor is inside the scrolling region:
//   If the cursor is on the bottom-most line of the scrolling region:
//     invoke scroll up with amount=1
//   If the cursor is not on the bottom-most line of the scrolling region:
//     move the cursor one line down
//
// This unsets the pending wrap state without wrapping.
pub fn (mut self Terminal) index() ! {
	mut screen := self.screens.active

	// Unset pending wrap state
	screen.cursor.pending_wrap = false

	// Outside of the scroll region we move the cursor one line down.
	if screen.cursor.y < self.scrolling_region.top
		|| screen.cursor.y > self.scrolling_region.bottom {
		// We only move down if we're not already at the bottom of the screen.
		if screen.cursor.y < self.rows - 1 {
			screen.cursor_down(1)
		}
		return
	}

	// If the cursor is inside the scrolling region and on the bottom-most
	// line, then we scroll up. If our scrolling region is the full screen
	// we create scrollback.
	if screen.cursor.y == self.scrolling_region.bottom
		&& screen.cursor.x >= self.scrolling_region.left
		&& screen.cursor.x <= self.scrolling_region.right {
		// If our scrolling region is at the top, we create scrollback.
		if self.scrolling_region.top == 0 && self.scrolling_region.left == 0
			&& self.scrolling_region.right == self.cols - 1 {
			screen.cursor_scroll_above()!
			return
		}

		// Slow path for left and right scrolling region margins.
		if self.scrolling_region.left != 0 || self.scrolling_region.right != self.cols - 1 {
			self.scroll_up(1)!
			return
		}

		// Use eraseRowBounded equivalent
		screen.cursor_scroll_above()!
		return
	}

	// Increase cursor by 1, maximum to bottom of scroll region
	if screen.cursor.y < self.scrolling_region.bottom {
		screen.cursor_down(1)
	}
}

// Move the cursor to the previous line in the scrolling region, possibly
// scrolling.
//
// If the cursor is outside of the scrolling region, move the cursor one
// line up if it is not on the top-most line of the screen.
//
// If the cursor is inside the scrolling region:
//   * If the cursor is on the top-most line: invoke scroll down with amount=1
//   * Otherwise: move the cursor one line up
pub fn (mut self Terminal) reverse_index() {
	if self.screens.active.cursor.y != self.scrolling_region.top
		|| self.screens.active.cursor.x < self.scrolling_region.left
		|| self.screens.active.cursor.x > self.scrolling_region.right {
		self.cursor_up(1)
		return
	}
	self.scroll_down(1)
}

// ============================================================
// Cursor positioning
// ============================================================

// Set Cursor Position. Move cursor to the position indicated
// by row and column (1-indexed). If column is 0, it is adjusted to 1.
// If column is greater than the right-most column it is adjusted to
// the right-most column. If row is 0, it is adjusted to 1. If row is
// greater than the bottom-most row it is adjusted to the bottom-most row.
pub fn (mut self Terminal) set_cursor_pos(row_req int, col_req int) {
	// If cursor origin mode is set the cursor row will be moved relative to
	// the top margin row.
	x_offset, y_offset, x_max, y_max := if self.modes.get(.origin) {
		self.scrolling_region.left, self.scrolling_region.top, self.scrolling_region.right + 1, self.scrolling_region.bottom + 1
	} else {
		u16(0), u16(0), self.cols, self.rows
	}

	// Unset pending wrap state
	self.screens.active.cursor.pending_wrap = false

	// Calculate our new x/y
	row := if row_req == 0 { 1 } else { row_req }
	col := if col_req == 0 { 1 } else { col_req }

	raw_x := int(col) + int(x_offset)
	raw_y := int(row) + int(y_offset)
	x := u16(if raw_x > int(x_max) { int(x_max) } else { raw_x }) - 1
	y := u16(if raw_y > int(y_max) { int(y_max) } else { raw_y }) - 1

	// Move cursor
	self.screens.active.cursor_absolute(u32(x), u32(y))
}

// ============================================================
// Margin setting
// ============================================================

// Set Top and Bottom Margins. Top and bottom are 1-indexed.
pub fn (mut self Terminal) set_top_and_bottom_margin(top_req int, bottom_req int) {
	top := if top_req < 1 { 1 } else { top_req }
	bottom_limit := if bottom_req == 0 { int(self.rows) } else { bottom_req }
	bottom := if bottom_limit > int(self.rows) { int(self.rows) } else { bottom_limit }
	if top >= bottom {
		return
	}
	self.scrolling_region.top = u16(top - 1)
	self.scrolling_region.bottom = u16(bottom - 1)
	self.set_cursor_pos(1, 1)
}

// DECSLRM - Set Left and Right Margin
pub fn (mut self Terminal) set_left_and_right_margin(left_req int, right_req int) {
	// We must have this mode enabled to do anything
	if !self.modes.get(.enable_left_and_right_margin) {
		return
	}

	left := if left_req < 1 { 1 } else { left_req }
	right_limit := if right_req == 0 { int(self.cols) } else { right_req }
	right := if right_limit > int(self.cols) { int(self.cols) } else { right_limit }
	if left >= right {
		return
	}
	self.scrolling_region.left = u16(left - 1)
	self.scrolling_region.right = u16(right - 1)
	self.set_cursor_pos(1, 1)
}

// ============================================================
// Scrolling
// ============================================================

// Scroll the text down by one row.
pub fn (mut self Terminal) scroll_down(count int) {
	// Preserve our x/y to restore.
	old_x := self.screens.active.cursor.x
	old_y := self.screens.active.cursor.y
	old_wrap := self.screens.active.cursor.pending_wrap

	// Move to the top of the scroll region
	self.screens.active.cursor_absolute(u32(self.scrolling_region.left), u32(self.scrolling_region.top))
	self.insert_lines(count)

	// Restore cursor
	self.screens.active.cursor_absolute(u32(old_x), u32(old_y))
	self.screens.active.cursor.pending_wrap = old_wrap
}

// Removes amount lines from the top of the scroll region. The remaining lines
// to the bottom margin are shifted up and space from the bottom margin up
// is filled with empty lines.
//
// The new lines are created according to the current SGR state.
//
// Does not change the (absolute) cursor position.
pub fn (mut self Terminal) scroll_up(count int) ! {
	// Preserve our x/y to restore.
	old_x := self.screens.active.cursor.x
	old_y := self.screens.active.cursor.y
	old_wrap := self.screens.active.cursor.pending_wrap

	// If our scroll region is at the top and we have no left/right
	// margins then we move the scrolled out text into the scrollback.
	if self.scrolling_region.top == 0 && self.scrolling_region.left == 0
		&& self.scrolling_region.right == self.cols - 1 {
		// Clamp count to the scroll region height.
		region_height := int(self.scrolling_region.bottom) + 1
		adjusted_count := if count < region_height { count } else { region_height }

		// Move cursor to bottom and scroll
		self.screens.active.cursor_absolute(0, u32(self.scrolling_region.bottom))
		for _ in 0 .. adjusted_count {
			self.screens.active.cursor_scroll_above()!
		}

		// Restore cursor
		self.screens.active.cursor_absolute(u32(old_x), u32(old_y))
		self.screens.active.cursor.pending_wrap = old_wrap
		return
	}

	// Move to the top of the scroll region
	self.screens.active.cursor_absolute(u32(self.scrolling_region.left), u32(self.scrolling_region.top))
	self.delete_lines(count)

	// Restore cursor
	self.screens.active.cursor_absolute(u32(old_x), u32(old_y))
	self.screens.active.cursor.pending_wrap = old_wrap
}

// Scroll the viewport of the terminal grid.
pub fn (mut self Terminal) scroll_viewport(behavior ScrollViewport, delta int) ! {
	match behavior {
		.top { self.screens.active.scroll(.top) }
		.bottom { self.screens.active.scroll(.active) }
		.delta {
			// XTODO
			// Full delta scroll needs PageList.scroll with delta_row support.
			// This simplified version just scrolls active.
			self.screens.active.scroll(.active)
		}
	}
}

// ============================================================
// Insert / Delete lines
// ============================================================

// Insert amount lines at the current cursor row. The contents of the line
// at the current cursor row and below (to the bottom-most line in the
// scrolling region) are shifted down by amount lines.
//
// This unsets the pending wrap state without wrapping. If the current cursor
// position is outside of the current scroll region it does nothing.
//
// Moves the cursor to the left margin.
pub fn (mut self Terminal) insert_lines(count int) {
	// Rare, but happens
	if count == 0 {
		return
	}

	// If the cursor is outside the scroll region we do nothing.
	if self.screens.active.cursor.y < self.scrolling_region.top
		|| self.screens.active.cursor.y > self.scrolling_region.bottom
		|| self.screens.active.cursor.x < self.scrolling_region.left
		|| self.screens.active.cursor.x > self.scrolling_region.right {
		return
	}

	start_y := self.screens.active.cursor.y

	// Remaining rows from our cursor to the bottom of the scroll region.
	rem := int(self.scrolling_region.bottom) - int(self.screens.active.cursor.y) + 1
	adjusted_count := if count < rem { count } else { rem }

	// Check if we have left/right scroll margins
	left_right := self.scrolling_region.left > 0 || self.scrolling_region.right < self.cols - 1

	// Shift rows down
	active_start := self.screens.active.pages.active_start
	for y := int(self.scrolling_region.bottom); y >= int(start_y) + adjusted_count; y-- {
		src_y := y - adjusted_count
		src_idx := active_start + src_y
		dst_idx := active_start + y

		if src_idx < self.screens.active.pages.screen_rows.len
			&& dst_idx < self.screens.active.pages.screen_rows.len {
			if !left_right {
				unsafe {
					// Full row swap
					mut dst_row := &self.screens.active.pages.screen_rows[dst_idx]
					src_row := self.screens.active.pages.screen_rows[src_idx]
					dst_row.cells = src_row.cells.clone()
					dst_row.wrap = src_row.wrap
					dst_row.wrap_continuation = src_row.wrap_continuation
					dst_row.styled = src_row.styled
					dst_row.grapheme = src_row.grapheme
					dst_row.hyperlink = src_row.hyperlink
					dst_row.dirty = true
				}
			} else {
				// Left/right margins: only copy cells within the margin range
				unsafe {
					mut dst_row := &self.screens.active.pages.screen_rows[dst_idx]
					src_row := self.screens.active.pages.screen_rows[src_idx]
					for x in int(self.scrolling_region.left) .. int(self.scrolling_region.right) + 1 {
						if x < src_row.cells.len && x < dst_row.cells.len {
							dst_row.cells[x] = src_row.cells[x]
						}
					}
					dst_row.dirty = true
				}
			}
		}
	}

	// Clear the inserted rows
	for y in int(start_y) .. int(start_y) + adjusted_count {
		idx := active_start + y
		if idx < self.screens.active.pages.screen_rows.len {
			if !left_right {
				self.screens.active.clear_active_row(u32(y))
			} else {
				self.screens.active.clear_cells(idx, int(self.scrolling_region.left),
					int(self.scrolling_region.right) + 1)
			}
		}
	}

	// Return cursor to the left margin
	self.screens.active.cursor_absolute(u32(self.scrolling_region.left), u32(start_y))
	self.screens.active.cursor.pending_wrap = false
}

// Removes amount lines from the current cursor row down. The remaining lines
// to the bottom margin are shifted up and space from the bottom margin up is
// filled with empty lines.
//
// Moves the cursor to the left margin.
pub fn (mut self Terminal) delete_lines(count int) {
	// Rare, but happens
	if count == 0 {
		return
	}

	// If the cursor is outside the scroll region we do nothing.
	if self.screens.active.cursor.y < self.scrolling_region.top
		|| self.screens.active.cursor.y > self.scrolling_region.bottom
		|| self.screens.active.cursor.x < self.scrolling_region.left
		|| self.screens.active.cursor.x > self.scrolling_region.right {
		return
	}

	start_y := self.screens.active.cursor.y

	// Remaining rows from our cursor to the bottom of the scroll region.
	rem := int(self.scrolling_region.bottom) - int(self.screens.active.cursor.y) + 1
	adjusted_count := if count < rem { count } else { rem }

	// Check if we have left/right scroll margins
	left_right := self.scrolling_region.left > 0 || self.scrolling_region.right < self.cols - 1

	active_start := self.screens.active.pages.active_start

	// Shift rows up
	for y in int(start_y) .. int(self.scrolling_region.bottom) - adjusted_count + 1 {
		src_y := y + adjusted_count
		src_idx := active_start + src_y
		dst_idx := active_start + y

		if src_idx < self.screens.active.pages.screen_rows.len
			&& dst_idx < self.screens.active.pages.screen_rows.len {
			if !left_right {
				unsafe {
					mut dst_row := &self.screens.active.pages.screen_rows[dst_idx]
					src_row := self.screens.active.pages.screen_rows[src_idx]
					dst_row.cells = src_row.cells.clone()
					dst_row.wrap = src_row.wrap
					dst_row.wrap_continuation = src_row.wrap_continuation
					dst_row.styled = src_row.styled
					dst_row.grapheme = src_row.grapheme
					dst_row.hyperlink = src_row.hyperlink
					dst_row.dirty = true
				}
			} else {
				unsafe {
					mut dst_row := &self.screens.active.pages.screen_rows[dst_idx]
					src_row := self.screens.active.pages.screen_rows[src_idx]
					for x in int(self.scrolling_region.left) .. int(self.scrolling_region.right) + 1 {
						if x < src_row.cells.len && x < dst_row.cells.len {
							dst_row.cells[x] = src_row.cells[x]
						}
					}
					dst_row.dirty = true
				}
			}
		}
	}

	// Clear the vacated rows at the bottom
	for y in int(self.scrolling_region.bottom) - adjusted_count + 1 .. int(self.scrolling_region.bottom) + 1 {
		idx := active_start + y
		if idx < self.screens.active.pages.screen_rows.len {
			if !left_right {
				self.screens.active.clear_active_row(u32(y))
			} else {
				self.screens.active.clear_cells(idx, int(self.scrolling_region.left),
					int(self.scrolling_region.right) + 1)
			}
		}
	}

	// Return cursor to the left margin
	self.screens.active.cursor_absolute(u32(self.scrolling_region.left), u32(start_y))
	self.screens.active.cursor.pending_wrap = false
}

// ============================================================
// Insert / Delete / Erase characters
// ============================================================

// Inserts spaces at current cursor position moving existing cell contents
// to the right. The contents of the count right-most columns in the scroll
// region are lost. The cursor position is not changed.
//
// This unsets the pending wrap state without wrapping.
pub fn (mut self Terminal) insert_blanks(count int) {
	// Unset pending wrap state without wrapping.
	self.screens.active.cursor.pending_wrap = false

	// If our cursor is outside the margins then do nothing.
	if self.screens.active.cursor.x < self.scrolling_region.left
		|| self.screens.active.cursor.x > self.scrolling_region.right {
		return
	}

	// Remaining cols from our cursor to the right margin.
	rem := int(self.scrolling_region.right) - int(self.screens.active.cursor.x) + 1
	adjusted_count := if count < rem { count } else { rem }
	scroll_amount := rem - adjusted_count

	row_idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
	if row_idx >= self.screens.active.pages.screen_rows.len {
		return
	}

	cursor_x := int(self.screens.active.cursor.x)
	unsafe {
		mut row := &self.screens.active.pages.screen_rows[row_idx]

		// Shift cells right
		if scroll_amount > 0 {
			for x := cursor_x + scroll_amount - 1; x >= cursor_x; x-- {
				src_x := x
				dst_x := x + adjusted_count
				if src_x < row.cells.len && dst_x < row.cells.len {
					row.cells[dst_x] = row.cells[src_x]
				}
			}
		}

		// Insert blanks
		for x in cursor_x .. cursor_x + adjusted_count {
			if x < row.cells.len {
				row.cells[x] = CellData{
					style_id: self.screens.active.cursor.style_id
				}
			}
		}

		row.dirty = true
	}
}

// Removes amount characters from the current cursor position to the right.
// The remaining characters are shifted to the left and space from the right
// margin is filled with spaces.
//
// Does not change the cursor position.
pub fn (mut self Terminal) delete_chars(count_req int) {
	if count_req == 0 {
		return
	}

	// If our cursor is outside the margins then do nothing.
	if self.screens.active.cursor.x < self.scrolling_region.left
		|| self.screens.active.cursor.x > self.scrolling_region.right {
		return
	}

	// Remaining cols from our cursor to the right margin.
	rem := int(self.scrolling_region.right) - int(self.screens.active.cursor.x) + 1
	count := if count_req < rem { count_req } else { rem }

	row_idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
	if row_idx >= self.screens.active.pages.screen_rows.len {
		return
	}

	cursor_x := int(self.screens.active.cursor.x)
	scroll_amount := rem - count
	unsafe {
		mut row := &self.screens.active.pages.screen_rows[row_idx]

		// Shift cells left
		if scroll_amount > 0 {
			for x in cursor_x .. cursor_x + scroll_amount {
				src_x := x + count
				if x < row.cells.len && src_x < row.cells.len {
					row.cells[x] = row.cells[src_x]
				}
			}
		}

		// Clear the vacated cells at the right
		for x in cursor_x + scroll_amount .. cursor_x + rem {
			if x < row.cells.len {
				row.cells[x] = CellData{
					style_id: self.screens.active.cursor.style_id
				}
			}
		}

		// Row's soft-wrap is always reset
		row.wrap = false
		row.dirty = true
	}
}

// Erase characters at the cursor position.
pub fn (mut self Terminal) erase_chars(count_req int) {
	remaining := int(self.cols) - int(self.screens.active.cursor.x)
	count_min := if count_req < 1 { 1 } else { count_req }
	count := if count_min < remaining { count_min } else { remaining }

	// Reset our row's soft-wrap.
	self.screens.active.cursor_reset_wrap()
	self.screens.active.cursor_mark_dirty()

	row_idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
	cursor_x := int(self.screens.active.cursor.x)

	if row_idx >= self.screens.active.pages.screen_rows.len {
		return
	}

	// If we never had a protection mode, then we can go with the fast path.
	if self.screens.active.protected_mode != .iso {
		self.screens.active.clear_cells(row_idx, cursor_x, cursor_x + count)
		return
	}

	// Respect protected cells
	unsafe {
		mut row := &self.screens.active.pages.screen_rows[row_idx]
		for x in cursor_x .. cursor_x + count {
			if x < row.cells.len && !row.cells[x].is_protected {
				row.cells[x] = CellData{
					style_id: self.screens.active.cursor.style_id
				}
			}
		}
		row.dirty = true
	}
}

// ============================================================
// Erase line / display
// ============================================================

// Erase the line.
pub fn (mut self Terminal) erase_line(mode EraseLine, protected_req bool) {
	row_idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
	cursor_x := int(self.screens.active.cursor.x)

	start, end := match mode {
		.right {
			// Reset our row's soft-wrap.
			self.screens.active.cursor_reset_wrap()
			cursor_x, int(self.cols)
		}
		.left {
			0, cursor_x + 1
		}
		.complete {
			0, int(self.cols)
		}
	}

	// All modes will clear the pending wrap state
	self.screens.active.cursor.pending_wrap = false
	self.screens.active.cursor_mark_dirty()

	// We respect protected attributes if explicitly requested or if our
	// last protected mode was ISO.
	is_protected := self.screens.active.protected_mode == .iso || protected_req

	if !is_protected {
		self.screens.active.clear_cells(row_idx, start, end)
		return
	}

	// Protected mode: only clear unprotected cells
	if row_idx < self.screens.active.pages.screen_rows.len {
		unsafe {
			mut row := &self.screens.active.pages.screen_rows[row_idx]
			for x in start .. end {
				if x < row.cells.len && !row.cells[x].is_protected {
					row.cells[x] = CellData{
						style_id: self.screens.active.cursor.style_id
					}
				}
			}
			row.dirty = true
		}
	}
}

pub enum EraseLine {
	right
	left
	complete
}

// Erase the display.
pub fn (mut self Terminal) erase_display(mode EraseDisplay, protected_req bool) {
	// We respect protected attributes if explicitly requested or if our
	// last protected mode was ISO.
	is_protected := self.screens.active.protected_mode == .iso || protected_req

	match mode {
		.scroll_complete {
			self.screens.active.scroll_clear() or {
				self.erase_display(.complete, protected_req)
				return
			}
			// Unsets pending wrap state
			self.screens.active.cursor.pending_wrap = false
		}
		.complete {
			// If we're on the primary screen and our last non-empty row is
			// a prompt, then we do a scroll_complete instead. (Heuristic for ^L)
			if self.screens.active_key == .primary {
				// Check for prompt at bottom of active area
				at_prompt := self.check_at_prompt_for_clear()
				if at_prompt {
					self.screens.active.scroll_clear() or {}
				}
			}

			// All active area
			self.screens.active.clear_rows(.active, ?PointTag(none), is_protected)
			self.screens.active.cursor.pending_wrap = false
			self.flags.dirty.clear = true
		}
		.below {
			// All lines to the right (including the cursor)
			self.erase_line(.right, protected_req)

			// All lines below
			if self.screens.active.cursor.y + 1 < self.rows {
				self.screens.active.clear_rows_range(
					int(self.screens.active.cursor.y) + 1,
					int(self.rows),
					is_protected,
				)
			}
		}
		.above {
			// Erase to the left (including the cursor)
			self.erase_line(.left, protected_req)

			// All lines above
			if self.screens.active.cursor.y > 0 {
				self.screens.active.clear_rows_range(0, int(self.screens.active.cursor.y),
					is_protected)
			}
		}
		.scrollback {
			self.screens.active.erase_rows(.history, ?PointTag(none))
		}
	}
}

pub enum EraseDisplay {
	scroll_complete
	complete
	below
	above
	scrollback
}

fn (self &Terminal) check_at_prompt_for_clear() bool {
	// Go from the bottom of the active up and see if we're at a prompt.
	active_start := self.screens.active.pages.active_start
	for y := int(self.rows) - 1; y >= 0; y-- {
		idx := active_start + y
		if idx >= self.screens.active.pages.screen_rows.len {
			continue
		}
		row := self.screens.active.pages.screen_rows[idx]
		match row.semantic_prompt {
			.prompt, .prompt_continuation { return true }
			.unknown { return false }
			else { continue }
		}
	}
	return false
}

// ============================================================
// DECALN - Screen Alignment Pattern
// ============================================================

// Resets all margins and fills the whole screen with the character 'E'.
// Sets the cursor to the top left corner.
pub fn (mut self Terminal) decaln() ! {
	// Reset margins, also sets cursor to top-left
	self.scrolling_region = ScrollingRegion{
		top: 0
		bottom: self.rows - 1
		left: 0
		right: self.cols - 1
	}

	// Origin mode is disabled
	self.modes.set(.origin, false)

	// Move our cursor to the top-left
	self.set_cursor_pos(1, 1)

	// Clear and fill with Es
	active_start := self.screens.active.pages.active_start
	for y in 0 .. int(self.rows) {
		idx := active_start + y
		if idx < self.screens.active.pages.screen_rows.len {
			unsafe {
				mut row := &self.screens.active.pages.screen_rows[idx]
				for x in 0 .. int(self.cols) {
					if x < row.cells.len {
						row.cells[x] = CellData{
							codepoint: u32(`E`)
							content_tag: .codepoint
							style_id: self.screens.active.cursor.style_id
							is_protected: false // DECALN does not respect protected state
						}
					}
				}
				if self.screens.active.cursor.style_id != terminal.default_style_id {
					row.styled = true
				}
				row.dirty = true
			}
		}
	}

	// Reset the cursor to the top-left
	self.set_cursor_pos(1, 1)
}

// ============================================================
// Kitty graphics (stub)
// ============================================================

// Execute a kitty graphics command.
pub fn (mut self Terminal) kitty_graphics(cmd voidptr) ?voidptr {
	// XTODO
	// Requires kitty.graphics module with Command/Response types
	// and the full execute() function.
	return none
}

// ============================================================
// Style attributes
// ============================================================

// Set a style attribute.
pub fn (mut self Terminal) set_attribute(attr SgrAttribute) ! {
	self.screens.active.set_attribute(attr)!
}

// Print the active attributes as a string. This is used to respond to DECRQSS.
pub fn (mut self Terminal) print_attributes() !string {
	mut result := strings.new_builder(64)

	// The SGR response always starts with a 0.
	result.write_string('0')

	pen := self.screens.active.cursor.style

	if pen.flags.bold {
		result.write_string(';1')
	}
	if pen.flags.faint {
		result.write_string(';2')
	}
	if pen.flags.italic {
		result.write_string(';3')
	}
	if pen.flags.underline != .none {
		result.write_string(';4')
	}
	if pen.flags.blink {
		result.write_string(';5')
	}
	if pen.flags.inverse {
		result.write_string(';7')
	}
	if pen.flags.invisible {
		result.write_string(';8')
	}
	if pen.flags.strikethrough {
		result.write_string(';9')
	}

	// Foreground and background color formatting would go here
	// XTODO: full color attribute printing needs style color type matching

	return result.str()
}

// ============================================================
// DECCOLM
// ============================================================

// DECCOLM changes the terminal width between 80 and 132 columns.
// This will do NOTHING unless enable_mode_3 has been set.
pub fn (mut self Terminal) deccolm(mode DeccolmMode) ! {
	// If DEC mode 40 isn't enabled, then this is ignored.
	if !self.modes.get(.enable_mode_3) {
		self.modes.set(.column_132, false)
		return
	}

	// Enable it
	self.modes.set(.column_132, mode == .cols_132)

	// Resize to the requested size
	new_cols := match mode {
		.cols_132 { u16(132) }
		.cols_80 { u16(80) }
	}
	self.resize(new_cols, self.rows)!

	// Erase our display and move our cursor.
	self.erase_display(.complete, false)
	self.set_cursor_pos(1, 1)
}

// ============================================================
// Resize
// ============================================================

// Resize the underlying terminal.
pub fn (mut self Terminal) resize(cols u16, rows u16) ! {
	// If our cols/rows didn't change then we're done
	if self.cols == cols && self.rows == rows {
		return
	}

	// Resize our tabstops
	if self.cols != cols {
		self.tabstops.deinit()
		self.tabstops = Tabstops.init(int(cols), 8)!
	}

	// Resize primary screen
	self.screens.primary.resize(ScreenResize{
		cols: u32(cols)
		rows: u32(rows)
		reflow: self.modes.get(.wraparound)
	})!

	// Alternate screen, if it exists, doesn't reflow
	if _ := self.screens.alternate {
		mut alt := self.screens.alternate or { return }
		alt.resize(ScreenResize{
			cols: u32(cols)
			rows: u32(rows)
			reflow: false
		})!
	}

	// Whenever we resize we just mark it as a screen clear
	self.flags.dirty.clear = true

	// Set our size
	self.cols = cols
	self.rows = rows

	// Reset the scrolling region
	self.scrolling_region = ScrollingRegion{
		top: 0
		bottom: rows - 1
		left: 0
		right: cols - 1
	}
}

// ============================================================
// PWD
// ============================================================

// Set the pwd for the terminal.
pub fn (mut self Terminal) set_pwd(pwd_str string) ! {
	self.pwd = pwd_str
}

// Returns the pwd for the terminal, if any.
pub fn (self &Terminal) get_pwd() ?string {
	if self.pwd.len == 0 {
		return none
	}
	return self.pwd
}

// ============================================================
// Screen switching
// ============================================================

// Switch to the given screen type (alternate or primary).
//
// This does NOT handle behaviors such as clearing the screen,
// copying the cursor, etc.
pub fn (mut self Terminal) switch_screen(key ScreenKey) !&Screen {
	// If we're already on the requested screen we do nothing.
	if self.screens.active_key == key {
		return unsafe { &Screen(nil) }
	}
	mut old := self.screens.active

	// We always end hyperlink state when switching screens.
	old.end_hyperlink()

	// Switch the screens
	match key {
		.alternate {
			if _ := self.screens.alternate {
				// Already exists
			} else {
				// Create alternate screen (no scrollback)
				self.screens.alternate = Screen.init(u32(self.cols), u32(self.rows), 0)
			}
		}
		.primary {}
	}

	// Switch and bring charset state
	self.screens.switch_to(key)
	self.screens.active.charset = old.charset

	// Clear selection on new screen
	self.screens.active.clear_selection()

	// Mark terminal as dirty
	self.flags.dirty.clear = true

	return old
}

// Switch screen via a mode switch (e.g. mode 47, 1047, 1049).
pub fn (mut self Terminal) switch_screen_mode(mode SwitchScreenMode, enabled bool) ! {
	match mode {
		.mode_47 {}
		// If we're disabling 1047 and we're on alt screen then
		// we clear the screen.
		.mode_1047 {
			if !enabled && self.screens.active_key == .alternate {
				self.erase_display(.complete, false)
			}
		}
		// 1049 unconditionally saves the cursor on enabling.
		.mode_1049 {
			if enabled {
				self.save_cursor()
			}
		}
	}

	// Switch screens
	to := if enabled { ScreenKey.alternate } else { ScreenKey.primary }
	old_ := self.switch_screen(to)!

	match mode {
		// For these modes, we need to copy the cursor.
		.mode_47, .mode_1047 {
			// cursor is implicitly in the right place after switch
			_ = old_
		}
		// Mode 1049 restores cursor on the primary screen when disabled.
		.mode_1049 {
			if enabled {
				self.erase_display(.complete, false)
			} else {
				self.restore_cursor()
			}
		}
	}
}

// ============================================================
// Plain string output
// ============================================================

// Return the current string value of the terminal. Newlines are
// encoded as "\n". This omits any formatting such as fg/bg.
pub fn (mut self Terminal) plain_string() !string {
	return self.screens.active.dump_string_alloc(.active)!
}

// Same as plain_string, but respects row wrap state when building the string.
pub fn (mut self Terminal) plain_string_unwrapped() !string {
	return self.screens.active.dump_string_alloc_unwrapped(.active)!
}

// ============================================================
// Full reset
// ============================================================

// Full reset.
//
// This will attempt to free the existing screen memory but if that fails
// this will reuse the existing memory. In the latter case, memory may
// be wasted (since its unused) but it isn't leaked.
pub fn (mut self Terminal) full_reset() {
	// Ensure we're back on primary screen
	self.screens.switch_to(.primary)
	self.screens.remove(.alternate)

	// Reset our screens
	self.screens.active.reset()

	// Reset our basic state
	self.modes.reset()
	self.flags = TerminalFlags{}
	self.tabstops.reset(terminal.tabstop_interval)
	self.previous_char = none
	self.pwd = ''
	self.status_display = .main
	self.scrolling_region = ScrollingRegion{
		top: 0
		bottom: self.rows - 1
		left: 0
		right: self.cols - 1
	}

	// Always mark dirty so we redraw everything
	self.flags.dirty.clear = true
}

// ============================================================
// Testing helpers
// ============================================================

// Returns true if the point is dirty, used for testing.
pub fn (self &Terminal) is_dirty(x u32, y u32) bool {
	idx := self.screens.active.pages.active_start + int(y)
	if idx < self.screens.active.pages.screen_rows.len {
		row := self.screens.active.pages.screen_rows[idx]
		return row.dirty
	}
	return false
}

// Clear all dirty bits. Testing only.
pub fn (mut self Terminal) clear_dirty() {
	for mut row in self.screens.active.pages.screen_rows {
		row.dirty = false
	}
}

// Helper to clear rows in a range (active-area-relative y coordinates).
fn (mut self Screen) clear_rows_range(start_y int, end_y int, is_protected bool) {
	active_start := self.pages.active_start
	for y in start_y .. end_y {
		idx := active_start + y
		if idx >= self.pages.screen_rows.len {
			break
		}
		unsafe {
			mut row := &self.pages.screen_rows[idx]
			if is_protected {
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
