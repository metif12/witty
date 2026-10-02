module xev

// libxev src/main.zig and api.zig, pinned 34fa508. WASI has a
// single candidate backend (wasi_poll), so Dynamic equals the static API.
// Backend operations use the original result tags and ErrorKind projection.

// This is used to detect a static vs dynamic API at comptime.
pub const dynamic = false

// The backend that this is. This is supplied at comptime so
// it is up to the caller to say the right thing. This lets custom
// implementations also "quack" like an implementation.
//
// An accessor because the Linux dynamic API's `backend` is a variable, and V
// module globals cannot be read from other modules.
pub fn backend() Backend {
	return .wasi_poll
}

// A function to test if this API is available on the
// current system.
pub fn available() bool {
	return wasi_poll_available()
}

// The core loop APIs.
pub type Loop = WasiLoop
pub type Completion = WasiCompletion
pub type Result = WasiResult
pub type ReadBuffer = WasiReadBuffer
pub type WriteBuffer = WasiWriteBuffer

// Shared stream types
pub type PollEvent = WasiPollEvent
pub type WriteQueue = IntrusiveQueue[WasiWriteRequest]
pub type WriteRequest = WasiWriteRequest

// The high-level helper interfaces that make it easier to perform
// common tasks. These may not work with all possible Loop implementations.
pub type Async = WasiAsync

// watcher/process.zig returns an empty type for WASI: it has no process API.
pub struct Process {}

pub type Stream = WasiStream
pub type Timer = WasiTimer

// The callback of the main Loop operations. Higher level interfaces may
// use a different callback mechanism.
pub type Callback = fn (userdata voidptr, loop &WasiLoop, completion &WasiCompletion, result WasiResult) CallbackAction

// A callback that does nothing and immediately disarms. This
// implements xev.Callback and is the default value for completions.
pub fn noop_callback(userdata voidptr, loop &WasiLoop, completion &WasiCompletion, result WasiResult) CallbackAction {
	return wasi_noop_callback(userdata, loop, completion, result)
}
