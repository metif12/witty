module main

import os
import vaxis
import term.termios

#include <unistd.h>
#include <termios.h>

fn C.read(fd int, bytes voidptr, size uint) int
fn same(a termios.Termios, b termios.Termios) bool {
	return a.c_iflag == b.c_iflag && a.c_oflag == b.c_oflag && a.c_cflag == b.c_cflag
		&& a.c_lflag == b.c_lflag && a.c_cc == b.c_cc && a.c_ispeed == b.c_ispeed
		&& a.c_ospeed == b.c_ospeed
}

fn main() {
	count := os.args[1].int()
	mutate := os.args[2] == '1'
	mut original := termios.Termios{}
	if termios.tcgetattr(0, mut original) != 0 { panic('fixture original') }
	mut tty := vaxis.Tty.new() or { panic('fixture init ${err}') }
	mut raw := termios.Termios{}
	if termios.tcgetattr(0, mut raw) != 0 { panic('fixture raw') }
	was_raw := raw.c_lflag & termios.flag(int(C.ICANON) | int(C.ECHO) | int(C.ISIG)) == 0
		&& raw.c_iflag & termios.flag(int(C.ICRNL) | int(C.IXON)) == 0
		&& raw.c_oflag & termios.flag(int(C.OPOST)) == 0
	mut writes := 0
	mut ws := tty.get_winsize() or { panic('fixture winsize') }
	for i in 0 .. count {
		if mutate && i > 0 {
			mut changed := termios.Termios{}
			if termios.tcgetattr(0, mut changed) != 0 { panic('fixture change') }
			changed.c_lflag ^= termios.flag(int(C.ECHO))
			if termios.tcsetattr(0, C.TCSANOW, mut changed) != 0 { panic('fixture tcsetattr') }
		}
		tty.deinit()
		tty.write('D') or { continue }
		writes++
		ws = tty.get_winsize() or { panic('UNEXPECTED post-deinit winsize ${err}') }
	}
	mut current := termios.Termios{}
	if termios.tcgetattr(0, mut current) != 0 { panic('fixture current') }
	println('${int(was_raw)}|${int(same(current, original))}|${writes}|${ws.rows}|${ws.cols}|${ws.x_pixel}|${ws.y_pixel}')
	C.fflush(C.stdout)
	mut held := [1]u8{}
	C.read(os.args[3].int(), &held[0], 1)
}
