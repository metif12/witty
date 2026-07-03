module terminal

// --- Original Ghostty Comments Start: src/terminal/Parser.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/terminal/Parser.zig
//
// VT-series parser for escape and control sequences.
//
// This is implemented directly as the state machine described on
// vt100.net: https://vt100.net/emu/dec_ansi_parser
// States for the state machine
// Transition action is an action that can be taken during a state
// transition. This is more of an internal action, not one used by
// end users, typically.
// Action is the action that a caller of the parser is expected to
// take as a result of some input character.
// Draw character to the screen. This is a unicode codepoint.
// Execute the C0 or C1 function.
// Execute the CSI command. Note that pointers within this
// structure are only valid until the next call to "next".
// Execute the ESC command.
// Execute the OSC command.
// DCS-related events.
// APC data
// The list of separators used for CSI params. The value of the
// bit can be mapped to Sep. The index of this bit set specifies
// the separator AFTER that param. For example: 0;4:3 would have
// index 1 set.
// The separator used for CSI params.
// Implement formatter for logging
// Implement formatter for logging
// Implement formatter for logging. This is mostly copied from the
// std.fmt implementation, but we modify it slightly so that we can
// print out custom formats for some of our primitives.
// If this is the active field...
// Unicode
// Byte
// Note: we don't do ASCII (u8) because there are a lot
// of invisible characters we don't want to handle right
// now.
// All others do the default behavior
// Maximum number of intermediate characters during parsing. This is
// 4 because we also use the intermediates array for UTF8 decoding which
// can be at most 4 bytes.
// Maximum number of CSI parameters. This is arbitrary. Practically, the
// only CSI command that uses more than 3 parameters is the SGR command
// which can be infinitely long. 24 is a reasonable limit based on empirical
// data. This used to be 16 but Kakoune has a SGR command that uses 17
// parameters.
//
// We could in the future make this the static limit and then allocate after
// but that's a lot more work and practically its so rare to exceed this
// number. I implore TUI authors to not use more than this number of CSI
// params, but I suspect we'll introduce a slow path with heap allocation
// one day.
// Current state of the state machine
// Intermediate tracking.
// Param tracking, building
// Parser for OSC sequences
// Initialize our undefined fields so Valgrind can catch it.
// https://github.com/ziglang/zig/issues/19148
// Next consumes the next character c and returns the actions to execute.
// Up to 3 actions may need to be executed -- in order -- representing
// the state exit, transition, and entry actions.
// log.info("next: {x}", .{c});
// After generating the actions, we set our next state.
// When going from one state to another, the actions take place in this order:
//
// 1. exit action from old state
// 2. transition action
// 3. entry action to new state
// Exit depends on current state
// Entry depends on new state
// Finalize parameters
// Semicolon separates parameters. If we encounter a semicolon
// we need to store and move on to the next parameter.
// Ignore too many parameters
// Set param final value
// Reset current param value to 0
// A numeric value. Add it to our accumulator.
// Increment our accumulator index. If we overflow then
// we're out of bounds and we exit immediately.
// The client is expected to perform no action.
// Ignore too many parameters
// Finalize parameters if we have one
// We only allow colon or mixed separators for the 'm' command.
// This is from a Kakoune actual SGR sequence.
// This is from a Kakoune actual SGR sequence also.
// https://github.com/darrenstarr/VtNetCore/pull/14
// Saw this on HN, decided to add a test case because why not.
// Has to be +2 for the loops below
//
// --- Original Ghostty Comments End: src/terminal/Parser.zig


// VT Parser state machine based on Paul Williams' DEC-compatible parser.
// https://vt100.net/emu/dec_ansi_parser
//
// This implements the standard VT parser that processes a byte stream
// and produces actions (print, execute, csi_dispatch, esc_dispatch,
// osc_dispatch, dcs_hook, dcs_put, dcs_unhook, apc_start, apc_put,
// apc_end).

// Maximum number of CSI parameters.
const max_params = 24

// Maximum number of intermediate bytes.
const max_intermediates = 4

// ============================================================
// Parser state
// ============================================================

// ParserState represents the state of the VT parser state machine.
pub enum ParserState {
	ground
	escape
	escape_intermediate
	csi_entry
	csi_param
	csi_intermediate
	csi_ignore
	dcs_entry
	dcs_param
	dcs_intermediate
	dcs_passthrough
	dcs_ignore
	osc_string
	sos_pm_apc_string
}

// ============================================================
// Separator list for CSI params (tracks ; vs : separators)
// ============================================================

// SepList tracks whether each CSI parameter separator was a colon (:)
// vs semicolon (;). The bit at index N indicates the separator AFTER
// param N. A set bit means colon, unset means semicolon.
pub struct SepList {
pub mut:
	bits u64
}

pub fn (self SepList) is_set(idx int) bool {
	if idx < 0 || idx >= 64 {
		return false
	}
	return (self.bits & (u64(1) << u32(idx))) != 0
}

pub fn (mut self SepList) set(idx int) {
	if idx >= 0 && idx < 64 {
		self.bits |= u64(1) << u32(idx)
	}
}

pub fn SepList.init_empty() SepList {
	return SepList{}
}

// count returns the number of set bits, i.e. how many colon (:) separators
// were used. A non-zero count means at least one colon/mixed separator was
// present in the CSI parameters.
pub fn (self SepList) count() int {
	mut c := 0
	mut v := self.bits
	for v != 0 {
		v &= v - 1
		c += 1
	}
	return c
}

// ============================================================
// Parser action data types
// ============================================================

// CSIAction contains the data for a CSI dispatch action.
pub struct CSIAction {
pub:
	intermediates []u8
	params        []u16
	params_sep    SepList
	final_byte    u8
}

// ESCAction contains the data for an ESC dispatch action.
pub struct ESCAction {
pub:
	intermediates []u8
	final_byte    u8
}

// DCSAction contains the data for a DCS hook action.
pub struct DCSAction {
pub:
	intermediates []u8
	params        []u16
	final_byte    u8
}

// OscCommand represents a parsed OSC (Operating System Command).
pub struct OscCommand {
pub:
	cmd_type OscCommandType
	// Primary string data (title, icon, pwd, uri, etc.)
	data string
	// Secondary string data (notification body, hyperlink id, etc.)
	data2 string
}

// OscCommandType identifies the type of OSC command.
pub enum OscCommandType {
	invalid
	change_window_title
	change_window_icon
	semantic_prompt
	clipboard_contents
	report_pwd
	mouse_shape
	color_operation
	kitty_color_protocol
	show_desktop_notification
	hyperlink_start
	hyperlink_end
	conemu_progress_report
	conemu_ignored
	kitty_text_sizing
}

// ============================================================
// Parser action
// ============================================================

// ParserActionType identifies the type of parser action.
pub enum ParserActionType {
	none
	print_action
	execute_action
	csi_dispatch_action
	esc_dispatch_action
	osc_dispatch_action
	dcs_hook_action
	dcs_put_action
	dcs_unhook_action
	apc_start_action
	apc_put_action
	apc_end_action
}

// ParserAction represents an action produced by the VT parser.
pub struct ParserAction {
pub:
	action_type ParserActionType
	char        u32        // for print
	byte_val    u8         // for execute, dcs_put, apc_put
	csi         CSIAction  // for csi_dispatch
	esc         ESCAction  // for esc_dispatch
	osc         OscCommand // for osc_dispatch
	dcs         DCSAction  // for dcs_hook
}

// ============================================================
// VTParser
// ============================================================

// VTParser processes a stream of bytes according to the VT parser
// state machine and produces parser actions.
pub struct VTParser {
pub mut:
	state ParserState = .ground

	// CSI/ESC/DCS parameter tracking
	params            [max_params]u16
	params_idx        u8
	param_acc         u16
	param_acc_idx     u8
	params_sep        SepList

	intermediates     [max_intermediates]u8
	intermediates_idx u8

	// OSC string accumulation
	osc_buf []u8
}

// clear resets the parser's parameter accumulation state.
pub fn (mut self VTParser) clear() {
	self.intermediates_idx = 0
	self.params_idx = 0
	self.params_sep = SepList.init_empty()
	self.param_acc = 0
	self.param_acc_idx = 0
}

// deinit frees any allocated resources.
pub fn (mut self VTParser) deinit() {
	self.osc_buf = []
}

// next processes a single byte and returns a list of actions.
pub fn (mut self VTParser) next(c u8) []ParserAction {
	mut actions := []ParserAction{}

	match self.state {
		.ground {
			self.do_ground(c, mut actions)
		}
		.escape {
			self.do_escape(c, mut actions)
		}
		.escape_intermediate {
			self.do_escape_intermediate(c, mut actions)
		}
		.csi_entry {
			self.do_csi_entry(c, mut actions)
		}
		.csi_param {
			self.do_csi_param(c, mut actions)
		}
		.csi_intermediate {
			self.do_csi_intermediate(c, mut actions)
		}
		.csi_ignore {
			self.do_csi_ignore(c, mut actions)
		}
		.osc_string {
			self.do_osc_string(c, mut actions)
		}
		.dcs_entry {
			self.do_dcs_entry(c, mut actions)
		}
		.dcs_param {
			self.do_dcs_param(c, mut actions)
		}
		.dcs_intermediate {
			self.do_dcs_intermediate(c, mut actions)
		}
		.dcs_passthrough {
			self.do_dcs_passthrough(c, mut actions)
		}
		.dcs_ignore {
			self.do_dcs_ignore(c, mut actions)
		}
		.sos_pm_apc_string {
			self.do_sos_pm_apc_string(c, mut actions)
		}
	}

	return actions
}

// ============================================================
// State handlers
// ============================================================

fn (mut self VTParser) do_ground(c u8, mut actions []ParserAction) {
	if c < 0x20 {
		actions << ParserAction{
			action_type: .execute_action
			byte_val: c
		}
	} else if c >= 0x80 && c <= 0x9F {
		// C1 8-bit control codes. These map to the same states/actions as
		// their 7-bit ESC-prefixed equivalents (the "anywhere" transitions
		// in the DEC ANSI parse table). Previously these were treated as
		// printable which is incorrect.
		self.do_c1(c, mut actions)
	} else if c != 0x7F {
		actions << ParserAction{
			action_type: .print_action
			char: u32(c)
		}
	}
}

// do_c1 handles the C1 (0x80-0x9F) 8-bit control codes. This mirrors the
// "anywhere" transitions from Ghostty's parse table (parse_table.zig).
fn (mut self VTParser) do_c1(c u8, mut actions []ParserAction) {
	match c {
		0x90 {
			// DCS (Device Control String) 8-bit -> dcs_entry
			self.clear()
			self.state = .dcs_entry
		}
		0x98, 0x9E, 0x9F {
			// SOS/PM/APC 8-bit -> sos_pm_apc_string
			self.state = .sos_pm_apc_string
			actions << ParserAction{
				action_type: .apc_start_action
			}
		}
		0x9B {
			// CSI (Control Sequence Introducer) 8-bit -> csi_entry
			self.clear()
			self.state = .csi_entry
		}
		0x9C {
			// ST (String Terminator) 8-bit -> ground, no action
			self.state = .ground
		}
		0x9D {
			// OSC (Operating System Command) 8-bit -> osc_string
			self.osc_buf = []
			self.state = .osc_string
		}
		else {
			// 0x80-0x8F, 0x91-0x97, 0x99, 0x9A -> execute (ground)
			actions << ParserAction{
				action_type: .execute_action
				byte_val: c
			}
		}
	}
}

fn (mut self VTParser) do_escape(c u8, mut actions []ParserAction) {
	if c <= 0x17 || c == 0x19 || (c >= 0x1C && c <= 0x1F) {
		// Execute C0 control
		actions << ParserAction{
			action_type: .execute_action
			byte_val: c
		}
	} else if c == 0x18 || c == 0x1A {
		// Cancel -> ground
		self.state = .ground
	} else if c == 0x1B {
		// Another ESC - restart
		self.clear()
	} else if c >= 0x20 && c <= 0x2F {
		// Intermediate -> escape_intermediate
		self.collect_intermediate(c)
		self.state = .escape_intermediate
	} else if c == 0x50 {
		// 'P' -> DCS entry
		self.clear()
		self.state = .dcs_entry
	} else if c == 0x5B {
		// '[' -> CSI entry
		self.clear()
		self.state = .csi_entry
	} else if c == 0x5D {
		// ']' -> OSC string
		self.osc_buf = []
		self.state = .osc_string
	} else if c == 0x58 || c == 0x5E || c == 0x5F {
		// 'X', '^', '_' -> SOS/PM/APC string
		self.state = .sos_pm_apc_string
		actions << ParserAction{ action_type: .apc_start_action }
	} else if c >= 0x30 && c <= 0x7E {
		// ESC dispatch (final byte)
		actions << self.build_esc_action(c)
		self.state = .ground
	}
	// 0x7F (DEL) is ignored
}

fn (mut self VTParser) do_escape_intermediate(c u8, mut actions []ParserAction) {
	if c <= 0x17 || c == 0x19 || (c >= 0x1C && c <= 0x1F) {
		actions << ParserAction{
			action_type: .execute_action
			byte_val: c
		}
	} else if c == 0x18 || c == 0x1A {
		self.state = .ground
	} else if c == 0x1B {
		self.clear()
		self.state = .escape
	} else if c >= 0x20 && c <= 0x2F {
		self.collect_intermediate(c)
	} else if c >= 0x30 && c <= 0x7E {
		actions << self.build_esc_action(c)
		self.state = .ground
	}
	// 0x7F is ignored
}

fn (mut self VTParser) do_csi_entry(c u8, mut actions []ParserAction) {
	if c <= 0x17 || c == 0x19 || (c >= 0x1C && c <= 0x1F) {
		actions << ParserAction{
			action_type: .execute_action
			byte_val: c
		}
	} else if c == 0x18 || c == 0x1A {
		self.state = .ground
	} else if c == 0x1B {
		self.clear()
		self.state = .escape
	} else if c >= 0x20 && c <= 0x2F {
		// Intermediate byte
		self.collect_intermediate(c)
		self.state = .csi_intermediate
	} else if (c >= 0x30 && c <= 0x39) || c == 0x3B {
		// Digit or semicolon -> csi_param, process param
		self.state = .csi_param
		self.process_csi_param_byte(c)
	} else if c == 0x3A {
		// Colon -> csi_param, process as separator
		self.state = .csi_param
		self.process_csi_param_byte(c)
	} else if c >= 0x3C && c <= 0x3F {
		// Private marker (< = > ?) -> collect as intermediate, go to csi_param
		self.collect_intermediate(c)
		self.state = .csi_param
	} else if c >= 0x40 && c <= 0x7E {
		// Final byte -> CSI dispatch with no params
		actions << self.build_csi_action(c)
		self.state = .ground
	}
	// 0x7F is ignored
}

fn (mut self VTParser) do_csi_param(c u8, mut actions []ParserAction) {
	if c <= 0x17 || c == 0x19 || (c >= 0x1C && c <= 0x1F) {
		actions << ParserAction{
			action_type: .execute_action
			byte_val: c
		}
	} else if c == 0x18 || c == 0x1A {
		self.state = .ground
	} else if c == 0x1B {
		self.clear()
		self.state = .escape
	} else if (c >= 0x30 && c <= 0x39) || c == 0x3A || c == 0x3B {
		// Digit, colon, or semicolon
		self.process_csi_param_byte(c)
	} else if c >= 0x3C && c <= 0x3F {
		// Second private marker -> csi_ignore (error)
		self.state = .csi_ignore
	} else if c >= 0x20 && c <= 0x2F {
		// Intermediate byte
		self.collect_intermediate(c)
		self.state = .csi_intermediate
	} else if c >= 0x40 && c <= 0x7E {
		// Final byte -> CSI dispatch
		actions << self.build_csi_action(c)
		self.state = .ground
	}
	// 0x7F is ignored
}

fn (mut self VTParser) do_csi_intermediate(c u8, mut actions []ParserAction) {
	if c <= 0x17 || c == 0x19 || (c >= 0x1C && c <= 0x1F) {
		actions << ParserAction{
			action_type: .execute_action
			byte_val: c
		}
	} else if c == 0x18 || c == 0x1A {
		self.state = .ground
	} else if c == 0x1B {
		self.clear()
		self.state = .escape
	} else if c >= 0x20 && c <= 0x2F {
		self.collect_intermediate(c)
	} else if c >= 0x30 && c <= 0x3F {
		// Parameter byte after intermediate -> error
		self.state = .csi_ignore
	} else if c >= 0x40 && c <= 0x7E {
		// Final byte -> CSI dispatch
		actions << self.build_csi_action(c)
		self.state = .ground
	}
	// 0x7F is ignored
}

fn (mut self VTParser) do_csi_ignore(c u8, mut actions []ParserAction) {
	if c <= 0x17 || c == 0x19 || (c >= 0x1C && c <= 0x1F) {
		actions << ParserAction{
			action_type: .execute_action
			byte_val: c
		}
	} else if c == 0x18 || c == 0x1A {
		self.state = .ground
	} else if c == 0x1B {
		self.clear()
		self.state = .escape
	} else if c >= 0x40 && c <= 0x7E {
		// Final byte -> ground (sequence is ignored)
		self.state = .ground
	}
	// Everything else is ignored
}

fn (mut self VTParser) do_osc_string(c u8, mut actions []ParserAction) {
	if c == 0x1B {
		// ESC received - might be ESC \ (ST). Generate osc_dispatch.
		actions << self.build_osc_action()
		self.state = .escape
		self.clear()
	} else if c == 0x07 {
		// BEL terminator
		actions << self.build_osc_action()
		self.state = .ground
	} else if c == 0x18 || c == 0x1A {
		// Cancel
		self.state = .ground
	} else if c >= 0x20 || c == 0x09 {
		// Accumulate printable characters and TAB
		self.osc_buf << c
	}
	// Other C0 controls are ignored
}

fn (mut self VTParser) do_dcs_entry(c u8, mut actions []ParserAction) {
	if c <= 0x17 || c == 0x19 || (c >= 0x1C && c <= 0x1F) {
		// Ignore (no execute in DCS entry)
	} else if c == 0x18 || c == 0x1A {
		self.state = .ground
	} else if c == 0x1B {
		self.clear()
		self.state = .escape
	} else if c >= 0x20 && c <= 0x2F {
		self.collect_intermediate(c)
		self.state = .dcs_intermediate
	} else if (c >= 0x30 && c <= 0x39) || c == 0x3B {
		self.state = .dcs_param
		self.process_csi_param_byte(c)
	} else if c >= 0x3C && c <= 0x3F {
		self.collect_intermediate(c)
		self.state = .dcs_param
	} else if c >= 0x40 && c <= 0x7E {
		actions << self.build_dcs_hook_action(c)
		self.state = .dcs_passthrough
	}
}

fn (mut self VTParser) do_dcs_param(c u8, mut actions []ParserAction) {
	if c <= 0x17 || c == 0x19 || (c >= 0x1C && c <= 0x1F) {
		// Ignore
	} else if c == 0x18 || c == 0x1A {
		self.state = .ground
	} else if c == 0x1B {
		self.clear()
		self.state = .escape
	} else if (c >= 0x30 && c <= 0x39) || c == 0x3B {
		self.process_csi_param_byte(c)
	} else if c >= 0x3C && c <= 0x3F {
		self.state = .dcs_ignore
	} else if c >= 0x20 && c <= 0x2F {
		self.collect_intermediate(c)
		self.state = .dcs_intermediate
	} else if c >= 0x40 && c <= 0x7E {
		actions << self.build_dcs_hook_action(c)
		self.state = .dcs_passthrough
	}
}

fn (mut self VTParser) do_dcs_intermediate(c u8, mut actions []ParserAction) {
	if c <= 0x17 || c == 0x19 || (c >= 0x1C && c <= 0x1F) {
		// Ignore
	} else if c == 0x18 || c == 0x1A {
		self.state = .ground
	} else if c == 0x1B {
		self.clear()
		self.state = .escape
	} else if c >= 0x20 && c <= 0x2F {
		self.collect_intermediate(c)
	} else if c >= 0x30 && c <= 0x3F {
		self.state = .dcs_ignore
	} else if c >= 0x40 && c <= 0x7E {
		actions << self.build_dcs_hook_action(c)
		self.state = .dcs_passthrough
	}
}

fn (mut self VTParser) do_dcs_passthrough(c u8, mut actions []ParserAction) {
	if c == 0x18 || c == 0x1A {
		actions << ParserAction{ action_type: .dcs_unhook_action }
		self.state = .ground
	} else if c == 0x1B {
		actions << ParserAction{ action_type: .dcs_unhook_action }
		self.state = .escape
		self.clear()
	} else if c != 0x7F {
		// Put
		actions << ParserAction{
			action_type: .dcs_put_action
			byte_val: c
		}
	}
}

fn (mut self VTParser) do_dcs_ignore(c u8, mut actions []ParserAction) {
	if c == 0x18 || c == 0x1A {
		self.state = .ground
	} else if c == 0x1B {
		self.clear()
		self.state = .escape
	}
	// Everything else is ignored
}

fn (mut self VTParser) do_sos_pm_apc_string(c u8, mut actions []ParserAction) {
	if c == 0x18 || c == 0x1A {
		actions << ParserAction{ action_type: .apc_end_action }
		self.state = .ground
	} else if c == 0x1B {
		actions << ParserAction{ action_type: .apc_end_action }
		self.state = .escape
		self.clear()
	} else if c != 0x7F {
		actions << ParserAction{
			action_type: .apc_put_action
			byte_val: c
		}
	}
}

// ============================================================
// Helper methods
// ============================================================

fn (mut self VTParser) collect_intermediate(c u8) {
	if self.intermediates_idx < max_intermediates {
		self.intermediates[self.intermediates_idx] = c
		self.intermediates_idx += 1
	}
}

// process_csi_param_byte handles a digit, semicolon, or colon in CSI param state.
fn (mut self VTParser) process_csi_param_byte(c u8) {
	if c >= 0x30 && c <= 0x39 {
		// Digit
		if self.params_idx < max_params {
			// Saturating multiply and add
			v := u32(self.param_acc) * 10 + u32(c - 0x30)
			self.param_acc = if v > 65535 { u16(65535) } else { u16(v) }
			self.param_acc_idx |= 1
		}
	} else if c == 0x3A || c == 0x3B {
		// Colon or semicolon separator
		if self.params_idx < max_params {
			self.params[self.params_idx] = self.param_acc
			if c == 0x3A {
				self.params_sep.set(int(self.params_idx))
			}
			self.params_idx += 1
			self.param_acc = 0
			self.param_acc_idx = 0
		}
	}
}

// build_csi_action creates a CSI dispatch action from the current parser state.
fn (mut self VTParser) build_csi_action(final_byte u8) ParserAction {
	// Finalize params: add accumulator if digits were seen
	mut p_len := int(self.params_idx)
	if self.param_acc_idx > 0 && self.params_idx < max_params {
		self.params[self.params_idx] = self.param_acc
		p_len = int(self.params_idx) + 1
	}

	// Copy params and intermediates to slices
	mut params_copy := []u16{cap: p_len}
	for i in 0 .. p_len {
		params_copy << self.params[i]
	}
	mut inter_copy := []u8{cap: int(self.intermediates_idx)}
	for i in 0 .. int(self.intermediates_idx) {
		inter_copy << self.intermediates[i]
	}

	// We only allow colon or mixed separators for the 'm' command.
	// If any colon separator was used for a non-'m' command, we discard
	// the sequence entirely (no dispatch). This matches Ghostty and is
	// derived from real-world Kakoune SGR sequences.
	if final_byte != u8(`m`) && self.params_sep.count() > 0 {
		return ParserAction{
			action_type: .none
		}
	}

	return ParserAction{
		action_type: .csi_dispatch_action
		csi: CSIAction{
			intermediates: inter_copy
			params: params_copy
			params_sep: self.params_sep
			final_byte: final_byte
		}
	}
}

// build_esc_action creates an ESC dispatch action from the current parser state.
fn (self &VTParser) build_esc_action(final_byte u8) ParserAction {
	mut inter_copy := []u8{cap: int(self.intermediates_idx)}
	for i in 0 .. int(self.intermediates_idx) {
		inter_copy << self.intermediates[i]
	}

	return ParserAction{
		action_type: .esc_dispatch_action
		esc: ESCAction{
			intermediates: inter_copy
			final_byte: final_byte
		}
	}
}

// build_osc_action creates an OSC dispatch action from the accumulated buffer.
fn (mut self VTParser) build_osc_action() ParserAction {
	osc_data := self.osc_buf.bytestr()
	self.osc_buf = []

	cmd := parse_osc_command(osc_data)

	return ParserAction{
		action_type: .osc_dispatch_action
		osc: cmd
	}
}

// build_dcs_hook_action creates a DCS hook action from the current parser state.
fn (mut self VTParser) build_dcs_hook_action(final_byte u8) ParserAction {
	mut p_len := int(self.params_idx)
	if self.param_acc_idx > 0 && self.params_idx < max_params {
		self.params[self.params_idx] = self.param_acc
		p_len = int(self.params_idx) + 1
	}

	mut params_copy := []u16{cap: p_len}
	for i in 0 .. p_len {
		params_copy << self.params[i]
	}
	mut inter_copy := []u8{cap: int(self.intermediates_idx)}
	for i in 0 .. int(self.intermediates_idx) {
		inter_copy << self.intermediates[i]
	}

	return ParserAction{
		action_type: .dcs_hook_action
		dcs: DCSAction{
			intermediates: inter_copy
			params: params_copy
			final_byte: final_byte
		}
	}
}

// parse_osc_command parses an OSC string into a command.
// The format is: <number>[;<data>]. Some OSCs (e.g. 104, 110-119, 133)
// may legitimately arrive without a trailing semicolon.
fn parse_osc_command(data string) OscCommand {
	// Find the first semicolon.
	mut sep_idx := -1
	for i, b in data {
		if b == u8(`;`) {
			sep_idx = i
			break
		}
	}

	// The numeric prefix is everything before the first semicolon (or the
	// whole string if there is no semicolon).
	num_str := if sep_idx < 0 { data } else { data[..sep_idx] }
	payload := if sep_idx < 0 { '' } else { data[sep_idx + 1..] }

	if num_str.len == 0 {
		return OscCommand{ cmd_type: .invalid }
	}

	// Parse the command number.
	mut num := 0
	for b in num_str {
		if b < u8(`0`) || b > u8(`9`) {
			return OscCommand{ cmd_type: .invalid }
		}
		num = num * 10 + int(b - u8(`0`))
	}

	// OSC color operations (4, 5, 10-19, 104, 105, 110-119). These are
	// handled by the color operation parser which needs the operation
	// number, so we pass the full OSC string (including the number) as the
	// command data.
	if is_color_operation_osc(num) {
		return OscCommand{
			cmd_type: .color_operation
			data: data
		}
	}

	// Map number to command type.
	return match num {
		0, 2 {
			OscCommand{
				cmd_type: .change_window_title
				data: payload
			}
		}
		1 {
			OscCommand{
				cmd_type: .change_window_icon
				data: payload
			}
		}
		7 {
			OscCommand{
				cmd_type: .report_pwd
				data: payload
			}
		}
		8 {
			// Hyperlinks: 8;params;uri
			parse_osc_8_hyperlink(payload)
		}
		21 {
			// Kitty color protocol (OSC 21). The body is passed through to
			// the kitty color parser.
			OscCommand{
				cmd_type: .kitty_color_protocol
				data: payload
			}
		}
		52 {
			OscCommand{
				cmd_type: .clipboard_contents
				data: payload
			}
		}
		133 {
			// Semantic prompt (OSC 133). The body (e.g. "A", "B;redraw=1")
			// is parsed by the stream dispatcher.
			OscCommand{
				cmd_type: .semantic_prompt
				data: payload
			}
		}
		// XTODO: remaining OSC numbers (9, 22, 777, 1337, etc.)
		else {
			OscCommand{ cmd_type: .invalid }
		}
	}
}

// is_color_operation_osc reports whether the given OSC number is a color
// operation (OSC 4, 5, 10-19, 104, 105, 110-119).
fn is_color_operation_osc(num int) bool {
	return num == 4 || num == 5 || (num >= 10 && num <= 19) || num == 104 || num == 105
		|| (num >= 110 && num <= 119)
}

// parse_osc_8_hyperlink parses an OSC 8 hyperlink command.
// Format: params;uri (where params can contain id=...)
fn parse_osc_8_hyperlink(data string) OscCommand {
	mut sep_idx := -1
	for i, b in data {
		if b == u8(`;`) {
			sep_idx = i
			break
		}
	}

	if sep_idx < 0 {
		return OscCommand{ cmd_type: .invalid }
	}

	params_str := data[..sep_idx]
	uri := data[sep_idx + 1..]

	if uri.len == 0 {
		// Empty URI means end hyperlink
		return OscCommand{ cmd_type: .hyperlink_end }
	}

	// Extract id from params if present
	mut id_val := ''
	for part in params_str.split(':') {
		if part.starts_with('id=') {
			id_val = part[3..]
		}
	}

	return OscCommand{
		cmd_type: .hyperlink_start
		data: uri
		data2: id_val
	}
}
