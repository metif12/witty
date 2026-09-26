module core

import apprt
import configpkg
import datastruct
import input
import terminal

struct AppWakeupProbe {
mut:
	count int
}

fn app_wakeup_probe(data voidptr) {
	mut probe := unsafe { &AppWakeupProbe(data) }
	probe.count++
}

fn make_test_app() App {
	return App{
		mailbox: MailboxQueue.create() or { panic(err) }
	}
}

// fake_surface returns a distinct surface identity for queue-order tests. The
// app mailbox stores the pointer without dereferencing it.
fn fake_surface(id int) &Surface {
	return unsafe { &Surface(voidptr(usize(id + 1))) }
}

fn redraw_target(msg Message) &Surface {
	match msg {
		RedrawSurfaceMsg {
			return msg.surface
		}
		else {
			panic('unexpected app mailbox message')
		}
	}
}

fn app_mailbox_push_forever_for_test(queue_ptr voidptr, done chan bool) {
	mut queue := unsafe { &MailboxQueue(queue_ptr) }
	assert queue.push(Message(RedrawSurfaceMsg{ surface: fake_surface(999) }), datastruct.blocking_queue_forever) == app_mailbox_capacity
	done <- true
}

fn test_runtime_app_records_actions_and_quit_timer() ! {
	mut runtime := apprt.RuntimeApp{}
	runtime.perform_action(apprt.Target(apprt.AppTarget{}), .quit_timer, apprt.ActionValue(apprt.QuitTimer.start))!
	assert runtime.actions.len == 1
	assert runtime.actions[0].action == .quit_timer
	assert runtime.quit_timer_running
	runtime.perform_action(apprt.Target(apprt.AppTarget{}), .quit_timer, apprt.ActionValue(apprt.QuitTimer.stop))!
	assert !runtime.quit_timer_running
}

fn test_app_initialized_font_grid_set_is_empty_at_teardown() ! {
	mut app := App{}
	app.init()!
	assert app.font_grid_set.count() == 0
	app.deinit()
}

fn test_app_mailbox_dispatches_open_config() ! {
	mut app := make_test_app()
	mut runtime := apprt.RuntimeApp{}
	_ = app.mailbox.push(Message(OpenConfigMsg{}), datastruct.blocking_queue_forever)
	app.tick(mut runtime)!
	assert runtime.actions.len == 1
	assert runtime.actions[0].action == .open_config
}

fn test_app_mailbox_push_wakes_runtime() {
	mut probe := AppWakeupProbe{}
	mut runtime := apprt.RuntimeApp{
		user_data: &probe
		wakeup_fn: app_wakeup_probe
	}
	mut queue := MailboxQueue.create() or { panic(err) }
	defer {
		queue.destroy()
	}
	app_mailbox := Mailbox{
		rt_app:  &runtime
		mailbox: queue
	}
	assert app_mailbox.push(Message(QuitMsg{}), datastruct.blocking_queue_instant) == 1
	assert probe.count == 1
	assert app_mailbox.push(Message(QuitMsg{}), datastruct.blocking_queue_instant) == 2
	assert probe.count == 2
}

fn test_app_color_scheme_change_requests_soft_reload() ! {
	mut app := App{}
	mut runtime := apprt.RuntimeApp{}
	app.color_scheme_event(mut runtime, .dark)!

	assert runtime.actions.len == 1
	assert runtime.actions[0].action == .reload_config
	assert action_value[apprt.ReloadConfig](runtime.actions[0].data).soft
	app.color_scheme_event(mut runtime, .dark)!
	assert runtime.actions.len == 1
}

fn test_app_mailbox_is_bounded_fifo_and_reusable() {
	mut queue := MailboxQueue.create() or { panic(err) }
	defer {
		queue.destroy()
	}

	assert queue.pop() == none
	for i in 0 .. app_mailbox_capacity {
		assert queue.push(Message(RedrawSurfaceMsg{ surface: fake_surface(i) }), datastruct.blocking_queue_instant) == u32(i + 1)
	}
	assert queue.push(Message(RedrawSurfaceMsg{ surface: fake_surface(999) }), datastruct.blocking_queue_instant) == 0
	assert queue.len() == app_mailbox_capacity

	for i in 0 .. app_mailbox_capacity {
		msg := queue.pop() or {
			assert false, 'message ${i} missing'
			return
		}
		assert voidptr(redraw_target(msg)) == voidptr(fake_surface(i))
	}
	assert queue.pop() == none
	assert queue.push(Message(RedrawSurfaceMsg{ surface: fake_surface(64) }), datastruct.blocking_queue_instant) == 1
	msg := queue.pop() or {
		assert false
		return
	}
	assert voidptr(redraw_target(msg)) == voidptr(fake_surface(64))
}

fn test_app_mailbox_blocking_push_waits_for_capacity() {
	mut queue := MailboxQueue.create() or { panic(err) }
	defer {
		queue.destroy()
	}
	for i in 0 .. app_mailbox_capacity {
		assert queue.push(Message(RedrawSurfaceMsg{ surface: fake_surface(i) }), datastruct.blocking_queue_instant) == u32(i + 1)
	}

	done := chan bool{cap: 1}
	worker := spawn app_mailbox_push_forever_for_test(voidptr(queue), done)
	first := queue.pop() or {
		assert false
		return
	}
	assert voidptr(redraw_target(first)) == voidptr(fake_surface(0))
	worker.wait()
	assert <-done
	assert queue.len() == app_mailbox_capacity
	for _ in 1 .. app_mailbox_capacity {
		_ = queue.pop() or {
			assert false
			return
		}
	}
	last := queue.pop() or {
		assert false
		return
	}
	assert voidptr(redraw_target(last)) == voidptr(fake_surface(999))
}

fn test_app_present_surface_message_ignores_stale_pointer() ! {
	mut app := make_test_app()
	mut runtime := apprt.RuntimeApp{}
	stale := unsafe { &Surface(voidptr(usize(0xdeadbeef))) }
	_ = app.mailbox.push(Message(SurfaceMessageMsg{
		surface: stale
		message: apprt.SurfaceMessagePresentSurface{}
	}), datastruct.blocking_queue_forever)
	assert app.mailbox.len() == 1
	app.tick(mut runtime)!
	assert app.mailbox.len() == 0
	assert runtime.actions.len == 0
}

fn test_renderer_wakeup_routes_core_pointer_to_runtime_render() ! {
	mut app := make_test_app()
	mut runtime := apprt.RuntimeApp{}
	mut core_surface := Surface{ app: &app }
	mut surface := &SurfaceRef{ core_surface: &core_surface }
	app.surfaces = SurfaceList([surface])

	surface_renderer_wakeup(voidptr(&core_surface))
	assert app.mailbox.len() == 1
	app.tick(mut runtime)!
	assert runtime.actions.len == 1
	assert runtime.actions[0].action == .render
	target := runtime.actions[0].target
	match target {
		apprt.SurfaceTarget {
			assert target.surface == voidptr(&core_surface)
		}
		else {
			assert false, 'expected surface render target'
		}
	}
}

fn test_renderer_wakeup_ignores_stale_core_pointer() ! {
	mut app := make_test_app()
	mut runtime := apprt.RuntimeApp{}
	mut stale_surface := Surface{ app: &app }
	surface_renderer_wakeup(voidptr(&stale_surface))
	app.tick(mut runtime)!
	assert runtime.actions.len == 0
}

fn test_termio_surface_message_routes_core_pointer_to_live_surface() ! {
	mut app := make_test_app()
	mut apprt_runtime := apprt.RuntimeApp{}
	mut probe := AppWakeupProbe{}
	mut core_runtime := apprt.RuntimeApp{
		actions_handled: true
		user_data: &probe
		wakeup_fn: app_wakeup_probe
	}
	mut core_surface := Surface{ rt_app: &core_runtime }
	mut surface := &SurfaceRef{ core_surface: &core_surface }
	app.surfaces = SurfaceList([surface])
	assert termio_surface_message_push(voidptr(&app), voidptr(&core_surface), apprt.SurfaceMessageSetMouseShape{ shape: .pointer }, datastruct.blocking_queue_forever) == 1
	assert probe.count == 1
	app.tick(mut apprt_runtime)!
	assert core_runtime.actions.len == 1
	assert core_runtime.actions[0].action == .mouse_shape
	assert action_value[terminal.MouseShape](core_runtime.actions[0].data) == terminal.MouseShape.pointer
}

fn test_termio_surface_message_ignores_closed_surface() ! {
	mut app := make_test_app()
	mut apprt_runtime := apprt.RuntimeApp{}
	mut stale_surface := Surface{}
	assert termio_surface_message_push(voidptr(&app), voidptr(&stale_surface), apprt.SurfaceMessageRingBell{}, datastruct.blocking_queue_forever) == 1
	app.tick(mut apprt_runtime)!
	assert app.mailbox.len() == 0
}

fn test_termio_surface_message_preserves_instant_timeout() {
	mut app := make_test_app()
	defer { app.mailbox.destroy() }
	for i in 0 .. app_mailbox_capacity {
		assert app.mailbox.push(Message(RedrawSurfaceMsg{ surface: fake_surface(i) }), datastruct.blocking_queue_instant) == u32(i + 1)
	}
	mut surface := Surface{}
	assert termio_surface_message_push(voidptr(&app), voidptr(&surface), apprt.SurfaceMessageRingBell{}, datastruct.blocking_queue_instant) == 0
}

fn test_app_key_event_uses_runtime_config_binding() {
	mut cfg := configpkg.Config.default_config()
	cfg.keybind.set.put(input.Trigger{
		key: input.TriggerKey.new_unicode(u32(`q`))
		mods: input.Mods.init(false, false, false, true, false, false, input.SideInfo{})
	}, input.Action.new(.quit))
	mut runtime := apprt.RuntimeApp{
		config: cfg
	}
	mut app := App{}
	used := app.key_event(mut runtime, input.KeyEvent{
		key: .key_q
		action: .press
		mods: input.Mods.init(false, false, false, true, false, false, input.SideInfo{})
		utf8: 'q'
	})
	assert used
	assert runtime.actions.len == 1
	assert runtime.actions[0].action == .quit
}

fn test_app_key_event_is_binding_includes_leader_entries() {
	mut cfg := configpkg.Config.default_config()
	cfg.keybind.set.parse_and_put('ctrl+a>b=new_window') or { panic(err.msg()) }
	mut runtime := apprt.RuntimeApp{
		config: cfg
	}
	mut app := App{}
	event := input.KeyEvent{
		key: .key_a
		action: .press
		mods: input.Mods.init(false, true, false, false, false, false, input.SideInfo{})
		utf8: 'a'
	}

	// The app scope cannot execute leader sequences, but the top-level leader
	// is still a binding and must not be forwarded as terminal input.
	assert app.key_event_is_binding(mut runtime, event)
	assert !app.key_event(mut runtime, event)
}

fn test_app_new_window_targets_valid_parent() ! {
	mut runtime := apprt.RuntimeApp{}
	mut app := App{}
	mut core_surface := Surface{}
	mut surface := &SurfaceRef{
		core_surface: &core_surface
		rt_app: &runtime
	}
	app.add_surface(surface)
	// Ignore the quit-timer stop generated by add_surface.
	runtime.actions.clear()
	app.new_window(mut runtime, NewWindowMsg{ parent: &core_surface })!
	assert runtime.actions.len == 1
	assert runtime.actions[0].action == .new_window
	target := runtime.actions[0].target
	match target {
		apprt.SurfaceTarget {
			assert target.surface == voidptr(&core_surface)
		}
		else {
			assert false, 'expected surface target'
		}
	}
}

fn test_app_surface_lifecycle_controls_quit_timer() {
	mut runtime := apprt.RuntimeApp{}
	mut app := App{}
	mut core_surface := Surface{}
	mut surface := &SurfaceRef{
		core_surface: &core_surface
		rt_app: &runtime
	}
	app.add_surface(surface)
	assert !runtime.quit_timer_running
	app.delete_surface(surface)
	assert runtime.quit_timer_running
}

fn test_app_delete_surface_uses_swap_remove() {
	mut app := App{}
	mut first := &SurfaceRef{}
	mut second := &SurfaceRef{}
	mut third := &SurfaceRef{}
	app.surfaces = SurfaceList([first, second, third])

	app.delete_surface(first)
	assert app.surfaces.len == 2
	assert voidptr(app.surfaces[0]) == voidptr(third)
	assert voidptr(app.surfaces[1]) == voidptr(second)
}

fn test_app_focus_surface_requires_known_core_surface() {
	mut app := App{}
	mut first_core := Surface{}
	mut second_core := Surface{}
	mut first := &SurfaceRef{ core_surface: &first_core }
	mut second := &SurfaceRef{ core_surface: &second_core }
	app.surfaces = SurfaceList([first, second])

	app.focus_surface(&second_core)
	focused := app.focused_surface() or {
		assert false, 'expected a focused surface'
		return
	}
	assert voidptr(focused) == voidptr(&second_core)

	mut unknown := Surface{}
	app.focus_surface(&unknown)
	assert voidptr(app.focused_surface()?) == voidptr(&second_core)

	// Deleting the runtime surface clears focus even if the address is reused.
	app.delete_surface(second)
	assert app.focused_surface() == none
	assert app.last_focused_surface == none
}

// The source reads an action's value as `value.<field>`; V needs the variant.
fn action_value[T](v apprt.ActionValue) T {
	if v is T {
		return v
	}
	panic('action value is not the expected variant')
}
