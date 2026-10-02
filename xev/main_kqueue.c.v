module xev

$if macos || ios || freebsd {
	// V translation of libxev's src/main.zig default API (pinned 34fa508) for
	// macOS, iOS and FreeBSD, where it is Xev(.kqueue, backend/kqueue.zig).
	//
	// Ghostty imports `xev.Dynamic`, which is dynamic.zig's Xev(Backend.candidates()).
	// These targets have the single candidate `.kqueue`, and "if only one backend is given,
	// the returned type is equivalent to the static API", so this file is both the
	// default and the Dynamic API here.
	//
	// Not forwarded: `Sys` (V cannot alias a module), the per-operation error sets
	// (V errors carry an ErrorKind instead; see errors.v), and the File, TCP, and
	// UDP watchers, which Ghostty does not use and are not translated.

	// This is used to detect a static vs dynamic API at comptime.
	pub const dynamic = false

	// The backend that this is. This is supplied at comptime so
	// it is up to the caller to say the right thing. This lets custom
	// implementations also "quack" like an implementation.
	//
	// An accessor because the Linux dynamic API's `backend` is a variable, and V
	// module globals cannot be read from other modules.
	pub fn backend() Backend {
		return .kqueue
	}

	// A function to test if this API is available on the
	// current system.
	pub fn available() bool {
		return kqueue_available()
	}

	// The core loop APIs.
	pub type Loop = KqueueLoop
	pub type Completion = KqueueCompletion
	pub type Result = KqueueResult
	pub type ReadBuffer = KqueueReadBuffer
	pub type WriteBuffer = KqueueWriteBuffer

	// Shared stream types
	pub type PollEvent = KqueuePollEvent
	pub type WriteQueue = IntrusiveQueue[KqueueWriteRequest]
	pub type WriteRequest = KqueueWriteRequest

	// The high-level helper interfaces that make it easier to perform
	// common tasks. These may not work with all possible Loop implementations.
	pub type Async = KqueueAsync
	pub type Process = KqueueProcess
	pub type Stream = KqueueStream
	pub type Timer = KqueueTimer

	// The callback of the main Loop operations. Higher level interfaces may
	// use a different callback mechanism.
	pub type Callback = fn (userdata voidptr, loop &KqueueLoop, completion &KqueueCompletion, result KqueueResult) CallbackAction

	// A callback that does nothing and immediately disarms. This
	// implements xev.Callback and is the default value for completions.
	pub fn noop_callback(userdata voidptr, loop &KqueueLoop, completion &KqueueCompletion, result KqueueResult) CallbackAction {
		return kqueue_noop_callback(userdata, loop, completion, result)
	}
}
