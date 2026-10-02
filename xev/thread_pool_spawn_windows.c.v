module xev

#include <windows.h>
#flag windows -lntdll

fn C.GetProcessHeap() voidptr
fn C.HeapAlloc(heap voidptr, flags u32, size usize) voidptr
fn C.HeapFree(heap voidptr, flags u32, ptr voidptr) bool
fn C.CreateThread(attributes voidptr, stack_size usize, entry voidptr, arg voidptr, flags u32, id &u32) voidptr
fn C.RtlWaitOnAddress(address voidptr, expected voidptr, size usize, timeout voidptr) int
fn C.RtlWakeAddressSingle(address voidptr)
fn C.RtlWakeAddressAll(address voidptr)

// std.Thread.WindowsThreadImpl, Zig 0.15.2. The allocated instance has the
// source completion state so entry and detach safely race to free ownership.
struct ThreadPoolWindowsInstance {
mut:
	pool          &ThreadPool = unsafe { nil }
	completion    u32 // running = 0, completed = 1, detached = 2
	heap_ptr      voidptr
	heap_handle   voidptr
	thread_handle voidptr
}

fn thread_pool_spawn(config ThreadPoolSpawnConfig, pool &ThreadPool) !&ThreadPoolWindowsInstance {
	heap := C.GetProcessHeap()
	if heap == unsafe { nil } { return new_error(.out_of_memory) }
	// HeapAlloc is aligned to MEMORY_ALLOCATION_ALIGNMENT (16 on Win64).
	allocation := C.HeapAlloc(heap, 0, usize(sizeof(ThreadPoolWindowsInstance)) + 16)
	if allocation == unsafe { nil } { return new_error(.out_of_memory) }
	aligned := (usize(allocation) + 15) & ~usize(15)
	mut instance := unsafe { &ThreadPoolWindowsInstance(voidptr(aligned)) }
	unsafe { *instance = ThreadPoolWindowsInstance{ pool: pool, heap_ptr: allocation, heap_handle: heap } }
	stack_size := if config.stack_size > 64 * 1024 { config.stack_size } else { u32(64 * 1024) }
	instance.thread_handle = C.CreateThread(unsafe { nil }, usize(stack_size), voidptr(thread_pool_windows_entry), instance, 0, unsafe { nil })
	if instance.thread_handle == unsafe { nil } {
		C.HeapFree(heap, 0, allocation)
		return thread_pool_error_unexpected
	}
	return instance
}

fn thread_pool_detach(instance_ &ThreadPoolWindowsInstance) {
	mut instance := unsafe { instance_ }
	C.CloseHandle(instance.thread_handle)
	match C.atomic_exchange_u32(&instance.completion, 2) {
		0 {}
		1 { thread_pool_windows_free(instance) }
		else { panic('unreachable') }
	}
}

fn thread_pool_windows_entry(raw voidptr) u32 {
	mut instance := unsafe { &ThreadPoolWindowsInstance(raw) }
	mut pool := instance.pool
	ThreadPoolThread.run(mut pool)
	match C.atomic_exchange_u32(&instance.completion, 1) {
		0 {}
		2 { thread_pool_windows_free(instance) }
		else { panic('unreachable') }
	}
	return 0
}

fn thread_pool_windows_free(instance &ThreadPoolWindowsInstance) {
	ok := C.HeapFree(instance.heap_handle, 0, instance.heap_ptr)
	assert ok
}

// std.Thread.Futex.WindowsImpl, no-timeout wait/wake used by libxev.
fn thread_pool_windows_futex_wait(ptr &ThreadPoolAtomic[u32], expect u32) {
	expected := expect
	rc := C.RtlWaitOnAddress(voidptr(&ptr.raw), voidptr(&expected), 4, unsafe { nil })
	if rc != 0 { panic('unreachable RtlWaitOnAddress status=${rc}') }
}

fn thread_pool_windows_futex_wake(ptr &ThreadPoolAtomic[u32], max_waiters u32) {
	assert max_waiters != 0
	if max_waiters == 1 {
		C.RtlWakeAddressSingle(voidptr(&ptr.raw))
	} else {
		C.RtlWakeAddressAll(voidptr(&ptr.raw))
	}
}
