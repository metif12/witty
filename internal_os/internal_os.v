module internal_os

import os

// C interop declarations for pipes and resource limits.
#include <unistd.h>

#include <fcntl.h>

#include <sys/resource.h>

#include <pwd.h>

fn C.pipe(fds &int) int

fn C.fcntl(fd i32, cmd i32, arg ...voidptr) i32

fn C.getrlimit(resource int, rlp &C.rlimit) int

fn C.setrlimit(resource int, rlp &C.rlimit) int

fn C.getpid() int

fn C.getppid() int

fn C.getuid() int

fn C.getpwuid_r(uid int, pwd &C.passwd, buf &char, buflen usize, result &&C.passwd) int

struct C.passwd {
	pw_name  &char
	pw_dir   &char
	pw_shell &char
}

// rlimit mirrors the C `struct rlimit`. rlim_t is an unsigned 64-bit
// integer on the platforms we target (macOS, Linux, *BSD).
struct C.rlimit {
mut:
	rlim_cur u64
	rlim_max u64
}

// open opens a URL or file path using the system default handler.
pub fn open(url string) ! {
	mut process := os.new_process('')
	$if macos {
		process = os.new_process('/usr/bin/open')
	} $else $if linux || freebsd {
		process = os.new_process('xdg-open')
	} $else $if windows {
		process = os.new_process('rundll32')
	} $else {
		return error('URL opening is unsupported on this platform')
	}
	$if windows {
		process.set_args(['url.dll,FileProtocolHandler', url])
	} $else {
		process.set_args([url])
	}
	process.run()
	if process.status == .aborted {
		return error('failed to start URL handler: ${process.err}')
	}
	spawn reap_open_process(mut process)
}

// The platform URL opener may block until the target application exits. Reap
// it away from the caller so opening a link never stalls terminal input.
fn reap_open_process(mut process os.Process) {
	process.wait()
	process.close()
}

// TempDir manages a temporary directory for scratch files.
pub struct TempDir {
pub:
	path string
}

pub fn TempDir.init() !TempDir {
	p := os.join_path(os.temp_dir(), 'Witty')
	os.mkdir_all(p) or {}
	return TempDir{ path: p }
}

pub fn (t TempDir) create_file(name string) !os.File {
	full := os.join_path(t.path, name)
	return os.create(full)
}

pub fn (t TempDir) deinit() {
	os.rmdir_all(t.path) or {}
}

// get_env_map returns the current environment as a map.
pub fn get_env_map() !map[string]string {
	return os.environ()
}

// launched_from_desktop detects launches from Finder on macOS and desktop
// files on Linux/BSD. This is the platform switch used by Ghostty when
// deciding whether GUI-only environment overrides should reach child shells.
pub fn launched_from_desktop() bool {
	$if macos {
		if os.getenv('GHOSTTY_MAC_LAUNCH_SOURCE') == 'app' {
			return true
		}
		return C.getppid() == 1
	} $else $if linux || freebsd {
		pid := os.getenv('GIO_LAUNCHED_DESKTOP_FILE_PID').int()
		return pid > 0 && pid == C.getpid()
	} $else $if ios {
		return true
	} $else {
		return false
	}
}

// append_env appends a value to an existing environment variable string,
// separated by the platform path delimiter (:).
pub fn append_env(existing string, value string) string {
	if existing.len == 0 {
		return value
	}
	return '${existing}:${value}'
}

// append_env_always appends a value, always using the colon separator
// even if the existing value is empty (resulting in a leading colon).
pub fn append_env_always(existing string, value string) string {
	return '${existing}:${value}'
}

// prepend_env prepends a value to an existing environment variable string,
// separated by the platform path delimiter (:).
pub fn prepend_env(existing string, value string) string {
	if existing.len == 0 {
		return value
	}
	return '${value}:${existing}'
}

// is_flatpak returns true if running inside a Flatpak sandbox.
pub fn is_flatpak() bool {
	return os.exists('/.flatpak-info')
}

// home returns the user's home directory.
pub fn home() ?string {
	h := os.home_dir()
	if h.len == 0 {
		return none
	}
	// Strip trailing separator
	if h.ends_with('/') || h.ends_with('\\') {
		return h[..h.len - 1]
	}
	return h
}

// PasswdEntry represents a passwd database entry.
pub struct PasswdEntry {
pub:
	shell ?string
	home  ?string
	name  ?string
}

// get_passwd returns the passwd entry for the current user.
pub fn get_passwd() !PasswdEntry {
	$if windows {
		name := os.loginname() or { return PasswdEntry{} }
		h := home() or { return PasswdEntry{ name: name } }
		return PasswdEntry{
			name: name
			home: h
		}
	}

	mut buf := []u8{len: 1024}
	mut pw := C.passwd{}
	mut pw_result := &C.passwd(unsafe { nil })
	if C.getpwuid_r(C.getuid(), &pw, unsafe { &char(buf.data) }, usize(buf.len), &pw_result) != 0
		|| isnil(pw_result) {
		return PasswdEntry{}
	}
	return PasswdEntry{
		shell: if isnil(pw.pw_shell) { none } else { unsafe { cstring_to_vstring(pw.pw_shell) } }
		home: if isnil(pw.pw_dir) { none } else { unsafe { cstring_to_vstring(pw.pw_dir) } }
		name: if isnil(pw.pw_name) { none } else { unsafe { cstring_to_vstring(pw.pw_name) } }
	}
}

// pipe() that works on POSIX systems. This sets CLOEXEC on the file
// descriptors. Returns [read_fd, write_fd].
pub fn pipe() ![2]int {
	mut fds := [2]int{}
	if C.pipe(&fds[0]) != 0 {
		return error('failed to create pipe')
	}

	// POSIX doesn't have pipe2() everywhere (e.g. macOS), so we set
	// CLOEXEC manually with fcntl to match Ghostty's pipe2(.{ .CLOEXEC = true }).
	set_cloexec(fds[0])
	set_cloexec(fds[1])
	return fds
}

// set_cloexec sets the FD_CLOEXEC flag on the given file descriptor.
fn set_cloexec(fd int) {
	flags := C.fcntl(fd, C.F_GETFD, 0)
	if flags >= 0 {
		C.fcntl(fd, C.F_SETFD, flags | C.FD_CLOEXEC)
	}
}

// Rlimit mirrors the Unix resource limit (soft/hard) for a resource.
pub struct Rlimit {
pub mut:
	cur u64
	max u64
}

// fix_max_files maximizes the number of file descriptors we can have open.
// We need to do this because each window consumes at least a handful of fds.
// This is extracted from the Zig compiler source code. Returns the previous
// limit so it can later be restored, or none if the limit couldn't be queried.
pub fn fix_max_files() !Rlimit {
	old := getrlimit_nofile() or {
		// Oh well; we tried.
		return error('failed to query file handle limit, may limit max windows')
	}

	// If we're already at the max, we're done.
	if old.cur >= old.max {
		return old
	}

	// Do a binary search for the limit.
	mut lim := old
	mut min := old.cur
	mut max := u64(1) << 20
	// But if there's a defined upper bound, don't search, just set it.
	if old.max != rlim_infinity() {
		min = old.max
		max = old.max
	}

	for {
		lim.cur = min + (max - min) / 2
		if setrlimit_nofile(lim) {
			min = lim.cur
		} else {
			max = lim.cur
		}
		if min + 1 >= max {
			break
		}
	}

	return old
}

// restore_max_files restores the file descriptor limit to a previous value.
pub fn restore_max_files(lim Rlimit) {
	setrlimit_nofile(lim)
}

// getrlimit_nofile queries the current NOFILE resource limit.
fn getrlimit_nofile() ?Rlimit {
	mut rl := C.rlimit{}
	if C.getrlimit(C.RLIMIT_NOFILE, &rl) != 0 {
		return none
	}
	return Rlimit{
		cur: rl.rlim_cur
		max: rl.rlim_max
	}
}

// setrlimit_nofile sets the NOFILE resource limit, returning true on success.
fn setrlimit_nofile(lim Rlimit) bool {
	rl := C.rlimit{
		rlim_cur: lim.cur
		rlim_max: lim.max
	}
	return C.setrlimit(C.RLIMIT_NOFILE, &rl) == 0
}

// rlim_infinity returns the RLIM_INFINITY sentinel value for this platform.
fn rlim_infinity() u64 {
	return u64(C.RLIM_INFINITY)
}

// ShellCommandBuilder accumulates arguments to build a shell command string.
pub struct ShellCommandBuilder {
mut:
	args []string
}

// init creates a new ShellCommandBuilder.
pub fn ShellCommandBuilder.init() ShellCommandBuilder {
	return ShellCommandBuilder{}
}

// append_arg adds an argument to the command being built.
pub fn (mut b ShellCommandBuilder) append_arg(arg string) {
	b.args << arg
}

// to_owned_slice returns the accumulated command as a single space-joined string.
pub fn (b ShellCommandBuilder) to_owned_slice() string {
	return b.args.join(' ')
}

// deinit cleans up the builder.
pub fn (mut b ShellCommandBuilder) deinit() {
	b.args = []string{}
}
