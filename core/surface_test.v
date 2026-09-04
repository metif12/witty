module core

import input
import apprt
import terminal
import configpkg

// Test helper: sets up a 10x5 cell grid with 10x20px cells and 5px padding on all sides.
fn make_test_size() Size {
	return Size{
		cell: CellSize{ width: 10, height: 20 }
		padding: Padding{ left: 5, top: 5, right: 5, bottom: 5 }
		screen: ScreenSize{ width: 110, height: 110 }
	}
}

// Test helper: creates a Surface with an initialized terminal (avoids nil deref).
fn make_test_surface() Surface {
	mut t := terminal.Terminal.init(terminal.Options{ cols: 80, rows: 24 }) or { panic(err) }
	return Surface{
		renderer_state: RendererState{
			terminal: &t
		}
	}
}

fn test_derived_config_uses_selection_and_clipboard_maps() {
	mut cfg := configpkg.Config.default_config()
	cfg.selection_word_chars.parse_cli('._')!
	cfg.clipboard_codepoint_map.parse_cli('U+2500=U+002D')!
	derived := DerivedConfig.from_config(&cfg)!
	assert derived.selection_word_chars == [u32(0), u32(`.`), u32(`_`)]
	assert derived.clipboard_codepoint_map.len == 1
	assert derived.clipboard_codepoint_map[0].range_start == 0x2500
}

fn test_surface_key_binding_applies_modifier_remap() {
	mut cfg := configpkg.Config.default_config()
	cfg.keybind.set = input.Set{}
	cfg.keybind.set.put(input.Trigger{
		key: input.TriggerKey.new_unicode(u32(`q`))
		mods: input.Mods{ super_: true }
	}, input.Action.new(.quit))
	cfg.key_remap.parse('ctrl=super')!
	cfg.key_remap.finalize()

	mut surf := make_test_surface()
	surf.config = DerivedConfig.from_config(&cfg)!
	flags := surf.key_event_is_binding(input.KeyEvent{
		key: .key_q
		action: .press
		mods: input.Mods{
			ctrl: true
			sides: input.SideInfo{ ctrl: .left }
		}
		utf8: 'q'
	}) or {
		assert false, 'remapped binding was not found'
		return
	}
	assert !flags.global
}

fn test_grid_size_basic() {
	s := make_test_size()
	g := s.grid()
	// usable: 110 - 5 - 5 = 100 width, 110 - 5 - 5 = 100 height
	// cols = 100 / 10 = 10, rows = 100 / 20 = 5
	assert g.columns == 10
	assert g.rows == 5
}

fn test_grid_size_zero_cell() {
	s := Size{
		cell: CellSize{ width: 0, height: 0 }
		padding: Padding{}
		screen: ScreenSize{ width: 100, height: 100 }
	}
	g := s.grid()
	assert g.columns == 0
	assert g.rows == 0
}

fn test_grid_size_large_padding() {
	s := Size{
		cell: CellSize{ width: 10, height: 10 }
		padding: Padding{ left: 50, top: 50, right: 50, bottom: 50 }
		screen: ScreenSize{ width: 100, height: 100 }
	}
	g := s.grid()
	// usable: 100 - 50 - 50 = 0
	assert g.columns == 0
	assert g.rows == 0
}

fn test_screen_size_equals() {
	a := ScreenSize{ width: 100, height: 200 }
	b := ScreenSize{ width: 100, height: 200 }
	c := ScreenSize{ width: 100, height: 201 }
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
	surf.mouse.pressure_stage = .light
	// Same stage should be a no-op
	surf.mouse_pressure_callback(.light, 0.5)!
	assert surf.mouse.pressure_stage == .light
}

fn test_mouse_pressure_callback_change() ! {
	mut surf := make_test_surface()
	surf.mouse.pressure_stage = .none_
	surf.mouse_pressure_callback(.deep, 0.9)!
	assert surf.mouse.pressure_stage == .deep
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

fn test_size_callback_no_change() ! {
	mut surf := make_test_surface()
	surf.size = Size{
		screen: ScreenSize{ width: 800, height: 600 }
		cell: CellSize{ width: 10, height: 20 }
	}
	// Same size should be a no-op (no error)
	surf.size_callback(800, 600)!
}

fn test_color_scheme_callback_no_change() ! {
	mut surf := make_test_surface()
	surf.config_conditional_state = ConditionalState{ theme: .dark }
	// Same scheme should be a no-op
	surf.color_scheme_callback(.dark)!
	assert surf.config_conditional_state.theme == .dark
}

fn test_color_scheme_callback_change() ! {
	mut surf := make_test_surface()
	surf.config_conditional_state = ConditionalState{ theme: .dark }
	surf.color_scheme_callback(.light)!
	assert surf.config_conditional_state.theme == .light
}

fn test_child_exited_no_wait() {
	mut surf := make_test_surface()
	surf.config = DerivedConfig{
		wait_after_command: false
		abnormal_command_exit_runtime_ms: 500
	}
	assert surf.child_exited == false
	surf.child_exited_handler(1000, 0)
	assert surf.child_exited == true
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
	assert surf.io.messages[0].data.bytestr() == 'one\rtwo'
}

fn test_complete_clipboard_paste_encodes_bracketed_fences() ! {
	mut surf := make_test_surface()
	surf.renderer_state.terminal.modes.set(.bracketed_paste, true)
	surf.complete_clipboard_paste('one\ntwo', true)!
	assert surf.io.messages.len == 3
	assert surf.io.messages.map(it.data.bytestr()).join('') == '\x1b[200~one\ntwo\x1b[201~'
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
	mut runtime := RuntimeSurface{}
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
	assert surf.io.messages[0].data.bytestr() == '\x1b]52;s;aGVsbG8=\x1b\\'
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
	mut runtime := RuntimeSurface{}
	surf.rt_surface = &runtime
	surf.complete_clipboard_request(apprt.ClipboardRequest{
		kind: .osc_52_write
		clipboard: .primary
	}, 'hello', true)!
	assert runtime.clipboards[.primary][0].mime == 'text/plain'
	assert runtime.clipboards[.primary][0].data == 'hello'
}

fn test_end_key_sequence_no_queued() {
	mut runtime := RuntimeApp{}
	mut surf := Surface{ rt_app: &runtime }
	// With no queued items, should just clear sequence_set
	surf.keyboard.sequence_queued = []
	surf.end_key_sequence(.flush, .retain)
	assert surf.keyboard.sequence_set == none
	assert runtime.actions.len == 1
	assert runtime.actions[0].kind == .key_sequence
	assert !runtime.actions[0].key_sequence.active
}

fn test_deactivate_all_key_tables_empty() ! {
	mut surf := Surface{}
	// Empty table stack should return false
	result := surf.deactivate_all_key_tables()!
	assert result == false
}

fn test_deactivate_all_key_tables_action_payload() ! {
	mut runtime := RuntimeApp{ actions_handled: true }
	mut surf := Surface{ rt_app: &runtime }
	surf.keyboard.table_stack << KeyTableEntry{ name: 'copy-mode' }
	assert surf.deactivate_all_key_tables()!
	assert surf.keyboard.table_stack.len == 0
	assert runtime.actions.len == 1
	assert runtime.actions[0].kind == .key_table
	assert runtime.actions[0].key_table.tag == .deactivate_all
}

fn test_deactivate_key_table_action_payload() ! {
	mut runtime := RuntimeApp{ actions_handled: true }
	mut surf := Surface{ rt_app: &runtime }
	surf.keyboard.table_stack << KeyTableEntry{ name: 'copy-mode' }
	assert surf.perform_binding_action(input.Action.new(.deactivate_key_table))!
	assert surf.keyboard.table_stack.len == 0
	assert runtime.actions.len == 1
	assert runtime.actions[0].kind == .key_table
	assert runtime.actions[0].key_table.tag == .deactivate
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
	mut s := Size{
		screen: ScreenSize{ width: 120, height: 120 }
		cell: CellSize{ width: 10, height: 20 }
		padding: Padding{}
	}
	// 120/10 = 12 cols, 12*10 = 120, extra_w = 0
	// 120/20 = 6 rows, 6*20 = 120, extra_h = 0
	explicit := Padding{ left: 5, top: 5, right: 5, bottom: 5 }
	s.balance_padding(explicit)
	// usable: 120 - 10 = 110, 110/10 = 11 cols, 11*10=110, extra=0
	assert s.padding.left >= 5
	assert s.padding.top >= 5
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

	surf.renderer_state.terminal.screens.active.selection = TermSelection{
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
	assert req.data.len > 0
	assert req.data[0] == u8(`a`)
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
	assert req.data.len == 1
	assert req.data[0] == 0x1b
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

fn test_copy_selection_to_standard_clipboard() ! {
	mut surf := make_test_surface()
	mut runtime := RuntimeSurface{}
	surf.rt_surface = &runtime
	for i, cp in 'hello'.runes() {
		surf.renderer_state.terminal.screens.active.pages.screen_rows[0].cells[i] = terminal.CellData.init(u32(cp))
	}
	start := surf.renderer_state.terminal.screens.active.pages.pin(terminal.PinOpts{
		tag: .active
		x: 0
		y: 0
	}) or { panic('no start pin') }
	end := surf.renderer_state.terminal.screens.active.pages.pin(terminal.PinOpts{
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
	mut runtime := RuntimeSurface{}
	surf.rt_surface = &runtime
	for i, cp in 'hello'.runes() {
		surf.renderer_state.terminal.screens.active.pages.screen_rows[0].cells[i] = terminal.CellData.init(u32(cp))
	}
	start := surf.renderer_state.terminal.screens.active.pages.pin(terminal.PinOpts{
		tag: .active
		x: 0
		y: 0
	}) or { panic('no start pin') }
	end := surf.renderer_state.terminal.screens.active.pages.pin(terminal.PinOpts{
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

struct RuntimeCallbackProbe {
mut:
	action_kind AppActionKind
	closed      bool
	confirmed   bool
}

fn runtime_action_probe(data voidptr, action AppAction) !bool {
	mut probe := unsafe { &RuntimeCallbackProbe(data) }
	probe.action_kind = action.kind
	return true
}

fn runtime_close_probe(data voidptr, confirm bool) {
	mut probe := unsafe { &RuntimeCallbackProbe(data) }
	probe.closed = true
	probe.confirmed = confirm
}

fn runtime_scale_probe(data voidptr) !ContentScale {
	_ = data
	return ContentScale{ x: 2, y: 3 }
}

fn test_runtime_callbacks_override_headless_storage() ! {
	mut probe := RuntimeCallbackProbe{}
	mut app := RuntimeApp{
		user_data: &probe
		action_fn: runtime_action_probe
	}
	assert app.perform_action(AppAction{ kind: .ring_bell })!
	assert probe.action_kind == .ring_bell
	assert app.actions.len == 0

	mut surface := RuntimeSurface{
		user_data: &probe
		close_fn: runtime_close_probe
		content_scale_fn: runtime_scale_probe
	}
	surface.close(true)
	assert probe.closed
	assert probe.confirmed
	assert !surface.closed
	assert surface.get_content_scale()! == ContentScale{ x: 2, y: 3 }
}
