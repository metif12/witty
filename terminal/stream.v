module terminal

import encoding.utf8.validate
import osc
import simd

// --- Original Ghostty Comments Start: src/terminal/stream.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/terminal/stream.zig
//
// Flip this to true when you want verbose debug output for
// debugging terminal stream issues. In addition to louder
// output this will also disable the SIMD optimizations in
// order to make it easier to see every byte. So if you're
// debugging an issue in the SIMD code then you'll need to
// do something else.
// The possible actions that can be emitted by the Stream
// function for handling.
// C ABI functions.
// TODO: Before shipping an ABI-compatible libghostty, verify this.
// This was just arbitrarily chosen for now.
// Field types
// The value of the cursor movement. Depending on the tag of this
// union this may be an absolute value or it may be a relative
// value. For example, `cursor_up` is relative, but `cursor_row`
// is absolute.
// Returns a type that can process a stream of tty control characters.
// This will call the `vt` function on type T with the following signature:
//
//   fn(comptime action: Action.Key, value: Action.Value(action)) !void
//
// The handler type T can choose to react to whatever actions it cares
// about in its pursuit of implementing a terminal emulator or other
// functionality.
//
// The Handler type must also have a `deinit` function.
//
// The "comptime" key is on purpose (vs. a standard Zig tagged union)
// because it allows the compiler to optimize away unimplemented actions.
// e.g. you don't need to pay a conditional branching cost on every single
// action because the Zig compiler codegens separate code paths for every
// single action at comptime.
// Initialize an allocation-free stream. This will preallocate various
// sizes as necessary and anything over that will be dropped. If you
// want to support more dynamic behavior use initAlloc instead.
//
// As a concrete example of something that requires heap allocation,
// consider OSC 52 (clipboard operations) which can be arbitrarily
// large.
//
// If you want to limit allocation size, use an allocator with
// a size limit with initAlloc.
//
// This takes ownership of the handler and will call deinit
// when the stream is deinitialized.
// Initialize the stream that supports heap allocation as necessary.
// Process a string of characters.
// Disable SIMD optimizations if build requests it or if our
// manual debug mode is on.
// This is the maximum number of codepoints we can decode
// at one time for this function call. This is somewhat arbitrary
// so if someone can demonstrate a better number then we can switch.
// Split the input into chunks that fit into cp_buf.
// If the scalar UTF-8 decoder was in the middle of processing
// a code sequence, we continue until it's not.
// If we're not in the ground state then we process until
// we are. This can happen if the last chunk of input put us
// in the middle of a control sequence.
// If we're in the ground state then we can use SIMD to process
// input until we see an ESC (0x1B), since all other characters
// up to that point are just UTF-8.
// Consume the bytes we just processed.
// If our offset is NOT an escape then we must have a
// partial UTF-8 sequence. In that case, we pass it off
// to the scalar parser.
// Process control sequences until we run out.
// Parses back-to-back escape sequences until none are left.
// Returns the number of bytes consumed from the provided input.
//
// Expects input to start with 0x1B, use consumeUntilGround first
// if the stream may be in the middle of an escape sequence.
// Parses escape sequences until the parser reaches the ground state.
// Returns the number of bytes consumed from the provided input.
// Like nextSlice but takes one byte and is necessarily a scalar
// operation that can't use SIMD. Prefer nextSlice if you can and
// try to get multiple bytes at once.
// The scalar path can be responsible for decoding UTF-8.
// Process the next byte and print as necessary.
//
// This assumes we're in the UTF-8 decoding state. If we may not
// be in the UTF-8 decoding state call nextSlice or next.
// We optimize for the scenario where the text being
// printed in the terminal ISN'T full of ill-formed
// UTF-8 sequences.
// It should be impossible for the decoder
// to not consume the byte twice in a row.
// To be called whenever the utf-8 decoder produces a codepoint.
//
// This function is abstracted this way to handle the case where
// the decoder emits a 0x1B after rejecting an ill-formed sequence.
// We need to increase the eval branch limit because a lot of
// tests end up running almost completely at comptime due to
// a chain of inline functions.
// C0 control
// ESC
// Process the next character and call any callbacks if necessary.
//
// This assumes that we're not in the UTF-8 decoding state. If
// we may be in the UTF-8 decoding state call nextSlice or next.
// Fast path for CSI entry.
// Fast path for CSI params.
// csi_param is the most common parser state
// other than ground by a fairly wide margin.
//
// ref: https://github.com/qwerasd205/asciinema-stats
// A C0 escape (yes, this is valid):
// We ignore C0 escapes > 0xF since execute
// doesn't have processing for them anyway:
// We don't currently have any handling for
// 0x18 or 0x1A, but they should still move
// the parser state to ground.
// A parameter digit:
// The parser's CSI param action uses param_acc_idx
// to decide if there's a final param that needs to
// be consumed or not, but it doesn't matter really
// what it is as long as it's not 0.
// A parameter separator:
// Explicitly ignored:
// Defer to the state machine to
// handle any other characters:
// We explicitly inline this call here for performance reasons.
//
// We do this rather than mark Parser.next as inline because doing
// that causes weird behavior in some tests- I'm not sure if they
// miscompile or it's just very counter-intuitive comptime stuff,
// but regardless, this is the easy solution.
// A handler can expose this to get the raw action before
// it is further parsed. If this returns `true` then we skip
// processing ourselves.
// Always skip erroneous actions because we can't
// be sure...
// If the character is > 0x7F, it's a C1 (8-bit) control,
// which is strictly equivalent to `ESC` plus `c - 0x40`.
// We ignore SOH/STX: https://github.com/microsoft/terminal/issues/10786
// The branch hints here are based on real world data
// which indicates that the most common CSI finals are:
//
// 1. m
// 2. H
// 3. K
// 4. A
// 5. C
// 6. X
// 7. l
// 8. h
// 9. r
//
// Together, these 9 finals make up about 96% of all
// CSI sequences encountered in real world scenarios.
//
// Additionally, within the prongs, unlikely branch
// hints have been added to branches that deal with
// invalid sequences/commands, this is in order to
// optimize for the happy path where we're getting
// valid data from the program we're running.
//
// ref: https://github.com/qwerasd205/asciinema-stats
// CUU - Cursor Up
// CUD - Cursor Down
// CUF - Cursor Right
// CUB - Cursor Left
// CNL - Cursor Next Line
// CPL - Cursor Previous Line
// HPA - Cursor Horizontal Position Absolute
// TODO: test
// CUP - Set Cursor Position.
// TODO: test
// CHT - Cursor Horizontal Tabulation
// Erase Display
// Erase Line
// IL - Insert Lines
// TODO: test
// DL - Delete Lines
// TODO: test
// Delete Character (DCH)
// Scroll Up (SD)
// Scroll Down (SD)
// Cursor Tabulation Control
// Erase Characters (ECH)
// CHT - Cursor Horizontal Tabulation Back
// HPR - Cursor Horizontal Position Relative
// Repeat Previous Char (REP)
// c - Device Attributes (DA1)
// VPA - Cursor Vertical Position Absolute
// VPR - Cursor Vertical Position Relative
// TBC - Tab Clear
// TODO: test
// SM - Set Mode
// RM - Reset Mode
// SGR - Select Graphic Rendition
// This is the most common case.
// log.info("parse SGR params={any}", .{input.params});
// log.info("SGR attribute: {}", .{attr});
// Reset
// We don't support any of the subparams yet for these.
// We only support the numeric form.
// Nothing, but I wanted a place to put this comment:
// there are others forms of CSI m that have intermediates.
// `vim --clean` uses `CSI ? 4 m` and I don't know what
// that means.
// TODO: test
// Handle deviceStatusReport first
// Handle other forms of CSI n
// This isn't strictly correct. CSI > n has parameters that
// control what exactly is being disabled. However, we
// only support reverting back to modify other keys in
// numeric except format.
// DECRQM - Request Mode
// DECSCUSR - Select Cursor Style
// TODO: test
// DECSCA
// XTVERSION
// DECSTBM - Set Top and Bottom Margins
// Restore Mode
// DECSLRM
// CSI S is ambiguous with zero params so we defer
// to our handler to do the proper logic. If mode 69
// is set, then we should invoke DECSLRM, otherwise
// we should invoke SC.
// XTSHIFTESCAPE
// XTWINOPS
// report the text area size in pixels
// report cell size in pixels
// report screen size in characters
// report window title
// we only support window title
// push/pop title
// Kitty keyboard protocol
// ICH - Insert Blanks
// DECSASD - Select Active Status Display
// Verify we're getting a DECSASD command
// The branch hints here are based on real world data
// which indicates that the most common OSC commands are:
//
// 1. hyperlink_end
// 2. change_window_title
// 3. change_window_icon
// 4. hyperlink_start
// 5. report_pwd
// 6. color_operation
// 7. semantic_prompt
//
// Together, these 7 commands make up about 96% of all
// OSC commands encountered in real world scenarios.
//
// Additionally, within the prongs, unlikely branch
// hints have been added to branches that deal with
// invalid sequences/commands, this is in order to
// optimize for the happy path where we're getting
// valid data from the program we're running.
//
// ref: https://github.com/qwerasd205/asciinema-stats
// This is an invalid internal state, not an invalid OSC
// string being parsed. We shouldn't see this.
// TODO: support slots '-', '.', '/'
// The branch hints here are based on real world data
// which indicates that the most common ESC finals are:
//
// 1. B
// 2. \
// 3. 0
// 4. M
// 5. 8
// 6. 7
// 7. >
// 8. =
//
// Together, these 8 finals make up nearly 99% of all
// ESC sequences encountered in real world scenarios.
//
// Additionally, within the prongs, unlikely branch
// hints have been added to branches that deal with
// invalid sequences/commands, this is in order to
// optimize for the happy path where we're getting
// valid data from the program we're running.
//
// ref: https://github.com/qwerasd205/asciinema-stats
// Charsets
// DECSC - Save Cursor
// DECRC - Restore Cursor
// DECALN - Fill Screen with E
// IND - Index
// NEL - Next Line
// HTS - Horizontal Tab Set
// RI - Reverse Index
// SS2 - Single Shift 2
// SS3 - Single Shift 3
// SPA - Start of Guarded Area
// EPA - End of Guarded Area
// DECID
// RIS - Full Reset
// LS2 - Locking Shift 2
// LS3 - Locking Shift 3
// LS1R - Locking Shift 1 Right
// LS2R - Locking Shift 2 Right
// LS3R - Locking Shift 3 Right
// Set application keypad mode
// Reset application keypad mode
// Sets ST (string terminator). We don't have to do anything
// because our parser always accepts ST.
// Forces the C type to be reified when the target is C, ensuring
// all our types are C ABI compatible.
// Invalid and ignored by the handler
// Invalid and ignored by the handler
// Invalid and ignored by the handler
// Invalid and ignored by the handler
// Invalid and ignored by the handler
// Kakoune-style SGR with underline color as 17th parameter
// This tests the fix where param 17 was being dropped
//
// --- Original Ghostty Comments End: src/terminal/stream.zig

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
pub enum ActionKey as i32 {
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
	mouse_shape
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
	// title_push, title_pop, etc. Ghostty's cursor-oriented values are u16.
	num u16
	// Ghostty uses usize for repeat/edit/scroll counts even though values parsed
	// from CSI parameters currently originate as u16.
	count usize
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
	// Device status request (for .device_status)
	device_status DeviceStatusRequest
	// Size report style (for .size_report)
	size_report_style SizeReportStyle
	// Status display (for .active_status_display)
	status_display StatusDisplay
	// Mouse shape (for .mouse_shape)
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
	// String value (for .window_title and .report_pwd).
	str1 string
	// OSC request terminator, mirrored by response-producing operations.
	osc_terminator osc.Terminator
	// Parsed OSC color data, carried through without reinterpreting raw strings.
	color_op          osc.ColorOperation
	color_requests    []osc.ColorRequest
	kitty_color_items []osc.KittyColorItem
	// Byte value (for .dcs_put, .apc_put)
	byte_val u8
	// Clipboard kind (for .clipboard_contents)
	clipboard osc.ClipboardContents
	// Parsed OSC 8 hyperlink payload.
	hyperlink osc.HyperlinkStart
	// Semantic prompt action (for .semantic_prompt)
	semantic_prompt_action osc.SemanticAction
	// Semantic prompt options string (for .semantic_prompt, raw ;k=v pairs)
	semantic_prompt_opts string
	// Parsed ConEmu progress report.
	progress_report osc.ProgressReport
	// Parsed OSC 9 / OSC 777 desktop notification.
	desktop_notification osc.DesktopNotification
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

// DeviceStatusRequest is defined in device_status.v.

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
	// Enabled only on the inspector's parallel parser stream. The terminal's
	// main stream keeps this false so normal operation pays no capture cost.
	capture_raw bool
	// Raw parser actions retained for Ghostty's Terminal IO inspector. These
	// are cleared alongside the semantic events after each dispatch batch.
	raw_events []ParserAction
}

// init creates a new stream.
pub fn Stream.init() Stream {
	return Stream{
		parser: VTParser.init()
	}
}

// init_alloc initializes the source allocation-enabled stream. V manages the
// payload storage itself, while the non-null token preserves OSC capability
// selection in the translated parser.
pub fn Stream.init_alloc(allocator voidptr) Stream {
	return Stream{
		parser: VTParser{
			osc_parser: osc.Parser.init(allocator)
		}
	}
}

// deinit frees resources.
pub fn (mut self Stream) deinit() {
	self.parser.deinit()
	self.events = []
	self.raw_events = []
}

// clear_events clears the collected events.
pub fn (mut self Stream) clear_events() {
	self.events.clear()
	self.raw_events.clear()
}

// ============================================================
// Byte processing
// ============================================================

// next_slice processes a string of bytes. Printable UTF-8 is decoded in
// batches while control sequences and partial sequences stay on the scalar
// state-machine path. The inspector capture path is intentionally scalar so
// it retains every raw parser action.
pub fn (mut self Stream) next_slice(input_ []u8) {
	if self.capture_raw {
		for c in input_ {
			self.next(c)
		}
		return
	}

	mut cp_buf := []u32{len: 4096}
	mut offset := usize(0)
	for {
		remaining := usize(input_.len) - offset
		len := if usize(cp_buf.len) < remaining { usize(cp_buf.len) } else { remaining }
		self.next_slice_capped(input_[offset..offset + len], mut cp_buf)
		offset += len
		if offset >= usize(input_.len) {
			break
		}
	}
}

fn (mut self Stream) next_slice_capped(input_ []u8, mut cp_buf []u32) {
	assert input_.len <= cp_buf.len
	mut offset := usize(0)

	// Complete any UTF-8 sequence split across calls before bulk decoding.
	for self.utf8d.state != 0 {
		if offset >= usize(input_.len) {
			return
		}
		self.next_utf8(input_[offset])
		offset++
	}
	if offset >= usize(input_.len) {
		return
	}

	// Finish a control sequence carried over from the previous chunk.
	offset += self.consume_until_ground(input_[offset..])
	if offset >= usize(input_.len) {
		return
	}
	offset += self.consume_all_escapes(input_[offset..])

	for self.parser.state == .ground && offset < usize(input_.len) {
		result := simd.utf8_decode_until_control_seq(input_[offset..], mut cp_buf)
		for cp in cp_buf[..result.decoded] {
			if cp <= 0x0f {
				self.execute(u8(cp))
			} else {
				self.print(cp)
			}
		}
		offset += result.consumed
		if offset >= usize(input_.len) {
			return
		}

		// A non-ESC stop is an incomplete or invalid leading sequence. Give
		// the remainder to the incremental decoder so it can carry state.
		if input_[offset] != 0x1b {
			for c in input_[offset..] {
				self.next_utf8(c)
			}
			return
		}
		offset += self.consume_all_escapes(input_[offset..])
	}
}

// consume_all_escapes parses consecutive escape sequences and returns their
// byte count. The caller enters at an ESC while the parser is in ground.
fn (mut self Stream) consume_all_escapes(input_ []u8) usize {
	mut offset := usize(0)
	for offset < usize(input_.len) && input_[offset] == 0x1b {
		self.parser.state = .escape
		self.parser.clear()
		offset++
		offset += self.consume_until_ground(input_[offset..])
		if offset >= usize(input_.len) {
			return usize(input_.len)
		}
	}
	return offset
}

// consume_until_ground advances an in-progress escape sequence until the VT
// parser returns to ground, or consumes all available input.
fn (mut self Stream) consume_until_ground(input_ []u8) usize {
	mut offset := usize(0)
	for self.parser.state != .ground {
		if offset >= usize(input_.len) {
			return usize(input_.len)
		}
		self.next_non_utf8(input_[offset])
		offset++
	}
	return offset
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
	assert self.parser.state == .ground
	res := self.utf8d.next(c)
	if cp := res.codepoint {
		self.handle_codepoint(cp)
	}
	if !res.consumed {
		// The byte was not consumed (invalid continuation).
		// Retry with the same byte after the decoder has been reset.
		retry := self.utf8d.next(c)
		assert retry.consumed
		if cp := retry.codepoint {
			self.handle_codepoint(cp)
		}
	}
}

// handle_codepoint processes a decoded codepoint.
fn (mut self Stream) handle_codepoint(c u32) {
	// C0 control
	if c <= 0x0f {
		self.execute(u8(c))
		return
	}
	// ESC
	if c == 0x1B {
		self.parser.state = .escape
		self.parser.clear()
		return
	}
	self.print(c)
}

// next_non_utf8 processes a byte when the parser is not in ground state.
fn (mut self Stream) next_non_utf8(c u8) {
	assert self.parser.state != .ground
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
					self.parser.params_sep.set(usize(self.parser.params_idx))
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
		if self.capture_raw && action.action_type !in [.print_action, .execute_action] {
			self.raw_events << action.clone_for_retention()
		}
		match action.action_type {
			.print_action {
				self.print(action.char)
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
		}
	}
}

// ============================================================
// Dispatch helper
// ============================================================

fn (mut self Stream) dispatch(key ActionKey, payload ActionPayload) {
	self.events << StreamEvent{ key: key, payload: payload }
}

// clone_for_retention copies parser-backed views when Witty's event adapter
// retains a raw action beyond Parser.next. Ghostty's vtRaw callback is
// synchronous, so any retaining handler must make this same ownership copy.
fn (self ParserAction) clone_for_retention() ParserAction {
	return ParserAction{
		action_type: self.action_type
		char: self.char
		byte_val: self.byte_val
		csi: CSIAction{
			intermediates: self.csi.intermediates.clone()
			params: self.csi.params.clone()
			params_sep: self.csi.params_sep
			final_byte: self.csi.final_byte
		}
		esc: ESCAction{
			intermediates: self.esc.intermediates.clone()
			final_byte: self.esc.final_byte
		}
		osc: self.osc
		dcs: DCSAction{
			intermediates: self.dcs.intermediates.clone()
			params: self.dcs.params.clone()
			final_byte: self.dcs.final_byte
		}
	}
}

// ============================================================
// Print and Execute
// ============================================================

pub fn (mut self Stream) print(c u32) {
	if self.capture_raw {
		self.raw_events << ParserAction{
			action_type: .print_action
			char: c
		}
	}
	self.dispatch(.print, ActionPayload{ cp: c })
}

pub fn (mut self Stream) execute(c u8) {
	if self.capture_raw {
		self.raw_events << ParserAction{
			action_type: .execute_action
			byte_val: c
		}
	}
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
				self.dispatch(.insert_lines, ActionPayload{ count: val })
			}
		}

		// DL - Delete Lines
		u8(`M`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.delete_lines, ActionPayload{ count: val })
			}
		}

		// DCH - Delete Character
		u8(`P`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.delete_chars, ActionPayload{ count: val })
			}
		}

		// SU - Scroll Up
		u8(`S`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.scroll_up, ActionPayload{ count: val })
			}
		}

		// SD - Scroll Down
		u8(`T`) {
			if input.intermediates.len == 0 {
				val := self.csi_single_param(input, 1) or { return }
				self.dispatch(.scroll_down, ActionPayload{ count: val })
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
				self.dispatch(.erase_chars, ActionPayload{ count: val })
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
				self.dispatch(.print_repeat, ActionPayload{ count: val })
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
				self.dispatch(.insert_blanks, ActionPayload{ count: val })
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
		22 { ActionKey.erase_display_scroll_complete }
		else {
			return
		}
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
		else {
			return
		}
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
			else {
				return
			}
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

		if request := req_from_int(input.params[0], question) {
			self.dispatch(.device_status, ActionPayload{
				device_status: request
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

	if input.intermediates[0] != u8(`?`) || input.intermediates[1] != u8(`$`) {
		return
	}
	is_ansi := false

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
			else {
				return
			}
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
						else {
							return
						}
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
						else {
							return
						}
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
							else {
								return
							}
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
						if input.params[0] > 31 {
							return
						}
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
						if input.params[0] > 31 {
							return
						}
						u8(input.params[0])
					} else {
						u8(0)
					}
					number := if input.params.len >= 2 { input.params[1] } else { u16(1) }
					key := match number {
						1 { ActionKey.kitty_keyboard_set }
						2 { ActionKey.kitty_keyboard_set_or }
						3 { ActionKey.kitty_keyboard_set_not }
						else {
							return
						}
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
			if !validate.utf8_string(cmd.str_value) {
				return
			}
			self.dispatch(.window_title, ActionPayload{ str1: cmd.str_value })
		}
		.change_window_icon {
			// Ignored (icon not supported)
		}
		.clipboard_contents {
			self.dispatch(.clipboard_contents, ActionPayload{
				clipboard: cmd.clipboard
			})
		}
		.report_pwd {
			self.dispatch(.report_pwd, ActionPayload{ str1: cmd.str_value })
		}
		.mouse_shape {
			if ms := MouseShape.from_string(cmd.str_value) {
				self.dispatch(.mouse_shape, ActionPayload{
					mouse_shape_val: ms
				})
			}
		}
		.hyperlink_start {
			self.dispatch(.start_hyperlink, ActionPayload{
				hyperlink: cmd.hyperlink
			})
		}
		.hyperlink_end {
			self.dispatch(.end_hyperlink, ActionPayload{})
		}
		.show_desktop_notification {
			self.dispatch(.show_desktop_notification, ActionPayload{
				desktop_notification: cmd.desktop_notification
			})
		}
		.semantic_prompt {
			self.dispatch(.semantic_prompt, ActionPayload{
				semantic_prompt_action: cmd.semantic_prompt_action
				semantic_prompt_opts: cmd.semantic_prompt_options
			})
		}
		.color_operation {
			self.dispatch(.color_operation, ActionPayload{
				osc_terminator: cmd.terminator
				color_op: cmd.color_op
				color_requests: cmd.color_requests
			})
		}
		.kitty_color_protocol {
			self.dispatch(.kitty_color_report, ActionPayload{
				osc_terminator: cmd.terminator
				kitty_color_items: cmd.kitty_color_items
			})
		}
		.conemu_progress_report {
			self.dispatch(.progress_report, ActionPayload{
				progress_report: osc.ProgressReport{
					state: cmd.progress_state
					progress: cmd.progress
				}
			})
		}
		.conemu_sleep, .conemu_show_message_box, .conemu_change_tab_title, .conemu_wait_input, .conemu_guimacro, .conemu_run_process, .conemu_output_environment_variable, .conemu_xterm_emulation, .conemu_comment, .kitty_text_sizing {
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
		else {
			return
		}
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
// mode_from_int is defined in modes.v.

// SgrParser is defined in sgr.v with full colon-separator support.
