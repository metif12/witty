module terminal

// Stream processes VT escape sequences and dispatches actions.
//
// This is a translation of Ghostty's stream.zig. It takes a byte stream,
// parses escape sequences using VTParser, and produces a series of
// StreamEvents that represent terminal control actions.
//
// The stream collects events into an array. Callers process events after
// calling next_slice or next.

// ============================================================
// Action types
// ============================================================

// ActionKey identifies the type of stream action.
// These correspond to the possible actions that can be emitted by the
// stream for handling.
pub enum ActionKey {
	print
	print_repeat
	bell
	backspace
	horizontal_tab
	horizontal_tab_back
	linefeed
	carriage_return
	enquiry
	invoke_charset
	cursor_up
	cursor_down
	cursor_left
	cursor_right
	cursor_col
	cursor_row
	cursor_col_relative
	cursor_row_relative
	cursor_pos
	cursor_style
	erase_display_below
	erase_display_above
	erase_display_complete
	erase_display_scrollback
	erase_display_scroll_complete
	erase_line_right
	erase_line_left
	erase_line_complete
	erase_line_right_unless_pending_wrap
	delete_chars
	erase_chars
	insert_lines
	insert_blanks
	delete_lines
	scroll_up
	scroll_down
	tab_clear_current
	tab_clear_all
	tab_set
	tab_reset
	index
	next_line
	reverse_index
	full_reset
	set_mode
	reset_mode
	save_mode
	restore_mode
	request_mode
	request_mode_unknown
	top_and_bottom_margin
	left_and_right_margin
	left_and_right_margin_ambiguous
	save_cursor
	restore_cursor
	modify_key_format
	mouse_shift_capture
	protected_mode_off
	protected_mode_iso
	protected_mode_dec
	size_report
	title_push
	title_pop
	xtversion
	device_attributes
	device_status
	kitty_keyboard_query
	kitty_keyboard_push
	kitty_keyboard_pop
	kitty_keyboard_set
	kitty_keyboard_set_or
	kitty_keyboard_set_not
	dcs_hook
	dcs_put
	dcs_unhook
	apc_start
	apc_end
	apc_put
	end_hyperlink
	active_status_display
	decaln
	window_title
	report_pwd
	show_desktop_notification
	progress_report
	start_hyperlink
	clipboard_contents
	mouse_shape_action
	configure_charset
	set_attribute
	kitty_color_report
	color_operation
	semantic_prompt
}

// ActionPayload carries the value associated with a stream action.
// Only the field(s) relevant to the specific ActionKey are meaningful.
pub struct ActionPayload {
pub:
	// For .print
	cp u32
	// For cursor movements, counts, tab amounts, kitty_keyboard_pop,
	// title_push, title_pop, print_repeat, etc.
	num u16
	// Second numeric value (for cursor_pos col, margin bottom_right)
	num2 u16
	// Boolean flag (for erase protected, mouse_shift_capture)
	flag bool
	// Terminal mode (for mode operations)
	mode Mode
	// Cursor style (for .cursor_style)
	cursor_style AnsiCursorStyle
	// Modify key format (for .modify_key_format)
	modify_key_format ModifyKeyFormat
	// Device attribute request (for .device_attributes)
	device_attr DeviceAttributeReq
	// Size report style (for .size_report)
	size_report_style SizeReportStyle
	// Status display (for .active_status_display)
	status_display StatusDisplay
	// Mouse shape (for .mouse_shape_action)
	mouse_shape_val MouseShape
	// Charset bank GL/GR (for .invoke_charset)
	charset_bank ActiveSlot
	// Charset slot G0-G3 (for .invoke_charset, .configure_charset)
	charset_slot CharsetSlot
	// Charset (for .configure_charset)
	charset_val Charset
	// Charset locking flag (for .invoke_charset)
	charset_locking bool
	// SGR attribute (for .set_attribute)
	sgr SgrAttribute
	// Kitty keyboard flags (for .kitty_keyboard_push/set/set_or/set_not)
	kitty_flags u8
	// Raw mode + ansi flag (for .request_mode_unknown)
	raw_mode u16
	raw_ansi bool
	// String values (for .window_title, .report_pwd, .start_hyperlink, etc.)
	str1 string
	str2 string
	// Byte value (for .dcs_put, .apc_put)
	byte_val u8
	// Clipboard kind (for .clipboard_contents)
	clipboard_kind u8
	// DCS data (for .dcs_hook)
	dcs_intermediates []u8
	dcs_params        []u16
	dcs_final         u8
}

// StreamEvent represents a single event dispatched by the stream.
pub struct StreamEvent {
pub:
	key     ActionKey
	payload ActionPayload
}

// ============================================================
// Additional type definitions needed by the stream
// ============================================================

// AnsiCursorStyle represents cursor styles from DECSCUSR (CSI Ps SP q).
pub enum AnsiCursorStyle {
	default_
	blinking_block
	steady_block
	blinking_underline
	steady_underline
	blinking_bar
	steady_bar
}

// DeviceAttributeReq identifies a device attribute request type.
pub enum DeviceAttributeReq {
	primary
	secondary
	tertiary
}

// ModifyKeyFormat tracks the xterm modifyOtherKeys format.
pub enum ModifyKeyFormat {
	legacy
	cursor_keys
	function_keys
	other_keys_none
	other_keys_numeric
	other_keys_numeric_except
}

// SizeReportStyle identifies which CSI t size report was requested.
pub enum SizeReportStyle {
	csi_14_t
	csi_16_t
	csi_18_t
	csi_21_t
}

// DeviceStatusRequest identifies a device status report request.
pub enum DeviceStatusRequest {
	operating_status
	cursor_position
	color_scheme
}

// SemanticPromptAction identifies a semantic prompt action (OSC 133).
pub enum SemanticPromptAction {
	prompt_start
	input_start
	command_start
	command_end
}

// ProgressState for ConEmu progress reports.
pub enum ProgressState {
	remove
	set
	error_state
	indeterminate
	pause
}

// ============================================================
// Stream
// ============================================================

// Stream processes VT escape sequences and dispatches actions.
// Events are collected into the events array for processing.
pub struct Stream {
pub mut:
	parser VTParser
	utf8d  UTF8Decoder
	// Collected stream events
	events []StreamEvent
}

// init creates a new stream.
pub fn Stream.init() Stream {
	return Stream{}
}

// deinit frees resources.
pub fn (mut self Stream) deinit() {
	self.parser.deinit()
	self.events = []
}

// clear_events clears the collected events.
pub fn (mut self Stream) clear_events() {
	self.events.clear()
}

// ============================================================
// Byte processing
// ============================================================

// next_slice processes a string of bytes.
// In the Zig version, this has SIMD optimizations. Here we use
// the scalar path which processes one byte at a time.
pub fn (mut self Stream) next_slice(input_ []u8) {
	for c in input_ {
		self.next(c)
	}
}

// next processes a single byte.
pub fn (mut self Stream) next(c u8) {
	// If we're in ground state, decode UTF-8
	if self.parser.state == .ground {
		self.next_utf8(c)
		return
	}
	self.next_non_utf8(c)
}

// next_utf8 processes a byte in the UTF-8 decoding state (ground).
fn (mut self Stream) next_utf8(c u8) {
	res := self.utf8d.next(c)
	if cp := res.codepoint {
		self.handle_codepoint(cp)
	}
	if !res.consumed {
		// The byte was not consumed (invalid continuation).
		// Retry with the same byte after the decoder has been reset.
		retry := self.utf8d.next(c)
		if cp := retry.codepoint {
			self.handle_codepoint(cp)
		}
	}
}

// handle_codepoint processes a decoded codepoint.
fn (mut self Stream) handle_codepoint(c u32) {
	// ESC
	if c == 0x1B {
		self.parser.state = .escape
		self.parser.clear()
		return
	}
	// C0 control (0x00-0x1F)
	if c < 0x20 {
		self.execute(u8(c))
		return
	}
	// DEL
	if c == 0x7F {
		return
	}
	self.do_print(c)
}

// next_non_utf8 processes a byte when the parser is not in ground state.
fn (mut self Stream) next_non_utf8(c u8) {
	// Fast path for CSI entry: ESC [
	if self.parser.state == .escape && c == u8(`[`) {
		self.parser.state = .csi_entry
		return
	}

	// Fast path for CSI params
	if self.parser.state == .csi_param {
		// C0 escape (yes, this is valid)
		if c <= 0x0F {
			self.execute(c)
			return
		}
		// Ignored C0 escapes > 0xF
		if (c >= 0x10 && c <= 0x17) || c == 0x19 || (c >= 0x1C && c <= 0x1F) {
			return
		}
		// Move to ground on 0x18/0x1A
		if c == 0x18 || c == 0x1A {
			self.parser.state = .ground
			return
		}
		// Parameter digit
		if c >= u8(`0`) && c <= u8(`9`) {
			if self.parser.params_idx < max_params {
				v := u32(self.parser.param_acc) * 10 + u32(c - u8(`0`))
				self.parser.param_acc = if v > 65535 { u16(65535) } else { u16(v) }
				self.parser.param_acc_idx |= 1
			}
			return
		}
		// Parameter separator
		if c == u8(`:`) || c == u8(`;`) {
			if self.parser.params_idx < max_params {
				self.parser.params[self.parser.params_idx] = self.parser.param_acc
				if c == u8(`:`) {
					self.parser.params_sep.set(int(self.parser.params_idx))
				}
				self.parser.params_idx += 1
				self.parser.param_acc = 0
				self.parser.param_acc_idx = 0
			}
			return
		}
		// DEL is ignored
		if c == 0x7F {
			return
		}
		// Fall through to parser for other characters
	}

	// Normal path: call parser
	actions := self.parser.next(c)

	for action in actions {
		match action.action_type {
			.print_action {
				self.do_print(action.char)
			}
			.execute_action {
				self.execute(action.byte_val)
			}
			.csi_dispatch_action {
				self.csi_dispatch(action.csi)
			}
			.esc_dispatch_action {
				self.esc_dispatch(action.esc)
			}
			.osc_dispatch_action {
				self.osc_dispatch(action.osc)
			}
			.dcs_hook_action {
				self.dispatch(.dcs_hook, ActionPayload{
					dcs_intermediates: action.dcs.intermediates
					dcs_params: action.dcs.params
					dcs_final: action.dcs.final_byte
				})
			}
			.dcs_put_action {
				self.dispatch(.dcs_put, ActionPayload{ byte_val: action.byte_val })
			}
			.dcs_unhook_action {
				self.dispatch(.dcs_unhook, ActionPayload{})
			}
			.apc_start_action {
				self.dispatch(.apc_start, ActionPayload{})
			}
			.apc_put_action {
				self.dispatch(.apc_put, ActionPayload{ byte_val: action.byte_val })
			}
			.apc_end_action {
				self.dispatch(.apc_end, ActionPayload{})
			}
			.none {}
		}
	}
}

// ============================================================
// Dispatch helper
// ============================================================

fn (mut self Stream) dispatch(key ActionKey, payload ActionPayload) {
	self.events << StreamEvent{ key: key, payload: payload }
}

// ============================================================
// Print and Execute
// ============================================================

fn (mut self Stream) do_print(c u32) {
	self.dispatch(.print, ActionPayload{ cp: c })
}

fn (mut self Stream) execute(c u8) {
	// If the character is > 0x7F, it's a C1 (8-bit) control,
	// which is strictly equivalent to ESC plus c - 0x40.
	if c > 0x7F {
		self.esc_dispatch(ESCAction{
			intermediates: []
			final_byte: c - 0x40
		})
		return
	}

	// Map C0 control codes to actions
	// We ignore SOH/STX: https://github.com/microsoft/terminal/issues/10786
	if c == 0x00 || c == 0x01 || c == 0x02 {
		// NUL, SOH, STX - ignore
		return
	}
	if c == 0x05 {
		// ENQ
		self.dispatch(.enquiry, ActionPayload{})
		return
	}
	if c == 0x07 {
		// BEL
		self.dispatch(.bell, ActionPayload{})
		return
	}
	if c == 0x08 {
		// BS
		self.dispatch(.backspace, ActionPayload{})
		return
	}
	if c == 0x09 {
		// HT
		self.dispatch(.horizontal_tab, ActionPayload{ num: 1 })
		return
	}
	if c == 0x0A || c == 0x0B || c == 0x0C {
		// LF, VT, FF
		self.dispatch(.linefeed, ActionPayload{})
		return
	}
	if c == 0x0D {
		// CR
		self.dispatch(.carriage_return, ActionPayload{})
		return
	}
	if c == 0x0E {
		// SO - Shift Out
		self.dispatch(.invoke_charset, ActionPayload{
			charset_bank: .gl
			charset_slot: .g1
			charset_locking: false
		})
		return
	}
	if c == 0x0F {
		// SI - Shift In
		self.dispatch(.invoke_charset, ActionPayload{
			charset_bank: .gl
			charset_slot: .g0
			charset_locking: false
		})
		return
	}
	// Other C0 controls are ignored
}

// ============================================================
// CSI Dispatch
// ============================================================

// csi_dispatch handles a CSI (Control Sequence Introducer) action.
// This is the main dispatch for CSI sequences which make up the
// majority of terminal control sequences.
fn (mut self Stream) csi_dispatch(input CSIAction) {
	match input.final_byte {
		// CUU - Cursor Up
		u8(`A`), u8(`k`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.cursor_up, ActionPayload{ num: val })
			}
		}
		// CUD - Cursor Down
		u8(`B`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.cursor_down, ActionPayload{ num: val })
			}
		}
		// CUF - Cursor Right
		u8(`C`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.cursor_right, ActionPayload{ num: val })
			}
		}
		// CUB - Cursor Left
		u8(`D`), u8(`j`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.cursor_left, ActionPayload{ num: val })
			}
		}
		// CNL - Cursor Next Line
		u8(`E`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.cursor_down, ActionPayload{ num: val })
				self.dispatch(.carriage_return, ActionPayload{})
			}
		}
		// CPL - Cursor Previous Line
		u8(`F`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.cursor_up, ActionPayload{ num: val })
				self.dispatch(.carriage_return, ActionPayload{})
			}
		}
		// HPA - Cursor Horizontal Position Absolute
		u8(`G`), u8(`\``) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.cursor_col, ActionPayload{ num: val })
			}
		}
		// CUP - Set Cursor Position
		u8(`H`), u8(`f`) {
			if input.intermediates.len == 0 {
				row, col := self.csi_two_params(input, 1, 1) or { return }
				self.dispatch(.cursor_pos, ActionPayload{ num: row, num2: col })
			}
		}
		// CHT - Cursor Horizontal Tabulation
		u8(`I`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.horizontal_tab, ActionPayload{ num: val })
			}
		}
		// Erase Display
		u8(`J`) {
			self.csi_erase_display(input)
		}
		// Erase Line
		u8(`K`) {
			self.csi_erase_line(input)
		}
		// IL - Insert Lines
		u8(`L`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.insert_lines, ActionPayload{ num: val })
			}
		}
		// DL - Delete Lines
		u8(`M`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.delete_lines, ActionPayload{ num: val })
			}
		}
		// DCH - Delete Character
		u8(`P`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.delete_chars, ActionPayload{ num: val })
			}
		}
		// SU - Scroll Up
		u8(`S`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.scroll_up, ActionPayload{ num: val })
			}
		}
		// SD - Scroll Down
		u8(`T`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.scroll_down, ActionPayload{ num: val })
			}
		}
		// Cursor Tabulation Control
		u8(`W`) {
			self.csi_tab_control(input)
		}
		// ECH - Erase Characters
		u8(`X`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.erase_chars, ActionPayload{ num: val })
			}
		}
		// CBT - Cursor Horizontal Tabulation Back
		u8(`Z`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.horizontal_tab_back, ActionPayload{ num: val })
			}
		}
		// HPR - Cursor Horizontal Position Relative
		u8(`a`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.cursor_col_relative, ActionPayload{ num: val })
			}
		}
		// REP - Repeat Previous Char
		u8(`b`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.print_repeat, ActionPayload{ num: val })
			}
		}
		// DA - Device Attributes
		u8(`c`) {
			self.csi_device_attributes(input)
		}
		// VPA - Cursor Vertical Position Absolute
		u8(`d`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.cursor_row, ActionPayload{ num: val })
			}
		}
		// VPR - Cursor Vertical Position Relative
		u8(`e`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.cursor_row_relative, ActionPayload{ num: val })
			}
		}
		// TBC - Tab Clear
		u8(`g`) {
			if input.intermediates.len == 0 && input.params.len == 1 {
				if input.params[0] == 0 {
					self.dispatch(.tab_clear_current, ActionPayload{})
				} else if input.params[0] == 3 {
					self.dispatch(.tab_clear_all, ActionPayload{})
				}
			}
		}
		// SM - Set Mode
		u8(`h`) {
			self.csi_set_reset_mode(input, true)
		}
		// RM - Reset Mode
		u8(`l`) {
			self.csi_set_reset_mode(input, false)
		}
		// SGR - Select Graphic Rendition
		u8(`m`) {
			self.csi_sgr(input)
		}
		// DSR and CSI > n
		u8(`n`) {
			self.csi_dsr(input)
		}
		// DECRQM - Request Mode
		u8(`p`) {
			self.csi_request_mode(input)
		}
		// DECSCUSR / DECSCA / XTVERSION
		u8(`q`) {
			self.csi_q(input)
		}
		// DECSTBM / Restore Mode
		u8(`r`) {
			self.csi_r(input)
		}
		// DECSLRM / Save Mode / XTSHIFTESCAPE
		u8(`s`) {
			self.csi_s(input)
		}
		// XTWINOPS
		u8(`t`) {
			self.csi_t(input)
		}
		// SCORC / Kitty keyboard
		u8(`u`) {
			self.csi_u(input)
		}
		// ICH - Insert Blanks
		u8(`@`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.insert_blanks, ActionPayload{ num: val })
			}
		}
		// DECSASD - Select Active Status Display
		u8(`}`) {
			if input.intermediates.len == 1 && input.intermediates[0] == u8(`$`)
				&& input.params.len == 1 {
				if input.params[0] == 0 {
					self.dispatch(.active_status_display, ActionPayload{
						status_display: .main
					})
				} else if input.params[0] == 1 {
					self.dispatch(.active_status_display, ActionPayload{
						status_display: .status_line
					})
				}
			}
		}
		else {}
	}
}

// ============================================================
// CSI dispatch helpers
// ============================================================

// csi_single_param extracts a single u16 param with a default value.
// Returns none if there are too many params.
fn (self &Stream) csi_single_param(input CSIAction, default_val u16) ?u16 {
	return match input.params.len {
		0 { default_val }
		1 { input.params[0] }
		else { none }
	}
}

// csi_two_params extracts two u16 params with default values.
// Returns none if there are too many params.
fn (self &Stream) csi_two_params(input CSIAction, def1 u16, def2 u16) ?(u16, u16) {
	return match input.params.len {
		0 { def1, def2 }
		1 { input.params[0], def2 }
		2 { input.params[0], input.params[1] }
		else { none }
	}
}

fn (mut self Stream) csi_erase_display(input CSIAction) {
	// Determine if protected mode
	protected_ := if input.intermediates.len == 0 {
		false
	} else if input.intermediates.len == 1 && input.intermediates[0] == u8(`?`) {
		true
	} else {
		return
	}

	// Determine erase mode
	mode_val := if input.params.len == 0 {
		0
	} else if input.params.len == 1 {
		int(input.params[0])
	} else {
		return
	}

	key := match mode_val {
		0 { ActionKey.erase_display_below }
		1 { ActionKey.erase_display_above }
		2 { ActionKey.erase_display_complete }
		3 { ActionKey.erase_display_scrollback }
		4 { ActionKey.erase_display_scroll_complete }
		else { return }
	}

	self.dispatch(key, ActionPayload{ flag: protected_ })
}

fn (mut self Stream) csi_erase_line(input CSIAction) {
	protected_ := if input.intermediates.len == 0 {
		false
	} else if input.intermediates.len == 1 && input.intermediates[0] == u8(`?`) {
		true
	} else {
		return
	}

	mode_val := if input.params.len == 0 {
		0
	} else if input.params.len == 1 {
		int(input.params[0])
	} else {
		return
	}

	key := match mode_val {
		0 { ActionKey.erase_line_right }
		1 { ActionKey.erase_line_left }
		2 { ActionKey.erase_line_complete }
		else { return }
	}

	self.dispatch(key, ActionPayload{ flag: protected_ })
}

fn (mut self Stream) csi_tab_control(input CSIAction) {
	if input.intermediates.len == 0 {
		if input.params.len == 0 || (input.params.len == 1 && input.params[0] == 0) {
			self.dispatch(.tab_set, ActionPayload{})
			return
		}
		if input.params.len == 1 {
			if input.params[0] == 2 {
				self.dispatch(.tab_clear_current, ActionPayload{})
			} else if input.params[0] == 5 {
				self.dispatch(.tab_clear_all, ActionPayload{})
			}
		}
	} else if input.intermediates.len == 1 && input.intermediates[0] == u8(`?`)
		&& input.params.len == 1 && input.params[0] == 5 {
		self.dispatch(.tab_reset, ActionPayload{})
	}
}

fn (mut self Stream) csi_set_reset_mode(input CSIAction, set bool) {
	// Determine if this is ANSI or DEC private mode
	is_ansi := if input.intermediates.len == 0 {
		true
	} else if input.intermediates.len == 1 && input.intermediates[0] == u8(`?`) {
		false
	} else {
		return
	}

	action_key := if set { ActionKey.set_mode } else { ActionKey.reset_mode }

	for param in input.params {
		if m := mode_from_int(param, is_ansi) {
			self.dispatch(action_key, ActionPayload{ mode: m })
		}
	}
}

fn (mut self Stream) csi_sgr(input CSIAction) {
	if input.intermediates.len == 0 {
		// Standard SGR
		mut p := SgrParser{
			params: input.params
			params_sep: input.params_sep
		}
		for {
			attr := p.next() or { break }
			self.dispatch(.set_attribute, ActionPayload{ sgr: attr })
		}
	} else if input.intermediates.len == 1 && input.intermediates[0] == u8(`>`) {
		// CSI > m - modify key format
		if input.params.len == 0 {
			self.dispatch(.modify_key_format, ActionPayload{
				modify_key_format: .legacy
			})
			return
		}
		format := match input.params[0] {
			0 { ModifyKeyFormat.legacy }
			1 { ModifyKeyFormat.cursor_keys }
			2 { ModifyKeyFormat.function_keys }
			4 { ModifyKeyFormat.other_keys_none }
			else { return }
		}

		mut final_format := format
		if input.params.len == 2 && format == .other_keys_none && input.params[1] == 2 {
			final_format = .other_keys_numeric
		} else if input.params.len > 2 {
			return
		}
		self.dispatch(.modify_key_format, ActionPayload{
			modify_key_format: final_format
		})
	}
}

fn (mut self Stream) csi_dsr(input CSIAction) {
	if input.intermediates.len == 0 || (input.intermediates.len == 1
		&& input.intermediates[0] == u8(`?`)) {
		if input.params.len != 1 {
			return
		}
		question := input.intermediates.len == 1 && input.intermediates[0] == u8(`?`)

		if req := device_status_req_from_int(input.params[0], question) {
			self.dispatch(.device_status, ActionPayload{
				// XTODO: proper device status request payload
				num: input.params[0]
				flag: question
			})
		}
		return
	}

	if input.intermediates.len == 1 && input.intermediates[0] == u8(`>`) {
		// CSI > n - revert modify other keys
		self.dispatch(.modify_key_format, ActionPayload{
			modify_key_format: .other_keys_numeric_except
		})
	}
}

fn (mut self Stream) csi_request_mode(input CSIAction) {
	if input.intermediates.len != 2 {
		return
	}

	is_ansi := if input.intermediates[0] == u8(`$`) {
		true
	} else if input.intermediates[0] == u8(`?`) && input.intermediates[1] == u8(`$`) {
		false
	} else {
		return
	}

	if input.params.len != 1 {
		return
	}

	mode_raw := input.params[0]
	if m := mode_from_int(mode_raw, is_ansi) {
		self.dispatch(.request_mode, ActionPayload{ mode: m })
	} else {
		self.dispatch(.request_mode_unknown, ActionPayload{
			raw_mode: mode_raw
			raw_ansi: is_ansi
		})
	}
}

fn (mut self Stream) csi_device_attributes(input CSIAction) {
	req := if input.intermediates.len == 0 {
		DeviceAttributeReq.primary
	} else if input.intermediates.len == 1 {
		match input.intermediates[0] {
			u8(`>`) { DeviceAttributeReq.secondary }
			u8(`=`) { DeviceAttributeReq.tertiary }
			else { return }
		}
	} else {
		return
	}
	self.dispatch(.device_attributes, ActionPayload{ device_attr: req })
}

fn (mut self Stream) csi_q(input CSIAction) {
	if input.intermediates.len != 1 {
		return
	}
	match input.intermediates[0] {
		// DECSCUSR - Select Cursor Style
		u8(` `) {
			style := match input.params.len {
				0 {
					AnsiCursorStyle.default_
				}
				1 {
					match input.params[0] {
						0 { AnsiCursorStyle.default_ }
						1 { AnsiCursorStyle.blinking_block }
						2 { AnsiCursorStyle.steady_block }
						3 { AnsiCursorStyle.blinking_underline }
						4 { AnsiCursorStyle.steady_underline }
						5 { AnsiCursorStyle.blinking_bar }
						6 { AnsiCursorStyle.steady_bar }
						else { return }
					}
				}
				else {
					return
				}
			}
			self.dispatch(.cursor_style, ActionPayload{ cursor_style: style })
		}
		// DECSCA - Select Character Protection Attribute
		u8(`"`) {
			pm := match input.params.len {
				0 {
					ActionKey.protected_mode_off
				}
				1 {
					match input.params[0] {
						0, 2 { ActionKey.protected_mode_off }
						1 { ActionKey.protected_mode_dec }
						else { return }
					}
				}
				else {
					return
				}
			}
			self.dispatch(pm, ActionPayload{})
		}
		// XTVERSION
		u8(`>`) {
			self.dispatch(.xtversion, ActionPayload{})
		}
		else {}
	}
}

fn (mut self Stream) csi_r(input CSIAction) {
	match input.intermediates.len {
		// DECSTBM - Set Top and Bottom Margins
		0 {
			top, bottom := self.csi_two_params(input, 0, 0) or { return }
			self.dispatch(.top_and_bottom_margin, ActionPayload{
				num: top
				num2: bottom
			})
		}
		1 {
			if input.intermediates[0] == u8(`?`) {
				// Restore Mode
				for param in input.params {
					if m := mode_from_int(param, false) {
						self.dispatch(.restore_mode, ActionPayload{ mode: m })
					}
				}
			}
		}
		else {}
	}
}

fn (mut self Stream) csi_s(input CSIAction) {
	match input.intermediates.len {
		// DECSLRM
		0 {
			match input.params.len {
				0 {
					self.dispatch(.left_and_right_margin_ambiguous, ActionPayload{})
				}
				1 {
					self.dispatch(.left_and_right_margin, ActionPayload{
						num: input.params[0]
						num2: 0
					})
				}
				2 {
					self.dispatch(.left_and_right_margin, ActionPayload{
						num: input.params[0]
						num2: input.params[1]
					})
				}
				else {}
			}
		}
		1 {
			match input.intermediates[0] {
				u8(`?`) {
					// Save Mode
					for param in input.params {
						if m := mode_from_int(param, false) {
							self.dispatch(.save_mode, ActionPayload{ mode: m })
						}
					}
				}
				u8(`>`) {
					// XTSHIFTESCAPE
					capture := if input.params.len == 0 {
						false
					} else if input.params.len == 1 {
						match input.params[0] {
							0 { false }
							1 { true }
							else { return }
						}
					} else {
						return
					}
					self.dispatch(.mouse_shift_capture, ActionPayload{ flag: capture })
				}
				else {}
			}
		}
		else {}
	}
}

fn (mut self Stream) csi_t(input CSIAction) {
	if input.intermediates.len != 0 {
		return
	}
	if input.params.len == 0 {
		return
	}

	match input.params[0] {
		14 {
			if input.params.len == 1 {
				self.dispatch(.size_report, ActionPayload{
					size_report_style: .csi_14_t
				})
			}
		}
		16 {
			if input.params.len == 1 {
				self.dispatch(.size_report, ActionPayload{
					size_report_style: .csi_16_t
				})
			}
		}
		18 {
			if input.params.len == 1 {
				self.dispatch(.size_report, ActionPayload{
					size_report_style: .csi_18_t
				})
			}
		}
		21 {
			if input.params.len == 1 {
				self.dispatch(.size_report, ActionPayload{
					size_report_style: .csi_21_t
				})
			}
		}
		22, 23 {
			// Push/pop title
			if (input.params.len == 2 || input.params.len == 3)
				&& (input.params[1] == 0 || input.params[1] == 2) {
				idx := if input.params.len == 3 { input.params[2] } else { u16(0) }
				key := if input.params[0] == 22 {
					ActionKey.title_push
				} else {
					ActionKey.title_pop
				}
				self.dispatch(key, ActionPayload{ num: idx })
			}
		}
		else {}
	}
}

fn (mut self Stream) csi_u(input CSIAction) {
	match input.intermediates.len {
		0 {
			// SCORC - Restore Cursor
			self.dispatch(.restore_cursor, ActionPayload{})
		}
		1 {
			match input.intermediates[0] {
				u8(`?`) {
					// Kitty keyboard query
					self.dispatch(.kitty_keyboard_query, ActionPayload{})
				}
				u8(`>`) {
					// Kitty keyboard push
					flags := if input.params.len == 1 {
						if input.params[0] > 31 { return }
						u8(input.params[0])
					} else {
						u8(0)
					}
					self.dispatch(.kitty_keyboard_push, ActionPayload{
						kitty_flags: flags
					})
				}
				u8(`<`) {
					// Kitty keyboard pop
					number := if input.params.len == 1 { input.params[0] } else { u16(1) }
					self.dispatch(.kitty_keyboard_pop, ActionPayload{ num: number })
				}
				u8(`=`) {
					// Kitty keyboard set
					flags := if input.params.len >= 1 {
						if input.params[0] > 31 { return }
						u8(input.params[0])
					} else {
						u8(0)
					}
					number := if input.params.len >= 2 { input.params[1] } else { u16(1) }
					key := match number {
						1 { ActionKey.kitty_keyboard_set }
						2 { ActionKey.kitty_keyboard_set_or }
						3 { ActionKey.kitty_keyboard_set_not }
						else { return }
					}
					self.dispatch(key, ActionPayload{ kitty_flags: flags })
				}
				else {}
			}
		}
		else {}
	}
}

// ============================================================
// OSC Dispatch
// ============================================================

fn (mut self Stream) osc_dispatch(cmd OscCommand) {
	match cmd.cmd_type {
		.change_window_title {
			if !is_valid_utf8(cmd.data) {
				return
			}
			self.dispatch(.window_title, ActionPayload{ str1: cmd.data })
		}
		.change_window_icon {
			// Ignored (icon not supported)
		}
		.clipboard_contents {
			// XTODO: parse clipboard kind from data
			self.dispatch(.clipboard_contents, ActionPayload{
				str1: cmd.data
			})
		}
		.report_pwd {
			self.dispatch(.report_pwd, ActionPayload{ str1: cmd.data })
		}
		.mouse_shape {
			if ms := mouse_shape_from_string(cmd.data) {
				self.dispatch(.mouse_shape_action, ActionPayload{
					mouse_shape_val: ms
				})
			}
		}
		.hyperlink_start {
			self.dispatch(.start_hyperlink, ActionPayload{
				str1: cmd.data
				str2: cmd.data2
			})
		}
		.hyperlink_end {
			self.dispatch(.end_hyperlink, ActionPayload{})
		}
		.show_desktop_notification {
			// XTODO: parse title/body from data
			self.dispatch(.show_desktop_notification, ActionPayload{
				str1: cmd.data
			})
		}
		.semantic_prompt {
			// XTODO: parse semantic prompt action from data
		}
		.color_operation {
			// XTODO: color operations
		}
		.kitty_color_protocol {
			// XTODO: kitty color protocol
		}
		.conemu_progress_report {
			// XTODO: progress reports
		}
		.conemu_ignored, .kitty_text_sizing {
			// Ignored
		}
		.invalid {}
	}
}

// ============================================================
// ESC Dispatch
// ============================================================

fn (mut self Stream) esc_dispatch(action ESCAction) {
	match action.final_byte {
		// Charsets
		u8(`B`) {
			self.configure_charset(action.intermediates, .ascii)
		}
		u8(`A`) {
			self.configure_charset(action.intermediates, .british)
		}
		u8(`0`) {
			self.configure_charset(action.intermediates, .dec_special)
		}
		// DECSC - Save Cursor
		u8(`7`) {
			if action.intermediates.len == 0 {
				self.dispatch(.save_cursor, ActionPayload{})
			}
		}
		u8(`8`) {
			if action.intermediates.len == 0 {
				// DECRC - Restore Cursor
				self.dispatch(.restore_cursor, ActionPayload{})
			} else if action.intermediates.len == 1 && action.intermediates[0] == u8(`#`) {
				// DECALN - Fill Screen with E
				self.dispatch(.decaln, ActionPayload{})
			}
		}
		// IND - Index
		u8(`D`) {
			if action.intermediates.len == 0 {
				self.dispatch(.index, ActionPayload{})
			}
		}
		// NEL - Next Line
		u8(`E`) {
			if action.intermediates.len == 0 {
				self.dispatch(.next_line, ActionPayload{})
			}
		}
		// HTS - Horizontal Tab Set
		u8(`H`) {
			if action.intermediates.len == 0 {
				self.dispatch(.tab_set, ActionPayload{})
			}
		}
		// RI - Reverse Index
		u8(`M`) {
			if action.intermediates.len == 0 {
				self.dispatch(.reverse_index, ActionPayload{})
			}
		}
		// SS2 - Single Shift 2
		u8(`N`) {
			if action.intermediates.len == 0 {
				self.dispatch(.invoke_charset, ActionPayload{
					charset_bank: .gl
					charset_slot: .g2
					charset_locking: true
				})
			}
		}
		// SS3 - Single Shift 3
		u8(`O`) {
			if action.intermediates.len == 0 {
				self.dispatch(.invoke_charset, ActionPayload{
					charset_bank: .gl
					charset_slot: .g3
					charset_locking: true
				})
			}
		}
		// SPA - Start of Guarded Area
		u8(`V`) {
			if action.intermediates.len == 0 {
				self.dispatch(.protected_mode_iso, ActionPayload{})
			}
		}
		// EPA - End of Guarded Area
		u8(`W`) {
			if action.intermediates.len == 0 {
				self.dispatch(.protected_mode_off, ActionPayload{})
			}
		}
		// DECID
		u8(`Z`) {
			if action.intermediates.len == 0 {
				self.dispatch(.device_attributes, ActionPayload{
					device_attr: .primary
				})
			}
		}
		// RIS - Full Reset
		u8(`c`) {
			if action.intermediates.len == 0 {
				self.dispatch(.full_reset, ActionPayload{})
			}
		}
		// LS2 - Locking Shift 2
		u8(`n`) {
			if action.intermediates.len == 0 {
				self.dispatch(.invoke_charset, ActionPayload{
					charset_bank: .gl
					charset_slot: .g2
					charset_locking: false
				})
			}
		}
		// LS3 - Locking Shift 3
		u8(`o`) {
			if action.intermediates.len == 0 {
				self.dispatch(.invoke_charset, ActionPayload{
					charset_bank: .gl
					charset_slot: .g3
					charset_locking: false
				})
			}
		}
		// LS1R - Locking Shift 1 Right
		u8(`~`) {
			if action.intermediates.len == 0 {
				self.dispatch(.invoke_charset, ActionPayload{
					charset_bank: .gr
					charset_slot: .g1
					charset_locking: false
				})
			}
		}
		// LS2R - Locking Shift 2 Right
		u8(`}`) {
			if action.intermediates.len == 0 {
				self.dispatch(.invoke_charset, ActionPayload{
					charset_bank: .gr
					charset_slot: .g2
					charset_locking: false
				})
			}
		}
		// LS3R - Locking Shift 3 Right
		u8(`|`) {
			if action.intermediates.len == 0 {
				self.dispatch(.invoke_charset, ActionPayload{
					charset_bank: .gr
					charset_slot: .g3
					charset_locking: false
				})
			}
		}
		// Set application keypad mode
		u8(`=`) {
			if action.intermediates.len == 0 {
				if m := mode_from_int(66, false) {
					// keypad_keys mode - use set_mode
					self.dispatch(.set_mode, ActionPayload{ mode: m })
				}
			}
		}
		// Reset application keypad mode
		u8(`>`) {
			if action.intermediates.len == 0 {
				if m := mode_from_int(66, false) {
					self.dispatch(.reset_mode, ActionPayload{ mode: m })
				}
			}
		}
		// ST (String Terminator) - no-op, parser always accepts ST
		u8(`\\`) {}
		else {}
	}
}

fn (mut self Stream) configure_charset(intermediates []u8, charset Charset) {
	if intermediates.len != 1 {
		return
	}
	slot := match intermediates[0] {
		u8(`(`) { CharsetSlot.g0 }
		u8(`)`) { CharsetSlot.g1 }
		u8(`*`) { CharsetSlot.g2 }
		u8(`+`) { CharsetSlot.g3 }
		else { return }
	}
	self.dispatch(.configure_charset, ActionPayload{
		charset_slot: slot
		charset_val: charset
	})
}

// ============================================================
// Mode mapping
// ============================================================

// mode_from_int maps a mode integer (from CSI params) to a terminal Mode.
// ansi_mode is true for ANSI modes (no ? prefix), false for DEC private modes.
// Returns none if the mode is not recognized.
pub fn mode_from_int(mode_int u16, ansi_mode bool) ?Mode {
	if ansi_mode {
		return match mode_int {
			4 { Mode.insert }
			20 { Mode.linefeed }
			else { none }
		}
	}
	// DEC private modes
	return match mode_int {
		3 { Mode.column_132 }
		6 { Mode.origin }
		7 { Mode.wraparound }
		25 { Mode.cursor_visible }
		40 { Mode.enable_mode_3 }
		45 { Mode.reverse_wrap }
		69 { Mode.enable_left_and_right_margin }
		95 { Mode.reverse_wrap_extended }
		1004 { Mode.focus_event }
		2004 { Mode.bracketed_paste }
		2027 { Mode.grapheme_cluster }
		else { none }
	}
}

// device_status_req_from_int maps a DSR parameter to a device status request.
pub fn device_status_req_from_int(param u16, question bool) ?DeviceStatusRequest {
	if !question {
		return match param {
			5 { DeviceStatusRequest.operating_status }
			6 { DeviceStatusRequest.cursor_position }
			else { none }
		}
	}
	// DEC private DSR
	return match param {
		6 { DeviceStatusRequest.cursor_position }
		else { none }
	}
}

// mouse_shape_from_string converts a string to a MouseShape.
pub fn mouse_shape_from_string(s string) ?MouseShape {
	return match s {
		'default' { MouseShape.default_ }
		'text' { MouseShape.text }
		'pointer' { MouseShape.pointer }
		'crosshair' { MouseShape.crosshair }
		'help' { MouseShape.help }
		'progress' { MouseShape.progress }
		else { none }
	}
}

// ============================================================
// SGR Parser
// ============================================================

// SgrParser iterates through CSI params to produce SGR attributes.
pub struct SgrParser {
pub:
	params     []u16
	params_sep SepList
pub mut:
	idx int
}

// next returns the next SGR attribute, or none if exhausted.
pub fn (mut self SgrParser) next() ?SgrAttribute {
	if self.idx >= self.params.len {
		return none
	}

	p := self.params[self.idx]
	self.idx += 1

	return match p {
		0 { SgrAttribute{ kind: .unset } }
		1 { SgrAttribute{ kind: .bold } }
		2 { SgrAttribute{ kind: .faint } }
		3 { SgrAttribute{ kind: .italic } }
		4 {
			// Underline - check for colon subparam
			self.parse_underline()
		}
		5 { SgrAttribute{ kind: .blink } }
		7 { SgrAttribute{ kind: .inverse } }
		8 { SgrAttribute{ kind: .invisible } }
		9 { SgrAttribute{ kind: .strikethrough } }
		21 { SgrAttribute{ kind: .underline_set, underline: .double } }
		22 { SgrAttribute{ kind: .reset_bold } }
		23 { SgrAttribute{ kind: .reset_italic } }
		24 { SgrAttribute{ kind: .underline_set, underline: .none } }
		25 { SgrAttribute{ kind: .reset_blink } }
		27 { SgrAttribute{ kind: .reset_inverse } }
		28 { SgrAttribute{ kind: .reset_invisible } }
		29 { SgrAttribute{ kind: .reset_strikethrough } }
		30, 31, 32, 33, 34, 35, 36, 37 {
			SgrAttribute{ kind: .fg_8, index: u8(p - 30) }
		}
		38 {
			self.parse_extended_color(.direct_color_fg, .fg_256)
		}
		39 { SgrAttribute{ kind: .reset_fg } }
		40, 41, 42, 43, 44, 45, 46, 47 {
			SgrAttribute{ kind: .bg_8, index: u8(p - 40) }
		}
		48 {
			self.parse_extended_color(.direct_color_bg, .bg_256)
		}
		49 { SgrAttribute{ kind: .reset_bg } }
		53 { SgrAttribute{ kind: .overline } }
		55 { SgrAttribute{ kind: .reset_overline } }
		58 {
			self.parse_extended_color(.underline_color, .underline_color_256)
		}
		59 { SgrAttribute{ kind: .reset_underline_color } }
		90, 91, 92, 93, 94, 95, 96, 97 {
			SgrAttribute{ kind: .bright_fg_8, index: u8(p - 90) }
		}
		100, 101, 102, 103, 104, 105, 106, 107 {
			SgrAttribute{ kind: .bright_bg_8, index: u8(p - 100) }
		}
		else {
			SgrAttribute{ kind: .unknown }
		}
	}
}

// parse_underline handles SGR code 4 with optional colon subparam for underline style.
fn (mut self SgrParser) parse_underline() SgrAttribute {
	mut style := UnderlineStyle.single
	if self.idx < self.params.len && self.params_sep.is_set(self.idx - 1) {
		sub := self.params[self.idx]
		self.idx += 1
		style = match sub {
			0 { UnderlineStyle.none }
			1 { UnderlineStyle.single }
			2 { UnderlineStyle.double }
			3 { UnderlineStyle.curly }
			4 { UnderlineStyle.dotted }
			5 { UnderlineStyle.dashed }
			else { UnderlineStyle.single }
		}
	}
	return SgrAttribute{ kind: .underline_set, underline: style }
}

// parse_extended_color parses 38;2;r;g;b (direct) or 38;5;n (256-color).
fn (mut self SgrParser) parse_extended_color(direct_kind SgrAttributeKind, indexed_kind SgrAttributeKind) SgrAttribute {
	if self.idx >= self.params.len {
		return SgrAttribute{ kind: .unknown }
	}

	// Check if using colon separator (38:2:r:g:b)
	is_colon := self.params_sep.is_set(self.idx - 1)

	sub := self.params[self.idx]
	self.idx += 1

	if sub == 2 {
		// Direct color: 38;2;r;g;b or 38:2:r:g:b
		// With colon, there may be a colorspace param: 38:2:cs:r:g:b
		if is_colon && self.idx + 3 <= self.params.len {
			// Skip optional colorspace ID
			if self.idx + 4 <= self.params.len {
				// Has colorspace param
				self.idx += 1 // skip colorspace
			}
		}
		if self.idx + 2 < self.params.len {
			r := u8(self.params[self.idx])
			g := u8(self.params[self.idx + 1])
			b := u8(self.params[self.idx + 2])
			self.idx += 3
			return SgrAttribute{
				kind: direct_kind
				r: r
				g: g
				b: b
			}
		}
		return SgrAttribute{ kind: .unknown }
	} else if sub == 5 {
		// 256-color: 38;5;n
		if self.idx < self.params.len {
			n := u8(self.params[self.idx])
			self.idx += 1
			return SgrAttribute{ kind: indexed_kind, index: n }
		}
		return SgrAttribute{ kind: .unknown }
	}

	return SgrAttribute{ kind: .unknown }
}

// ============================================================
// UTF-8 validation helper
// ============================================================

// is_valid_utf8 checks if a string contains valid UTF-8.
fn is_valid_utf8(s string) bool {
	mut i := 0
	for i < s.len {
		b := s[i]
		if b < 0x80 {
			i += 1
		} else if b & 0xE0 == 0xC0 {
			if i + 1 >= s.len || s[i + 1] & 0xC0 != 0x80 {
				return false
			}
			// Overlong check
			cp := (u32(b & 0x1F) << 6) | u32(s[i + 1] & 0x3F)
			if cp < 0x80 {
				return false
			}
			i += 2
		} else if b & 0xF0 == 0xE0 {
			if i + 2 >= s.len || s[i + 1] & 0xC0 != 0x80 || s[i + 2] & 0xC0 != 0x80 {
				return false
			}
			cp := (u32(b & 0x0F) << 12) | (u32(s[i + 1] & 0x3F) << 6) | u32(s[i + 2] & 0x3F)
			if cp < 0x800 || (cp >= 0xD800 && cp <= 0xDFFF) {
				return false
			}
			i += 3
		} else if b & 0xF8 == 0xF0 {
			if i + 3 >= s.len || s[i + 1] & 0xC0 != 0x80 || s[i + 2] & 0xC0 != 0x80
				|| s[i + 3] & 0xC0 != 0x80 {
				return false
			}
			cp := (u32(b & 0x07) << 18) | (u32(s[i + 1] & 0x3F) << 12) | (u32(s[i + 2] & 0x3F) << 6) | u32(s[i + 3] & 0x3F)
			if cp < 0x10000 || cp > 0x10FFFF {
				return false
			}
			i += 4
		} else {
			return false
		}
	}
	return true
}
