module internal_os

import os

// Options controls the optional application subdirectory and permits a
// caller to provide an already-cached home directory.
pub struct Options {
pub:
	subdir ?string
	home   ?string
}

pub fn config(opts Options) !string {
	return xdg_dir(opts, 'XDG_CONFIG_HOME', 'LOCALAPPDATA', '.config')
}

pub fn cache(opts Options) !string {
	return xdg_dir(opts, 'XDG_CACHE_HOME', 'LOCALAPPDATA', '.cache')
}

pub fn state(opts Options) !string {
	return xdg_dir(opts, 'XDG_STATE_HOME', 'LOCALAPPDATA', '.local/state')
}

fn xdg_dir(opts Options, env_name string, windows_env_name string, default_subdir string) !string {
	if cached_home := opts.home {
		return join_xdg(cached_home, default_subdir, opts.subdir)
	}

	mut base := getenv_not_empty(env_name)
	$if windows {
		if base == none {
			base = getenv_not_empty(windows_env_name)
		}
	}
	if env_dir := base {
		if subdir := opts.subdir {
			return os.join_path(env_dir, subdir)
		}
		return env_dir.clone()
	}

	// Get our home dir
	if home_dir := home()!.value {
		return join_xdg(home_dir, default_subdir, opts.subdir)
	}

	return error('NoHomeDir')
}

fn join_xdg(home_dir string, default_subdir string, subdir ?string) string {
	if value := subdir {
		return os.join_path(home_dir, default_subdir, value)
	}
	return os.join_path(home_dir, default_subdir)
}

// parse_terminal_exec recognizes the xdg-terminal-exec argv convention and
// returns its command tail. A leading -e is optional and removed.
pub fn parse_terminal_exec(argv []string) ?[]string {
	if argv.len == 0 || os.file_name(argv[0]) != 'xdg-terminal-exec' {
		return none
	}
	if argv.len < 2 {
		return []string{}
	}
	start := if argv[1] == '-e' { 2 } else { 1 }
	return argv[start..].clone()
}
