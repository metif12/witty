module xev

// libxev src/main.zig and api.zig, pinned 34fa508. Windows has a
// single candidate backend (iocp), so Dynamic equals the static API.
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
	return .iocp
}

// A function to test if this API is available on the
// current system.
pub fn available() bool {
	return iocp_available()
}

// The core loop APIs.
pub type Loop = IocpLoop
pub type Completion = IocpCompletion
pub type Result = IocpResult
pub type ReadBuffer = IocpReadBuffer
pub type WriteBuffer = IocpWriteBuffer

// Shared stream types
pub type PollEvent = IocpPollEvent
pub type WriteQueue = IntrusiveQueue[IocpWriteRequest]
pub type WriteRequest = IocpWriteRequest

// The high-level helper interfaces that make it easier to perform
// common tasks. These may not work with all possible Loop implementations.
pub type Async = IocpAsync
pub type Process = IocpProcess
pub type Stream = IocpStream
pub type Timer = IocpTimer

// The callback of the main Loop operations. Higher level interfaces may
// use a different callback mechanism.
pub type Callback = fn (userdata voidptr, loop &IocpLoop, completion &IocpCompletion, result IocpResult) CallbackAction

// A callback that does nothing and immediately disarms. This
// implements xev.Callback and is the default value for completions.
pub fn noop_callback(userdata voidptr, loop &IocpLoop, completion &IocpCompletion, result IocpResult) CallbackAction {
	return iocp_noop_callback(userdata, loop, completion, result)
}
