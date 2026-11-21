module build_support

import os

pub fn (d Driver) install_help_generator() ! {
	d.generate_help_strings()!
	d.install_file(d.cache_path('host', host_executable('helpgen')), 'bin/' + host_executable('helpgen'))!
}

pub fn (d Driver) generate_help_strings() !string {
	tool := d.host_tool('helpgen', 'tools/helpgen')!
	output := d.cache_path('generated', 'helpgen.zig')
	os.mkdir_all(os.dir(output))!
	os.write_file(output, checked_process_env(d.cfg.root, [tool], {
		'WITTY_HELP_RECORDS': os.dir(output)
	}, false)!)!
	return output
}

pub fn (d Driver) generate_unicode_tables() ![]string {
	mut outputs := []string{}
	for name, folder in {'props-unigen': 'tools/props_unigen', 'symbols-unigen': 'tools/symbols_unigen'} {
		tool := d.host_tool(name, folder)!
		output := d.cache_path('generated', if name == 'props-unigen' { 'props.zig' } else { 'symbols.zig' })
		os.mkdir_all(os.dir(output))!
		os.write_file(output, checked_process_env(d.cfg.root, [tool], {
			'WITTY_UNICODE_BINARY': output.all_before_last('.zig') + '.bin'
		}, false)!)!
		outputs << output
	}
	mut binary := os.read_bytes(d.cache_path('generated', 'props.bin'))!
	binary << os.read_bytes(d.cache_path('generated', 'symbols.bin'))!
	// The separate grapheme state-transition table is pinned generated data;
	// UnicodeTables.zig only regenerates properties and symbol lookups.
	grapheme := os.read_bytes(os.join_path(d.cfg.root, 'unicode', 'tables.bin'))!
	binary << grapheme[98846..]
	os.write_file_array(d.cache_path('generated', 'unicode-tables.bin'), binary)!
	return outputs
}

pub fn (d Driver) install_unicode_generators() ! {
	d.generate_unicode_tables()!
	for name in ['props-unigen', 'symbols-unigen'] { d.install_file(d.cache_path('host', host_executable(name)), 'bin/' + host_executable(name))! }
}
