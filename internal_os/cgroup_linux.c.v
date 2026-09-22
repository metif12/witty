module internal_os

import os

#include "@VMODROOT/internal_os/cgroup_linux.h"

#include <errno.h>

#include <fcntl.h>

fn C.witty_clone_into_cgroup(path &char, error_code &int) int

fn C.open(path &char, flags int, mode ...int) int

// current returns the process's cgroup path from /proc/<pid>/cgroup.
pub fn current(pid int) !CgroupCurrentResult {
	contents := os.read_file('/proc/${pid}/cgroup')!
	if contents.len > 1024 * 1024 {
		return error('cgroup proc file exceeds 1 MiB')
	}
	return cgroup_path_from_contents(contents)
}

// create creates child beneath cgroup and optionally moves a process
// into it immediately.
pub fn create(cgroup string, child string, move ?int) ! {
	path := checked_cgroup_path('${cgroup}/${child}')!
	os.mkdir_all(path)!
	if pid := move {
		cgroup_write_existing(os.join_path(path, 'cgroup.procs'), pid.str())!
	}
}

// remove removes an empty cgroup. A missing path is already removed.
pub fn remove(cgroup string) ! {
	path := checked_cgroup_path(cgroup)!
	os.rmdir(path) or {
		if err.code() == C.ENOENT {
			return
		}
		return err
	}
}

pub fn move_into(cgroup string, pid int) ! {
	path := os.join_path(checked_cgroup_path(cgroup)!, 'cgroup.procs')
	cgroup_write_existing(path, pid.str())!
}

pub fn controllers(cgroup string) !string {
	path := os.join_path(checked_cgroup_path(cgroup)!, 'cgroup.controllers')
	contents := os.read_file(path)!
	if contents.len > 1024 * 1024 {
		return error('cgroup controllers file exceeds 1 MiB')
	}
	return contents.trim_right(' \r\n')
}

pub fn configure_controllers(cgroup string, value string) ! {
	path := os.join_path(checked_cgroup_path(cgroup)!, 'cgroup.subtree_control')
	cgroup_write_existing(path, value)!
}

pub fn configure_limit(cgroup string, limit CgroupLimit) ! {
	filename := match limit.kind {
		.memory_high { 'memory.high' }
		.pids_max { 'pids.max' }
	}
	path := os.join_path(checked_cgroup_path(cgroup)!, filename)
	cgroup_write_existing(path, limit.value.str())!
}

fn cgroup_write_existing(path string, value string) ! {
	// V's C binding requires the variadic mode slot even when O_CREAT is not
	// set; libc ignores this zero value for the source's write-only open.
	fd := C.open(&char(path.str), C.O_WRONLY, 0)
	if fd < 0 {
		return os.error_posix()
	}
	defer {
		os.fd_close(fd)
	}

	mut offset := usize(0)
	for offset < usize(value.len) {
		ptr := unsafe { voidptr(usize(value.str) + offset) }
		written := C.write(fd, ptr, usize(value.len) - offset)
		if written < 0 {
			if C.errno == C.EINTR {
				continue
			}
			return os.error_posix()
		}
		if written == 0 {
			return error('short write to cgroup control file')
		}
		offset += usize(written)
	}
}

// clone_into uses clone3(CLONE_INTO_CGROUP) so the child is born in
// the target cgroup and never races while being moved after fork.
pub fn clone_into(cgroup string) !int {
	path := checked_cgroup_path(cgroup)!
	mut error_code := 0
	pid := C.witty_clone_into_cgroup(&char(path.str), &error_code)
	if pid < 0 {
		return error_with_code('unable to clone into cgroup', error_code)
	}
	return pid
}

fn checked_cgroup_path(cgroup string) !string {
	if cgroup.len == 0 || cgroup[0] != `/` {
		return error('cgroup path must be non-empty and /-prefixed')
	}
	path := '/sys/fs/cgroup${cgroup}'
	if path.len + 1 > os.max_path_len {
		return error('cgroup path too long')
	}
	return path
}
