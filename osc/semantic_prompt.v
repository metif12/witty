module osc

// Semantic prompt parsing for OSC 133.
//
// https://gitlab.freedesktop.org/Per_Bothner/specifications/blob/master/proposals/semantic-prompts.md

// A semantic prompt action.
pub enum SemanticAction as u8 {
	fresh_line // 'L'
	fresh_line_new_prompt // 'A'
	new_command // 'N'
	prompt_start // 'P'
	end_prompt_start_input // 'B'
	end_prompt_start_input_terminate_eol // 'I'
	end_input_start_output // 'C'
	end_command // 'D'
}

// The `cl` option specifies what kind of cursor key sequences are handled
// by the application for click-to-move-cursor functionality.
pub enum Click as u8 {
	// Value: "line". Allows motion within a single input line using standard
	// left/right arrow escape sequences. Only a single left/right sequence
	// should be emitted for double-width characters.
	line
	// Value: "m". Allows movement between different lines in the same group,
	// but only using left/right arrow escape sequences.
	multiple
	// Value: "v". Like `multiple` but cursor up/down should be used. The
	// terminal should be conservative when moving between lines: move the
	// cursor left to the start of line, emit the needed up/down sequences,
	// then move the cursor right to the clicked destination.
	conservative_vertical
	// Value: "w". Like `conservative_vertical` but specifies that there are
	// no spurious spaces at the end of the line, and the application editor
	// handles "smart vertical movement".
	smart_vertical
}

// Parse a Click value from a string.
pub fn Click.init(value string) ?Click {
	if value.len == 1 {
		match value[0] {
			`m` {
				return .multiple
			}
			`v` {
				return .conservative_vertical
			}
			`w` {
				return .smart_vertical
			}
			else {
				return none
			}
		}
	} else if value == 'line' {
		return .line
	}
	return none
}

pub enum PromptKind as u8 {
	initial
	right
	continuation
	secondary
}

// Parse a PromptKind from a single character.
pub fn PromptKind.init(c u8) ?PromptKind {
	match c {
		`i` {
			return .initial
		}
		`r` {
			return .right
		}
		`c` {
			return .continuation
		}
		`s` {
			return .secondary
		}
		else {
			return none
		}
	}
}

// The values for the `redraw` extension to OSC133. This was
// started by Kitty[1] and extended by Ghostty (the "last" option).
//
// [1]: https://sw.kovidgoyal.net/kitty/shell-integration/#notes-for-shell-developers
pub enum Redraw as u8 {
	// The shell supports redrawing the full prompt and all continuations.
	// This is the default value, it does not need to be explicitly set
	// unless it is to reset a prior other value.
	redraw_true  = 0
	// The shell does NOT support redrawing. In this case, Ghostty will NOT
	// clear any prompt lines on resize.
	redraw_false = 1
	// The shell supports redrawing only the LAST line of the prompt.
	// Ghostty will only clear the last line of the prompt on resize.
	//
	// This is specifically introduced because Bash only redraws the last
	// line. It is literally the only shell that does this and it does this
	// because its bad and they should feel bad. Don't be like Bash.
	last         = 2
}

// ============================================================
// Option reading from raw options string
// ============================================================

// read_option_raw finds the value for a given key in a semicolon-separated
// options string (e.g. "aid=14;cl=line"). Returns the value string or none.
// Any errors in the raw string will return none since the OSC133
// specification says to ignore unknown or malformed options.
fn read_option_raw(raw string, key string) ?string {
	mut remaining := raw
	for remaining.len > 0 {
		// Length of the next value is up to the `;` or the end of the string.
		sep := remaining.index_u8(`;`)
		len := if sep >= 0 { sep } else { remaining.len }

		// Grab our full value and move our cursor past the `;`.
		full := unsafe { remaining[..len] }

		// Parse our key=value and verify our key matches our expectation.
		eq := full.index_u8(`=`)
		if eq >= 0 {
			if full[..eq] == key {
				return full[eq + 1..]
			}
		}

		// No match, advance.
		if len < remaining.len {
			remaining = remaining[len + 1..]
		} else {
			break
		}
	}
	return none
}

// Read the 'aid' option (application identifier). Returns the aid string or none.
pub fn read_aid(raw string) ?string {
	return read_option_raw(raw, 'aid')
}

// Read the 'cl' option (click type). Returns the Click enum value or none.
pub fn read_click(raw string) ?Click {
	value := read_option_raw(raw, 'cl') or { return none }
	return Click.init(value)
}

// Read the 'k' option (prompt kind). Returns the PromptKind enum value or none.
pub fn read_prompt_kind(raw string) ?PromptKind {
	value := read_option_raw(raw, 'k') or { return none }
	if value.len == 1 {
		return PromptKind.init(value[0])
	}
	return none
}

// Read the 'err' option (error string). Returns the error string or none.
pub fn read_err(raw string) ?string {
	return read_option_raw(raw, 'err')
}

// Read the 'redraw' option. Returns the Redraw enum value or none.
pub fn read_redraw(raw string) ?Redraw {
	value := read_option_raw(raw, 'redraw') or { return none }
	if value == '0' {
		return .redraw_false
	} else if value == '1' {
		return .redraw_true
	} else if value == 'last' {
		return .last
	}
	return none
}

// Read the 'special_key' option. Returns bool or none.
pub fn read_special_key(raw string) ?bool {
	value := read_option_raw(raw, 'special_key') or { return none }
	if value.len == 1 {
		match value[0] {
			`0` {
				return false
			}
			`1` {
				return true
			}
			else {
				return none
			}
		}
	}
	return none
}

// Read the 'click_events' option. Returns bool or none.
pub fn read_click_events(raw string) ?bool {
	value := read_option_raw(raw, 'click_events') or { return none }
	if value.len == 1 {
		match value[0] {
			`0` {
				return false
			}
			`1` {
				return true
			}
			else {
				return none
			}
		}
	}
	return none
}

// Read the exit code (first value before any key=value pairs).
// Not technically an option that can be set with k=v and only
// present currently with command 'D' but its easier to just
// parse it into our options.
pub fn read_exit_code(raw string) ?i32 {
	if raw.len == 0 {
		return none
	}
	// The exit code is the first value, up to the first semicolon.
	sep := raw.index_u8(`;`)
	code_str := if sep >= 0 { raw[..sep] } else { raw }
	return i32(parse_int_signed_decimal(code_str, u64(max_i32), u64(max_i32) + 1) or {
		return none
	})
}

// ============================================================
// Parse OSC 133 semantic prompt commands
// ============================================================

// parse_osc133 parses a semantic prompt command from the OSC parser buffer.
pub fn parse_osc133(mut parser Parser, _ ?u8) ?Command {
	data := parser.buffered()
	if data.len == 0 {
		parser.state = .invalid
		return none
	}

	// All valid cases terminate within this block. Any fallthroughs
	// are invalid. This makes some of our parse logic a little less
	// repetitive.

	match data[0] {
		`A` {
			parser.command = SemanticPrompt.init(.fresh_line_new_prompt)
			if data.len == 1 {
				return parser.command
			}
			if data[1] != `;` {
				parser.state = .invalid
				return none
			}
			parser.set_semantic_prompt_options(data[2..].bytestr())
			return parser.command
		}
		`B` {
			parser.command = SemanticPrompt.init(.end_prompt_start_input)
			if data.len == 1 {
				return parser.command
			}
			if data[1] != `;` {
				parser.state = .invalid
				return none
			}
			parser.set_semantic_prompt_options(data[2..].bytestr())
			return parser.command
		}
		`I` {
			parser.command = SemanticPrompt.init(.end_prompt_start_input_terminate_eol)
			if data.len == 1 {
				return parser.command
			}
			if data[1] != `;` {
				parser.state = .invalid
				return none
			}
			parser.set_semantic_prompt_options(data[2..].bytestr())
			return parser.command
		}
		`C` {
			parser.command = SemanticPrompt.init(.end_input_start_output)
			if data.len == 1 {
				return parser.command
			}
			if data[1] != `;` {
				parser.state = .invalid
				return none
			}
			parser.set_semantic_prompt_options(data[2..].bytestr())
			return parser.command
		}
		`D` {
			parser.command = SemanticPrompt.init(.end_command)
			if data.len == 1 {
				return parser.command
			}
			if data[1] != `;` {
				parser.state = .invalid
				return none
			}
			parser.set_semantic_prompt_options(data[2..].bytestr())
			return parser.command
		}
		`L` {
			if data.len > 1 {
				parser.state = .invalid
				return none
			}
			parser.command = SemanticPrompt.init(.fresh_line)
			return parser.command
		}
		`N` {
			parser.command = SemanticPrompt.init(.new_command)
			if data.len == 1 {
				return parser.command
			}
			if data[1] != `;` {
				parser.state = .invalid
				return none
			}
			parser.set_semantic_prompt_options(data[2..].bytestr())
			return parser.command
		}
		`P` {
			parser.command = SemanticPrompt.init(.prompt_start)
			if data.len == 1 {
				return parser.command
			}
			if data[1] != `;` {
				parser.state = .invalid
				return none
			}
			parser.set_semantic_prompt_options(data[2..].bytestr())
			return parser.command
		}
		else {}
	}

	// Any fallthroughs are invalid.
	parser.state = .invalid
	return none
}

// parser.command.semantic_prompt.options_unvalidated = options
fn (mut self Parser) set_semantic_prompt_options(options string) {
	if mut self.command is SemanticPrompt {
		self.command.options_unvalidated = options
	}
}
