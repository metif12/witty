@[has_globals]
module macos

fn test_search_grapheme_debounce_boundary() {
	assert composed_character_count('') == 0
	assert composed_character_count('ab') == 2
	assert composed_character_count('abc') == 3
	assert composed_character_count('a\u0301b') == 2
	assert composed_character_count('👨‍👩‍👧‍👦') == 1
}

fn test_source_key_context_stack_order() {
	mut state := &NativeActionSurface{
		closed: true
	}
	state.set_key_table(0, 'first')
	state.set_key_table(0, 'second')
	assert state.key_tables == ['first', 'second']
	state.set_key_table(1, '')
	assert state.key_tables == ['first']
	state.set_key_table(2, '')
	assert state.key_tables.len == 0
	state.set_key_table(1, '')
	assert state.key_tables.len == 0
	state.set_key_sequence(true, '⌘K')
	state.set_key_sequence(true, '⌘C')
	assert state.key_sequence == ['⌘K', '⌘C']
	state.set_key_sequence(false, '')
	assert state.key_sequence.len == 0
}

__global audit_native_actions = []string{}

fn audit_action_binding(_userdata voidptr, action string) bool {
	audit_native_actions << action
	return true
}

fn test_native_search_editor_and_timer_consumers() {
	app_init()
	view := create_window(640, 480, '')
	mut surface := new_action_surface(view, unsafe { nil }, ActionCallbacks{
		binding: audit_action_binding
	})
	defer {
		surface.deinit()
		close_tab(view)
	}
	audit_native_actions.clear()
	surface.start_search('ab')
	assert surface.search_active
	assert audit_native_actions.len == 0
	assert msg_f64(msg_id(surface.search_timer, 'fireDate'), 'timeIntervalSinceNow') > 0.2
	pending := surface.search_timer
	surface.start_search('abc')
	assert !msg_bool(pending, 'isValid')
	assert audit_native_actions == ['search:abc']
	surface.start_search('')
	assert surface.search_needle == 'abc'
	assert audit_native_actions == ['search:abc']
	surface.search_counts(uint(2), uint(5))
	assert objc_utf8_string(msg_id(surface.search_count, 'stringValue')) == '3/5'
	surface.search_counts(none, uint(0))
	assert objc_utf8_string(msg_id(surface.search_count, 'stringValue')) == '-/0'
	surface.search_counts(uint(0), none)
	assert objc_utf8_string(msg_id(surface.search_count, 'stringValue')) == '1/?'
	// Native control notifications update state through the registered delegate.
	msg_void1(surface.search_field, 'setStringValue:', nsstring('x'))
	action_search_edit(surface.owner, sel('controlTextDidChange:'), nil_obj())
	assert surface.search_needle == 'x'
	msg_void(surface.search_timer, 'fire')
	assert audit_native_actions.last() == 'search:x'
	surface.end_search()
	assert audit_native_actions.last() == 'end_search'
	assert !surface.search_active
	surface.end_search()
	assert audit_native_actions.filter(it == 'end_search').len == 1
	surface.set_progress(1, u8(25))
	assert msg_f64(msg_id(surface.progress_timer, 'fireDate'), 'timeIntervalSinceNow') > 14
	first := surface.progress_timer
	surface.set_progress(2, none)
	assert !msg_bool(first, 'isValid')
	msg_void(surface.progress_timer, 'fire')
	assert !surface.progress_active
	surface.set_progress(1, u8(25))
	removed := surface.progress_timer
	surface.set_progress(99, u8(25))
	assert !msg_bool(removed, 'isValid')
	assert !surface.progress_active
	assert surface.progress_state == 0
	assert surface.progress == none
	surface.ring_bell()
	assert surface.bell
	surface.begin_key_down()
	assert !surface.bell
	surface.ring_bell()
	surface.focus(true)
	assert !surface.bell
}
