module crash

// Sentry provides crash metadata tracking.
pub struct Sentry {
pub mut:
	thread_state ?ThreadState
}

pub struct ThreadState {}

// Global sentry instance.
pub const sentry = &Sentry{}

// Process-wide crash reporter lifecycle. The pinned Ghostty implementation
// returns immediately when its optional Sentry build flag is disabled. Witty
// does not link the Sentry native SDK, so these are that exact disabled-build
// path while still preserving the global lifecycle API.
pub fn initialize() ! {}

pub fn shutdown() {}
