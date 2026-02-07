module crash

// Sentry provides crash metadata tracking.
pub struct Sentry {
pub mut:
	thread_state ?ThreadState
}

pub struct ThreadState {}

// Global sentry instance.
pub const sentry = &Sentry{}
