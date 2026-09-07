module crash

import os

#include "@VMODROOT/crash/mtime.h"

fn C.witty_crash_file_mtime_ns(path &char, value &i64) int

fn C.witty_crash_thread_state_set(kind int, surface voidptr)

fn C.witty_crash_thread_state_clear()

fn C.witty_crash_thread_state_get(kind &int, surface &voidptr) int

// ThreadState carries the same per-thread context Ghostty attaches to crash
// reports. The surface stays opaque here to avoid a crash -> core -> crash
// import cycle.
pub struct ThreadState {
pub:
	kind    ThreadType
	surface voidptr
}

pub enum ThreadType {
	main
	renderer
	io
}

pub fn set_thread_state(state ThreadState) {
	C.witty_crash_thread_state_set(int(state.kind), state.surface)
}

pub fn clear_thread_state() {
	C.witty_crash_thread_state_clear()
}

pub fn thread_state() ?ThreadState {
	mut kind := 0
	mut surface := voidptr(unsafe { nil })
	if C.witty_crash_thread_state_get(&kind, &surface) == 0 {
		return none
	}
	return ThreadState{
		kind: unsafe { ThreadType(kind) }
		surface: surface
	}
}

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

// ReportIterator lazily returns regular crash-report files. V's directory API
// returns the directory entries as an owned array, so deinit releases that
// array instead of closing an open directory handle.
pub struct ReportIterator {
	path string
pub mut:
	entries []string
	index   int
}

// default_dir returns Ghostty's XDG state directory for crash reports.
pub fn default_dir() Dir {
	return Dir{
		path: os.join_path(os.state_dir(), 'ghostty', 'crash')
	}
}

// iterator returns an iterator over the crash reports in this directory. A
// missing or unreadable directory behaves like an empty report directory.
pub fn (dir &Dir) iterator() !ReportIterator {
	return ReportIterator{
		path: dir.path
		entries: os.ls(dir.path) or { []string{} }
	}
}

pub fn (mut self ReportIterator) deinit() {
	self.entries.clear()
	self.index = 0
}

// next returns the next regular crash-report file, skipping directories and
// other non-file entries just like std.fs.Dir.Iterator in Ghostty.
pub fn (mut self ReportIterator) next() ?Report {
	for self.index < self.entries.len {
		name := self.entries[self.index]
		self.index++
		path := os.join_path(self.path, name)
		if !os.is_file(path) {
			continue
		}

		mut mtime := i64(0)
		if C.witty_crash_file_mtime_ns(&char(path.str), &mtime) != 0 {
			continue
		}
		return Report{
			name: name
			mtime: mtime
		}
	}
	return none
}

// reports collects the report iterator for callers that need an owned array.
pub fn (dir &Dir) reports() ![]Report {
	mut iter := dir.iterator()!
	defer {
		iter.deinit()
	}
	mut result := []Report{}
	for {
		report := iter.next() or { break }
		result << report
	}
	return result
}
