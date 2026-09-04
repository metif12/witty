module inspector

import cimgui
import input

const test_font = $embed_file('@VMODROOT/font/res/JetBrainsMono-Regular.ttf').to_bytes()

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

fn test_inspector_renders_key_stream_into_real_imgui_frame() {
	if !cimgui.available() {
		return
	}
	context := cimgui.Context.create(test_font)!
	defer {
		context.destroy()
	}
	context.set_size(800, 600)
	assert context.build_font_atlas()
	mut value := Inspector.init()!
	defer {
		value.deinit()
	}
	mut event := KeyEvent.init(input.KeyEvent{
		action: .press
		key: .key_a
		mods: input.Mods{ shift: true, super_: true }
		utf8: 'A'
	})
	event.binding = [input.Action.new(.copy_to_clipboard)]
	event.pty = [u8(`A`)]
	value.record_key_event(event)

	context.begin_frame(1.0 / 60.0)
	value.render(context.handle)
	dockspace_id := context.get_id('Main Dockspace')
	assert context.dock_node_exists(dockspace_id)
	context.render_frame()
}

fn test_key_stream_colors_match_pinned_ghostty() {
	assert action_color(.press) == u32(0x1a4a6f4a)
	assert action_color(.release) == u32(0x1a6a5a5a)
	assert action_color(.repeat) == u32(0x1a4a5a6f)
	assert hsv_to_rgba(0, 0.5, 0.9, 1) == u32(0xff7272e5)
}
