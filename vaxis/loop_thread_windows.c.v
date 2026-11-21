module vaxis

#include <windows.h>
#flag -I @VMODROOT/vaxis
#include "loop_thread_shims.h"

fn C.GetProcessHeap() voidptr
fn C.HeapAlloc(heap voidptr, flags u32, size uint) voidptr
fn C.HeapFree(heap voidptr, flags u32, memory voidptr) bool
fn C.witty_vaxis_create_thread(entry voidptr, context voidptr) voidptr
fn C.WaitForSingleObjectEx(handle voidptr, milliseconds u32, alertable bool) u32

struct LoopThreadArgs {
mut:
	context   voidptr
	heap      voidptr
	completed bool
}

struct LoopThread {
	handle voidptr
	args   &LoopThreadArgs
}

fn loop_thread_start[T](context voidptr) !LoopThread {
	heap := C.GetProcessHeap()
	if isnil(heap) { return error('OutOfMemory') }
	mut args := unsafe {
		&LoopThreadArgs(C.HeapAlloc(heap, 0, uint(sizeof(LoopThreadArgs) + sizeof(voidptr))))
	}
	if isnil(args) { return error('OutOfMemory') }
	args.context = context
	args.heap = heap
	args.completed = false
	handle := C.witty_vaxis_create_thread(voidptr(loop_thread_entry[T]), args)
	if isnil(handle) {
		result := C.HeapFree(heap, 0, args)
		assert result
		return error('Unexpected')
	}
	return LoopThread{
		handle: handle
		args:   args
	}
}

fn loop_thread_entry[T](ptr voidptr) u32 {
	mut args := unsafe { &LoopThreadArgs(ptr) }
	loop_tty_run[T](args.context) or { eprintln('error: ${err}') }
	args.completed = true
	return 0
}

fn (worker LoopThread) join() {
	result := C.WaitForSingleObjectEx(worker.handle, u32(0xffffffff), false)
	assert result == 0
	close_result := C.CloseHandle(worker.handle)
	assert close_result != 0
	assert worker.args.completed
	free_result := C.HeapFree(worker.args.heap, 0, worker.args)
	assert free_result
}
