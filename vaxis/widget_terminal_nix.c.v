module vaxis

import sync

#flag -I @VMODROOT/vaxis
#include "widget_terminal_shims.h"

fn C.witty_terminal_globals_lock_init()
fn C.witty_terminal_globals_unlock_init()
fn C.witty_terminal_globals_get() voidptr
fn C.witty_terminal_globals_set(ptr voidptr)
fn C.witty_terminal_errno() int
fn C.witty_terminal_close(fd int) int
fn C.witty_terminal_kill(pid int) int
fn C.witty_terminal_eot(fd int) int
fn C.witty_terminal_waitpid() int
fn C.witty_terminal_sigchild(entry voidptr) int
fn C.witty_terminal_thread_start(entry voidptr, context voidptr, result &int) voidptr
fn C.witty_terminal_thread_join(handle voidptr) int

// The C root keeps the GC-owned source global registry alive without requiring
// V's optional __global language feature from module consumers.
@[heap]
pub struct TerminalGlobalState {
pub mut:
	mutex              &sync.Mutex = sync.new_mutex()
	vts                ?map[int]&Terminal
	sigchild_installed bool
	count              uint
}

pub fn terminal_global_state() &TerminalGlobalState {
	ptr := C.witty_terminal_globals_get()
	if !isnil(ptr) { return unsafe { &TerminalGlobalState(ptr) } }
	C.witty_terminal_globals_lock_init()
	defer { C.witty_terminal_globals_unlock_init() }
	again := C.witty_terminal_globals_get()
	if !isnil(again) { return unsafe { &TerminalGlobalState(again) } }
	result := &TerminalGlobalState{}
	C.witty_terminal_globals_set(result)
	return result
}

pub fn (pty TerminalPty) deinit() {
	terminal_close(pty.pty.fd)
	terminal_close(pty.tty.fd)
}

fn terminal_close(fd int) {
	result := C.witty_terminal_close(fd)
	if result < 0 && C.witty_terminal_errno() == C.EBADF { panic('unreachable') }
}

pub fn (mut command TerminalCommand) kill() {
	if pid := command.pid {
		C.witty_terminal_kill(pid)
		command.pid = none
	}
}

pub fn (mut terminal Terminal) deinit() {
	terminal.should_quit = true
	mut globals := terminal_global_state()
	globals.mutex.lock()
	if mut vts := globals.vts {
		// Source removal mutates shared map entries through a copied map header,
		// while its count remains local unless the entire registry is cleared.
		mut local_count := globals.count
		if pid := terminal.cmd.pid {
			if pid in vts {
				vts.delete(pid)
				if local_count == 0 { panic('integer overflow') }
				local_count--
			}
		}
		if local_count == 0 {
			globals.vts = none
			globals.count = 0
		} else {
			globals.vts = vts.move()
		}
	}
	globals.mutex.unlock()
	terminal.cmd.kill()
	if handle := terminal.thread {
		if C.witty_terminal_eot(terminal.pty.tty.fd) < 0 {
			code := C.witty_terminal_errno()
			if code == C.EFAULT || code == C.EDESTADDRREQ { panic('unreachable') }
		}
		if C.witty_terminal_thread_join(handle) != 0 { panic('Assertion failed') }
		terminal.thread = none
	}
	terminal.pty.deinit()
	terminal.front_screen.deinit()
	terminal.back_screen_pri.deinit()
	terminal.back_screen_alt.deinit()
	terminal.tab_stops = []u16{}
	terminal.title = []u8{}
	terminal.working_directory = []u8{}
}

fn terminal_thread_entry(context voidptr) voidptr {
	mut terminal := unsafe { &Terminal(context) }
	terminal.run() or { eprintln('error: ${err.msg()}') }
	return unsafe { nil }
}

fn terminal_start_thread(mut terminal Terminal) !voidptr {
	mut result := 0
	handle := C.witty_terminal_thread_start(voidptr(terminal_thread_entry), terminal, &result)
	if result == 0 { return handle }
	if result == -1 { return error('OutOfMemory') }
	if result == -2 || result == C.ENOMEM { return error('SystemResources') }
	if result == C.EAGAIN {
		$if linux {
			return error('ThreadQuotaExceeded')
		} $else {
			return error('SystemResources')
		}
	}
	if result == C.EPERM || result == C.EINVAL { panic('unreachable') }
	return error('Unexpected')
}

fn terminal_sigchild(_ int) {
	pid := C.witty_terminal_waitpid()
	if pid < 0 { panic('unreachable') }
	mut globals := terminal_global_state()
	globals.mutex.lock()
	defer { globals.mutex.unlock() }
	if vts := globals.vts {
		if pid in vts {
			mut terminal := vts[pid] or { return }
			terminal.event_queue.push(TerminalExited{})
		}
	}
}
