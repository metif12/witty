module vaxis

fn test_session_event_capabilities_and_query_probes() {
	mut vx := Vaxis.new(VaxisOptions{})
	vx.query_terminal_send()
	shift := Modifiers.init(true, false, false, false, false, false, false, false)
	alt := Modifiers.init(false, true, false, false, false, false, false, false)
	assert vx.handle_input(InputEvent(Key{
		codepoint: f3
		mods:      shift
	})) == none
	assert vx.caps.explicit_width
	assert vx.caps.unicode == .unicode
	assert vx.screen.width_method == .unicode
	assert vx.handle_input(InputEvent(Key{
		codepoint: f3
		mods:      alt
	})) == none
	assert vx.caps.scaled_text
	$if !windows {
		assert vx.handle_input(InputEvent(CapabilityEvent{
			capability: .kitty_graphics
		})) == none
		assert vx.caps.kitty_graphics
	}
	assert vx.handle_input(InputEvent(CapabilityEvent{
		capability: .da1
	})) == none
	assert vx.queries_done
	forwarded := vx.handle_input(InputEvent(Key{
		codepoint: f3
		mods:      shift
	})) or { panic('missing forwarded key') }
	assert forwarded is Key
	vx.screen.deinit()
	vx.screen_last.deinit()
}

fn test_session_event_resize_and_pixel_mouse() {
	mut vx := Vaxis.new(VaxisOptions{})
	vx.resize(Winsize{
		cols:    10
		rows:    5
		x_pixel: 100
		y_pixel: 50
	})
	vx.state.pixel_mouse = true
	forwarded := vx.handle_input(InputEvent(Mouse{
		col: 29
		row: 26
	})) or { panic('missing mouse') }
	assert forwarded is Mouse
	if forwarded is Mouse {
		assert forwarded.col == 2
		assert forwarded.row == 2
		assert forwarded.xoffset == 9
		assert forwarded.yoffset == 6
	}
	assert vx.handle_input(InputEvent(Winsize{
		cols: 4
		rows: 3
	})) != none
	$if windows {
		assert !vx.state.in_band_resize
	} $else {
		assert vx.state.in_band_resize
	}
	vx.screen.deinit()
	vx.screen_last.deinit()
}
