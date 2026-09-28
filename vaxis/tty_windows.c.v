module vaxis

pub fn (mut tty Tty) deinit() {
	_ = tty
}

pub fn (tty &Tty) get_winsize() !Winsize {
	_ = tty
	return terminal_size()
}

pub fn (tty &Tty) write(bytes string) ! {
	_ = tty
	print(bytes)
	flush_stdout()
}
