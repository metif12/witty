module xev

// The default API of this module on Linux.
//
// Ghostty imports `xev.Dynamic`, which is src/main.zig's
// `DynamicXev(Backend.candidates())` (pinned 34fa508). On Linux the candidates
// are io_uring and epoll, so it is src/dynamic.zig's `Xev(&.{ .io_uring,
// .epoll })`, which chooses between the two backends at runtime. This file
// holds the public declarations of that struct; its Loop and the dynamic
// Completion, buffer, and queue types are in dynamic_linux.c.v and the watchers
// in dynamic_*_linux.c.v. See main_darwin.c.v for the Darwin counterpart.
//
// Zig's comptime `inline else` over the backend tag becomes a `match` over
// the runtime backend with one arm per candidate.
//
// Not forwarded: the per-operation error sets (AcceptError, CancelError,
// CloseError, ConnectError, PollError, ShutdownError, WriteError, ReadError,
// which are the union of the candidates' error sets; V errors carry an
// ErrorKind instead, see errors.v), and the File, TCP, and UDP watchers, which
// Ghostty does not use and are not translated. ThreadPool, Options, RunMode,
// CallbackAction, and CompletionState are already module-level declarations.

// This is a flag that can be used to detect that you're using
// a dynamic API and not the static API via `hasDecl`.
pub const dynamic = true

pub const candidates = [Backend.io_uring, .epoll]

// The shared structures
pub type Completion = DynamicCompletion
pub type PollEvent = DynamicPollEvent
pub type ReadBuffer = DynamicReadBuffer
pub type WriteBuffer = DynamicWriteBuffer
pub type WriteQueue = DynamicWriteQueue
pub type WriteRequest = DynamicWriteRequest

// Core types
pub type Async = DynamicAsync
pub type Process = DynamicProcess
pub type Stream = DynamicStream
pub type Timer = DynamicTimer

pub type Loop = DynamicLoop

// Backend becomes the subset of the full xev.Backend that
// is available to this dynamic API.
//
// This is EnumSubset(Backend, candidates): the same backing type and integer
// values as Backend for the candidate backends.
pub enum DynamicBackend as u8 {
	io_uring = 0
	epoll    = 1
}

// The state behind the source's `pub var backend`. V module globals are not
// visible to other modules, so the variable is held behind a constant pointer
// and read with backend().
struct DynamicBackendState {
mut:
	backend DynamicBackend
}

// The backend that is in use.
const dynamic_backend_state = &DynamicBackendState{
	backend: subset(candidates[candidates.len - 1])
}

// The backend that is in use.
pub fn backend() DynamicBackend {
	return dynamic_backend_state.backend
}

// Assign the source's `backend` variable.
fn set_backend(be DynamicBackend) {
	mut state := unsafe { &DynamicBackendState(dynamic_backend_state) }
	state.backend = be
}

// `be.Api().available()`: whether the static API of the candidate backend
// `be` is available on the current system. Only the Linux candidates are
// translated for Linux.
pub fn (be Backend) api_available() bool {
	return match be {
		.io_uring { io_uring_available() }
		.epoll { epoll_available() }
		else { false }
	}
}

// Detect the preferred backend based on the system and set it
// for use. "Preferred" is the first available (API exists) candidate
// backend in the list.
pub fn detect() ! {
	for be in candidates {
		if be.api_available() {
			set_backend(subset(be))
			return
		}
	}

	return new_error(.no_available_backends)
}

// Manually set the backend to use, but if the backend is not
// available, this will not change the backend in use.
pub fn prefer(be Backend) bool {
	for candidate in candidates {
		if candidate == be {
			if !candidate.api_available() {
				return false
			}
			set_backend(subset(candidate))
			return true
		}
	}

	return false
}

// Helpers to convert between the subset/superset of backends.
pub fn subset(be Backend) DynamicBackend {
	// @enumFromInt(@intFromEnum(be)). The source's `be` is comptime, so a
	// backend that is not a candidate is a compile error there.
	return match be {
		.io_uring { .io_uring }
		.epoll { .epoll }
		else { panic('xev: backend ${be} is not a candidate') }
	}
}

pub fn superset(be DynamicBackend) Backend {
	return unsafe { Backend(u8(be)) }
}
