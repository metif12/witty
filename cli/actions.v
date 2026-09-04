module cli

import configpkg
import os
import terminal

// list_colors_output implements the deterministic plain output of
// `+list-colors`. Pretty terminal rendering is only presentation; the source
// data and ordering are identical to Ghostty's X.Org rgb.txt-backed command.
pub fn list_colors_output(args []string) !string {
	for arg in args {
		if arg != '--plain' {
			return error('unknown option for list-colors: ${arg}')
		}
	}
	mut entries := terminal.x11_color_entries()
	entries.sort_with_compare(fn (a &terminal.NamedRGB, b &terminal.NamedRGB) int {
		lhs := a.name.to_lower()
		rhs := b.name.to_lower()
		if lhs < rhs {
			return -1
		}
		if lhs > rhs {
			return 1
		}
		return 0
	})
	mut lines := []string{cap: entries.len}
	for entry in entries {
		lines << '${entry.name} = #${entry.rgb.r:02x}${entry.rgb.g:02x}${entry.rgb.b:02x}'
	}
	return output_lines(lines)
}

pub fn run_list_colors(args []string) !int {
	print(list_colors_output(args)!)
	return 0
}

// list_keybinds_output serializes either the default or loaded binding set in
// valid Ghostty configuration syntax. `--docs` is accepted for parity; the
// pinned Ghostty option documents that it currently has no effect.
pub fn list_keybinds_output(args []string) !string {
	mut defaults := false
	for arg in args {
		match arg {
			'--default' { defaults = true }
			'--docs', '--plain' {}
			else { return error('unknown option for list-keybinds: ${arg}') }
		}
	}
	config := if defaults { configpkg.Config.default_config() } else { configpkg.Config.load_args([]) }
	return output_lines(config.keybind.format_entries())
}

pub fn run_list_keybinds(args []string) !int {
	print(list_keybinds_output(args)!)
	return 0
}

pub struct ValidateResult {
pub:
	code   int
	output string
}

// validate_config evaluates a specified file, or the normal default config
// stack, and renders every diagnostic one per line.
pub fn validate_config(args []string) !ValidateResult {
	mut path := ?string(none)
	mut i := 0
	for i < args.len {
		arg := args[i]
		if arg.starts_with('--config-file=') {
			if path != none {
				return error('config-file specified more than once')
			}
			path = arg.all_after('=')
		} else if arg == '--config-file' {
			if path != none || i + 1 >= args.len {
				return error('value required for --config-file')
			}
			i++
			path = args[i]
		} else {
			return error('unknown option for validate-config: ${arg}')
		}
		i++
	}

	mut config := if config_path := path {
		mut value := configpkg.Config.default_config()
		abs_path := os.real_path(config_path)
		value.load_file(abs_path)
		value.load_recursive_files()
		value.finalize()
		value
	} else {
		configpkg.Config.load_args([])
	}
	mut lines := []string{cap: config.diagnostics.len}
	for diagnostic in config.diagnostics {
		lines << diagnostic.str()
	}
	return ValidateResult{
		code: if lines.len > 0 { 1 } else { 0 }
		output: output_lines(lines)
	}
}

pub fn run_validate_config(args []string) !int {
	result := validate_config(args)!
	print(result.output)
	return result.code
}

fn output_lines(lines []string) string {
	if lines.len == 0 {
		return ''
	}
	return lines.join('\n') + '\n'
}
