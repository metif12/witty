module core

import input
import apprt
import terminal
import configpkg
import highlight
import search as searchpkg
import termio as termiopkg
import time
import osc
import crash
import oniguruma
import renderer as rendererpkg

fn test_desktop_notification_digest_matches_source_wyhash_stream() {
	// Ghostty updates one Wyhash state with title and then body, which is
	// equivalent to hashing their concatenated bytes.
	assert desktop_notification_digest('Compiler', 'Build failed') == u64(0x7bd2dcc36d0783fa)
	assert desktop_notification_digest('', '') == u64(0x0409638ee2bde459)
}

fn test_apprt_color_change_matches_source_supported_targets() {
	palette := apprt_color_change(osc.ColoredTarget{
		target: osc.ColorTargetPalette{ index: 42 }
		color: osc.RGB{ r: 1, g: 2, b: 3 }
	}) or { panic('palette color change must be supported') }
	assert int(palette.kind) == 42
	assert palette.r == 1
	assert palette.g == 2
	assert palette.b == 3

	dynamic := apprt_color_change(osc.ColoredTarget{
		target: osc.ColorTargetDynamic{ color: .cursor }
		color: osc.RGB{ r: 4, g: 5, b: 6 }
	}) or { panic('cursor color change must be supported') }
	assert dynamic.kind == .cursor
	assert dynamic.r == 4
	assert dynamic.g == 5
	assert dynamic.b == 6

	assert apprt_color_change(osc.ColoredTarget{
		target: osc.ColorTargetDynamic{ color: .pointer_foreground }
	}) == none
	assert apprt_color_change(osc.ColoredTarget{
		target: osc.ColorTargetSpecial{ color: .bold }
	}) == none
}

fn test_surface_crash_thread_state_carries_main_surface() {
	surface := &Surface{}
	state := surface.crash_thread_state()
	assert state.kind == crash.ThreadType.main
	assert state.surface == voidptr(surface)
}

// Test helper: sets up a 10x5 cell grid with 10x20px cells and 5px padding on all sides.
fn make_test_size() rendererpkg.Size {
	return rendererpkg.Size{
		cell: rendererpkg.CellSize{ width: 10, height: 20 }
		padding: rendererpkg.Padding{ left: 5, top: 5, right: 5, bottom: 5 }
		screen: rendererpkg.ScreenSize{ width: 110, height: 110 }
	}
}

// Test helper: creates a Surface with an initialized terminal (avoids nil deref).
fn make_test_surface() Surface {
	mut t := terminal.Terminal.init(terminal.Options{ cols: 80, rows: 24 }) or { panic(err) }
	return Surface{
		renderer_state: RendererState{
			terminal_: &t
		}
	}
}

fn pop_surface_core_message(mut app App) SurfaceCoreMsg {
	message := app.mailbox.pop() or { panic('missing surface message') }
	match message {
		SurfaceCoreMsg {
			return message
		}
		else {
			panic('unexpected app mailbox message')
		}
	}
}

fn test_search_callback_routes_owned_results_and_ui_state() {
	mut app := App{
		mailbox: Mailbox.init()
	}
	defer {
		app.mailbox.deinit()
	}
	mut surface := Surface{
		app: &app
	}

	surface_search_event(searchpkg.Event{
		kind: .viewport_matches
		viewport_matches: [highlight.FlattenedHighlight.empty()]
	}, voidptr(&surface))
	assert app.mailbox.len() == 0

	surface_search_event(searchpkg.Event{
		kind: .selected_match
		selected: searchpkg.ThreadSelectedMatch{
			idx: 4
			highlight: highlight.FlattenedHighlight.empty()
		}
	}, voidptr(&surface))
	selected := pop_surface_core_message(mut app)
	assert voidptr(selected.surface) == voidptr(&surface)
	assert selected.message.kind == .search_selected
	assert selected.message.search_selected? == 4

	surface_search_event(searchpkg.Event{
		kind: .total_matches
		total: 9
	}, voidptr(&surface))
	total := pop_surface_core_message(mut app)
	assert total.message.kind == .search_total
	assert total.message.search_total? == 9

	surface_search_event(searchpkg.Event{ kind: .quit }, voidptr(&surface))
	cleared_total := pop_surface_core_message(mut app)
	cleared_selected := pop_surface_core_message(mut app)
	assert cleared_total.message.kind == .search_total
	assert cleared_total.message.search_total == none
	assert cleared_selected.message.kind == .search_selected
	assert cleared_selected.message.search_selected == none
}

fn test_derived_config_uses_selection_and_clipboard_maps() {
	mut cfg := configpkg.Config.default_config()
	cfg.selection_word_chars.parse_cli('._')!
	cfg.clipboard_codepoint_map.parse_cli('U+2500=U+002D')!
	cfg.link_previews = .osc8
	mut derived := DerivedConfig.from_config(&cfg)!
	defer { derived.deinit() }
	assert derived.selection_word_chars == [u32(0), u32(`.`), u32(`_`)]
	assert derived.clipboard_codepoint_map.map.list.len == 1
	assert derived.clipboard_codepoint_map.map.list[0].range_start == 0x2500
	assert derived.link_previews == configpkg.LinkPreviews.osc8
}

fn test_surface_command_uses_initial_command_only_for_first_surface() {
	mut cfg := configpkg.Config.default_config()
	cfg.command = configpkg.Command(configpkg.DirectCmd{ direct: ['regular'] })
	cfg.initial_command = configpkg.Command(configpkg.DirectCmd{ direct: ['initial', 'arg'] })
	first := surface_command(&cfg, true) or { panic('missing first command') }
	later := surface_command(&cfg, false) or { panic('missing regular command') }
	assert first.string_val() == 'initial arg'
	assert later.string_val() == 'regular'
}

fn test_surface_initial_title_follows_command_kind() {
	mut cfg := configpkg.Config.default_config()
	direct := configpkg.Command(configpkg.DirectCmd{ direct: ['echo', 'hello'] })
	shell := configpkg.Command(configpkg.ShellCmd{ shell: 'echo hello' })
	assert (surface_initial_title(&cfg, direct) or { '' }) == 'echo'
	assert surface_initial_title(&cfg, shell) == none
	cfg.title = 'configured'
	assert (surface_initial_title(&cfg, direct) or { '' }) == 'configured'
}

fn test_surface_initial_title_uses_full_xdg_command_on_linux() {
	$if linux {
		mut cfg := configpkg.Config.default_config()
		cfg.xdg_terminal_exec = true
		command := configpkg.Command(configpkg.DirectCmd{ direct: ['echo', 'hello world'] })
		assert (surface_initial_title(&cfg, command) or { '' }) == 'echo hello world'
	}
}

fn test_derived_config_preserves_complete_font_configuration() {
	mut cfg := configpkg.Config.default_config()
	cfg.load_string('font-style-bold = Heavy\nfont-variation = wght=350\nfont-codepoint-map = U+E000-U+E001=Symbols\nfont-synthetic-style = no-bold,italic,bold-italic\nadjust-cell-width = 10%\nfreetype-load-flags = no-hinting,force-autohint\n')
	assert cfg.diagnostics.len == 0
	derived := DerivedConfig.from_config(&cfg)!
	assert derived.font.font_style_bold.name_value()? == 'Heavy'
	assert derived.font.font_variation.len == 1
	assert derived.font.font_variation[0].id.str() == 'wght'
	assert derived.font.font_variation[0].value == 350
	assert derived.font.font_codepoint_map.entries.len == 1
	assert derived.font.font_codepoint_map.entries[0].descriptor.family? == 'Symbols'
	assert !derived.font.font_synthetic_style.bold()
	assert derived.font.adjust_cell_width?.is_percent
	assert derived.font.adjust_cell_width?.percent == 1.1
	assert !derived.font.freetype_load_flags.hinting()
	assert derived.font.freetype_load_flags.force_autohint()
}

fn test_derived_config_preserves_macos_surface_options() {
	mut cfg := configpkg.Config.default_config()
	cfg.load_string('macos-non-native-fullscreen = visible-menu\nmacos-option-as-alt = right\n')
	assert cfg.diagnostics.len == 0
	derived := DerivedConfig.from_config(&cfg)!
	assert derived.macos_non_native_fullscreen == .visible_menu
	assert derived.macos_option_as_alt? == .right
}

fn test_derived_config_preserves_right_click_action() {
	mut cfg := configpkg.Config.default_config()
	cfg.right_click_action = .copy_or_paste
	derived := DerivedConfig.from_config(&cfg)!
	assert derived.right_click_action == .copy_or_paste
}

fn test_toggle_fullscreen_uses_configured_macos_mode() {
	mut runtime := apprt.RuntimeApp{ actions_handled: true }
	mut surf := make_test_surface()
	surf.rt_app = &runtime
	surf.config.macos_non_native_fullscreen = .padded_notch
	assert surf.perform_binding_action(input.Action.new(.toggle_fullscreen))!
	assert runtime.actions.len == 1
	assert runtime.actions[0].action == .toggle_fullscreen
	match runtime.actions[0].target {
		apprt.SurfaceTarget {
			assert runtime.actions[0].target.surface == voidptr(&surf)
		}
		apprt.AppTarget {
			assert false, 'surface binding must retain its surface target'
		}
	}
	assert runtime.actions[0].data.toggle_fullscreen == .macos_non_native_padded_notch
}

fn test_binding_actions_use_canonical_runtime_payloads() {
	mut runtime := apprt.RuntimeApp{ actions_handled: true }
	mut surf := make_test_surface()
	surf.rt_app = &runtime
	surf.size.screen = rendererpkg.ScreenSize{ width: 800, height: 600 }

	assert surf.perform_binding_action(input.Action.new_enum(.new_split, i32(input.SplitDirection.auto_)))!
	assert runtime.actions.last().data.new_split == apprt.SplitDirection.right
	surf.size.screen = rendererpkg.ScreenSize{ width: 600, height: 800 }
	assert surf.perform_binding_action(input.Action.new_enum(.new_split, i32(input.SplitDirection.auto_)))!
	assert runtime.actions.last().data.new_split == apprt.SplitDirection.down

	assert surf.perform_binding_action(input.Action.new_enum(.close_tab, i32(input.CloseTabMode.other)))!
	assert runtime.actions.last().data.close_tab == apprt.CloseTabMode.other
	assert surf.perform_binding_action(input.Action.new_enum(.goto_split, i32(input.SplitFocusDirection.left)))!
	assert runtime.actions.last().data.goto_split_ == apprt.GotoSplit.left
	assert surf.perform_binding_action(input.Action.new_enum(.goto_window, i32(input.GotoWindow.next)))!
	assert runtime.actions.last().data.goto_window_ == apprt.GotoWindow.next
	assert surf.perform_binding_action(input.Action.new_enum2(.resize_split, i32(input.SplitResizeDirection.right), 7))!
	assert runtime.actions.last().data.resize_split_.direction == apprt.ResizeSplitDirection.right
	assert runtime.actions.last().data.resize_split_.amount == 7
	assert surf.perform_binding_action(input.Action.new_enum(.inspector, i32(input.InspectorMode.show)))!
	assert runtime.actions.last().data.inspector_ == apprt.InspectorAction.show
	assert surf.perform_binding_action(input.Action.new(.previous_tab))!
	assert runtime.actions.last().data.goto_tab == apprt.GotoTab.previous
	assert surf.perform_binding_action(input.Action.new_uint(.goto_tab, 7))!
	assert int(runtime.actions.last().data.goto_tab) == 7
}

fn test_surface_key_binding_applies_modifier_remap() {
	mut cfg := configpkg.Config.default_config()
	cfg.keybind.set = input.Set{}
	cfg.keybind.set.put(input.Trigger{
		key: input.TriggerKey.new_unicode(u32(`q`))
		mods: input.Mods.init(false, false, false, true, false, false, input.SideInfo{})
	}, input.Action.new(.quit))
	cfg.key_remap.parse('ctrl=super')!
	cfg.key_remap.finalize()

	mut surf := make_test_surface()
	surf.config = DerivedConfig.from_config(&cfg)!
	flags := surf.key_event_is_binding(input.KeyEvent{
		key: .key_q
		action: .press
		mods: input.Mods.init(false, true, false, false, false, false, input.SideInfo.init(.left, .left, .left, .left))
		utf8: 'q'
	}) or {
		assert false, 'remapped binding was not found'
		return
	}
	assert !flags.global()
}

fn test_surface_inspector_records_owned_key_and_pty_data() {
	mut surf := make_test_surface()
	surf.activate_inspector()!

	mut event := input.KeyEvent{
		action: .press
		key: .key_x
		utf8: 'x'
		unshifted_codepoint: u32(`x`)
	}
	assert surf.key_callback(event)! == .consumed
	event.utf8 = 'changed'

	insp := surf.inspector or {
		assert false, 'inspector unexpectedly inactive'
		return
	}
	assert insp.key_events.len == 1
	assert insp.key_events[0].event.utf8 == 'x'
	assert insp.key_events[0].pty == [u8(`x`)]

	surf.deactivate_inspector()
}

fn test_surface_inspector_records_triggered_binding() {
	mut surf := make_test_surface()
	surf.config.keybind.set.put(input.Trigger{
		key: input.TriggerKey.new_physical(.f1)
	}, input.Action.new(.ignore))
	surf.activate_inspector()!
	defer {
		surf.deactivate_inspector()
	}

	assert surf.key_callback(input.KeyEvent{ action: .press, key: .f1 })! == .ignored
	insp := surf.inspector or {
		assert false, 'inspector unexpectedly inactive'
		return
	}
	assert insp.key_events.len == 1
	assert insp.key_events[0].binding.len == 1
	assert insp.key_events[0].binding[0].tag == .ignore
	assert insp.key_events[0].pty.len == 0
}

fn test_surface_inspector_records_mouse_position() {
	mut surf := make_test_surface()
	surf.size = make_test_size()
	surf.activate_inspector()!
	defer {
		surf.deactivate_inspector()
	}

	surf.cursor_pos_callback(apprt.CursorPos{ x: 25, y: 45 }, none)!

	insp := surf.inspector or {
		assert false, 'inspector unexpectedly inactive'
		return
	}
	assert insp.mouse.last_xpos == 25
	assert insp.mouse.last_ypos == 45
	point := insp.mouse.last_point or {
		assert false, 'inspector mouse point was not recorded'
		return
	}
	assert point.x == 2
	assert point.y == 2
}

fn test_surface_mouse_buttons_use_canonical_enum_indices() {
	mut surf := make_test_surface()
	assert surf.mouse.click_state.len == input.mouse_button_max

	surf.mouse_button_callback(.press, .ten, input.Mods{})!
	assert surf.mouse.click_state[int(input.MouseButton.unknown)] == .release
	assert surf.mouse.click_state[int(input.MouseButton.ten)] == .press

	surf.mouse_button_callback(.release, .ten, input.Mods{})!
	assert surf.mouse.click_state[int(input.MouseButton.ten)] == .release
}

fn test_left_click_uses_source_multi_click_selection_state_machine() {
	mut runtime := apprt.RuntimeSurface{ cursor_pos: apprt.CursorPos{ x: 15, y: 15 } }
	mut surf := make_test_surface()
	surf.rt_surface = &runtime
	surf.size = make_test_size()
	surf.config.mouse_interval = u64(10 * time.second)
	surf.renderer_state.terminal_.print_string('one two')!

	assert !surf.mouse_button_callback(.press, .left, input.Mods{})!
	assert surf.mouse.left_click_count == 1
	assert surf.mouse.left_click_screen == .primary
	surf.mouse_button_callback(.release, .left, input.Mods{})!

	assert !surf.mouse_button_callback(.press, .left, input.Mods{})!
	assert surf.mouse.left_click_count == 2
	selection := surf.renderer_state.terminal_.screens.active.selection or {
		assert false, 'double click did not select a word'
		return
	}
	assert selection.contains(surf.renderer_state.terminal_.screens.active, terminal.Pin{
		x: 1
		y: 0
	})
	surf.mouse_button_callback(.release, .left, input.Mods{})!

	assert !surf.mouse_button_callback(.press, .left, input.Mods{})!
	assert surf.mouse.left_click_count == 3
	line := surf.renderer_state.terminal_.screens.active.selection or {
		assert false, 'triple click did not select a line'
		return
	}
	assert line.start().y == 0
	assert line.end().y == 0
}

fn test_right_click_context_menu_selects_word_without_consuming() {
	mut runtime := apprt.RuntimeSurface{ cursor_pos: apprt.CursorPos{ x: 15, y: 15 } }
	mut surf := make_test_surface()
	surf.rt_surface = &runtime
	surf.size = make_test_size()
	surf.config.right_click_action = .context_menu
	surf.renderer_state.terminal_.print_string('hello world')!

	assert !surf.mouse_button_callback(.press, .right, input.Mods{})!
	selection := surf.renderer_state.terminal_.screens.active.selection or {
		assert false, 'right click did not select a word'
		return
	}
	assert selection.contains(surf.renderer_state.terminal_.screens.active, terminal.Pin{
		x: 1
		y: 0
	})
}

fn test_right_click_copy_or_paste_requests_paste_without_selection() {
	mut runtime := apprt.RuntimeSurface{ cursor_pos: apprt.CursorPos{ x: 15, y: 15 } }
	mut surf := make_test_surface()
	surf.rt_surface = &runtime
	surf.size = make_test_size()
	surf.config.right_click_action = .copy_or_paste

	assert surf.mouse_button_callback(.press, .right, input.Mods{})!
	assert runtime.requests.len == 1
	assert runtime.requests[0].clipboard == .standard
	assert runtime.requests[0].request.kind == .paste
}

fn test_mouse_shift_capture_uses_terminal_override_then_config_default() {
	mut surf := make_test_surface()
	surf.config.mouse_shift_capture = .false_
	surf.renderer_state.terminal_.flags.set_mouse_shift_capture(.null_)
	assert !surf.mouse_shift_capture(false)

	surf.config.mouse_shift_capture = .true_
	assert surf.mouse_shift_capture(false)

	surf.renderer_state.terminal_.flags.set_mouse_shift_capture(.false_)
	assert !surf.mouse_shift_capture(false)
	surf.config.mouse_shift_capture = .false_
	surf.renderer_state.terminal_.flags.set_mouse_shift_capture(.true_)
	assert surf.mouse_shift_capture(false)

	surf.config.mouse_shift_capture = .never
	assert !surf.mouse_shift_capture(false)
	surf.config.mouse_shift_capture = .always
	surf.renderer_state.terminal_.flags.set_mouse_shift_capture(.false_)
	assert surf.mouse_shift_capture(false)
}

fn test_surface_pwd_returns_an_owned_copy() {
	mut surf := make_test_surface()
	surf.renderer_state.terminal_.set_pwd('/first')!
	pwd := surf.pwd() or {
		assert false, 'surface pwd was missing'
		return
	}
	surf.renderer_state.terminal_.set_pwd('/second')!
	assert pwd == '/first'
	assert surf.pwd()? == '/second'
}

fn test_text_binding_decodes_zig_escapes_before_writing() {
	mut surf := make_test_surface()
	assert surf.perform_binding_action(input.Action.new_str(.text, 'line\\n\\x41'))!
	assert surf.io.messages.len == 1
	assert surf.io.messages[0].kind == .write_small
	assert surf.io.messages[0].write_slice().bytestr() == 'line\nA'
}

fn test_long_text_binding_uses_allocated_write() {
	mut surf := make_test_surface()
	text := 'x'.repeat(129)
	assert surf.perform_binding_action(input.Action.new_str(.text, text))!
	assert surf.io.messages.len == 1
	assert surf.io.messages[0].kind == .write_alloc
	assert surf.io.messages[0].write_slice().bytestr() == text
}

fn test_oversized_csi_binding_is_rejected_without_truncation() {
	mut surf := make_test_surface()
	action := input.Action.new_str(.csi, 'x'.repeat(127))
	surf.perform_binding_action(action) or {
		assert err.msg() == 'binding sequence exceeds 128 bytes'
		assert surf.io.messages.len == 0
		return
	}
	assert false, 'oversized CSI binding unexpectedly succeeded'
}

fn test_csi_binding_accepts_exact_fixed_buffer_size_without_truncation() {
	mut surf := make_test_surface()
	action := input.Action.new_str(.csi, 'x'.repeat(126))
	assert surf.perform_binding_action(action)!
	assert surf.io.messages.len == 1
	assert surf.io.messages[0].kind == .write_alloc
	assert surf.io.messages[0].write_slice().len == 128
}

fn test_invalid_text_binding_is_handled_without_writing() {
	mut surf := make_test_surface()
	assert surf.perform_binding_action(input.Action.new_str(.text, '\\q'))!
	assert surf.io.messages.len == 0
}

fn test_cursor_key_binding_selects_sequence_from_terminal_mode() {
	mut surf := make_test_surface()
	action := input.Action.new_cursor_key('\x1b[A', '\x1bOA')
	assert surf.perform_binding_action(action)!
	assert surf.io.messages.last().write_slice().bytestr() == '\x1b[A'

	surf.renderer_state.terminal_.modes.set(.cursor_keys, true)
	assert surf.perform_binding_action(action)!
	assert surf.io.messages.last().write_slice().bytestr() == '\x1bOA'
}

fn test_grid_size_basic() {
	s := make_test_size()
	g := s.grid()
	// usable: 110 - 5 - 5 = 100 width, 110 - 5 - 5 = 100 height
	// cols = 100 / 10 = 10, rows = 100 / 20 = 5
	assert g.columns == 10
	assert g.rows == 5
}

fn test_grid_size_large_padding() {
	s := rendererpkg.Size{
		cell: rendererpkg.CellSize{ width: 10, height: 10 }
		padding: rendererpkg.Padding{ left: 50, top: 50, right: 50, bottom: 50 }
		screen: rendererpkg.ScreenSize{ width: 100, height: 100 }
	}
	g := s.grid()
	// Ghostty's renderer grid always retains at least one cell per axis.
	assert g.columns == 1
	assert g.rows == 1
}

fn test_screen_size_equals() {
	a := rendererpkg.ScreenSize{ width: 100, height: 200 }
	b := rendererpkg.ScreenSize{ width: 100, height: 200 }
	c := rendererpkg.ScreenSize{ width: 100, height: 201 }
	assert a.equals(b) == true
	assert a.equals(c) == false
}

fn test_coordinate_eql() {
	a := Coordinate{ x: 5, y: 10 }
	b := Coordinate{ x: 5, y: 10 }
	c := Coordinate{ x: 5, y: 11 }
	assert a.eql(b) == true
	assert a.eql(c) == false
}

fn test_scroll_amount_direction() {
	up := ScrollAmount{ delta: 5 }
	down := ScrollAmount{ delta: -3 }
	zero := ScrollAmount{ delta: 0 }

	assert up.direction() == .up_right
	assert down.direction() == .down_left
	assert zero.direction() == .up_right // zero is non-negative
}

fn test_scroll_amount_magnitude() {
	up := ScrollAmount{ delta: 5 }
	down := ScrollAmount{ delta: -3 }
	zero := ScrollAmount{ delta: 0 }

	assert up.magnitude() == 5
	assert down.magnitude() == 3
	assert zero.magnitude() == 0
}

fn test_pos_to_viewport_basic() {
	mut surf := Surface{
		size: make_test_size()
	}
	// Cell at (15, 25): subtract 5px padding -> (10, 20) -> cell (1, 1)
	coord := surf.pos_to_viewport(15.0, 25.0)
	assert coord.x == 1
	assert coord.y == 1
}

fn test_pos_to_viewport_origin() {
	mut surf := Surface{
		size: make_test_size()
	}
	// At padding boundary: (5, 5) -> (0, 0) -> cell (0, 0)
	coord := surf.pos_to_viewport(5.0, 5.0)
	assert coord.x == 0
	assert coord.y == 0
}

fn test_pos_to_viewport_negative() {
	mut surf := Surface{
		size: make_test_size()
	}
	// Negative coords should clamp to 0
	coord := surf.pos_to_viewport(-10.0, -10.0)
	assert coord.x == 0
	assert coord.y == 0
}

fn test_pos_to_viewport_last_cell() {
	mut surf := Surface{
		size: make_test_size()
	}
	// Last cell: x = 5 + 9*10 = 95, y = 5 + 4*20 = 85
	coord := surf.pos_to_viewport(95.0, 85.0)
	assert coord.x == 9
	assert coord.y == 4
}

fn test_pos_to_viewport_clamps_to_grid() {
	surf := Surface{
		size: make_test_size()
	}
	coord := surf.pos_to_viewport(10000.0, 10000.0)
	assert coord.x == 9
	assert coord.y == 4
}

fn test_input_effect_values() {
	assert apprt.InputEffect.ignored != apprt.InputEffect.consumed
	assert apprt.InputEffect.consumed != apprt.InputEffect.closed
	assert apprt.InputEffect.ignored != apprt.InputEffect.closed
}

fn test_needs_confirm_quit_readonly() {
	surf := Surface{
		readonly: true
	}
	assert surf.needs_confirm_quit() == true
}

fn test_needs_confirm_quit_child_exited() {
	surf := Surface{
		child_exited: true
	}
	assert surf.needs_confirm_quit() == false
}

fn test_needs_confirm_quit_config_always() {
	surf := Surface{
		config: DerivedConfig{
			confirm_close_surface: .always
		}
	}
	assert surf.needs_confirm_quit() == true
}

fn test_needs_confirm_quit_config_false() {
	surf := Surface{
		config: DerivedConfig{
			confirm_close_surface: .false_
		}
	}
	assert surf.needs_confirm_quit() == false
}

fn test_scaled_padding() {
	cfg := DerivedConfig{
		window_padding_top: 10
		window_padding_bottom: 20
		window_padding_left: 15
		window_padding_right: 5
	}
	// At 72 DPI, scaling factor is 1.0 (72/72)
	p := cfg.scaled_padding(72.0, 72.0)
	assert p.top == 10
	assert p.bottom == 20
	assert p.left == 15
	assert p.right == 5
}

fn test_scaled_padding_2x() {
	cfg := DerivedConfig{
		window_padding_top: 10
		window_padding_bottom: 20
		window_padding_left: 15
		window_padding_right: 5
	}
	// At 144 DPI, scaling factor is 2.0 (144/72)
	p := cfg.scaled_padding(144.0, 144.0)
	assert p.top == 20
	assert p.bottom == 40
	assert p.left == 30
	assert p.right == 10
}

fn test_preedit_width() {
	p := Preedit{
		codepoints: [
			PreeditCodepoint{ codepoint: 0x3042, wide: true }, // あ (wide)
			PreeditCodepoint{ codepoint: 0x61, wide: false }, // a (narrow)
			PreeditCodepoint{ codepoint: 0x4e16, wide: true }, // 世 (wide)
		]
	}
	assert p.width() == 5 // 2 + 1 + 2
}

fn test_preedit_width_empty() {
	p := Preedit{
		codepoints: []
	}
	assert p.width() == 0
}

fn test_preedit_callback_uses_unicode_width_table() {
	mut surf := make_test_surface()
	text := 'a' + rune(0x0301).str() + rune(0x4e16).str()
	surf.preedit_callback(text)!
	preedit := surf.renderer_state.preedit or {
		assert false, 'preedit was not installed'
		return
	}
	// The combining acute accent has width zero and is omitted. The CJK
	// character width comes from the pinned generated Unicode table.
	assert preedit.codepoints.len == 2
	assert preedit.codepoints[0].codepoint == `a`
	assert !preedit.codepoints[0].wide
	assert preedit.codepoints[1].codepoint == 0x4e16
	assert preedit.codepoints[1].wide
}

fn test_key_is_modifier() {
	assert key_is_modifier(.shift_left) == true
	assert key_is_modifier(.shift_right) == true
	assert key_is_modifier(.control_left) == true
	assert key_is_modifier(.control_right) == true
	assert key_is_modifier(.alt_left) == true
	assert key_is_modifier(.alt_right) == true
	assert key_is_modifier(.meta_left) == true
	assert key_is_modifier(.meta_right) == true
	assert key_is_modifier(.key_a) == false
	assert key_is_modifier(.escape) == false
	assert key_is_modifier(.space) == false
}

fn test_hide_show_mouse() {
	mut surf := Surface{}
	assert surf.mouse.hidden == false

	surf.hide_mouse()
	assert surf.mouse.hidden == true

	// Calling hide again should be a no-op
	surf.hide_mouse()
	assert surf.mouse.hidden == true

	surf.show_mouse()
	assert surf.mouse.hidden == false

	// Calling show again should be a no-op
	surf.show_mouse()
	assert surf.mouse.hidden == false
}

fn test_mouse_pressure_callback_no_change() ! {
	mut surf := make_test_surface()
	surf.mouse.pressure_stage = .normal
	// Same stage should be a no-op
	surf.mouse_pressure_callback(.normal, 0.5)!
	assert surf.mouse.pressure_stage == .normal
}

fn test_mouse_pressure_callback_change() ! {
	mut surf := make_test_surface()
	surf.mouse.pressure_stage = .none_
	surf.mouse_pressure_callback(.deep, 0.9)!
	assert surf.mouse.pressure_stage == .deep
}

fn test_mouse_pressure_deep_selects_word_at_original_click_pin() ! {
	mut surf := make_test_surface()
	surf.config.selection_word_chars = [u32(` `)]
	for i, cp in 'left right'.runes() {
		surf.renderer_state.terminal_.screens.active.pages.screen_rows[0].cells[i] = terminal.CellData.init(u32(cp))
	}
	surf.mouse.click_state[int(input.MouseButton.left)] = .press
	surf.mouse.left_click_pin = terminal.Pin{ x: 1, y: 0 }

	surf.mouse_pressure_callback(.deep, 0.9)!
	selection := surf.renderer_state.terminal_.screens.active.selection or {
		assert false, 'deep pressure should select the clicked word'
		return
	}
	assert selection.start().x == 0
	assert selection.end().x == 3
}

fn test_focus_callback_same_state() ! {
	mut surf := make_test_surface()
	surf.focused = true
	// Same focus state should be a no-op
	surf.focus_callback(true)!
	assert surf.focused == true
}

fn test_focus_callback_change() ! {
	mut surf := make_test_surface()
	surf.focused = true
	surf.focus_callback(false)!
	assert surf.focused == false
}

fn test_focus_callback_releases_pressed_key_and_modifiers() ! {
	mut runtime_surface := apprt.RuntimeSurface{}
	mut surf := make_test_surface()
	surf.rt_surface = &runtime_surface
	surf.focused = true
	surf.pressed_key = KeyEvent{
		key: .key_a
		action: .press
		mods: input.Mods.init(true, true, false, false, false, false, input.SideInfo{})
		utf8: ''
	}
	surf.focus_callback(false)!
	assert surf.pressed_key == none
	assert surf.mouse.mods.empty()
}

fn test_key_release_preserves_held_modifiers_for_focus_loss() ! {
	mut runtime_surface := apprt.RuntimeSurface{}
	mut surf := make_test_surface()
	surf.rt_surface = &runtime_surface
	surf.pressed_key = KeyEvent{
		key: .key_a
		mods: input.Mods.init(true, false, false, false, false, false, input.SideInfo{})
	}
	effect := surf.key_callback(KeyEvent{
		key: .key_a
		action: .release
		mods: input.Mods.init(true, false, false, false, false, false, input.SideInfo{})
	})!
	assert effect == .ignored
	pending := surf.pressed_key or {
		assert false, 'held modifier state was discarded'
		return
	}
	assert pending.key == .unidentified
	assert pending.mods.shift()
}

fn test_modifier_key_updates_mouse_shape() ! {
	mut runtime := apprt.RuntimeApp{}
	mut surf := make_test_surface()
	surf.rt_app = &runtime
	surf.config.mouse_shift_capture = .always
	surf.renderer_state.terminal_.flags.set_mouse_event(.normal)
	effect := surf.key_callback(KeyEvent{
		key: .shift_left
		mods: input.Mods.init(true, false, false, false, false, false, input.SideInfo{})
	})!
	assert effect == .ignored
	assert runtime.actions.len == 1
	assert runtime.actions[0].action == .mouse_shape
	assert runtime.actions[0].data.mouse_shape_ == .text
}

fn test_modifier_key_refreshes_link_hover() ! {
	mut runtime_app := apprt.RuntimeApp{}
	mut runtime_surface := apprt.RuntimeSurface{
		cursor_pos: apprt.CursorPos{ x: 6, y: 6 }
	}
	mut surf := make_test_surface()
	surf.size = make_test_size()
	surf.rt_app = &runtime_app
	surf.rt_surface = &runtime_surface
	surf.config.link_previews = .true_
	surf.config.links = [DerivedConfigLink{
		regex: oniguruma.Regex.init(r'http://a', oniguruma.Options{}, .utf8, .default_, none)!
		action: .open
		highlight: .hover
	}]
	defer { surf.config.links[0].regex.deinit() }
	mut stream := surf.renderer_state.terminal_.vt_stream()
	stream.next_slice('http://a')!

	mods := input.ctrl_or_super_mods(input.Mods{})
	key := if mods.super_() { input.Key.meta_left } else { input.Key.control_left }
	effect := surf.key_callback(KeyEvent{
		key: key
		mods: mods
	})!
	assert effect == .ignored
	assert surf.mouse.over_link
	assert runtime_app.actions.len == 2
	assert runtime_app.actions[0].action == .mouse_shape
	assert runtime_app.actions[0].data.mouse_shape_ == .pointer
	assert runtime_app.actions[1].action == .mouse_over_link
	assert runtime_app.actions[1].data.mouse_over_link_.url == 'http://a'
}

fn test_focus_callback_always_reveals_mouse() ! {
	mut runtime := apprt.RuntimeApp{}
	mut surf := make_test_surface()
	surf.rt_app = &runtime
	surf.focused = true
	surf.mouse.hidden = true
	surf.focus_callback(false)!
	assert !surf.mouse.hidden
	assert runtime.actions.len == 1
	assert runtime.actions[0].action == .mouse_visibility
	assert runtime.actions[0].data.mouse_visibility_ == .visible
}

fn test_content_scale_callback_unchanged_dpi_is_noop() ! {
	mut surf := make_test_surface()
	surf.font_size.xdpi = u16(default_dpi)
	surf.font_size.ydpi = u16(default_dpi)
	surf.content_scale_callback(apprt.ContentScale{ x: 1, y: 1 })!
	assert surf.font_size.xdpi == u16(default_dpi)
	assert surf.font_size.ydpi == u16(default_dpi)
}

fn test_size_callback_no_change() ! {
	mut surf := make_test_surface()
	surf.size = rendererpkg.Size{
		screen: rendererpkg.ScreenSize{ width: 800, height: 600 }
		cell: rendererpkg.CellSize{ width: 10, height: 20 }
	}
	// Same size should be a no-op (no error)
	surf.size_callback(apprt.SurfaceSize{ width: 800, height: 600 })!
}

fn test_color_scheme_callback_no_change() ! {
	mut surf := make_test_surface()
	surf.config_conditional_state = ConditionalState{ theme: .dark }
	// Same scheme should be a no-op
	surf.color_scheme_callback(.dark)!
	assert surf.config_conditional_state.theme == .dark
}

fn test_color_scheme_callback_change() ! {
	mut runtime := apprt.RuntimeApp{}
	mut surf := make_test_surface()
	surf.rt_app = &runtime
	surf.config_conditional_state = ConditionalState{ theme: .dark }
	surf.color_scheme_callback(.light)!
	assert surf.config_conditional_state.theme == .light
	assert runtime.actions.len == 1
	assert runtime.actions[0].action == .reload_config
	assert runtime.actions[0].data.reload_config_.soft
}

fn test_secure_input_actions_preserve_on_off_and_toggle() ! {
	mut runtime := apprt.RuntimeApp{ actions_handled: true }
	mut surf := make_test_surface()
	surf.rt_app = &runtime

	assert surf.perform_binding_action(input.Action.new(.toggle_secure_input))!
	assert runtime.actions.last().data.secure_input_ == .toggle
	runtime.actions.clear()

	surf.password_input(true)!
	assert runtime.actions.last().data.secure_input_ == .on
	surf.password_input(false)!
	assert runtime.actions.last().data.secure_input_ == .off
}

fn test_child_exited_no_wait() {
	mut app_runtime := apprt.RuntimeApp{ actions_handled: true }
	mut surface_runtime := apprt.RuntimeSurface{}
	mut surf := make_test_surface()
	surf.rt_app = &app_runtime
	surf.rt_surface = &surface_runtime
	surf.config = DerivedConfig{
		wait_after_command: false
		abnormal_command_exit_runtime_ms: 500
	}
	assert surf.child_exited == false
	surf.child_exited_handler(1000, 0)
	assert surf.child_exited == true
	assert app_runtime.actions.len == 1
	assert app_runtime.actions[0].action == .show_child_exited
	assert app_runtime.actions[0].data.show_child_exited_.runtime_ms == 1000
	assert app_runtime.actions[0].data.show_child_exited_.exit_code == 0
	assert surface_runtime.closed
}

fn test_child_exited_abnormal_native_banner_stops_fallback() {
	mut app_runtime := apprt.RuntimeApp{ actions_handled: true }
	mut surface_runtime := apprt.RuntimeSurface{}
	mut surf := make_test_surface()
	surf.rt_app = &app_runtime
	surf.rt_surface = &surface_runtime
	surf.config = DerivedConfig{
		wait_after_command: false
		abnormal_command_exit_runtime_ms: 500
	}
	surf.child_exited_handler(100, 127)
	assert app_runtime.actions.len == 1
	assert app_runtime.actions[0].data.show_child_exited_ == apprt.ChildExited{
		exit_code: 127
		runtime_ms: 100
	}
	assert !surface_runtime.closed
}

fn test_child_exited_abnormal_terminal_fallback() {
	mut app_runtime := apprt.RuntimeApp{}
	mut surface_runtime := apprt.RuntimeSurface{}
	mut surf := make_test_surface()
	surf.rt_app = &app_runtime
	surf.rt_surface = &surface_runtime
	surf.config = DerivedConfig{
		abnormal_command_exit_runtime_ms: 500
	}
	surf.io.impl.backend.subprocess.args = ['missing-command', '--flag']
	surf.child_exited_handler(100, 127)
	mut terminal_state := surf.renderer_state.terminal_
	text := terminal_state.plain_string() or { panic(err) }
	assert text.contains('Ghostty failed to launch the requested command:')
	assert text.contains('missing-command --flag')
	assert text.contains('Runtime: 100 ms')
	$if !macos {
		assert text.contains('Exit Code: 127')
	}
	assert text.contains('Press any key to close the window.')
	assert !terminal_state.modes.get(.cursor_visible)
	assert !surface_runtime.closed
}

fn test_selection_scroll_tick_inactive() ! {
	mut surf := Surface{
		selection_scroll_active: false
	}
	// Should return immediately without error
	surf.selection_scroll_tick()!
}

fn test_selection_scroll_tick_no_click() ! {
	mut surf := Surface{
		selection_scroll_active: true
	}
	surf.mouse.left_click_count = 0
	// Should return immediately without error
	surf.selection_scroll_tick()!
}

fn test_selection_scroll_stops_after_screen_switch() ! {
	mut runtime := apprt.RuntimeSurface{}
	mut surf := make_test_surface()
	surf.rt_surface = &runtime
	surf.selection_scroll_active = true
	surf.mouse.left_click_count = 1
	surf.mouse.left_click_screen = .primary
	surf.renderer_state.terminal_.switch_screen(.alternate)!

	surf.selection_scroll_tick()!
	assert surf.io.messages.len == 1
	assert surf.io.messages[0].kind == .selection_scroll
	assert !surf.io.messages[0].flag_val
}

fn test_complete_clipboard_paste_empty() ! {
	mut surf := Surface{}
	// Empty data should return immediately
	surf.complete_clipboard_paste('', true)!
}

fn test_complete_clipboard_paste_encodes_non_bracketed_newlines() ! {
	mut surf := make_test_surface()
	surf.complete_clipboard_paste('one\ntwo', true)!
	assert surf.io.messages.len == 1
	assert surf.io.messages[0].kind == .write_alloc
	assert surf.io.messages[0].write_slice().bytestr() == 'one\rtwo'
}

fn test_complete_clipboard_paste_encodes_bracketed_fences() ! {
	mut surf := make_test_surface()
	surf.renderer_state.terminal_.modes.set(.bracketed_paste, true)
	surf.complete_clipboard_paste('one\ntwo', true)!
	assert surf.io.messages.len == 3
	assert surf.io.messages.map(it.write_slice().bytestr()).join('') == '\x1b[200~one\ntwo\x1b[201~'
}

fn test_complete_clipboard_paste_rejects_unsafe_text() {
	mut surf := make_test_surface()
	surf.config.clipboard_paste_protection = true
	surf.complete_clipboard_paste('one\ntwo', false) or {
		assert err.msg() == 'UnsafePaste'
		assert surf.io.messages.len == 0
		return
	}
	assert false, 'expected UnsafePaste'
}

fn test_runtime_clipboard_request_preserves_source_and_request() ! {
	mut runtime := apprt.RuntimeSurface{}
	request := apprt.ClipboardRequest{
		kind: .osc_52_read
		clipboard: .primary
	}
	assert runtime.clipboard_request(.standard, request)!
	assert runtime.requests.len == 1
	assert runtime.requests[0].clipboard == .standard
	assert runtime.requests[0].request == request
}

fn test_complete_clipboard_request_osc52_read() ! {
	mut surf := make_test_surface()
	surf.config.clipboard_read = .allow
	surf.complete_clipboard_request(apprt.ClipboardRequest{
		kind: .osc_52_read
		clipboard: .selection
	}, 'hello', false)!
	assert surf.io.messages.len == 1
	assert surf.io.messages[0].write_slice().bytestr() == '\x1b]52;s;aGVsbG8=\x1b\\'
}

fn test_complete_clipboard_request_osc52_read_requires_confirmation() {
	mut surf := make_test_surface()
	surf.config.clipboard_read = .ask
	surf.complete_clipboard_request(apprt.ClipboardRequest{
		kind: .osc_52_read
		clipboard: .standard
	}, 'hello', false) or {
		assert err.msg() == 'UnauthorizedPaste'
		assert surf.io.messages.len == 0
		return
	}
	assert false, 'expected UnauthorizedPaste'
}

fn test_complete_clipboard_request_osc52_write() ! {
	mut surf := make_test_surface()
	mut runtime := apprt.RuntimeSurface{}
	surf.rt_surface = &runtime
	surf.complete_clipboard_request(apprt.ClipboardRequest{
		kind: .osc_52_write
		clipboard: .primary
	}, 'hello', true)!
	assert runtime.clipboards[.primary][0].mime == 'text/plain'
	assert runtime.clipboards[.primary][0].data == 'hello'
}

fn test_end_key_sequence_no_queued() {
	mut runtime := apprt.RuntimeApp{}
	mut surf := Surface{ rt_app: &runtime }
	// With no queued items, should just clear sequence_set
	surf.keyboard.sequence_queued = []
	surf.end_key_sequence(.flush, .retain)
	assert surf.keyboard.sequence_set == none
	assert runtime.actions.len == 1
	assert runtime.actions[0].action == .key_sequence
	assert !runtime.actions[0].data.key_sequence_.active
}

fn test_end_key_sequence_flush_preserves_allocated_write() {
	mut runtime := apprt.RuntimeApp{}
	mut surf := Surface{ rt_app: &runtime }
	data := 'x'.repeat(80)
	surf.keyboard.sequence_queued << termiopkg.WriteReq.init(data.bytes())

	surf.end_key_sequence(.flush, .retain)

	assert surf.keyboard.sequence_queued.len == 0
	assert surf.io.messages.len == 1
	assert surf.io.messages[0].kind == .write_alloc
	assert surf.io.messages[0].write_slice().bytestr() == data
}

fn test_deactivate_all_key_tables_empty() ! {
	mut surf := Surface{}
	// Empty table stack should return false
	result := surf.deactivate_all_key_tables()!
	assert result == false
}

fn test_deactivate_all_key_tables_action_payload() ! {
	mut runtime := apprt.RuntimeApp{ actions_handled: true }
	mut surf := Surface{ rt_app: &runtime }
	surf.keyboard.table_stack << KeyTableEntry{ name: 'copy-mode' }
	assert surf.deactivate_all_key_tables()!
	assert surf.keyboard.table_stack.len == 0
	assert runtime.actions.len == 1
	assert runtime.actions[0].action == .key_table
	assert runtime.actions[0].data.key_table_.tag == .deactivate_all
}

fn test_deactivate_key_table_action_payload() ! {
	mut runtime := apprt.RuntimeApp{ actions_handled: true }
	mut surf := Surface{ rt_app: &runtime }
	surf.keyboard.table_stack << KeyTableEntry{ name: 'copy-mode' }
	assert surf.perform_binding_action(input.Action.new(.deactivate_key_table))!
	assert surf.keyboard.table_stack.len == 0
	assert runtime.actions.len == 1
	assert runtime.actions[0].action == .key_table
	assert runtime.actions[0].data.key_table_.tag == .deactivate
}

fn test_balance_padding_if_needed_disabled() {
	mut surf := Surface{
		config: DerivedConfig{
			window_padding_balance: false
		}
	}
	// Should return immediately without modifying padding
	original_padding := surf.size.padding
	surf.balance_padding_if_needed()
	assert surf.size.padding.top == original_padding.top
}

fn test_balance_padding_basic() {
	mut s := rendererpkg.Size{
		screen: rendererpkg.ScreenSize{ width: 120, height: 120 }
		cell: rendererpkg.CellSize{ width: 10, height: 20 }
		padding: rendererpkg.Padding{}
	}
	explicit := rendererpkg.Padding{ left: 5, top: 5, right: 5, bottom: 5 }
	s.balance_padding(explicit)
	// The explicit padding is installed before calculating the 11x5 grid.
	// Balancing the remaining 10x20 pixels produces 5 horizontal and 10
	// vertical pixels, exactly as renderer.Size.balancePadding does.
	assert s.padding == rendererpkg.Padding{ left: 5, right: 5, top: 10, bottom: 10 }
}

fn test_pin_eql() {
	a := Pin{ x: 3, y: 7 }
	b := Pin{ x: 3, y: 7 }
	c := Pin{ x: 4, y: 7 }
	assert a.eql(b) == true
	assert a.eql(c) == false
}

fn test_pin_before() {
	a := Pin{ x: 0, y: 0 }
	b := Pin{ x: 1, y: 0 }
	c := Pin{ x: 0, y: 1 }
	assert a.before(b) == true
	assert b.before(a) == false
	assert a.before(c) == true
	assert c.before(a) == false
}

fn test_terminal_selection_eql() {
	s1 := TermSelection{
		start_pin: Pin{ x: 0, y: 0 }
		end_pin: Pin{ x: 5, y: 2 }
	}
	s2 := TermSelection{
		start_pin: Pin{ x: 0, y: 0 }
		end_pin: Pin{ x: 5, y: 2 }
	}
	s3 := TermSelection{
		start_pin: Pin{ x: 0, y: 0 }
		end_pin: Pin{ x: 5, y: 3 }
	}
	assert s1.eql(s2) == true
	assert s1.eql(s3) == false
}

fn test_closing_action() {
	assert closing_action(input.Action.new(.close_surface)) == true
	assert closing_action(input.Action.new(.close_window)) == true
	assert closing_action(input.Action.new(.close_tab)) == true
	assert closing_action(input.Action.new(.ignore)) == false
	assert closing_action(input.Action.new(.reset)) == false
}

fn test_has_selection() {
	mut surf := make_test_surface()
	assert surf.has_selection() == false

	surf.renderer_state.terminal_.screens.active.selection = TermSelection{
		start_pin: Pin{ x: 0, y: 0 }
		end_pin: Pin{ x: 5, y: 0 }
	}
	assert surf.has_selection() == true
}

fn test_mouse_selection_same_point() {
	pin := Pin{ x: 5, y: 3 }
	size := make_test_size()
	sel := mouse_selection(pin, pin, 55, 55, input.Mods{}, size)
	assert sel == none
}

fn test_encode_key_text() {
	mut surf := make_test_surface()
	ev := KeyEvent{
		key: .key_a
		action: .press
		utf8: 'a'
	}
	req := surf.encode_key(ev) or {
		assert false, 'expected write req'
		return
	}
	assert req.slice().len > 0
	assert req.slice()[0] == u8(`a`)
}

fn test_encode_key_escape() {
	mut surf := make_test_surface()
	ev := KeyEvent{
		key: .escape
		action: .press
		utf8: ''
	}
	req := surf.encode_key(ev) or {
		assert false, 'expected write req'
		return
	}
	assert req.slice().len == 1
	assert req.slice()[0] == 0x1b
}

fn test_encode_key_no_output() {
	mut surf := make_test_surface()
	ev := KeyEvent{
		key: .shift_left
		action: .press
		utf8: ''
	}
	req := surf.encode_key(ev)
	assert req == none
}

fn test_encode_key_honors_ignore_keypad_with_numlock_mode() {
	mut surf := make_test_surface()
	surf.renderer_state.terminal_.modes.set(.keypad_keys, true)
	surf.renderer_state.terminal_.modes.set(.ignore_keypad_with_numlock, true)
	req := surf.encode_key(KeyEvent{
		key: .numpad_1
		utf8: '1'
	}) or {
		assert false, 'expected write req'
		return
	}
	assert req.slice().bytestr() == '1'
}

fn test_scroll_callback_uses_precision_multiplier_and_accumulates_pixels() {
	mut surf := make_test_surface()
	surf.size.cell = rendererpkg.CellSize{ width: 10, height: 10 }
	surf.config.mouse_scroll_multiplier = configpkg.MouseScrollMultiplier{
		precision: 2
		discrete: 3
	}
	surf.scroll_callback(0, 2, input.ScrollMods.init(true, .none_))!
	assert surf.mouse.pending_scroll_y == 4
	surf.scroll_callback(0, 3, input.ScrollMods.init(true, .none_))!
	assert surf.mouse.pending_scroll_y == 0
}

fn test_scroll_callback_alternate_screen_emits_cursor_sequences() {
	mut surf := make_test_surface()
	surf.size.cell = rendererpkg.CellSize{ width: 10, height: 10 }
	mut term := surf.renderer_state.terminal_
	term.switch_screen(.alternate)!
	term.modes.set(.cursor_keys, true)
	surf.scroll_callback(0, 0.1, input.ScrollMods{})!
	assert surf.io.messages.len == 3
	for msg in surf.io.messages {
		assert msg.kind == .write_stable
		assert msg.write_slice().bytestr() == '\x1bOA'
	}
}

fn test_scroll_callback_reports_horizontal_wheel_buttons() {
	mut runtime := apprt.RuntimeSurface{}
	mut surf := make_test_surface()
	surf.rt_surface = &runtime
	surf.size = make_test_size()
	surf.config.mouse_reporting = true
	surf.renderer_state.terminal_.flags.set_mouse_event(.normal)
	surf.scroll_callback(2, 0, input.ScrollMods{})!
	assert surf.io.messages.len == 2
	for msg in surf.io.messages {
		assert msg.kind in [.write_small, .write_alloc]
		assert msg.write_slice().len > 0
	}
}

fn test_copy_selection_to_standard_clipboard() ! {
	mut surf := make_test_surface()
	mut runtime := apprt.RuntimeSurface{}
	surf.rt_surface = &runtime
	for i, cp in 'hello'.runes() {
		surf.renderer_state.terminal_.screens.active.pages.screen_rows[0].cells[i] = terminal.CellData.init(u32(cp))
	}
	start := surf.renderer_state.terminal_.screens.active.pages.pin(terminal.PinOpts{
		tag: .active
		x: 0
		y: 0
	}) or { panic('no start pin') }
	end := surf.renderer_state.terminal_.screens.active.pages.pin(terminal.PinOpts{
		tag: .active
		x: 4
		y: 0
	}) or { panic('no end pin') }
	surf.copy_selection_to_clipboards(terminal.Selection.init(start, end, false), [
		.standard,
	], .plain)!
	contents := runtime.clipboards[.standard]
	assert contents.len == 1
	assert contents[0].mime == 'text/plain'
	assert contents[0].data == 'hello'
}

fn test_copy_selection_mixed_to_requested_clipboards() ! {
	mut surf := make_test_surface()
	mut runtime := apprt.RuntimeSurface{}
	surf.rt_surface = &runtime
	for i, cp in 'hello'.runes() {
		surf.renderer_state.terminal_.screens.active.pages.screen_rows[0].cells[i] = terminal.CellData.init(u32(cp))
	}
	start := surf.renderer_state.terminal_.screens.active.pages.pin(terminal.PinOpts{
		tag: .active
		x: 0
		y: 0
	}) or { panic('no start pin') }
	end := surf.renderer_state.terminal_.screens.active.pages.pin(terminal.PinOpts{
		tag: .active
		x: 4
		y: 0
	}) or { panic('no end pin') }
	surf.copy_selection_to_clipboards(terminal.Selection.init(start, end, false), [
		.standard,
		.selection,
	], .mixed)!
	for loc in [apprt.Clipboard.standard, .selection] {
		contents := runtime.clipboards[loc]
		assert contents.len == 2
		assert contents[0].mime == 'text/plain'
		assert contents[0].data == 'hello'
		assert contents[1].mime == 'text/html'
		assert contents[1].data.contains('hello')
	}
}

fn test_copy_url_to_clipboard_uses_configured_trailing_space_policy() ! {
	mut surf := make_test_surface()
	surf.size = make_test_size()
	surf.config.clipboard_trim_trailing_spaces = false
	surf.config.links = [DerivedConfigLink{
		regex: oniguruma.Regex.init(r'http://a   ', oniguruma.Options{}, .utf8, .default_, none)!
		action: .open
		highlight: .hover
	}]
	defer { surf.config.links[0].regex.deinit() }
	surf.mouse.over_link = true
	mut runtime := apprt.RuntimeSurface{
		cursor_pos: apprt.CursorPos{ x: 6, y: 6 }
	}
	surf.rt_surface = &runtime
	mut stream := surf.renderer_state.terminal_.vt_stream()
	stream.next_slice('http://a   ')!

	assert surf.perform_binding_action(input.Action.new(.copy_url_to_clipboard))!
	contents := runtime.clipboards[.standard]
	assert contents.len == 1
	assert contents[0].data == 'http://a   '
}

fn test_mouse_link_preview_forwards_untrimmed_url() ! {
	mut surf := make_test_surface()
	surf.size = make_test_size()
	surf.config.link_previews = .true_
	surf.config.links = [DerivedConfigLink{
		regex: oniguruma.Regex.init(r'http://a   ', oniguruma.Options{}, .utf8, .default_, none)!
		action: .open
		highlight: .hover
	}]
	defer { surf.config.links[0].regex.deinit() }
	mut runtime := apprt.RuntimeApp{}
	surf.rt_app = &runtime
	mut stream := surf.renderer_state.terminal_.vt_stream()
	stream.next_slice('http://a   ')!

	surf.mouse_refresh_links(apprt.CursorPos{ x: 6, y: 6 }, Coordinate{ x: 0, y: 0 }, false)!
	assert surf.mouse.over_link
	assert surf.renderer_state.terminal_.screens.active.dirty.hyperlink_hover()
	assert runtime.actions.len == 2
	assert runtime.actions[0].action == .mouse_shape
	assert runtime.actions[1].action == .mouse_over_link
	assert runtime.actions[1].data.mouse_over_link_.url == 'http://a   '
}

struct RuntimeCallbackProbe {
mut:
	action_kind apprt.ActionKey
	clipboard   apprt.Clipboard
	closed      bool
	confirmed   bool
}

fn runtime_action_probe(data voidptr, action apprt.RuntimeAction) !bool {
	mut probe := unsafe { &RuntimeCallbackProbe(data) }
	probe.action_kind = action.action
	return true
}

fn runtime_action_failure(_ voidptr, _ apprt.RuntimeAction) !bool {
	return error('runtime action failed')
}

fn test_surface_best_effort_notifications_ignore_runtime_errors() {
	mut runtime := apprt.RuntimeApp{
		action_fn: runtime_action_failure
	}
	mut surf := Surface{
		rt_app: &runtime
	}
	mut failed := false
	surf.handle_message(SurfaceMessage{ kind: .ring_bell }) or { failed = true }
	assert !failed
	surf.handle_message(SurfaceMessage{
		kind: .progress_report
		progress_report: osc.ProgressReport{}
	}) or { failed = true }
	assert !failed
}

fn test_surface_ring_bell_uses_monotonic_rate_limit() ! {
	mut runtime := apprt.RuntimeApp{}
	mut surf := Surface{
		rt_app: &runtime
	}
	surf.handle_message(SurfaceMessage{ kind: .ring_bell })!
	first := surf.last_bell_time or {
		assert false, 'bell did not store a timestamp'
		return
	}
	surf.handle_message(SurfaceMessage{ kind: .ring_bell })!
	assert surf.last_bell_time? >= first
	assert runtime.actions.len == 1
}

fn runtime_close_probe(data voidptr, confirm bool) {
	mut probe := unsafe { &RuntimeCallbackProbe(data) }
	probe.closed = true
	probe.confirmed = confirm
}

fn runtime_scale_probe(data voidptr) !apprt.ContentScale {
	_ = data
	return apprt.ContentScale{ x: 2, y: 3 }
}

fn runtime_env_probe(data voidptr) !map[string]string {
	_ = data
	return {
		'WITTY_TEST_ENV': 'runtime'
	}
}

fn runtime_supports_clipboard_probe(data voidptr, clipboard apprt.Clipboard) bool {
	mut probe := unsafe { &RuntimeCallbackProbe(data) }
	probe.clipboard = clipboard
	return clipboard == .primary
}

fn test_runtime_callbacks_override_headless_storage() ! {
	mut probe := RuntimeCallbackProbe{}
	mut app := apprt.RuntimeApp{
		user_data: &probe
		action_fn: runtime_action_probe
	}
	assert app.perform_action(apprt.Target(apprt.AppTarget{}), .ring_bell, apprt.ActionValue{})!
	assert probe.action_kind == .ring_bell
	assert app.actions.len == 0

	mut surface := apprt.RuntimeSurface{
		user_data: &probe
		close_fn: runtime_close_probe
		content_scale_fn: runtime_scale_probe
		supports_clipboard_fn: runtime_supports_clipboard_probe
		default_env_fn: runtime_env_probe
	}
	surface.close(true)
	assert probe.closed
	assert probe.confirmed
	assert !surface.closed
	assert surface.get_content_scale()! == apprt.ContentScale{ x: 2, y: 3 }
	assert surface.supports_clipboard(.primary)
	assert probe.clipboard == .primary
	assert !surface.supports_clipboard(.selection)
	assert probe.clipboard == .selection
	assert surface.default_termio_env()!['WITTY_TEST_ENV'] == 'runtime'
}

fn test_runtime_surface_clones_configured_default_environment() ! {
	surface := apprt.RuntimeSurface{
		default_env: {
			'WITTY_TEST_ENV': 'configured'
		}
	}
	mut env := surface.default_termio_env()!
	env['WITTY_TEST_ENV'] = 'changed'
	assert surface.default_env['WITTY_TEST_ENV'] == 'configured'
}

fn test_open_url_preserves_content_kind_for_runtime() ! {
	mut runtime := apprt.RuntimeApp{ actions_handled: true }
	mut surface := make_test_surface()
	surface.rt_app = &runtime
	surface.open_url(apprt.OpenUrl{
		kind: .html
		url: '/tmp/export.html'
	})!

	assert runtime.actions.len == 1
	assert runtime.actions[0].action == .open_url
	assert runtime.actions[0].data.open_url_.kind == .html
	assert runtime.actions[0].data.open_url_.url == '/tmp/export.html'
}

fn test_command_finished_preserves_duration_and_exit_code() ! {
	mut runtime := apprt.RuntimeApp{ actions_handled: true }
	mut surf := make_test_surface()
	surf.rt_app = &runtime
	surf.command_timer = time.sys_mono_now() - 1_234_567
	surf.handle_message(apprt.SurfaceMessage{
		kind: .stop_command
		stop_command_exit_code: u8(7)
	})!

	assert surf.command_timer == none
	assert runtime.actions.len == 1
	assert runtime.actions[0].action == .command_finished
	assert runtime.actions[0].data.command_finished_.exit_code? == 7
	assert runtime.actions[0].data.command_finished_.duration.duration >= 1_234_567
}
