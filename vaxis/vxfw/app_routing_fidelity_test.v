module vxfw

import os
import vaxis

// These same-module consumers exercise private V adapters. Unchanged-source
// comparisons must use public App.run rather than expose its private handlers.
@[heap]
struct AppRoutingFidelityLog {
mut:
	items []string
}

@[heap]
struct AppRoutingFidelityWidget {
	name string
mut:
	log          &AppRoutingFidelityLog
	fail_kind    string
	queue_focus  bool
	consume_kind string
}

fn (value &AppRoutingFidelityWidget) widget() Widget {
	return Widget{
		userdata:        unsafe { voidptr(value) }
		event_handler:   app_routing_fidelity_event
		capture_handler: app_routing_fidelity_event
		draw_fn:         app_routing_fidelity_draw
	}
}

fn app_routing_fidelity_draw(ptr voidptr, _ DrawContext) !Surface {
	value := unsafe { &AppRoutingFidelityWidget(ptr) }
	return Surface.empty(value.widget())
}

fn app_routing_fidelity_event(ptr voidptr, mut ctx EventContext, event Event) ! {
	mut value := unsafe { &AppRoutingFidelityWidget(ptr) }
	kind := match event {
		vaxis.FocusOut { 'out' }
		vaxis.FocusIn { 'in' }
		vaxis.MouseLeave { 'leave' }
		MouseEnter { 'enter' }
		vaxis.Mouse { 'mouse' }
		else { 'event' }
	}

	value.log.items << '${value.name}:${ctx.phase}:${kind}:${ctx.cmds.len}'
	if value.queue_focus {
		ctx.add_cmd(Command(RequestFocus{ widget: value.widget() }))
	}
	if value.consume_kind == kind {
		ctx.consume_event = true
	}
	if value.fail_kind == kind {
		return error('fixture ${kind}')
	}
}

fn app_routing_fidelity_app() App {
	return App{
		tty:         vaxis.Tty{}
		vx:          vaxis.Vaxis.new(vaxis.VaxisOptions{})
		timers:      []Tick{}
		wants_focus: none
	}
}

fn app_routing_fidelity_surface(widget Widget) Surface {
	return Surface{
		widget:   widget
		size:     Size{
			width:  2
			height: 2
		}
		buffer:   []vaxis.Cell{}
		children: []SubSurface{}
	}
}

fn test_app_focus_transition_errors_keep_source_commit_order() {
	mut log := &AppRoutingFidelityLog{}
	mut old := &AppRoutingFidelityWidget{
		name:      'old'
		log:       log
		fail_kind: 'out'
	}
	mut next := &AppRoutingFidelityWidget{
		name:      'next'
		log:       log
		fail_kind: 'in'
	}
	mut handler := FocusHandler.new(old.widget())
	handler.path_to_focused = [old.widget()]
	mut ctx := EventContext{
		phase: .bubbling
		cmds:  []Command{}
	}
	mut failed := false
	handler.focus_widget(mut ctx, next.widget()) or {
		assert err.msg() == 'fixture out'
		failed = true
	}
	assert failed
	assert handler.focused_widget.eql(old.widget())
	assert handler.path_to_focused.len == 1 && handler.path_to_focused[0].eql(old.widget())
	assert ctx.phase == .at_target
	assert log.items == ['old:at_target:out:0']
	old.fail_kind = ''
	log.items.clear()
	failed = false
	handler.focus_widget(mut ctx, next.widget()) or {
		assert err.msg() == 'fixture in'
		failed = true
	}
	assert failed
	assert handler.focused_widget.eql(next.widget())
	assert handler.path_to_focused.len == 1 && handler.path_to_focused[0].eql(old.widget())
	assert log.items == ['old:at_target:out:0', 'next:at_target:in:0']
	// Equality returns before another FocusIn, even after that callback failed.
	log.items.clear()
	handler.focus_widget(mut ctx, next.widget()) or { panic(err) }
	assert log.items.len == 0
}

fn test_app_missing_focus_preserves_source_empty_path_and_outer_root() {
	log := &AppRoutingFidelityLog{}
	root := &AppRoutingFidelityWidget{
		name: 'root'
		log:  log
	}
	missing := &AppRoutingFidelityWidget{
		name: 'missing'
		log:  log
	}
	other := &AppRoutingFidelityWidget{
		name: 'other'
		log:  log
	}
	mut handler := FocusHandler.new(root.widget())
	handler.focused_widget = missing.widget()
	handler.path_to_focused = [missing.widget(), root.widget()]
	handler.update(Surface.empty(root.widget()))
	// The source comment promises refocusing, but the executable code does not.
	assert handler.path_to_focused.len == 0
	assert handler.focused_widget.eql(missing.widget())
	handler.update(Surface.empty(other.widget()))
	assert handler.path_to_focused.len == 1
	assert handler.path_to_focused[0].eql(root.widget())
	assert handler.focused_widget.eql(missing.widget())
}

fn test_app_focus_capture_error_keeps_phase_and_stops_target() {
	log := &AppRoutingFidelityLog{}
	root := &AppRoutingFidelityWidget{
		name: 'root'
		log:  log
	}
	child := &AppRoutingFidelityWidget{
		name:      'child'
		log:       log
		fail_kind: 'event'
	}
	mut handler := FocusHandler.new(root.widget())
	handler.focused_widget = child.widget()
	handler.path_to_focused = [root.widget(), child.widget()]
	mut ctx := EventContext{
		phase: .bubbling
		cmds:  []Command{}
	}
	mut failed := false
	handler.handle_event(mut ctx, Event(InitEvent{})) or {
		assert err.msg() == 'fixture event'
		failed = true
	}
	assert failed
	assert ctx.phase == .capturing
	assert log.items == ['root:capturing:event:0', 'child:capturing:event:0']
}

fn test_app_mouse_enter_leave_errors_keep_hits_and_pending_commands() {
	for failing_kind in ['leave', 'enter'] {
		log := &AppRoutingFidelityLog{}
		old := &AppRoutingFidelityWidget{
			name:        'old'
			log:         log
			queue_focus: true
			fail_kind:   if failing_kind == 'leave' { 'leave' } else { '' }
		}
		next := &AppRoutingFidelityWidget{
			name:        'next'
			log:         log
			queue_focus: true
			fail_kind:   if failing_kind == 'enter' { 'enter' } else { '' }
		}
		mut app := app_routing_fidelity_app()
		defer { app.vx.deinit() }
		mut handler := MouseHandler.new(old.widget())
		handler.last_frame = app_routing_fidelity_surface(next.widget())
		handler.last_hit_list = [
			HitResult{
				local:  Point{
					row: 0
					col: 0
				}
				widget: old.widget()
			},
		]
		mut ctx := EventContext{
			phase: .bubbling
			cmds:  []Command{}
		}
		mut failed := false
		handler.handle_mouse(mut app, mut ctx, vaxis.Mouse{ row: 1, col: 1 }) or {
			assert err.msg() == 'fixture ${failing_kind}'
			failed = true
		}
		assert failed
		mouse := handler.mouse or { panic('missing mouse') }
		assert mouse.row == 1 && mouse.col == 1
		assert handler.last_hit_list.len == 1 && handler.last_hit_list[0].widget.eql(old.widget())
		assert ctx.phase == .bubbling
		assert ctx.cmds.len == 1
		if failing_kind == 'leave' {
			assert app.wants_focus == none
			assert log.items == ['old:bubbling:leave:0']
		} else {
			focus := app.wants_focus or { panic('missing earlier command') }
			assert focus.eql(old.widget())
			assert log.items == ['old:bubbling:leave:0', 'next:bubbling:enter:0']
		}
	}
}

fn test_app_mouse_enter_consumption_still_reaches_first_target() {
	mut log := &AppRoutingFidelityLog{}
	value := &AppRoutingFidelityWidget{
		name:         'target'
		log:          log
		queue_focus:  true
		consume_kind: 'enter'
	}
	mut app := app_routing_fidelity_app()
	defer { app.vx.deinit() }
	mut handler := MouseHandler.new(value.widget())
	handler.last_frame = app_routing_fidelity_surface(value.widget())
	mut ctx := EventContext{
		phase: .capturing
		cmds:  []Command{}
	}
	handler.handle_mouse(mut app, mut ctx, vaxis.Mouse{ row: 1, col: 1 }) or { panic(err) }
	assert log.items == ['target:capturing:enter:0', 'target:at_target:mouse:0']
	assert ctx.consume_event && ctx.cmds.len == 0
	assert handler.last_hit_list.len == 1
	log.items.clear()
	handler.mouse_exit(mut app, mut ctx) or { panic(err) }
	handler.mouse_exit(mut app, mut ctx) or { panic(err) }
	assert log.items == ['target:at_target:leave:0', 'target:at_target:leave:0']
	assert handler.last_hit_list.len == 1 && handler.mouse != none
}

fn test_app_focus_source_assertions_survive_production() {
	mode := os.getenv('WITTY_APP_ROUTING_ASSERTION')
	if mode != '' {
		log := &AppRoutingFidelityLog{}
		value := &AppRoutingFidelityWidget{
			name: 'target'
			log:  log
		}
		mut widget := value.widget()
		widget.event_handler = none
		mut handler := FocusHandler.new(widget)
		mut ctx := EventContext{
			phase: .bubbling
			cmds:  []Command{}
		}
		if mode == 'missing-handler' {
			// Source asserts before equality, including its already-focused widget.
			handler.focus_widget(mut ctx, widget) or { panic(err) }
		} else if mode == 'empty-path' {
			handler.handle_event(mut ctx, Event(InitEvent{})) or { panic(err) }
		}
		panic('UNEXPECTED assertion returned')
	}
	for assertion in ['missing-handler', 'empty-path'] {
		mut process := os.new_process(os.executable())
		mut env := os.environ()
		env['WITTY_APP_ROUTING_ASSERTION'] = assertion
		process.set_environment(env)
		process.set_redirect_stdio()
		process.wait()
		stdout := process.stdout_slurp()
		stderr := process.stderr_slurp()
		assert process.code != 0
		process.close()
		assert stdout == ''
		assert !stderr.contains('UNEXPECTED')
		assert stderr.split_into_lines().any(it == 'V panic: Assertion failed')
	}
}
