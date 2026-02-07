module terminal

// x11_color_test.v - Tests for X11 color name lookup.
//
// Translated from the tests in Ghostty's terminal/x11_color.zig.

fn test_x11_color_no_such_color() {
	assert x11_color_get('nosuchcolor') == none
}

fn test_x11_color_white() {
	c := x11_color_get('white') or {
		assert false, 'expected white'
		return
	}
	assert c.r == 255 && c.g == 255 && c.b == 255
}

fn test_x11_color_medium_spring_green() {
	c := x11_color_get('medium spring green') or {
		assert false, 'expected medium spring green'
		return
	}
	assert c.r == 0 && c.g == 250 && c.b == 154
}

fn test_x11_color_forest_green_camel() {
	c := x11_color_get('ForestGreen') or {
		assert false, 'expected ForestGreen'
		return
	}
	assert c.r == 34 && c.g == 139 && c.b == 34
}

fn test_x11_color_forest_green_mixed_case() {
	// Case insensitive lookup
	c := x11_color_get('FoReStGReen') or {
		assert false, 'expected FoReStGReen'
		return
	}
	assert c.r == 34 && c.g == 139 && c.b == 34
}

fn test_x11_color_black() {
	c := x11_color_get('black') or {
		assert false, 'expected black'
		return
	}
	assert c.r == 0 && c.g == 0 && c.b == 0
}

fn test_x11_color_red() {
	c := x11_color_get('red') or {
		assert false, 'expected red'
		return
	}
	assert c.r == 255 && c.g == 0 && c.b == 0
}

fn test_x11_color_green() {
	c := x11_color_get('green') or {
		assert false, 'expected green'
		return
	}
	assert c.r == 0 && c.g == 255 && c.b == 0
}

fn test_x11_color_blue() {
	c := x11_color_get('blue') or {
		assert false, 'expected blue'
		return
	}
	assert c.r == 0 && c.g == 0 && c.b == 255
}

fn test_x11_color_lawn_green() {
	c := x11_color_get('lawngreen') or {
		assert false, 'expected lawngreen'
		return
	}
	assert c.r == 124 && c.g == 252 && c.b == 0
}

fn test_x11_color_medium_spring_green_no_spaces() {
	c := x11_color_get('mediumspringgreen') or {
		assert false, 'expected mediumspringgreen'
		return
	}
	assert c.r == 0 && c.g == 250 && c.b == 154
}

fn test_x11_color_forest_green_lower() {
	c := x11_color_get('forestgreen') or {
		assert false, 'expected forestgreen'
		return
	}
	assert c.r == 34 && c.g == 139 && c.b == 34
}
