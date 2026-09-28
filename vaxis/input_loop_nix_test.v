module vaxis

import time

#include <unistd.h>

fn C.pipe(fds voidptr) int

fn wake_input_loop_for_test(fd int) {
	time.sleep(30 * time.millisecond)
	mut byte := u8(`z`)
	assert C.write(fd, &byte, 1) == 1
}

fn test_input_loop_reads_and_queues_terminal_events() {
	mut fds := [2]int{}
	assert C.pipe(&fds[0]) == 0
	defer {
		C.close(fds[0])
		C.close(fds[1])
	}
	mut tty := Tty{
		fd:      fds[0]
		pending: []u8{cap: 32}
	}
	mut vx := Vaxis.new(VaxisOptions{})
	defer {
		vx.screen.deinit()
		vx.screen_last.deinit()
	}
	mut loop := InputLoop.new(mut tty)
	loop.start()
	mut input := [u8(`x`), u8(`y`)]!
	assert C.write(fds[1], &input[0], 2) == 2
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
	waker := spawn wake_input_loop_for_test(fds[1])
	loop.stop(&vx)
	waker.wait()
	assert loop.try_event() == none
	loop.deinit(&vx)
}
