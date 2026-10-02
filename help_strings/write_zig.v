module help_strings

import io

fn write_all(mut writer io.Writer, text string) ! {
	mut remaining := text.bytes()
	for remaining.len > 0 {
		count := writer.write(remaining)!
		if count <= 0 || count > remaining.len { return error('invalid help writer byte count') }
		remaining = remaining[count..]
	}
}

// helpgen.zig's emitter, operating on the already parsed, pinned doc records.
// Parsing Zig syntax is a compiler-specific input step; these same records
// were explicitly retained as generated data by the original audit.
pub fn write_zig(mut writer io.Writer) ! {
	write_all(mut writer, '// THIS FILE IS AUTO GENERATED\n\n')!
	for index, entries in [gen_config().entries, gen_actions().entries, gen_keybind_actions().entries] {
		heading := ['Configuration help', 'Actions help', 'keybind actions help'][index]
		name := ['Config', 'Action', 'KeybindAction'][index]
		write_all(mut writer, '${if index == 1 { '\n' } else { '' }}/// ${heading}\npub const ${name} = struct {\n\n')!
		for entry in entries {
			identifier := if index == 1 || entry.name.contains('-') { '@"${entry.name}"' } else { entry.name }
			write_all(mut writer, 'pub const ${identifier}${if index == 1 { '' } else { ': [:0]const u8' }} = \n')!
			for line in entry.text.split('\n') { write_all(mut writer, '    \\\\${line}\n')! }
			write_all(mut writer, ';\n${if index == 1 { '\n\n' } else { '\n' }}')!
		}
		write_all(mut writer, '};\n')!
	}
}
