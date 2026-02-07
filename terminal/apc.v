module terminal

// APC command handler. This should be hooked into a terminal.Stream handler.
// The start/feed/end functions are meant to be called from the terminal.Stream
// apc_start, apc_put, and apc_end functions, respectively.
//
// APC (Application Program Command) is an escape sequence that allows
// applications to send custom commands to the terminal. The most notable
// user of APC is the Kitty graphics protocol.

// ============================================================
// APC State
// ============================================================

// ApcStateInactive represents the state where we're not in the middle
// of an APC command yet.
pub struct ApcStateInactive {}

// ApcStateIgnore represents the state where we got an unrecognized APC
// sequence or the APC sequence we recognized became invalid. We're just
// dropping bytes.
pub struct ApcStateIgnore {}

// ApcStateIdentify represents the state where we're waiting to identify
// the APC sequence. This is done by inspecting the first byte of the sequence.
pub struct ApcStateIdentify {}

// ApcStateKitty represents the state where we're parsing a Kitty graphics
// protocol command.
// XTODO: When kitty graphics are implemented, this will hold the
// kitty_gfx.CommandParser state.
pub struct ApcStateKitty {
pub mut:
	// XTODO: parser kitty_gfx.CommandParser
	data []u8
}

// ApcState is a sumtype representing the current state of APC parsing.
pub type ApcState = ApcStateInactive
	| ApcStateIgnore
	| ApcStateIdentify
	| ApcStateKitty

// deinit cleans up state-specific resources.
fn apc_state_deinit(mut state ApcState) {
	match mut state {
		ApcStateInactive, ApcStateIgnore, ApcStateIdentify {}
		ApcStateKitty {
			// XTODO: When kitty graphics are implemented, call parser.deinit()
			state.data = []
		}
	}
}

// ============================================================
// APC Command
// ============================================================

// ApcCommandKitty represents a parsed Kitty graphics protocol command.
// XTODO: When kitty graphics are implemented, this will hold the
// actual kitty_gfx.Command.
pub struct ApcCommandKitty {
pub mut:
	// XTODO: command kitty_gfx.Command
	data []u8
}

// ApcCommand is a sumtype representing possible APC commands.
pub type ApcCommand = ApcCommandKitty

// deinit cleans up command-specific resources.
pub fn (mut self ApcCommand) deinit() {
	// ApcCommand is currently only ApcCommandKitty.
	// XTODO: When kitty graphics are implemented, call command.deinit()
	mut cmd := &ApcCommandKitty(self)
	cmd.data = []
}

// ============================================================
// APC Handler
// ============================================================

// ApcHandler is the APC command handler. It processes APC sequences
// byte by byte through start/feed/end calls.
pub struct ApcHandler {
pub mut:
	state ApcState = ApcStateInactive{}
}

// deinit cleans up the handler.
pub fn (mut self ApcHandler) deinit() {
	apc_state_deinit(mut self.state)
}

// start begins a new APC sequence. Any previous state is discarded.
pub fn (mut self ApcHandler) start() {
	apc_state_deinit(mut self.state)
	self.state = ApcStateIdentify{}
}

// feed processes a single byte of the APC sequence.
pub fn (mut self ApcHandler) feed(byte u8) {
	match mut self.state {
		ApcStateInactive {
			// Should not be called when inactive
			return
		}
		// We're ignoring this APC command, likely because we don't
		// recognize it so there is no need to store the data in memory.
		ApcStateIgnore {
			return
		}
		// We identify the APC command by the first byte.
		ApcStateIdentify {
			match byte {
				// Kitty graphics protocol
				`G` {
					// XTODO: When kitty graphics are implemented:
					// self.state = ApcStateKitty{ parser: kitty_gfx.CommandParser.init(alloc) }
					// For now, we stub it and just collect data.
					self.state = ApcStateKitty{}
				}
				// Unknown
				else {
					self.state = ApcStateIgnore{}
				}
			}
		}
		ApcStateKitty {
			// XTODO: When kitty graphics are implemented, feed the byte
			// to the parser. On error, transition to ignore state.
			self.state.data << byte
		}
	}
}

// end finishes the APC sequence and returns a command if one was
// successfully parsed, or none if the sequence was invalid or unknown.
pub fn (mut self ApcHandler) end() ?ApcCommand {
	defer {
		apc_state_deinit(mut self.state)
		self.state = ApcStateInactive{}
	}

	match mut self.state {
		ApcStateInactive {
			// Should not be called when inactive
			return none
		}
		ApcStateIgnore, ApcStateIdentify {
			return none
		}
		ApcStateKitty {
			// XTODO: When kitty graphics are implemented:
			// Use the same allocator that was used to create the parser.
			// const command = p.complete(alloc) catch |err| {
			//     log.warn("kitty graphics protocol error: {}", .{err})
			//     return none
			// }
			// return ApcCommand(ApcCommandKitty{ command: command })
			//
			// For now, return none since we can't parse kitty commands yet.
			return none
		}
	}
}
