module cli

import ascii
import configpkg
import font
import input
import os
import terminal

struct ListActionsOptions {
mut:
	docs bool
}

// list_actions_output lists every keybinding action, not the CLI actions.
// This is the translated `cli/list_actions.zig` output path; `--docs` asks
// the shared input help generator to include each action's documentation.
pub fn list_actions_output(args []string) !string {
	opts := parse_action_options[ListActionsOptions](args)!
	return input.generate_help(.plaintext, opts.docs)
}

pub fn run_list_actions(args []string) !int {
	print(list_actions_output(args)!)
	return 0
}

// list_colors_output implements the deterministic plain output of
// `+list-colors`. Pretty terminal rendering is only presentation; the source
// data and ordering are identical to Ghostty's X.Org rgb.txt-backed command.
struct ListColorsOptions {
mut:
	plain bool
}

pub fn list_colors_output(args []string) !string {
	opts := parse_action_options[ListColorsOptions](args)!
	_ = opts.plain
	mut entries := terminal.x11_color_entries()
	entries.sort_with_compare(fn (a &terminal.NamedRGB, b &terminal.NamedRGB) int {
		return ascii.order_ignore_case(a.name, b.name)
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
struct ListKeybindsOptions {
mut:
	default_ bool
	docs     bool
	plain    bool
}

pub fn list_keybinds_output(args []string) !string {
	opts := parse_action_options[ListKeybindsOptions](args)!
	_ = opts.docs
	_ = opts.plain
	config := if opts.default_ {
		configpkg.Config.default_config()
	} else {
		configpkg.Config.load_args([])!
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
	mut discovery := font.Discover.init()
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
	return parse_action_options[FontListOptions](args)
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

struct ValidateConfigOptions {
mut:
	config_file ?string
}

// validate_config evaluates a specified file, or the normal default config
// stack, and renders every diagnostic one per line.
pub fn validate_config(args []string) !ValidateResult {
	opts := parse_action_options[ValidateConfigOptions](args)!

	mut config := if config_path := opts.config_file {
		mut value := configpkg.Config.default_config()
		abs_path := os.real_path(config_path)
		value.load_file(abs_path)!
		value.load_recursive_files()!
		value.finalize()!
		value
	} else {
		configpkg.Config.load_args([])!
	}
	mut lines := []string{cap: config.diagnostics.len}
	for diagnostic in config.diagnostics {
		lines << diagnostic.format()
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
struct EditConfigOptions {}

pub fn edit_config_target(args []string) !string {
	_ := parse_action_options[EditConfigOptions](args)!
	_ := configpkg.Config.load_args([])!
	path := configpkg.preferred_default_file_path()!
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
	default_     bool
	changes_only bool = true
	docs         bool
}

pub fn show_config_output(args []string) !string {
	opts := parse_show_config_options(args)!
	config := if opts.default_ {
		configpkg.Config.default_config()
	} else {
		configpkg.Config.load_args([])!
	}
	return config.format_config_with_docs(!opts.default_ && opts.changes_only, opts.docs)
}

pub fn run_show_config(args []string) !int {
	print(show_config_output(args)!)
	return 0
}

fn parse_show_config_options(args []string) !ShowConfigOptions {
	return parse_action_options[ShowConfigOptions](args)
}

fn output_lines(lines []string) string {
	if lines.len == 0 {
		return ''
	}
	return lines.join('\n') + '\n'
}
