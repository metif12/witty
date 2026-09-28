module vaxis

import time

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

pub fn (mut tty Tty) next_input() !InputEvent {
	for {
		if event := tty.poll() {
			return event
		}
		time.sleep(8 * time.millisecond)
	}
	panic('unreachable')
}
