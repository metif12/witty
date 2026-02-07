module terminal

// DCS command handler. This should be hooked into a terminal.Stream handler.
// The hook/put/unhook functions are meant to be called from the
// terminal.stream dcs_hook, dcs_put, and dcs_unhook functions, respectively.
//
// DCS (Device Control String) is an escape sequence used for several
// terminal control features including XTGETTCAP (terminfo capability
// queries), DECRQSS (request status string), and tmux control mode.

// ============================================================
// DCS parameters (matching the DCS struct from the stream parser)
// ============================================================

// DcsParams holds the parsed DCS sequence parameters (intermediates, params,
// and final byte) as passed from the stream parser.
pub struct DcsParams {
pub:
	intermediates string
	params        []u16
	final_byte    u8
}

// ============================================================
// DCS State
// ============================================================

// DcsStateInactive represents the state where we're not in a DCS
// state at the moment.
pub struct DcsStateInactive {}

// DcsStateIgnore represents the state where we're hooked, but it's an
// unknown DCS command or one that went invalid due to some bad input,
// so we're ignoring the rest.
pub struct DcsStateIgnore {}

// DcsStateXtgettcap holds the buffer for XTGETTCAP data being collected.
pub struct DcsStateXtgettcap {
pub mut:
	data []u8
}

// DcsStateDecrqss holds a small buffer for DECRQSS data (max 2 bytes).
pub struct DcsStateDecrqss {
pub mut:
	data [2]u8
	len  int
}

// DcsStateTmux holds the tmux control mode parser state.
// XTODO: When tmux control mode is implemented, this will hold the
// actual tmux.ControlParser.
pub struct DcsStateTmux {
pub mut:
	max_bytes int
	buffer    []u8
}

// DcsState is a sumtype representing the current state of DCS parsing.
pub type DcsState = DcsStateInactive
	| DcsStateIgnore
	| DcsStateXtgettcap
	| DcsStateDecrqss
	| DcsStateTmux

// deinit cleans up state-specific resources.
fn dcs_state_deinit(mut state DcsState) {
	match mut state {
		DcsStateInactive, DcsStateIgnore, DcsStateDecrqss {}
		DcsStateXtgettcap {
			state.data = []
		}
		DcsStateTmux {
			// XTODO: When tmux control mode is implemented, call parser.deinit()
			state.buffer = []
		}
	}
}

// ============================================================
// DCS Command
// ============================================================

// XTGETTCAP command data. Contains the raw hex-encoded terminfo
// capability names separated by semicolons.
pub struct DcsXtgettcap {
pub mut:
	data []u8
	i    int
}

// next returns the next terminfo key being requested, or none when
// there are no more keys. The returned value is NOT hex-decoded
// because we expect to use a comptime lookup table.
pub fn (mut self DcsXtgettcap) next() ?string {
	if self.i >= self.data.len {
		return none
	}
	rem := self.data[self.i..]
	// Find the next semicolon separator
	mut idx := rem.len
	for j in 0 .. rem.len {
		if rem[j] == u8(`;`) {
			idx = j
			break
		}
	}

	// Note that if we're at the end, idx + 1 is len + 1 so we're over
	// the end but that's okay because our check above is >= so we'll
	// never read.
	self.i += idx + 1

	return rem[0..idx].bytestr()
}

// Supported DECRQSS settings
pub enum DcsDecrqss {
	none_val
	sgr
	decscusr
	decstbm
	decslrm
}

// DcsCommandXtgettcap wraps the XTGETTCAP data.
pub struct DcsCommandXtgettcap {
pub mut:
	xtgettcap DcsXtgettcap
}

// DcsCommandDecrqss wraps the DECRQSS setting.
pub struct DcsCommandDecrqss {
pub:
	decrqss DcsDecrqss
}

// DcsCommandTmux represents a tmux control mode notification.
// XTODO: When tmux control mode is implemented, this will hold the
// actual tmux.ControlNotification.
pub enum DcsTmuxNotification {
	enter
	exit
	// XTODO: Add other tmux notifications as needed
}

pub struct DcsCommandTmux {
pub:
	notification DcsTmuxNotification
}

// DcsCommand is a sumtype representing possible DCS commands.
pub type DcsCommand = DcsCommandXtgettcap
	| DcsCommandDecrqss
	| DcsCommandTmux

// deinit cleans up command-specific resources.
pub fn (mut self DcsCommand) deinit() {
	match mut self {
		DcsCommandXtgettcap {
			self.xtgettcap.data = []
		}
		DcsCommandDecrqss {}
		DcsCommandTmux {}
	}
}

// ============================================================
// DCS Handler
// ============================================================

// DcsHandler is the DCS command handler. It processes DCS sequences
// through hook/put/unhook calls.
pub struct DcsHandler {
pub mut:
	state DcsState = DcsStateInactive{}

	// Maximum bytes any DCS command can take. This is to prevent
	// malicious input from causing us to allocate too much memory.
	// This is arbitrarily set to 1MB today, increase if needed.
	max_bytes int = 1024 * 1024
}

// deinit cleans up the handler.
pub fn (mut self DcsHandler) deinit() {
	self.discard()
}

// hook begins processing a DCS sequence. The DCS parameters are used to
// identify what kind of command this is. Returns a command if one should
// be immediately executed (e.g. tmux enter), or none if the command
// requires more data via put().
pub fn (mut self DcsHandler) hook(dcs DcsParams) ?DcsCommand {
	// Initialize our state to ignore in case of error
	self.state = DcsStateIgnore{}

	// Try to parse the hook.
	hook_result := self.try_hook(dcs) or {
		// Error initializing DCS hook, will ignore hook
		return none
	}
	if hook_result.state is DcsStateIgnore {
		// Unknown DCS hook
		return none
	}

	self.state = hook_result.state
	return hook_result.command
}

// DcsHook holds the result of parsing a DCS hook.
struct DcsHook {
mut:
	state   DcsState
	command ?DcsCommand
}

// try_hook attempts to parse the DCS hook and determine the command type.
fn (self DcsHandler) try_hook(dcs DcsParams) !DcsHook {
	if dcs.intermediates.len == 0 {
		match dcs.final_byte {
			// Tmux control mode
			`p` {
				// XTODO: tmux control mode not fully implemented
				// Tmux control mode must start with ESC P 1000 p
				if dcs.params.len != 1 || dcs.params[0] != 1000 {
					return DcsHook{
						state: DcsStateIgnore{}
					}
				}

				return DcsHook{
					state: DcsStateTmux{
						max_bytes: self.max_bytes
						buffer: []u8{cap: 128} // Arbitrary choice to limit initial reallocs
					}
					command: DcsCommand(DcsCommandTmux{
						notification: .enter
					})
				}
			}
			else {
				return DcsHook{
					state: DcsStateIgnore{}
				}
			}
		}
	} else if dcs.intermediates.len == 1 {
		match dcs.intermediates[0] {
			`+` {
				match dcs.final_byte {
					// XTGETTCAP
					// https://github.com/mitchellh/ghostty/issues/517
					`q` {
						return DcsHook{
							state: DcsStateXtgettcap{
								data: []u8{cap: 128} // Arbitrary choice
							}
						}
					}
					else {
						return DcsHook{
							state: DcsStateIgnore{}
						}
					}
				}
			}
			`$` {
				match dcs.final_byte {
					// DECRQSS
					`q` {
						return DcsHook{
							state: DcsStateDecrqss{}
						}
					}
					else {
						return DcsHook{
							state: DcsStateIgnore{}
						}
					}
				}
			}
			else {
				return DcsHook{
					state: DcsStateIgnore{}
				}
			}
		}
	} else {
		return DcsHook{
			state: DcsStateIgnore{}
		}
	}
}

// put processes a single byte of the DCS sequence data. May return a
// command if one needs to be executed immediately (e.g. tmux notifications).
pub fn (mut self DcsHandler) put(byte u8) ?DcsCommand {
	self.try_put(byte) or {
		// On error we just discard our state and ignore the rest
		self.discard()
		self.state = DcsStateIgnore{}
	}
	return none
}

// try_put attempts to process a byte, potentially returning an error
// if limits are exceeded. Returns nothing on success; the caller
// catches errors and discards state.
fn (mut self DcsHandler) try_put(byte u8) ! {
	match mut self.state {
		DcsStateInactive, DcsStateIgnore {
			// Nothing to do
		}
		DcsStateTmux {
			// XTODO: When tmux control mode is implemented:
			// return DcsCommand(DcsCommandTmux{
			//     notification: tmux.put(byte) orelse return none
			// })
			if self.state.buffer.len >= self.state.max_bytes {
				return error('DCS tmux buffer exceeded max_bytes')
			}
			self.state.buffer << byte
		}
		DcsStateXtgettcap {
			if self.state.data.len >= self.max_bytes {
				return error('DCS xtgettcap buffer exceeded max_bytes')
			}
			self.state.data << byte
		}
		DcsStateDecrqss {
			if self.state.len >= self.state.data.len {
				return error('DCS decrqss buffer overflow')
			}
			self.state.data[self.state.len] = byte
			self.state.len += 1
		}
	}
}

// unhook finishes the DCS sequence and returns a command if one was
// successfully parsed. Some commands transfer memory ownership via
// the returned command.
pub fn (mut self DcsHandler) unhook() ?DcsCommand {
	// Note: we do NOT call deinit here on purpose because some commands
	// transfer memory ownership. If state needs cleanup, the match
	// branch below should handle it.
	defer {
		self.state = DcsStateInactive{}
	}

	match mut self.state {
		DcsStateInactive, DcsStateIgnore {
			return none
		}
		DcsStateTmux {
			// XTODO: When tmux control mode is implemented, clean up state
			dcs_state_deinit(mut self.state)
			return DcsCommand(DcsCommandTmux{
				notification: .exit
			})
		}
		DcsStateXtgettcap {
			// Note: purposely do not deinit our state here because
			// we copy it into the resulting command.
			// Convert to uppercase
			mut items := self.state.data.clone()
			for i in 0 .. items.len {
				b := items[i]
				if b >= u8(`a`) && b <= u8(`z`) {
					items[i] = b - 32
				}
			}
			return DcsCommand(DcsCommandXtgettcap{
				xtgettcap: DcsXtgettcap{
					data: items
				}
			})
		}
		DcsStateDecrqss {
			decrqss_val := match self.state.len {
				0 {
					DcsDecrqss.none_val
				}
				1 {
					match self.state.data[0] {
						`m` { DcsDecrqss.sgr }
						`r` { DcsDecrqss.decstbm }
						`s` { DcsDecrqss.decslrm }
						else { DcsDecrqss.none_val }
					}
				}
				2 {
					match self.state.data[0] {
						` ` {
							match self.state.data[1] {
								`q` { DcsDecrqss.decscusr }
								else { DcsDecrqss.none_val }
							}
						}
						else {
							DcsDecrqss.none_val
						}
					}
				}
				else {
					DcsDecrqss.none_val
				}
			}
			return DcsCommand(DcsCommandDecrqss{
				decrqss: decrqss_val
			})
		}
	}
}

// discard cleans up current state and returns to inactive.
pub fn (mut self DcsHandler) discard() {
	dcs_state_deinit(mut self.state)
	self.state = DcsStateInactive{}
}
