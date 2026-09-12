module terminal

import osc

// --- Original Ghostty Comments Start: src/terminal/stream_readonly.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/terminal/stream_readonly.zig
//
// This is a Stream implementation that processes actions against
// a Terminal and updates the Terminal state. It is called "readonly" because
// it only processes actions that modify terminal state, while ignoring
// any actions that require a response (like queries).
//
// If you're implementing a terminal emulator that only needs to render
// output and doesn't need to respond (since it maybe isn't running the
// actual program), this is the stream type to use. For example, this is
// ideal for replay tooling, CI logs, PaaS builder output, etc.
// See Stream, which is just the stream wrapper around this.
//
// This isn't attached directly to Terminal because there is additional
// state and options we plan to add in the future, such as APC/DCS which
// don't make sense to me to add to the Terminal directly. Instead, you
// can call `vtHandler` on Terminal to initialize this handler.
// The terminal state to modify.
// Currently does nothing but may in the future so callers should
// call this.
// No supported DCS commands have any terminal-modifying effects,
// but they may in the future. For now we just ignore it.
// APC can modify terminal state (Kitty graphics) but we don't
// currently support it in the readonly stream.
// Have no terminal-modifying effect
// Set the mode on the terminal
// Some modes require additional processing
// Move cursor using escape sequences
// Move to position 2,3
// Print some text
// Move cursor to position 1,6 and erase from cursor to end of line
// Test wraparound mode
// Set scrolling region from line 5 to 20
// Configure G0 as DEC special graphics
// Write to primary screen
// Switch to alt screen
// Write to alt screen
// Switch back to primary
// Move cursor to 10,15
// Save cursor
// Move cursor elsewhere
// Restore cursor
// Set bold and write text
// Verify we can write attributes - just check the string was written
// Run DECALN
// Verify entire screen is filled with 'E'
// Cursor should be at 1,1
// Make some changes
// Full reset
// Verify reset state
// These should be ignored without error
// Terminal should still be functional
// Save default color
// Set color 0 to red
// Reset color 0
// Set multiple colors
// Reset all palette colors
// Initially unset
// Set foreground to red
// Reset foreground
// Set background to green
// Reset background
// Set cursor to blue
// Reset cursor
// After reset, cursor might be null (using default)
// Set palette color 5 to magenta using kitty protocol
// Set and then reset palette color
// Set foreground using kitty protocol
// Set background using kitty protocol
// Set cursor using kitty protocol
// Set and reset foreground
// After reset, should be unset
// Clear dirty flag
// Setting palette color should set dirty flag
// Clear and test reset
// Clear and test kitty protocol
// Write some text and then send OSC 133;A (fresh_line_new_prompt)
// Should do a fresh line (carriage return + index)
// Should set cursor semantic_content to prompt
// Test with redraw option
// Write some text and then send OSC 133;A (fresh_line_new_prompt)
// Write some text
// OSC 133;P marks the start of a prompt (without fresh line behavior)
// Write some text
// Should behave like fresh_line_new_prompt - cursor moves to column 0
// on next line since we had content
// OSC 133;N when already at column 0 should stay on same line
// Set input terminated by EOL
// Linefeed should reset semantic content to output
//
// --- Original Ghostty Comments End: src/terminal/stream_readonly.zig

// ReadonlyStream processes VT actions against a Terminal and updates
// the Terminal state. It is called "readonly" because it only processes
// actions that modify terminal state, while ignoring any actions that
// require a response (like queries).
//
// If you're implementing a terminal emulator that only needs to render
// output and doesn't need to respond (since it maybe isn't running the
// actual program), this is the stream type to use. For example, this is
// ideal for replay tooling, CI logs, PaaS builder output, etc.
//
// Source: stream_readonly.zig

// ReadonlyStream combines a byte-level Stream parser with a
// ReadonlyHandler that applies parsed actions to a Terminal.
pub struct ReadonlyStream {
pub mut:
	handler ReadonlyHandler
	stream  Stream
}

pub fn ReadonlyStream.init(mut term Terminal) ReadonlyStream {
	return ReadonlyStream{
		handler: ReadonlyHandler.init(mut term)
		stream: Stream.init_alloc(voidptr(1))
	}
}

pub fn (mut self ReadonlyStream) deinit() {
	self.stream.deinit()
	self.handler.deinit()
}

// Process a string of bytes through the stream and apply to the terminal.
pub fn (mut self ReadonlyStream) next_slice(input_ string) ! {
	self.stream.next_slice(input_.bytes())
	self.apply_events()!
}

// Process one byte through the stream and apply its actions to the terminal.
pub fn (mut self ReadonlyStream) next(c u8) ! {
	self.stream.next(c)
	self.apply_events()!
}

// Apply a decoded codepoint directly through the readonly handler.
pub fn (mut self ReadonlyStream) print(c u32) ! {
	self.stream.print(c)
	self.apply_events()!
}

// Apply a C0 or C1 control directly through the readonly handler.
pub fn (mut self ReadonlyStream) execute(c u8) ! {
	self.stream.execute(c)
	self.apply_events()!
}

fn (mut self ReadonlyStream) apply_events() ! {
	defer { self.stream.clear_events() }
	for event in self.stream.events {
		self.handler.vt(event)!
	}
}

// ============================================================
// ReadonlyHandler
// ============================================================

// ReadonlyHandler processes stream events and applies them to a Terminal.
//
// This isn't attached directly to Terminal because there is additional
// state and options we plan to add in the future, such as APC/DCS which
// don't make sense to add to the Terminal directly.
pub struct ReadonlyHandler {
pub mut:
	// The terminal state to modify.
	terminal &Terminal = unsafe { nil }
}

pub fn ReadonlyHandler.init(mut term Terminal) ReadonlyHandler {
	return ReadonlyHandler{
		terminal: unsafe { &term }
	}
}

pub fn (mut self ReadonlyHandler) deinit() {
	// Currently does nothing but may in the future so callers should
	// call this.
}

// Process a single stream event and apply it to the terminal.
pub fn (mut self ReadonlyHandler) vt(event StreamEvent) ! {
	match event.key {
		.print {
			self.terminal.print(event.payload.cp)!
		}
		.print_repeat {
			self.terminal.print_repeat(int(event.payload.num))!
		}
		.backspace {
			self.terminal.backspace()
		}
		.carriage_return {
			self.terminal.carriage_return()
		}
		.linefeed {
			self.terminal.linefeed()!
		}
		.index {
			self.terminal.index()!
		}
		.next_line {
			self.terminal.index()!
			self.terminal.carriage_return()
		}
		.reverse_index {
			self.terminal.reverse_index()
		}
		.cursor_up {
			self.terminal.cursor_up(int(event.payload.num))
		}
		.cursor_down {
			self.terminal.cursor_down(int(event.payload.num))
		}
		.cursor_left {
			self.terminal.cursor_left(int(event.payload.num))
		}
		.cursor_right {
			self.terminal.cursor_right(int(event.payload.num))
		}
		.cursor_pos {
			self.terminal.set_cursor_pos(int(event.payload.num), int(event.payload.num2))
		}
		.cursor_col {
			self.terminal.set_cursor_pos(int(self.terminal.screens.active.cursor.y) + 1, int(event.payload.num))
		}
		.cursor_row {
			self.terminal.set_cursor_pos(int(event.payload.num), int(self.terminal.screens.active.cursor.x) + 1)
		}
		.cursor_col_relative {
			self.terminal.set_cursor_pos(
				int(self.terminal.screens.active.cursor.y) + 1,
				int(self.terminal.screens.active.cursor.x) + 1 + int(event.payload.num),
			)
		}
		.cursor_row_relative {
			self.terminal.set_cursor_pos(
				int(self.terminal.screens.active.cursor.y) + 1 + int(event.payload.num),
				int(self.terminal.screens.active.cursor.x) + 1,
			)
		}
		.cursor_style {
			blink := match event.payload.cursor_style {
				.default_, .steady_block, .steady_bar, .steady_underline { false }
				.blinking_block, .blinking_bar, .blinking_underline { true }
			}
			style := match event.payload.cursor_style {
				.default_, .blinking_block, .steady_block { CursorStyle.block }
				.blinking_bar, .steady_bar { CursorStyle.bar }
				.blinking_underline, .steady_underline { CursorStyle.underline }
			}
			self.terminal.modes.set(.cursor_blinking, blink)
			self.terminal.screens.active.cursor.cursor_style = style
		}
		.erase_display_below {
			self.terminal.erase_display(.below, event.payload.flag)
		}
		.erase_display_above {
			self.terminal.erase_display(.above, event.payload.flag)
		}
		.erase_display_complete {
			self.terminal.erase_display(.complete, event.payload.flag)
		}
		.erase_display_scrollback {
			self.terminal.erase_display(.scrollback, event.payload.flag)
		}
		.erase_display_scroll_complete {
			self.terminal.erase_display(.scroll_complete, event.payload.flag)
		}
		.erase_line_right {
			self.terminal.erase_line(.right, event.payload.flag)
		}
		.erase_line_left {
			self.terminal.erase_line(.left, event.payload.flag)
		}
		.erase_line_complete {
			self.terminal.erase_line(.complete, event.payload.flag)
		}
		.erase_line_right_unless_pending_wrap {
			self.terminal.erase_line(.right_unless_pending_wrap, event.payload.flag)
		}
		.delete_chars {
			self.terminal.delete_chars(int(event.payload.num))
		}
		.erase_chars {
			self.terminal.erase_chars(int(event.payload.num))
		}
		.insert_lines {
			self.terminal.insert_lines(int(event.payload.num))
		}
		.insert_blanks {
			self.terminal.insert_blanks(int(event.payload.num))
		}
		.delete_lines {
			self.terminal.delete_lines(int(event.payload.num))
		}
		.scroll_up {
			self.terminal.scroll_up(int(event.payload.num))!
		}
		.scroll_down {
			self.terminal.scroll_down(int(event.payload.num))
		}
		.horizontal_tab {
			self.horizontal_tab(event.payload.num)
		}
		.horizontal_tab_back {
			self.horizontal_tab_back(event.payload.num)
		}
		.tab_clear_current {
			self.terminal.tab_clear(.current)
		}
		.tab_clear_all {
			self.terminal.tab_clear(.all)
		}
		.tab_set {
			self.terminal.tab_set()
		}
		.tab_reset {
			self.terminal.tab_reset()
		}
		.set_mode {
			self.set_mode(event.payload.mode, true)!
		}
		.reset_mode {
			self.set_mode(event.payload.mode, false)!
		}
		.save_mode {
			self.terminal.modes.save(event.payload.mode)
		}
		.restore_mode {
			v := self.terminal.modes.restore(event.payload.mode)
			self.set_mode(event.payload.mode, v)!
		}
		.top_and_bottom_margin {
			self.terminal.set_top_and_bottom_margin(int(event.payload.num), int(event.payload.num2))
		}
		.left_and_right_margin {
			self.terminal.set_left_and_right_margin(int(event.payload.num), int(event.payload.num2))
		}
		.left_and_right_margin_ambiguous {
			if self.terminal.modes.get(.enable_left_and_right_margin) {
				self.terminal.set_left_and_right_margin(0, 0)
			} else {
				self.terminal.save_cursor()
			}
		}
		.save_cursor {
			self.terminal.save_cursor()
		}
		.restore_cursor {
			self.terminal.restore_cursor()
		}
		.invoke_charset {
			self.terminal.invoke_charset(event.payload.charset_bank, event.payload.charset_slot, event.payload.charset_locking)
		}
		.configure_charset {
			self.terminal.configure_charset(event.payload.charset_slot, event.payload.charset_val)
		}
		.set_attribute {
			if event.payload.sgr.kind != .unknown {
				self.terminal.set_attribute(event.payload.sgr) or {}
			}
		}
		.protected_mode_off {
			self.terminal.set_protected_mode(.off)
		}
		.protected_mode_iso {
			self.terminal.set_protected_mode(.iso)
		}
		.protected_mode_dec {
			self.terminal.set_protected_mode(.dec)
		}
		.mouse_shift_capture {
			self.terminal.flags.mouse_shift_capture = if event.payload.flag {
				MouseShiftCaptureState.true_
			} else {
				MouseShiftCaptureState.false_
			}
		}
		.kitty_keyboard_push {
			self.terminal.screens.active.kitty_keyboard.push(u32(event.payload.kitty_flags))
		}
		.kitty_keyboard_pop {
			self.terminal.screens.active.kitty_keyboard.pop(usize(event.payload.num))
		}
		.kitty_keyboard_set {
			self.terminal.screens.active.kitty_keyboard.set(.set_, u32(event.payload.kitty_flags))
		}
		.kitty_keyboard_set_or {
			self.terminal.screens.active.kitty_keyboard.set(.or_, u32(event.payload.kitty_flags))
		}
		.kitty_keyboard_set_not {
			self.terminal.screens.active.kitty_keyboard.set(.not_, u32(event.payload.kitty_flags))
		}
		.modify_key_format {
			self.terminal.flags.modify_other_keys_2 = false
			match event.payload.modify_key_format {
				.other_keys_numeric {
					self.terminal.flags.modify_other_keys_2 = true
				}
				else {}
			}
		}
		.active_status_display {
			self.terminal.status_display = event.payload.status_display
		}
		.decaln {
			self.terminal.decaln()!
		}
		.full_reset {
			self.terminal.full_reset()
		}
		.start_hyperlink {
			self.terminal.screens.active.start_hyperlink(event.payload.hyperlink.uri, event.payload.hyperlink.id)!
		}
		.end_hyperlink {
			self.terminal.screens.active.end_hyperlink()
		}
		.semantic_prompt {
			self.terminal.semantic_prompt_options(event.payload.semantic_prompt_action, event.payload.semantic_prompt_opts)
		}
		.mouse_shape {
			self.terminal.mouse_shape = event.payload.mouse_shape_val
		}
		.color_operation {
			self.color_operation(event.payload.color_op, event.payload.color_requests)
		}
		.kitty_color_report {
			self.kitty_color_operation(event.payload.kitty_color_items)
		}

		// No supported DCS commands have any terminal-modifying effects,
		// but they may in the future. For now we just ignore them.
		.dcs_hook, .dcs_put, .dcs_unhook {}
		// APC can modify terminal state (Kitty graphics) but we don't
		// currently support it in the readonly stream.
		.apc_start, .apc_end, .apc_put {}
		// Have no terminal-modifying effect
		.bell, .enquiry, .request_mode, .request_mode_unknown, .size_report, .xtversion, .device_attributes, .device_status, .kitty_keyboard_query, .window_title, .report_pwd, .show_desktop_notification, .progress_report, .clipboard_contents, .title_push, .title_pop {
		}
	}
}

fn (mut self ReadonlyHandler) horizontal_tab(count u16) {
	for _ in 0 .. int(count) {
		x := self.terminal.screens.active.cursor.x
		self.terminal.horizontal_tab()
		if x == self.terminal.screens.active.cursor.x {
			break
		}
	}
}

fn (mut self ReadonlyHandler) horizontal_tab_back(count u16) {
	for _ in 0 .. int(count) {
		x := self.terminal.screens.active.cursor.x
		self.terminal.horizontal_tab_back()
		if x == self.terminal.screens.active.cursor.x {
			break
		}
	}
}

// color_operation applies the parsed request list emitted by osc.Parser.
fn (mut self ReadonlyHandler) color_operation(op osc.ColorOperation, requests []osc.ColorRequest) {
	_ = op
	for request in requests {
		match request {
			osc.ColorRequestSet {
				color := RGB{
					r: request.color.r
					g: request.color.g
					b: request.color.b
				}
				match request.target {
					osc.ColorTargetPalette {
						self.terminal.flags.dirty.palette = true
						self.terminal.colors.palette.set(request.target.index, color)
					}
					osc.ColorTargetDynamic {
						self.readonly_dynamic_set(request.target.color, color)
					}
					osc.ColorTargetSpecial {}
				}
			}
			osc.ColorRequestReset {
				match request.target {
					osc.ColorTargetPalette {
						self.terminal.flags.dirty.palette = true
						self.terminal.colors.palette.reset(request.target.index)
					}
					osc.ColorTargetDynamic {
						self.readonly_dynamic_reset(request.target.color)
					}
					osc.ColorTargetSpecial {}
				}
			}
			osc.ColorRequestResetPalette {
				for i in 0 .. 256 {
					idx := u8(i)
					if self.terminal.colors.palette.mask_is_set(idx) {
						self.terminal.flags.dirty.palette = true
						self.terminal.colors.palette.reset(idx)
					}
				}
			}
			osc.ColorRequestQuery, osc.ColorRequestResetSpecial {}
		}
	}
}

fn (mut self ReadonlyHandler) readonly_dynamic_set(dynamic osc.DynamicColor, color RGB) {
	match dynamic {
		.foreground { self.terminal.colors.foreground.set(color) }
		.background { self.terminal.colors.background.set(color) }
		.cursor { self.terminal.colors.cursor.set(color) }
		else {}
	}
}

fn (mut self ReadonlyHandler) readonly_dynamic_reset(dynamic osc.DynamicColor) {
	match dynamic {
		.foreground { self.terminal.colors.foreground.reset() }
		.background { self.terminal.colors.background.reset() }
		.cursor { self.terminal.colors.cursor.reset() }
		else {}
	}
}

fn (mut self ReadonlyHandler) kitty_color_operation(items []osc.KittyColorItem) {
	for item in items {
		if item.item_type == .query {
			continue
		}
		match item.key.kind {
			.palette {
				self.terminal.flags.dirty.palette = true
				if item.item_type == .set {
					self.terminal.colors.palette.set(item.key.palette, RGB{
						r: item.color.r
						g: item.color.g
						b: item.color.b
					})
				} else {
					self.terminal.colors.palette.reset(item.key.palette)
				}
			}
			.special {
				self.readonly_kitty_special(item)
			}
		}
	}
}

fn (mut self ReadonlyHandler) readonly_kitty_special(item osc.KittyColorItem) {
	if item.item_type == .set {
		color := RGB{
			r: item.color.r
			g: item.color.g
			b: item.color.b
		}
		match item.key.special {
			.foreground { self.terminal.colors.foreground.set(color) }
			.background { self.terminal.colors.background.set(color) }
			.cursor { self.terminal.colors.cursor.set(color) }
			else {}
		}
		return
	}
	match item.key.special {
		.foreground { self.terminal.colors.foreground.reset() }
		.background { self.terminal.colors.background.reset() }
		.cursor { self.terminal.colors.cursor.reset() }
		else {}
	}
}

fn (mut self ReadonlyHandler) set_mode(mode Mode, enabled bool) ! {
	// Set the mode on the terminal
	self.terminal.modes.set(mode, enabled)

	// Some modes require additional processing
	match mode {
		.autorepeat, .reverse_colors {}
		.origin {
			self.terminal.set_cursor_pos(1, 1)
		}
		.enable_left_and_right_margin {
			if !enabled {
				self.terminal.scrolling_region.left = 0
				self.terminal.scrolling_region.right = self.terminal.cols - 1
			}
		}
		.alt_screen_legacy {
			self.terminal.switch_screen_mode(.mode_47, enabled)!
		}
		.alt_screen {
			self.terminal.switch_screen_mode(.mode_1047, enabled)!
		}
		.alt_screen_save_cursor_clear_enter {
			self.terminal.switch_screen_mode(.mode_1049, enabled)!
		}
		.save_cursor {
			if enabled {
				self.terminal.save_cursor()
			} else {
				self.terminal.restore_cursor()
			}
		}
		.enable_mode_3 {}
		.column_132 {
			self.terminal.deccolm(if enabled {
				DeccolmMode.cols_132
			} else {
				DeccolmMode.cols_80
			})!
		}
		.synchronized_output, .linefeed, .in_band_size_reports, .focus_event {}
		.mouse_event_x10 {
			if enabled {
				self.terminal.flags.mouse_event = .x10
			} else {
				self.terminal.flags.mouse_event = .none
			}
		}
		.mouse_event_normal {
			if enabled {
				self.terminal.flags.mouse_event = .normal
			} else {
				self.terminal.flags.mouse_event = .none
			}
		}
		.mouse_event_button {
			if enabled {
				self.terminal.flags.mouse_event = .button
			} else {
				self.terminal.flags.mouse_event = .none
			}
		}
		.mouse_event_any {
			if enabled {
				self.terminal.flags.mouse_event = .any
			} else {
				self.terminal.flags.mouse_event = .none
			}
		}
		.mouse_format_utf8 {
			self.terminal.flags.mouse_format = if enabled {
				MouseFormat.utf8
			} else {
				MouseFormat.x10
			}
		}
		.mouse_format_sgr {
			self.terminal.flags.mouse_format = if enabled {
				MouseFormat.sgr
			} else {
				MouseFormat.x10
			}
		}
		.mouse_format_urxvt {
			self.terminal.flags.mouse_format = if enabled {
				MouseFormat.urxvt
			} else {
				MouseFormat.x10
			}
		}
		.mouse_format_sgr_pixels {
			self.terminal.flags.mouse_format = if enabled {
				MouseFormat.sgr_pixels
			} else {
				MouseFormat.x10
			}
		}
		else {}
	}
}
