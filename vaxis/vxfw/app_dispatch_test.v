module vxfw

import vaxis

struct AppDrawObservation {
mut:
	context ?DrawContext
}

fn app_observe_draw(ptr voidptr, ctx DrawContext) !Surface {
	mut observation := unsafe { &AppDrawObservation(ptr) }
	observation.context = ctx
	return Surface.empty(Widget{
		userdata: ptr
		draw_fn:  app_observe_draw
	})
}

fn app_failing_event(_ voidptr, mut ctx EventContext, _ Event) ! {
	ctx.phase = .bubbling
	ctx.consume_event = true
	ctx.redraw = false
	ctx.quit = true
	ctx.queue_refresh()
	ctx.redraw = false
	return error('callback failure')
}

fn test_app_event_error_resets_only_per_event_context_fields() {
	mut observation := &AppDrawObservation{}
	widget := Widget{
		userdata:      observation
		draw_fn:       app_observe_draw
		event_handler: app_failing_event
	}
	mut app := App{
		tty:         vaxis.Tty{}
		vx:          vaxis.Vaxis.new(vaxis.VaxisOptions{})
		timers:      []Tick{}
		wants_focus: none
	}
	defer { app.vx.deinit() }
	mut mouse := MouseHandler.new(widget)
	mut focus := FocusHandler.new(widget)
	focus.path_to_focused << widget
	mut ctx := EventContext{
		cmds: []Command{}
	}
	mut failed := false
	app.handle_event(Event(vaxis.Key{ codepoint: u32(`a`) }), mut mouse, mut focus, mut ctx) or {
		assert err.msg() == 'callback failure'
		failed = true
	}
	assert failed
	assert ctx.phase == .capturing && !ctx.consume_event
	assert ctx.quit && !ctx.redraw
	assert ctx.cmds.len == 1 && ctx.cmds[0] is QueueRefresh
}

fn test_app_layout_uses_screen_cells_and_floor_pixel_geometry() {
	mut observation := &AppDrawObservation{}
	widget := Widget{
		userdata: observation
		draw_fn:  app_observe_draw
	}
	mut app := App{
		tty:         vaxis.Tty{}
		vx:          vaxis.Vaxis.new(vaxis.VaxisOptions{})
		timers:      []Tick{}
		wants_focus: none
	}
	defer { app.vx.deinit() }
	app.vx.resize(vaxis.Winsize{ cols: 3, rows: 2, x_pixel: 11, y_pixel: 7 })
	app.do_layout(widget)!
	ctx := observation.context or { panic('draw was not called') }
	assert ctx.min == Size{}
	assert ctx.max.size() == Size{
		width:  3
		height: 2
	}
	assert ctx.cell_size == Size{
		width:  3
		height: 3
	}
}
