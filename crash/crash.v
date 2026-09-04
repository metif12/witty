module crash

import os

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

pub struct Dir {
pub:
	path string
}

pub struct Report {
pub:
	name  string
	mtime i64
}

// default_dir returns Ghostty's XDG state directory for crash reports.
pub fn default_dir() Dir {
	return Dir{
		path: os.join_path(os.state_dir(), 'ghostty', 'crash')
	}
}

// reports returns regular crash-report files and their nanosecond mtimes. A
// missing or unreadable directory behaves like an empty report directory.
pub fn (dir Dir) reports() ![]Report {
	entries := os.ls(dir.path) or { return []Report{} }
	mut result := []Report{}
	for name in entries {
		path := os.join_path(dir.path, name)
		if !os.is_file(path) {
			continue
		}
		file_stat := os.stat(path)!
		result << Report{
			name: name
			mtime: file_stat.mtime * i64(1_000_000_000)
		}
	}
	return result
}
