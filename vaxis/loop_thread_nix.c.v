module vaxis

#include <pthread.h>
#include <unistd.h>
#flag -I @VMODROOT/vaxis
#include "loop_thread_shims.h"

@[typedef]
struct C.pthread_t {}

@[typedef]
struct C.pthread_attr_t {}

fn C.pthread_attr_setguardsize(attr voidptr, size usize) int
fn C.getpagesize() int
fn C.witty_vaxis_pthread_join(handle C.pthread_t) int

struct LoopThread {
	handle C.pthread_t
}

struct LoopThreadArgs {
mut:
	context voidptr
}

// std.Thread's libc-backed spawn parameters and fallible creation boundary.
fn loop_thread_start[T](context voidptr) !LoopThread {
	mut args := unsafe { &LoopThreadArgs(C.malloc(sizeof(LoopThreadArgs))) }
	if isnil(args) { return error('OutOfMemory') }
	args.context = context
	mut attr := C.pthread_attr_t{}
	if C.pthread_attr_init(&attr) != 0 {
		unsafe { C.free(args) }
		return error('SystemResources')
	}
	defer {
		result := C.pthread_attr_destroy(&attr)
		assert result == 0
	}
	stack_result := C.pthread_attr_setstacksize(&attr, usize(16 * 1024 * 1024))
	assert stack_result == 0
	guard_result := C.pthread_attr_setguardsize(&attr, usize(C.getpagesize()))
	assert guard_result == 0
	mut handle := C.pthread_t{}
	result := C.pthread_create(&handle, &attr, voidptr(loop_thread_entry[T]), args)
	if result == 0 { return LoopThread{
			handle: handle
		} }
	unsafe { C.free(args) }
	if result == C.EAGAIN { return error('SystemResources') }
	if result == C.EPERM || result == C.EINVAL { panic('unreachable') }
	return error('Unexpected')
}

fn loop_thread_entry[T](ptr voidptr) voidptr {
	args := unsafe { &LoopThreadArgs(ptr) }
	defer { unsafe { C.free(args) } }
	loop_tty_run[T](args.context) or { eprintln('error: ${err}') }
	return unsafe { nil }
}

fn (worker LoopThread) join() {
	result := C.witty_vaxis_pthread_join(worker.handle)
	assert result == 0
}
