module search

import highlight
import terminal

fn write_screen_search_text(mut screen terminal.Screen, absolute_y int, x int, text string) {
	for i, ch in text.runes() {
		screen.pages.screen_rows[absolute_y].cells[x + i] = terminal.CellData{
			content_tag: .codepoint
			codepoint: u32(ch)
		}
	}
}

fn clear_screen_search_row(mut screen terminal.Screen, absolute_y int) {
	screen.pages.screen_rows[absolute_y] = terminal.RowData.init(screen.pages.cols)
}

fn screen_search_point(searcher &ScreenSearch, hl highlight.FlattenedHighlight) terminal.Pin {
	point := searcher.pages.point_from_pin(.screen, hl.start_pin()) or {
		assert false, 'search result pin is not in the snapshot'
		return terminal.Pin{}
	}
	return terminal.Pin{
		x: point.coord.x
		y: point.coord.y
	}
}

fn test_screen_search_finds_active_matches_newest_first() {
	mut screen := terminal.Screen.init(10, 5, 100)
	defer { screen.deinit() }
	write_screen_search_text(mut screen, 0, 0, 'Fizz')
	write_screen_search_text(mut screen, 2, 0, 'Fizz')

	mut finder := ScreenSearch.init(mut screen, 'Fizz'.bytes())
	defer { finder.deinit() }
	finder.search_all()
	assert finder.state == .complete
	assert finder.matches_len() == 2

	mut matches := finder.matches()
	defer {
		for mut item in matches {
			item.deinit()
		}
	}
	assert screen_search_point(&finder, matches[0]).y == 2
	assert screen_search_point(&finder, matches[1]).y == 0
}

fn test_screen_search_finds_scrollback_beyond_first_page() {
	mut screen := terminal.Screen.init(10, 4, 200)
	defer { screen.deinit() }
	for _ in 0 .. 80 {
		screen.pages.screen_rows << terminal.RowData.init(screen.pages.cols)
	}
	screen.pages.active_start = 80
	write_screen_search_text(mut screen, 3, 1, 'Fizz')
	write_screen_search_text(mut screen, 79, 2, 'Fizz')
	write_screen_search_text(mut screen, 82, 0, 'Fizz')

	mut finder := ScreenSearch.init(mut screen, 'Fizz'.bytes())
	defer { finder.deinit() }
	finder.search_all()
	assert finder.matches_len() == 3

	mut matches := finder.matches()
	defer {
		for mut item in matches {
			item.deinit()
		}
	}
	assert screen_search_point(&finder, matches[0]).y == 82
	assert screen_search_point(&finder, matches[1]).y == 79
	assert screen_search_point(&finder, matches[2]).y == 3
}

fn test_screen_search_select_next_and_prev_do_not_wrap() {
	mut screen := terminal.Screen.init(10, 5, 100)
	defer { screen.deinit() }
	write_screen_search_text(mut screen, 0, 0, 'Fizz')
	write_screen_search_text(mut screen, 2, 0, 'Fizz')

	mut finder := ScreenSearch.init(mut screen, 'Fizz'.bytes())
	defer { finder.deinit() }
	finder.search_all()
	assert finder.do_select(.next)
	assert finder.selected or { panic('missing selected match') }.idx == 0
	selected_newest := finder.selected_match() or { panic('missing newest match') }
	assert screen_search_point(&finder, selected_newest).y == 2
	assert finder.do_select(.next)
	assert finder.selected or { panic('missing selected match') }.idx == 1
	assert !finder.do_select(.next)
	assert finder.do_select(.prev)
	assert finder.selected or { panic('missing selected match') }.idx == 0
	assert !finder.do_select(.prev)
}

fn test_screen_search_reload_researches_changed_active_area() {
	mut screen := terminal.Screen.init(10, 5, 100)
	defer { screen.deinit() }
	write_screen_search_text(mut screen, 0, 0, 'Fizz')
	write_screen_search_text(mut screen, 2, 0, 'Fizz')

	mut finder := ScreenSearch.init(mut screen, 'Fizz'.bytes())
	defer { finder.deinit() }
	finder.search_all()
	clear_screen_search_row(mut screen, 0)
	clear_screen_search_row(mut screen, 2)
	write_screen_search_text(mut screen, 1, 3, 'Fizz')
	finder.reload_active()
	assert finder.state == .complete
	assert finder.matches_len() == 1
	mut matches := finder.matches()
	defer {
		for mut item in matches {
			item.deinit()
		}
	}
	point := screen_search_point(&finder, matches[0])
	assert point.x == 3
	assert point.y == 1
}

fn test_screen_search_reload_preserves_selection_at_same_coordinates() {
	mut screen := terminal.Screen.init(10, 5, 100)
	defer { screen.deinit() }
	write_screen_search_text(mut screen, 2, 0, 'Fizz')

	mut finder := ScreenSearch.init(mut screen, 'Fizz'.bytes())
	defer { finder.deinit() }
	finder.search_all()
	assert finder.do_select(.next)
	// Change unrelated text so the snapshot must be rebuilt.
	write_screen_search_text(mut screen, 4, 0, 'Buzz')
	finder.reload_active()
	selected := finder.selected_match() or { panic('selection was lost') }
	assert screen_search_point(&finder, selected).y == 2
}

fn test_screen_search_no_scrollback_has_no_history_search() {
	mut screen := terminal.Screen.init(10, 3, 0)
	defer { screen.deinit() }
	write_screen_search_text(mut screen, 1, 0, 'Fizz')

	mut finder := ScreenSearch.init(mut screen, 'Fizz'.bytes())
	defer { finder.deinit() }
	finder.search_all()
	assert finder.matches_len() == 1
	assert finder.history_search == none
}
