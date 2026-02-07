module global_state

// Stub module for Ghostty's global application state.

// ResourcesDir holds the application resources directory path.
pub struct ResourcesDir {
pub:
	path string
}

// app returns the application resources directory, or empty string if not set.
pub fn (r ResourcesDir) app() string {
	return r.path
}

// The global state singleton.
pub const resources_dir = ResourcesDir{}
