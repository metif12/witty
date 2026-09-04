module inspector

import input

fn test_key_event_owns_data_and_formats_details() {
	mut source := input.KeyEvent{
		action: .press
		key: .unidentified
		mods: input.Mods{ shift: true, ctrl: true }
		composing: true
		utf8: 'é'
	}
	mut event := KeyEvent.init(source)
	source.utf8 = 'changed'
	event.binding = [input.Action.new(.copy_to_clipboard)]
	event.pty = [u8(0x1b), `a`, u8(0), u8(0x20), u8(0x7f)]

	assert event.event.utf8 == 'é'
	assert event.label() == 'Press: Shift+Ctrl+é (composing)'
	assert event.utf8_codepoints() == 'U+E9 '
	assert event.pty_text() == 'ESC a0x0 0x20 0x7F '

	event.deinit()
	assert event.event.utf8 == ''
	assert event.binding.len == 0
	assert event.pty.len == 0
}

fn test_inspector_key_stream_is_bounded_and_evicts_oldest() {
	mut value := Inspector.init()!
	defer {
		value.deinit()
	}
	for index in 0 .. 75 {
		assert value.record_key_event(KeyEvent.init(input.KeyEvent{
			key: .key_a
			utf8: index.str()
		}))
	}
	assert value.key_events.len == max_key_events
	assert value.key_events[0].event.utf8 == '25'
	assert value.key_events[49].event.utf8 == '74'

	value.clear_key_events()
	assert value.key_events.len == 0
}
