module gtk

fn test_noop_window_update_config_event_is_a_noop() {
	mut window := NoopWindow{}
	window.update_config_event(unsafe { nil })!
}
