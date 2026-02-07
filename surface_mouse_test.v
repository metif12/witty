module main

fn test_key_to_mouse_shape_no_specific_key() {
	// No specific key pressed
	m := SurfaceMouse{
		physical_key: .unidentified
		mouse_event: .none_
		mouse_shape: .progress
		mods: Mods{}
		over_link: false
		hidden: false
	}

	got := m.key_to_mouse_shape()
	assert got == none
}

fn test_key_to_mouse_shape_over_link() {
	// Over a link. NOTE: This tests that we don't touch the inbound state,
	// not necessarily if we're over a link.
	m := SurfaceMouse{
		physical_key: .shift_left
		mouse_event: .none_
		mouse_shape: .progress
		mods: Mods{}
		over_link: true
		hidden: false
	}

	got := m.key_to_mouse_shape()
	assert got == none
}

fn test_key_to_mouse_shape_hidden() {
	// Mouse is currently hidden
	m := SurfaceMouse{
		physical_key: .shift_left
		mouse_event: .none_
		mouse_shape: .progress
		mods: Mods{}
		over_link: true
		hidden: true
	}

	got := m.key_to_mouse_shape()
	assert got == none
}

fn test_key_to_mouse_shape_default_no_mods_tracking() {
	// default, no mods (mouse tracking)
	m := SurfaceMouse{
		physical_key: .shift_left
		mouse_event: .x10
		mouse_shape: .default_
		mods: Mods{}
		over_link: false
		hidden: false
	}

	want := MouseShape.default_
	got := m.key_to_mouse_shape()
	assert got != none
	assert got? == want
}

fn test_key_to_mouse_shape_default_to_crosshair_tracking() {
	// default -> crosshair (mouse tracking)
	m := SurfaceMouse{
		physical_key: .alt_left
		mouse_event: .x10
		mouse_shape: .default_
		mods: Mods{
			ctrl: true
			super_: true
			alt: true
			shift: true
		}
		over_link: false
		hidden: false
	}

	want := MouseShape.crosshair
	got := m.key_to_mouse_shape()
	assert got != none
	assert got? == want
}

fn test_key_to_mouse_shape_default_to_text_tracking() {
	// default -> text (mouse tracking)
	m := SurfaceMouse{
		physical_key: .shift_left
		mouse_event: .x10
		mouse_shape: .default_
		mods: Mods{
			shift: true
		}
		over_link: false
		hidden: false
	}

	want := MouseShape.text
	got := m.key_to_mouse_shape()
	assert got != none
	assert got? == want
}

fn test_key_to_mouse_shape_crosshair_to_text_tracking() {
	// crosshair -> text (mouse tracking)
	m := SurfaceMouse{
		physical_key: .alt_left
		mouse_event: .x10
		mouse_shape: .crosshair
		mods: Mods{
			shift: true
		}
		over_link: false
		hidden: false
	}

	want := MouseShape.text
	got := m.key_to_mouse_shape()
	assert got != none
	assert got? == want
}

fn test_key_to_mouse_shape_crosshair_to_default_tracking() {
	// crosshair -> default (mouse tracking)
	m := SurfaceMouse{
		physical_key: .alt_left
		mouse_event: .x10
		mouse_shape: .crosshair
		mods: Mods{}
		over_link: false
		hidden: false
	}

	want := MouseShape.default_
	got := m.key_to_mouse_shape()
	assert got != none
	assert got? == want
}

fn test_key_to_mouse_shape_text_to_crosshair_tracking() {
	// text -> crosshair (mouse tracking)
	m := SurfaceMouse{
		physical_key: .alt_left
		mouse_event: .x10
		mouse_shape: .text
		mods: Mods{
			ctrl: true
			super_: true
			alt: true
			shift: true
		}
		over_link: false
		hidden: false
	}

	want := MouseShape.crosshair
	got := m.key_to_mouse_shape()
	assert got != none
	assert got? == want
}

fn test_key_to_mouse_shape_text_to_default_tracking() {
	// text -> default (mouse tracking)
	m := SurfaceMouse{
		physical_key: .shift_left
		mouse_event: .x10
		mouse_shape: .text
		mods: Mods{}
		over_link: false
		hidden: false
	}

	want := MouseShape.default_
	got := m.key_to_mouse_shape()
	assert got != none
	assert got? == want
}

fn test_key_to_mouse_shape_text_no_mods_no_tracking() {
	// text, no mods (no mouse tracking)
	m := SurfaceMouse{
		physical_key: .shift_left
		mouse_event: .none_
		mouse_shape: .text
		mods: Mods{}
		over_link: false
		hidden: false
	}

	want := MouseShape.text
	got := m.key_to_mouse_shape()
	assert got != none
	assert got? == want
}

fn test_key_to_mouse_shape_text_to_crosshair_no_tracking() {
	// text -> crosshair (no mouse tracking)
	m := SurfaceMouse{
		physical_key: .alt_left
		mouse_event: .none_
		mouse_shape: .text
		mods: Mods{
			ctrl: true
			super_: true
			alt: true
		}
		over_link: false
		hidden: false
	}

	want := MouseShape.crosshair
	got := m.key_to_mouse_shape()
	assert got != none
	assert got? == want
}

fn test_key_to_mouse_shape_crosshair_to_text_no_tracking() {
	// crosshair -> text (no mouse tracking)
	m := SurfaceMouse{
		physical_key: .alt_left
		mouse_event: .none_
		mouse_shape: .crosshair
		mods: Mods{}
		over_link: false
		hidden: false
	}

	want := MouseShape.text
	got := m.key_to_mouse_shape()
	assert got != none
	assert got? == want
}
