module tmux

// Tmux control mode parser.
//
// Source: terminal/tmux/control.zig
//
// This file contains the implementation for tmux control mode. See
// tmux(1) for more information on control mode. Some basics are documented
// here but this is not meant to be a comprehensive source of protocol
// documentation.

import regex

// ============================================================
// Notification - possible notification types from tmux control mode
// ============================================================

// Possible notification types from tmux control mode. These are documented
// in tmux(1). A lot of the simple documentation was copied from that man
// page here.
pub type Notification = NotifEnter
	| NotifExit
	| NotifBlockEnd
	| NotifBlockErr
	| NotifOutput
	| NotifSessionChanged
	| NotifSessionsChanged
	| NotifLayoutChange
	| NotifWindowAdd
	| NotifWindowRenamed
	| NotifWindowPaneChanged
	| NotifClientDetached
	| NotifClientSessionChanged

// Entering tmux control mode. This isn't an actual event sent by
// tmux but is one sent by us to indicate that we have detected that
// tmux control mode is starting.
pub struct NotifEnter {}

// Exit.
//
// NOTE: The tmux protocol contains a "reason" string (human friendly)
// associated with this. We currently drop it because we don't need it
// but this may be something we want to add later. If we do add it,
// we have to consider buffer limits and how we handle those (dropping
// vs truncating, etc.).
pub struct NotifExit {}

// Dispatched at the end of a begin/end block with the raw data.
// The control mode parser can't parse the data because it is unaware
// of the command that was sent to trigger this output.
pub struct NotifBlockEnd {
pub:
	data string
}

pub struct NotifBlockErr {
pub:
	data string
}

// Raw output from a pane.
pub struct NotifOutput {
pub:
	pane_id usize
	data    string // unescaped
}

// The client is now attached to the session with ID session-id, which is
// named name.
pub struct NotifSessionChanged {
pub:
	id   usize
	name string
}

// A session was created or destroyed.
pub struct NotifSessionsChanged {}

// The layout of the window with ID window-id changed.
pub struct NotifLayoutChange {
pub:
	window_id      usize
	layout         string
	visible_layout string
	raw_flags      string
}

// The window with ID window-id was linked to the current session.
pub struct NotifWindowAdd {
pub:
	id usize
}

// The window with ID window-id was renamed to name.
pub struct NotifWindowRenamed {
pub:
	id   usize
	name string
}

// The active pane in the window with ID window-id changed to the pane
// with ID pane-id.
pub struct NotifWindowPaneChanged {
pub:
	window_id usize
	pane_id   usize
}

// The client has detached.
pub struct NotifClientDetached {
pub:
	client string
}

// The client is now attached to the session with ID session-id, which is
// named name.
pub struct NotifClientSessionChanged {
pub:
	client     string
	session_id usize
	name       string
}

// Format a notification for display/logging.
pub fn (self Notification) str() string {
	return match self {
		NotifEnter { 'Notification{ .enter }' }
		NotifExit { 'Notification{ .exit }' }
		NotifBlockEnd { 'Notification{ .block_end = "${self.data}" }' }
		NotifBlockErr { 'Notification{ .block_err = "${self.data}" }' }
		NotifOutput { 'Notification{ .output = pane_id=${self.pane_id} }' }
		NotifSessionChanged {
			'Notification{ .session_changed = id=${self.id} name="${self.name}" }'
		}
		NotifSessionsChanged { 'Notification{ .sessions_changed }' }
		NotifLayoutChange { 'Notification{ .layout_change = window_id=${self.window_id} }' }
		NotifWindowAdd { 'Notification{ .window_add = id=${self.id} }' }
		NotifWindowRenamed { 'Notification{ .window_renamed = id=${self.id} name="${self.name}" }' }
		NotifWindowPaneChanged {
			'Notification{ .window_pane_changed = window_id=${self.window_id} pane_id=${self.pane_id} }'
		}
		NotifClientDetached { 'Notification{ .client_detached = client="${self.client}" }' }
		NotifClientSessionChanged {
			'Notification{ .client_session_changed = client="${self.client}" session_id=${self.session_id} name="${self.name}" }'
		}
	}
}

// ============================================================
// Parser - tmux control mode parser
// ============================================================

// Parser state.
enum ParserState as u8 {
	// Outside of any active notifications. This should drop any output
	// unless it is '%' on the first byte of a line. The buffer will be
	// cleared when it sees '%', this is so that the previous notification
	// data is valid until we receive/process new data.
	idle
	// We experienced unexpected input and are in a broken state
	// so we cannot continue processing. When this state is set,
	// the buffer has been deinited and must not be accessed.
	broken
	// Inside an active notification (started with '%').
	notification
	// Inside a begin/end block.
	block
}

// A tmux control mode parser. This takes in output from tmux control
// mode and parses it into structured notifications.
//
// It is up to the caller to establish the connection to the tmux
// control mode session in some way (e.g. via exec, a network socket,
// whatever). This is fully agnostic to how the data is received and sent.
pub struct ControlParser {
pub mut:
	// Current state of the client.
	state ParserState = .idle

	// The buffer used to store in-progress notifications, output, etc.
	buffer []u8

	// The maximum size in bytes of the buffer. This is used to limit
	// memory usage. If the buffer exceeds this size, the client will
	// enter a broken state (the control mode session will be forcibly
	// exited and future data dropped).
	max_bytes usize = 1024 * 1024
}

pub fn (mut self ControlParser) deinit() {
	// If we're in a broken state, we already deinited
	// the buffer, so we don't need to do anything.
	if self.state == .broken {
		return
	}
	self.buffer = []
}

// ControlParserPutValue preserves Ghostty's !?Notification contract. V cannot
// nest an Option in a Result, so notification represents the optional layer.
pub struct ControlParserPutValue {
pub:
	notification ?Notification
}

// Handle a byte of input.
//
// If we reach our byte limit this will return an error. It only
// does this on the first time we exceed the limit; subsequent calls
// will return none as we drop all input in a broken state.
pub fn (mut self ControlParser) put(byte u8) !ControlParserPutValue {
	// If we're in a broken state, just do nothing.
	//
	// We have to do this check here before we check the buffer, because if
	// we're in a broken state then we'd have already deinited the buffer.
	if self.state == .broken {
		return ControlParserPutValue{}
	}

	if usize(self.buffer.len) >= self.max_bytes {
		self.set_broken()
		return error('tmux control parser exceeded max_bytes')
	}

	match self.state {
		// Drop because we're in a broken state.
		.broken {
			return ControlParserPutValue{}
		}

		// Waiting for a notification so if the byte is not '%' then
		// we're in a broken state. Control mode output should always
		// be wrapped in '%begin/%end' otherwise we expect a notification.
		// Return an exit notification.
		.idle {
			if byte != `%` {
				self.set_broken()
				return ControlParserPutValue{
					notification: Notification(NotifExit{})
				}
			} else {
				self.buffer = []
				self.state = .notification
			}
		}

		// If we're in a notification and its not a newline then
		// we accumulate. If it is a newline then we have a
		// complete notification we need to parse.
		.notification {
			if byte == `\n` {
				// We have a complete notification, parse it.
				notification := self.parse_notification() or {
					// If parsing failed, then we do not mark the state
					// as broken because we may be able to continue parsing
					// other types of notifications.
					//
					// In the future we may want to emit a notification
					// here about unknown or unsupported notifications.
					return ControlParserPutValue{}
				}
				return ControlParserPutValue{
					notification: notification
				}
			}
		}

		// If we're in a block then we accumulate until we see a newline
		// and then we check to see if that line ended the block.
		.block {
			if byte == `\n` {
				written := self.buffer.bytestr()
				// Find the last newline to get the current line.
				last_nl := written.last_index_u8(`\n`)
				line := if last_nl >= 0 {
					written[last_nl + 1..]
				} else {
					written
				}

				if line.starts_with('%end') || line.starts_with('%error') {
					is_err := line.starts_with('%error')
					// Get the output before this line.
					output := if last_nl >= 0 {
						written[..last_nl].trim_right('\r\n')
					} else {
						''
					}

					// Important: do not clear buffer since the notification
					// contains it.
					self.state = .idle
					if is_err {
						return ControlParserPutValue{
							notification: Notification(NotifBlockErr{ data: output })
						}
					} else {
						return ControlParserPutValue{
							notification: Notification(NotifBlockEnd{ data: output })
						}
					}
				}

				// Didn't end the block, continue accumulating.
			}
		}
	}

	self.buffer << byte
	return ControlParserPutValue{}
}

fn (mut self ControlParser) parse_notification() ?Notification {
	assert self.state == .notification

	mut line := self.buffer.bytestr()
	if line.len > 0 && line[line.len - 1] == `\r` {
		line = line[..line.len - 1]
	}

	// Get the command (first word).
	space_idx := line.index_u8(` `)
	cmd := if space_idx >= 0 { line[..space_idx] } else { line }

	if cmd == '%begin' {
		// We don't use the rest of the tokens for now because tmux
		// claims to guarantee that begin/end are always in order and
		// never intermixed. In the future, we should probably validate
		// this.

		// Move to block state because we expect a corresponding end/error
		// and want to accumulate the data.
		self.state = .block
		self.buffer = []
		return none
	} else if cmd == '%output' {
		// Parse: %output %<pane_id> <data>
		mut re := regex.regex_opt(r'^%output %(\d+) (.+)$') or {
			return none
		}
		re.match_string(line)
		if re.groups.len >= 4 {
			pane_id := parse_usize(line[re.groups[0]..re.groups[1]]) or { panic(err) }
			data := line[re.groups[2]..re.groups[3]]

			// Important: do not clear buffer here since data points to it.
			self.state = .idle
			return Notification(NotifOutput{ pane_id: pane_id, data: data })
		}
	} else if cmd == '%session-changed' {
		// Parse: %session-changed $<id> <name>
		mut re := regex.regex_opt(r'^%session-changed [$](\d+) (.+)$') or {
			return none
		}
		re.match_string(line)
		if re.groups.len >= 4 {
			id := parse_usize(line[re.groups[0]..re.groups[1]]) or { panic(err) }
			name := line[re.groups[2]..re.groups[3]]

			// Important: do not clear buffer here since name points to it.
			self.state = .idle
			return Notification(NotifSessionChanged{ id: id, name: name })
		}
	} else if cmd == '%sessions-changed' {
		if line != '%sessions-changed' {
			// Mismatch, fall through.
		} else {
			self.buffer = []
			self.state = .idle
			return Notification(NotifSessionsChanged{})
		}
	} else if cmd == '%layout-change' {
		// Parse: %layout-change @<window_id> <layout> <visible_layout> <flags>
		mut re := regex.regex_opt(r'^%layout-change @(\d+) (\S+) (\S+) (.*)$') or {
			return none
		}
		re.match_string(line)
		if re.groups.len >= 8 {
			id := parse_usize(line[re.groups[0]..re.groups[1]]) or { panic(err) }
			layout := line[re.groups[2]..re.groups[3]]
			visible_layout := line[re.groups[4]..re.groups[5]]
			raw_flags := line[re.groups[6]..re.groups[7]]

			// Important: do not clear buffer here since layout strings point to it.
			self.state = .idle
			return Notification(NotifLayoutChange{
				window_id: id
				layout: layout
				visible_layout: visible_layout
				raw_flags: raw_flags
			})
		}
	} else if cmd == '%window-add' {
		// Parse: %window-add @<id>
		mut re := regex.regex_opt(r'^%window-add @(\d+)$') or {
			return none
		}
		re.match_string(line)
		if re.groups.len >= 2 {
			id := parse_usize(line[re.groups[0]..re.groups[1]]) or { panic(err) }

			self.buffer = []
			self.state = .idle
			return Notification(NotifWindowAdd{ id: id })
		}
	} else if cmd == '%window-renamed' {
		// Parse: %window-renamed @<id> <name>
		mut re := regex.regex_opt(r'^%window-renamed @(\d+) (.+)$') or {
			return none
		}
		re.match_string(line)
		if re.groups.len >= 4 {
			id := parse_usize(line[re.groups[0]..re.groups[1]]) or { panic(err) }
			name := line[re.groups[2]..re.groups[3]]

			// Important: do not clear buffer here since name points to it.
			self.state = .idle
			return Notification(NotifWindowRenamed{ id: id, name: name })
		}
	} else if cmd == '%window-pane-changed' {
		// Parse: %window-pane-changed @<window_id> %<pane_id>
		mut re := regex.regex_opt(r'^%window-pane-changed @(\d+) %(\d+)$') or {
			return none
		}
		re.match_string(line)
		if re.groups.len >= 4 {
			window_id := parse_usize(line[re.groups[0]..re.groups[1]]) or { panic(err) }
			pane_id := parse_usize(line[re.groups[2]..re.groups[3]]) or { panic(err) }

			self.buffer = []
			self.state = .idle
			return Notification(NotifWindowPaneChanged{
				window_id: window_id
				pane_id: pane_id
			})
		}
	} else if cmd == '%client-detached' {
		// Parse: %client-detached <client>
		mut re := regex.regex_opt(r'^%client-detached (.+)$') or {
			return none
		}
		re.match_string(line)
		if re.groups.len >= 2 {
			client := line[re.groups[0]..re.groups[1]]

			// Important: do not clear buffer here since client points to it.
			self.state = .idle
			return Notification(NotifClientDetached{ client: client })
		}
	} else if cmd == '%client-session-changed' {
		// Parse: %client-session-changed <client> $<session_id> <name>
		mut re := regex.regex_opt(r'^%client-session-changed (.+) [$](\d+) (.+)$') or {
			return none
		}
		re.match_string(line)
		if re.groups.len >= 6 {
			client := line[re.groups[0]..re.groups[1]]
			session_id := parse_usize(line[re.groups[2]..re.groups[3]]) or { panic(err) }
			name := line[re.groups[4]..re.groups[5]]

			// Important: do not clear buffer here since client/name point to it.
			self.state = .idle
			return Notification(NotifClientSessionChanged{
				client: client
				session_id: session_id
				name: name
			})
		}
	}

	// Unknown command. Clear the buffer and return to idle state.
	self.buffer = []
	self.state = .idle

	return none
}

// Mark the tmux state as broken.
fn (mut self ControlParser) set_broken() {
	self.state = .broken
	self.buffer = []
}
