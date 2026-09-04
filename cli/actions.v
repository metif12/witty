module cli

import configpkg
import font
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
			'--default' {
				defaults = true
			}
			'--docs', '--plain' {}
			else {
				return error('unknown option for list-keybinds: ${arg}')
			}
		}
	}
	config := if defaults {
		configpkg.Config.default_config()
	} else {
		configpkg.Config.load_args([])
	}
	return output_lines(config.keybind.format_entries())
}

pub fn run_list_keybinds(args []string) !int {
	print(list_keybinds_output(args)!)
	return 0
}

pub struct FontListOptions {
pub mut:
	family ?string
	style  ?string
	bold   bool
	italic bool
}

pub struct FontListEntry {
pub:
	family string
	name   string
}

// list_fonts_output uses the same native discovery abstraction as the font
// grid. With no family filter Ghostty sorts by family and full face name; a
// family query deliberately preserves discovery priority.
pub fn list_fonts_output(args []string) !string {
	opts := parse_list_fonts_options(args)!
	mut discovery := font.Discover.init()!
	defer {
		discovery.deinit()
	}
	mut iterator := discovery.discover(font.Descriptor{
		family: opts.family
		style: opts.style
		bold: opts.bold
		italic: opts.italic
		monospace: opts.family == none
	})!
	defer {
		iterator.deinit()
	}
	mut entries := []FontListEntry{}
	for {
		mut face := iterator.next() or { break }
		family := face.family_name_value()
		name := face.deferred_name()
		if family.len > 0 && name.len > 0 {
			entries << FontListEntry{
				family: family
				name: name
			}
		}
		face.deinit()
	}
	return format_font_list(entries, opts.family == none)
}

pub fn run_list_fonts(args []string) !int {
	print(list_fonts_output(args)!)
	return 0
}

fn parse_list_fonts_options(args []string) !FontListOptions {
	mut opts := FontListOptions{}
	mut i := 0
	for i < args.len {
		arg := args[i]
		if arg == '--bold' {
			opts.bold = true
		} else if arg == '--italic' {
			opts.italic = true
		} else if arg.starts_with('--family=') {
			opts.family = arg.all_after('=')
		} else if arg.starts_with('--style=') {
			opts.style = arg.all_after('=')
		} else if arg == '--family' || arg == '--style' {
			if i + 1 >= args.len {
				return error('value required for ${arg}')
			}
			i++
			if arg == '--family' {
				opts.family = args[i]
			} else {
				opts.style = args[i]
			}
		} else {
			return error('unknown option for list-fonts: ${arg}')
		}
		i++
	}
	return opts
}

pub fn format_font_list(entries []FontListEntry, sort_results bool) string {
	mut families := []string{}
	mut grouped := map[string][]string{}
	for entry in entries {
		if entry.family !in grouped {
			families << entry.family
			grouped[entry.family] = []string{}
		}
		mut names := grouped[entry.family]
		names << entry.name
		grouped[entry.family] = names
	}
	if sort_results {
		families.sort()
	}
	mut lines := []string{}
	for family in families {
		mut names := grouped[family]
		if sort_results {
			names.sort()
		}
		if names.len == 0 {
			continue
		}
		lines << family
		for name in names {
			lines << '  ${name}'
		}
		lines << ''
	}
	return output_lines(lines)
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

// edit_config_target performs the non-exec portion of `+edit-config`: load the
// config once, resolve Ghostty's preferred user file, and make sure its parent
// directory exists so an editor can create a first configuration.
pub fn edit_config_target(args []string) !string {
	if args.len > 0 {
		return error('unknown option for edit-config: ${args[0]}')
	}
	_ := configpkg.Config.load_args([])
	path := configpkg.preferred_default_file_path()
	ensure_config_parent(path)!
	return path
}

fn ensure_config_parent(path string) ! {
	os.mkdir_all(os.dir(path))!
}

pub fn choose_editor(visual string, editor string) string {
	if visual.len > 0 {
		return visual
	}
	return editor
}

pub fn run_edit_config(args []string) !int {
	path := edit_config_target(args)!
	$if windows {
		eprintln('The `ghostty +edit-config` command is not supported on Windows.')
		eprintln('Please edit the configuration file manually at the following path:\n')
		eprintln(path)
		return 1
	} $else {
		editor := choose_editor(os.getenv('VISUAL'), os.getenv('EDITOR'))
		if editor.len == 0 {
			eprintln('The \$EDITOR or \$VISUAL environment variable is not set or is empty.')
			eprintln('This environment variable is required to edit the Ghostty configuration')
			eprintln('via this CLI command.\n')
			eprintln('Please set the environment variable to your preferred terminal')
			eprintln('text editor and try again.\n')
			eprintln('If you prefer to edit the configuration file another way,')
			eprintln('you can find the configuration file at the following path:\n')
			eprintln('\x1b]8;;file://${path}\x1b\\${path}\x1b]8;;\x1b\\')
			return 1
		}
		os.execvp(editor, [path]) or {
			eprintln('Failed to execute the editor. ${err.msg()}')
			eprintln('Editor: ${editor}')
			eprintln('Path: ${path}')
			return 1
		}
		return 0
	}
}

pub struct ShowConfigOptions {
pub mut:
	defaults     bool
	changes_only bool = true
	docs         bool
}

pub fn show_config_output(args []string) !string {
	opts := parse_show_config_options(args)!
	config := if opts.defaults {
		configpkg.Config.default_config()
	} else {
		configpkg.Config.load_args([])
	}
	return config.format_config_with_docs(!opts.defaults && opts.changes_only, opts.docs)
}

pub fn run_show_config(args []string) !int {
	print(show_config_output(args)!)
	return 0
}

fn parse_show_config_options(args []string) !ShowConfigOptions {
	mut opts := ShowConfigOptions{}
	for arg in args {
		if arg == '--default' {
			opts.defaults = true
		} else if arg == '--docs' {
			opts.docs = true
		} else if arg == '--changes-only' {
			opts.changes_only = true
		} else if arg.starts_with('--changes-only=') {
			value := arg.all_after('=')
			opts.changes_only = match value {
				'true', 't', '1' { true }
				'false', 'f', '0' { false }
				else {
					return error('invalid value for --changes-only: ${value}')
				}
			}
		} else {
			return error('unknown option for show-config: ${arg}')
		}
	}
	return opts
}

fn output_lines(lines []string) string {
	if lines.len == 0 {
		return ''
	}
	return lines.join('\n') + '\n'
}
