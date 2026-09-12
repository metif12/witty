module terminal_c

// Translated from ghostty/src/terminal/c/ directory.
//
// This module provides C-compatible API wrappers around the terminal
// module's functionality. In Ghostty, these are used to expose the
// terminal through a C ABI for use by C/ObjC/Swift code.
//
// In V, modules are accessed directly, so these wrappers primarily
// exist for completeness and to provide the same API surface if
// needed for FFI or shared library export.
//
// Source files translated:
//   - c/result.zig → Result enum
//   - c/color.zig  → rgb_get()
//   - c/paste.zig  → paste_is_safe()
//   - c/osc.zig    → OscParser/OscCommand wrappers, CommandData enum
//   - c/main.zig   → module aggregator (this file)

import input
import osc
import terminal

// ============================================================
// Result (from c/result.zig)
// ============================================================

// Result represents the outcome of a C API operation.
// C: GhosttyResult
pub enum Result as i32 {
	success       = 0
	out_of_memory = -1
	invalid_value = -2
}

// ============================================================
// Color (from c/color.zig)
// ============================================================

// RGB holds red, green, blue color components.
pub struct RGB {
pub:
	r u8
	g u8
	b u8
}

// Extract individual r, g, b components from an RGB value.
pub fn rgb_get(c RGB) (u8, u8, u8) {
	return c.r, c.g, c.b
}

// ============================================================
// Paste (from c/paste.zig)
// ============================================================

// Check if paste data is safe. Delegates to input.paste_is_safe.
//
// Data is considered unsafe if it contains newlines (which can inject
// commands) or the bracketed paste end sequence (\x1b[201~).
pub fn paste_is_safe(data string) bool {
	return input.paste_is_safe(data)
}

// ============================================================
// Key event (from c/key_event.zig)
// ============================================================

// KeyEvent wraps input.KeyEvent for the C-facing lifecycle API. V-managed
// strings are owned, so UTF-8 set through this wrapper remains valid without
// imposing the C API's borrowed-buffer lifetime on V callers.
@[heap]
pub struct KeyEvent {
pub mut:
	event input.KeyEvent
}

pub fn key_event_new() &KeyEvent {
	return &KeyEvent{}
}

pub fn key_event_free(mut event KeyEvent) {
	event.event = input.KeyEvent{}
}

pub fn (mut self KeyEvent) set_action(action input.KeyAction) {
	self.event.action = action
}

pub fn (self &KeyEvent) get_action() input.KeyAction {
	return self.event.action
}

pub fn (mut self KeyEvent) set_key(key input.Key) {
	self.event.key = key
}

pub fn (self &KeyEvent) get_key() input.Key {
	return self.event.key
}

pub fn (mut self KeyEvent) set_mods(mods input.Mods) {
	self.event.mods = mods
}

pub fn (self &KeyEvent) get_mods() input.Mods {
	return self.event.mods
}

pub fn (mut self KeyEvent) set_consumed_mods(mods input.Mods) {
	self.event.consumed_mods = mods
}

pub fn (self &KeyEvent) get_consumed_mods() input.Mods {
	return self.event.consumed_mods
}

pub fn (mut self KeyEvent) set_composing(composing bool) {
	self.event.composing = composing
}

pub fn (self &KeyEvent) get_composing() bool {
	return self.event.composing
}

pub fn (mut self KeyEvent) set_utf8(utf8 string) {
	self.event.utf8 = utf8
}

pub fn (self &KeyEvent) get_utf8() string {
	return self.event.utf8
}

pub fn (mut self KeyEvent) set_unshifted_codepoint(codepoint u32) {
	self.event.unshifted_codepoint = codepoint
}

pub fn (self &KeyEvent) get_unshifted_codepoint() u32 {
	return self.event.unshifted_codepoint
}

// ============================================================
// Key encoder (from c/key_encode.zig)
// ============================================================

@[heap]
pub struct KeyEncoder {
pub mut:
	opts input.Options
}

pub enum KeyEncoderOption as i32 {
	cursor_key_application     = 0
	keypad_key_application     = 1
	ignore_keypad_with_numlock = 2
	alt_esc_prefix             = 3
	modify_other_keys_state_2  = 4
	kitty_flags                = 5
	macos_option_as_alt        = 6
}

// V's sum type is the typed equivalent of the C API's option-specific void
// pointer. Values with the wrong type for an option are ignored just as an
// invalid C option is rejected before mutating the encoder.
pub type KeyEncoderOptionValue = bool | input.OptionAsAlt | u8

pub fn key_encoder_new() &KeyEncoder {
	return &KeyEncoder{}
}

pub fn key_encoder_free(mut encoder KeyEncoder) {
	encoder.opts = input.Options{}
}

pub fn (mut self KeyEncoder) setopt(option KeyEncoderOption, value KeyEncoderOptionValue) {
	match value {
		bool {
			match option {
				.cursor_key_application {
					self.opts.cursor_key_application = value
				}
				.keypad_key_application {
					self.opts.keypad_key_application = value
				}
				.ignore_keypad_with_numlock {
					self.opts.ignore_keypad_with_numlock = value
				}
				.alt_esc_prefix {
					self.opts.alt_esc_prefix = value
				}
				.modify_other_keys_state_2 {
					self.opts.modify_other_keys_state_2 = value
				}
				else {}
			}
		}
		u8 {
			if option == .kitty_flags {
				self.opts.kitty_flags = input.KittyFlags.from_int(value)
			}
		}
		input.OptionAsAlt {
			if option == .macos_option_as_alt {
				self.opts.macos_option_as_alt = value
			}
		}
	}
}

// encode writes into the caller's fixed buffer. The returned byte count is
// the bytes written on success or the required size when the buffer is too
// small, matching ghostty_key_encoder_encode.
pub fn (self &KeyEncoder) encode(event &KeyEvent, mut out []u8) (Result, usize) {
	encoded := input.encode(event.event, self.opts)
	if encoded.len > out.len {
		return Result.out_of_memory, usize(encoded.len)
	}
	for i, byte in encoded.bytes() {
		out[i] = byte
	}
	return Result.success, usize(encoded.len)
}

// ============================================================
// OSC (from c/osc.zig)
// ============================================================

// OscParser wraps the osc.Parser for C-compatible access.
pub struct OscParser {
pub mut:
	parser osc.Parser
}

// Create a new OSC parser.
pub fn osc_new() OscParser {
	return OscParser{
		parser: osc.Parser.init(voidptr(1))
	}
}

pub fn osc_free(mut parser OscParser) {
	parser.parser.deinit()
}

// Reset the OSC parser state.
pub fn (mut self OscParser) reset() {
	self.parser.reset()
}

// Feed a byte to the OSC parser.
pub fn (mut self OscParser) next(byte u8) {
	self.parser.next(byte)
}

// Finalize parsing and return the command, if any.
pub fn (mut self OscParser) end(terminator u8) ?osc.Command {
	return self.parser.end(terminator)
}

pub fn osc_command_type(cmd ?osc.Command) osc.CommandType {
	command := cmd or { return .invalid }
	return command.cmd_type
}

// CommandData enumerates the types of data that can be extracted
// from an OSC command through the C API.
// C: GhosttyOscCommandData
pub enum CommandData {
	invalid // 0
	change_window_title_str // 1
}

// Extract typed data from an OSC command.
// Returns the string data if the command matches the requested data type.
pub fn command_data(cmd ?osc.Command, data CommandData) ?string {
	c := cmd or { return none }
	match data {
		.invalid {
			return none
		}
		.change_window_title_str {
			if c.cmd_type == .change_window_title {
				return c.str_value
			}
			return none
		}
	}
}

// ============================================================
// SGR (from c/sgr.zig)
// ============================================================

// SgrParser wraps the terminal SGR parser and owns its copied parameter list.
@[heap]
pub struct SgrParser {
pub mut:
	parser terminal.SgrParser
}

pub fn sgr_new() &SgrParser {
	return &SgrParser{}
}

pub fn sgr_free(mut parser SgrParser) {
	parser.parser.params = []u16{}
	parser.parser.params_sep = terminal.SepList.init_empty()
	parser.parser.idx = 0
}

pub fn (mut self SgrParser) reset() {
	self.parser.idx = 0
}

// set_params copies the caller's parameters and separator bytes. A colon byte
// marks the separator after the corresponding parameter; every other byte is
// treated as a semicolon, matching the C API.
pub fn (mut self SgrParser) set_params(params []u16, separators ?[]u8) Result {
	mut sep_list := terminal.SepList.init_empty()
	if seps := separators {
		if seps.len > 64 || seps.len < params.len {
			return .invalid_value
		}
		for i, sep in seps[..params.len] {
			if sep == `:` {
				sep_list.set(usize(i))
			}
		}
	}
	self.parser.params = params.clone()
	self.parser.params_sep = sep_list
	self.parser.idx = 0
	return .success
}

pub fn (mut self SgrParser) next() ?terminal.SgrAttribute {
	return self.parser.next()
}

pub fn sgr_unknown_full(attr terminal.SgrAttribute) []u16 {
	return attr.unknown_full
}

pub fn sgr_unknown_partial(attr terminal.SgrAttribute) []u16 {
	return attr.unknown_partial
}

pub fn sgr_attribute_tag(attr terminal.SgrAttribute) terminal.SgrAttributeKind {
	return attr.kind
}

// V does not need the C tagged-union projection: SgrAttribute is already a
// value-safe representation of the tag and its payload.
pub fn sgr_attribute_value(attr terminal.SgrAttribute) terminal.SgrAttribute {
	return attr
}
