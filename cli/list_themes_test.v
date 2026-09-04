module cli

import configpkg
import vaxis

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
	mut p := Preview.new([], .all)
	// Empty list: up does nothing
	p.up(1)
	assert p.current == 0

	// With items
	mut themes := []ThemeListElement{}
	for i in 0 .. 5 {
		themes << ThemeListElement{ theme: '${i}' }
	}
	p = Preview.new(themes, .all)
	p.current = 3
	p.up(1)
	assert p.current == 2
	p.up(5) // saturating subtraction
	assert p.current == 0
}

fn test_preview_down() {
	mut p := Preview.new([], .all)
	// Empty list: down does nothing
	p.down(1)
	assert p.current == 0

	// With items
	mut themes := []ThemeListElement{}
	for i in 0 .. 5 {
		themes << ThemeListElement{ theme: '${i}' }
	}
	p = Preview.new(themes, .all)
	p.down(1)
	assert p.current == 1
	p.down(100) // clamps to last
	assert p.current == 4
}

// Test Preview filter cycling
fn test_preview_filter_cycling() {
	mut themes := [
		ThemeListElement{ theme: 'Test' },
	]
	mut p := Preview.new(themes, .all)
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
	// Index 0 in default palette is black (0x00, 0x00, 0x00)
	c := color_from_palette(cfg, 0)
	assert c.rgb[0] == 0x00
	assert c.rgb[1] == 0x00
	assert c.rgb[2] == 0x00

	// Index 1 should be red-ish (0xaa, 0x00, 0x00)
	c1 := color_from_palette(cfg, 1)
	assert c1.rgb[0] == 0xaa
	assert c1.rgb[1] == 0x00
	assert c1.rgb[2] == 0x00
}

// Test Options defaults
fn test_options_defaults() {
	opts := Options{}
	assert opts.path == false
	assert opts.plain == false
	assert opts.color == .all
}

fn test_preview_search_uses_text_input() {
	mut p := Preview.new([
		ThemeListElement{ theme: 'Dracula' },
		ThemeListElement{ theme: 'Gruvbox' },
	], .all)
	p.mode = .search
	p.update(Event(KeyPressEvent{
		key: vaxis.Key{ codepoint: u32(`d`) }
	}))
	assert p.search_text == 'd'
	assert p.filtered.len == 1
	assert p.themes[p.filtered[0]].theme == 'Dracula'

	p.update(Event(KeyPressEvent{
		key: vaxis.Key{ codepoint: vaxis.backspace }
	}))
	assert p.search_text == ''
	assert p.filtered.len == 2
}

fn test_preview_mouse_selects_visible_theme() {
	mut p := Preview.new([
		ThemeListElement{ theme: 'One' },
		ThemeListElement{ theme: 'Two' },
		ThemeListElement{ theme: 'Three' },
	], .all)
	p.winsize = vaxis.Winsize{ rows: 20, cols: 100 }
	p.update(Event(MouseEvent{
		mouse: vaxis.Mouse{
			button: .left
			type_: .release
			row: 2
			col: 5
		}
	}))
	assert p.current == 2
}

fn test_preview_draws_empty_state() {
	mut p := Preview.new([], .all)
	p.winsize = vaxis.Winsize{ rows: 12, cols: 80 }
	output := p.draw()
	assert output.contains('No theme found!')
	assert output.contains('\x1b[2J\x1b[H')
}
