module cli

import ascii
import cli_args
import configpkg
import encoding.utf8.validate
import font
import input
import os
import terminal

// list_actions_output lists every keybinding action, not the CLI actions.
// This is the translated `cli/list_actions.zig` output path; `--docs` asks
// the shared input help generator to include each action's documentation.
pub fn list_actions_output(args []string) !string {
	mut docs := false
	for arg in args {
		match arg {
			'--docs' {
				docs = true
			}
			else {
				return error('unknown option for list-actions: ${arg}')
			}
		}
	}
	return input.generate_help(.plaintext, docs)
}

pub fn run_list_actions(args []string) !int {
	print(list_actions_output(args)!)
	return 0
}

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

pub struct ShowFaceOptions {
pub mut:
	cp           ?u32
	string_value ?string
	style        font.FontStyle = .regular
	presentation ?font.Presentation
	config_args  []string
}

pub struct ShowFaceResult {
pub:
	code   int
	output string
	errors string
}

// show_face resolves codepoints through the same SharedGrid used by terminal
// surfaces, including configured faces, platform fallbacks, embedded faces,
// emoji presentation, and Ghostty's internal sprite font.
pub fn show_face(args []string) !ShowFaceResult {
	opts := parse_show_face_options(args)!
	if opts.cp == none && opts.string_value == none {
		return ShowFaceResult{
			code: 1
			errors: 'You must specify a codepoint with --cp or a string with --string\n'
		}
	}

	mut config := configpkg.Config.load_args(opts.config_args)
	mut errors := []string{}
	for diagnostic in config.diagnostics {
		errors << 'config error: ${diagnostic}'
	}

	mut grid_set := font.SharedGridSet.init() or {
		return ShowFaceResult{
			code: 1
			errors: output_lines(errors) + 'Unable to initialize font grid set: ${err}\n'
		}
	}
	defer {
		grid_set.deinit()
	}
	mut font_config := derived_font_config(config)
	defer {
		font_config.deinit()
	}
	key, mut grid := grid_set.ref(&font_config, font.DesiredSize{
		points: config.font_size
		xdpi: 96
		ydpi: 96
	}) or {
		return ShowFaceResult{
			code: 1
			errors: output_lines(errors) + 'Unable to get font grid: ${err}\n'
		}
	}
	defer {
		grid_set.deref(key)
	}
	mut output := []string{}
	if cp := opts.cp {
		if lookup_error := show_face_lookup(mut grid, cp, opts.style, opts.presentation, mut output) {
			errors << lookup_error
			return ShowFaceResult{
				code: 1
				output: output_lines(output)
				errors: output_lines(errors)
			}
		}
	}
	if value := opts.string_value {
		if !validate.utf8_string(value) {
			errors << 'Unable to parse string as unicode: invalid UTF-8'
			return ShowFaceResult{
				code: 1
				output: output_lines(output)
				errors: output_lines(errors)
			}
		}
		for cp in value.runes() {
			if lookup_error := show_face_lookup(mut grid, u32(cp), opts.style, opts.presentation, mut output) {
				errors << lookup_error
				return ShowFaceResult{
					code: 1
					output: output_lines(output)
					errors: output_lines(errors)
				}
			}
		}
	}

	return ShowFaceResult{
		output: output_lines(output)
		errors: output_lines(errors)
	}
}

pub fn run_show_face(args []string) !int {
	result := show_face(args) or {
		eprintln('Error parsing args: ${err}')
		return 1
	}
	print(result.output)
	eprint(result.errors)
	return result.code
}

fn parse_show_face_options(args []string) !ShowFaceOptions {
	mut opts := ShowFaceOptions{}
	for arg in args {
		if !arg.starts_with('--') {
			opts.config_args << arg
			continue
		}
		key_value := arg[2..]
		equals := key_value.index_u8(`=`)
		key := if equals < 0 { key_value } else { key_value[..equals] }
		value := if equals < 0 { none } else { ?string(key_value[equals + 1..]) }
		match key {
			'cp' {
				raw := value or { return error('value required for --cp') }
				opts.cp = parse_show_face_codepoint(raw) or {
					return error('invalid value for --cp: ${raw}')
				}
			}
			'string' {
				opts.string_value = value or { return error('value required for --string') }
			}
			'style' {
				raw := value or { return error('value required for --style') }
				opts.style = match raw {
					'regular' { .regular }
					'bold' { .bold }
					'italic' { .italic }
					'bold_italic' { .bold_italic }
					else {
						return error('invalid value for --style: ${raw}')
					}
				}
			}
			'presentation' {
				raw := value or { return error('value required for --presentation') }
				opts.presentation = match raw {
					'text' { font.Presentation.text }
					'emoji' { font.Presentation.emoji }
					else {
						return error('invalid value for --presentation: ${raw}')
					}
				}
			}
			else {
				// The upstream action enables diagnostics so ordinary Config flags
				// remain available alongside action-specific flags.
				opts.config_args << arg
			}
		}
	}
	return opts
}

fn parse_show_face_codepoint(value string) ?u32 {
	return u32(cli_args.parse_unsigned_int(value, 21) or { return none })
}

fn grid_set_font_style(style configpkg.FontStyle) font.GridSetFontStyleConfig {
	return font.GridSetFontStyleConfig{
		kind: match style.kind {
			.default_ { .default_ }
			.false_ { .false_ }
			.name { .name }
		}
		name: style.name
	}
}

fn derived_font_config(config &configpkg.Config) font.GridSetDerivedConfig {
	return font.GridSetDerivedConfig{
		font_family: config.font_family.clone()
		font_family_bold: config.font_family_bold.clone()
		font_family_italic: config.font_family_italic.clone()
		font_family_bold_italic: config.font_family_bold_italic.clone()
		font_style: grid_set_font_style(config.font_style)
		font_style_bold: grid_set_font_style(config.font_style_bold)
		font_style_italic: grid_set_font_style(config.font_style_italic)
		font_style_bold_italic: grid_set_font_style(config.font_style_bold_italic)
		font_variation: config.font_variation.list.clone()
		font_variation_bold: config.font_variation_bold.list.clone()
		font_variation_italic: config.font_variation_italic.list.clone()
		font_variation_bold_italic: config.font_variation_bold_italic.list.clone()
		font_codepoint_map: config.font_codepoint_map.map.clone()
		font_synthetic_style: config.font_synthetic_style
		adjust_cell_width: config.adjust_cell_width
		adjust_cell_height: config.adjust_cell_height
		adjust_font_baseline: config.adjust_font_baseline
		adjust_underline_position: config.adjust_underline_position
		adjust_underline_thickness: config.adjust_underline_thickness
		adjust_strikethrough_position: config.adjust_strikethrough_position
		adjust_strikethrough_thickness: config.adjust_strikethrough_thickness
		adjust_overline_position: config.adjust_overline_position
		adjust_overline_thickness: config.adjust_overline_thickness
		adjust_cursor_thickness: config.adjust_cursor_thickness
		adjust_cursor_height: config.adjust_cursor_height
		adjust_box_thickness: config.adjust_box_thickness
		adjust_icon_height: config.adjust_icon_height
		freetype_load_flags: config.freetype_load_flags
	}
}

fn show_face_lookup(mut grid font.SharedGrid, cp u32, style font.FontStyle, presentation ?font.Presentation, mut output []string) ?string {
	value := grid.get_index(cp, style, presentation) or {
		return 'Unable to get face: ${err}'
	}
	display := rune(cp).str()
	if !value.has_value {
		output << 'U+${cp:02X} « ${display} » not found.'
		return none
	}
	if _ := value.index.special() {
		output << "U+${cp:02X} « ${display} » is handled by Ghostty's internal sprites."
		return none
	}
	mut name_buf := []u8{len: 1024}
	face := grid.resolver.collection.get_face(value.index) or {
		return 'Unable to get face: ${err}'
	}
	name := face.name(mut name_buf) or {
		return 'Unable to get name of face: ${err}'
	}
	output << 'U+${cp:02X} « ${display} » found in face “${name}”.'
	return none
}

fn output_lines(lines []string) string {
	if lines.len == 0 {
		return ''
	}
	return lines.join('\n') + '\n'
}
