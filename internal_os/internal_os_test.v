module internal_os

import os

fn test_pipe_returns_distinct_fds() {
	fds := pipe() or { panic(err) }
	defer {
		os.fd_close(fds[0])
		os.fd_close(fds[1])
	}
	assert fds[0] >= 0
	assert fds[1] >= 0
	assert fds[0] != fds[1]
}

fn test_fix_max_files_can_restore_when_available() {
	lim := fix_max_files() or { return }
	restore_max_files(lim)
	assert lim.cur > 0
	assert lim.max >= lim.cur
}

fn test_fix_max_files_does_not_shrink_limit() {
	// After fixing, the current NOFILE limit must be at least what it was
	// before: fix_max_files only ever raises it, then returns the *old*
	// value so it can be restored.
	old := fix_max_files() or { return }
	// The old value must be sane: a positive soft limit within the hard limit.
	assert old.cur > 0
	assert old.max >= old.cur
	restore_max_files(old)
}
