module configpkg

import os
import input
import terminal

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

fn test_load_cli_args_applies_flags_paths_and_command_tail() {
	mut cfg := Config.default_config()
	cfg.font_family = ['From File']
	cfg.load_cli_args([
		'--font-family=From CLI',
		'--window-vsync=false',
		'--custom-shader=shader.glsl',
		'-e',
		'/bin/echo',
		'hello world',
	])

	assert cfg.font_family == ['From CLI']
	assert !cfg.window_vsync
	assert cfg.custom_shader.items == [
		Path{ path: os.join_path(os.getwd(), 'shader.glsl') },
	]
	command := cfg.initial_command or { panic('missing -e command') }
	match command {
		DirectCmd {
			assert command.direct == ['/bin/echo', 'hello world']
		}
		ShellCmd {
			assert false, '-e must produce a direct command'
		}
	}
	assert cfg.gtk_single_instance == .false_
	assert cfg.quit_after_last_window_closed
}

fn test_load_args_cli_can_discard_default_files_and_add_recursive_file() {
	dir := os.join_path(os.temp_dir(), 'witty-config-cli-${os.getpid()}')
	xdg_dir := os.join_path(dir, 'ghostty')
	os.rmdir_all(dir) or {}
	os.mkdir_all(xdg_dir)!
	defer { os.rmdir_all(dir) or {} }
	old_xdg := os.getenv_opt('XDG_CONFIG_HOME')
	os.setenv('XDG_CONFIG_HOME', dir, true)
	defer {
		if value := old_xdg {
			os.setenv('XDG_CONFIG_HOME', value, true)
		} else {
			os.unsetenv('XDG_CONFIG_HOME')
		}
	}
	os.write_file(os.join_path(xdg_dir, 'config.ghostty'), 'font-size = 9\n')!
	extra := os.join_path(dir, 'extra.conf')
	os.write_file(extra, 'cursor-opacity = 0.25\n')!

	cfg := Config.load_args([
		'--config-default-files=false',
		'--font-size=17',
		'--config-file=${extra}',
	])
	assert cfg.font_size == 17
	assert cfg.cursor_opacity == 0.25
	assert !cfg.config_default_files
	assert cfg.diagnostics.len == 0
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

fn test_preferred_default_file_path_uses_platform_location() {
	old := os.getenv_opt('XDG_CONFIG_HOME')
	os.setenv('XDG_CONFIG_HOME', '/tmp/witty-config-home', true)
	defer {
		if value := old {
			os.setenv('XDG_CONFIG_HOME', value, true)
		} else {
			os.unsetenv('XDG_CONFIG_HOME')
		}
	}

	expected := $if macos { app_support_config_path('config.ghostty') } $else { os.join_path('/tmp/witty-config-home', 'ghostty', 'config.ghostty') }
	assert preferred_default_file_path() == expected
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

fn test_duration_as_milliseconds_saturates() {
	assert Duration{ duration: 999_999 }.as_milliseconds() == 0
	assert Duration{ duration: 1_500_000 }.as_milliseconds() == 1
	assert Duration{ duration: u64_max }.as_milliseconds() == u32(0xffff_ffff)
}

fn test_duration_round_and_lte() {
	assert Duration{ duration: 1_999_999 }.round(1_000_000) == Duration{
		duration: 1_000_000
	}
	assert Duration{ duration: 5 }.lte(Duration{ duration: 5 })
	assert Duration{ duration: 4 }.lte(Duration{ duration: 5 })
	assert !Duration{ duration: 6 }.lte(Duration{ duration: 5 })
}

fn test_quit_after_last_window_closed_delay_parse_and_format() {
	mut cfg := Config.default_config()
	assert cfg.quit_after_last_window_closed == default_quit_after_last_window_closed
	assert cfg.quit_after_last_window_closed_delay == none
	cfg.load_string('quit-after-last-window-closed-delay = 1s500ms')
	delay := cfg.quit_after_last_window_closed_delay or {
		assert false, 'expected quit delay'
		return
	}
	assert delay.duration == 1_500_000_000
	assert cfg.format_config(true).contains('quit-after-last-window-closed-delay = 1s 500ms\n')

	cfg.load_string('quit-after-last-window-closed-delay =')
	assert cfg.quit_after_last_window_closed_delay == none
	cfg.load_string('quit-after-last-window-closed-delay = soon')
	assert cfg.diagnostics.len == 1
}

fn test_resize_overlay_defaults_parse_and_format() {
	mut cfg := Config.default_config()
	assert cfg.resize_overlay == .after_first
	assert cfg.resize_overlay_position == .center
	assert cfg.resize_overlay_duration.duration == 750_000_000

	cfg.load_string('resize-overlay = always\nresize-overlay-position = bottom-right\nresize-overlay-duration = 1s250ms')
	assert cfg.diagnostics.len == 0
	assert cfg.resize_overlay == .always
	assert cfg.resize_overlay_position == .bottom_right
	assert cfg.resize_overlay_duration.duration == 1_250_000_000
	formatted := cfg.format_config(true)
	assert formatted.contains('resize-overlay = always\n')
	assert formatted.contains('resize-overlay-position = bottom-right\n')
	assert formatted.contains('resize-overlay-duration = 1s 250ms\n')

	cfg.load_string('resize-overlay = sometimes\nresize-overlay-position = middle\nresize-overlay-duration = soon')
	assert cfg.diagnostics.len == 3
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

fn test_background_blur_cval() {
	assert BackgroundBlur{ kind: .bool_false }.cval() == 0
	assert BackgroundBlur{ kind: .bool_true }.cval() == 20
	assert BackgroundBlur{ kind: .radius, radius: 37 }.cval() == 37
	assert BackgroundBlur{ kind: .radius, radius: 255 }.cval() == 255
	assert BackgroundBlur{ kind: .macos_glass_regular }.cval() == -1
	assert BackgroundBlur{ kind: .macos_glass_clear }.cval() == -2
}

fn test_repeatable_command_parse_clear_clone_and_format() {
	mut defaults := Config.default_config()
	assert defaults.command_palette_entry.items.len == input.command_defaults.len
	defaults.load_string('command-palette-entry =\ncommand-palette-entry = title:Only,action:ignore\n')
	assert defaults.command_palette_entry.items.len == 1
	assert defaults.command_palette_entry.items[0].title == 'Only'

	mut commands := RepeatableCommand{}
	commands.parse_cli('title:Foo,action:ignore')!
	commands.parse_cli('title:"Bar, Baz",description:"line\\ntext",action:"text:hello, world"')!
	assert commands.items.len == 2
	assert commands.items[0].title == 'Foo'
	assert commands.items[0].action.tag == .ignore
	assert commands.items[1].title == 'Bar, Baz'
	assert commands.items[1].description == 'line\ntext'
	assert commands.items[1].action.tag == .text
	assert commands.items[1].action.str_param == 'hello, world'

	clone := commands.clone()
	assert clone.equal(commands)

	mut cfg := Config{}
	cfg.command_palette_entry = commands
	formatted := cfg.format_config(false)
	assert formatted.contains('command-palette-entry = title:"Foo",action:"ignore"\n')
	assert formatted.contains('command-palette-entry = title:"Bar, Baz",description:"line\\ntext",action:"text:hello, world"\n')

	mut roundtrip := Config{}
	roundtrip.load_string(formatted)
	assert roundtrip.command_palette_entry.equal(cfg.command_palette_entry)

	commands.parse_cli('')!
	assert commands.items.len == 0
}

fn test_repeatable_command_rejects_missing_and_invalid_fields() {
	mut commands := RepeatableCommand{}
	commands.parse_cli('title:Foo') or {
		commands.parse_cli('action:ignore') or {
			commands.parse_cli('title:Foo,unknown:x,action:ignore') or {
				commands.parse_cli('title:Foo,action:not_an_action') or { return }
			}
		}
	}
	assert false, 'expected invalid command palette entries'
}

fn test_gtk_window_config_parse_format_and_defaults() {
	mut cfg := Config.default_config()
	assert cfg.window_new_tab_position == .current
	assert cfg.window_show_tab_bar == .auto
	assert cfg.window_subtitle == .false_
	assert cfg.gtk_opengl_debug == default_gtk_opengl_debug
	assert cfg.gtk_titlebar
	assert cfg.gtk_tabs_location == .top
	assert !cfg.gtk_titlebar_hide_when_maximized
	assert cfg.gtk_toolbar_style == .raised
	assert cfg.gtk_titlebar_style == .native
	assert cfg.gtk_wide_tabs
	assert cfg.quick_terminal_position == .top
	assert cfg.quick_terminal_size.primary == none
	assert cfg.gtk_quick_terminal_layer == .top
	assert cfg.gtk_quick_terminal_namespace == 'ghostty-quick-terminal'
	assert cfg.quick_terminal_screen == .main
	assert cfg.quick_terminal_animation_duration == 0.2
	assert cfg.quick_terminal_autohide == default_quick_terminal_autohide
	assert cfg.quick_terminal_space_behavior == .move
	assert cfg.quick_terminal_keyboard_interactivity == .on_demand

	gtk_debug_value := if default_gtk_opengl_debug { 'false' } else { 'true' }
	quick_autohide_value := if default_quick_terminal_autohide { 'false' } else { 'true' }
	cfg.load_string('window-new-tab-position = end
window-show-tab-bar = never
window-subtitle = working-directory
quick-terminal-position = right
quick-terminal-size = 50%,320px
gtk-quick-terminal-layer = overlay
gtk-quick-terminal-namespace = dev.ghostty.quick
quick-terminal-screen = macos-menu-bar
quick-terminal-animation-duration = 0.35
quick-terminal-autohide = ${quick_autohide_value}
quick-terminal-space-behavior = remain
quick-terminal-keyboard-interactivity = exclusive
gtk-opengl-debug = ${gtk_debug_value}
gtk-titlebar = false
gtk-tabs-location = bottom
gtk-titlebar-hide-when-maximized = true
gtk-toolbar-style = raised-border
gtk-titlebar-style = tabs
gtk-wide-tabs = false')
	assert cfg.diagnostics.len == 0
	assert cfg.window_new_tab_position == .end
	assert cfg.window_show_tab_bar == .never
	assert cfg.window_subtitle == .working_directory
	assert cfg.quick_terminal_position == .right
	quick_primary := cfg.quick_terminal_size.primary or {
		assert false
		return
	}
	quick_secondary := cfg.quick_terminal_size.secondary or {
		assert false
		return
	}
	assert quick_primary.kind == .percentage
	assert quick_primary.percentage == 50
	assert quick_secondary.kind == .pixels
	assert quick_secondary.pixels == 320
	assert cfg.gtk_quick_terminal_layer == .overlay
	assert cfg.gtk_quick_terminal_namespace == 'dev.ghostty.quick'
	assert cfg.quick_terminal_screen == .macos_menu_bar
	assert cfg.quick_terminal_animation_duration == 0.35
	assert cfg.quick_terminal_autohide == !default_quick_terminal_autohide
	assert cfg.quick_terminal_space_behavior == .remain
	assert cfg.quick_terminal_keyboard_interactivity == .exclusive
	assert cfg.gtk_opengl_debug == !default_gtk_opengl_debug
	assert !cfg.gtk_titlebar
	assert cfg.gtk_tabs_location == .bottom
	assert cfg.gtk_titlebar_hide_when_maximized
	assert cfg.gtk_toolbar_style == .raised_border
	assert cfg.gtk_titlebar_style == .tabs
	assert !cfg.gtk_wide_tabs

	formatted := cfg.format_config(true)
	assert formatted.contains('window-new-tab-position = end\n')
	assert formatted.contains('window-show-tab-bar = never\n')
	assert formatted.contains('window-subtitle = working-directory\n')
	assert formatted.contains('quick-terminal-position = right\n')
	assert formatted.contains('quick-terminal-size = 50%,320px\n')
	assert formatted.contains('gtk-quick-terminal-layer = overlay\n')
	assert formatted.contains('gtk-quick-terminal-namespace = dev.ghostty.quick\n')
	assert formatted.contains('quick-terminal-screen = macos-menu-bar\n')
	assert formatted.contains('quick-terminal-animation-duration = 0.35\n')
	assert formatted.contains('quick-terminal-autohide = ${quick_autohide_value}\n')
	assert formatted.contains('quick-terminal-space-behavior = remain\n')
	assert formatted.contains('quick-terminal-keyboard-interactivity = exclusive\n')
	assert formatted.contains('gtk-opengl-debug = ${gtk_debug_value}\n')
	assert formatted.contains('gtk-titlebar = false\n')
	assert formatted.contains('gtk-tabs-location = bottom\n')
	assert formatted.contains('gtk-titlebar-hide-when-maximized = true\n')
	assert formatted.contains('gtk-toolbar-style = raised-border\n')
	assert formatted.contains('gtk-titlebar-style = tabs\n')
	assert formatted.contains('gtk-wide-tabs = false\n')

	mut roundtrip := Config.default_config()
	roundtrip.load_string(formatted)
	assert roundtrip.window_new_tab_position == cfg.window_new_tab_position
	assert roundtrip.window_show_tab_bar == cfg.window_show_tab_bar
	assert roundtrip.window_subtitle == cfg.window_subtitle
	assert roundtrip.quick_terminal_position == cfg.quick_terminal_position
	roundtrip_primary := roundtrip.quick_terminal_size.primary or {
		assert false
		return
	}
	roundtrip_secondary := roundtrip.quick_terminal_size.secondary or {
		assert false
		return
	}
	assert roundtrip_primary == quick_primary
	assert roundtrip_secondary == quick_secondary
	assert roundtrip.gtk_quick_terminal_layer == cfg.gtk_quick_terminal_layer
	assert roundtrip.gtk_quick_terminal_namespace == cfg.gtk_quick_terminal_namespace
	assert roundtrip.quick_terminal_screen == cfg.quick_terminal_screen
	assert roundtrip.quick_terminal_animation_duration == cfg.quick_terminal_animation_duration
	assert roundtrip.quick_terminal_autohide == cfg.quick_terminal_autohide
	assert roundtrip.quick_terminal_space_behavior == cfg.quick_terminal_space_behavior
	assert roundtrip.quick_terminal_keyboard_interactivity == cfg.quick_terminal_keyboard_interactivity
	assert roundtrip.gtk_opengl_debug == cfg.gtk_opengl_debug
	assert roundtrip.gtk_titlebar == cfg.gtk_titlebar
	assert roundtrip.gtk_tabs_location == cfg.gtk_tabs_location
	assert roundtrip.gtk_titlebar_hide_when_maximized == cfg.gtk_titlebar_hide_when_maximized
	assert roundtrip.gtk_toolbar_style == cfg.gtk_toolbar_style
	assert roundtrip.gtk_titlebar_style == cfg.gtk_titlebar_style
	assert roundtrip.gtk_wide_tabs == cfg.gtk_wide_tabs
}

fn test_gtk_window_config_rejects_invalid_enum() {
	mut cfg := Config.default_config()
	cfg.load_string('gtk-toolbar-style = floating')
	assert cfg.diagnostics.len == 1
}

fn test_linux_cgroup_config_parse_format_and_defaults() {
	mut cfg := Config.default_config()
	assert cfg.linux_cgroup == default_linux_cgroup
	assert cfg.linux_cgroup_memory_limit == none
	assert cfg.linux_cgroup_processes_limit == none
	assert !cfg.linux_cgroup_hard_fail

	cfg.load_string('linux-cgroup = always
linux-cgroup-memory-limit = 1048576
linux-cgroup-processes-limit = 256
linux-cgroup-hard-fail = true')
	assert cfg.diagnostics.len == 0
	assert cfg.linux_cgroup == .always
	assert cfg.linux_cgroup_memory_limit or { 0 } == 1_048_576
	assert cfg.linux_cgroup_processes_limit or { 0 } == 256
	assert cfg.linux_cgroup_hard_fail
	formatted := cfg.format_config(true)
	assert formatted.contains('linux-cgroup = always\n')
	assert formatted.contains('linux-cgroup-memory-limit = 1048576\n')
	assert formatted.contains('linux-cgroup-processes-limit = 256\n')
	assert formatted.contains('linux-cgroup-hard-fail = true\n')

	cfg.load_string('linux-cgroup-memory-limit =\nlinux-cgroup-processes-limit =')
	assert cfg.linux_cgroup_memory_limit == none
	assert cfg.linux_cgroup_processes_limit == none
	cfg.load_string('linux-cgroup = sometimes')
	assert cfg.diagnostics.len == 1
}

fn test_editable_config_path_creates_file_without_truncating() ! {
	dir := os.join_path(os.temp_dir(), 'witty-edit-config-${os.getpid()}')
	os.rmdir_all(dir) or {}
	defer {
		os.rmdir_all(dir) or {}
	}
	path := os.join_path(dir, 'ghostty', 'config.ghostty')
	ensure_editable_config_path(path)!
	assert os.is_file(path)
	os.write_file(path, 'keep me')!
	ensure_editable_config_path(path)!
	assert os.read_file(path)! == 'keep me'
}

fn test_bell_features_parse_format_and_defaults() {
	mut cfg := Config.default_config()
	assert !cfg.bell_features.system
	assert !cfg.bell_features.audio
	assert cfg.bell_features.attention
	assert cfg.bell_features.title
	assert !cfg.bell_features.border

	cfg.load_string('bell-features = audio,no-attention,no-title,border')
	assert cfg.diagnostics.len == 0
	assert !cfg.bell_features.system
	assert cfg.bell_features.audio
	assert !cfg.bell_features.attention
	assert !cfg.bell_features.title
	assert cfg.bell_features.border
	assert cfg.format_config(true).contains('bell-features = no-system,audio,no-attention,no-title,border\n')

	cfg.load_string('bell-features = true')
	assert cfg.bell_features.system
	assert cfg.bell_features.audio
	assert cfg.bell_features.attention
	assert cfg.bell_features.title
	assert cfg.bell_features.border

	cfg.load_string('bell-features = sparkle')
	assert cfg.diagnostics.len == 1
}

fn test_bell_audio_parse_format_and_path_expansion() {
	mut cfg := Config.default_config()
	assert cfg.bell_audio_path == none
	assert cfg.bell_audio_volume == 0.5
	cfg.load_string('bell-audio-path = ?sounds/bell.oga\nbell-audio-volume = 0.75')
	assert cfg.diagnostics.len == 0
	assert cfg.bell_audio_path? == Path{ path: 'sounds/bell.oga', optional: true }
	assert cfg.bell_audio_volume == 0.75
	cfg.expand_paths('/tmp/witty-config')
	assert cfg.bell_audio_path? == Path{
		path: '/tmp/witty-config/sounds/bell.oga'
		optional: true
	}
	formatted := cfg.format_config(true)
	assert formatted.contains('bell-audio-path = ?/tmp/witty-config/sounds/bell.oga\n')
	assert formatted.contains('bell-audio-volume = 0.75\n')

	cfg.load_string('bell-audio-path =\nbell-audio-volume = loud')
	assert cfg.bell_audio_path == none
	assert cfg.diagnostics.len == 1
}

fn test_gtk_css_config_parse_format_clone_and_clear() {
	mut cfg := Config.default_config()
	cfg.load_string('window-title-font-family = Cantarell\nwindow-titlebar-background = #123456\nwindow-titlebar-foreground = aliceblue\ngtk-custom-css = one.css\ngtk-custom-css = ?optional.css')
	assert cfg.diagnostics.len == 0
	assert cfg.window_title_font_family? == 'Cantarell'
	assert cfg.window_titlebar_background? == ColorRGB{18, 52, 86}
	assert cfg.window_titlebar_foreground? == ColorRGB{240, 248, 255}
	assert cfg.gtk_custom_css.items == [
		Path{ path: 'one.css' },
		Path{ path: 'optional.css', optional: true },
	]

	cloned := cfg.clone()
	assert cloned.gtk_custom_css.equal(&cfg.gtk_custom_css)
	formatted := cfg.format_config(true)
	assert formatted.contains('window-title-font-family = Cantarell\n')
	assert formatted.contains('window-titlebar-background = #123456\n')
	assert formatted.contains('window-titlebar-foreground = #f0f8ff\n')
	assert formatted.contains('gtk-custom-css = one.css\n')
	assert formatted.contains('gtk-custom-css = ?optional.css\n')

	cfg.load_string('window-title-font-family =\nwindow-titlebar-background =\nwindow-titlebar-foreground =\ngtk-custom-css =')
	assert cfg.window_title_font_family == none
	assert cfg.window_titlebar_background == none
	assert cfg.window_titlebar_foreground == none
	assert cfg.gtk_custom_css.items.len == 0
}

fn test_app_notifications_parse_format_and_defaults() {
	mut cfg := Config.default_config()
	assert cfg.app_notifications.clipboard_copy
	assert cfg.app_notifications.config_reload

	cfg.load_string('app-notifications = no-clipboard-copy,config-reload')
	assert cfg.diagnostics.len == 0
	assert !cfg.app_notifications.clipboard_copy
	assert cfg.app_notifications.config_reload
	assert cfg.format_config(true).contains('app-notifications = no-clipboard-copy,config-reload\n')

	cfg.load_string('app-notifications = false')
	assert !cfg.app_notifications.clipboard_copy
	assert !cfg.app_notifications.config_reload

	cfg.load_string('app-notifications = true')
	assert cfg.app_notifications.clipboard_copy
	assert cfg.app_notifications.config_reload

	cfg.load_string('app-notifications = sparkle')
	assert cfg.diagnostics.len == 1
}

fn test_notify_on_command_finish_action_and_after() {
	mut cfg := Config.default_config()
	assert cfg.notify_on_command_finish == .never
	assert cfg.notify_on_command_finish_action.bell
	assert !cfg.notify_on_command_finish_action.notify
	assert cfg.notify_on_command_finish_after == Duration{ duration: 5_000_000_000 }

	cfg.load_string('notify-on-command-finish = unfocused\nnotify-on-command-finish-action = no-bell,notify\nnotify-on-command-finish-after = 1m 250ms')
	assert cfg.diagnostics.len == 0
	assert cfg.notify_on_command_finish == .unfocused
	assert !cfg.notify_on_command_finish_action.bell
	assert cfg.notify_on_command_finish_action.notify
	assert cfg.notify_on_command_finish_after == Duration{ duration: 60_250_000_000 }
	formatted := cfg.format_config(true)
	assert formatted.contains('notify-on-command-finish-action = no-bell,notify\n')
	assert formatted.contains('notify-on-command-finish-after = 1m 250ms\n')

	cfg.load_string('notify-on-command-finish-action = false')
	assert !cfg.notify_on_command_finish_action.bell
	assert !cfg.notify_on_command_finish_action.notify
	cfg.load_string('notify-on-command-finish-action = true')
	assert cfg.notify_on_command_finish_action.bell
	assert cfg.notify_on_command_finish_action.notify

	cfg.load_string('notify-on-command-finish-action = sparkle\nnotify-on-command-finish-after = soon')
	assert cfg.diagnostics.len == 2
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
		cfg.load_string('﻿abnormal-command-exit-runtime = 2500\n')
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

fn test_theme_loading_resolves_user_theme_name() {
	dir := os.join_path(os.temp_dir(), 'witty-theme-name-${os.getpid()}')
	theme_dir := os.join_path(dir, 'ghostty', 'themes')
	os.rmdir_all(dir) or {}
	os.mkdir_all(theme_dir)!
	defer {
		os.rmdir_all(dir) or {}
	}
	old_xdg := os.getenv_opt('XDG_CONFIG_HOME')
	os.setenv('XDG_CONFIG_HOME', dir, true)
	defer {
		if value := old_xdg {
			os.setenv('XDG_CONFIG_HOME', value, true)
		} else {
			os.unsetenv('XDG_CONFIG_HOME')
		}
	}
	os.write_file(os.join_path(theme_dir, 'named-theme'), 'background = #123456\ncustom-shader = shader.glsl\n')!
	mut cfg := Config.default_config()
	cfg.load_string('theme = named-theme\n')
	cfg.finalize()
	assert cfg.background == ColorRGB{0x12, 0x34, 0x56}
	assert cfg.custom_shader.items == [
		Path{ path: os.join_path(theme_dir, 'shader.glsl') },
	]
	assert cfg.diagnostics.len == 0
}

fn test_theme_rejects_relative_path_with_separator() {
	mut cfg := Config.default_config()
	cfg.load_string('theme = nested/theme\n')
	cfg.finalize()
	assert cfg.diagnostics.len == 1
	assert cfg.diagnostics[0].message.contains('cannot include path separators')
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

fn test_theme_replay_preserves_all_user_overrides_and_repeatables() {
	dir := os.join_path(os.temp_dir(), 'witty-theme-replay-${os.getpid()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir)!
	defer { os.rmdir_all(dir) or {} }
	theme_path := os.join_path(dir, 'theme')
	config_path := os.join_path(dir, 'config')
	os.write_file(theme_path, '
font-size = 9
cursor-color = #010203
palette = 1=#111111
font-family = Theme Font
custom-shader = theme.glsl
keybind = ctrl+a=new_window
config-file = ignored.conf
')!
	os.write_file(config_path, '
theme = ${theme_path}
font-size = 17
cursor-color = #AABBCC
palette = 2=#222222
font-family = User Font
custom-shader = user.glsl
keybind = ctrl+b=new_tab
')!

	mut cfg := Config.default_config()
	cfg.load_file(config_path)
	cfg.finalize()

	assert cfg.font_size == 17
	assert cfg.cursor_color?.color == ColorRGB{0xAA, 0xBB, 0xCC}
	assert cfg.palette.value[1] == ColorRGB{0x11, 0x11, 0x11}
	assert cfg.palette.value[2] == ColorRGB{0x22, 0x22, 0x22}
	assert cfg.font_family == ['Theme Font', 'User Font']
	assert cfg.custom_shader.items == [
		Path{ path: os.join_path(dir, 'theme.glsl') },
		Path{ path: os.join_path(dir, 'user.glsl') },
	]
	assert cfg.config_file.items.len == 0
	assert cfg.keybind.set.get(input.Trigger.parse('ctrl+a')!) or {
		panic('theme keybind was not retained')
	}.value.leaf_action.tag == .new_window
	assert cfg.keybind.set.get(input.Trigger.parse('ctrl+b')!) or {
		panic('user keybind was not retained')
	}.value.leaf_action.tag == .new_tab
	assert cfg.diagnostics.len == 0
}

fn test_conditional_theme_replay_replaces_theme_repeatables() {
	dir := os.join_path(os.temp_dir(), 'witty-theme-replay-conditional-${os.getpid()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir)!
	defer { os.rmdir_all(dir) or {} }
	light := os.join_path(dir, 'light')
	dark := os.join_path(dir, 'dark')
	os.write_file(light, 'font-family = Light Font\ncustom-shader = light.glsl\n')!
	os.write_file(dark, 'font-family = Dark Font\ncustom-shader = dark.glsl\n')!

	mut cfg := Config.default_config()
	cfg.load_string('theme = light:${light},dark:${dark}\nfont-family = User Font\ncustom-shader = user.glsl\n')
	cfg.finalize()
	assert cfg.font_family == ['Light Font', 'User Font']
	assert cfg.custom_shader.items == [
		Path{ path: os.join_path(dir, 'light.glsl') },
		Path{ path: 'user.glsl' },
	]

	dark_cfg := cfg.change_conditional_state(ConditionalState{ theme: .dark }) or {
		panic('conditional theme was not marked relevant')
	}
	assert dark_cfg.font_family == ['Dark Font', 'User Font']
	assert dark_cfg.custom_shader.items == [
		Path{ path: os.join_path(dir, 'dark.glsl') },
		Path{ path: 'user.glsl' },
	]
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
	assert cfg.cursor_color?.kind == .cell_foreground
	assert cfg.cursor_text?.kind == .cell_background
}

// Config.zig: "compatibility: removed selection-invert-fg-bg"
fn test_compat_removed_selection_invert_fg_bg() {
	mut cfg := Config.default_config()
	cfg.load_string('selection-invert-fg-bg = true\n')
	cfg.finalize()
	assert cfg.selection_foreground?.kind == .cell_background
	assert cfg.selection_background?.kind == .cell_foreground
}

fn test_terminal_color_config_fields() {
	mut cfg := Config.default_config()
	assert cfg.search_foreground.color == ColorRGB{0, 0, 0}
	assert cfg.search_background.color == ColorRGB{0xff, 0xe0, 0x82}
	assert cfg.search_selected_foreground.color == ColorRGB{0, 0, 0}
	assert cfg.search_selected_background.color == ColorRGB{0xf2, 0xa5, 0x7e}

	cfg.load_string('cursor-color = #4e2a84\ncursor-text = cell-background\nselection-background = cell-foreground\nsearch-background = #010203\n')
	assert cfg.cursor_color?.kind == .color
	assert cfg.cursor_color?.color == ColorRGB{78, 42, 132}
	assert cfg.cursor_text?.kind == .cell_background
	assert cfg.selection_background?.kind == .cell_foreground
	assert cfg.search_background.color == ColorRGB{1, 2, 3}
	assert cfg.diagnostics.len == 0

	cfg.load_string('cursor-color =\nselection-background =\n')
	assert cfg.cursor_color == none
	assert cfg.selection_background == none
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

fn test_default_config_initializes_complete_darwin_keybinds() {
	cfg := Config.default_config()
	$if macos {
		assert cfg.keybind.set.bindings.len == 93

		quit := cfg.keybind.set.get(input.Trigger{
			key: input.TriggerKey.new_unicode(u32(`q`))
			mods: input.Mods{ super_: true }
		}) or { panic('missing default quit binding') }
		assert quit.value.leaf_action.tag == .quit

		resize := cfg.keybind.set.get(input.Trigger{
			key: input.TriggerKey.new_physical(.arrow_left)
			mods: input.Mods{ super_: true, ctrl: true }
		}) or { panic('missing default split resize binding') }
		assert resize.value.leaf_action == input.Action.new_enum2(.resize_split, i32(input.SplitResizeDirection.left), 10)

		natural := cfg.keybind.set.get(input.Trigger{
			key: input.TriggerKey.new_physical(.arrow_right)
			mods: input.Mods{ alt: true }
		}) or { panic('missing natural text editing binding') }
		assert natural.value.leaf_action == input.Action.new_str(.esc, 'f')
	} $else {
		assert cfg.keybind.set.bindings.len > 60
	}
}

fn test_default_config_initializes_url_link() {
	mut cfg := Config.default_config()
	assert cfg.link.links.items.len == 1
	link := cfg.link.links.items[0]
	assert link.pattern == default_url_pattern
	assert link.action == .open
	assert link.highlight == .hover_mods
	assert link.mods == input.ctrl_or_super_mods(input.Mods{})

	clone := cfg.clone()
	cfg.link.links.items << LinkEntry{
		pattern: 'issue-[0-9]+'
		action: .open
		highlight: .always
	}
	assert clone.link.links.items.len == 1

	cfg.link_url = false
	cfg.finalize()
	assert cfg.link.links.items.len == 1
	assert cfg.link.links.items[0].pattern == 'issue-[0-9]+'
}

fn test_selection_word_chars_defaults_and_parse() {
	mut chars := SelectionWordChars.defaults()
	assert chars.codepoints[0] == 0
	assert u32(`;`) in chars.codepoints
	assert u32(0x2502) in chars.codepoints

	chars.parse_cli('._')!
	assert chars.codepoints == [u32(0), u32(`.`), u32(`_`)]
}

fn test_clipboard_codepoint_map_parse() {
	mut mappings := RepeatableClipboardCodepointMap{}
	mappings.parse_cli('U+2500=U+002D')!
	mappings.parse_cli('U+0001 - U+0005, U+03A3=SUM')!
	assert mappings.map.len == 3
	assert mappings.map[0].range_start == 0x2500
	assert mappings.map[0].range_end == 0x2500
	match mappings.map[0].replacement {
		terminal.CodepointRepl {
			assert mappings.map[0].replacement.codepoint == u32(`-`)
		}
		terminal.StringRepl {
			assert false, 'expected codepoint replacement'
		}
	}
	assert mappings.map[1].range_start == 1
	assert mappings.map[1].range_end == 5
	match mappings.map[2].replacement {
		terminal.StringRepl {
			assert mappings.map[2].replacement.str == 'SUM'
		}
		terminal.CodepointRepl {
			assert false, 'expected string replacement'
		}
	}
}

fn test_load_string_applies_selection_and_clipboard_maps() {
	mut cfg := Config.default_config()
	cfg.load_string('
selection-word-chars = ._
clipboard-codepoint-map = U+2500=U+002D
')
	assert cfg.selection_word_chars.codepoints == [u32(0), u32(`.`), u32(`_`)]
	assert cfg.clipboard_codepoint_map.map.len == 1
	assert cfg.diagnostics.len == 0
}

fn test_font_configuration_rejects_invalid_values_and_resets_metric_modifier() {
	mut cfg := Config.default_config()
	cfg.load_string('adjust-cell-width = 2\nadjust-cell-width = \nfont-variation = abc=1\nfont-codepoint-map = U+0001-0002=Symbols\nadjust-cell-height = 1.5\nfont-synthetic-style = shadow\nfreetype-load-flags = lcd\n')
	assert cfg.adjust_cell_width == none
	assert cfg.diagnostics.len == 5
}

fn test_config_key_remap_is_parsed_cloned_and_finalized() {
	mut cfg := Config.default_config()
	cfg.load_string('key-remap = ctrl=super\nkey-remap = right_ctrl=alt\n')
	assert cfg.diagnostics.len == 0
	cfg.finalize()

	left_ctrl := input.Mods{
		ctrl: true
		sides: input.SideInfo{ ctrl: .left }
	}
	right_ctrl := input.Mods{
		ctrl: true
		sides: input.SideInfo{ ctrl: .right }
	}
	assert cfg.key_remap.apply(left_ctrl).super_
	assert cfg.key_remap.apply(right_ctrl).alt

	cloned := cfg.clone()
	assert cloned.key_remap.equal(cfg.key_remap)
}

fn test_load_string_applies_full_existing_config_surface() {
	mut cfg := Config.default_config()
	cfg.load_string('
command = direct:nvim file.txt
initial-command = shell:echo hi
initial-input = hello
env = FOO=first
env = BAR=second
env = FOO=replaced
enquiry-response = witty
font-feature = liga
font-feature = calt
font-style = Regular
font-style-bold = Bold
font-style-italic = Italic
font-style-bold-italic = Bold Italic
font-synthetic-style = bold,no-italic,no-bold-italic
font-variation = wght=200
font-variation = slnt=-15.5
font-variation-bold = wght=700
font-variation-italic = ital=1
font-variation-bold-italic = opsz=13
font-codepoint-map = U+ABCD=Comic Sans
font-codepoint-map = U+0001-U+0005,U+0006=Verdana
font-thicken = true
font-thicken-strength = 42
font-shaping-break = no-cursor
adjust-cell-width = 1
adjust-cell-height = 20%
adjust-font-baseline = -2
adjust-underline-position = 3
adjust-underline-thickness = 4
adjust-strikethrough-position = -5
adjust-strikethrough-thickness = 6
adjust-overline-position = -7
adjust-overline-thickness = 8
adjust-cursor-thickness = 9
adjust-cursor-height = -10%
adjust-box-thickness = 11
adjust-icon-height = 12%
freetype-load-flags = no-hinting,force-autohint,monochrome,no-autohint,light
custom-shader = one.glsl
custom-shader = ?"optional shader.glsl"
config-file = extra.conf
config-file = ?optional.conf
background-image = ?bg.png
background-image-opacity = 0.75
background-image-position = center-center
background-image-fit = cover
background-image-repeat = true
background-opacity-cells = true
bold-color = RebeccaPurple
unfocused-split-fill = LightGoldenrodYellow
split-divider-color = #abc
split-preserve-zoom = navigation
window-padding-x = 3,4
window-padding-y = 1,2
window-padding-balance = true
window-padding-color = extend-always
window-position-x = -120
window-position-y = 340
window-save-state = always
window-step-resize = true
window-vsync = false
window-colorspace = display-p3
alpha-blending = linear
background-blur = 37
clipboard-read = deny
clipboard-write = ask
copy-on-select = clipboard
confirm-close-surface = always
mouse-shift-capture = never
shell-integration = fish
shell-integration-features = no-cursor,sudo,ssh-env,no-path
link-previews = osc8
scroll-to-bottom = no-keystroke,output
grapheme-width-method = legacy
scrollbar = never
notify-on-command-finish = always
cursor-style = bar
cursor-style-blink = false
right-click-action = copy-or-paste
osc-color-report-format = 8-bit
custom-shader-animation = always
mouse-scroll-multiplier = 2.5
image-storage-limit = 0x100
undo-timeout = 1h30m
async-backend = io_uring
auto-update = download
auto-update-channel = stable
')

	assert cfg.diagnostics.len == 0
	command := cfg.command or { panic('missing command') }
	match command {
		DirectCmd {
			assert command.direct == ['nvim', 'file.txt']
		}
		ShellCmd {
			assert false, 'expected direct command'
		}
	}
	initial_command := cfg.initial_command or { panic('missing initial command') }
	match initial_command {
		ShellCmd {
			assert initial_command.shell == 'echo hi'
		}
		DirectCmd {
			assert false, 'expected shell command'
		}
	}
	assert cfg.initial_input? == 'hello'
	assert cfg.env.entries == [StringMapEntry{'FOO', 'replaced'}, StringMapEntry{'BAR', 'second'}]
	assert cfg.enquiry_response == 'witty'
	assert cfg.font_feature == ['liga', 'calt']
	assert cfg.font_style == FontStyle{ kind: .name, name: 'Regular' }
	assert cfg.font_style_bold == FontStyle{ kind: .name, name: 'Bold' }
	assert cfg.font_style_italic == FontStyle{ kind: .name, name: 'Italic' }
	assert cfg.font_style_bold_italic == FontStyle{ kind: .name, name: 'Bold Italic' }
	assert cfg.font_synthetic_style.bold
	assert !cfg.font_synthetic_style.italic
	assert !cfg.font_synthetic_style.bold_italic
	assert cfg.font_variation.list.len == 2
	assert cfg.font_variation.list[0].id.str() == 'wght'
	assert cfg.font_variation.list[0].value == 200
	assert cfg.font_variation.list[1].id.str() == 'slnt'
	assert cfg.font_variation.list[1].value == -15.5
	assert cfg.font_variation_bold.list[0].id.str() == 'wght'
	assert cfg.font_variation_italic.list[0].id.str() == 'ital'
	assert cfg.font_variation_bold_italic.list[0].id.str() == 'opsz'
	assert cfg.font_codepoint_map.map.entries.len == 3
	assert cfg.font_codepoint_map.map.entries[0].range == [u32(0xabcd), u32(0xabcd)]!
	assert cfg.font_codepoint_map.map.entries[0].descriptor.family? == 'Comic Sans'
	assert cfg.font_codepoint_map.map.entries[1].range == [u32(1), u32(5)]!
	assert cfg.font_codepoint_map.map.entries[2].range == [u32(6), u32(6)]!
	assert cfg.adjust_cell_width?.absolute == 1
	assert cfg.adjust_cell_height?.is_percent
	assert cfg.adjust_cell_height?.percent == 1.2
	assert cfg.adjust_font_baseline?.absolute == -2
	assert cfg.adjust_underline_position?.absolute == 3
	assert cfg.adjust_underline_thickness?.absolute == 4
	assert cfg.adjust_strikethrough_position?.absolute == -5
	assert cfg.adjust_strikethrough_thickness?.absolute == 6
	assert cfg.adjust_overline_position?.absolute == -7
	assert cfg.adjust_overline_thickness?.absolute == 8
	assert cfg.adjust_cursor_thickness?.absolute == 9
	assert cfg.adjust_cursor_height?.percent == 0.9
	assert cfg.adjust_box_thickness?.absolute == 11
	assert cfg.adjust_icon_height?.percent == 1.12
	assert !cfg.freetype_load_flags.hinting
	assert cfg.freetype_load_flags.force_autohint
	assert cfg.freetype_load_flags.monochrome
	assert !cfg.freetype_load_flags.autohint
	assert cfg.freetype_load_flags.light
	assert cfg.font_thicken
	assert cfg.font_thicken_strength == 42
	assert !cfg.font_shaping_break.cursor
	assert cfg.custom_shader.items == [
		Path{ path: 'one.glsl' },
		Path{ path: 'optional shader.glsl', optional: true },
	]
	assert cfg.config_file.items == [
		Path{ path: 'extra.conf' },
		Path{ path: 'optional.conf', optional: true },
	]
	assert cfg.background_image?.path == 'bg.png'
	assert cfg.background_image?.optional
	assert cfg.background_image_opacity == 0.75
	assert cfg.background_image_position == .center_center
	assert cfg.background_image_fit == .cover
	assert cfg.background_image_repeat
	assert cfg.background_opacity_cells
	assert cfg.bold_color?.bright == false
	assert cfg.bold_color?.color == ColorRGB{102, 51, 153}
	assert cfg.unfocused_split_fill? == ColorRGB{250, 250, 210}
	assert cfg.split_divider_color? == ColorRGB{170, 187, 204}
	assert cfg.split_preserve_zoom.navigation
	assert cfg.window_padding_x == WindowPadding{3, 4}
	assert cfg.window_padding_y == WindowPadding{1, 2}
	assert cfg.window_padding_balance
	assert cfg.window_padding_color == .extend_always
	assert cfg.window_position_x? == -120
	assert cfg.window_position_y? == 340
	assert cfg.window_save_state == .always
	assert cfg.window_step_resize
	assert !cfg.window_vsync
	assert cfg.window_colorspace == .display_p3
	assert cfg.alpha_blending == .linear
	assert cfg.background_blur.kind == .radius
	assert cfg.background_blur.radius == 37
	assert cfg.clipboard_read == .deny
	assert cfg.clipboard_write == .ask
	assert cfg.copy_on_select == .clipboard
	assert cfg.confirm_close_surface == .always
	assert cfg.mouse_shift_capture == .never
	assert cfg.shell_integration == .fish
	assert !cfg.shell_integration_features.cursor
	assert cfg.shell_integration_features.sudo
	assert cfg.shell_integration_features.ssh_env
	assert !cfg.shell_integration_features.path
	assert cfg.link_previews == .osc8
	assert !cfg.scroll_to_bottom.keystroke
	assert cfg.scroll_to_bottom.output
	assert cfg.grapheme_width_method == .legacy
	assert cfg.scrollbar == .never
	assert cfg.notify_on_command_finish == .always
	assert cfg.cursor_style == .bar
	assert cfg.cursor_style_blink? == false
	assert cfg.right_click_action == .copy_or_paste
	assert cfg.osc_color_report_format == .format_8_bit
	assert cfg.custom_shader_animation == .always
	assert cfg.mouse_scroll_multiplier == 2.5
	assert cfg.image_storage_limit == 0x100
	assert cfg.undo_timeout.duration == u64(5_400) * 1_000_000_000
	assert cfg.async_backend == .io_uring
	assert cfg.auto_update? == .download
	assert cfg.auto_update_channel? == .stable
}

fn test_repeatable_config_values_reset_and_env_remove() {
	mut cfg := Config.default_config()
	cfg.load_string('
font-feature = liga
font-feature =
custom-shader = one
custom-shader =
config-file = one
config-file =
env = A=B
env = A=
env = C=D
env =
command = echo hi
command =
')
	assert cfg.font_feature.len == 0
	assert cfg.custom_shader.items.len == 0
	assert cfg.config_file.items.len == 0
	assert cfg.env.entries.len == 0
	assert cfg.command == none
	assert cfg.diagnostics.len == 0
}

fn test_invalid_scalar_config_values_are_diagnostics_not_zeroes() {
	mut cfg := Config.default_config()
	before_font_size := cfg.font_size
	before_window_width := cfg.window_width
	cfg.load_string('
font-size = nope
window-width = -1
font-thicken-strength = 256
background-image-opacity = nope
font-shaping-break = mouse
shell-integration = powershell
right-click-action = explode
')
	assert cfg.font_size == before_font_size
	assert cfg.window_width == before_window_width
	assert cfg.font_thicken_strength == 255
	assert cfg.background_image_opacity == 1.0
	assert cfg.diagnostics.len == 7
}

fn test_named_colors_work_for_base_colors_and_palette() {
	mut cfg := Config.default_config()
	cfg.load_string('
background = RebeccaPurple
foreground = LightGoldenrodYellow
palette = 17=DeepSkyBlue
')
	assert cfg.background == ColorRGB{102, 51, 153}
	assert cfg.foreground == ColorRGB{250, 250, 210}
	assert cfg.palette.value[17] == ColorRGB{0, 191, 255}
	assert cfg.diagnostics.len == 0
}

fn test_repeatable_path_parses_required_optional_quotes_and_reset() {
	mut paths := RepeatablePath{}
	paths.parse_cli('one.glsl')!
	paths.parse_cli('?"optional shader.glsl"')!
	paths.parse_cli('?')!
	assert paths.items == [
		Path{ path: 'one.glsl' },
		Path{ path: 'optional shader.glsl', optional: true },
	]
	paths.parse_cli('')!
	assert paths.items.len == 0
}

fn test_path_parse_distinguishes_quoted_question_mark() {
	required := Path.parse('"?required.conf"') or { panic('missing required path') }
	optional := Path.parse('?"optional.conf"') or { panic('missing optional path') }
	assert required == Path{ path: '?required.conf' }
	assert optional == Path{ path: 'optional.conf', optional: true }
	assert !required.equal(&optional)
}

fn test_load_file_expands_paths_relative_to_declaring_file() {
	dir := os.join_path(os.temp_dir(), 'witty-config-paths-${os.getpid()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir)!
	defer {
		os.rmdir_all(dir) or {}
	}
	path := os.join_path(dir, 'config.ghostty')
	os.write_file(path, 'custom-shader = shader.glsl\nbackground-image = images/bg.png\n')!
	mut cfg := Config.default_config()
	cfg.load_file(path)
	assert cfg.custom_shader.items == [Path{ path: os.join_path(dir, 'shader.glsl') }]
	assert cfg.background_image? == Path{ path: os.join_path(dir, 'images', 'bg.png') }
	assert cfg.diagnostics.len == 0
}

fn test_load_recursive_files_preserves_order_and_nested_bases() {
	dir := os.join_path(os.temp_dir(), 'witty-config-recursive-${os.getpid()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(os.join_path(dir, 'nested'))!
	defer {
		os.rmdir_all(dir) or {}
	}
	root := os.join_path(dir, 'config.ghostty')
	first := os.join_path(dir, 'first.conf')
	second := os.join_path(dir, 'nested', 'second.conf')
	os.write_file(root, 'font-size = 10\nconfig-file = first.conf\n')!
	os.write_file(first, 'font-size = 11\nconfig-file = nested/second.conf\n')!
	os.write_file(second, 'font-size = 12\ncustom-shader = effect.glsl\n')!

	mut cfg := Config.default_config()
	cfg.load_file(root)
	cfg.load_recursive_files()
	assert cfg.font_size == 12
	assert cfg.config_file.items == [
		Path{ path: first },
		Path{ path: second },
	]
	assert cfg.custom_shader.items == [
		Path{ path: os.join_path(dir, 'nested', 'effect.glsl') },
	]
	assert cfg.diagnostics.len == 0
}

fn test_recursive_files_skip_optional_missing_and_report_required_and_cycles() {
	dir := os.join_path(os.temp_dir(), 'witty-config-recursive-errors-${os.getpid()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir)!
	defer {
		os.rmdir_all(dir) or {}
	}
	root := os.join_path(dir, 'config.ghostty')
	child := os.join_path(dir, 'child.conf')
	os.write_file(root, 'config-file = ?missing.conf\nconfig-file = required.conf\nconfig-file = child.conf\n')!
	os.write_file(child, 'config-file = child.conf\n')!

	mut cfg := Config.default_config()
	cfg.load_file(root)
	cfg.load_recursive_files()
	assert cfg.diagnostics.len == 2
	assert cfg.diagnostics[0].message == 'error opening config-file ${os.join_path(dir, 'required.conf')}: file not found'
	assert cfg.diagnostics[1].message == 'config-file ${child}: cycle detected'
}

fn test_preferred_xdg_path_uses_new_then_legacy_name() {
	dir := os.join_path(os.temp_dir(), 'witty-config-default-path-${os.getpid()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(os.join_path(dir, 'ghostty'))!
	defer {
		os.rmdir_all(dir) or {}
	}
	old_xdg := os.getenv_opt('XDG_CONFIG_HOME')
	os.setenv('XDG_CONFIG_HOME', dir, true)
	defer {
		if value := old_xdg {
			os.setenv('XDG_CONFIG_HOME', value, true)
		} else {
			os.unsetenv('XDG_CONFIG_HOME')
		}
	}
	new_path := os.join_path(dir, 'ghostty', 'config.ghostty')
	legacy_path := os.join_path(dir, 'ghostty', 'config')
	assert preferred_xdg_config_path() == new_path
	os.write_file(legacy_path, 'font-size = 10\n')!
	assert preferred_xdg_config_path() == legacy_path
	os.write_file(new_path, 'font-size = 11\n')!
	assert preferred_xdg_config_path() == new_path
}

fn test_keybinds_format_entries_includes_root_tables_and_chains() {
	mut keybinds := Keybinds{}
	keybinds.parse_cli('ctrl+a=new_window')!
	keybinds.parse_cli('editing/x=text:hello')!
	keybinds.parse_cli('editing/chain=new_tab')!
	assert keybinds.format_entries() == [
		'keybind = ctrl+a=new_window',
		'keybind = editing/x=text:hello',
		'keybind = chain=new_tab',
	]
}

fn test_format_config_default_formats_all_supported_values() {
	formatted := Config.default_config().format_config(false)
	assert formatted.contains('font-size = 13.0\n')
	assert formatted.contains('background = #282c34\n')
	assert formatted.contains('clipboard-codepoint-map = \n')
	assert formatted.contains('keybind = ')
	assert formatted.contains('palette = 255=#eeeeee\n')
}

fn test_format_config_changes_only_round_trips_supported_values() {
	mut original := Config.default_config()
	original.load_string('font-size = 17.5\nfont-style-bold = Heavy\nfont-synthetic-style = no-bold,italic,bold-italic\nfont-variation = wght=321.5\nfont-codepoint-map = U+0001-U+0002=Symbols\nadjust-cell-height = -25%\nfreetype-load-flags = no-hinting,force-autohint\nbackground = RebeccaPurple\ncommand = direct:echo hello\ncustom-shader = ?shader.glsl\nkeybind = ctrl+a>n=new_window\nkeybind = chain=move_tab:-1\nsplit-preserve-zoom = navigation\nwindow-padding-x = 6,7\nwindow-padding-y = 8\nwindow-position-x = -9\nwindow-position-y = 10\nwindow-save-state = never\nwindow-step-resize = true\nundo-timeout = 45s\nasync-backend = io_uring\nauto-update = check\nauto-update-channel = stable\n')
	formatted := original.format_config(true)
	assert formatted.contains('font-size = 17.5\n')
	assert formatted.contains('font-style-bold = Heavy\n')
	assert formatted.contains('font-synthetic-style = no-bold,italic,bold-italic\n')
	assert formatted.contains('font-variation = wght=321.5\n')
	assert formatted.contains('font-codepoint-map = U+0001-U+0002=Symbols\n')
	assert formatted.contains('adjust-cell-height = -25%\n')
	assert formatted.contains('freetype-load-flags = no-hinting,force-autohint,no-monochrome,autohint,light\n')
	assert formatted.contains('background = #663399\n')
	assert formatted.contains('command = direct:echo hello\n')
	assert formatted.contains('custom-shader = ?shader.glsl\n')
	assert formatted.contains('keybind = ctrl+a>n=new_window\n')
	assert formatted.contains('keybind = chain=move_tab:-1\n')
	assert formatted.contains('split-preserve-zoom = navigation\n')
	assert formatted.contains('window-padding-x = 6,7\n')
	assert formatted.contains('window-padding-y = 8\n')
	assert formatted.contains('window-position-x = -9\n')
	assert formatted.contains('window-position-y = 10\n')
	assert formatted.contains('window-save-state = never\n')
	assert formatted.contains('window-step-resize = true\n')
	assert formatted.contains('undo-timeout = 45s\n')
	assert formatted.contains('async-backend = io_uring\n')
	assert formatted.contains('auto-update = check\n')
	assert formatted.contains('auto-update-channel = stable\n')

	mut parsed := Config.default_config()
	parsed.load_string(formatted)
	assert parsed.diagnostics.len == 0
	assert parsed.font_size == original.font_size
	assert parsed.font_style_bold == original.font_style_bold
	assert parsed.font_synthetic_style == original.font_synthetic_style
	assert parsed.font_variation.equal(original.font_variation)
	assert parsed.font_codepoint_map.equal(original.font_codepoint_map)
	assert parsed.adjust_cell_height == original.adjust_cell_height
	assert parsed.freetype_load_flags == original.freetype_load_flags
	assert parsed.background == original.background
	assert parsed.command?.string_val() == original.command?.string_val()
	assert parsed.custom_shader.equal(&original.custom_shader)
	assert parsed.split_preserve_zoom.navigation
	assert parsed.window_padding_x == original.window_padding_x
	assert parsed.window_padding_y == original.window_padding_y
	assert parsed.window_position_x == original.window_position_x
	assert parsed.window_position_y == original.window_position_y
	assert parsed.window_save_state == original.window_save_state
	assert parsed.window_step_resize
	assert parsed.undo_timeout == original.undo_timeout
	assert parsed.async_backend == original.async_backend
	assert parsed.auto_update == original.auto_update
	assert parsed.auto_update_channel == original.auto_update_channel
	// Ghostty's binding formatter intentionally serializes triggers and
	// actions but not the in-memory performable/consumed flags.
	assert parsed.keybind.set.get_trigger(input.Action{ tag: .new_window }) != none
}
