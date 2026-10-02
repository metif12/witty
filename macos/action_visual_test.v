module macos

fn test_source_native_visual_layers_and_cursor_consumers() {
	app_init()
	view := create_window(640, 480, 'visuals')
	mut surface := new_action_surface(view, unsafe { nil }, ActionCallbacks{})
	defer {
		surface.deinit()
		close_tab(view)
	}
	surface.set_key_table(0, 'first')
	surface.set_key_sequence(true, '⌘K')
	assert surface.key_dots.len == 3
	assert msg_u64(msg_id(surface.key_badge, 'subviews'), 'count') >= 4
	assert surface.key_width > 0
	assert !is_nil(surface.pulse_timer)
	surface.bell_border = true
	surface.ring_bell()
	assert msg_f64(surface.bell_layer, 'borderWidth') == 3
	assert msg_f64(msg_id1(surface.bell_layer, 'valueForKey:', nsstring('opacity')), 'doubleValue') == 1
	surface.begin_key_down()
	assert msg_f64(msg_id1(surface.bell_layer, 'valueForKey:', nsstring('opacity')), 'doubleValue') == 0
	surface.set_progress(3, none)
	assert msg_f64(msg_id1(surface.progress_layer, 'animationForKey:', nsstring('bounce')), 'duration') == 1.2
	assert objc_utf8_string(msg_id(surface.progress_view, 'accessibilityValue')) == 'Operation in progress'
	surface.set_progress(4, none)
	assert msg_rect(surface.progress_layer, 'frame').width == view_width(view)
	assert objc_utf8_string(msg_id(surface.progress_view, 'accessibilityValue')) == '100 percent complete'
	surface.mouse_over_link('https://example.com/long/path')
	assert !is_nil(surface.hover_tracking)
	assert msg_u64(msg_id(surface.hover_label, 'cell'), 'lineBreakMode') == 5
	surface.presented()
	assert surface.highlighted
	assert msg_u64(msg_id(surface.highlight_radial, 'colors'), 'count') == 3
	msg_void(surface.highlight_timer, 'fire')
	assert !surface.highlighted
	set_cursor_shape(view, 8)
	assert msg_id(surface.scroll.scroll, 'documentCursor') == msg_id(get_class('NSCursor'), 'IBeamCursor')
	assert cursor_for_shape(4) == none
}
