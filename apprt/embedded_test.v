module apprt

import input

fn test_embedded_perform_ipc_reports_unhandled() {
	assert perform_ipc('new-window')! == false
}

// Test creating default AppOptions.
fn test_app_options_default() {
	opts := AppOptions{}
	assert opts.userdata == unsafe { nil }
	assert opts.supports_selection_clipboard == false
}

// Test creating default SurfaceOptions.
fn test_surface_options_default() {
	opts := SurfaceOptions{}
	assert opts.scale_factor == 1.0
	assert opts.font_size == 0
	assert opts.wait_after_command == false
	assert opts.context == .window
}

// Test EmbeddedKeyEvent.core conversion.
fn test_embedded_key_event_core() {
	event := EmbeddedKeyEvent{
		action: .press
		mods: input.Mods{ shift: true }
		consumed_mods: input.Mods{}
		keycode: 0
		text: 'A'
		unshifted_codepoint: 0x41
		composing: false
	}

	core_event := event.core() or {
		assert false, 'core() should not return none'
		return
	}

	assert core_event.action == .press
	assert core_event.mods.shift == true
	assert core_event.utf8 == 'A'
	assert core_event.unshifted_codepoint == 0x41
	assert core_event.composing == false
}

// Test EmbeddedKeyEvent.core with no text.
fn test_embedded_key_event_core_no_text() {
	event := EmbeddedKeyEvent{
		action: .release
		mods: input.Mods{}
		consumed_mods: input.Mods{}
		keycode: 42
		text: none
		unshifted_codepoint: 0
		composing: false
	}

	core_event := event.core() or {
		assert false, 'core() should not return none'
		return
	}

	assert core_event.action == .release
	assert core_event.utf8 == ''
	assert core_event.unshifted_codepoint == 0
}

// Test EmbeddedKeyEvent.core with oversized codepoint clamping.
fn test_embedded_key_event_oversized_codepoint() {
	event := EmbeddedKeyEvent{
		action: .press
		mods: input.Mods{}
		consumed_mods: input.Mods{}
		keycode: 0
		text: none
		unshifted_codepoint: 0xFFFFFFFF // too large for valid Unicode
		composing: false
	}

	core_event := event.core() or {
		assert false, 'core() should not return none'
		return
	}

	// Should be clamped to 0 since it exceeds U+10FFFF.
	assert core_event.unshifted_codepoint == 0
}

// Test CAPIKeyEvent conversion.
fn test_capi_key_event_conversion() {
	capi := CAPIKeyEvent{
		action: .press
		mods: 0x05 // shift + alt
		consumed_mods: 0x01 // shift
		keycode: 10
		text: 'a'
		unshifted_codepoint: 0x61
		composing: false
	}

	event := capi.key_event()
	assert event.action == .press
	assert event.mods.shift == true
	assert event.mods.alt == true
	assert event.mods.ctrl == false
	assert event.consumed_mods.shift == true
	assert event.consumed_mods.alt == false
	assert event.keycode == 10
}

// Test mods_from_int / mods_to_int roundtrip.
fn test_mods_roundtrip() {
	original := input.Mods{
		shift: true
		ctrl: false
		alt: true
		super_: true
	}

	encoded := mods_to_int(original)
	decoded := mods_from_int(encoded)

	assert decoded.shift == original.shift
	assert decoded.ctrl == original.ctrl
	assert decoded.alt == original.alt
	assert decoded.super_ == original.super_
}

// Test mods_from_int with zero.
fn test_mods_from_int_zero() {
	m := mods_from_int(0)
	assert m.shift == false
	assert m.ctrl == false
	assert m.alt == false
	assert m.super_ == false
}

// Test mods_to_int with all set.
fn test_mods_to_int_all() {
	m := input.Mods{
		shift: true
		ctrl: true
		alt: true
		super_: true
	}
	assert mods_to_int(m) == 0x0F
}

// Test PlatformTag enum values.
fn test_platform_tag_values() {
	assert int(PlatformTag.macos) == 1
	assert int(PlatformTag.ios) == 2
}

// Test platform_init with macOS.
fn test_platform_init_macos() {
	dummy_view := voidptr(usize(0xDEAD))
	p := platform_init(1, PlatformC{ nsview: dummy_view }) or {
		assert false, 'should not fail'
		return
	}
	match p {
		MacOSPlatform {
			assert p.nsview == dummy_view
		}
		IOSPlatform {
			assert false, 'expected macOS'
		}
	}
}

// Test platform_init with null nsview fails.
fn test_platform_init_macos_null() {
	platform_init(1, PlatformC{}) or {
		assert err.msg() == 'NSView must be set'
		return
	}
	assert false, 'should have failed'
}

// Test CAPIText deinit.
fn test_capi_text_deinit() {
	mut text := CAPIText{
		tl_px_x: 10.0
		tl_px_y: 20.0
		offset_start: 0
		offset_len: 5
		text: 'hello'
		text_len: 5
	}

	text.deinit()
	assert text.text == none
	assert text.text_len == 0
}

// Test CAPIPoint tag values.
fn test_capi_point_tag_values() {
	assert int(CAPIPointTag.active) == 0
	assert int(CAPIPointTag.viewport) == 1
	assert int(CAPIPointTag.screen) == 2
	assert int(CAPIPointTag.history) == 3
}

// Test CAPICoordTag values.
fn test_capi_coord_tag_values() {
	assert int(CAPICoordTag.exact) == 0
	assert int(CAPICoordTag.top_left) == 1
	assert int(CAPICoordTag.bottom_right) == 2
}

// Test ghostty_surface_config_new returns defaults.
fn test_ghostty_surface_config_new() {
	opts := ghostty_surface_config_new()
	assert opts.scale_factor == 1.0
	assert opts.font_size == 0
	assert opts.context == .window
}

// Test ColorScheme enum.
fn test_color_scheme() {
	assert ColorScheme.light != ColorScheme.dark
}

// Test NewSurfaceContext enum.
fn test_new_surface_context() {
	assert NewSurfaceContext.window != NewSurfaceContext.tab
	assert NewSurfaceContext.tab != NewSurfaceContext.split
}

// Test CAPISurfaceSize fields.
fn test_capi_surface_size() {
	s := CAPISurfaceSize{
		columns: 80
		rows: 24
		width_px: 800
		height_px: 600
		cell_width_px: 10
		cell_height_px: 25
	}
	assert s.columns == 80
	assert s.rows == 24
}

// Test Surface supports_clipboard.
fn test_surface_supports_clipboard() {
	mut app := App{
		opts: AppOptions{
			supports_selection_clipboard: false
		}
	}
	surface := Surface{
		app: &app
	}
	assert surface.supports_clipboard(.standard) == true
	assert surface.supports_clipboard(.selection) == false

	app.opts.supports_selection_clipboard = true
	assert surface.supports_clipboard(.selection) == true
}

// Test has_global_keybinds returns false by default.
fn test_has_global_keybinds() {
	app := App{}
	assert app.has_global_keybinds() == false
}

fn test_has_global_keybinds_leaf() {
	mut app := App{}
	app.config.keybind.parse_cli('global:ctrl+a=new_window')!
	assert app.has_global_keybinds()
}

fn test_has_global_keybinds_chained_leaf() {
	mut app := App{}
	app.config.keybind.parse_cli('global:ctrl+a=new_window')!
	app.config.keybind.parse_cli('chain=toggle_fullscreen')!
	assert app.has_global_keybinds()
}

fn test_has_global_keybinds_ignores_global_leaf_under_leader() {
	mut app := App{}
	// Global trigger sequences are invalid, so construct the otherwise-valid
	// nested shape directly to verify parity with Ghostty's top-level scan.
	mut leader := input.Set{}
	leader.put_flags(input.Trigger.parse('b')!, input.Action.new(.new_window), input.Flags{
		global: true
	})
	app.config.keybind.set.bindings << input.SetEntry{
		trigger: input.Trigger.parse('ctrl+a')!
		value: input.SetValue{
			typ: .leader
			leader: &leader
		}
	}
	assert !app.has_global_keybinds()
}
