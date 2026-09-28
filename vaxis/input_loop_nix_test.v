module vaxis

import time

#include <unistd.h>
#include <signal.h>

$if macos {
	#include <util.h>
} $else {
	#include <pty.h>
	#flag -lutil
}

fn C.openpty(master &int, slave &int, name voidptr, termp voidptr, winp voidptr) int

fn C.raise(signal_number int) int

fn wake_input_loop_for_test(fd int) {
	time.sleep(30 * time.millisecond)
	mut bytes := [u8(`z`), u8(`\n`)]!
	assert C.write(fd, &bytes[0], 2) == 2
}

fn test_input_loop_reads_and_queues_terminal_events() {
	mut master := 0
	mut slave := 0
	mut size := C.winsize{
		ws_row: 24
		ws_col: 80
	}
	assert C.openpty(&master, &slave, unsafe { nil }, unsafe { nil }, &size) == 0
	defer {
		C.close(master)
		C.close(slave)
	}
	mut tty := Tty{
		fd:      slave
		pending: []u8{cap: 32}
	}
	mut vx := Vaxis.new(VaxisOptions{})
	defer {
		vx.screen.deinit()
		vx.screen_last.deinit()
	}
	C.witty_vaxis_install_winch()
	defer { C.witty_vaxis_reset_winch() }
	mut loop := InputLoop.new(mut tty, mut vx)
	loop.init()!
	loop.start()
	initial := loop.next_event()
	assert initial is Winsize
	if initial is Winsize {
		assert initial.rows == 24
		assert initial.cols == 80
	}
	assert !vx.state.in_band_resize
	assert C.raise(C.SIGWINCH) == 0
	resized := loop.next_event()
	assert resized is Winsize
	assert !vx.state.in_band_resize
	mut input := [u8(`x`), u8(`y`), u8(`\n`)]!
	assert C.write(master, &input[0], 3) == 3
	first := loop.next_event()
	second := loop.next_event()
	assert first is Key
	assert second is Key
	if first is Key {
		assert first.codepoint == `x`
	}
	if second is Key {
		assert second.codepoint == `y`
	}
	_ = loop.next_event() // the canonical PTY's newline
	resize_report := '\x1b[48;30;90t\n'.bytes()
	assert C.write(master, resize_report.data, usize(resize_report.len)) == resize_report.len
	in_band := loop.next_event()
	assert in_band is Winsize
	if in_band is Winsize {
		assert in_band.rows == 30
		assert in_band.cols == 90
	}
	assert vx.state.in_band_resize
	_ = loop.next_event() // the report's newline
	waker := spawn wake_input_loop_for_test(master)
	loop.stop(&vx)
	waker.wait()
	assert loop.try_event() == none
	loop.deinit(&vx)
}
