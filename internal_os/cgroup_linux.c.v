module internal_os

import os

#include "@VMODROOT/internal_os/cgroup_linux.h"

fn C.witty_clone_into_cgroup(path &char, error_code &int) int

// cgroup_current returns the process's cgroup path from /proc/<pid>/cgroup.
pub fn cgroup_current(pid int) !CgroupCurrentResult {
	contents := os.read_file('/proc/${pid}/cgroup')!
	if contents.len > 1024 * 1024 {
		return error('cgroup proc file exceeds 1 MiB')
	}
	return cgroup_path_from_contents(contents)
}

// cgroup_create creates child beneath cgroup and optionally moves a process
// into it immediately.
pub fn cgroup_create(cgroup string, child string, move ?int) ! {
	path := checked_cgroup_path('${cgroup}/${child}')!
	os.mkdir_all(path)!
	if pid := move {
		os.write_file(os.join_path(path, 'cgroup.procs'), pid.str())!
	}
}

// cgroup_remove removes an empty cgroup. A missing path is already removed.
pub fn cgroup_remove(cgroup string) ! {
	path := checked_cgroup_path(cgroup)!
	os.rmdir(path) or {
		if err.code() == C.ENOENT {
			return
		}
		return err
	}
}

pub fn cgroup_move_into(cgroup string, pid int) ! {
	path := os.join_path(checked_cgroup_path(cgroup)!, 'cgroup.procs')
	os.write_file(path, pid.str())!
}

pub fn cgroup_controllers(cgroup string) !string {
	path := os.join_path(checked_cgroup_path(cgroup)!, 'cgroup.controllers')
	contents := os.read_file(path)!
	if contents.len > 1024 * 1024 {
		return error('cgroup controllers file exceeds 1 MiB')
	}
	return contents.trim_right(' \r\n')
}

pub fn cgroup_configure_controllers(cgroup string, value string) ! {
	path := os.join_path(checked_cgroup_path(cgroup)!, 'cgroup.subtree_control')
	os.write_file(path, value)!
}

pub fn cgroup_configure_limit(cgroup string, limit CgroupLimit) ! {
	filename := match limit.kind {
		.memory_high { 'memory.high' }
		.pids_max { 'pids.max' }
	}
	path := os.join_path(checked_cgroup_path(cgroup)!, filename)
	os.write_file(path, limit.value.str())!
}

// cgroup_clone_into uses clone3(CLONE_INTO_CGROUP) so the child is born in
// the target cgroup and never races while being moved after fork.
pub fn cgroup_clone_into(cgroup string) !int {
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
