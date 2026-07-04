module configpkg

import os

fn test_load_file_applies_theme_colors() {
	path := os.join_path(os.temp_dir(), 'witty-theme-test.conf')
	os.write_file(path, '
# comment
palette = 0=#010203
palette = 15=#fdfefd
background = #102030
foreground = #abcdef
')!
	defer {
		os.rm(path) or {}
	}

	mut cfg := Config.default_config()
	cfg.load_file(path)

	assert cfg.diagnostics.len == 0
	assert cfg.background == ColorRGB{
		r: 0x10
		g: 0x20
		b: 0x30
	}
	assert cfg.foreground == ColorRGB{
		r: 0xab
		g: 0xcd
		b: 0xef
	}
	assert cfg.palette.value[0] == ColorRGB{
		r: 1
		g: 2
		b: 3
	}
	assert cfg.palette.value[15] == ColorRGB{
		r: 0xfd
		g: 0xfe
		b: 0xfd
	}
}

fn test_load_file_records_diagnostics_for_invalid_lines() {
	path := os.join_path(os.temp_dir(), 'witty-theme-invalid-test.conf')
	os.write_file(path, '
foreground #ffffff
background = nope
palette = 300=#ffffff
')!
	defer {
		os.rm(path) or {}
	}

	mut cfg := Config.default_config()
	cfg.load_file(path)

	assert cfg.diagnostics.len == 3
}

fn test_preferred_default_file_path_uses_xdg_config_home() {
	old := os.getenv_opt('XDG_CONFIG_HOME')
	os.setenv('XDG_CONFIG_HOME', '/tmp/witty-config-home', true)
	defer {
		if value := old {
			os.setenv('XDG_CONFIG_HOME', value, true)
		} else {
			os.unsetenv('XDG_CONFIG_HOME')
		}
	}

	assert preferred_default_file_path() == os.join_path('/tmp/witty-config-home', 'ghostty',
		'config')
}

// ============================================================
// Translated from ghostty src/config/Config.zig `test "..."` blocks.
// ============================================================

// expect_parse_error asserts that the given error carries the given
// ParseError kind (mirroring Zig's expectError).
fn expect_parse_error(err IError, want ParseError) {
	got := parse_error_of(err) or {
		assert false, 'expected ParseError.${want}, got non-ParseError: ${err}'
		return
	}
	assert got == want, 'expected ParseError.${want}, got ParseError.${got}'
}

// --- Color ---

// Config.zig: Color "fromHex"
fn test_color_from_hex() {
	assert color_from_hex('#000000')! == ColorRGB{0, 0, 0}
	assert color_from_hex('#0A0B0C')! == ColorRGB{10, 11, 12}
	assert color_from_hex('0A0B0C')! == ColorRGB{10, 11, 12}
	assert color_from_hex('FFFFFF')! == ColorRGB{255, 255, 255}
	assert color_from_hex('FFF')! == ColorRGB{255, 255, 255}
	assert color_from_hex('#345')! == ColorRGB{51, 68, 85}
}

// Config.zig: Color "parseCLI from name"
fn test_color_parse_cli_from_name() {
	assert color_parse_cli('black')! == ColorRGB{0, 0, 0}
}

// Config.zig: Color "parseCLI with whitespace"
fn test_color_parse_cli_with_whitespace() {
	assert color_parse_cli(' #AABBCC   ')! == ColorRGB{0xAA, 0xBB, 0xCC}
	assert color_parse_cli('  black ')! == ColorRGB{0, 0, 0}
}

// Config.zig: Color "formatConfig"
fn test_color_format() {
	assert format_color(ColorRGB{10, 11, 12}) == '#0a0b0c'
}

// --- TerminalColor ---

// Config.zig: TerminalColor "parseCLI"
fn test_terminal_color_parse_cli() {
	a := terminal_color_parse_cli('#4e2a84')!
	assert a.kind == .color
	assert a.color == ColorRGB{78, 42, 132}

	b := terminal_color_parse_cli('black')!
	assert b.kind == .color
	assert b.color == ColorRGB{0, 0, 0}

	assert terminal_color_parse_cli('cell-foreground')!.kind == .cell_foreground
	assert terminal_color_parse_cli('cell-background')!.kind == .cell_background

	terminal_color_parse_cli('a') or {
		expect_parse_error(err, .invalid_value)
		return
	}
	assert false, 'expected error for "a"'
}

// --- BoldColor ---

// Config.zig: BoldColor "parseCLI"
fn test_bold_color_parse_cli() {
	a := bold_color_parse_cli('#4e2a84')!
	assert !a.bright
	assert a.color == ColorRGB{78, 42, 132}

	b := bold_color_parse_cli('black')!
	assert !b.bright
	assert b.color == ColorRGB{0, 0, 0}

	assert bold_color_parse_cli('bright')!.bright

	bold_color_parse_cli('a') or {
		expect_parse_error(err, .invalid_value)
		return
	}
	assert false, 'expected error for "a"'
}

// --- Palette ---

// Config.zig: Palette "parseCLI"
fn test_palette_parse_cli() {
	mut p := Palette.default_palette()
	p.parse_cli('0=#AABBCC')!
	assert p.value[0].r == 0xAA
	assert p.value[0].g == 0xBB
	assert p.value[0].b == 0xCC
}

// Config.zig: Palette "parseCLI base"
fn test_palette_parse_cli_base() {
	mut p := Palette.default_palette()
	p.parse_cli('0b1=#014589')!
	p.parse_cli('0o7=#234567')!
	p.parse_cli('0xF=#ABCDEF')!

	assert p.value[1] == ColorRGB{0x01, 0x45, 0x89}
	assert p.value[7] == ColorRGB{0x23, 0x45, 0x67}
	assert p.value[15] == ColorRGB{0xAB, 0xCD, 0xEF}
}

// Config.zig: Palette "parseCLI overflow"
fn test_palette_parse_cli_overflow() {
	mut p := Palette.default_palette()
	p.parse_cli('256=#AABBCC') or {
		expect_parse_error(err, .overflow)
		return
	}
	assert false, 'expected overflow error'
}

// Config.zig: Palette "parseCLI with whitespace"
fn test_palette_parse_cli_with_whitespace() {
	mut p := Palette.default_palette()
	p.parse_cli('0 =  #AABBCC')!
	p.parse_cli(' 1= #DDEEFF    ')!
	p.parse_cli('  2  =  #123456 ')!

	assert p.value[0] == ColorRGB{0xAA, 0xBB, 0xCC}
	assert p.value[1] == ColorRGB{0xDD, 0xEE, 0xFF}
	assert p.value[2] == ColorRGB{0x12, 0x34, 0x56}
}

// --- RepeatableString ---

// Config.zig: RepeatableString "parseCLI"
fn test_repeatable_string_parse_cli() {
	mut list := RepeatableStringList{}
	list.parse_cli('A')!
	list.parse_cli('B')!
	assert list.list.len == 2

	list.parse_cli('')!
	assert list.list.len == 0
}

// Config.zig: RepeatableString "parseCLI overwrite"
fn test_repeatable_string_parse_cli_overwrite() {
	mut list := RepeatableStringList{}
	list.parse_cli('A')!

	list.overwrite_next = true

	list.parse_cli('B')!
	assert list.list.len == 1
	list.parse_cli('C')!
	assert list.list.len == 2
}

// --- Duration ---

// Config.zig: "parse duration"
fn test_parse_duration() {
	// "0<unit>" == 0 for every unit.
	for unit in duration_units {
		d := duration_parse_cli('0${unit.name}')!
		assert d.duration == 0
	}
	// "1<unit>" == unit.factor for every unit.
	for unit in duration_units {
		d := duration_parse_cli('1${unit.name}')!
		assert d.duration == unit.factor
	}

	assert duration_parse_cli('0')!.duration == 0
	assert duration_parse_cli('100ns')!.duration == 100
	assert duration_parse_cli('1µs')!.duration == 1000
	assert duration_parse_cli('1µs1ns')!.duration == 1001
	assert duration_parse_cli('1µs 1ns')!.duration == 1001
	assert duration_parse_cli(' 1µs1ns')!.duration == 1001
	assert duration_parse_cli('1µs1ns ')!.duration == 1001
	assert duration_parse_cli('30s')!.duration == u64(30) * 1_000_000_000
	assert duration_parse_cli('584y 49w 23h 34m 33s 709ms 551µs 615ns')!.duration == u64_max
	// Overflow saturates.
	assert duration_parse_cli('600y')!.duration == u64_max
	// Repeated units accumulate.
	assert duration_parse_cli('100ns100ns')!.duration == 200

	duration_parse_cli(none) or {
		expect_parse_error(err, .value_required)
		duration_parse_cli('') or {
			expect_parse_error(err, .value_required)
			duration_parse_cli('1') or {
				expect_parse_error(err, .invalid_value)
				duration_parse_cli('s') or {
					expect_parse_error(err, .invalid_value)
					duration_parse_cli('1x') or {
						expect_parse_error(err, .invalid_value)
						duration_parse_cli('1 ') or {
							expect_parse_error(err, .invalid_value)
							return
						}
						assert false
						return
					}
					assert false
					return
				}
				assert false
				return
			}
			assert false
			return
		}
		assert false
		return
	}
	assert false, 'expected value_required for null'
}

// Config.zig: "test format" (Duration formatting)
fn test_duration_format() {
	for unit in duration_units {
		d := Duration{
			duration: unit.factor
		}
		expected := if unit.name != 'us' { '1${unit.name}' } else { '1µs' }
		assert d.format() == expected
	}
}

// Config.zig: Duration "test entryFormatter" (max value formatting)
fn test_duration_format_max() {
	d := Duration{
		duration: u64_max
	}
	assert d.format() == '584y 49w 23h 34m 33s 709ms 551µs 615ns'
}

// --- WindowPadding ---

// Config.zig: WindowPadding "parse WindowPadding"
fn test_parse_window_padding() {
	assert window_padding_parse_cli('100')! == WindowPadding{100, 100}
	assert window_padding_parse_cli('100,200')! == WindowPadding{100, 200}
	assert window_padding_parse_cli(' 100 , 200 ')! == WindowPadding{100, 200}

	window_padding_parse_cli(none) or {
		expect_parse_error(err, .value_required)
		window_padding_parse_cli('') or {
			expect_parse_error(err, .invalid_value)
			window_padding_parse_cli('a') or {
				expect_parse_error(err, .invalid_value)
				return
			}
			assert false
			return
		}
		assert false
		return
	}
	assert false, 'expected value_required for null'
}

// --- MouseScrollMultiplier ---

// Config.zig: MouseScrollMultiplier "parse"
fn test_mouse_scroll_multiplier_parse() {
	mut args := MouseScrollMultiplier{
		precision: 0.1
		discrete: 3
	}
	args.parse_cli('3')!
	assert args.precision == 3
	assert args.discrete == 3

	args = MouseScrollMultiplier{
		precision: 0.1
		discrete: 3
	}
	args.parse_cli('precision:1')!
	assert args.precision == 1
	assert args.discrete == 3

	args = MouseScrollMultiplier{
		precision: 0.1
		discrete: 3
	}
	args.parse_cli('discrete:5')!
	assert args.precision == 0.1
	assert args.discrete == 5

	args = MouseScrollMultiplier{
		precision: 0.1
		discrete: 3
	}
	args.parse_cli('precision:3,discrete:7')!
	assert args.precision == 3
	assert args.discrete == 7

	args = MouseScrollMultiplier{
		precision: 0.1
		discrete: 3
	}
	args.parse_cli('discrete:8,precision:6')!
	assert args.precision == 6
	assert args.discrete == 8

	mut e := MouseScrollMultiplier{}
	e.parse_cli('foo:1') or {
		expect_parse_error(err, .invalid_value)
		e.parse_cli('precision:bar') or {
			expect_parse_error(err, .invalid_value)
			e.parse_cli('precision:1,discrete:3,foo:5') or {
				expect_parse_error(err, .invalid_value)
				e.parse_cli('precision:1,,discrete:3') or {
					expect_parse_error(err, .invalid_value)
					e.parse_cli(',precision:1,discrete:3') or {
						expect_parse_error(err, .invalid_value)
						return
					}
					assert false
					return
				}
				assert false
				return
			}
			assert false
			return
		}
		assert false
		return
	}
	assert false, 'expected invalid_value for foo:1'
}

// Config.zig: MouseScrollMultiplier "format entry MouseScrollMultiplier"
fn test_mouse_scroll_multiplier_format() {
	args := MouseScrollMultiplier{
		precision: 1.5
		discrete: 2.5
	}
	assert args.format() == 'precision:1.5,discrete:2.5'
}

// --- QuickTerminalSize ---

// Config.zig: QuickTerminalSize "parse QuickTerminalSize"
fn test_parse_quick_terminal_size() {
	mut v := QuickTerminalSize{}

	v.parse_cli('50%')!
	primary := v.primary or {
		assert false
		return
	}
	assert primary.kind == .percentage
	assert primary.percentage == 50
	assert v.secondary == none

	v = QuickTerminalSize{}
	v.parse_cli('200px')!
	p2 := v.primary or {
		assert false
		return
	}
	assert p2.kind == .pixels
	assert p2.pixels == 200
	assert v.secondary == none

	v = QuickTerminalSize{}
	v.parse_cli('50%,200px')!
	p3 := v.primary or {
		assert false
		return
	}
	s3 := v.secondary or {
		assert false
		return
	}
	assert p3.percentage == 50
	assert s3.pixels == 200

	mut e := QuickTerminalSize{}
	e.parse_cli(none) or {
		expect_parse_error(err, .value_required)
		e.parse_cli('') or {
			expect_parse_error(err, .value_required)
			e.parse_cli('69px,') or {
				expect_parse_error(err, .value_required)
				e.parse_cli('69px,42%,69px') or {
					expect_parse_error(err, .too_many_arguments)
					e.parse_cli('420') or {
						expect_parse_error(err, .missing_unit)
						e.parse_cli('bobr') or {
							expect_parse_error(err, .missing_unit)
							e.parse_cli('bobr%') or {
								expect_parse_error(err, .invalid_value)
								e.parse_cli('-32%') or {
									expect_parse_error(err, .invalid_value)
									e.parse_cli('-69px') or {
										expect_parse_error(err, .invalid_value)
										return
									}
									assert false
									return
								}
								assert false
								return
							}
							assert false
							return
						}
						assert false
						return
					}
					assert false
					return
				}
				assert false
				return
			}
			assert false
			return
		}
		assert false
		return
	}
	assert false, 'expected value_required for null'
}

// Config.zig: QuickTerminalSize "calculate QuickTerminalSize"
fn test_calculate_quick_terminal_size() {
	dims_landscape := QuickTerminalDimensions{
		width: 2560
		height: 1600
	}
	dims_portrait := QuickTerminalDimensions{
		width: 1600
		height: 2560
	}

	size := QuickTerminalSize{}
	assert size.calculate(.top, dims_landscape) == QuickTerminalDimensions{2560, 400}
	assert size.calculate(.left, dims_landscape) == QuickTerminalDimensions{400, 1600}
	// Center on landscape: 800x400
	assert size.calculate(.center, dims_landscape) == QuickTerminalDimensions{800, 400}
	// Center on portrait: 400x800
	assert size.calculate(.center, dims_portrait) == QuickTerminalDimensions{400, 800}
}

// --- BackgroundBlur ---

// Config.zig: BackgroundBlur "parse BackgroundBlur"
fn test_parse_background_blur() {
	assert background_blur_parse_cli(none)!.kind == .bool_true
	assert background_blur_parse_cli('true')!.kind == .bool_true
	assert background_blur_parse_cli('false')!.kind == .bool_false

	r := background_blur_parse_cli('42')!
	assert r.kind == .radius
	assert r.radius == 42

	assert background_blur_parse_cli('macos-glass-regular')!.kind == .macos_glass_regular
	assert background_blur_parse_cli('macos-glass-clear')!.kind == .macos_glass_clear

	background_blur_parse_cli('') or {
		expect_parse_error(err, .invalid_value)
		background_blur_parse_cli('aaaa') or {
			expect_parse_error(err, .invalid_value)
			background_blur_parse_cli('420') or {
				expect_parse_error(err, .invalid_value)
				return
			}
			assert false
			return
		}
		assert false
		return
	}
	assert false, 'expected invalid_value for empty'
}

// --- WindowDecoration ---

// Config.zig: WindowDecoration "parse WindowDecoration"
fn test_parse_window_decoration() {
	assert window_decoration_parse_cli(none)! == .auto
	assert window_decoration_parse_cli('true')! == .auto
	assert window_decoration_parse_cli('false')! == .none_
	assert window_decoration_parse_cli('server')! == .server
	assert window_decoration_parse_cli('client')! == .client
	assert window_decoration_parse_cli('auto')! == .auto
	assert window_decoration_parse_cli('none')! == .none_

	window_decoration_parse_cli('') or {
		expect_parse_error(err, .invalid_value)
		window_decoration_parse_cli('aaaa') or {
			expect_parse_error(err, .invalid_value)
			return
		}
		assert false
		return
	}
	assert false, 'expected invalid_value for empty'
}

// --- Theme ---

// Config.zig: Theme "parse Theme"
fn test_parse_theme() {
	// Single
	single := theme_pair_parse_cli('foo')!
	assert single.light == 'foo'
	assert single.dark == 'foo'

	// Single whitespace
	single_ws := theme_pair_parse_cli('  foo  ')!
	assert single_ws.light == 'foo'
	assert single_ws.dark == 'foo'

	// Light/dark
	pair := theme_pair_parse_cli(' light:foo,  dark : bar  ')!
	assert pair.light == 'foo'
	assert pair.dark == 'bar'

	theme_pair_parse_cli(none) or {
		expect_parse_error(err, .value_required)
		theme_pair_parse_cli('') or {
			expect_parse_error(err, .value_required)
			theme_pair_parse_cli('light:foo') or {
				expect_parse_error(err, .invalid_value)
				theme_pair_parse_cli('dark:foo') or {
					expect_parse_error(err, .invalid_value)
					return
				}
				assert false
				return
			}
			assert false
			return
		}
		assert false
		return
	}
	assert false, 'expected value_required for null'
}

// ============================================================
// Top-level Config tests
// ============================================================

// Config.zig: "handle bom in config files"
fn test_handle_bom_in_config_files() {
	// With a UTF-8 BOM prefix.
	{
		mut cfg := Config.default_config()
		cfg.load_string('\xef\xbb\xbfabnormal-command-exit-runtime = 2500\n')
		cfg.finalize()
		assert cfg.diagnostics.len == 0
		assert cfg.abnormal_command_exit_runtime == 2500
	}
	// Without a BOM prefix.
	{
		mut cfg := Config.default_config()
		cfg.load_string('abnormal-command-exit-runtime = 2500\n')
		cfg.finalize()
		assert cfg.diagnostics.len == 0
		assert cfg.abnormal_command_exit_runtime == 2500
	}
}

// Config.zig: "clone default"
fn test_clone_default() {
	source := Config.default_config()
	dest := source.clone()
	// A cloned default should equal the source on representative fields.
	assert dest.font_size == source.font_size
	assert dest.background == source.background
	assert dest.foreground == source.foreground
	assert dest.term == source.term
	assert dest.abnormal_command_exit_runtime == source.abnormal_command_exit_runtime
}

// Config.zig: "clone preserves conditional state"
fn test_clone_preserves_conditional_state() {
	mut a := Config.default_config()
	a.conditional_state = ConditionalState{
		theme: .dark
	}
	assert a.conditional_state.theme == .dark
	dest := a.clone()
	assert dest.conditional_state.theme == .dark
}

// Config.zig: "changeConditionalState ignores irrelevant changes"
fn test_change_conditional_state_ignores_irrelevant() {
	mut cfg := Config.default_config()
	cfg.load_string('theme = foo\n')
	cfg.finalize()

	// A single (non light/dark) theme is not conditional.
	mut got_none := false
	if _ := cfg.change_conditional_state(ConditionalState{ theme: .dark }) {
		got_none = false
	} else {
		got_none = true
	}
	assert got_none, 'expected none for irrelevant change'
}

// Config.zig: "changeConditionalState applies relevant changes"
fn test_change_conditional_state_applies_relevant() {
	mut cfg := Config.default_config()
	cfg.load_string('theme = light:foo,dark:bar\n')
	cfg.finalize()

	cfg2 := cfg.change_conditional_state(ConditionalState{ theme: .dark }) or {
		assert false, 'expected a config for relevant change'
		return
	}
	assert 'theme' in cfg2.conditional_set
}

// Config.zig: "theme loading"
fn test_theme_loading() {
	dir := os.join_path(os.temp_dir(), 'witty-theme-load-${os.getpid()}')
	os.mkdir_all(dir) or {}
	path := os.join_path(dir, 'theme')
	os.write_file(path, 'background = #123ABC\n')!
	defer {
		os.rmdir_all(dir) or {}
	}

	mut cfg := Config.default_config()
	cfg.load_string('theme = ${path}\n')
	cfg.finalize()

	assert cfg.background == ColorRGB{0x12, 0x3A, 0xBC}
	// Not a conditional theme.
	assert 'theme' !in cfg.conditional_set
}

// Config.zig: "theme priority is lower than config"
fn test_theme_priority_lower_than_config() {
	dir := os.join_path(os.temp_dir(), 'witty-theme-prio-${os.getpid()}')
	os.mkdir_all(dir) or {}
	path := os.join_path(dir, 'theme')
	os.write_file(path, 'background = #123ABC\n')!
	defer {
		os.rmdir_all(dir) or {}
	}

	mut cfg := Config.default_config()
	// Config sets background explicitly; theme must not override it.
	cfg.load_string('background = #ABCDEF\ntheme = ${path}\n')
	cfg.finalize()

	assert cfg.background == ColorRGB{0xAB, 0xCD, 0xEF}
}

// Config.zig: "theme loading correct light/dark"
fn test_theme_loading_correct_light_dark() {
	dir := os.join_path(os.temp_dir(), 'witty-theme-ld-${os.getpid()}')
	os.mkdir_all(dir) or {}
	light := os.join_path(dir, 'theme_light')
	dark := os.join_path(dir, 'theme_dark')
	os.write_file(light, 'background = #FFFFFF\n')!
	os.write_file(dark, 'background = #EEEEEE\n')!
	defer {
		os.rmdir_all(dir) or {}
	}

	theme_line := 'theme = light:${light},dark:${dark}\n'

	// Light
	{
		mut cfg := Config.default_config()
		cfg.load_string(theme_line)
		cfg.finalize()
		assert cfg.background == ColorRGB{0xFF, 0xFF, 0xFF}
	}
	// Dark (via conditional state)
	{
		mut cfg := Config.default_config()
		cfg.conditional_state = ConditionalState{
			theme: .dark
		}
		cfg.load_string(theme_line)
		cfg.finalize()
		assert cfg.background == ColorRGB{0xEE, 0xEE, 0xEE}
	}
	// Light to Dark (via changeConditionalState)
	{
		mut cfg := Config.default_config()
		cfg.load_string(theme_line)
		cfg.finalize()
		newc := cfg.change_conditional_state(ConditionalState{ theme: .dark }) or {
			assert false
			return
		}
		assert newc.background == ColorRGB{0xEE, 0xEE, 0xEE}
	}
}

// Config.zig: "theme specifying light/dark changes window-theme from auto"
fn test_theme_light_dark_changes_window_theme() {
	mut cfg := Config.default_config()
	cfg.load_string('theme = light:foo,dark:bar\nwindow-theme = auto\n')
	cfg.finalize()
	assert cfg.window_theme == .system
}

// Config.zig: "theme specifying light/dark sets theme usage in conditional state"
fn test_theme_light_dark_sets_conditional() {
	mut cfg := Config.default_config()
	cfg.load_string('theme = light:foo,dark:bar\nwindow-theme = auto\n')
	cfg.finalize()
	assert cfg.window_theme == .system
	assert 'theme' in cfg.conditional_set
}

// Config.zig: "compatibility: gtk-single-instance desktop"
fn test_compat_gtk_single_instance_desktop() {
	mut cfg := Config.default_config()
	cfg.load_string('gtk-single-instance = desktop\n')
	// Before finalize, desktop remains detect.
	assert cfg.gtk_single_instance == .detect
}

// Config.zig: "compatibility: removed cursor-invert-fg-bg"
fn test_compat_removed_cursor_invert_fg_bg() {
	mut cfg := Config.default_config()
	cfg.load_string('cursor-invert-fg-bg = true\n')
	cfg.finalize()
	assert cfg.cursor_color? == .cell_foreground
	assert cfg.cursor_text? == .cell_background
}

// Config.zig: "compatibility: removed selection-invert-fg-bg"
fn test_compat_removed_selection_invert_fg_bg() {
	mut cfg := Config.default_config()
	cfg.load_string('selection-invert-fg-bg = true\n')
	cfg.finalize()
	assert cfg.selection_foreground? == .cell_background
	assert cfg.selection_background? == .cell_foreground
}

// Config.zig: "compatibility: removed bold-is-bright"
fn test_compat_removed_bold_is_bright() {
	mut cfg := Config.default_config()
	cfg.load_string('bold-is-bright = true\n')
	cfg.finalize()
	bc := cfg.bold_color or {
		assert false, 'expected bold_color to be set'
		return
	}
	assert bc.bright
}

// Config.zig: "compatibility: window new-window"
fn test_compat_window_new_window() {
	mut cfg := Config.default_config()
	cfg.load_string('macos-dock-drop-behavior = window\n')
	cfg.finalize()
	assert cfg.macos_dock_drop_behavior == .new_window
}

// --- Keybinds ---
// Translations of Config.zig's `Keybinds` tests. Tests that require the config
// formatter subsystem (formatEntry/formatConfig) are omitted because that
// subsystem is not translated in witty.

// Config.zig: Keybinds "parseCLI"
fn test_keybinds_parse_cli() {
	mut set := Keybinds{}
	set.parse_cli('shift+a=copy_to_clipboard')!
	set.parse_cli('shift+a=csi:hello')!
	// Same trigger, so the second overwrites the first.
	assert set.set.bindings.len == 1
}

// Config.zig: Keybinds "parseCLI table definition"
fn test_keybinds_parse_cli_table_definition() {
	mut keybinds := Keybinds{}

	// Define a table by adding a binding to it.
	keybinds.parse_cli('foo/shift+a=copy_to_clipboard')!
	assert keybinds.tables.len == 1
	assert 'foo' in keybinds.tables

	table := keybinds.tables['foo'] or { panic('missing table') }
	assert table.bindings.len == 1
}

// Config.zig: Keybinds "parseCLI table clear"
fn test_keybinds_parse_cli_table_clear() {
	mut keybinds := Keybinds{}

	keybinds.parse_cli('foo/shift+a=copy_to_clipboard')!
	assert keybinds.tables['foo']!.bindings.len == 1

	// Clear the table with "foo/".
	keybinds.parse_cli('foo/')!
	assert keybinds.tables['foo']!.bindings.len == 0
}

// Config.zig: Keybinds "parseCLI table multiple bindings"
fn test_keybinds_parse_cli_table_multiple_bindings() {
	mut keybinds := Keybinds{}

	keybinds.parse_cli('foo/shift+a=copy_to_clipboard')!
	keybinds.parse_cli('foo/shift+b=paste_from_clipboard')!
	keybinds.parse_cli('bar/ctrl+c=close_window')!

	assert keybinds.tables.len == 2
	assert keybinds.tables['foo']!.bindings.len == 2
	assert keybinds.tables['bar']!.bindings.len == 1
}

// Config.zig: Keybinds "parseCLI table does not affect root set"
fn test_keybinds_parse_cli_table_does_not_affect_root_set() {
	mut keybinds := Keybinds{}

	keybinds.parse_cli('shift+a=copy_to_clipboard')!
	keybinds.parse_cli('foo/shift+b=paste_from_clipboard')!

	// Root set should have the first binding.
	assert keybinds.set.bindings.len == 1
	// Table should have the second binding.
	assert keybinds.tables['foo']!.bindings.len == 1
}

// Config.zig: Keybinds "parseCLI table empty name is invalid"
fn test_keybinds_parse_cli_table_empty_name_is_invalid() {
	mut keybinds := Keybinds{}
	keybinds.parse_cli('/shift+a=copy_to_clipboard') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false, 'expected an error'
}

// Config.zig: Keybinds "parseCLI table with key sequence"
fn test_keybinds_parse_cli_table_with_key_sequence() {
	mut keybinds := Keybinds{}

	// Key sequences should work within tables.
	keybinds.parse_cli('foo/ctrl+a>ctrl+b=new_window')!

	table := keybinds.tables['foo'] or { panic('missing table') }
	assert table.bindings.len == 1
}

// Config.zig: Keybinds "parseCLI slash in action argument is not a table"
fn test_keybinds_parse_cli_slash_in_action_argument_is_not_a_table() {
	mut keybinds := Keybinds{}

	// A slash after the = should not be interpreted as a table delimiter.
	keybinds.parse_cli('ctrl+a=text:/hello')!

	// Should be in root set, not a table.
	assert keybinds.set.bindings.len == 1
	assert keybinds.tables.len == 0
}

// Config.zig: Keybinds "parseCLI slash as key with modifier is not a table"
fn test_keybinds_parse_cli_slash_as_key_with_modifier_is_not_a_table() {
	mut keybinds := Keybinds{}

	// ctrl+/ should be parsed as a keybind with '/' as the key, not a table.
	keybinds.parse_cli('ctrl+/=text:foo')!

	assert keybinds.set.bindings.len == 1
	assert keybinds.tables.len == 0
}

// Config.zig: Keybinds "parseCLI shift+slash as key is not a table"
fn test_keybinds_parse_cli_shift_slash_as_key_is_not_a_table() {
	mut keybinds := Keybinds{}

	// shift+/ should be parsed as a keybind, not a table.
	keybinds.parse_cli('shift+/=ignore')!

	assert keybinds.set.bindings.len == 1
	assert keybinds.tables.len == 0
}

// Config.zig: Keybinds "parseCLI bare slash as key is not a table"
fn test_keybinds_parse_cli_bare_slash_as_key_is_not_a_table() {
	mut keybinds := Keybinds{}

	// Bare / as a key should work (empty table name is rejected).
	keybinds.parse_cli('/=text:foo')!

	assert keybinds.set.bindings.len == 1
	assert keybinds.tables.len == 0
}

// Config.zig: Keybinds "parseCLI slash in key sequence is not a table"
fn test_keybinds_parse_cli_slash_in_key_sequence_is_not_a_table() {
	mut keybinds := Keybinds{}

	// Key sequence ending with / should work.
	keybinds.parse_cli('ctrl+a>ctrl+/=new_window')!

	assert keybinds.set.bindings.len == 1
	assert keybinds.tables.len == 0
}

// Config.zig: Keybinds "parseCLI table with slash in binding"
fn test_keybinds_parse_cli_table_with_slash_in_binding() {
	mut keybinds := Keybinds{}

	// Table with a binding that uses / as the key.
	keybinds.parse_cli('mytable//=text:foo')!

	assert keybinds.set.bindings.len == 0
	assert keybinds.tables.len == 1
	assert 'mytable' in keybinds.tables
	assert keybinds.tables['mytable']!.bindings.len == 1
}

// Config.zig: Keybinds "parseCLI table with sequence containing slash"
fn test_keybinds_parse_cli_table_with_sequence_containing_slash() {
	mut keybinds := Keybinds{}

	// Table with a key sequence that ends with /.
	keybinds.parse_cli('mytable/a>/=new_window')!

	assert keybinds.set.bindings.len == 0
	assert keybinds.tables.len == 1
	assert 'mytable' in keybinds.tables
}

// Config.zig: Keybinds "clone with tables"
fn test_keybinds_clone_with_tables() {
	mut keybinds := Keybinds{}
	keybinds.parse_cli('shift+a=copy_to_clipboard')!
	keybinds.parse_cli('foo/shift+b=paste_from_clipboard')!
	keybinds.parse_cli('bar/ctrl+c=close_window')!

	cloned := keybinds.clone()

	// Verify the clone has the same structure.
	assert cloned.set.bindings.len == keybinds.set.bindings.len
	assert cloned.tables.len == keybinds.tables.len
	assert cloned.tables['foo']!.bindings.len == keybinds.tables['foo']!.bindings.len
	assert cloned.tables['bar']!.bindings.len == keybinds.tables['bar']!.bindings.len
}

// Config.zig: Keybinds "equal with tables"
fn test_keybinds_equal_with_tables() {
	mut keybinds1 := Keybinds{}
	keybinds1.parse_cli('foo/shift+a=copy_to_clipboard')!

	mut keybinds2 := Keybinds{}
	keybinds2.parse_cli('foo/shift+a=copy_to_clipboard')!

	assert keybinds1.equal(keybinds2)
}

// Config.zig: Keybinds "equal with tables different table count"
fn test_keybinds_equal_with_tables_different_table_count() {
	mut keybinds1 := Keybinds{}
	keybinds1.parse_cli('foo/shift+a=copy_to_clipboard')!

	mut keybinds2 := Keybinds{}
	keybinds2.parse_cli('foo/shift+a=copy_to_clipboard')!
	keybinds2.parse_cli('bar/shift+b=paste_from_clipboard')!

	assert !keybinds1.equal(keybinds2)
}

// Config.zig: Keybinds "equal with tables different table names"
fn test_keybinds_equal_with_tables_different_table_names() {
	mut keybinds1 := Keybinds{}
	keybinds1.parse_cli('foo/shift+a=copy_to_clipboard')!

	mut keybinds2 := Keybinds{}
	keybinds2.parse_cli('bar/shift+a=copy_to_clipboard')!

	assert !keybinds1.equal(keybinds2)
}

// Config.zig: Keybinds "equal with tables different bindings"
fn test_keybinds_equal_with_tables_different_bindings() {
	mut keybinds1 := Keybinds{}
	keybinds1.parse_cli('foo/shift+a=copy_to_clipboard')!

	mut keybinds2 := Keybinds{}
	keybinds2.parse_cli('foo/shift+b=paste_from_clipboard')!

	assert !keybinds1.equal(keybinds2)
}

// Config.zig: Keybinds "parseCLI clear clears tables"
fn test_keybinds_parse_cli_clear_clears_tables() {
	mut keybinds := Keybinds{}

	// Add bindings to root set and tables.
	keybinds.parse_cli('shift+a=copy_to_clipboard')!
	keybinds.parse_cli('foo/shift+b=paste_from_clipboard')!
	keybinds.parse_cli('bar/ctrl+c=close_window')!

	assert keybinds.set.bindings.len == 1
	assert keybinds.tables.len == 2

	// Clear all keybinds.
	keybinds.parse_cli('clear')!

	// Both root set and tables should be cleared.
	assert keybinds.set.bindings.len == 0
	assert keybinds.tables.len == 0
}

// Config.zig: Keybinds "parseCLI reset clears tables"
fn test_keybinds_parse_cli_reset_clears_tables() {
	mut keybinds := Keybinds{}

	// Add bindings to tables.
	keybinds.parse_cli('foo/shift+a=copy_to_clipboard')!
	keybinds.parse_cli('bar/shift+b=paste_from_clipboard')!

	assert keybinds.tables.len == 2

	// Reset to defaults (empty value).
	keybinds.parse_cli('')!

	// Tables should be cleared, root set has defaults.
	assert keybinds.tables.len == 0
	assert keybinds.set.bindings.len > 0
}

// Verify config defaults match ghostty's src/config/Config.zig declared defaults.
fn test_default_values_match_ghostty() {
	mut cfg := Config.default_config()

	// background: Color = .{ .r = 0x28, .g = 0x2C, .b = 0x34 }
	assert cfg.background == ColorRGB{
		r: 0x28
		g: 0x2C
		b: 0x34
	}
	// foreground: Color = .{ .r = 0xFF, .g = 0xFF, .b = 0xFF }
	assert cfg.foreground == ColorRGB{
		r: 0xFF
		g: 0xFF
		b: 0xFF
	}
	// term: []const u8 = "xterm-ghostty"
	assert cfg.term == 'xterm-ghostty'
	// @"title-report": bool = false
	assert cfg.title_report == false
	// @"mouse-hide-while-typing": bool = false
	assert cfg.mouse_hide_while_typing == false
	// @"selection-clear-on-copy": bool = false
	assert cfg.selection_clear_on_copy == false
	// @"selection-clear-on-typing": bool = true
	assert cfg.selection_clear_on_typing == true
	// @"cursor-click-to-move": bool = true
	assert cfg.cursor_click_to_move == true
	// @"clipboard-trim-trailing-spaces": bool = true
	assert cfg.clipboard_trim_trailing_spaces == true
	// @"font-thicken-strength": u8 = 255
	assert cfg.font_thicken_strength == 255
	// @"minimum-contrast": f64 = 1
	assert cfg.minimum_contrast == 1.0

	// Empty term falls back to xterm-ghostty in finalize.
	mut cfg2 := Config.default_config()
	cfg2.term = ''
	cfg2.finalize()
	assert cfg2.term == 'xterm-ghostty'
}
