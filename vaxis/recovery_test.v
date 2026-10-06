module vaxis

fn test_recover_without_registered_terminal_preserves_absence() {
	previous := C.witty_vaxis_recovery_tty_get()
	defer { C.witty_vaxis_recovery_tty_set(previous) }
	C.witty_vaxis_recovery_tty_set(unsafe { nil })
	recover()
	recover()
	assert isnil(C.witty_vaxis_recovery_tty_get())
}

fn test_recovery_registration_owns_an_independent_terminal_value() {
	previous := C.witty_vaxis_recovery_tty_get()
	defer { C.witty_vaxis_recovery_tty_set(previous) }
	mut tty := Tty{
		fd:          17
		input_mode:  3
		output_mode: 9
		output_cp:   1234
	}
	register_recovery_tty(tty)
	saved := unsafe { &Tty(C.witty_vaxis_recovery_tty_get()) }
	tty.fd = 91
	tty.input_mode = 0
	tty.output_mode = 0
	tty.output_cp = 0
	assert saved.fd == 17 && saved.input_mode == 3
	assert saved.output_mode == 9 && saved.output_cp == 1234
	// Registration replaces the previous successful value, while retaining a copy.
	register_recovery_tty(tty)
	second := unsafe { &Tty(C.witty_vaxis_recovery_tty_get()) }
	tty.fd = -1
	assert second.fd == 91 && saved.fd == 17
	assert saved != second
}
