module xev

@[typedef]
struct C.pthread_t {}

@[typedef]
struct C.pthread_attr_t {}

fn C.pthread_detach(thread C.pthread_t) i32
fn C.pthread_attr_setguardsize(attr voidptr, guardsize uint) i32
fn C.getpagesize() int

// Minimal translation of `std.Thread.spawn(config, Thread.run, .{thread_pool})`
// (PosixThreadImpl.spawn). V's `spawn` cannot take a runtime stack size and
// panics when pthread_create fails, while the pool relies on both
// (`stack_size` config and `catch return self.unregister(null)`), so pthread is
// used directly. The pool pointer is passed as the single thread argument, so no
// argument allocation is needed.
fn thread_pool_spawn(config ThreadPoolSpawnConfig, thread_pool &ThreadPool) !C.pthread_t {
	$if wasm32_wasi {
		// libxev passes only stack_size to std.Thread.spawn. Zig's WASI
		// implementation immediately panics because that config omits the
		// required allocator (std/Thread.zig WasiThreadImpl.spawn:938).
		panic('an allocator is required to spawn a WASI thread')
	}
	mut attr := C.pthread_attr_t{}
	if C.pthread_attr_init(&attr) != 0 {
		return thread_pool_error_system_resources
	}
	defer {
		C.pthread_attr_destroy(&attr)
	}

	// Use the same set of parameters used by the libc-less impl.
	stack_size := if config.stack_size > 16 * 1024 { config.stack_size } else { 16 * 1024 }
	// (Not inside `assert`: V drops asserts, and their side effects, in -prod builds.)
	setstacksize_rc := C.pthread_attr_setstacksize(&attr, uint(stack_size))
	assert setstacksize_rc == 0
	// std.heap.pageSize()
	setguardsize_rc := C.pthread_attr_setguardsize(&attr, uint(C.getpagesize()))
	assert setguardsize_rc == 0

	mut handle := C.pthread_t{}
	rc := C.pthread_create(&handle, &attr, voidptr(thread_pool_thread_entry), voidptr(thread_pool))
	match rc {
		0 { return handle }
		C.EAGAIN { return thread_pool_error_system_resources }
		C.EPERM, C.EINVAL { panic('unreachable') }
		else { return thread_pool_error_unexpected }
	}
}

// std.Thread.detach()
fn thread_pool_detach(handle C.pthread_t) {
	C.pthread_detach(handle)
}

// PosixThreadImpl.spawn's Instance.entryFn: calls Thread.run(thread_pool).
fn thread_pool_thread_entry(raw_arg voidptr) voidptr {
	mut thread_pool := unsafe { &ThreadPool(raw_arg) }
	ThreadPoolThread.run(mut thread_pool)
	return unsafe { nil }
}
