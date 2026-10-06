module vxfw

import vaxis

fn app_contract_draw(_ voidptr, _ DrawContext) !Surface {
	return error('OutOfMemory')
}

fn app_contract_widget(id usize) Widget {
	return Widget{
		userdata: voidptr(id)
		draw_fn:  app_contract_draw
	}
}

fn app_contract_focus_id(value ?Widget) usize {
	return if focused := value { usize(focused.userdata) } else { usize(0) }
}

fn test_app_options_remain_mutable_and_copy_by_value() {
	mut options := AppOptions{}
	assert options.framerate == 60
	options.framerate = 0
	mut copied := options
	copied.framerate = 255
	assert options.framerate == 0
	assert copied.framerate == 255
}

fn test_app_public_state_copy_preserves_borrowed_timer_items_and_separate_headers() {
	mut app := App{
		tty:         vaxis.Tty{}
		vx:          vaxis.Vaxis.new(vaxis.VaxisOptions{})
		timers:      [Tick{ deadline_ms: 4, widget: app_contract_widget(1) },
			Tick{ deadline_ms: 7, widget: app_contract_widget(2) }]
		wants_focus: none
	}
	defer { app.vx.deinit() }
	mut copied := app
	assert app.timers.data == copied.timers.data
	copied.timers[0].deadline_ms = 99
	assert app.timers[0].deadline_ms == 99
	copied.timers = copied.timers[..1]
	assert app.timers.len == 2
	assert copied.timers.len == 1
	copied.wants_focus = app_contract_widget(3)
	assert app.wants_focus == none
	assert app_contract_focus_id(copied.wants_focus) == 3
	app.wants_focus = app_contract_widget(4)
	assert app_contract_focus_id(copied.wants_focus) == 3
	copied.vx.screen.width = 17
	assert app.vx.screen.width == 0
	assert copied.vx.screen.width == 17
	app.tty = vaxis.Tty{}
}
