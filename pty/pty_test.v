module pty

// Tests for Pty: open, get size, set size, close.

fn test_winsize_defaults() {
	ws := Winsize{}
	assert ws.ws_row == 100
	assert ws.ws_col == 80
	assert ws.ws_xpixel == 800
	assert ws.ws_ypixel == 600
}

fn test_mode_defaults() {
	m := Mode{}
	assert m.canonical == true
	assert m.echo == true
}

fn test_pty_defaults() {
	p := Pty{}
	assert p.master == -1
	assert p.slave == -1
}

fn test_pty_open_and_close() {
	ws := Winsize{
		ws_row: 50
		ws_col: 80
		ws_xpixel: 1
		ws_ypixel: 1
	}

	mut p := Pty.open(ws) or {
		assert false, 'failed to open pty: ${err}'
		return
	}
	defer {
		p.deinit()
	}

	// Verify the file descriptors are valid (non-negative).
	assert p.master >= 0
	assert p.slave >= 0
}

fn test_pty_get_size() {
	ws := Winsize{
		ws_row: 50
		ws_col: 80
		ws_xpixel: 1
		ws_ypixel: 1
	}

	mut p := Pty.open(ws) or {
		assert false, 'failed to open pty: ${err}'
		return
	}
	defer {
		p.deinit()
	}

	// Initial size should match what we gave it.
	got := p.get_size() or {
		assert false, 'failed to get size: ${err}'
		return
	}
	assert got.ws_row == 50
	assert got.ws_col == 80
}

fn test_pty_set_size() {
	ws := Winsize{
		ws_row: 50
		ws_col: 80
		ws_xpixel: 1
		ws_ypixel: 1
	}

	mut p := Pty.open(ws) or {
		assert false, 'failed to open pty: ${err}'
		return
	}
	defer {
		p.deinit()
	}

	// Set a new size.
	new_ws := Winsize{
		ws_row: 100
		ws_col: 120
		ws_xpixel: 2
		ws_ypixel: 2
	}
	p.set_size(new_ws) or {
		assert false, 'failed to set size: ${err}'
		return
	}

	// Read back the new size.
	got := p.get_size() or {
		assert false, 'failed to get size after set: ${err}'
		return
	}
	assert got.ws_row == 100
	assert got.ws_col == 120
}

fn test_pty_get_mode() {
	ws := Winsize{
		ws_row: 25
		ws_col: 80
		ws_xpixel: 1
		ws_ypixel: 1
	}

	mut p := Pty.open(ws) or {
		assert false, 'failed to open pty: ${err}'
		return
	}
	defer {
		p.deinit()
	}

	// Default mode should have canonical and echo enabled.
	mode := p.get_mode() or {
		assert false, 'failed to get mode: ${err}'
		return
	}
	// The defaults for a newly opened pty typically have canonical
	// and echo enabled, matching the Mode struct defaults.
	assert mode.canonical == true
	assert mode.echo == true
}

fn test_pty_close_slave() {
	ws := Winsize{
		ws_row: 25
		ws_col: 80
		ws_xpixel: 1
		ws_ypixel: 1
	}

	mut p := Pty.open(ws) or {
		assert false, 'failed to open pty: ${err}'
		return
	}
	defer {
		p.deinit()
	}

	assert p.slave >= 0
	p.close_slave()
	assert p.slave == -1
}
