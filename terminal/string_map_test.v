module terminal

import oniguruma

// Tests for StringMap.
// Translated from Ghostty's StringMap.zig tests.

// Ghostty's URL tests use `config/url.zig`'s regex. configpkg imports this
// module, so the terminal tests cannot import it back; this pattern matches
// the same URLs in these inputs.
const string_map_test_url_regex = r'https?://[^ ]+'

fn string_map_test_pin(s &Screen, x u16, y u32) Pin {
	return s.pages.pin(Point.new(.active, Coordinate{ x: x, y: y })) or {
		panic('test pin is outside the page list')
	}
}

fn string_map_test_point(s &Screen, p Pin) Point {
	return s.pages.point_from_pin(.screen, p) or { panic('match pin is outside the page list') }
}

fn test_selection_string_map_allocation_failure_cleanup() {
	assert sizeof(SelectionStringFailPoint) == 1
	assert u8(SelectionStringFailPoint.copy_map) == 0

	mut s := Screen.init(10, 5, 0)
	defer { s.deinit() }
	s.test_write_string('hello')!
	sel := Selection.init(
		string_map_test_pin(&s, 0, 0),
		string_map_test_pin(&s, 4, 0),
		false,
	)
	mut smap := &StringMap{
		string: 'unchanged'
	}

	mut tw := selection_string_tripwire()
	tw.error_always(.copy_map, error('OutOfMemory'))
	defer {
		tw.end(.reset) or { panic(err) }
	}
	if _ := s.selection_string(SelectionString{
		sel: sel
		map: smap
	}) {
		assert false, 'expected map allocation failure'
	} else {
		assert err.msg() == 'OutOfMemory'
	}
	assert smap.string == 'unchanged'
	assert smap.map.len == 0
}

fn test_string_map_search_iterator() ! {
	// Initialize our regex
	mut re := oniguruma.Regex.init('[A-B]{2}', oniguruma.Options{}, .utf8, .default_, none)!
	defer { re.deinit() }

	// Initialize our screen
	mut s := Screen.init(5, 5, 0)
	defer { s.deinit() }
	str := '1ABCD2EFGH\n3IJKL'
	s.test_write_string(str)!
	line := s.select_line(SelectLine{
		pin: string_map_test_pin(&s, 2, 1)
	}) or { panic('expected line selection') }
	mut smap := &StringMap{}
	_ = s.selection_string(SelectionString{
		sel:  line
		trim: false
		map:  smap
	})!
	defer { smap.deinit() }

	// Get our iterator
	mut it := smap.search_iterator(re)
	{
		mut match_ := (it.next()!).get() or { panic('expected a match') }
		defer { match_.deinit() }

		sel := match_.selection()
		assert string_map_test_point(&s, sel.start()) == Point.new(.screen, Coordinate{
			x: 1
			y: 0
		})
		assert string_map_test_point(&s, sel.end()) == Point.new(.screen, Coordinate{
			x: 2
			y: 0
		})
	}

	assert (it.next()!).get() == none
}

fn test_string_map_search_iterator_url_detection() ! {
	// Initialize URL regex
	mut re := oniguruma.Regex.init(string_map_test_url_regex, oniguruma.Options{}, .utf8,
		.default_, none)!
	defer { re.deinit() }

	// Initialize our screen with text containing a URL
	mut s := Screen.init(40, 5, 0)
	defer { s.deinit() }
	s.test_write_string('hello https://example.com/path world')!

	// Get the line
	line := s.select_line(SelectLine{
		pin: string_map_test_pin(&s, 10, 0)
	}) or { panic('expected line selection') }
	mut smap := &StringMap{}
	_ = s.selection_string(SelectionString{
		sel:  line
		trim: false
		map:  smap
	})!
	defer { smap.deinit() }

	// Search for URL match
	mut it := smap.search_iterator(re)
	{
		mut match_ := (it.next()!).get() or { panic('expected a URL match') }
		defer { match_.deinit() }

		sel := match_.selection()
		// URL should start at x=6 ("https://example.com/path" starts after "hello ")
		assert string_map_test_point(&s, sel.start()) == Point.new(.screen, Coordinate{
			x: 6
			y: 0
		})
		// URL should end at x=29 (end of "/path")
		assert string_map_test_point(&s, sel.end()) == Point.new(.screen, Coordinate{
			x: 29
			y: 0
		})
	}

	assert (it.next()!).get() == none
}

fn test_string_map_search_iterator_url_with_click_position() ! {
	// Initialize URL regex
	mut re := oniguruma.Regex.init(string_map_test_url_regex, oniguruma.Options{}, .utf8,
		.default_, none)!
	defer { re.deinit() }

	// Initialize our screen with text containing a URL
	mut s := Screen.init(40, 5, 0)
	defer { s.deinit() }
	s.test_write_string('hello https://example.com world')!

	// Simulate clicking on "example" (x=14)
	click_pin := string_map_test_pin(&s, 14, 0)

	// Get the line
	line := s.select_line(SelectLine{
		pin: click_pin
	}) or { panic('expected line selection') }
	mut smap := &StringMap{}
	_ = s.selection_string(SelectionString{
		sel:  line
		trim: false
		map:  smap
	})!
	defer { smap.deinit() }

	// Search for URL match and verify click position is within URL
	mut it := smap.search_iterator(re)
	mut found_url := false
	for {
		mut match_ := (it.next()!).get() or { break }
		sel := match_.selection()
		match_.deinit()
		if sel.contains(&s, click_pin) {
			found_url = true
			// Verify URL bounds
			assert string_map_test_point(&s, sel.start()) == Point.new(.screen, Coordinate{
				x: 6
				y: 0
			})
			assert string_map_test_point(&s, sel.end()) == Point.new(.screen, Coordinate{
				x: 24
				y: 0
			})
			break
		}
	}
	assert found_url
}
