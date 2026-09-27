module terminal

// ApcHandler parses Application Program Command sequences. The start, feed,
// and end methods are called by a terminal stream handler for APC actions.
pub struct ApcHandler {
mut:
	state ApcState = ApcStateInactive{}
}

pub struct ApcStateInactive {}

pub struct ApcStateIgnore {}

pub struct ApcStateIdentify {}

pub struct ApcStateKitty {
mut:
	parser CommandParser
}

// ApcState retains parser storage only while a Kitty graphics command is
// active, matching terminal/apc.zig's tagged State union.
pub type ApcState = ApcStateInactive | ApcStateIgnore | ApcStateIdentify | ApcStateKitty

fn apc_state_deinit(mut state ApcState) {
	match mut state {
		ApcStateInactive, ApcStateIgnore, ApcStateIdentify {}
		ApcStateKitty { state.parser.deinit() }
	}
}

// ApcCommand is the source's currently one-arm Command union. A struct is the
// lossless V representation of a union with exactly one possible active arm.
pub struct ApcCommand {
pub mut:
	kitty Command
}

pub fn (mut self ApcCommand) deinit() {
	self.kitty.deinit()
}

pub fn (mut self ApcHandler) deinit() {
	apc_state_deinit(mut self.state)
	self.state = ApcStateInactive{}
}

pub fn (mut self ApcHandler) start() {
	self.deinit()
	self.state = ApcStateIdentify{}
}

pub fn (mut self ApcHandler) feed(byte_val u8) {
	if self.state is ApcStateInactive {
		panic('ApcHandler.feed called while inactive')
	}
	if self.state is ApcStateIgnore {
		return
	}
	mut identified := ?ApcState(none)
	if self.state is ApcStateIdentify {
		identified = if byte_val == `G` && kitty_graphics {
			ApcState(ApcStateKitty{ parser: CommandParser.init() })
		} else {
			ApcState(ApcStateIgnore{})
		}
	}
	if next_state := identified {
		self.state = next_state
		return
	}

	mut invalid := false
	match mut self.state {
		ApcStateKitty {
			self.state.parser.feed(byte_val) or { invalid = true }
		}
		else {}
	}
	if invalid {
		apc_state_deinit(mut self.state)
		self.state = ApcStateIgnore{}
	}
}

pub fn (mut self ApcHandler) end() ?ApcCommand {
	defer {
		apc_state_deinit(mut self.state)
		self.state = ApcStateInactive{}
	}

	if self.state is ApcStateInactive {
		panic('ApcHandler.end called while inactive')
	}
	match mut self.state {
		ApcStateKitty {
			command := self.state.parser.complete() or { return none }
			return ApcCommand{ kitty: command }
		}
		else {
			return none
		}
	}
}
