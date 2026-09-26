module xev

// Common loop structures. The actual loop implementation is in backend-specific
// files such as kqueue_darwin.c.v.
//
// V translation of libxev's src/loop.zig (pinned 34fa508).

// Common options across backends. Not all options apply to all backends.
// Read the doc comment for individual fields to learn what backends they
// apply to.
pub struct Options {
pub:
	// The number of queued completions that can be in flight before
	// requiring interaction with the kernel.
	//
	// Backends: io_uring
	entries u32 = 256

	// A thread pool to use for blocking operations. If the backend doesn't
	// need to perform any blocking operations then no threads will ever
	// be spawned. If the backend does need to perform blocking operations
	// on a thread and no thread pool is provided, the operations will simply
	// fail. Unless you're trying to really optimize for space, it is
	// recommended you provide a thread pool.
	//
	// Backends: epoll, kqueue
	thread_pool &ThreadPool = unsafe { nil }
}

// The loop run mode -- all backends are required to support this in some way.
// Backends may provide backend-specific APIs that behave slightly differently
// or in a more configurable way.
pub enum RunMode as i32 {
	// Run the event loop once. If there are no blocking operations ready,
	// return immediately.
	no_wait    = 0
	// Run the event loop once, waiting for at least one blocking operation
	// to complete.
	once       = 1
	// Run the event loop until it is "done". "Doneness" is defined as
	// there being no more completions that are active.
	until_done = 2
}

// The result type for callbacks. This should be used by all loop
// implementations and higher level abstractions in order to control
// what to do after the loop completes.
pub enum CallbackAction as i32 {
	// The request is complete and is not repeated. For example, a read
	// callback only fires once and is no longer watched for reads. You
	// can always free memory associated with the completion prior to
	// returning this.
	disarm = 0
	// Requeue the same operation request with the same parameters
	// with the event loop. This makes it easy to repeat a read, timer,
	// etc. This rearms the request EXACTLY as-is. For example, the
	// low-level timer interface for io_uring uses an absolute timeout.
	// If you rearm the timer, it will fire immediately because the absolute
	// timeout will be in the past.
	//
	// The completion is reused so it is not safe to use the same completion
	// for anything else.
	rearm  = 1
}

// The state that a completion can be in.
pub enum CompletionState as i32 {
	// The completion is not being used and is ready to be configured
	// for new work.
	dead   = 0
	// The completion is part of an event loop. This may be already waited
	// on or in the process of being registered.
	active = 1
}

// The payloads of every backend's `ReadBuffer` and `WriteBuffer`
// union(enum). Each backend's buffer type is a sum type of these variants.

// Read into this slice.
//
// For zero-length slices, the event will notify of read readiness
// (similar to poll) rather than performing an explicit zero-length
// read which will always succeed regardless of if the fd is ready
// or not.
pub struct ReadBufferSlice {
pub mut:
	slice []u8
}

// Read into this array, just set this to undefined and it will
// be populated up to the size of the array. This is an option because
// the other union members force a specific size anyways so this lets us
// use the other size in the union to support small reads without worrying
// about buffer allocation.
//
// To know the size read you have to use the return value of the
// read operations (i.e. recv).
//
// Note that the union at the time of this writing could accomodate a
// much larger fixed size array here but we want to retain flexiblity
// for future fields.
pub struct ReadBufferArray {
pub mut:
	array [32]u8
}

// Write from this buffer.
pub struct WriteBufferSlice {
pub mut:
	slice []u8
}

// Write from this array. See ReadBuffer.array for why we support this.
pub struct WriteBufferArray {
pub mut:
	array [32]u8
	len   usize
}
