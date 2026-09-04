module gtk

import configpkg
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
