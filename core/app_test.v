module core

import apprt
import configpkg
import datastruct
import input

struct AppWakeupProbe {
mut:
	count int
}

fn app_wakeup_probe(data voidptr) {
	mut probe := unsafe { &AppWakeupProbe(data) }
	probe.count++
}

fn app_mailbox_push_forever_for_test(mailbox_ptr voidptr, done chan bool) {
	mut mailbox := unsafe { &Mailbox(mailbox_ptr) }
	assert mailbox.push(Message(PresentSurfaceMsg{ address: 999 })) == app_mailbox_capacity
	done <- true
}

fn test_runtime_app_records_actions_and_quit_timer() ! {
	mut runtime := apprt.RuntimeApp{}
	runtime.perform_action(apprt.Target(apprt.AppTarget{}), .quit_timer, apprt.ActionValue{
		quit_timer_: .start
	})!
	assert runtime.actions.len == 1
	assert runtime.actions[0].action == .quit_timer
	assert runtime.quit_timer_running
	runtime.perform_action(apprt.Target(apprt.AppTarget{}), .quit_timer, apprt.ActionValue{
		quit_timer_: .stop
	})!
	assert !runtime.quit_timer_running
}

fn test_app_mailbox_dispatches_open_config() ! {
	mut app := App{}
	mut runtime := apprt.RuntimeApp{}
	app.request_open_config()
	app.tick(mut runtime)!
	assert runtime.actions.len == 1
	assert runtime.actions[0].action == .open_config
}

fn test_app_color_scheme_change_requests_soft_reload() ! {
	mut app := App{}
	mut runtime := apprt.RuntimeApp{}
	app.color_scheme_event(mut runtime, .dark)!

	assert runtime.actions.len == 1
	assert runtime.actions[0].action == .reload_config
	assert runtime.actions[0].data.reload_config_.soft
	app.color_scheme_event(mut runtime, .dark)!
	assert runtime.actions.len == 1
}

fn test_app_mailbox_is_bounded_fifo_and_reusable() {
	mut mailbox := Mailbox.init()
	defer {
		mailbox.deinit()
	}

	assert mailbox.pop() == none
	for i in 0 .. app_mailbox_capacity {
		assert mailbox.try_push(Message(PresentSurfaceMsg{ address: u64(i) })) == i + 1
	}
	assert mailbox.try_push(Message(PresentSurfaceMsg{ address: 999 })) == 0
	assert mailbox.len() == app_mailbox_capacity

	for i in 0 .. app_mailbox_capacity {
		msg := mailbox.pop() or {
			assert false, 'message ${i} missing'
			return
		}
		match msg {
			PresentSurfaceMsg {
				assert msg.address == u64(i)
			}
			else {
				assert false, 'unexpected app mailbox message'
			}
		}
	}
	assert mailbox.pop() == none
	assert mailbox.try_push(Message(PresentSurfaceMsg{ address: 64 })) == 1
	msg := mailbox.pop() or {
		assert false
		return
	}
	match msg {
		PresentSurfaceMsg {
			assert msg.address == 64
		}
		else {
			assert false
		}
	}
}

fn test_app_mailbox_blocking_push_waits_for_capacity() {
	mut mailbox := Mailbox.init()
	defer {
		mailbox.deinit()
	}
	for i in 0 .. app_mailbox_capacity {
		assert mailbox.try_push(Message(PresentSurfaceMsg{ address: u64(i) })) == i + 1
	}

	done := chan bool{ cap: 1 }
	worker := spawn app_mailbox_push_forever_for_test(voidptr(&mailbox), done)
	first := mailbox.pop() or {
		assert false
		return
	}
	match first {
		PresentSurfaceMsg {
			assert first.address == 0
		}
		else {
			assert false
		}
	}
	worker.wait()
	assert <-done
	assert mailbox.len() == app_mailbox_capacity
	for _ in 1 .. app_mailbox_capacity {
		_ = mailbox.pop() or {
			assert false
			return
		}
	}
	last := mailbox.pop() or {
		assert false
		return
	}
	match last {
		PresentSurfaceMsg {
			assert last.address == 999
		}
		else {
			assert false
		}
	}
}

fn test_app_present_surface_request_ignores_stale_address() ! {
	mut app := App{}
	mut runtime := apprt.RuntimeApp{}
	app.request_present_surface(0xdeadbeef)
	assert app.pending_message_count() == 1
	app.tick(mut runtime)!
	assert app.pending_message_count() == 0
}

fn test_renderer_wakeup_routes_core_pointer_to_runtime_render() ! {
	mut app := App{}
	mut runtime := apprt.RuntimeApp{}
	mut core_surface := Surface{ app: &app }
	mut surface := &SurfaceRef{ core_surface: &core_surface }
	app.surfaces = SurfaceList([surface])

	surface_renderer_wakeup(voidptr(&core_surface))
	assert app.pending_message_count() == 1
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
	mut app := App{}
	mut runtime := apprt.RuntimeApp{}
	mut stale_surface := Surface{ app: &app }
	surface_renderer_wakeup(voidptr(&stale_surface))
	app.tick(mut runtime)!
	assert runtime.actions.len == 0
}

fn test_termio_surface_message_routes_core_pointer_to_live_surface() ! {
	mut app := App{}
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
	assert termio_surface_message_push(voidptr(&app), voidptr(&core_surface), apprt.SurfaceMessage{
		kind: .set_mouse_shape
		mouse_shape: .pointer
	}, datastruct.blocking_queue_forever) == 1
	assert probe.count == 1
	app.tick(mut apprt_runtime)!
	assert core_runtime.actions.len == 1
	assert core_runtime.actions[0].action == .mouse_shape
	assert core_runtime.actions[0].data.mouse_shape_ == .pointer
}

fn test_termio_surface_message_ignores_closed_surface() ! {
	mut app := App{}
	mut apprt_runtime := apprt.RuntimeApp{}
	mut stale_surface := Surface{}
	assert termio_surface_message_push(voidptr(&app), voidptr(&stale_surface), apprt.SurfaceMessage{
		kind: .ring_bell
	}, datastruct.blocking_queue_forever) == 1
	app.tick(mut apprt_runtime)!
	assert app.pending_message_count() == 0
}

fn test_termio_surface_message_preserves_instant_timeout() {
	mut app := App{}
	defer { app.mailbox.deinit() }
	for i in 0 .. app_mailbox_capacity {
		assert app.mailbox.try_push(Message(PresentSurfaceMsg{ address: u64(i) })) == i + 1
	}
	mut surface := Surface{}
	assert termio_surface_message_push(voidptr(&app), voidptr(&surface), apprt.SurfaceMessage{
		kind: .ring_bell
	}, datastruct.blocking_queue_instant) == 0
}

fn test_app_key_event_uses_runtime_config_binding() {
	mut cfg := configpkg.Config.default_config()
	cfg.keybind.set.put(input.Trigger{
		key: input.TriggerKey.new_unicode(u32(`q`))
		mods: input.Mods{ super_: true }
	}, input.Action.new(.quit))
	mut runtime := apprt.RuntimeApp{
		config: cfg
	}
	mut app := App{}
	used := app.key_event(mut runtime, input.KeyEvent{
		key: .key_q
		action: .press
		mods: input.Mods{ super_: true }
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
		mods: input.Mods{ ctrl: true }
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
	app.new_window(mut runtime, NewWindowMsg{ parent: surface })!
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

fn test_app_focus_core_surface_resolves_runtime_wrapper() {
	mut app := App{}
	mut first_core := Surface{}
	mut second_core := Surface{}
	mut first := &SurfaceRef{ core_surface: &first_core }
	mut second := &SurfaceRef{ core_surface: &second_core }
	app.surfaces = SurfaceList([first, second])

	app.focus_core_surface(&second_core)
	focused := app.focused_surface_valid() or {
		assert false, 'expected a focused surface'
		return
	}
	assert voidptr(focused) == voidptr(second)

	mut unknown := Surface{}
	app.focus_core_surface(&unknown)
	assert voidptr(app.focused_surface_valid()?) == voidptr(second)
}
