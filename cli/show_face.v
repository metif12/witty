module cli

import cli_args
import configpkg
import diagnostics
import encoding.utf8.validate
import font

pub struct ShowFaceOptions {
pub mut:
	cp           ?u32 @[cli_u21]
	string_      ?string
	style        font.FontStyle = .regular
	presentation ?font.Presentation
	diagnostics  diagnostics.DiagnosticList
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
	mut errors := []string{}
	for diagnostic in opts.diagnostics.items() {
		if diagnostic.location is diagnostics.CliLocation
			&& cli_args.has_field[ShowFaceOptions](diagnostic.key) {
			errors << 'config error: ${diagnostic.format()}'
		}
	}
	if errors.len > 0 {
		return ShowFaceResult{
			code: 1
			errors: output_lines(errors)
		}
	}
	if opts.cp == none && opts.string_ == none {
		return ShowFaceResult{
			code: 1
			errors: 'You must specify a codepoint with --cp or a string with --string\n'
		}
	}

	mut config := configpkg.Config.load_args(args) or {
		return ShowFaceResult{
			code: 1
			errors: 'Unable to load config: ${err}'
		}
	}
	for diagnostic in config.diagnostics {
		if cli_args.has_field[ShowFaceOptions](diagnostic.key)
			&& (diagnostic.location is diagnostics.NoneLocation
				|| diagnostic.location is diagnostics.CliLocation) {
			continue
		}
		errors << 'config error: ${diagnostic.format()}'
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
	if value := opts.string_ {
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
		if is_action_help_requested(err) {
			return err
		}
		eprintln('Error parsing args: ${err}')
		return 1
	}
	print(result.output)
	eprint(result.errors)
	return result.code
}

fn parse_show_face_options(args []string) !ShowFaceOptions {
	for arg in args {
		request_action_help(arg)!
	}
	mut opts := ShowFaceOptions{}
	cli_args.parse[ShowFaceOptions](mut opts, args)!
	return opts
}

fn derived_font_config(config &configpkg.Config) font.GridSetDerivedConfig {
	return font.GridSetDerivedConfig{
		font_family: config.font_family.clone()
		font_family_bold: config.font_family_bold.clone()
		font_family_italic: config.font_family_italic.clone()
		font_family_bold_italic: config.font_family_bold_italic.clone()
		font_style: config.font_style.clone()
		font_style_bold: config.font_style_bold.clone()
		font_style_italic: config.font_style_italic.clone()
		font_style_bold_italic: config.font_style_bold_italic.clone()
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
