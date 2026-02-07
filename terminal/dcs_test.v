module terminal

import tmux

// Tests for DCS command handler.
// Translated from Ghostty's dcs.zig tests.

fn test_dcs_unknown_command() {
	mut h := DcsHandler{}
	defer { h.deinit() }
	assert h.hook(DcsParams{ final_byte: `A` }) == none
	assert h.state is DcsStateIgnore
	assert h.unhook() == none
	assert h.state is DcsStateInactive
}

fn test_dcs_xtgettcap_command() {
	mut h := DcsHandler{}
	defer { h.deinit() }
	assert h.hook(DcsParams{ intermediates: '+', final_byte: `q` }) == none
	for byte in '536D756C78'.bytes() {
		_ = h.put(byte)
	}
	mut cmd := h.unhook() or { assert false; return }
	defer { cmd.deinit() }
	match mut cmd {
		DcsCommandXtgettcap {
			val := cmd.xtgettcap.next() or {
				assert false
				return
			}
			assert val == '536D756C78'
			assert cmd.xtgettcap.next() == none
		}
		else {
			assert false
		}
	}
}

fn test_dcs_xtgettcap_mixed_case() {
	mut h := DcsHandler{}
	defer { h.deinit() }
	assert h.hook(DcsParams{ intermediates: '+', final_byte: `q` }) == none
	for byte in '536d756C78'.bytes() {
		_ = h.put(byte)
	}
	mut cmd := h.unhook() or { assert false; return }
	defer { cmd.deinit() }
	match mut cmd {
		DcsCommandXtgettcap {
			// Should be uppercased
			val := cmd.xtgettcap.next() or {
				assert false
				return
			}
			assert val == '536D756C78'
			assert cmd.xtgettcap.next() == none
		}
		else {
			assert false
		}
	}
}

fn test_dcs_xtgettcap_multiple_keys() {
	mut h := DcsHandler{}
	defer { h.deinit() }
	assert h.hook(DcsParams{ intermediates: '+', final_byte: `q` }) == none
	for byte in '536D756C78;536D756C78'.bytes() {
		_ = h.put(byte)
	}
	mut cmd := h.unhook() or { assert false; return }
	defer { cmd.deinit() }
	match mut cmd {
		DcsCommandXtgettcap {
			val1 := cmd.xtgettcap.next() or {
				assert false
				return
			}
			assert val1 == '536D756C78'
			val2 := cmd.xtgettcap.next() or {
				assert false
				return
			}
			assert val2 == '536D756C78'
			assert cmd.xtgettcap.next() == none
		}
		else {
			assert false
		}
	}
}

fn test_dcs_xtgettcap_invalid_data() {
	mut h := DcsHandler{}
	defer { h.deinit() }
	assert h.hook(DcsParams{ intermediates: '+', final_byte: `q` }) == none
	for byte in 'who;536D756C78'.bytes() {
		_ = h.put(byte)
	}
	mut cmd := h.unhook() or { assert false; return }
	defer { cmd.deinit() }
	match mut cmd {
		DcsCommandXtgettcap {
			// "who" should be uppercased to "WHO"
			val1 := cmd.xtgettcap.next() or {
				assert false
				return
			}
			assert val1 == 'WHO'
			val2 := cmd.xtgettcap.next() or {
				assert false
				return
			}
			assert val2 == '536D756C78'
			assert cmd.xtgettcap.next() == none
		}
		else {
			assert false
		}
	}
}

fn test_dcs_decrqss_command() {
	mut h := DcsHandler{}
	defer { h.deinit() }
	assert h.hook(DcsParams{ intermediates: '$', final_byte: `q` }) == none
	_ = h.put(`m`)
	mut cmd := h.unhook() or { assert false; return }
	defer { cmd.deinit() }
	match cmd {
		DcsCommandDecrqss {
			assert cmd.decrqss == DcsDecrqss.sgr
		}
		else {
			assert false
		}
	}
}

fn test_dcs_decrqss_invalid_command() {
	mut h := DcsHandler{}
	defer { h.deinit() }
	assert h.hook(DcsParams{ intermediates: '$', final_byte: `q` }) == none
	_ = h.put(`z`)
	mut cmd := h.unhook() or { assert false; return }
	defer { cmd.deinit() }
	if cmd is DcsCommandDecrqss {
		assert cmd.decrqss == DcsDecrqss.none_val
	} else {
		assert false
	}

	h.discard()

	assert h.hook(DcsParams{ intermediates: '$', final_byte: `q` }) == none
	_ = h.put(`"`)
	_ = h.put(` `)
	_ = h.put(`q`)
	// Buffer overflow (3 bytes > 2 byte buffer), should be discarded
	assert h.unhook() == none
}

fn test_dcs_tmux_enter_and_implicit_exit() {
	mut h := DcsHandler{}
	defer { h.deinit() }

	// Hook with tmux params (1000, 'p')
	cmd1 := h.hook(DcsParams{
		params:     [u16(1000)]
		final_byte: `p`
	}) or {
		assert false
		return
	}
	match cmd1 {
		DcsCommandTmux {
			assert cmd1.notification is tmux.NotifEnter
		}
		else {
			assert false
		}
	}

	// Unhook should return tmux exit
	cmd2 := h.unhook() or { assert false; return }
	match cmd2 {
		DcsCommandTmux {
			assert cmd2.notification is tmux.NotifExit
		}
		else {
			assert false
		}
	}
}
