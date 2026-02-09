module internal_os

import os

// open opens a URL or file path using the system default handler.
pub fn open(url string) ! {
	os.execute('open "${url}"')
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
	name ?string
	home ?string
}

// get_passwd returns the passwd entry for the current user.
pub fn get_passwd() !PasswdEntry {
	name := os.loginname() or { return PasswdEntry{} }
	h := home() or { return PasswdEntry{ name: name } }
	return PasswdEntry{
		name: name
		home: h
	}
}

// pipe creates a pipe and returns [read_fd, write_fd].
// XTODO: needs real OS pipe implementation via C interop.
pub fn pipe() ![2]int {
	return [0, 0]!
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
