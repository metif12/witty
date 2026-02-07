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
	p := os.join_path(os.temp_dir(), 'vterminal')
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
