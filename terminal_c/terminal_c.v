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

// ============================================================
// Result (from c/result.zig)
// ============================================================

// Result represents the outcome of a C API operation.
// C: GhosttyResult
pub enum Result {
	success        // 0
	out_of_memory  // -1
	invalid_value  // -2
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
		parser: osc.Parser{}
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

// CommandData enumerates the types of data that can be extracted
// from an OSC command through the C API.
// C: GhosttyOscCommandData
pub enum CommandData {
	invalid                  // 0
	change_window_title_str  // 1
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
