module vaxis

import os

fn test_working_directory_uri_preserves_raw_bytes_and_escapes_components() {
	previous := os.getenv_opt('HOSTNAME')
	defer {
		if hostname := previous {
			os.setenv('HOSTNAME', hostname, true)
		} else {
			os.unsetenv('HOSTNAME')
		}
	}
	os.setenv('HOSTNAME', 'host name/@', true)
	mut vx := Vaxis.new(VaxisOptions{})
	defer { vx.deinit() }
	host := $if windows { 'localhost' } $else { 'host%20name%2F%40' }
	assert vx.set_terminal_working_directory('/tmp/a b#c%25?\xe9\xff')! == '\x1b]7;file://${host}/tmp/a%20b%23c%2525%3F%E9%FF\x1b\\'
}

fn test_render_resize_mouse_names_and_retained_shape_updates() {
	mut vx := Vaxis.new(VaxisOptions{})
	defer { vx.deinit() }
	vx.enter_alt_screen()
	for shape in [MouseShape.ew_resize, .ns_resize] {
		vx.set_mouse_shape(shape)
		name := if shape == .ew_resize { 'ew-resize' } else { 'ns-resize' }
		assert vx.render() == '\x1b[?2026h\x1b[?25l\x1b[H\x1b[m\x1b]22;${name}\x1b\\\x1b[?2026l'
		assert vx.screen_last.mouse_shape == shape
		assert vx.render() == '\x1b[?2026h\x1b[?25l\x1b[H\x1b[m\x1b[?2026l'
	}
}
