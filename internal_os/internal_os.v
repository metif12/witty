module internal_os

import os
import crypto.rand as crypto_rand
import encoding.base64
import log
import zig_fmt
import openurl

// OpenType is the source alias for the content hint consumed by open.
pub type OpenType = openurl.Kind

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

fn C.ReadFile(handle voidptr, buffer voidptr, bytes_to_read u32, bytes_read &u32, overlapped voidptr) bool

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

// open_command_for_os translates the platform switch in os/open.zig. Keeping
// the selection separate also makes every target's exact argv testable on one
// host.
fn open_command_for_os(os_name string, kind openurl.Kind, url string) !(string, []string) {
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

// open opens a URL or path with the source content-type hint.
pub fn open(kind OpenType, url string) ! {
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
	stdout_result := chan OpenProcessOutput{ cap: 1 }
	stderr_result := chan OpenProcessOutput{ cap: 1 }
	stdout_thread := spawn collect_open_stdout(mut process, stdout_result)
	stderr_thread := spawn collect_open_stderr(mut process, stderr_result)
	stdout := <-stdout_result
	stderr := <-stderr_result
	stdout_thread.wait()
	stderr_thread.wait()
	process.wait()
	if !stdout.too_long && !stderr.too_long && stderr.data.len > 0 {
		log.warn('URL opener stderr: ${stderr.data}')
	}
	process.close()
}

const open_process_output_max = 50 * 1024

struct OpenProcessOutput {
	data     string
	too_long bool
}

struct OpenProcessOutputAccumulator {
mut:
	data     []u8
	too_long bool
}

fn (mut self OpenProcessOutputAccumulator) add(chunk []u8) {
	if self.data.len <= open_process_output_max {
		remaining := open_process_output_max + 1 - self.data.len
		keep := if chunk.len < remaining { chunk.len } else { remaining }
		self.data << chunk[..keep]
		if keep < chunk.len {
			self.too_long = true
		}
	} else {
		self.too_long = true
	}
}

fn (mut self OpenProcessOutputAccumulator) finish() OpenProcessOutput {
	if self.data.len > open_process_output_max {
		self.too_long = true
	}
	return OpenProcessOutput{
		data: if self.too_long { '' } else { self.data.bytestr() }
		too_long: self.too_long
	}
}

fn collect_open_stdout(mut process os.Process, result chan OpenProcessOutput) {
	collect_open_output(mut process, .stdout, result)
}

fn collect_open_stderr(mut process os.Process, result chan OpenProcessOutput) {
	collect_open_output(mut process, .stderr, result)
}

fn collect_open_output(mut process os.Process, kind os.ChildProcessPipeKind, result chan OpenProcessOutput) {
	mut output := OpenProcessOutputAccumulator{
		data: []u8{ cap: open_process_output_max + 1 }
	}
	$if windows {
		wdata := unsafe { &os.WProcess(process.wdata) }
		handle := match kind {
			.stdout { voidptr(wdata.child_stdout_read) }
			.stderr { voidptr(wdata.child_stderr_read) }
			.stdin { unsafe { nil } }
		}
		if !isnil(handle) {
			mut buffer := [4096]u8{}
			for {
				mut bytes_read := u32(0)
				if !C.ReadFile(handle, &buffer[0], u32(buffer.len), &bytes_read, unsafe { nil })
					|| bytes_read == 0 {
					break
				}
				output.add(buffer[..int(bytes_read)])
			}
		}
	} $else {
		fd := process.stdio_fd[int(kind)]
		for {
			chunk, count := os.fd_read(fd, 4096)
			if count <= 0 {
				break
			}
			output.add(chunk.bytes())
		}
	}
	result <- output.finish()
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
	parent := alloc_tmp_dir() or { os.getwd() }
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
	if is_flatpak() {
		return map[string]string{}
	}
	return os.environ()
}

// ArgIterator is the flattened translation of os/args.zig's platform-aware
// command-line iterator. V owns its process arguments, so the iterator keeps
// an owned snapshot and has the same next/skip/deinit lifecycle.
pub struct ArgIterator {
mut:
	args  []string
	index usize
}

// init_with_allocator is the V-owned counterpart of
// ArgIterator.initWithAllocator. V strings and arrays are GC-owned, so there
// is no allocator argument to retain.
pub fn ArgIterator.init_with_allocator() ArgIterator {
	return ArgIterator{
		args: platform_args()
	}
}

pub fn iterator() ArgIterator {
	return ArgIterator.init_with_allocator()
}

pub fn (mut self ArgIterator) deinit() {
	self.args.clear()
	self.index = 0
}

pub fn (mut self ArgIterator) next() ?string {
	if self.index >= usize(self.args.len) {
		return none
	}
	result := self.args[self.index]
	self.index++
	return result
}

pub fn (mut self ArgIterator) skip() bool {
	if self.index >= usize(self.args.len) {
		return false
	}
	self.index++
	return true
}

// launched_by_dbus_activation reports the environment contract used by D-Bus
// activation. Values may be empty; presence of both variables is sufficient.
pub fn launched_by_dbus_activation() bool {
	$if linux {
		return getenv('DBUS_STARTER_ADDRESS') != none && getenv('DBUS_STARTER_BUS_TYPE') != none
	} $else {
		return false
	}
}

// Direct translation of `std.fmt.parseInt(@TypeOf(c.getpid()), value, 10)`.
fn parse_pid(value string) ?int {
	return int(zig_fmt.parse_int_signed(value, 32, 10) or { return none })
}

// launched_from_desktop detects launches from Finder on macOS and desktop
// files on Linux/BSD. This is the platform switch used by Ghostty when
// deciding whether GUI-only environment overrides should reach child shells.
pub fn launched_from_desktop() bool {
	$if macos {
		// The pinned build configuration selects the executable artifact.
		// Ghostty consults GHOSTTY_MAC_LAUNCH_SOURCE only for library builds.
		return C.getppid() == 1
	} $else $if linux || freebsd {
		pid := parse_pid(os.getenv('GIO_LAUNCHED_DESKTOP_FILE_PID')) or { return false }
		return pid == C.getpid()
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

	// A Flatpak passwd entry only has a reliable username. Query the host for
	// the shell and home directory, matching Ghostty's host-command path.
	$if linux {
		if is_flatpak() {
			name := if isnil(pw.pw_name) {
				''
			} else {
				unsafe { cstring_to_vstring(pw.pw_name) }
			}
			return get_passwd_flatpak(name)!
		}
	}
	return PasswdEntry{
		shell: if isnil(pw.pw_shell) { none } else { unsafe { cstring_to_vstring(pw.pw_shell) } }
		home: if isnil(pw.pw_dir) { none } else { unsafe { cstring_to_vstring(pw.pw_dir) } }
		name: if isnil(pw.pw_name) { none } else { unsafe { cstring_to_vstring(pw.pw_name) } }
	}
}

fn parse_flatpak_passwd_output(output string) PasswdEntry {
	parts := output.trim_right(' \r\n').split(':')
	return PasswdEntry{
		shell: if parts.len > 0 { parts[parts.len - 1] } else { none }
		home: if parts.len > 1 { parts[parts.len - 2] } else { none }
	}
}

// pipe() that works on POSIX systems. This sets CLOEXEC on the file
// descriptors. Returns [read_fd, write_fd].
pub fn pipe() ![2]int {
	mut fds := [2]int{}
	if C.pipe(&fds[0]) != 0 {
		return os.error_posix()
	}

	// POSIX doesn't have pipe2() everywhere (e.g. macOS), so we set
	// CLOEXEC manually with fcntl to match Ghostty's pipe2(.{ .CLOEXEC = true }).
	set_cloexec(fds[0]) or {
		os.fd_close(fds[0])
		os.fd_close(fds[1])
		return err
	}
	set_cloexec(fds[1]) or {
		os.fd_close(fds[0])
		os.fd_close(fds[1])
		return err
	}
	return fds
}

// set_cloexec sets the FD_CLOEXEC flag on the given file descriptor.
fn set_cloexec(fd int) ! {
	flags := C.fcntl(fd, C.F_GETFD, 0)
	if flags < 0 {
		return os.error_posix()
	}
	if C.fcntl(fd, C.F_SETFD, flags | C.FD_CLOEXEC) < 0 {
		return os.error_posix()
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
pub fn fix_max_files() ?Rlimit {
	old := getrlimit_nofile() or {
		// Oh well; we tried.
		return none
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

// alloc_tmp_dir returns the source-compatible recommended temporary directory.
// V strings are garbage collected, so free_tmp_dir is intentionally a no-op.
pub fn alloc_tmp_dir() ?string {
	$if windows {
		return getenv('TMP')
	} $else {
		if value := getenv('TMPDIR') {
			return value
		}
		if value := getenv('TMP') {
			return value
		}
		return '/tmp'
	}
}

pub fn free_tmp_dir(dir string) {
	_ = dir
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
