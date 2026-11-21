module macos

fn test_native_palette_uses_localized_filter_and_source_title_order() {
	options := [NativeCommandOption{ title: 'Foo Bar: Two' }, NativeCommandOption{ title: 'Foo: One' },
		NativeCommandOption{
			title:    'Ångström'
			subtitle: 'Subdirectory'
		}, NativeCommandOption{ title: 'Colored', leading_color: voidptr(native_color(0xff0000, 1)) }]
	sorted := sorted_command_options(options)
	assert sorted.map(it.title).index('Foo: One') < sorted.map(it.title).index('Foo Bar: Two')
	assert filtered_command_options(sorted, 'ång')[0].title == 'Ångström'
	assert filtered_command_options(sorted, 'subdirectory')[0].title == 'Ångström'
	assert filtered_command_options(sorted, 'absent').len == 0
	assert palette_color_score(voidptr(native_color(0xff0000, 1)), 'red') > 0
	assert filtered_command_options(sorted, 'red')[0].title == 'Colored'
}

fn test_native_palette_edit_and_wrapping_selection_consumers() {
	app_init()
	view := create_window(640, 480, '')
	mut surface := new_action_surface(view, unsafe { nil }, ActionCallbacks{})
	defer {
		surface.deinit()
		close_tab(view)
	}
	surface.toggle_command_palette([
		NativeCommandOption{ title: 'One', leading_icon: 'shippingbox.fill', badge: '1.2', emphasis: true },
		NativeCommandOption{ title: 'Two' },
	])
	mut palette := surface.palette
	assert palette.selected == none
	first_row := msg_id_u64(msg_id(palette.document, 'subviews'), 'objectAtIndex:', 0)
	assert msg_f64(msg_id(first_row, 'layer'), 'borderWidth') == 1.5
	assert msg_u64(msg_id(first_row, 'subviews'), 'count') == 2
	assert palette_command(palette.owner, sel('control:textView:doCommandBySelector:'),
		palette.field, nil_obj(), sel('moveDown:'))
	assert (palette.selected or { uint(99) }) == 0
	palette_command(palette.owner, nil_obj(), palette.field, nil_obj(), sel('moveUp:'))
	assert (palette.selected or { uint(99) }) == 1
	msg_void1(palette.field, 'setStringValue:', nsstring('one'))
	palette_edit(palette.owner, nil_obj(), nil_obj())
	assert palette.filtered.len == 1
	assert palette.filtered[0].title == 'One'
	surface.toggle_command_palette([]NativeCommandOption{})
	assert surface.palette == unsafe { nil }
}
