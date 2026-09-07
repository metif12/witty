module tmux

// Tests for tmux control mode parser.
//
// Source: terminal/tmux/control.zig (tests)

// Feed a string into the parser byte by byte, returning the first
// notification encountered (or none if no notification was produced).
fn feed_string(mut c ControlParser, s string) ?Notification {
	for byte in s.bytes() {
		if n := c.put(byte) {
			return n
		}
	}
	return none
}

// Feed a string and assert no notification is produced.
fn feed_string_none(mut c ControlParser, s string) {
	for byte in s.bytes() {
		if _ := c.put(byte) {
			assert false, 'unexpected notification during feed'
		}
	}
}

fn test_tmux_begin_end_empty() {
	mut c := ControlParser{}
	defer { c.deinit() }

	// Feed the begin line -- should produce no notification.
	if _ := feed_string(mut c, '%begin 1578922740 269 1\n') {
		assert false, 'unexpected notification for begin'
	}

	// Feed the end line byte by byte (without the newline).
	feed_string_none(mut c, '%end 1578922740 269 1')

	// The final newline should trigger the notification.
	if n := c.put(`\n`) {
		if n is NotifBlockEnd {
			assert n.data == ''
		} else {
			assert false, 'expected NotifBlockEnd'
		}
	} else {
		assert false, 'expected notification'
	}
}

fn test_tmux_begin_error_empty() {
	mut c := ControlParser{}
	defer { c.deinit() }

	if _ := feed_string(mut c, '%begin 1578922740 269 1\n') {
		assert false, 'unexpected notification for begin'
	}
	feed_string_none(mut c, '%error 1578922740 269 1')

	if n := c.put(`\n`) {
		if n is NotifBlockErr {
			assert n.data == ''
		} else {
			assert false, 'expected NotifBlockErr'
		}
	} else {
		assert false, 'expected notification'
	}
}

fn test_tmux_begin_end_data() {
	mut c := ControlParser{}
	defer { c.deinit() }

	if _ := feed_string(mut c, '%begin 1578922740 269 1\n') {
		assert false, 'unexpected notification for begin'
	}
	if _ := feed_string(mut c, 'hello\nworld\n') {
		assert false, 'unexpected notification for data'
	}
	feed_string_none(mut c, '%end 1578922740 269 1')

	if n := c.put(`\n`) {
		if n is NotifBlockEnd {
			assert n.data == 'hello\nworld'
		} else {
			assert false, 'expected NotifBlockEnd'
		}
	} else {
		assert false, 'expected notification'
	}
}

fn test_tmux_output() {
	mut c := ControlParser{}
	defer { c.deinit() }

	feed_string_none(mut c, '%output %42 foo bar baz')

	if n := c.put(`\n`) {
		if n is NotifOutput {
			assert n.pane_id == 42
			assert n.data == 'foo bar baz'
		} else {
			assert false, 'expected NotifOutput'
		}
	} else {
		assert false, 'expected notification'
	}
}

fn test_tmux_output_pane_id_above_i32() {
	mut c := ControlParser{}
	defer { c.deinit() }

	feed_string_none(mut c, '%output %4294967295 data')
	if n := c.put(`\n`) {
		if n is NotifOutput {
			assert n.pane_id == usize(4294967295)
			assert n.data == 'data'
			return
		}
	}
	assert false, 'expected NotifOutput'
}

fn test_tmux_session_changed() {
	mut c := ControlParser{}
	defer { c.deinit() }

	feed_string_none(mut c, '%session-changed \$42 foo')

	if n := c.put(`\n`) {
		if n is NotifSessionChanged {
			assert n.id == 42
			assert n.name == 'foo'
		} else {
			assert false, 'expected NotifSessionChanged'
		}
	} else {
		assert false, 'expected notification'
	}
}

fn test_tmux_sessions_changed() {
	mut c := ControlParser{}
	defer { c.deinit() }

	feed_string_none(mut c, '%sessions-changed')

	if n := c.put(`\n`) {
		assert n is NotifSessionsChanged
	} else {
		assert false, 'expected notification'
	}
}

fn test_tmux_sessions_changed_carriage_return() {
	mut c := ControlParser{}
	defer { c.deinit() }

	feed_string_none(mut c, '%sessions-changed\r')

	if n := c.put(`\n`) {
		assert n is NotifSessionsChanged
	} else {
		assert false, 'expected notification'
	}
}

fn test_tmux_layout_change() {
	mut c := ControlParser{}
	defer { c.deinit() }

	feed_string_none(mut c, '%layout-change @2 1234x791,0,0{617x791,0,0,0,617x791,618,0,1} 1234x791,0,0{617x791,0,0,0,617x791,618,0,1} *-')

	if n := c.put(`\n`) {
		if n is NotifLayoutChange {
			assert n.window_id == 2
			assert n.layout == '1234x791,0,0{617x791,0,0,0,617x791,618,0,1}'
			assert n.visible_layout == '1234x791,0,0{617x791,0,0,0,617x791,618,0,1}'
			assert n.raw_flags == '*-'
		} else {
			assert false, 'expected NotifLayoutChange'
		}
	} else {
		assert false, 'expected notification'
	}
}

fn test_tmux_window_add() {
	mut c := ControlParser{}
	defer { c.deinit() }

	feed_string_none(mut c, '%window-add @14')

	if n := c.put(`\n`) {
		if n is NotifWindowAdd {
			assert n.id == 14
		} else {
			assert false, 'expected NotifWindowAdd'
		}
	} else {
		assert false, 'expected notification'
	}
}

fn test_tmux_window_renamed() {
	mut c := ControlParser{}
	defer { c.deinit() }

	feed_string_none(mut c, '%window-renamed @42 bar')

	if n := c.put(`\n`) {
		if n is NotifWindowRenamed {
			assert n.id == 42
			assert n.name == 'bar'
		} else {
			assert false, 'expected NotifWindowRenamed'
		}
	} else {
		assert false, 'expected notification'
	}
}

fn test_tmux_window_pane_changed() {
	mut c := ControlParser{}
	defer { c.deinit() }

	feed_string_none(mut c, '%window-pane-changed @42 %2')

	if n := c.put(`\n`) {
		if n is NotifWindowPaneChanged {
			assert n.window_id == 42
			assert n.pane_id == 2
		} else {
			assert false, 'expected NotifWindowPaneChanged'
		}
	} else {
		assert false, 'expected notification'
	}
}

fn test_tmux_client_detached() {
	mut c := ControlParser{}
	defer { c.deinit() }

	feed_string_none(mut c, '%client-detached /dev/pts/1')

	if n := c.put(`\n`) {
		if n is NotifClientDetached {
			assert n.client == '/dev/pts/1'
		} else {
			assert false, 'expected NotifClientDetached'
		}
	} else {
		assert false, 'expected notification'
	}
}

fn test_tmux_client_session_changed() {
	mut c := ControlParser{}
	defer { c.deinit() }

	feed_string_none(mut c, '%client-session-changed /dev/pts/1 \$2 mysession')

	if n := c.put(`\n`) {
		if n is NotifClientSessionChanged {
			assert n.client == '/dev/pts/1'
			assert n.session_id == 2
			assert n.name == 'mysession'
		} else {
			assert false, 'expected NotifClientSessionChanged'
		}
	} else {
		assert false, 'expected notification'
	}
}
