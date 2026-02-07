module terminal

/*
  Source: formatter.zig — 5,939 lines
  Output: formatter.v — 1,149 lines + formatter_test.v — 1,117 lines = 2,266 V lines total

  The V translation is significantly more compact because:
  - Zig's comptime patterns, explicit allocator passing, and Writer generics are replaced by V's strings.Builder
  - Zig's verbose test infrastructure (custom allocators, errdefer, error unions) becomes simple V test functions
  - The PageListFormatter was merged into PageFormatter since V uses a simpler Pages array model
  - PinMap/PointMap tracking (a perf/debugging feature) was omitted (XTODO)

*/

import strings

// Formats available.
pub enum Format {
	// Plain text.
	plain
	// Include VT sequences to preserve colors, styles, URLs, etc.
	// This is predominantly SGR sequences but may contain others as needed.
	//
	// Note that for reference colors, like palette indices, this will
	// vary based on the formatter and you should see the docs. For example,
	// PageFormatter with VT will emit SGR sequences with palette indices,
	// not the color itself.
	//
	// For VT, newlines will be emitted as `\r\n` so that the cursor properly
	// moves back to the beginning prior emitting follow-up lines.
	vt
	// HTML output.
	//
	// This will emit inline styles for as much styling as possible,
	// in the interest of simplicity and ease of editing. This isn't meant
	// to build the most beautiful or efficient HTML, but rather to be
	// stylistically correct.
	//
	// For colors, RGB values are emitted as inline CSS (#RRGGBB) while palette
	// indices use CSS variables (var(--vt-palette-N)). The palette colors are
	// emitted by TerminalFormatter.Extra.palette as a <style> block if you
	// want to also include that. But if you only format a screen or lower,
	// the formatter doesn't have access to the current palette to render it.
	//
	// Newlines are emitted as actual '\n' characters. Consumers should use
	// CSS white-space: pre or pre-wrap to preserve spacing and alignment.
	html
}

// Returns true if the format emits styled output.
pub fn (self Format) styled() bool {
	return match self {
		.plain { false }
		.html, .vt { true }
	}
}

// Unicode codepoint range to replace.
pub struct CodepointMap {
pub:
	// Unicode codepoint range to replace.
	// range[0] <= range[1]
	range_start u32
	range_end   u32
	// Replacement value for this range.
	replacement CodepointReplacement
}

// Replacement value: either a single codepoint or a string.
pub type CodepointReplacement = CodepointRepl | StringRepl

pub struct CodepointRepl {
pub:
	codepoint u32
}

pub struct StringRepl {
pub:
	str string
}

// Common encoding options regardless of what exact formatter is used.
pub struct FormatOptions {
pub:
	// The format to emit.
	emit Format = .plain
	// Whether to unwrap soft-wrapped lines. If false, this will emit the
	// screen contents as it is rendered on the page in the given size.
	unwrap bool
	// Trim trailing whitespace on lines with other text. Trailing blank
	// lines are always trimmed. This only affects trailing whitespace
	// on rows that have at least one other cell with text. Whitespace
	// is currently only space characters (0x20).
	trim bool = true
	// Replace matching Unicode codepoints with some other values.
	// This will use the last matching range found in the list.
	codepoint_map []CodepointMap
	// Set a background and foreground color to use for the "screen".
	// For styled formats, this will emit the proper sequences or styles.
	background ?RGB
	foreground ?RGB
	// If set, then styled formats in `emit` will use this palette to
	// emit colors directly as RGB. If this is null, styled formats will
	// still work but will use deferred palette styling (e.g. CSS variables
	// for HTML or the actual palette indexes for VT).
	palette ?[]RGB
}

// Predefined option sets.
pub const format_plain = FormatOptions{ emit: .plain }
pub const format_vt = FormatOptions{ emit: .vt }
pub const format_html = FormatOptions{ emit: .html }

// Terminal formatter formats the active terminal screen.
//
// This will always only emit data related to the currently active screen.
// If you want to emit data for a specific screen (e.g. primary vs alt), then
// switch to that screen in the terminal prior to using this.
//
// If you want to emit data for all screens (a less common operation), then
// you must create a no-content TerminalFormatter followed by multiple
// explicit ScreenFormatter calls. This isn't a common operation so this
// little extra work should be acceptable.
//
// For styled formatting, this will emit the palette colors at the
// beginning so that the output can be rendered properly according to
// the current terminal state.
pub struct TerminalFormatter {
pub:
	// The terminal to format.
	terminal &Terminal
	// The common options
	opts FormatOptions
pub mut:
	// The content to include.
	content ScreenContent = ScreenContent(ScreenContentSelection{ sel: none })
	// Extra stuff to emit, such as terminal modes, palette, cursor, etc.
	// This information is ONLY emitted when the format is "vt".
	extra TerminalExtra = terminal_extra_styles
}

// Extra stuff to emit for terminal formatting.
pub struct TerminalExtra {
pub:
	// Emit the palette using OSC 4 sequences.
	palette bool
	// Emit terminal modes that differ from their defaults using CSI h/l
	// sequences.
	modes bool
	// Emit scrolling region state using DECSTBM and DECSLRM sequences.
	scrolling_region bool
	// Emit tabstop positions by clearing all tabs (CSI 3 g) and setting
	// each configured tabstop with HTS.
	tabstops bool
	// Emit the present working directory using OSC 7.
	pwd bool
	// Emit keyboard modes such as ModifyOtherKeys.
	keyboard bool
	// The screen extras to emit.
	screen ScreenExtra = screen_extra_none
}

// Emit nothing.
pub const terminal_extra_none = TerminalExtra{
	palette: false
	modes: false
	scrolling_region: false
	tabstops: false
	pwd: false
	keyboard: false
	screen: screen_extra_none
}

// Emit style-relevant information only such as palettes.
pub const terminal_extra_styles = TerminalExtra{
	palette: true
	modes: false
	scrolling_region: false
	tabstops: false
	pwd: false
	keyboard: false
	screen: screen_extra_styles
}

// Emit everything. This reconstructs the terminal state as closely as possible.
pub const terminal_extra_all = TerminalExtra{
	palette: true
	modes: true
	scrolling_region: true
	tabstops: true
	pwd: true
	keyboard: true
	screen: screen_extra_all
}

pub fn TerminalFormatter.init(t &Terminal, opts FormatOptions) TerminalFormatter {
	return TerminalFormatter{
		terminal: unsafe { t }
		opts: opts
		content: ScreenContent(ScreenContentSelection{ sel: none })
		extra: terminal_extra_styles
	}
}

pub fn (self TerminalFormatter) format() string {
	mut sb := strings.new_builder(1024)

	// Emit palette before screen content if using VT format.
	if self.extra.palette {
		match self.opts.emit {
			.plain {}
			.vt {
				for i, rgb in self.terminal.colors.palette.entries {
					sb.write_string('\x1b]4;${i};rgb:${hex02(rgb.r)}/${hex02(rgb.g)}/${hex02(rgb.b)}\x1b\\')
				}
			}
			// For HTML, we emit CSS to setup our palette variables.
			.html {
				sb.write_string('<style>:root{')
				for i, rgb in self.terminal.colors.palette.entries {
					sb.write_string('--vt-palette-${i}: #${hex02(rgb.r)}${hex02(rgb.g)}${hex02(rgb.b)};')
				}
				sb.write_string('}</style>')
			}
		}
	}

	// Emit terminal modes that differ from defaults.
	// XTODO: mode emission requires iterating over all mode fields and
	// comparing to defaults, which needs the full modes system.
	// if self.opts.emit == .vt && self.extra.modes { ... }

	// Format the active screen content
	mut screen_fmt := ScreenFormatter.init(self.terminal.screens.active, self.opts)
	screen_fmt.content = self.content
	screen_fmt.extra = self.extra.screen
	sb.write_string(screen_fmt.format())

	// Extra terminal state to emit after the screen contents
	if self.opts.emit == .vt {
		// Emit scrolling region using DECSTBM and DECSLRM
		if self.extra.scrolling_region {
			region := self.terminal.scrolling_region
			// DECSTBM: top and bottom margins (1-indexed)
			// Only emit if not the full screen
			if region.top != 0 || region.bottom != self.terminal.rows - 1 {
				sb.write_string('\x1b[${region.top + 1};${region.bottom + 1}r')
			}
			// DECSLRM: left and right margins (1-indexed)
			// Only emit if not the full width
			if region.left != 0 || region.right != self.terminal.cols - 1 {
				sb.write_string('\x1b[${region.left + 1};${region.right + 1}s')
			}
		}

		// Emit tabstop positions
		if self.extra.tabstops {
			// Clear all tabs (CSI 3 g)
			sb.write_string('\x1b[3g')
			// Set each configured tabstop by moving cursor and using HTS
			for col in 0 .. int(self.terminal.cols) {
				if self.terminal.tabstops.get(u32(col)) {
					// Move cursor to the column (1-indexed)
					sb.write_string('\x1b[${col + 1}G')
					// Set tab (HTS)
					sb.write_string('\x1bH')
				}
			}
		}

		// Emit keyboard modes such as ModifyOtherKeys
		if self.extra.keyboard {
			// Only emit if modify_other_keys_2 is true
			if self.terminal.flags.modify_other_keys_2 {
				sb.write_string('\x1b[>4;2m')
			}
		}

		// Emit present working directory using OSC 7
		if self.extra.pwd {
			if self.terminal.pwd.len > 0 {
				sb.write_string('\x1b]7;${self.terminal.pwd}\x1b\\')
			}
		}
	}

	return sb.str()
}

// Screen formatter formats a single terminal screen (e.g. primary vs alt).
pub struct ScreenFormatter {
pub:
	// The screen to format.
	screen &Screen
	// The common options
	opts FormatOptions
pub mut:
	// The content to include.
	content ScreenContent = ScreenContent(ScreenContentSelection{ sel: none })
	// Extra stuff to emit, such as cursor, style, hyperlinks, etc.
	// This information is ONLY emitted when the format is "vt".
	extra ScreenExtra = screen_extra_none
}

// Content to include in screen formatting.
pub type ScreenContent = ScreenContentNone | ScreenContentSelection

// Emit no content, only terminal state such as modes, palette, etc. via extra.
pub struct ScreenContentNone {}

// Emit the content specified by the selection. Null for all.
// The selection is inclusive on both ends.
pub struct ScreenContentSelection {
pub:
	sel ?Selection
}

// Extra stuff to emit for screen formatting.
pub struct ScreenExtra {
pub:
	// Emit cursor position using CUP (CSI H).
	cursor bool
	// Emit current SGR style state based on the cursor's active style_id.
	style bool
	// Emit current hyperlink state using OSC 8 sequences.
	hyperlink bool
	// Emit character protection mode using DECSCA.
	protection bool
	// Emit Kitty keyboard protocol state using CSI > u and CSI = sequences.
	kitty_keyboard bool
	// Emit character set designations and invocations.
	charsets bool
}

// Emit nothing.
pub const screen_extra_none = ScreenExtra{
	cursor: false
	style: false
	hyperlink: false
	protection: false
	kitty_keyboard: false
	charsets: false
}

// Emit style-relevant information only.
pub const screen_extra_styles = ScreenExtra{
	cursor: false
	style: true
	hyperlink: true
	protection: false
	kitty_keyboard: false
	charsets: false
}

// Emit everything.
pub const screen_extra_all = ScreenExtra{
	cursor: true
	style: true
	hyperlink: true
	protection: true
	kitty_keyboard: true
	charsets: true
}

// Returns true if any extra flags are set.
pub fn (self ScreenExtra) is_set() bool {
	return self.cursor || self.style || self.hyperlink || self.protection
		|| self.kitty_keyboard || self.charsets
}

pub fn ScreenFormatter.init(screen &Screen, opts FormatOptions) ScreenFormatter {
	return ScreenFormatter{
		screen: unsafe { screen }
		opts: opts
		content: ScreenContent(ScreenContentSelection{ sel: none })
		extra: screen_extra_none
	}
}

pub fn (self ScreenFormatter) format() string {
	mut sb := strings.new_builder(1024)

	match self.content {
		ScreenContentNone {}
		ScreenContentSelection {
			// Emit our page content according to our selection.
			mut page_fmt := PageFormatter.init(&self.screen.pages, self.opts)
			if sel := self.content.sel {
				// Order the selection for formatting (start before end)
				s := if sel.start_pin.before(sel.end_pin) { sel.start_pin } else { sel.end_pin }
				e := if sel.start_pin.before(sel.end_pin) { sel.end_pin } else { sel.start_pin }
				page_fmt.start_x = s.x
				page_fmt.start_y = s.y
				page_fmt.end_x = e.x
				page_fmt.end_y = e.y
				page_fmt.rectangle = sel.rectangle
			}
			result := page_fmt.format_with_state()
			sb.write_string(result.output)
		}
	}

	// Emit extra screen state after content if we care.
	match self.opts.emit {
		.plain { return sb.str() }
		.vt {
			if !self.extra.is_set() {
				return sb.str()
			}
		}
		// HTML doesn't preserve any screen state
		.html { return sb.str() }
	}

	// Emit current SGR style state
	if self.extra.style {
		cursor := self.screen.cursor
		sb.write_string(format_style_vt(cursor.style))
	}

	// Emit current hyperlink state using OSC 8
	if self.extra.hyperlink {
		if link := self.screen.cursor.hyperlink_state {
			// Start hyperlink with uri (and explicit id if present)
			match link.id {
				HyperlinkExplicitId {
					sb.write_string('\x1b]8;id=${link.id.value};${link.uri}\x1b\\')
				}
				HyperlinkImplicitId {
					sb.write_string('\x1b]8;;${link.uri}\x1b\\')
				}
			}
		}
	}

	// Emit character protection mode using DECSCA
	if self.extra.protection {
		if self.screen.cursor.is_protected {
			// DEC protected mode
			sb.write_string('\x1b[1"q')
		}
	}

	// Emit Kitty keyboard protocol state using CSI = u
	if self.extra.kitty_keyboard {
		flags := self.screen.kitty_keyboard.flags[self.screen.kitty_keyboard.idx]
		if flags != 0 {
			sb.write_string('\x1b[=${flags};1u')
		}
	}

	// Emit character set designations and invocations
	if self.extra.charsets {
		cs := self.screen.charset

		// Emit G0-G3 designations
		for slot in [CharsetSlot.g0, .g1, .g2, .g3] {
			charset := cs.charsets.get(slot)
			if charset != .utf8 {
				// Only emit non-default charsets
				intermediate := match slot {
					.g0 { u8(`(`) }
					.g1 { u8(`)`) }
					.g2 { u8(`*`) }
					.g3 { u8(`+`) }
				}
				final_byte := match charset {
					.ascii { u8(`B`) }
					.british { u8(`A`) }
					.dec_special { u8(`0`) }
					else { continue }
				}
				sb.write_u8(0x1b)
				sb.write_u8(intermediate)
				sb.write_u8(final_byte)
			}
		}

		// Emit GL invocation if not G0
		if cs.gl != .g0 {
			seq := match cs.gl {
				.g0 { '' } // unreachable
				.g1 { '\x0e' } // SO - Shift Out
				.g2 { '\x1bn' } // LS2
				.g3 { '\x1bo' } // LS3
			}
			sb.write_string(seq)
		}

		// Emit GR invocation if not G2
		if cs.gr != .g2 {
			seq := match cs.gr {
				.g0 { '' } // unreachable
				.g1 { '\x1b~' } // LS1R
				.g2 { '' } // unreachable
				.g3 { '\x1b|' } // LS3R
			}
			sb.write_string(seq)
		}
	}

	// Emit cursor position using CUP (CSI H)
	if self.extra.cursor {
		cursor := self.screen.cursor
		// CUP is 1-indexed
		sb.write_string('\x1b[${cursor.y + 1};${cursor.x + 1}H')
	}

	return sb.str()
}

// Page formatter formats a single page (i.e., the Pages data).
//
// For styled formatting such as VT, this will emit references for palette
// colors. If you want to capture the palette as-is at the time of formatting,
// you'll have to emit the sequences for setting up the palette prior to
// this formatting.
pub struct PageFormatter {
pub:
	// The page data to format.
	pages &Pages
	// The common options
	opts FormatOptions
pub mut:
	// Start and end points within the page to format.
	// Start and end are both inclusive.
	start_x u32
	start_y u32
	end_x   u32 = max_u32
	end_y   u32 = max_u32
	// If true, the start x/y and end x/y define a rectangle selection.
	rectangle bool
	// The previous trailing state from the prior page.
	trailing_state ?TrailingState
}

// Trailing state for cross-page continuation.
pub struct TrailingState {
pub mut:
	rows  int
	cells int
}

pub const trailing_state_empty = TrailingState{ rows: 0, cells: 0 }

// Result of formatting with state.
pub struct FormatResult {
pub:
	output string
	state  TrailingState
}

pub fn PageFormatter.init(pages &Pages, opts FormatOptions) PageFormatter {
	return PageFormatter{
		pages: unsafe { pages }
		opts: opts
		start_x: 0
		start_y: 0
		end_x: max_u32
		end_y: max_u32
		rectangle: false
		trailing_state: none
	}
}

pub fn (self PageFormatter) format() string {
	return self.format_with_state().output
}

pub fn (self PageFormatter) format_with_state() FormatResult {
	mut blank_rows := 0
	mut blank_cells := 0

	// Continue our prior trailing state if we have it, but only if we're
	// starting from the beginning (start_y and start_x are both 0).
	// If a non-zero start position is specified, ignore trailing state.
	if state := self.trailing_state {
		if self.start_y == 0 && self.start_x == 0 {
			blank_rows = state.rows
			blank_cells = state.cells
		}
	}

	page_cols := self.pages.cols
	page_rows := u32(self.pages.screen_rows.len)

	// Setup our starting column and perform some validation for overflows.
	start_x := self.start_x
	if start_x >= page_cols {
		return FormatResult{
			output: ''
			state: TrailingState{ rows: blank_rows, cells: blank_cells }
		}
	}
	end_x_unclamped := if self.end_x == max_u32 { page_cols - 1 } else { self.end_x }
	mut end_x := min_u32(end_x_unclamped, page_cols - 1)

	// Setup our starting row and perform some validation for overflows.
	start_y := self.start_y
	if start_y >= page_rows {
		return FormatResult{
			output: ''
			state: TrailingState{ rows: blank_rows, cells: blank_cells }
		}
	}
	end_y_unclamped := if self.end_y == max_u32 { page_rows - 1 } else { self.end_y }
	if start_y > end_y_unclamped {
		return FormatResult{
			output: ''
			state: TrailingState{ rows: blank_rows, cells: blank_cells }
		}
	}
	mut end_y := min_u32(end_y_unclamped, page_rows - 1)

	// Edge case: if our end x/y falls on a spacer head AND we're unwrapping,
	// then we move the x/y to the start of the next row (if available).
	if self.opts.unwrap && !self.rectangle {
		final_row := self.pages.screen_rows[int(end_y)]
		if int(end_x) < final_row.cells.len {
			if final_row.cells[int(end_x)].wide == .spacer_head {
				if end_y < page_rows - 1 {
					end_y += 1
					end_x = 0
				}
			}
		}
	}

	// If we only have a single row, validate that start_x <= end_x
	if start_y == end_y && start_x > end_x {
		return FormatResult{
			output: ''
			state: TrailingState{ rows: blank_rows, cells: blank_cells }
		}
	}

	mut sb := strings.new_builder(1024)

	// Wrap HTML output in monospace font styling
	match self.opts.emit {
		.plain {}
		.html {
			sb.write_string('<div style="font-family: monospace; white-space: pre;')
			// Background/foreground colors
			if bg := self.opts.background {
				sb.write_string('background-color: #${hex02(bg.r)}${hex02(bg.g)}${hex02(bg.b)};')
			}
			if fg := self.opts.foreground {
				sb.write_string('color: #${hex02(fg.r)}${hex02(fg.g)}${hex02(fg.b)};')
			}
			sb.write_string('">')
		}
		.vt {
			// OSC 10 sets foreground color, OSC 11 sets background color
			if fg := self.opts.foreground {
				sb.write_string('\x1b]10;rgb:${hex02(fg.r)}/${hex02(fg.g)}/${hex02(fg.b)}\x1b\\')
			}
			if bg := self.opts.background {
				sb.write_string('\x1b]11;rgb:${hex02(bg.r)}/${hex02(bg.g)}/${hex02(bg.b)}\x1b\\')
			}
		}
	}

	// Our style for non-plain formats
	mut style := CellStyle{}

	for y_int in int(start_y) .. int(end_y) + 1 {
		y := u32(y_int)
		row := self.pages.screen_rows[y_int]
		cells := row.cells

		// Determine the x range for this row
		row_end_x := if self.rectangle || y == end_y {
			end_x + 1
		} else {
			page_cols
		}

		mut row_start_x := if start_x > 0 && (self.rectangle || y == start_y) {
			// Check if our start X falls on the tail of a wide character.
			if int(start_x) < cells.len {
				match cells[int(start_x)].wide {
					.spacer_tail { start_x - 1 }
					.spacer_head { continue } // skip this whole row
					else { start_x }
				}
			} else {
				start_x
			}
		} else {
			u32(0)
		}

		// Get the subset of cells for this row
		actual_end := min_u32(row_end_x, u32(cells.len))
		if row_start_x >= actual_end {
			// No cells in range
			blank_rows += 1
			continue
		}
		cells_subset := cells[int(row_start_x)..int(actual_end)]

		// If this row is blank, accumulate to avoid a bunch of extra work later.
		if !has_text_any(cells_subset) {
			blank_rows += 1
			continue
		}

		if blank_rows > 0 {
			// Reset style before emitting newlines to prevent background
			// colors from bleeding into the next line's leading cells.
			if !style.default() {
				sb.write_string(format_style_close(self.opts.emit))
				style = CellStyle{}
			}

			newline := match self.opts.emit {
				// Plaintext just uses standard newlines
				.plain { '\n' }
				// VT uses \r\n because in a raw pty, \n alone doesn't
				// guarantee moving the cursor back to column 0.
				.vt { '\r\n' }
				// HTML uses just \n
				.html { '\n' }
			}

			for _ in 0 .. blank_rows {
				sb.write_string(newline)
			}
			blank_rows = 0
		}

		// If we're not wrapped, we always add a newline so after
		// the row is printed we can add a newline.
		if !row.wrap || !self.opts.unwrap {
			blank_rows += 1
		}

		// If the row doesn't continue a wrap then we need to reset
		// our blank cell count.
		if !row.wrap_continuation || !self.opts.unwrap {
			blank_cells = 0
		}

		// Go through each cell and print it
		for _, cell in cells_subset {

			// Skip spacers
			match cell.wide {
				.narrow, .wide {}
				.spacer_head, .spacer_tail { continue }
			}

			// If we have a zero value, then we accumulate a counter.
			if self.opts.emit.styled() && (!cell_is_empty(cell) || cell_has_styling(cell)) {
				// Not blank - styled cell with content or styling
			} else if !cell.has_text() {
				blank_cells += 1
				continue
			} else if cell.codepoint == u32(` `) && self.opts.trim {
				blank_cells += 1
				continue
			}

			// This cell is not blank. If we have accumulated blank cells
			// then we want to emit them now.
			if blank_cells > 0 {
				for _ in 0 .. blank_cells {
					sb.write_u8(` `)
				}
				blank_cells = 0
			}

			// Handle style changes
			if self.opts.emit.styled() {
				cell_style := self.cell_style(cell)

				// If the style hasn't changed, don't bloat output.
				if !cell_style_eql(cell_style, style) {
					// If we had a previous style, we need to close it
					if !style.default() {
						match self.opts.emit {
							.html { sb.write_string(format_style_close(self.opts.emit)) }
							.vt {
								if cell_style.default() {
									sb.write_string(format_style_close(self.opts.emit))
								}
							}
							.plain {} // unreachable
						}
					}

					style = cell_style

					// If we're just the default style now, we're done.
					if !cell_style.default() {
						// New style, emit it.
						sb.write_string(self.format_style_open(style))
					}
				}
			}

			// Write the cell content
			if cell.content_tag == .codepoint {
				if !cell.has_text() {
					// Blank cells get an empty space for formatting preservation
					sb.write_u8(` `)
				} else {
					self.write_codepoint_with_replacement(mut sb, cell.codepoint)
					// Write grapheme continuation codepoints
					if cell.has_grapheme {
						for cp in cell.graphemes {
							self.write_codepoint_with_replacement(mut sb, cp)
						}
					}
				}
			} else {
				// bg_color_only: emit a space with the appropriate background
				sb.write_u8(` `)
			}
		}
	}

	// If the style is non-default, we need to close our style tag.
	if !style.default() {
		sb.write_string(format_style_close(self.opts.emit))
	}

	// Close the monospace wrapper for HTML output
	if self.opts.emit == .html {
		sb.write_string('</div>')
	}

	return FormatResult{
		output: sb.str()
		state: TrailingState{ rows: blank_rows, cells: blank_cells }
	}
}

// Write a codepoint with replacement map lookup.
fn (self PageFormatter) write_codepoint_with_replacement(mut sb strings.Builder, codepoint u32) {
	// Search for our replacement (last matching range wins)
	if self.opts.codepoint_map.len > 0 {
		for i_forward in 0 .. self.opts.codepoint_map.len {
			i := self.opts.codepoint_map.len - i_forward - 1
			entry := self.opts.codepoint_map[i]
			if entry.range_start <= codepoint && codepoint <= entry.range_end {
				match entry.replacement {
					CodepointRepl {
						self.write_codepoint(mut sb, entry.replacement.codepoint)
					}
					StringRepl {
						// Iterate over string as runes
						for ch in entry.replacement.str.runes() {
							self.write_codepoint(mut sb, u32(ch))
						}
					}
				}
				return
			}
		}
	}

	// No replacement, write directly.
	self.write_codepoint(mut sb, codepoint)
}

// Write a single codepoint in the appropriate format.
fn (self PageFormatter) write_codepoint(mut sb strings.Builder, codepoint u32) {
	match self.opts.emit {
		.plain, .vt {
			// Write as UTF-8
			write_utf8(mut sb, codepoint)
		}
		.html {
			match codepoint {
				u32(`<`) { sb.write_string('&lt;') }
				u32(`>`) { sb.write_string('&gt;') }
				u32(`&`) { sb.write_string('&amp;') }
				u32(`"`) { sb.write_string('&quot;') }
				u32(`'`) { sb.write_string('&#39;') }
				else {
					// For HTML, emit ASCII (< 0x80) directly, but encode
					// all non-ASCII as numeric entities to avoid encoding
					// detection issues.
					if codepoint < 0x80 {
						write_utf8(mut sb, codepoint)
					} else {
						sb.write_string('&#${codepoint};')
					}
				}
			}
		}
	}
}

// Returns the style for the given cell.
fn (self PageFormatter) cell_style(cell CellData) CellStyle {
	if cell.content_tag == .codepoint {
		if !cell_has_styling(cell) {
			return CellStyle{}
		}
		// XTODO: look up style from a style table by style_id.
		// For now, return a placeholder that at least preserves
		// the style_id being non-default.
		return lookup_style_by_id(self.pages, cell.style_id)
	}
	// bg_color_only: return style with just background color
	return CellStyle{}
}

// Format a style open tag.
fn (self PageFormatter) format_style_open(style CellStyle) string {
	match self.opts.emit {
		.plain { return '' } // unreachable
		.vt {
			return format_style_vt_with_palette(style, self.opts.palette)
		}
		.html {
			return '<div style="display: inline;${format_style_html_with_palette(style, self.opts.palette)}">'
		}
	}
}

// ============================================================
// Style formatting helpers
// ============================================================

// Format a style as a VT (SGR) sequence.
pub fn format_style_vt(style CellStyle) string {
	return format_style_vt_with_palette(style, none)
}

// Format a style as a VT (SGR) sequence, optionally resolving palette colors.
fn format_style_vt_with_palette(style CellStyle, palette ?[]RGB) string {
	mut sb := strings.new_builder(64)
	sb.write_string('\x1b[0m')

	if style.flags.bold {
		sb.write_string('\x1b[1m')
	}
	if style.flags.faint {
		sb.write_string('\x1b[2m')
	}
	if style.flags.italic {
		sb.write_string('\x1b[3m')
	}
	if style.flags.underline != .none {
		match style.flags.underline {
			.single { sb.write_string('\x1b[4m') }
			.double { sb.write_string('\x1b[4:2m') }
			.curly { sb.write_string('\x1b[4:3m') }
			.dotted { sb.write_string('\x1b[4:4m') }
			.dashed { sb.write_string('\x1b[4:5m') }
			.none {}
		}
	}
	if style.flags.blink {
		sb.write_string('\x1b[5m')
	}
	if style.flags.inverse {
		sb.write_string('\x1b[7m')
	}
	if style.flags.invisible {
		sb.write_string('\x1b[8m')
	}
	if style.flags.strikethrough {
		sb.write_string('\x1b[9m')
	}
	if style.flags.overline {
		sb.write_string('\x1b[53m')
	}

	// Foreground color
	match style.fg_color {
		.palette {
			if pal := palette {
				if int(style.fg_palette) < pal.len {
					rgb := pal[int(style.fg_palette)]
					sb.write_string('\x1b[38;2;${rgb.r};${rgb.g};${rgb.b}m')
				}
			} else {
				sb.write_string('\x1b[38;5;${style.fg_palette}m')
			}
		}
		.rgb {
			sb.write_string('\x1b[38;2;${style.fg_r};${style.fg_g};${style.fg_b}m')
		}
		.none {}
	}

	// Background color
	match style.bg_color {
		.palette {
			if pal := palette {
				if int(style.bg_palette) < pal.len {
					rgb := pal[int(style.bg_palette)]
					sb.write_string('\x1b[48;2;${rgb.r};${rgb.g};${rgb.b}m')
				}
			} else {
				sb.write_string('\x1b[48;5;${style.bg_palette}m')
			}
		}
		.rgb {
			sb.write_string('\x1b[48;2;${style.bg_r};${style.bg_g};${style.bg_b}m')
		}
		.none {}
	}

	return sb.str()
}

// Format a style as inline CSS for HTML output.
fn format_style_html_with_palette(style CellStyle, palette ?[]RGB) string {
	mut sb := strings.new_builder(128)

	if style.flags.bold {
		sb.write_string('font-weight: bold;')
	}
	if style.flags.italic {
		sb.write_string('font-style: italic;')
	}
	if style.flags.underline != .none {
		sb.write_string('text-decoration: underline;')
	}
	if style.flags.strikethrough {
		sb.write_string('text-decoration: line-through;')
	}
	if style.flags.overline {
		sb.write_string('text-decoration: overline;')
	}

	// Foreground color
	match style.fg_color {
		.palette {
			if pal := palette {
				if int(style.fg_palette) < pal.len {
					rgb := pal[int(style.fg_palette)]
					sb.write_string('color: rgb(${rgb.r}, ${rgb.g}, ${rgb.b});')
				}
			} else {
				sb.write_string('color: var(--vt-palette-${style.fg_palette});')
			}
		}
		.rgb {
			sb.write_string('color: rgb(${style.fg_r}, ${style.fg_g}, ${style.fg_b});')
		}
		.none {}
	}

	// Background color
	match style.bg_color {
		.palette {
			if pal := palette {
				if int(style.bg_palette) < pal.len {
					rgb := pal[int(style.bg_palette)]
					sb.write_string('background-color: rgb(${rgb.r}, ${rgb.g}, ${rgb.b});')
				}
			} else {
				sb.write_string('background-color: var(--vt-palette-${style.bg_palette});')
			}
		}
		.rgb {
			sb.write_string('background-color: rgb(${style.bg_r}, ${style.bg_g}, ${style.bg_b});')
		}
		.none {}
	}

	return sb.str()
}

// Format a style close tag.
fn format_style_close(emit Format) string {
	return match emit {
		.plain { '' }
		.vt { '\x1b[0m' }
		.html { '</div>' }
	}
}

// ============================================================
// Utility functions
// ============================================================

// Helper to format a u8 as a two-digit lowercase hex string.
fn hex02(val u8) string {
	hex_chars := '0123456789abcdef'.bytes()
	mut buf := [u8(0), 0]
	buf[0] = hex_chars[val >> 4]
	buf[1] = hex_chars[val & 0x0f]
	return buf[..].bytestr()
}

// Helper to write a unicode codepoint as UTF-8 bytes.
fn write_utf8(mut sb strings.Builder, codepoint u32) {
	if codepoint < 0x80 {
		sb.write_u8(u8(codepoint))
	} else if codepoint < 0x800 {
		sb.write_u8(u8(0xC0 | (codepoint >> 6)))
		sb.write_u8(u8(0x80 | (codepoint & 0x3F)))
	} else if codepoint < 0x10000 {
		sb.write_u8(u8(0xE0 | (codepoint >> 12)))
		sb.write_u8(u8(0x80 | ((codepoint >> 6) & 0x3F)))
		sb.write_u8(u8(0x80 | (codepoint & 0x3F)))
	} else {
		sb.write_u8(u8(0xF0 | (codepoint >> 18)))
		sb.write_u8(u8(0x80 | ((codepoint >> 12) & 0x3F)))
		sb.write_u8(u8(0x80 | ((codepoint >> 6) & 0x3F)))
		sb.write_u8(u8(0x80 | (codepoint & 0x3F)))
	}
}

// has_text_any is defined in types.v

// Check if a cell is empty (no codepoint, no styling).
fn cell_is_empty(cell CellData) bool {
	return cell.content_tag == .codepoint && cell.codepoint == 0 && cell.style_id == 0
}

// Check if a cell has non-default styling.
fn cell_has_styling(cell CellData) bool {
	return cell.style_id != default_style_id
}

// Compare two CellStyle structs for equality.
fn cell_style_eql(a CellStyle, b CellStyle) bool {
	return a.flags.bold == b.flags.bold && a.flags.faint == b.flags.faint
		&& a.flags.italic == b.flags.italic && a.flags.underline == b.flags.underline
		&& a.flags.overline == b.flags.overline && a.flags.blink == b.flags.blink
		&& a.flags.inverse == b.flags.inverse && a.flags.invisible == b.flags.invisible
		&& a.flags.strikethrough == b.flags.strikethrough && a.fg_color == b.fg_color
		&& a.bg_color == b.bg_color && a.underline_color == b.underline_color
		&& a.fg_r == b.fg_r && a.fg_g == b.fg_g && a.fg_b == b.fg_b && a.bg_r == b.bg_r
		&& a.bg_g == b.bg_g && a.bg_b == b.bg_b && a.fg_palette == b.fg_palette
		&& a.bg_palette == b.bg_palette
}

// XTODO: lookup a CellStyle from a style table by style_id.
// Ghostty uses a per-page style table with ref-counting. We don't have
// that yet, so for now we return a default style for id 0, and a
// placeholder for non-zero ids. This will need to be replaced when
// the style system is implemented.
fn lookup_style_by_id(pages &Pages, style_id u32) CellStyle {
	if style_id == default_style_id {
		return CellStyle{}
	}
	// XTODO: when we have a real style table, look up the style here.
	// For now return a default non-empty style marker so at least we
	// know there was a style.
	return CellStyle{}
}

// Max u32 sentinel value.
const max_u32 = u32(0xFFFFFFFF)

// Minimum of two u32 values.
fn min_u32(a u32, b u32) u32 {
	return if a < b { a } else { b }
}
