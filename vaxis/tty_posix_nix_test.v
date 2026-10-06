module vaxis

import term.termios
import os

#include <termios.h>
#include <fcntl.h>
#include <unistd.h>

fn C.isatty(fd int) int

fn test_posix_tty_raw_mode_and_restore() {
	$if !windows {
		if C.isatty(0) == 0 {
			assert os.getenv('WITTY_REQUIRE_TTY') != '1'
			return
		}
		mut tty := Tty.new() or { panic(err) }
		mut raw := termios.Termios{}
		assert termios.tcgetattr(tty.fd, mut raw) == 0
		assert raw.c_lflag & termios.flag(int(C.ICANON) | int(C.ECHO) | int(C.ISIG)) == 0
		assert raw.c_iflag & termios.flag(int(C.ICRNL) | int(C.IXON)) == 0
		assert raw.c_oflag & termios.flag(int(C.OPOST)) == 0
		assert raw.c_cc[int(C.VMIN)] == 1
		assert raw.c_cc[int(C.VTIME)] == 0
		assert (tty.get_winsize() or { panic(err) }).cols > 0
		original := tty.original_state
		original_fd := tty.fd
		tty.deinit()
		$if macos {
			assert tty.fd == original_fd
			assert (tty.get_winsize() or { panic(err) }).cols > 0
			// A second restoration must still use the live source descriptor.
			mut changed := original
			changed.c_lflag &= termios.invert(termios.flag(int(C.ECHO)))
			assert termios.tcsetattr(tty.fd, C.TCSANOW, mut changed) == 0
			tty.deinit()
		}
		probe_fd := C.open(c'/dev/tty', C.O_RDWR, 0)
		assert probe_fd >= 0
		defer { C.close(probe_fd) }
		mut restored := termios.Termios{}
		assert termios.tcgetattr(probe_fd, mut restored) == 0
		assert restored.c_lflag == original.c_lflag
		assert restored.c_iflag == original.c_iflag
		assert restored.c_oflag == original.c_oflag
	}
}
