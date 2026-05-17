module configpkg

import os

fn test_load_file_applies_theme_colors() {
	path := os.join_path(os.temp_dir(), 'witty-theme-test.conf')
	os.write_file(path, '
# comment
palette = 0=#010203
palette = 15=#fdfefd
background = #102030
foreground = #abcdef
')!
	defer {
		os.rm(path) or {}
	}

	mut cfg := Config.default_config()
	cfg.load_file(path)

	assert cfg.diagnostics.len == 0
	assert cfg.background == ColorRGB{
		r: 0x10
		g: 0x20
		b: 0x30
	}
	assert cfg.foreground == ColorRGB{
		r: 0xab
		g: 0xcd
		b: 0xef
	}
	assert cfg.palette.value[0] == ColorRGB{
		r: 1
		g: 2
		b: 3
	}
	assert cfg.palette.value[15] == ColorRGB{
		r: 0xfd
		g: 0xfe
		b: 0xfd
	}
}

fn test_load_file_records_diagnostics_for_invalid_lines() {
	path := os.join_path(os.temp_dir(), 'witty-theme-invalid-test.conf')
	os.write_file(path, '
foreground #ffffff
background = nope
palette = 300=#ffffff
')!
	defer {
		os.rm(path) or {}
	}

	mut cfg := Config.default_config()
	cfg.load_file(path)

	assert cfg.diagnostics.len == 3
}

fn test_preferred_default_file_path_uses_xdg_config_home() {
	old := os.getenv_opt('XDG_CONFIG_HOME')
	os.setenv('XDG_CONFIG_HOME', '/tmp/witty-config-home', true)
	defer {
		if value := old {
			os.setenv('XDG_CONFIG_HOME', value, true)
		} else {
			os.unsetenv('XDG_CONFIG_HOME')
		}
	}

	assert preferred_default_file_path() == os.join_path('/tmp/witty-config-home', 'ghostty',
		'config')
}
