module gtk

import apprt
import configpkg
import core
import input

fn test_application_accelerator_uses_reverse_keybind_lookup() {
	mut cfg := configpkg.Config{}
	cfg.keybind.parse_cli('ctrl+shift+a=new_split:left')!
	app := Application{
		config: cfg
	}
	action := input.Action.new_enum(.new_split, i32(input.SplitDirection.left))

	assert app.accelerator_for_action(action) or { '' } == '<Shift><Ctrl>a'
	assert app.accelerator_for_action(input.Action.new_enum(.new_split, i32(input.SplitDirection.right))) == none
}

fn test_application_accelerator_ignores_chained_binding() {
	mut cfg := configpkg.Config{}
	cfg.keybind.parse_cli('global:ctrl+b=ignore')!
	cfg.keybind.parse_cli('chain=new_window')!
	app := Application{
		config: cfg
	}

	assert app.accelerator_for_action(input.Action.new(.ignore)) == none
	assert app.accelerator_for_action(input.Action.new(.new_window)) == none
}

fn test_application_quit_timer_without_delay_expires_immediately() {
	mut app := Application{
		config: configpkg.Config{
			quit_after_last_window_closed: true
		}
	}
	app.start_quit_timer()
	assert app.quit_timer_state == .expired
}

fn test_application_quit_timer_callback_marks_expired() {
	mut app := Application{
		quit_timer_state: .active
		quit_timer_source: 42
	}
	assert handle_quit_timer_expired(voidptr(&app)) == 0
	assert app.quit_timer_state == .expired
	assert app.quit_timer_source == 0
}

fn test_application_cgroup_mode_gate() {
	assert !cgroup_isolation_enabled(.never, g_application_default_flags)
	assert cgroup_isolation_enabled(.always, g_application_non_unique)
	assert cgroup_isolation_enabled(.single_instance, g_application_default_flags)
	assert !cgroup_isolation_enabled(.single_instance, g_application_non_unique)
}

fn test_application_activate_queues_new_window() {
	mut core_app := &core.App{}
	mut app := Application{
		core_app: core_app
	}
	assert core_app.pending_message_count() == 0
	app.activate()
	assert core_app.pending_message_count() == 1
}

fn test_application_action_table_matches_ghostty() {
	string_array_type := C.g_variant_type_new(c'as')
	u64_type := C.g_variant_type_new(c't')
	actions := application_action_descriptors(string_array_type, u64_type)
	assert actions.map(it.name) == [
		'new-window',
		'new-window-command',
		'open-config',
		'present-surface',
		'quit',
		'reload-config',
	]
	assert isnil(actions[0].parameter_type)
	assert actions[1].parameter_type == string_array_type
	assert actions[3].parameter_type == u64_type
	C.g_variant_type_free(string_array_type)
	C.g_variant_type_free(u64_type)
}

fn test_application_action_callbacks_queue_core_messages() {
	mut core_app := &core.App{}
	mut app := Application{
		core_app: core_app
	}
	application_action_new_window_cb(unsafe { nil }, unsafe { nil }, voidptr(&app))
	application_action_open_config_cb(unsafe { nil }, unsafe { nil }, voidptr(&app))
	assert core_app.pending_message_count() == 2
}

fn test_application_dispatches_core_runtime_actions() ! {
	mut app := Application{
		config: configpkg.Config{
			quit_after_last_window_closed: true
		}
	}
	app.runtime_bridge.actions << apprt.RuntimeAction{
		target: apprt.Target(apprt.AppTarget{})
		action: .quit_timer
		data: apprt.ActionValue{
			quit_timer_: .start
		}
	}
	app.dispatch_runtime_actions()!
	assert app.runtime_bridge.actions.len == 0
	assert app.quit_timer_state == .expired

	app.runtime_bridge.actions << apprt.RuntimeAction{
		target: apprt.Target(apprt.AppTarget{})
		action: .quit_timer
		data: apprt.ActionValue{
			quit_timer_: .stop
		}
	}
	app.dispatch_runtime_actions()!
	assert app.quit_timer_state == .off
}

fn test_application_sigusr2_callback_continues_without_instance() {
	assert application_sigusr2_cb(unsafe { nil }) == 1
}

fn test_application_quit_without_confirmation_stops_runloop() {
	mut app := Application{
		running: true
	}
	app.quit()
	assert !app.running
}
