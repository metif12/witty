module osc

// OSC (Operating System Command) related functions and types.
//
// OSC is another set of control sequences for terminal programs that start with
// "ESC ]". Unlike CSI or standard ESC sequences, they may contain strings
// and other irregular formatting so a dedicated parser is created to handle it.

// Maximum size of a "normal" OSC.
const max_buf = 2048

// The terminator used to end an OSC command. For OSC commands that demand
// a response, we try to match the terminator used in the request since that
// is most likely to be accepted by the calling program.
pub enum Terminator {
	// The preferred string terminator is ESC followed by \
	st
	// Some applications and terminals use BELL (0x07) as the string terminator.
	bel
}

// init_terminator creates a terminator based on the last byte seen.
// If the last byte is a BEL then we use BEL, otherwise we just assume ST.
pub fn init_terminator(ch u8) Terminator {
	return if ch == 0x07 { Terminator.bel } else { Terminator.st }
}

// ProgressState represents the state of a ConEmu progress report.
pub enum ProgressState {
	remove
	set
	err_state
	indeterminate
	pause
}

// ProgressReport represents a ConEmu-style progress report.
// Sync with: ghostty_action_progress_report_s
pub struct ProgressReport {
pub:
	state    ProgressState
	progress ?u8
}

// ConEmuTabTitle represents a ConEmu tab title value (reset or set to a string).
pub enum ConEmuTabTitleKind {
	reset
	value
}

pub struct ConEmuTabTitle {
pub:
	kind  ConEmuTabTitleKind
	value string
}

// CommandType identifies the type of OSC command.
pub enum CommandType {
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
	conemu_sleep
	conemu_show_message_box
	conemu_change_tab_title
	conemu_progress_report
	conemu_wait_input
	conemu_guimacro
	conemu_run_process
	conemu_output_environment_variable
	conemu_xterm_emulation
	conemu_comment
	kitty_text_sizing
}

// Command represents a parsed OSC command.
pub struct Command {
pub:
	cmd_type   CommandType
	terminator Terminator
	// String data fields (used by various commands)
	str_value  string
	str_value2 string
	// ConEmu sleep duration
	duration_ms u16
	// ConEmu progress report
	progress_state ProgressState
	progress       ?u8
	// ConEmu xterm emulation
	xterm_keyboard ?bool
	xterm_output   ?bool
	// ConEmu tab title
	tab_title ConEmuTabTitle
	// Semantic prompt data (OSC 133)
	semantic_prompt_action SemanticAction = .fresh_line
pub mut:
	semantic_prompt_options string
}

// OscParserState tracks where we are in parsing the OSC number prefix.
enum OscParserState {
	start
	invalid
	s_0
	s_1
	s_2
	s_4
	s_5
	s_6
	s_7
	s_8
	s_9
	s_10
	s_11
	s_12
	s_13
	s_14
	s_15
	s_16
	s_17
	s_18
	s_19
	s_21
	s_22
	s_52
	s_66
	s_77
	s_104
	s_110
	s_111
	s_112
	s_113
	s_114
	s_115
	s_116
	s_117
	s_118
	s_119
	s_133
	s_777
	s_1337
}

// Parser accumulates bytes of an OSC sequence and dispatches to
// the appropriate sub-parser on end().
pub struct Parser {
pub mut:
	// Current state of the parser.
	state OscParserState = .start

	// Buffer for accumulating OSC data after the semicolon.
	buf []u8

	// Whether we're in "writing" mode (accumulating data after semicolon).
	writing bool

	// The command that is the result of parsing.
	command Command
}

// init creates a new OSC Parser. The allocator parameter is accepted
// for API compatibility but not used in this implementation.
pub fn Parser.init(allocator voidptr) Parser {
	return Parser{}
}

// deinit frees any allocated resources.
pub fn (mut self Parser) deinit() {
	self.reset()
}

// reset resets the parser state.
pub fn (mut self Parser) reset() {
	self.state = .start
	self.buf = []
	self.writing = false
	self.command = Command{}
}

// next processes the next byte of OSC data.
pub fn (mut self Parser) next(c u8) {
	// If the state becomes invalid for any reason, just discard
	// any further input.
	if self.state == .invalid {
		return
	}

	// If a writer has been initialized, we just accumulate the rest of the
	// OSC sequence in the buffer and skip the state machine.
	if self.writing {
		self.buf << c
		return
	}

	match self.state {
		.invalid {
			// handled above, should never be here
		}
		.start {
			match c {
				`0` { self.state = .s_0 }
				`1` { self.state = .s_1 }
				`2` { self.state = .s_2 }
				`4` { self.state = .s_4 }
				`5` { self.state = .s_5 }
				`6` { self.state = .s_6 }
				`7` { self.state = .s_7 }
				`8` { self.state = .s_8 }
				`9` { self.state = .s_9 }
				else { self.state = .invalid }
			}
		}
		.s_1 {
			match c {
				`;` { self.start_writing() }
				`0` { self.state = .s_10 }
				`1` { self.state = .s_11 }
				`2` { self.state = .s_12 }
				`3` { self.state = .s_13 }
				`4` { self.state = .s_14 }
				`5` { self.state = .s_15 }
				`6` { self.state = .s_16 }
				`7` { self.state = .s_17 }
				`8` { self.state = .s_18 }
				`9` { self.state = .s_19 }
				else { self.state = .invalid }
			}
		}
		.s_10 {
			match c {
				`;` { self.start_writing() }
				`4` { self.state = .s_104 }
				else { self.state = .invalid }
			}
		}
		.s_11 {
			match c {
				`;` { self.start_writing() }
				`0` { self.state = .s_110 }
				`1` { self.state = .s_111 }
				`2` { self.state = .s_112 }
				`3` { self.state = .s_113 }
				`4` { self.state = .s_114 }
				`5` { self.state = .s_115 }
				`6` { self.state = .s_116 }
				`7` { self.state = .s_117 }
				`8` { self.state = .s_118 }
				`9` { self.state = .s_119 }
				else { self.state = .invalid }
			}
		}
		.s_13 {
			match c {
				`;` { self.start_writing() }
				`3` { self.state = .s_133 }
				else { self.state = .invalid }
			}
		}
		.s_2 {
			match c {
				`;` { self.start_writing() }
				`1` { self.state = .s_21 }
				`2` { self.state = .s_22 }
				else { self.state = .invalid }
			}
		}
		.s_5 {
			match c {
				`;` { self.start_writing() }
				`2` { self.state = .s_52 }
				else { self.state = .invalid }
			}
		}
		.s_6 {
			match c {
				`6` { self.state = .s_66 }
				else { self.state = .invalid }
			}
		}
		.s_7 {
			match c {
				`;` { self.start_writing() }
				`7` { self.state = .s_77 }
				else { self.state = .invalid }
			}
		}
		.s_77 {
			match c {
				`7` { self.state = .s_777 }
				else { self.state = .invalid }
			}
		}
		.s_133 {
			match c {
				`;` { self.start_writing() }
				`7` { self.state = .s_1337 }
				else { self.state = .invalid }
			}
		}
		.s_0, .s_22, .s_777, .s_8, .s_9 {
			match c {
				`;` { self.start_writing() }
				else { self.state = .invalid }
			}
		}
		.s_4, .s_12, .s_14, .s_15, .s_16, .s_17, .s_18, .s_19,
		.s_21, .s_52, .s_66, .s_104, .s_110, .s_111, .s_112, .s_113,
		.s_114, .s_115, .s_116, .s_117, .s_118, .s_119, .s_1337 {
			match c {
				`;` { self.start_writing() }
				else { self.state = .invalid }
			}
		}
	}
}

// start_writing transitions the parser to accumulating data.
fn (mut self Parser) start_writing() {
	self.writing = true
	self.buf = []
}

// buffered returns the currently buffered data as a byte slice.
pub fn (self &Parser) buffered() []u8 {
	return self.buf
}

// write_byte appends a byte to the buffer.
pub fn (mut self Parser) write_byte(b u8) {
	self.buf << b
}

// end finalizes parsing and returns the command, if any.
// The optional terminator_ch is the final character in the OSC sequence.
pub fn (mut self Parser) end(terminator_ch u8) ?Command {
	match self.state {
		.start, .invalid {
			return none
		}
		.s_0, .s_2 {
			return parse_change_window_title(mut self, terminator_ch)
		}
		.s_1 {
			return parse_change_window_icon(mut self, terminator_ch)
		}
		.s_4, .s_5, .s_10, .s_11, .s_12, .s_13, .s_14, .s_15,
		.s_16, .s_17, .s_18, .s_19, .s_104, .s_110, .s_111,
		.s_112, .s_113, .s_114, .s_115, .s_116, .s_117, .s_118,
		.s_119 {
			return parse_color_operation(mut self, terminator_ch)
		}
		.s_7 {
			return parse_report_pwd(mut self, terminator_ch)
		}
		.s_8 {
			return parse_hyperlink(mut self, terminator_ch)
		}
		.s_9 {
			return parse_osc9(mut self, terminator_ch)
		}
		.s_21 {
			return parse_kitty_color_protocol(mut self, terminator_ch)
		}
		.s_22 {
			return parse_mouse_shape(mut self, terminator_ch)
		}
		.s_52 {
			return parse_clipboard_operation(mut self, terminator_ch)
		}
		.s_6 {
			// OSC 6 is not a valid OSC by itself (bridge state to 66)
			return none
		}
		.s_66 {
			return parse_kitty_text_sizing(mut self, terminator_ch)
		}
		.s_77 {
			// OSC 77 is not a valid OSC by itself (bridge state to 777)
			return none
		}
		.s_133 {
			return parse_osc133(mut self, terminator_ch)
		}
		.s_777 {
			return parse_rxvt_extension(mut self, terminator_ch)
		}
		.s_1337 {
			return parse_iterm2(mut self, terminator_ch)
		}
	}
}
