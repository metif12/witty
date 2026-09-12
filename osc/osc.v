module osc

// --- Original Ghostty Comments Start: src/terminal/osc.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/terminal/osc.zig
//
// OSC (Operating System Command) related functions and types.
//
// OSC is another set of control sequences for terminal programs that start with
// "ESC ]". Unlike CSI or standard ESC sequences, they may contain strings
// and other irregular formatting so a dedicated parser is created to handle it.
// This generally shouldn't ever be set except as an initial zero value.
// Ignore it.
// Set the window title of the terminal
//
// If title mode 0 is set text is expect to be hex encoded (i.e. utf-8
// with each code unit further encoded with two hex digits).
//
// If title mode 2 is set or the terminal is setup for unconditional
// utf-8 titles text is interpreted as utf-8. Else text is interpreted
// as latin1.
// Set the icon of the terminal window. The name of the icon is not
// well defined, so this is currently ignored by Ghostty at the time
// of writing this. We just parse it so that we don't get parse errors
// in the log.
// Semantic prompt command: https://gitlab.freedesktop.org/Per_Bothner/specifications/blob/master/proposals/semantic-prompts.md
// Set or get clipboard contents. If data is null, then the current
// clipboard contents are sent to the pty. If data is set, this
// contents is set on the clipboard.
// OSC 7. Reports the current working directory of the shell. This is
// a moderately flawed escape sequence but one that many major terminals
// support so we also support it. To understand the flaws, read through
// this terminal-wg issue: https://gitlab.freedesktop.org/terminal-wg/specifications/-/issues/20
// The reported pwd value. This is not checked for validity. It should
// be a file URL but it is up to the caller to utilize this value.
// OSC 22. Set the mouse shape. There doesn't seem to be a standard
// naming scheme for cursors but it looks like terminals such as Foot
// are moving towards using the W3C CSS cursor names. For OSC parsing,
// we just parse whatever string is given.
// OSC color operations to set, reset, or report color settings. Some OSCs
// allow multiple operations to be specified in a single OSC so we need a
// list-like datastructure to manage them. We use std.SegmentedList because
// it minimizes the number of allocations and copies because a large
// majority of the time there will be only one operation per OSC.
//
// Currently, these OSCs are handled by `color_operation`:
//
// 4, 5, 10-19, 104, 105, 110-119
// Kitty color protocol, OSC 21
// https://sw.kovidgoyal.net/kitty/color-stack/#id1
// Show a desktop notification (OSC 9 or OSC 777)
// Start a hyperlink (OSC 8)
// End a hyperlink (OSC 8)
// ConEmu sleep (OSC 9;1)
// ConEmu show GUI message box (OSC 9;2)
// ConEmu change tab title (OSC 9;3)
// ConEmu progress report (OSC 9;4)
// ConEmu wait input (OSC 9;5)
// ConEmu GUI macro (OSC 9;6)
// ConEmu run process (OSC 9;7)
// ConEmu output environment variable (OSC 9;8)
// ConEmu XTerm keyboard and output emulation (OSC 9;10)
// https://conemu.github.io/en/TerminalModes.html
// null => do not change
// false => turn off
// true => turn on
// null => do not change
// false => turn off
// true => turn on
// ConEmu comment (OSC 9;11)
// Kitty text sizing protocol (OSC 66)
// NOTE: Order matters, see LibEnum documentation.
// sync with ghostty_action_progress_report_s
// @compileLog(@sizeOf(Command));
// The terminator used to end an OSC command. For OSC commands that demand
// a response, we try to match the terminator used in the request since that
// is most likely to be accepted by the calling program.
// The preferred string terminator is ESC followed by \
// Some applications and terminals use BELL (0x07) as the string terminator.
// Initialize the terminator based on the last byte seen. If the
// last byte is a BEL then we use BEL, otherwise we just assume ST.
// The terminator as a string. This is static memory so it doesn't
// need to be freed.
// Maximum size of a "normal" OSC.
// Optional allocator used to accept data longer than MAX_BUF.
// This only applies to some commands (e.g. OSC 52) that can
// reasonably exceed MAX_BUF.
// Current state of the parser.
// Buffer for temporary storage of OSC data
// Fixed writer for accumulating OSC data
// Allocating writer for accumulating OSC data
// Pointer to the active writer for accumulating OSC data
// The command that is the result of parsing.
// OSC command prefixes. Not all of these are valid OSCs, but may be
// needed to "bridge" to a valid OSC (e.g. to support OSC 777 we need to
// have a state "77" even though there is no OSC 77).
// Keeping all our undefined values together so we can
// visually easily duplicate them in the Valgrind check below.
// Initialize our undefined fields so Valgrind can catch it.
// https://github.com/ziglang/zig/issues/19148
// This must be called to clean up any allocated memory.
// Reset the parser state.
// If we set up an allocating writer, free up that memory.
// Handle any cleanup that individual OSCs require.
// Initialize our undefined fields so Valgrind can catch it.
// https://github.com/ziglang/zig/issues/19148
// Make sure that we have an allocator. If we don't, set the state to
// invalid so that any additional OSC data is discarded.
// Set up a fixed Writer to collect the rest of the OSC data.
// Set up an allocating Writer to collect the rest of the OSC data. If we
// don't have an allocator or setting up the allocator fails, fall back to
// writing to a fixed buffer and hope that it's big enough.
// We don't have an allocator - fall back to a fixed buffer and hope
// that it's big enough.
// The allocator failed for some reason, fall back to a fixed buffer
// and hope that it's big enough.
// Consume the next character c and advance the parser state.
// If the state becomes invalid for any reason, just discard
// any further input.
// If a writer has been initialized, we just accumulate the rest of the
// OSC sequence in the writer's buffer and skip the state machine.
// We have overflowed our buffer or had some other error, set the
// state to invalid so that we discard any further input.
// handled above, so should never be here
// End the sequence and return the command, if any. If the return value
// is null, then no valid command was found. The optional terminator_ch
// is the final character in the OSC sequence. This is used to determine
// the response terminator.
//
// The returned pointer is only valid until the next call to the parser.
// Callers should copy out any data they wish to retain across calls.
//
// --- Original Ghostty Comments End: src/terminal/osc.zig

// OSC (Operating System Command) related functions and types.
//
// OSC is another set of control sequences for terminal programs that start with
// "ESC ]". Unlike CSI or standard ESC sequences, they may contain strings
// and other irregular formatting so a dedicated parser is created to handle it.

// Maximum size of a "normal" OSC.
pub const max_buf = 2048

// The terminator used to end an OSC command. For OSC commands that demand
// a response, we try to match the terminator used in the request since that
// is most likely to be accepted by the calling program.
pub enum Terminator as u8 {
	// The preferred string terminator is ESC followed by \
	st
	// Some applications and terminals use BELL (0x07) as the string terminator.
	bel
}

// TerminatorC is the C ABI representation of Terminator.
pub enum TerminatorC as int {
	st
	bel
}

// init creates a terminator based on the last byte seen.
// If the last byte is a BEL then we use BEL, otherwise we just assume ST.
pub fn Terminator.init(ch ?u8) Terminator {
	return if ch or { return .st } == 0x07 { Terminator.bel } else { Terminator.st }
}

// string returns the wire representation of this terminator.
pub fn (self Terminator) string() string {
	return match self {
		.st { '\x1b\\' }
		.bel { '\x07' }
	}
}

// cval returns the C ABI representation of this terminator.
pub fn (self Terminator) cval() TerminatorC {
	return match self {
		.st { .st }
		.bel { .bel }
	}
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

// ProgressReportC is the C ABI representation of ProgressReport.
pub struct ProgressReportC {
pub:
	state    int
	progress i8
}

// cval converts a progress report to its source C ABI layout.
pub fn (self ProgressReport) cval() ProgressReportC {
	progress := if value := self.progress {
		clamped := if value > 100 { u8(100) } else { value }
		i8(clamped)
	} else {
		i8(-1)
	}
	return ProgressReportC{
		state: int(self.state)
		progress: progress
	}
}

// DesktopNotification is the parsed payload for OSC 9 and OSC 777.
pub struct DesktopNotification {
pub:
	title string
	body  string
}

// ClipboardContents is the parsed payload for OSC 52 and iTerm2 Copy.
pub struct ClipboardContents {
pub:
	kind u8
	data string
}

// HyperlinkStart is the parsed payload for OSC 8.
pub struct HyperlinkStart {
pub:
	uri string
	id  ?string
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
	str_value string
	// ConEmu sleep duration
	duration_ms u16
	// ConEmu progress report
	progress_state ProgressState
	progress       ?u8
	// OSC 9 / OSC 777 desktop notification.
	desktop_notification DesktopNotification
	// OSC 52 / iTerm2 clipboard payload.
	clipboard ClipboardContents
	// OSC 8 hyperlink payload.
	hyperlink HyperlinkStart
	// OSC 66 Kitty text-sizing payload.
	kitty_text_sizing KittyTextSizing
	// ConEmu xterm emulation
	xterm_keyboard ?bool
	xterm_output   ?bool
	// ConEmu tab title
	tab_title ConEmuTabTitle
	// Semantic prompt data (OSC 133)
	semantic_prompt_action SemanticAction = .fresh_line
	// Color operation (OSC 4, 5, 10-19, 104, 105, 110-119). `color_op`
	// identifies which OSC produced this and `color_requests` holds the
	// parsed list of set/query/reset requests. (ColorOperation and
	// ColorRequest are defined in color_parser.v.)
	color_op       ColorOperation
	color_requests []ColorRequest
	// Kitty color protocol (OSC 21). Holds the parsed list of query/set/reset
	// items so downstream consumers can apply them without re-parsing
	// str_value. (KittyColorItem is defined in kitty_color.v.)
	kitty_color_items []KittyColorItem
pub mut:
	semantic_prompt_options string
}

// OscParserState tracks where we are in parsing the OSC number prefix.
pub enum OscParserState {
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

// OscWriter tracks the source writer selected for a payload. Normal OSCs use
// the fixed 2 KiB buffer; OSC 52 and OSC 66 use the allocating writer.
enum OscWriter {
	none
	fixed
	allocating
}

// Parser accumulates bytes of an OSC sequence and dispatches to
// the appropriate sub-parser on end().
pub struct Parser {
pub mut:
	// Whether the source parser was initialized with an allocator. V's arrays
	// are GC-managed, but the flag preserves Ghostty's allocation-free parser
	// contract for commands whose result itself requires allocation.
	has_allocator bool

	// Current state of the parser.
	state OscParserState = .start

	// Buffer for accumulating OSC data after the semicolon.
	buf []u8

	// Active source writer for accumulating data after the semicolon.
	writer OscWriter

	// The command that is the result of parsing.
	command Command
}

// init creates a new OSC Parser. V owns storage through its GC, while the
// allocator's presence still controls the same source parser capabilities.
pub fn Parser.init(allocator voidptr) Parser {
	return Parser{
		has_allocator: unsafe { allocator != nil }
	}
}

// deinit frees any allocated resources.
pub fn (mut self Parser) deinit() {
	self.reset()
}

// reset resets the parser state.
pub fn (mut self Parser) reset() {
	self.state = .start
	self.buf = []
	self.writer = .none
	self.command = Command{}
}

// ensure_allocator rejects OSCs whose parsed command requires allocation when
// the parser was initialized in allocation-free mode.
fn (mut self Parser) ensure_allocator() bool {
	if self.has_allocator {
		return true
	}
	self.state = .invalid
	return false
}

// write_to_fixed selects Ghostty's fixed-size writer.
fn (mut self Parser) write_to_fixed() {
	self.writer = .fixed
	self.buf = []
}

// write_to_allocating selects Ghostty's allocating writer. V's backing array
// already grows dynamically, so only the writer identity needs translation.
fn (mut self Parser) write_to_allocating() {
	self.writer = if self.has_allocator { .allocating } else { .fixed }
	self.buf = []
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
	if self.writer != .none {
		self.write_byte(c)
		return
	}

	match self.state {
		.invalid {
			// handled above, should never be here
		}
		.start {
			match c {
				`0` {
					self.state = .s_0
				}
				`1` {
					self.state = .s_1
				}
				`2` {
					self.state = .s_2
				}
				`4` {
					self.state = .s_4
				}
				`5` {
					self.state = .s_5
				}
				`6` {
					self.state = .s_6
				}
				`7` {
					self.state = .s_7
				}
				`8` {
					self.state = .s_8
				}
				`9` {
					self.state = .s_9
				}
				else {
					self.state = .invalid
				}
			}
		}
		.s_1 {
			match c {
				`;` { self.write_to_fixed() }
				`0` {
					self.state = .s_10
				}
				`1` {
					self.state = .s_11
				}
				`2` {
					self.state = .s_12
				}
				`3` {
					self.state = .s_13
				}
				`4` {
					self.state = .s_14
				}
				`5` {
					self.state = .s_15
				}
				`6` {
					self.state = .s_16
				}
				`7` {
					self.state = .s_17
				}
				`8` {
					self.state = .s_18
				}
				`9` {
					self.state = .s_19
				}
				else {
					self.state = .invalid
				}
			}
		}
		.s_10 {
			match c {
				`;` {
					if self.ensure_allocator() {
						self.write_to_fixed()
					}
				}
				`4` {
					self.state = .s_104
				}
				else {
					self.state = .invalid
				}
			}
		}
		.s_11 {
			match c {
				`;` {
					if self.ensure_allocator() {
						self.write_to_fixed()
					}
				}
				`0` {
					self.state = .s_110
				}
				`1` {
					self.state = .s_111
				}
				`2` {
					self.state = .s_112
				}
				`3` {
					self.state = .s_113
				}
				`4` {
					self.state = .s_114
				}
				`5` {
					self.state = .s_115
				}
				`6` {
					self.state = .s_116
				}
				`7` {
					self.state = .s_117
				}
				`8` {
					self.state = .s_118
				}
				`9` {
					self.state = .s_119
				}
				else {
					self.state = .invalid
				}
			}
		}
		.s_13 {
			match c {
				`;` {
					if self.ensure_allocator() {
						self.write_to_fixed()
					}
				}
				`3` {
					self.state = .s_133
				}
				else {
					self.state = .invalid
				}
			}
		}
		.s_2 {
			match c {
				`;` { self.write_to_fixed() }
				`1` {
					self.state = .s_21
				}
				`2` {
					self.state = .s_22
				}
				else {
					self.state = .invalid
				}
			}
		}
		.s_5 {
			match c {
				`;` {
					if self.ensure_allocator() {
						self.write_to_fixed()
					}
				}
				`2` {
					self.state = .s_52
				}
				else {
					self.state = .invalid
				}
			}
		}
		.s_6 {
			match c {
				`6` {
					self.state = .s_66
				}
				else {
					self.state = .invalid
				}
			}
		}
		.s_7 {
			match c {
				`;` { self.write_to_fixed() }
				`7` {
					self.state = .s_77
				}
				else {
					self.state = .invalid
				}
			}
		}
		.s_77 {
			match c {
				`7` {
					self.state = .s_777
				}
				else {
					self.state = .invalid
				}
			}
		}
		.s_133 {
			match c {
				`;` { self.write_to_fixed() }
				`7` {
					self.state = .s_1337
				}
				else {
					self.state = .invalid
				}
			}
		}
		.s_0, .s_22, .s_777, .s_8, .s_9 {
			match c {
				`;` { self.write_to_fixed() }
				else {
					self.state = .invalid
				}
			}
		}
		.s_52, .s_66 {
			match c {
				`;` { self.write_to_allocating() }
				else {
					self.state = .invalid
				}
			}
		}
		.s_4, .s_12, .s_14, .s_15, .s_16, .s_17, .s_18, .s_19, .s_21, .s_104, .s_110, .s_111, .s_112, .s_113, .s_114, .s_115, .s_116, .s_117, .s_118, .s_119 {
			match c {
				`;` {
					if self.ensure_allocator() {
						self.write_to_fixed()
					}
				}
				else {
					self.state = .invalid
				}
			}
		}
		.s_1337 {
			match c {
				`;` { self.write_to_fixed() }
				else {
					self.state = .invalid
				}
			}
		}
	}
}

// buffered returns the currently buffered data as a byte slice.
pub fn (self &Parser) buffered() []u8 {
	return self.buf
}

// write_byte appends a byte to the buffer.
pub fn (mut self Parser) write_byte(b u8) {
	if self.writer == .none {
		self.state = .invalid
		return
	}
	if self.writer == .fixed && self.buf.len >= max_buf {
		self.state = .invalid
		return
	}
	self.buf << b
}

// finish_zero_terminated mirrors parsers that append a sentinel byte before
// exposing a source sentinel-terminated slice. V strings do not retain that
// sentinel, but the fixed writer must still have room for it.
fn (mut self Parser) finish_zero_terminated() ?[]u8 {
	if self.writer == .none || (self.writer == .fixed && self.buf.len >= max_buf) {
		self.state = .invalid
		return none
	}
	return self.buf
}

// end finalizes parsing and returns the command, if any.
// The optional terminator_ch is the final character in the OSC sequence.
pub fn (mut self Parser) end(terminator_ch ?u8) ?Command {
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
		.s_4, .s_5, .s_10, .s_11, .s_12, .s_13, .s_14, .s_15, .s_16, .s_17, .s_18, .s_19, .s_104, .s_110, .s_111, .s_112, .s_113, .s_114, .s_115, .s_116, .s_117, .s_118, .s_119 {
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
