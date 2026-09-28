module cli

import os
import strings
import vaxis

fn preview_screen_row(screen &vaxis.Screen, row u16) string {
	mut out := strings.new_builder(int(screen.width) * 2)
	for col := u16(0); col < screen.width; col++ {
		cell := screen.read_cell(col, row) or { continue }
		out.write_string(cell.char_.grapheme)
	}
	return out.str()
}

fn test_preview_window_draws_empty_state_and_search_cursor() {
	mut p := Preview.init([], .all)!
	mut vx := vaxis.Vaxis.new(vaxis.VaxisOptions{})
	vx.resize(vaxis.Winsize{
		cols: 80
		rows: 20
	})
	p.draw_window(mut vx)!
	assert preview_screen_row(&vx.screen, 9).contains('No theme found!')
	assert !vx.screen.cursor_vis
	p.mode = .search
	p.text_input.insert_slice_at_cursor('abc')
	p.draw_window(mut vx)!
	assert vx.screen.cursor_vis
	assert vx.screen.cursor_row == 16
	assert vx.screen.cursor_col == 24
	assert preview_screen_row(&vx.screen, 16).contains('abc')
	p.deinit()
	vx.screen.deinit()
	vx.screen_last.deinit()
}

fn test_preview_window_draws_theme_list_and_load_error() {
	missing := os.join_path(os.temp_dir(), 'witty-missing-window-theme-${os.getpid()}')
	os.rm(missing) or {}
	mut p := Preview{
		themes:     [ThemeListElement{
			theme: 'Missing'
			path:  missing
		}]
		filtered:   [usize(0)]
		text_input: vaxis.TextInput.new()
	}
	mut vx := vaxis.Vaxis.new(vaxis.VaxisOptions{})
	vx.resize(vaxis.Winsize{
		cols: 100
		rows: 24
	})
	p.draw_window(mut vx)!
	assert (vx.screen.read_cell(0, 0) or { panic('missing selected cell') }).char_.grapheme == '❯'
	assert (vx.screen.read_cell(2, 0) or { panic('missing theme cell') }).link.uri == p.themes[0].to_uri()
	assert preview_screen_row(&vx.screen, 11).contains('Unable to open Missing from:')
	assert !vx.screen.cursor_vis
	p.text_input.deinit()
	vx.screen.deinit()
	vx.screen_last.deinit()
}

fn test_preview_window_retains_pinned_palette_and_selection_colors() {
	path := os.join_path(os.temp_dir(), 'witty-window-preview-${os.getpid()}')
	os.write_file(path, 'foreground = 010203\nbackground = 040506\nselection-foreground = 0d0e0f\nselection-background = 101112\n')!
	defer { os.rm(path) or {} }
	mut p := Preview.init([ThemeListElement{
		theme: 'Window Preview'
		path:  path
	}], .all)!
	mut vx := vaxis.Vaxis.new(vaxis.VaxisOptions{})
	vx.resize(vaxis.Winsize{
		cols: 120
		rows: 60
	})
	p.draw_window(mut vx)!
	assert preview_screen_row(&vx.screen, 4).contains('  0')
	assert preview_screen_row(&vx.screen, 21).contains('stdout.writeAll')
	assert preview_screen_row(&vx.screen, 27).contains('stdout.print')
	selected := vx.screen.read_cell(35, 27) or { panic('missing sample cell') }
	assert selected.style.bg is vaxis.ColorRgb
	p.deinit()
	vx.screen.deinit()
	vx.screen_last.deinit()
}

fn test_preview_window_mouse_selection_and_highlight() {
	mut p := Preview{
		themes:     [ThemeListElement{ theme: 'One', path: '/missing/one' }, ThemeListElement{
			theme: 'Two'
			path:  '/missing/two'
		}, ThemeListElement{ theme: 'Three', path: '/missing/three' }]
		filtered:   [usize(0), 1, 2]
		text_input: vaxis.TextInput.new()
	}
	mut vx := vaxis.Vaxis.new(vaxis.VaxisOptions{})
	vx.resize(vaxis.Winsize{
		cols: 100
		rows: 20
	})
	p.update(Event(MouseEvent{
		mouse: vaxis.Mouse{
			button: .left
			type_:  .release
			row:    2
			col:    5
		}
	}))!
	p.draw_window(mut vx)!
	assert p.current == 2
	assert p.mouse == none
	p.update(Event(MouseEvent{
		mouse: vaxis.Mouse{
			button: .none_
			type_:  .motion
			row:    1
			col:    5
		}
	}))!
	p.draw_window(mut vx)!
	assert (vx.screen.read_cell(2, 1) or { panic('missing highlighted cell') }).style.eql(p.ui_highlighted())
	p.text_input.deinit()
	vx.screen.deinit()
	vx.screen_last.deinit()
}

fn test_preview_window_segments_wrap_with_reported_width() {
	mut screen := vaxis.Screen.new(vaxis.Winsize{
		cols: 8
		rows: 4
	})
	root := vaxis.Window.new(&screen)
	pane := root.child(vaxis.WindowChildOptions{
		x_off:  2
		y_off:  0
		width:  6
		height: 4
	})
	p := Preview{}
	p.put_window_preview_segments(pane, 2, 1, 4, 8, 4, [PreviewSegment{
		text: 'ABCDEF'
	}])
	assert preview_screen_row(&screen, 1).contains('ABCD')
	assert (screen.read_cell(2, 2) or { panic('missing wrapped cell') }).char_.grapheme == 'E'
	screen.clear()
	screen.width_method = .unicode
	p.put_window_preview_segments(pane, 2, 0, 2, 8, 4, [PreviewSegment{
		text: '👩‍🚀x'
	}])
	assert (screen.read_cell(4, 0) or { panic('missing unicode width cell') }).char_.grapheme == 'x'
	screen.deinit()
}

fn test_preview_window_help_and_save_modals() {
	mut p := Preview{
		themes: [ThemeListElement{ theme: 'Theme A', path: '/missing/theme-a' }]
		filtered: [usize(0)]
		text_input: vaxis.TextInput.new()
	}
	mut vx := vaxis.Vaxis.new(vaxis.VaxisOptions{})
	vx.resize(vaxis.Winsize{
		cols: 120
		rows: 40
	})
	p.mode = .help
	p.draw_window(mut vx)!
	assert preview_screen_row(&vx.screen, 11).contains('^C, q, ESC')
	assert !vx.screen.cursor_vis
	p.mode = .save
	p.draw_window(mut vx)!
	assert preview_screen_row(&vx.screen, 16).contains('theme = Theme A')
	assert !vx.screen.cursor_vis
	p.text_input.deinit()
	vx.screen.deinit()
	vx.screen_last.deinit()
}
