module internal_os

import os
import crypto.rand as crypto_rand
import encoding.base64
import log

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

// OpenKind is the content hint supplied to the platform URL opener.
pub enum OpenKind {
	unknown
	text
	html
}

// open_command_for_os translates the platform switch in os/open.zig. Keeping
// the selection separate also makes every target's exact argv testable on one
// host.
fn open_command_for_os(os_name string, kind OpenKind, url string) !(string, []string) {
	return match os_name {
		'linux', 'freebsd' { 'xdg-open', [url] }
		'windows' { 'rundll32', ['url.dll,FileProtocolHandler', url] }
		'macos' {
			if kind == .text {
				'open', ['-t', url]
			} else {
				'open', [url]
			}
		}
		else { error('URL opening is unsupported on this platform') }
	}
}

// open opens a URL or file path using the most generic system handler.
pub fn open(url string) ! {
	open_kind(.unknown, url)!
}

// open_kind opens a URL or path with the source content-type hint.
pub fn open_kind(kind OpenKind, url string) ! {
	os_name := $if macos { 'macos' } $else $if linux { 'linux' } $else $if freebsd { 'freebsd' } $else $if windows { 'windows' } $else { 'unsupported' }
	executable, args := open_command_for_os(os_name, kind, url)!
	mut process := os.new_process(executable)
	process.set_args(args)
	// Ghostty pipes both streams so platform helpers never write into the
	// terminal and their diagnostic output can be captured by the reaper.
	process.set_redirect_stdio()
	process.run()
	if process.status == .aborted {
		return error('failed to start URL handler: ${process.err}')
	}
	spawn reap_open_process(mut process)
}

// The platform URL opener may block until the target application exits. Reap
// it away from the caller so opening a link never stalls terminal input.
fn reap_open_process(mut process os.Process) {
	_ = process.stdout_slurp()
	stderr := process.stderr_slurp()
	process.wait()
	if stderr.len > 0 {
		log.warn('URL opener stderr: ${stderr}')
	}
	process.close()
}

// TempDir manages a temporary directory for scratch files.
pub struct TempDir {
pub:
	path string
mut:
	parent    string
	dir_name  string
	destroyed bool
}

pub fn TempDir.init() !TempDir {
	parent := if os.temp_dir().len > 0 { os.temp_dir() } else { os.getwd() }
	for {
		random := crypto_rand.bytes(16)!
		name := base64.url_encode(random)
		path := os.join_path(parent, name)
		os.mkdir(path) or {
			if os.exists(path) {
				continue
			}
			return err
		}
		return TempDir{
			path: path
			parent: parent
			dir_name: name
		}
	}
	return error('unable to create temporary directory')
}

// name returns the generated basename, not the full temporary path.
pub fn (t &TempDir) name() string {
	return t.dir_name
}

pub fn (t TempDir) create_file(name string) !os.File {
	full := os.join_path(t.path, name)
	return os.create(full)
}

pub fn (mut t TempDir) deinit() {
	if t.destroyed || t.dir_name.len == 0 || t.path != os.join_path(t.parent, t.dir_name) {
		return
	}
	os.rmdir_all(t.path) or {
		eprintln('error deleting temp dir: ${err}')
		return
	}
	t.destroyed = true
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
	return '${existing}${os.path_delimiter}${value}'
}

// append_env_always appends a value, always using the colon separator
// even if the existing value is empty (resulting in a leading colon).
pub fn append_env_always(existing string, value string) string {
	return '${existing}${os.path_delimiter}${value}'
}

// prepend_env prepends a value to an existing environment variable string,
// separated by the platform path delimiter (:).
pub fn prepend_env(existing string, value string) string {
	if existing.len == 0 {
		return value
	}
	return '${value}${os.path_delimiter}${existing}'
}

// getenv returns the value of an environment variable, preserving the
// distinction between a missing variable and a variable set to an empty
// string.
pub fn getenv(key string) ?string {
	return os.getenv_opt(key)
}

// getenv_not_empty returns none for both missing and empty variables.
pub fn getenv_not_empty(key string) ?string {
	value := getenv(key) or { return none }
	if value.len == 0 {
		return none
	}
	return value
}

// setenv replaces an environment variable and returns the platform result
// code, matching libc setenv/_putenv_s semantics used by Ghostty.
pub fn setenv(key string, value string) int {
	return os.setenv(key, value, true)
}

// unsetenv removes an environment variable and returns the platform result
// code.
pub fn unsetenv(key string) int {
	return os.unsetenv(key)
}

// is_flatpak returns true if running inside a Flatpak sandbox.
pub fn is_flatpak() bool {
	return os.exists('/.flatpak-info')
}

// home returns the user's home directory.
pub fn home() ?string {
	$if windows {
		drive := getenv('HOMEDRIVE') or { return none }
		path := getenv('HOMEPATH') or { return none }
		return drive + path
	} $else $if ios {
		return none
	} $else {

		// HOME wins exactly as supplied, including an empty value or trailing
		// separator. This is observable in expand_home.
		if value := getenv('HOME') {
			return value
		}

		$if macos {
			// Multi-user macOS setups require NSFileManager rather than passwd.
			if value := home_macos() {
				return value
			}
		}

		// getpwuid_r is the portable fallback on every supported Unix host.
		entry := get_passwd() or { PasswdEntry{} }
		if value := entry.home {
			return value
		}

		// Last resort: ask the login shell to change to its home directory.
		result := os.execute('/bin/sh -c "cd && pwd"')
		if result.exit_code == 0 {
			return result.output.trim(' \n\t')
		}
		return none
	}
}

// expand_home expands only paths beginning with "~/". A lone tilde and
// named-user forms such as "~root/" are deliberately left untouched.
pub fn expand_home(path string) !string {
	$if ios {
		return path
	} $else {
		if !path.starts_with('~/') {
			return path
		}
		home_dir := home() or { return error('home detection failed') }
		return home_dir + path[1..]
	}
}

// PathExpandResult preserves Ghostty's error-union-of-optional return in V,
// which cannot directly express !?string. value == none means the command
// was not present in PATH; errors are still returned by expand.
pub struct PathExpandResult {
pub:
	value ?string
}

// expand searches PATH for cmd and returns the first executable non-directory
// entry. Commands containing a slash are returned unchanged without probing.
pub fn expand(cmd string) !PathExpandResult {
	if cmd.contains('/') {
		return PathExpandResult{
			value: cmd.clone()
		}
	}

	path_env := getenv('PATH') or { return PathExpandResult{} }
	mut saw_access_denied := false
	for search_path in path_env.split(os.path_delimiter) {
		// std.mem.tokenizeScalar, used by Ghostty, skips empty PATH entries.
		if search_path.len == 0 {
			continue
		}
		full_path := search_path + os.path_separator + cmd
		if full_path.len + 1 > os.max_path_len {
			return error('path too long')
		}

		file_stat := os.stat(full_path) or {
			if err.code() == C.EACCES {
				saw_access_denied = true
				continue
			}
			if err.code() == C.ENOENT || err.code() == C.ENOTDIR {
				continue
			}
			return err
		}
		if file_stat.get_filetype() == .directory {
			continue
		}
		// Ghostty opens the candidate before inspecting its mode, so a file
		// that cannot be opened for reading contributes AccessDenied even if
		// stat itself succeeds.
		if !os.is_readable(full_path) {
			saw_access_denied = true
			continue
		}

		$if windows {
			return PathExpandResult{
				value: full_path
			}
		} $else {
			mode := file_stat.get_mode()
			if mode.owner.execute || mode.group.execute || mode.others.execute {
				return PathExpandResult{
					value: full_path
				}
			}
		}
	}

	if saw_access_denied {
		return error('access denied')
	}
	return PathExpandResult{}
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
	if arg.len == 0 {
		return
	}
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

// ShellEscapeWriter escapes the characters Ghostty treats specially when
// constructing shell command text. Newlines deliberately remain unescaped so
// callers can use them to delimit file lists.
pub struct ShellEscapeWriter {
mut:
	buffer []u8
}

pub fn ShellEscapeWriter.init() ShellEscapeWriter {
	return ShellEscapeWriter{}
}

pub fn (mut self ShellEscapeWriter) write(data string) {
	for byte in data.bytes() {
		if byte == 0x60 || byte in [`\\`, `"`, `'`, `$`, `*`, `?`, ` `, `|`, `(`, `)`] {
			self.buffer << `\\`
		}
		self.buffer << byte
	}
}

pub fn (self &ShellEscapeWriter) string() string {
	return self.buffer.bytestr()
}

pub fn (mut self ShellEscapeWriter) deinit() {
	self.buffer = []u8{}
}

pub fn shell_escape(data string) string {
	mut writer := ShellEscapeWriter.init()
	writer.write(data)
	return writer.string()
}
