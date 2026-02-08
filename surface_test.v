module main

import input

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
	mut t := SurfaceTerminal{
		cols: 80
		rows: 24
	}
	return Surface{
		renderer_state: RendererState{
			terminal: &t
		}
	}
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
	assert InputEffect.ignored != InputEffect.consumed
	assert InputEffect.consumed != InputEffect.closed
	assert InputEffect.ignored != InputEffect.closed
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
			PreeditCodepoint{ codepoint: 0x3042, wide: true },  // あ (wide)
			PreeditCodepoint{ codepoint: 0x61, wide: false },    // a (narrow)
			PreeditCodepoint{ codepoint: 0x4e16, wide: true },  // 世 (wide)
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

fn test_end_key_sequence_no_queued() {
	mut surf := Surface{}
	// With no queued items, should just clear sequence_set
	surf.keyboard.sequence_queued = []
	surf.end_key_sequence(.flush, .retain)
	assert surf.keyboard.sequence_set == none
}

fn test_deactivate_all_key_tables_empty() ! {
	mut surf := Surface{}
	// Empty table stack should return false
	result := surf.deactivate_all_key_tables()!
	assert result == false
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
	assert closing_action(BindingAction{ kind: .close_surface }) == true
	assert closing_action(BindingAction{ kind: .close_window }) == true
	assert closing_action(BindingAction{ kind: .close_tab }) == true
	assert closing_action(BindingAction{ kind: .ignore }) == false
	assert closing_action(BindingAction{ kind: .none_ }) == false
}

fn test_has_selection() {
	mut surf := make_test_surface()
	assert surf.has_selection() == false

	surf.renderer_state.terminal.selection = TermSelection{
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
