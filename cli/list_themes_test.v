module cli

import configpkg
import os
import vaxis

fn preview_test_theme(name string) ThemeListElement {
	return ThemeListElement{
		theme: name
		path: @FILE
	}
}

fn test_list_themes_tag_layouts_match_source() {
	assert sizeof(ColorScheme) == 1
	assert int(ColorScheme.all) == 0
	assert int(ColorScheme.dark) == 1
	assert int(ColorScheme.light) == 2

	assert sizeof(PreviewMode) == 1
	assert int(PreviewMode.normal) == 0
	assert int(PreviewMode.help) == 1
	assert int(PreviewMode.search) == 2
	assert int(PreviewMode.save) == 3
}

// Test should_include_theme with dark filter
fn test_should_include_theme_dark_filter() {
	mut cfg := configpkg.Config.default_config()

	// Dark background (default: 0,0,0 => luminance ~0.0)
	cfg.background = configpkg.ColorRGB{ r: 0x00, g: 0x00, b: 0x00 }
	assert should_include_theme(.dark, cfg) == true
	assert should_include_theme(.light, cfg) == false
	assert should_include_theme(.all, cfg) == true
}

// Test should_include_theme with light filter
fn test_should_include_theme_light_filter() {
	mut cfg := configpkg.Config.default_config()

	// Light background (255,255,255 => luminance ~1.0)
	cfg.background = configpkg.ColorRGB{ r: 0xff, g: 0xff, b: 0xff }
	assert should_include_theme(.dark, cfg) == false
	assert should_include_theme(.light, cfg) == true
	assert should_include_theme(.all, cfg) == true
}

// Test should_include_theme with mid-range background
fn test_should_include_theme_midrange() {
	mut cfg := configpkg.Config.default_config()

	// Mid-gray (128,128,128 => luminance ~0.502)
	cfg.background = configpkg.ColorRGB{ r: 128, g: 128, b: 128 }
	// luminance = 0.2126*0.502 + 0.7152*0.502 + 0.0722*0.502 ≈ 0.502 > 0.5, so light
	assert should_include_theme(.light, cfg) == true
	assert should_include_theme(.dark, cfg) == false
}

// Test should_include_theme all filter always includes
fn test_should_include_theme_all() {
	mut cfg := configpkg.Config.default_config()

	cfg.background = configpkg.ColorRGB{ r: 0, g: 0, b: 0 }
	assert should_include_theme(.all, cfg) == true

	cfg.background = configpkg.ColorRGB{ r: 255, g: 255, b: 255 }
	assert should_include_theme(.all, cfg) == true

	cfg.background = configpkg.ColorRGB{ r: 100, g: 50, b: 200 }
	assert should_include_theme(.all, cfg) == true
}

// Test ThemeListElement sorting
fn test_theme_list_element_sorting() {
	mut themes := [
		ThemeListElement{ theme: 'Zenburn' },
		ThemeListElement{ theme: 'Dracula' },
		ThemeListElement{ theme: 'ayu' },
		ThemeListElement{ theme: 'Monokai' },
		ThemeListElement{ theme: 'gruvbox' },
	]
	themes.sort_with_compare(theme_list_less_than)

	assert themes[0].theme == 'ayu'
	assert themes[1].theme == 'Dracula'
	assert themes[2].theme == 'gruvbox'
	assert themes[3].theme == 'Monokai'
	assert themes[4].theme == 'Zenburn'
}

// Test ThemeListElement to_uri
fn test_theme_list_element_to_uri() {
	theme := ThemeListElement{
		path: '/home/user/.config/ghostty/themes/Dracula'
		theme: 'Dracula'
	}
	uri := theme.to_uri()
	assert uri == 'file:///home/user/.config/ghostty/themes/Dracula'
	spaced := ThemeListElement{
		path: '/home/user/My Themes/Dracula'
	}.to_uri()
	assert spaced == 'file:///home/user/My%20Themes/Dracula'
}

// Test Preview up/down navigation
fn test_preview_up() {
	mut p := Preview.new([], .all)!
	// Empty list: up does nothing
	p.up(1)
	assert p.current == 0

	// With items
	mut themes := []ThemeListElement{}
	for i in 0 .. 5 {
		themes << preview_test_theme('${i}')
	}
	p = Preview.new(themes, .all)!
	p.current = 3
	p.up(1)
	assert p.current == 2
	p.up(5) // saturating subtraction
	assert p.current == 0
}

fn test_preview_down() {
	mut p := Preview.new([], .all)!
	// Empty list: down does nothing
	p.down(1)
	assert p.current == 0

	// With items
	mut themes := []ThemeListElement{}
	for i in 0 .. 5 {
		themes << preview_test_theme('${i}')
	}
	p = Preview.new(themes, .all)!
	p.down(1)
	assert p.current == 1
	p.down(100) // clamps to last
	assert p.current == 4
}

// Test Preview filter cycling
fn test_preview_filter_cycling() {
	mut themes := [
		preview_test_theme('Test'),
	]
	mut p := Preview.new(themes, .all)!
	assert p.theme_filter == .all

	// Simulate pressing 'f' to cycle
	p.theme_filter = .dark
	assert p.theme_filter == .dark
	p.theme_filter = .light
	assert p.theme_filter == .light
	p.theme_filter = .all
	assert p.theme_filter == .all
}

// Test color_from_palette
fn test_color_from_palette() {
	cfg := configpkg.Config.default_config()
	for index in [0, 1] {
		expected := cfg.palette.value[index]
		actual := color_from_palette(cfg, index)
		assert actual.rgb == [expected.r, expected.g, expected.b]!
	}
}

// Test Options defaults
fn test_options_defaults() {
	opts := Options{}
	assert opts.path == false
	assert opts.plain == false
	assert opts.color == .all
}

fn test_parse_list_themes_options_uses_shared_cli_parser() {
	opts := parse_list_themes_options(['--path', '--plain=false', '--color=dark'])!
	assert opts.path
	assert !opts.plain
	assert opts.color == .dark

	if _ := parse_list_themes_options(['--unknown']) {
		assert false, 'unknown list-themes option must fail'
	}
}

fn test_preview_new_propagates_theme_load_failure() {
	missing := os.join_path(os.temp_dir(), 'witty-missing-theme-${os.getpid()}')
	os.rm(missing) or {}
	if _ := Preview.new([ThemeListElement{
		theme: 'Missing'
		path: missing
	}], .all) {
		assert false, 'missing theme must fail preview initialization'
	}
}

fn test_preview_search_uses_text_input() {
	mut p := Preview.new([
		preview_test_theme('Dracula'),
		preview_test_theme('Gruvbox'),
	], .all)!
	p.mode = .search
	p.update(Event(KeyPressEvent{
		key: vaxis.Key{ codepoint: u32(`d`) }
	}))!
	assert p.search_text == 'd'
	assert p.filtered.len == 1
	assert p.themes[p.filtered[0]].theme == 'Dracula'

	p.update(Event(KeyPressEvent{
		key: vaxis.Key{ codepoint: vaxis.backspace }
	}))!
	assert p.search_text == ''
	assert p.filtered.len == 2
}

fn test_preview_ascii_lowercases_search_tokens_for_zf() {
	mut p := Preview.new([
		preview_test_theme('Dracula'),
		preview_test_theme('ivory'),
	], .all)!
	p.search_text = 'D'
	p.update_filtered()!
	assert p.filtered.len == 1
	assert p.themes[p.filtered[0]].theme == 'Dracula'
	p.search_text = 'd'
	p.update_filtered()!
	assert p.filtered.len == 1
	p.search_text = 'İ'
	p.update_filtered()!
	assert p.filtered.len == 0
}

fn test_preview_mouse_selects_visible_theme() {
	mut p := Preview.new([
		preview_test_theme('One'),
		preview_test_theme('Two'),
		preview_test_theme('Three'),
	], .all)!
	p.winsize = vaxis.Winsize{ rows: 20, cols: 100 }
	p.update(Event(MouseEvent{
		mouse: vaxis.Mouse{
			button: .left
			type_: .release
			row: 2
			col: 5
		}
	}))!
	assert p.current == 2
}

fn test_preview_draws_empty_state() {
	mut p := Preview.new([], .all)!
	p.winsize = vaxis.Winsize{ rows: 12, cols: 80 }
	output := p.draw()
	assert output.contains('No theme found!')
	assert output.contains('\x1b[2J\x1b[H')
}

fn test_preview_draw_renders_theme_load_failure() {
	missing := os.join_path(os.temp_dir(), 'witty-missing-theme-draw-${os.getpid()}')
	os.rm(missing) or {}
	mut p := Preview{
		themes: [ThemeListElement{
			theme: 'Missing'
			path: missing
		}]
		filtered: [0]
		winsize: vaxis.Winsize{ rows: 12, cols: 80 }
		text_input: vaxis.TextInput.new()
	}
	output := p.draw()
	assert output.contains('Unable to open Missing from:')
	assert output.contains(missing)
}
