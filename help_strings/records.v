module help_strings

import os

// V's generated import is the documented record data, rather than a Zig
// declaration module. Preserve the records emitted by the source generator.
pub fn write_records(directory string) ! {
	os.mkdir_all(directory)!
	for index, entries in [gen_config().entries, gen_actions().entries, gen_keybind_actions().entries] {
		marker := if index == 0 { '\x1e' } else { '@@' }
		mut text := ''
		for entry in entries { text += marker + entry.name + '\n' + entry.text + '\n' }
		text += marker + '__end\n'
		filename := ['config_help.txt', 'cli_action_help.txt', 'keybind_action_help.txt'][index]
		os.write_file(os.join_path(directory, filename), text)!
	}
}
