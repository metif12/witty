module vaxis

fn test_session_query_and_feature_state() {
	mut vx := Vaxis.new(VaxisOptions{})
	assert vx.queries_done
	assert vx.query_terminal_send() == '\x1b[?1016$p\x1b[?2027$p\x1b[?2031$p\x1b[?2048h' +
		'\x1b[H\x1b]66;w=1; \x1b\\\x1b[6n' +
		'\x1b[H\x1b]66;s=2; \x1b\\\x1b[> q\x1b[6n' +
		'\x1b[>0q\x1b[?u\x1b_Gi=1,a=q\x1b\\\x1b[c'
	assert !vx.queries_done
	vx.queue_refresh()
	assert vx.refresh
	vx.caps.kitty_keyboard = true
	vx.caps.unicode = .unicode
	// The source's environment overrides are applied by enable_detected_features.
	// Test only the default state and query bytes here, independent of the host.
}

fn test_session_resize_and_reset_state() {
	mut vx := Vaxis.new(VaxisOptions{})
	vx.caps.unicode = .unicode
	vx.state.cursor.row = 2
	assert vx.resize(Winsize{
		cols:    4
		rows:    3
		x_pixel: 40
		y_pixel: 60
	}) == '\x1bM\x1bM\r\x1b[m\x1b[J'
	assert vx.screen.buf.len == 12
	assert vx.screen_last.buf.len == 12
	assert vx.screen.width_method == .unicode
	assert vx.state.cursor.row == 0
	assert vx.window().width == 4
	assert vx.enter_alt_screen() == '\x1b[?1049h'
	assert vx.resize(Winsize{
		cols: 2
		rows: 2
	}) == '\x1b[H\x1b[m\x1b[J'
	assert vx.set_bracketed_paste(true) == '\x1b[?2004h'
	assert vx.set_mouse_mode(true) == '\x1b[?1002;1003;1004;1006h'
	vx.state.kitty_keyboard = true
	assert vx.reset_state() == '\x1b[?25h\x1b[m\x1b[<u\x1b[?1002;1003;1004;1006;1016l' +
		'\x1b[?2004l\x1b[H\x1b[J\x1b[?1049l'
	assert !vx.state.kitty_keyboard
	assert !vx.state.bracketed_paste
	assert !vx.state.alt_screen
	// The pinned setMouseMode(false) writes a reset without clearing state.mouse.
	assert vx.state.mouse
	vx.screen.deinit()
	vx.screen_last.deinit()
}

fn test_session_pixel_mouse_translation() {
	mut vx := Vaxis.new(VaxisOptions{})
	vx.resize(Winsize{
		cols:    10
		rows:    5
		x_pixel: 102
		y_pixel: 51
	})
	vx.caps.sgr_pixels = true
	assert vx.set_mouse_mode(true) == '\x1b[?1002;1003;1004;1016h'
	mouse := Mouse{
		col: 23
		row: 17
	}
	translated := vx.translate_mouse(mouse)
	assert translated.col == 2
	assert translated.row == 1
	assert translated.xoffset == 3
	assert translated.yoffset == 7
	vx.screen.deinit()
	vx.screen_last.deinit()
}
