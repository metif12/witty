module tmux

// Tmux output handling - format variables and parsing.
//
// Source: terminal/tmux/output.zig
//
// Provides types and functions for parsing tmux format string output
// into structured data. The Variable enum represents the tmux format
// variables we support, and parseFormatStruct parses delimited output
// strings into typed structs.

// ============================================================
// ParseError
// ============================================================

pub enum ParseError {
	missing_entry
	extra_entry
	format_error
}

fn (self ParseError) str() string {
	return match self {
		.missing_entry { 'MissingEntry' }
		.extra_entry { 'ExtraEntry' }
		.format_error { 'FormatError' }
	}
}

// ============================================================
// Variable - possible variables in a tmux format string
// ============================================================

// Possible variables in a tmux format string that we support.
//
// Tmux supports a large number of variables, but we only implement
// a subset of them here that are relevant to the use case of implementing
// control mode for terminal emulators.
pub enum Variable {
	// 1 if pane is in alternate screen.
	alternate_on
	// Saved cursor X in alternate screen.
	alternate_saved_x
	// Saved cursor Y in alternate screen.
	alternate_saved_y
	// 1 if bracketed paste mode is enabled.
	bracketed_paste
	// 1 if the cursor is blinking.
	cursor_blinking
	// Cursor colour in pane. Possible formats:
	// - Named colors: `black`, `red`, `green`, etc.
	// - 256 colors: `colour<N>` where N is 0-255.
	// - RGB hex: `#RRGGBB`.
	// - Empty string if unset.
	cursor_colour
	// Pane cursor flag.
	cursor_flag
	// Cursor shape in pane. Possible values: `block`, `underline`, `bar`,
	// or `default`.
	cursor_shape
	// Cursor X position in pane.
	cursor_x
	// Cursor Y position in pane.
	cursor_y
	// 1 if focus reporting is enabled.
	focus_flag
	// Pane insert flag.
	insert_flag
	// Pane keypad cursor flag.
	keypad_cursor_flag
	// Pane keypad flag.
	keypad_flag
	// Pane mouse all flag.
	mouse_all_flag
	// Pane mouse any flag.
	mouse_any_flag
	// Pane mouse button flag.
	mouse_button_flag
	// Pane mouse SGR flag.
	mouse_sgr_flag
	// Pane mouse standard flag.
	mouse_standard_flag
	// Pane mouse UTF-8 flag.
	mouse_utf8_flag
	// Pane origin flag.
	origin_flag
	// Unique pane ID prefixed with `%` (e.g., `%0`, `%42`).
	pane_id
	// Pane tab positions as a comma-separated list.
	pane_tabs
	// Bottom of scroll region in pane.
	scroll_region_lower
	// Top of scroll region in pane.
	scroll_region_upper
	// Unique session ID prefixed with `$` (e.g., `$0`, `$42`).
	session_id
	// Server version (e.g., `3.5a`).
	version
	// Unique window ID prefixed with `@` (e.g., `@0`, `@42`).
	window_id
	// Width of window.
	window_width
	// Height of window.
	window_height
	// Window layout description.
	window_layout
	// Pane wrap flag.
	wrap_flag
}

// Returns the tmux format variable name.
pub fn (self Variable) name() string {
	return match self {
		.alternate_on { 'alternate_on' }
		.alternate_saved_x { 'alternate_saved_x' }
		.alternate_saved_y { 'alternate_saved_y' }
		.bracketed_paste { 'bracketed_paste' }
		.cursor_blinking { 'cursor_blinking' }
		.cursor_colour { 'cursor_colour' }
		.cursor_flag { 'cursor_flag' }
		.cursor_shape { 'cursor_shape' }
		.cursor_x { 'cursor_x' }
		.cursor_y { 'cursor_y' }
		.focus_flag { 'focus_flag' }
		.insert_flag { 'insert_flag' }
		.keypad_cursor_flag { 'keypad_cursor_flag' }
		.keypad_flag { 'keypad_flag' }
		.mouse_all_flag { 'mouse_all_flag' }
		.mouse_any_flag { 'mouse_any_flag' }
		.mouse_button_flag { 'mouse_button_flag' }
		.mouse_sgr_flag { 'mouse_sgr_flag' }
		.mouse_standard_flag { 'mouse_standard_flag' }
		.mouse_utf8_flag { 'mouse_utf8_flag' }
		.origin_flag { 'origin_flag' }
		.pane_id { 'pane_id' }
		.pane_tabs { 'pane_tabs' }
		.scroll_region_lower { 'scroll_region_lower' }
		.scroll_region_upper { 'scroll_region_upper' }
		.session_id { 'session_id' }
		.version { 'version' }
		.window_id { 'window_id' }
		.window_width { 'window_width' }
		.window_height { 'window_height' }
		.window_layout { 'window_layout' }
		.wrap_flag { 'wrap_flag' }
	}
}

// Parse an unsigned integer with Zig's `std.fmt.parseInt(usize, value, 10)`
// semantics.
fn parse_usize(value string) !usize {
	if value.len == 0 {
		return error('InvalidCharacter')
	}
	mut offset := 0
	mut negative := false
	if value[0] == `+` || value[0] == `-` {
		negative = value[0] == `-`
		offset = 1
	}
	if offset == value.len || value[offset] == `_` || value[value.len - 1] == `_` {
		return error('InvalidCharacter')
	}

	mut result := usize(0)
	for c in value[offset..] {
		if c == `_` {
			continue
		}
		if c < `0` || c > `9` {
			return error('InvalidCharacter')
		}
		digit := usize(c - `0`)
		if result > (usize(-1) - digit) / 10 {
			return error('Overflow')
		}
		result = result * 10 + digit
	}
	if negative && result != 0 {
		return error('Overflow')
	}
	return result
}

// ============================================================
// VariableValue - parsed value for a variable
// ============================================================

// VariableValue holds the parsed result of a tmux format variable.
// Depending on the variable type, it is either a bool, usize, or string.
pub type VariableValue = bool | string | usize

// Returns true if this variable type produces a boolean value.
pub fn (self Variable) is_bool() bool {
	return match self {
		.alternate_on, .bracketed_paste, .cursor_blinking, .cursor_flag, .focus_flag, .insert_flag, .keypad_cursor_flag, .keypad_flag, .mouse_all_flag, .mouse_any_flag, .mouse_button_flag, .mouse_sgr_flag, .mouse_standard_flag, .mouse_utf8_flag, .origin_flag, .wrap_flag {
			true
		}
		else {
			false
		}
	}
}

// Returns true if this variable type produces an integer value.
pub fn (self Variable) is_int() bool {
	return match self {
		.alternate_saved_x, .alternate_saved_y, .cursor_x, .cursor_y, .scroll_region_lower, .scroll_region_upper, .session_id, .window_id, .pane_id, .window_width, .window_height {
			true
		}
		else {
			false
		}
	}
}

// Returns true if this variable type produces a string value.
pub fn (self Variable) is_string() bool {
	return match self {
		.cursor_colour, .cursor_shape, .pane_tabs, .version, .window_layout {
			true
		}
		else {
			false
		}
	}
}

// Parse the given string value into the appropriate resulting
// type for this variable.
pub fn (self Variable) parse(value string) !VariableValue {
	if self.is_bool() {
		return VariableValue(value == '1')
	}

	if self.is_int() {
		return match self {
			.session_id {
				if value.len >= 2 && value[0] == `$` {
					VariableValue(parse_usize(value[1..])!)
				} else {
					return error('FormatError: session_id must start with \$')
				}
			}
			.window_id {
				if value.len >= 2 && value[0] == `@` {
					VariableValue(parse_usize(value[1..])!)
				} else {
					return error('FormatError: window_id must start with @')
				}
			}
			.pane_id {
				if value.len >= 2 && value[0] == `%` {
					VariableValue(parse_usize(value[1..])!)
				} else {
					return error('FormatError: pane_id must start with %')
				}
			}
			else {
				VariableValue(parse_usize(value)!)
			}
		}
	}

	// String type - return as-is.
	return VariableValue(value)
}

// ============================================================
// Format functions
// ============================================================

// Format a set of variables into the proper format string for tmux
// that we can handle with parse_format_struct.
pub fn format_variables(vars []Variable, delimiter u8) string {
	mut result := ''
	for i, variable in vars {
		if i != 0 {
			result += delimiter.ascii_str()
		}
		result += '#{${variable.name()}}'
	}
	return result
}

// ============================================================
// FormatResult - result from parsing a format struct
// ============================================================

// FormatResult holds the parsed values from a format string.
// The values are stored in the same order as the variables.
pub struct FormatResult {
pub:
	values []VariableValue
	vars   []Variable
}

// Get the value for a specific variable by name.
pub fn (self &FormatResult) get(v Variable) ?VariableValue {
	for i, var_ in self.vars {
		if var_ == v {
			return self.values[i]
		}
	}
	return none
}

// Get a boolean value for a specific variable.
pub fn (self &FormatResult) get_bool(v Variable) ?bool {
	val := self.get(v) or { return none }
	if val is bool {
		return val
	}
	return none
}

// Get an integer value for a specific variable.
pub fn (self &FormatResult) get_int(v Variable) ?usize {
	val := self.get(v) or { return none }
	if val is usize {
		return val
	}
	return none
}

// Get a string value for a specific variable.
pub fn (self &FormatResult) get_string(v Variable) ?string {
	val := self.get(v) or { return none }
	if val is string {
		return val
	}
	return none
}

// Parse the output from a command with the given format variables.
// The format struct is expected to be in the order of the variables
// used in the format string and the variables are expected to be
// plain variables. Each variable is expected to be separated by a
// single delimiter character.
pub fn parse_format_struct(vars []Variable, str string, delimiter u8) !FormatResult {
	parts := str.split(delimiter.ascii_str())
	if parts.len < vars.len {
		return error('MissingEntry')
	}
	if parts.len > vars.len {
		return error('ExtraEntry')
	}

	mut values := []VariableValue{cap: vars.len}
	for i, v in vars {
		val := v.parse(parts[i]) or {
			return error('FormatError: ${err.msg()}')
		}
		values << val
	}

	return FormatResult{
		values: values
		vars: vars
	}
}
