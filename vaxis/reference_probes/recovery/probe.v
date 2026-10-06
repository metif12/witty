module vaxis

import os
import term.termios

#include <sys/resource.h>
#include <fcntl.h>
#include <unistd.h>

struct C.rlimit {
mut:
	rlim_cur u64
	rlim_max u64
}

fn C.getrlimit(resource int, value &C.rlimit) int
fn C.setrlimit(resource int, value &C.rlimit) int
fn C.dup2(old int, new int) int

fn recovery_probe_raw(state termios.Termios) bool {
	return state.c_lflag & termios.flag(int(C.ICANON) | int(C.ECHO) | int(C.ISIG)) == 0
		&& state.c_iflag & termios.flag(int(C.ICRNL) | int(C.IXON)) == 0
		&& state.c_oflag & termios.flag(int(C.OPOST)) == 0
}

fn recovery_probe_init_fails() bool {
	mut saved := C.rlimit{}
	assert C.getrlimit(C.RLIMIT_NOFILE, &saved) == 0
	mut limits := saved
	limits.rlim_cur = 0
	assert C.setrlimit(C.RLIMIT_NOFILE, &limits) == 0
	defer { assert C.setrlimit(C.RLIMIT_NOFILE, &saved) == 0 }
	_ := Tty.new() or { return true }
	return false
}

fn test_recovery_reference_consumer() {
	text := os.getenv('WITTY_RECOVERY_CASE')
	if text == '' { return }
	p := text.split('|')
	mode := p[0]
	count := p[1].int()
	prefix := p[3].int()
	mut original := termios.Termios{}
	assert termios.tcgetattr(0, mut original) == 0
	mut expected := original
	mut fd := -1
	mut was_raw := false
	mut failed := false
	absent := mode in ['empty', 'panic_empty', 'none_fail']
	if !absent {
		mut tty := Tty.new() or { panic(err) }
		fd = tty.fd
		mut current := termios.Termios{}
		assert termios.tcgetattr(0, mut current) == 0
		was_raw = recovery_probe_raw(current)
		if prefix != 0 { tty.write('P'.repeat(prefix)) or { panic(err) } }
		if mode in ['two', 'panic_two'] {
			mut second := Tty.new() or { panic(err) }
			fd = second.fd
		}
		saved := unsafe { &Tty(C.witty_vaxis_recovery_tty_get()) }
		expected = saved.original_state
		if mode in ['mutate', 'panic_mutate'] {
			tty.original_state = current
			tty.fd = -1
			tty.stdin_handle = unsafe { nil }
			tty.stdout_handle = unsafe { nil }
		}
		if mode == 'deinit' { tty.deinit() }
		if mode == 'fail_init' { failed = recovery_probe_init_fails() }
		if mode in ['readonly', 'panic_readonly'] {
			readonly := C.open(c'/dev/tty', C.O_RDONLY, 0)
			assert readonly >= 0
			assert C.dup2(readonly, fd) == fd
			C.close(readonly)
		}
	} else if mode == 'none_fail' {
		failed = recovery_probe_init_fails()
	}
	if mode.starts_with('panic_') {
		println('READY')
		C.fflush(C.stdout)
		if mode == 'panic_call' { Panic.call('recovery-proof', unsafe { nil }, none) }
		if mode == 'panic_trace' { panic_handler('recovery-proof', voidptr(1), usize(0)) }
		panic_handler('recovery-proof', unsafe { nil }, none)
	}
	for _ in 0 .. count {
		recover()
	}
	mut current := termios.Termios{}
	assert termios.tcgetattr(0, mut current) == 0
	pointer := C.witty_vaxis_recovery_tty_get()
	present := !isnil(pointer)
	mut matches_fd := fd == -1
	mut matches_state := true
	if present {
		saved := unsafe { &Tty(pointer) }
		matches_fd = saved.fd == fd
		matches_state = saved.original_state == expected
	}
	println('${int(was_raw)},${int(current == expected)},${int(current == original)},${int(present)},${int(matches_fd)},${int(matches_state)},0,${int(failed)}')
	C.fflush(C.stdout)
	mut release := [1]u8{}
	assert C.read(os.getenv('WITTY_RECOVERY_RELEASE_FD').int(), &release[0], 1) == 1
}
