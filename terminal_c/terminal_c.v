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
import lib_allocator
import osc
import terminal

const object_alignment = u8(3)

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

// Check if paste data is safe. Delegates to input.is_safe.
//
// Data is considered unsafe if it contains newlines (which can inject
// commands) or the bracketed paste end sequence (\x1b[201~).
pub fn paste_is_safe(data string) bool {
	return input.is_safe(data)
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
mut:
	allocator lib_allocator.Allocator
	allocated bool
}

pub fn key_event_new() &KeyEvent {
	return &KeyEvent{}
}

// key_event_new_alloc is the allocator-aware constructor used by the C ABI.
// It preserves Ghostty's Result + output-pointer allocation contract.
pub fn key_event_new_alloc(allocator ?&lib_allocator.Allocator) (Result, &KeyEvent) {
	selected := lib_allocator.default(allocator)
	raw := selected.alloc_bytes(sizeof(KeyEvent), object_alignment, 0)
	if isnil(raw) {
		return Result.out_of_memory, unsafe { nil }
	}
	mut event := unsafe { &KeyEvent(raw) }
	unsafe {
		*event = KeyEvent{
			allocator: selected
			allocated: true
		}
	}
	return Result.success, event
}

pub fn key_event_free(mut event KeyEvent) {
	allocator := event.allocator
	allocated := event.allocated
	ptr := voidptr(&event)
	event.event = input.KeyEvent{}
	event.allocated = false
	if allocated {
		allocator.free_bytes(ptr, sizeof(KeyEvent), object_alignment, 0)
	}
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
mut:
	allocator lib_allocator.Allocator
	allocated bool
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

pub fn key_encoder_new_alloc(allocator ?&lib_allocator.Allocator) (Result, &KeyEncoder) {
	selected := lib_allocator.default(allocator)
	raw := selected.alloc_bytes(sizeof(KeyEncoder), object_alignment, 0)
	if isnil(raw) {
		return Result.out_of_memory, unsafe { nil }
	}
	mut encoder := unsafe { &KeyEncoder(raw) }
	unsafe {
		*encoder = KeyEncoder{
			allocator: selected
			allocated: true
		}
	}
	return Result.success, encoder
}

pub fn key_encoder_free(mut encoder KeyEncoder) {
	allocator := encoder.allocator
	allocated := encoder.allocated
	ptr := voidptr(&encoder)
	encoder.opts = input.Options{}
	encoder.allocated = false
	if allocated {
		allocator.free_bytes(ptr, sizeof(KeyEncoder), object_alignment, 0)
	}
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
@[heap]
pub struct OscParser {
pub mut:
	parser osc.Parser
mut:
	allocator lib_allocator.Allocator
	allocated bool
}

// Create a new OSC parser.
pub fn osc_new() OscParser {
	return OscParser{
		parser: osc.Parser.init(voidptr(1))
	}
}

pub fn osc_new_alloc(allocator ?&lib_allocator.Allocator) (Result, &OscParser) {
	selected := lib_allocator.default(allocator)
	raw := selected.alloc_bytes(sizeof(OscParser), object_alignment, 0)
	if isnil(raw) {
		return Result.out_of_memory, unsafe { nil }
	}
	mut parser := unsafe { &OscParser(raw) }
	unsafe {
		*parser = OscParser{
			parser: osc.Parser.init(voidptr(1))
			allocator: selected
			allocated: true
		}
	}
	return Result.success, parser
}

pub fn osc_free(mut parser OscParser) {
	parser.parser.deinit()
}

pub fn osc_free_alloc(mut parser OscParser) {
	allocator := parser.allocator
	allocated := parser.allocated
	ptr := voidptr(&parser)
	parser.parser.deinit()
	parser.allocated = false
	if allocated {
		allocator.free_bytes(ptr, sizeof(OscParser), object_alignment, 0)
	}
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

// end_ptr returns the parser-owned command storage used by the C ABI. Its
// lifetime ends at the next operation on this parser, matching Ghostty.
pub fn (mut self OscParser) end_ptr(terminator u8) ?&osc.Command {
	_ := self.parser.end(terminator) or { return none }
	return &self.parser.command
}

pub fn command_type(cmd ?osc.Command) osc.CommandType {
	command := cmd or { return .invalid }
	return command.cmd_type
}

// CommandData enumerates the types of data that can be extracted
// from an OSC command through the C API.
// C: GhosttyOscCommandData
pub enum CommandData as i32 {
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
mut:
	allocator  lib_allocator.Allocator
	allocated  bool
	params_ptr voidptr
	params_len usize
}

pub fn sgr_new() &SgrParser {
	return &SgrParser{
		allocator: lib_allocator.c_allocator_value()
	}
}

pub fn sgr_new_alloc(allocator ?&lib_allocator.Allocator) (Result, &SgrParser) {
	selected := lib_allocator.default(allocator)
	raw := selected.alloc_bytes(sizeof(SgrParser), object_alignment, 0)
	if isnil(raw) {
		return Result.out_of_memory, unsafe { nil }
	}
	mut parser := unsafe { &SgrParser(raw) }
	unsafe {
		*parser = SgrParser{
			allocator: selected
			allocated: true
		}
	}
	return Result.success, parser
}

pub fn sgr_free(mut parser SgrParser) {
	allocator := parser.allocator
	allocated := parser.allocated
	ptr := voidptr(&parser)
	if !isnil(parser.params_ptr) && parser.params_len > 0 {
		allocator.free_bytes(parser.params_ptr, parser.params_len * sizeof(u16), 1, 0)
	}
	parser.parser.params = []u16{}
	parser.parser.params_sep = terminal.SepList.init_empty()
	parser.parser.idx = 0
	parser.params_ptr = unsafe { nil }
	parser.params_len = 0
	parser.allocated = false
	if allocated {
		allocator.free_bytes(ptr, sizeof(SgrParser), object_alignment, 0)
	}
}

pub fn (mut self SgrParser) reset() {
	self.parser.idx = 0
}

fn u16_array_view(data voidptr, len usize) []u16 {
	mut result := []u16{}
	unsafe {
		mut header := &array(&result)
		header.data = data
		header.offset = 0
		header.len = int(len)
		header.cap = int(len)
		header.flags = .nogrow | .nofree
	}
	return result
}

// set_params_raw is the C-facing implementation. Like Ghostty, it copies the
// parameter list through the allocator retained by the parser, releases the
// previous list only after the new allocation succeeds, and then parses from
// that owned storage.
pub fn (mut self SgrParser) set_params_raw(params &u16, separators &u8, len usize) Result {
	if len > usize(max_int) || len > ~usize(0) / sizeof(u16) {
		return .out_of_memory
	}

	mut next_ptr := voidptr(unsafe { nil })
	if len > 0 {
		if isnil(params) {
			return .invalid_value
		}
		next_ptr = self.allocator.alloc_bytes(len * sizeof(u16), 1, 0)
		if isnil(next_ptr) {
			return .out_of_memory
		}
		unsafe {
			vmemcpy(next_ptr, params, len * sizeof(u16))
		}
	}

	if !isnil(self.params_ptr) && self.params_len > 0 {
		self.allocator.free_bytes(self.params_ptr, self.params_len * sizeof(u16), 1,
			0)
	}
	self.params_ptr = next_ptr
	self.params_len = len
	self.parser.params = if len == 0 { []u16{} } else { u16_array_view(next_ptr, len) }

	// The source replaces the parameter list and clears separators before
	// reporting an overlong separator list. Preserve that observable ordering.
	self.parser.params_sep = terminal.SepList.init_empty()
	if !isnil(separators) {
		if len > usize(terminal.max_params) {
			return .invalid_value
		}
		for i in 0 .. int(len) {
			if unsafe { separators[i] } == `:` {
				self.parser.params_sep.set(usize(i))
			}
		}
	}
	self.parser.idx = 0
	return .success
}

// set_params is the typed V convenience entry point over the same allocator-
// owned implementation. A colon byte marks the separator after the
// corresponding parameter; every other byte is treated as a semicolon.
pub fn (mut self SgrParser) set_params(params []u16, separators ?[]u8) Result {
	params_ptr := if params.len == 0 { &u16(unsafe { nil }) } else { &params[0] }
	if seps := separators {
		if seps.len < params.len {
			return .invalid_value
		}
		seps_ptr := if seps.len == 0 { &u8(unsafe { nil }) } else { &seps[0] }
		return self.set_params_raw(params_ptr, seps_ptr, usize(params.len))
	}
	return self.set_params_raw(params_ptr, &u8(unsafe { nil }), usize(params.len))
}

pub fn (mut self SgrParser) next() ?terminal.SgrAttribute {
	return self.parser.next()
}

pub fn unknown_full(attr terminal.SgrAttribute) []u16 {
	return attr.unknown_full
}

pub fn unknown_partial(attr terminal.SgrAttribute) []u16 {
	return attr.unknown_partial
}

pub fn attribute_tag(attr terminal.SgrAttribute) terminal.SgrAttributeKind {
	return attr.kind
}

// V callers can use the value-safe internal representation directly.
pub fn attribute_value(attr terminal.SgrAttribute) terminal.SgrAttribute {
	return attr
}

// SgrUnknownC is GhosttySgrUnknown.
pub struct SgrUnknownC {
pub mut:
	full_ptr    &u16 = unsafe { nil }
	full_len    usize
	partial_ptr &u16 = unsafe { nil }
	partial_len usize
}

// SgrAttributeValueC is the fixed 64-byte C union storage. The active member
// is selected by SgrAttributeC.tag.
pub struct SgrAttributeValueC {
pub mut:
	words [8]u64
}

// SgrAttributeC is the exact GhosttySgrAttribute C layout. The explicit
// padding places the 8-byte-aligned union at offset 8 on 64-bit targets.
pub struct SgrAttributeC {
pub mut:
	tag     terminal.SgrAttributeKind
	padding u32
	value   SgrAttributeValueC
}

// sgr_attribute_cval projects the internal safe value into Ghostty's tagged
// C union. Fields smaller than the union occupy its leading bytes.
pub fn sgr_attribute_cval(attr terminal.SgrAttribute) SgrAttributeC {
	mut result := SgrAttributeC{
		tag: attr.kind
	}
	unsafe {
		value := &u8(&result.value)
		match attr.kind {
			.unknown {
				mut unknown := &SgrUnknownC(value)
				unknown.full_ptr = if attr.unknown_full.len == 0 {
					&u16(nil)
				} else {
					&attr.unknown_full[0]
				}
				unknown.full_len = usize(attr.unknown_full.len)
				unknown.partial_ptr = if attr.unknown_partial.len == 0 {
					&u16(nil)
				} else {
					&attr.unknown_partial[0]
				}
				unknown.partial_len = usize(attr.unknown_partial.len)
			}
			.underline_set {
				*(&i32(value)) = i32(attr.underline)
			}
			.underline_color, .direct_color_fg, .direct_color_bg {
				value[0] = attr.r
				value[1] = attr.g
				value[2] = attr.b
			}
			.underline_color_256, .bg_8, .fg_8, .bright_bg_8, .bright_fg_8, .bg_256, .fg_256 {
				value[0] = attr.index
			}
			else {}
		}
	}
	return result
}

pub fn sgr_unknown_full(unknown SgrUnknownC) (&u16, usize) {
	return unknown.full_ptr, unknown.full_len
}

pub fn sgr_unknown_partial(unknown SgrUnknownC) (&u16, usize) {
	return unknown.partial_ptr, unknown.partial_len
}

// WebAssembly bindings cannot place an aggregate return value on their own
// stack, so the source exposes matching allocation helpers for SGR attributes.
pub fn wasm_alloc_attribute() &SgrAttributeC {
	raw := unsafe { malloc(sizeof(SgrAttributeC)) }
	if isnil(raw) {
		panic('out of memory')
	}
	mut attr := unsafe { &SgrAttributeC(raw) }
	unsafe {
		*attr = SgrAttributeC{}
	}
	return attr
}

pub fn wasm_free_attribute(attr &SgrAttributeC) {
	if isnil(attr) {
		return
	}
	unsafe {
		free(attr)
	}
}
