module inspector

import cimgui
import input
import osc
import terminal

const test_font = $embed_file('@VMODROOT/font/res/JetBrainsMono-Regular.ttf').to_bytes()

fn test_to_kibi_bytes_matches_source_integer_conversion() {
	assert to_kibi_bytes(0) == 0
	assert to_kibi_bytes(1023) == 0
	assert to_kibi_bytes(1024) == 1
	assert to_kibi_bytes(usize(1024) * 17 + 999) == 17
}

fn test_key_event_owns_data_and_formats_details() {
	mut source := input.KeyEvent{
		action:    .press
		key:       .unidentified
		mods:      input.Mods.init(true, true, false, false, false, false, input.SideInfo{})
		composing: true
		utf8:      'é'
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
			key:  .key_a
			utf8: index.str()
		}))
	}
	assert value.key_events.len == max_key_events
	assert value.key_events[0].event.utf8 == '25'
	assert value.key_events[49].event.utf8 == '74'

	value.clear_key_events()
	assert value.key_events.len == 0
}

fn test_renderer_overlay_features_preserve_activation_order() {
	mut value := RendererInfo{}
	value.set_feature(.semantic_prompts, true)
	value.set_feature(.highlight_hyperlinks, true)
	value.set_feature(.semantic_prompts, true)
	assert value.overlay_features() == [.semantic_prompts, .highlight_hyperlinks]

	value.set_feature(.semantic_prompts, false)
	assert value.overlay_features() == [.highlight_hyperlinks]
}

fn test_inspector_public_renderer_info_and_pty_read_entry_points() {
	mut term := terminal.Terminal.init(terminal.Options{
		cols: 80
		rows: 24
	})!
	defer {
		term.deinit()
	}
	mut value := Inspector.init()!
	defer {
		value.deinit()
	}

	mut renderer_info := value.renderer_info()
	renderer_info.set_feature(.semantic_prompts, true)
	assert value.renderer.overlay_features() == [.semantic_prompts]

	term.screens.active.cursor.x = 9
	value.record_pty_read(&term, '\x1b[2C'.bytes())!
	assert value.vt_stream.events.len == 1
	assert value.vt_stream.events[0].raw_description == '2 C'
	assert value.vt_stream.events[0].cursor.x == 9
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
		key:    .key_a
		mods:   input.Mods.init(true, false, false, true, false, false, input.SideInfo{})
		utf8:   'A'
	})
	event.binding = [input.Action.new(.copy_to_clipboard)]
	event.pty = [u8(`A`)]
	value.record_key_event(event)
	mut term := terminal.Terminal.init(terminal.Options{
		cols: 80
		rows: 24
	})!
	defer {
		term.deinit()
	}
	value.terminal_info.screens[.primary] = ScreenInfo{}

	context.begin_frame(1.0 / 60.0)
	value.render(context.handle, SurfaceInfo{
		screen_width:     800
		screen_height:    600
		grid_columns:     80
		grid_rows:        24
		cell_width:       10
		cell_height:      20
		font_points:      13
		font_pixels:      17.333
		hover_grid_x:     4
		hover_grid_y:     5
		hover_terminal_x: 40
		hover_terminal_y: 100
		click_grid_x:     4
		click_grid_y:     5
		left_click_xpos:  40
		left_click_ypos:  100
	}, mut term)
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

fn test_pagelist_inspector_max_coord_tracks_regions() {
	mut term := terminal.Terminal.init(terminal.Options{
		cols: 3
		rows: 2
	})!
	defer {
		term.deinit()
	}
	assert max_coord(&term.screens.active.pages, .active) or { panic('active region must exist') } == terminal.Coordinate{
		x: 2
		y: 1
	}
	assert max_coord(&term.screens.active.pages, .history) == none

	// Scroll one row into history.
	term.print_string('a\nb\nc')!
	assert max_coord(&term.screens.active.pages, .active) or { panic('active region must exist') } == terminal.Coordinate{
		x: 2
		y: 1
	}
	assert max_coord(&term.screens.active.pages, .history) or { panic('history region must exist') } == terminal.Coordinate{
		x: 2
		y: 0
	}
}

fn test_vt_event_encodings_match_pinned_ghostty() {
	assert encode_vt_action(terminal.ParserAction{
		action_type: .print_action
		char:        u32(`A`)
	}) == "'A' (U+41)"
	assert encode_vt_action(terminal.ParserAction{
		action_type: .execute_action
		byte_val:    0x07
	}) == 'BEL (0x7)'
	assert encode_vt_action(terminal.ParserAction{
		action_type: .execute_action
		byte_val:    0x19
	}) == '? (0x19)'
	assert encode_vt_action(terminal.ParserAction{
		action_type: .csi_dispatch_action
		csi:         terminal.CSIAction{
			intermediates: [u8(`?`)]
			params:        [u16(1), 4]
			final_byte:    u8(`h`)
		}
	}) == '? 1;4 h'
	assert encode_vt_action(terminal.ParserAction{
		action_type: .esc_dispatch_action
		esc:         terminal.ESCAction{
			intermediates: [u8(`(`)]
			final_byte:    u8(`B`)
		}
	}) == '( B'
	osc_action := terminal.ParserAction{
		action_type: .osc_dispatch_action
		osc:         terminal.OscCommand{
			cmd_type:  .hyperlink_start
			hyperlink: osc.HyperlinkStart{
				uri: 'https://example.com'
				id:  'link-id'
			}
		}
	}
	assert encode_vt_action(osc_action) == 'hyperlink_start '
	assert vt_action_metadata(osc_action) == {
		'id':  'link-id'
		'uri': 'https://example.com'
	}
	kitty_sizing := terminal.ParserAction{
		action_type: .osc_dispatch_action
		osc:         terminal.OscCommand{
			cmd_type:          .kitty_text_sizing
			kitty_text_sizing: osc.KittyTextSizing{
				scale:  2
				width:  3
				valign: .bottom
				text:   'hello'
			}
		}
	}
	assert vt_action_metadata(kitty_sizing) == {
		'scale':       '2'
		'width':       '3'
		'numerator':   '0'
		'denominator': '0'
		'valign':      'bottom'
		'halign':      'left'
		'text':        'hello'
	}
}

fn test_vt_stream_filters_snapshots_and_sequence_gaps() {
	mut term := terminal.Terminal.init(terminal.Options{
		cols: 80
		rows: 24
	})!
	defer {
		term.deinit()
	}
	mut stream := VTStream.init()
	defer {
		stream.deinit()
	}

	// Print is excluded by default but still advances the sequence.
	assert stream.vt_raw(terminal.ParserAction{
		action_type: .print_action
		char:        u32(`x`)
	}, &term)
	assert stream.events.len == 0
	term.screens.active.cursor.x = 7
	term.scrolling_region.top = 3
	assert !stream.vt_raw(terminal.ParserAction{
		action_type: .execute_action
		byte_val:    0x07
	}, &term)
	assert stream.events.len == 1
	assert stream.events[0].seq == 2
	assert stream.events[0].cursor.x == 7
	assert stream.events[0].scrolling_region.top == 3
	term.screens.active.cursor.x = 12
	term.scrolling_region.top = 4
	assert stream.events[0].cursor.x == 7
	assert stream.events[0].scrolling_region.top == 3

	stream.paused = true
	assert stream.vt_raw(terminal.ParserAction{
		action_type: .execute_action
		byte_val:    0x08
	}, &term)
	stream.paused = false
	stream.filter_text = 'does-not-match'
	assert stream.vt_raw(terminal.ParserAction{
		action_type: .execute_action
		byte_val:    0x09
	}, &term)
	stream.filter_text = 'bel'
	assert !stream.vt_raw(terminal.ParserAction{
		action_type: .execute_action
		byte_val:    0x07
	}, &term)
	assert stream.events.len == 2
	assert stream.events[1].seq == 5
}

fn test_vt_stream_parallel_parser_records_complete_actions() {
	mut term := terminal.Terminal.init(terminal.Options{
		cols: 80
		rows: 24
	})!
	defer {
		term.deinit()
	}
	mut stream := VTStream.init()
	defer {
		stream.deinit()
	}

	term.screens.active.cursor.x = 9
	for byte in '\x1b[2C'.bytes() {
		stream.record_pty_byte(byte, &term)
	}
	assert stream.events.len == 1
	assert stream.events[0].kind == .csi
	assert stream.events[0].raw_description == '2 C'
	assert stream.events[0].cursor.x == 9
	// The inspector parser only observes; the real terminal parser applies the
	// corresponding semantic action after inspection.
	assert term.screens.active.cursor.x == 9
}

fn test_vt_stream_is_bounded_and_navigation_matches_reverse_table() {
	mut term := terminal.Terminal.init(terminal.Options{
		cols: 2
		rows: 2
	})!
	defer {
		term.deinit()
	}
	mut stream := VTStream.init()
	defer {
		stream.deinit()
	}
	for _ in 0 .. 101 {
		assert !stream.vt_raw(terminal.ParserAction{
			action_type: .execute_action
			byte_val:    0x07
		}, &term)
	}
	assert stream.events.len == max_vt_events
	assert stream.events[0].seq == 2
	assert stream.events[99].seq == 101

	stream.navigate(.down)
	assert stream.selected_event_seq or { u32(0) } == u32(101)
	stream.navigate(.down)
	assert stream.selected_event_seq or { u32(0) } == u32(100)
	stream.navigate(.up)
	assert stream.selected_event_seq or { u32(0) } == u32(101)
	stream.reset()
	assert stream.events.len == 0
	assert stream.current_seq == 1
}

fn test_vt_key_action_layout_matches_source() {
	assert sizeof(VTKeyAction) == 1
	assert [VTKeyAction.down, .none_, .up].map(u8(it)) == [u8(0), 1, 2]
}

fn test_imgui_text_filter_semantics() {
	assert imgui_text_filter_pass('', 'anything')
	assert imgui_text_filter_pass('abc,xyz', 'prefix XYZ suffix')
	assert imgui_text_filter_pass('-abc', 'xyz')
	assert !imgui_text_filter_pass('-abc', 'ABC')
	assert !imgui_text_filter_pass('abc', 'xyz')
	assert !imgui_text_filter_pass('file', 'FİLE')
}
