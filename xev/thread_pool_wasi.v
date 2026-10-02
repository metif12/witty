module xev

$if wasm32_wasi {
	$if wasm_threads ? {
		#flag -matomics
		#flag -mbulk-memory
	}
	#include "thread_pool_wasi.h"
}

fn C.witty_xev_thread_current_get() voidptr
fn C.witty_xev_thread_current_set(value voidptr)
fn C.__builtin_wasm_memory_atomic_wait32(address voidptr, expected int, timeout i64) int
fn C.__builtin_wasm_memory_atomic_notify(address voidptr, count u32) u32

// Zig 0.15.2 std.Thread.Futex SingleThreadedImpl / WasmImpl. Infinite waits
// have no Timeout return, and the source requires the wasm atomics feature.
fn thread_pool_wasi_futex_wait(ptr &ThreadPoolAtomic[u32], expect u32) {
	$if wasm_threads ? {
		rc := C.__builtin_wasm_memory_atomic_wait32(voidptr(&ptr.raw), int(expect), -1)
		match rc {
			0, 1 {}
			else { panic('unreachable memory.atomic.wait32 result') }
		}
	} $else {
		panic('unreachable single-threaded futex wait')
	}
}

fn thread_pool_wasi_futex_wake(ptr &ThreadPoolAtomic[u32], max_waiters u32) {
	$if wasm_threads ? {
		assert max_waiters != 0
		_ = C.__builtin_wasm_memory_atomic_notify(voidptr(&ptr.raw), max_waiters)
	} $else {
		_ = ptr
		_ = max_waiters
	}
}
