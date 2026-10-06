module vxfw

import time
import vaxis

struct RoutingLog {
mut:
	items []string
}

struct RoutingWidget {
	name string
mut:
	log     &RoutingLog
	consume ?Phase
	ticks   int
	rearm   bool
}

fn (widget &RoutingWidget) widget() Widget {
	return Widget{
		userdata:        unsafe { voidptr(widget) }
		event_handler:   routing_event
		capture_handler: routing_capture
		draw_fn:         routing_draw
	}
}

fn routing_draw(ptr voidptr, ctx DrawContext) !Surface {
	widget := unsafe { &RoutingWidget(ptr) }
	return Surface.init(widget.widget(), ctx.min)
}

fn routing_event(ptr voidptr, mut ctx EventContext, event Event) ! {
	mut widget := unsafe { &RoutingWidget(ptr) }
	if event is TickEvent {
		widget.ticks++
		if widget.rearm { ctx.tick(0, widget.widget()) }
	}
	routing_record(mut widget, mut ctx, event)
}

fn routing_capture(ptr voidptr, mut ctx EventContext, event Event) ! {
	mut widget := unsafe { &RoutingWidget(ptr) }
	routing_record(mut widget, mut ctx, event)
}

fn routing_record(mut widget RoutingWidget, mut ctx EventContext, event Event) {
	kind := match event {
		vaxis.Mouse { 'mouse:${event.row},${event.col}' }
		MouseEnter { 'enter' }
		vaxis.MouseLeave { 'leave' }
		vaxis.FocusIn { 'focus_in' }
		vaxis.FocusOut { 'focus_out' }
		TickEvent { 'tick' }
		else { 'key' }
	}

	widget.log.items << '${widget.name}:${ctx.phase}:${kind}'
	if phase := widget.consume {
		if phase == ctx.phase { ctx.consume_event() }
	}
}

fn test_focus_capture_includes_target_and_bubble_excludes_target() {
	mut log := &RoutingLog{}
	root := &RoutingWidget{
		name: 'root'
		log:  log
	}
	mut child := &RoutingWidget{
		name: 'child'
		log:  log
	}
	mut focus := FocusHandler.new(root.widget())
	mut ctx := EventContext{
		cmds: []Command{}
	}
	focus.focus_widget(mut ctx, child.widget())!
	assert log.items == ['root:at_target:focus_out', 'child:at_target:focus_in']
	focus.update(Surface{
		size:     Size{}
		buffer:   []vaxis.Cell{}
		widget:   root.widget()
		children: [
			SubSurface{
				origin:  RelativePoint{
					row: 0
					col: 0
				}
				surface: Surface.empty(child.widget())
			},
		]
	})
	log.items.clear()
	focus.handle_event(mut ctx, Event(vaxis.Key{
		codepoint: u32(`a`)
	}))!
	assert log.items == ['root:capturing:key', 'child:capturing:key', 'child:at_target:key',
		'root:bubbling:key']
	log.items.clear()
	child.consume = Phase.capturing
	focus.handle_event(mut ctx, Event(vaxis.Key{
		codepoint: u32(`a`)
	}))!
	assert log.items == ['root:capturing:key', 'child:capturing:key']
	assert ctx.consume_event
}

fn test_mouse_routes_local_coordinates_and_excludes_target_capture() {
	mut log := &RoutingLog{}
	root := &RoutingWidget{
		name: 'root'
		log:  log
	}
	child := &RoutingWidget{
		name: 'child'
		log:  log
	}
	mut mouse := MouseHandler.new(root.widget())
	mut app := App{
		vx: vaxis.Vaxis.new(vaxis.VaxisOptions{})
	}
	defer { app.vx.deinit() }
	mut ctx := EventContext{
		cmds: []Command{}
	}
	mouse.last_frame = Surface{
		buffer:   []vaxis.Cell{}
		size:     Size{
			width:  10
			height: 10
		}
		widget:   root.widget()
		children: [
			SubSurface{
				origin:  RelativePoint{
					row: 2
					col: 3
				}
				surface: Surface{
					buffer:   []vaxis.Cell{}
					children: []SubSurface{}
					size:     Size{
						width:  3
						height: 3
					}
					widget:   child.widget()
				}
			},
		]
	}
	mouse.handle_mouse(mut app, mut ctx, vaxis.Mouse{ row: 3, col: 4, type_: .press, button: .left })!
	assert log.items == ['root:at_target:enter', 'child:at_target:enter', 'root:capturing:mouse:3,4',
		'child:at_target:mouse:1,1', 'root:bubbling:mouse:3,4']
	log.items.clear()
	mouse.mouse_exit(mut app, mut ctx)!
	assert log.items == ['root:bubbling:leave', 'child:bubbling:leave']
	assert mouse.last_hit_list.len == 2 // Source keeps the list on focus loss.
	log.items.clear()
	mouse.update_mouse(mut app, Surface{
		buffer:   []vaxis.Cell{}
		children: []SubSurface{}
		size:     Size{
			width:  10
			height: 10
		}
		widget:   root.widget()
	}, mut ctx)!
	assert log.items == ['child:bubbling:leave']
}

fn test_timers_descending_stable_order_and_deferred_rearm() {
	mut log := &RoutingLog{}
	a := &RoutingWidget{
		name: 'a'
		log:  log
	}
	b := &RoutingWidget{
		name:  'b'
		log:   log
		rearm: true
	}
	c := &RoutingWidget{
		name: 'c'
		log:  log
	}
	mut app := App{
		vx: vaxis.Vaxis.new(vaxis.VaxisOptions{})
	}
	defer { app.vx.deinit() }
	app.add_tick(Tick{ deadline_ms: 1, widget: a.widget() })
	app.add_tick(Tick{ deadline_ms: time.now().unix_milli() + 60000, widget: c.widget() })
	app.add_tick(Tick{ deadline_ms: 1, widget: b.widget() })
	mut ctx := EventContext{
		cmds: []Command{}
	}
	app.check_timers(mut ctx)!
	assert log.items == ['b:at_target:tick', 'a:at_target:tick']
	assert app.timers.len == 2
	assert app.timers[0].widget.eql(c.widget())
	assert app.timers[1].widget.eql(b.widget())
	assert b.ticks == 1
}
