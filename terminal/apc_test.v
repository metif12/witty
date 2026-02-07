module terminal

// Tests for APC command handler.
// Translated from Ghostty's apc.zig tests.

fn test_apc_unknown_command() {
	mut h := ApcHandler{}
	h.start()
	for c in 'Xabcdef1234'.bytes() {
		h.feed(c)
	}
	assert h.end() == none
}

fn test_apc_garbage_kitty_command() {
	// XTODO: When kitty graphics parsing is implemented, this test should
	// verify that a garbage kitty command (starting with 'G' but with
	// invalid content) returns none.
	//
	// Original test: feeds "Gabcdef1234", expects end() == null
	mut h := ApcHandler{}
	h.start()
	for c in 'Gabcdef1234'.bytes() {
		h.feed(c)
	}
	// Currently always returns none since kitty is stubbed
	assert h.end() == none
}

fn test_apc_kitty_command_overflow_u32() {
	// XTODO: When kitty graphics parsing is implemented, this test should
	// verify that an overflow in u32 parameter parsing is handled.
	//
	// Original test: feeds "Ga=p,i=10000000000", expects end() == null
	mut h := ApcHandler{}
	h.start()
	for c in 'Ga=p,i=10000000000'.bytes() {
		h.feed(c)
	}
	assert h.end() == none
}

fn test_apc_kitty_command_overflow_i32() {
	// XTODO: When kitty graphics parsing is implemented, this test should
	// verify that an overflow in i32 parameter parsing is handled.
	//
	// Original test: feeds "Ga=p,i=1,z=-9999999999", expects end() == null
	mut h := ApcHandler{}
	h.start()
	for c in 'Ga=p,i=1,z=-9999999999'.bytes() {
		h.feed(c)
	}
	assert h.end() == none
}

fn test_apc_valid_kitty_command() {
	// XTODO: When kitty graphics parsing is implemented, this test should
	// verify that a valid kitty command is parsed correctly.
	//
	// Original test: feeds "Gf=24,s=10,v=20,hello=world",
	// expects end() to return a kitty command.
	mut h := ApcHandler{}
	h.start()
	input := 'Gf=24,s=10,v=20,hello=world'
	for c in input.bytes() {
		h.feed(c)
	}
	// Currently returns none since kitty is stubbed
	// When implemented, this should return a valid ApcCommandKitty
	assert h.end() == none
}
