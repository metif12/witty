module terminal

import osc
import lib_allocator

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

// This is a Stream implementation that processes actions against
// a Terminal and updates the Terminal state.
pub type ReadonlyStream = Stream[ReadonlyHandler]

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

@[inline]
pub fn (mut self ReadonlyHandler) vt_print(value ActionPrint) ! {
	self.terminal.print(value.cp)!
}

pub fn (mut self ReadonlyHandler) vt(action ActionKey, value ActionValue) ! {
	match action {
		.print {
			if value is ActionPrint {
				self.vt_print(value)!
			}
		}
		.print_repeat {
			if value is uint {
				self.terminal.print_repeat(value)!
			}
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
			if value is ActionCursorMovement {
				self.terminal.cursor_up(value.value)
			}
		}
		.cursor_down {
			if value is ActionCursorMovement {
				self.terminal.cursor_down(value.value)
			}
		}
		.cursor_left {
			if value is ActionCursorMovement {
				self.terminal.cursor_left(value.value)
			}
		}
		.cursor_right {
			if value is ActionCursorMovement {
				self.terminal.cursor_right(value.value)
			}
		}
		.cursor_pos {
			if value is ActionCursorPos {
				self.terminal.set_cursor_pos(value.row, value.col)
			}
		}
		.cursor_col {
			if value is ActionCursorMovement {
				self.terminal.set_cursor_pos(uint(self.terminal.screens.active.cursor.y) + 1, value.value)
			}
		}
		.cursor_row {
			if value is ActionCursorMovement {
				self.terminal.set_cursor_pos(value.value, uint(self.terminal.screens.active.cursor.x) + 1)
			}
		}
		.cursor_col_relative {
			if value is ActionCursorMovement {
				base := self.terminal.screens.active.cursor.x + 1
				col := if u32(value.value) > u32(65535) - base {
					u32(65535)
				} else {
					base + u32(value.value)
				}
				self.terminal.set_cursor_pos(
					uint(self.terminal.screens.active.cursor.y) + 1,
					col,
				)
			}
		}
		.cursor_row_relative {
			if value is ActionCursorMovement {
				base := self.terminal.screens.active.cursor.y + 1
				row := if u32(value.value) > u32(65535) - base {
					u32(65535)
				} else {
					base + u32(value.value)
				}
				self.terminal.set_cursor_pos(
					row,
					uint(self.terminal.screens.active.cursor.x) + 1,
				)
			}
		}
		.cursor_style {
			if value is AnsiCursorStyle {
				blink := match value {
					.default_, .steady_block, .steady_bar, .steady_underline { false }
					.blinking_block, .blinking_bar, .blinking_underline { true }
				}
				style := match value {
					.default_, .blinking_block, .steady_block { CursorStyle.block }
					.blinking_bar, .steady_bar { CursorStyle.bar }
					.blinking_underline, .steady_underline { CursorStyle.underline }
				}
				self.terminal.modes.set(.cursor_blinking, blink)
				self.terminal.screens.active.cursor.cursor_style = style
			}
		}
		.erase_display_below {
			if value is bool {
				self.terminal.erase_display(.below, value)
			}
		}
		.erase_display_above {
			if value is bool {
				self.terminal.erase_display(.above, value)
			}
		}
		.erase_display_complete {
			if value is bool {
				self.terminal.erase_display(.complete, value)
			}
		}
		.erase_display_scrollback {
			if value is bool {
				self.terminal.erase_display(.scrollback, value)
			}
		}
		.erase_display_scroll_complete {
			if value is bool {
				self.terminal.erase_display(.scroll_complete, value)
			}
		}
		.erase_line_right {
			if value is bool {
				self.terminal.erase_line(.right, value)
			}
		}
		.erase_line_left {
			if value is bool {
				self.terminal.erase_line(.left, value)
			}
		}
		.erase_line_complete {
			if value is bool {
				self.terminal.erase_line(.complete, value)
			}
		}
		.erase_line_right_unless_pending_wrap {
			if value is bool {
				self.terminal.erase_line(.right_unless_pending_wrap, value)
			}
		}
		.delete_chars {
			if value is uint {
				self.terminal.delete_chars(value)
			}
		}
		.erase_chars {
			if value is uint {
				self.terminal.erase_chars(value)
			}
		}
		.insert_lines {
			if value is uint {
				self.terminal.insert_lines(value)
			}
		}
		.insert_blanks {
			if value is uint {
				self.terminal.insert_blanks(value)
			}
		}
		.delete_lines {
			if value is uint {
				self.terminal.delete_lines(value)
			}
		}
		.scroll_up {
			if value is uint {
				self.terminal.scroll_up(value)!
			}
		}
		.scroll_down {
			if value is uint {
				self.terminal.scroll_down(value)
			}
		}
		.horizontal_tab {
			if value is u16 {
				self.horizontal_tab(value)
			}
		}
		.horizontal_tab_back {
			if value is u16 {
				self.horizontal_tab_back(value)
			}
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
			if value is ActionMode {
				self.set_mode(value.mode, true)!
			}
		}
		.reset_mode {
			if value is ActionMode {
				self.set_mode(value.mode, false)!
			}
		}
		.save_mode {
			if value is ActionMode {
				self.terminal.modes.save(value.mode)
			}
		}
		.restore_mode {
			if value is ActionMode {
				v := self.terminal.modes.restore(value.mode)
				self.set_mode(value.mode, v)!
			}
		}
		.top_and_bottom_margin {
			if value is ActionMargin {
				self.terminal.set_top_and_bottom_margin(value.top_left, value.bottom_right)
			}
		}
		.left_and_right_margin {
			if value is ActionMargin {
				self.terminal.set_left_and_right_margin(value.top_left, value.bottom_right)
			}
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
			if value is ActionInvokeCharset {
				self.terminal.invoke_charset(value.bank, value.charset, value.locking)
			}
		}
		.configure_charset {
			if value is ActionConfigureCharset {
				self.terminal.configure_charset(value.slot, value.charset)
			}
		}
		.set_attribute {
			if value is SgrAttribute {
				match value {
					SgrUnknown {}
					else {
						self.terminal.set_attribute(value) or {}
					}
				}
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
			if value is bool {
				self.terminal.flags.set_mouse_shift_capture(if value {
					MouseShiftCaptureState.true_
				} else {
					MouseShiftCaptureState.false_
				})
			}
		}
		.kitty_keyboard_push {
			if value is ActionKittyKeyboardFlags {
				self.terminal.screens.active.kitty_keyboard.push(value.flags)
			}
		}
		.kitty_keyboard_pop {
			if value is u16 {
				self.terminal.screens.active.kitty_keyboard.pop(uint(value))
			}
		}
		.kitty_keyboard_set {
			if value is ActionKittyKeyboardFlags {
				self.terminal.screens.active.kitty_keyboard.set(.set_, value.flags)
			}
		}
		.kitty_keyboard_set_or {
			if value is ActionKittyKeyboardFlags {
				self.terminal.screens.active.kitty_keyboard.set(.or_, value.flags)
			}
		}
		.kitty_keyboard_set_not {
			if value is ActionKittyKeyboardFlags {
				self.terminal.screens.active.kitty_keyboard.set(.not_, value.flags)
			}
		}
		.modify_key_format {
			if value is ModifyKeyFormat {
				self.terminal.flags.set_modify_other_keys_2(false)
				match value {
					.other_keys_numeric {
						self.terminal.flags.set_modify_other_keys_2(true)
					}
					else {}
				}
			}
		}
		.active_status_display {
			if value is StatusDisplay {
				self.terminal.status_display = value
			}
		}
		.decaln {
			self.terminal.decaln()!
		}
		.full_reset {
			self.terminal.full_reset()
		}
		.start_hyperlink {
			if value is ActionStartHyperlink {
				self.terminal.screens.active.start_hyperlink(value.uri, value.id)!
			}
		}
		.end_hyperlink {
			self.terminal.screens.active.end_hyperlink()
		}
		.semantic_prompt {
			if value is osc.SemanticPrompt {
				self.terminal.semantic_prompt(value)
			}
		}
		.mouse_shape {
			if value is MouseShape {
				self.terminal.mouse_shape = value
			}
		}
		.color_operation {
			if value is ActionColorOperation {
				self.color_operation(value.op, value.requests)
			}
		}
		.kitty_color_report {
			if value is osc.KittyColorOSC {
				self.kitty_color_operation(value)
			}
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
fn (mut self ReadonlyHandler) color_operation(op osc.ColorOperation, requests lib_allocator.SegmentedList[osc.ColorRequest]) {
	_ = op
	for request_index in 0 .. requests.len {
		request := requests.at(request_index)
		match request {
			osc.ColorRequestSet {
				color := RGB{
					r: request.color.r
					g: request.color.g
					b: request.color.b
				}
				match request.target {
					osc.ColorTargetPalette {
						self.terminal.flags.set_dirty_palette(true)
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
						self.terminal.flags.set_dirty_palette(true)
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
						self.terminal.flags.set_dirty_palette(true)
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

fn (mut self ReadonlyHandler) kitty_color_operation(request osc.KittyColorOSC) {
	for item in request.list {
		match item {
			osc.KittyColorSet {
				color := RGB{
					r: item.color.r
					g: item.color.g
					b: item.color.b
				}
				match item.key {
					u8 {
						self.terminal.flags.set_dirty_palette(true)
						self.terminal.colors.palette.set(item.key, color)
					}
					osc.KittyColorSpecial {
						match item.key {
							.foreground { self.terminal.colors.foreground.set(color) }
							.background { self.terminal.colors.background.set(color) }
							.cursor { self.terminal.colors.cursor.set(color) }
							else {}
						}
					}
				}
			}
			osc.KittyColorReset {
				match item.key {
					u8 {
						self.terminal.flags.set_dirty_palette(true)
						self.terminal.colors.palette.reset(item.key)
					}
					osc.KittyColorSpecial {
						match item.key {
							.foreground { self.terminal.colors.foreground.reset() }
							.background { self.terminal.colors.background.reset() }
							.cursor { self.terminal.colors.cursor.reset() }
							else {}
						}
					}
				}
			}
			osc.KittyColorQuery {}
		}
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
				self.terminal.flags.set_mouse_event(.x10)
			} else {
				self.terminal.flags.set_mouse_event(.none)
			}
		}
		.mouse_event_normal {
			if enabled {
				self.terminal.flags.set_mouse_event(.normal)
			} else {
				self.terminal.flags.set_mouse_event(.none)
			}
		}
		.mouse_event_button {
			if enabled {
				self.terminal.flags.set_mouse_event(.button)
			} else {
				self.terminal.flags.set_mouse_event(.none)
			}
		}
		.mouse_event_any {
			if enabled {
				self.terminal.flags.set_mouse_event(.any)
			} else {
				self.terminal.flags.set_mouse_event(.none)
			}
		}
		.mouse_format_utf8 {
			self.terminal.flags.set_mouse_format(if enabled {
				MouseFormat.utf8
			} else {
				MouseFormat.x10
			})
		}
		.mouse_format_sgr {
			self.terminal.flags.set_mouse_format(if enabled {
				MouseFormat.sgr
			} else {
				MouseFormat.x10
			})
		}
		.mouse_format_urxvt {
			self.terminal.flags.set_mouse_format(if enabled {
				MouseFormat.urxvt
			} else {
				MouseFormat.x10
			})
		}
		.mouse_format_sgr_pixels {
			self.terminal.flags.set_mouse_format(if enabled {
				MouseFormat.sgr_pixels
			} else {
				MouseFormat.x10
			})
		}
		else {}
	}
}
