module terminal

fn test_apc_unknown_command() {
	mut handler := ApcHandler{}
	handler.start()
	for byte_val in 'Xabcdef1234'.bytes() {
		handler.feed(byte_val)
	}
	assert handler.end() == none
}

fn test_apc_garbage_kitty_command() {
	if !kitty_graphics {
		return
	}
	mut handler := ApcHandler{}
	handler.start()
	for byte_val in 'Gabcdef1234'.bytes() {
		handler.feed(byte_val)
	}
	assert handler.end() == none
}

fn test_apc_kitty_command_with_overflow_u32() {
	if !kitty_graphics {
		return
	}
	mut handler := ApcHandler{}
	handler.start()
	for byte_val in 'Ga=p,i=10000000000'.bytes() {
		handler.feed(byte_val)
	}
	assert handler.end() == none
}

fn test_apc_kitty_command_with_overflow_i32() {
	if !kitty_graphics {
		return
	}
	mut handler := ApcHandler{}
	handler.start()
	for byte_val in 'Ga=p,i=1,z=-9999999999'.bytes() {
		handler.feed(byte_val)
	}
	assert handler.end() == none
}

fn test_apc_valid_kitty_command() {
	if !kitty_graphics {
		return
	}
	mut handler := ApcHandler{}
	handler.start()
	for byte_val in 'Gf=24,s=10,v=20,hello=world'.bytes() {
		handler.feed(byte_val)
	}
	mut command := handler.end() or { panic('expected Kitty APC command') }
	defer { command.deinit() }
	transmission := command.kitty.transmission() or { panic('expected transmission command') }
	assert transmission.format_ == .rgb
	assert transmission.width == 10
	assert transmission.height == 20
}
