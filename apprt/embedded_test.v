module apprt

import configpkg
import input
import cimgui
import os

struct EmbeddedActionCapture {
mut:
	calls  int
	target Target = AppTarget{}
	action RuntimeAction
}

struct EmbeddedClipboardCapture {
mut:
	read_clipboard int
	read_state     &ClipboardRequest = unsafe { nil }
	write_count    usize
	write_mime     string
	write_data     string
	write_confirm  bool
}

struct EmbeddedSurfaceConfigCapture {
mut:
	input_items []configpkg.ReadableIO
}

fn embedded_surface_config_capture_init(config &configpkg.Config, core_app &CoreApp, _ &App, _ voidptr) !voidptr {
	mut capture := unsafe { &EmbeddedSurfaceConfigCapture(core_app.backend) }
	capture.input_items = config.input.items.clone()
	return unsafe { nil }
}

fn embedded_read_clipboard_test_callback(userdata voidptr, clipboard int, state &ClipboardRequest) {
	mut capture := unsafe { &EmbeddedClipboardCapture(userdata) }
	capture.read_clipboard = clipboard
	unsafe { capture.read_state = state }
}

fn embedded_write_clipboard_c_test_callback(userdata voidptr, _ int, contents &CAPIClipboardContentC, count usize, confirm bool) {
	mut capture := unsafe { &EmbeddedClipboardCapture(userdata) }
	capture.write_count = count
	capture.write_confirm = confirm
	if count > 0 {
		capture.write_mime = unsafe { cstring_to_vstring(contents[0].mime) }
		capture.write_data = unsafe { cstring_to_vstring(contents[0].data) }
	}
}

fn embedded_action_test_callback(app &App, target Target, action RuntimeAction) bool {
	mut capture := unsafe { &EmbeddedActionCapture(app.opts.userdata) }
	capture.calls++
	capture.target = target
	capture.action = action

	match target {
		AppTarget {
			return action.action == .open_config
		}
		SurfaceTarget {
			match action.target {
				SurfaceTarget {
					return target.surface != unsafe { nil } && action.target.surface == target.surface
				}
				AppTarget {
					return false
				}
			}
		}
	}
}

fn test_embedded_perform_ipc_reports_unhandled() {
	assert perform_ipc('new-window')! == false
}

fn test_surface_size_info_grid_enforces_source_minimum() {
	grid := SurfaceSizeInfo{
		screen: ScreenSizeInfo{ width: 3, height: 5 }
		cell: CellSizeInfo{ width: 8, height: 16 }
	}.grid()
	assert grid.columns == 1
	assert grid.rows == 1

	larger := SurfaceSizeInfo{
		screen: ScreenSizeInfo{ width: 81, height: 49 }
		cell: CellSizeInfo{ width: 8, height: 16 }
	}.grid()
	assert larger.columns == 10
	assert larger.rows == 3
}

fn test_embedded_clipboard_c_callbacks_preserve_request_and_project_contents() {
	mut capture := EmbeddedClipboardCapture{}
	mut app := App{
		opts: AppOptions{
			read_clipboard_cb: embedded_read_clipboard_test_callback
			c_write_clipboard_cb: embedded_write_clipboard_c_test_callback
		}
	}
	mut surface := Surface{
		app: &app
		userdata: voidptr(&capture)
	}
	request := ClipboardRequest{ kind: .osc_52_read, clipboard: .selection }
	assert surface.clipboard_request(.selection, request)!
	assert capture.read_clipboard == int(Clipboard.selection)
	assert !isnil(capture.read_state)
	assert capture.read_state.kind == .osc_52_read
	assert capture.read_state.clipboard == .selection

	surface.complete_clipboard_request('clipboard response', capture.read_state, true)
	surface.set_clipboard(.standard, [ClipboardContent{
		mime: 'text/plain'
		data: 'clipboard value'
	}], true)!
	assert capture.write_count == 1
	assert capture.write_mime == 'text/plain'
	assert capture.write_data == 'clipboard value'
	assert capture.write_confirm
}

fn test_embedded_action_callback_receives_target_tag_and_payload() {
	mut capture := EmbeddedActionCapture{}
	mut app := App{
		opts: AppOptions{
			userdata: voidptr(&capture)
			action_cb: embedded_action_test_callback
		}
	}
	assert app.perform_action(Target(AppTarget{}), .open_config, ActionVoid{})!
	assert capture.calls == 1
	assert capture.action.action == .open_config

	mut core_surface := CoreSurface{}
	target := Target(SurfaceTarget{ surface: voidptr(&core_surface) })
	action := RuntimeAction{
		target: target
		action: .resize_split
		data: ActionValue(ResizeSplit{
				direction: .left
				amount: 42
			})
	}
	assert app.perform_action(target, action.action, action.data)!
	assert capture.calls == 2
	assert action_value[ResizeSplit](action.data).direction == .left
	assert action_value[ResizeSplit](action.data).amount == 42
}

fn test_core_app_key_event_dispatches_app_binding() {
	mut capture := EmbeddedActionCapture{}
	mut config := configpkg.Config.default_config()
	trigger := input.Trigger{
		key: input.TriggerKey.new_physical(.f25)
		mods: input.Mods.init(false, true, true, false, false, false, input.SideInfo{})
	}
	config.keybind.set.put(trigger, input.ActionOpenConfig{})
	mut core_app := CoreApp{}
	mut app := App{
		core_app: &core_app
		config: config
		opts: AppOptions{
			userdata: voidptr(&capture)
			action_cb: embedded_action_test_callback
		}
	}
	event := input.KeyEvent{
		action: .press
		key: .f25
		mods: input.Mods.init(false, true, true, false, false, false, input.SideInfo{})
	}
	assert core_app.key_event_is_binding(&app, voidptr(&event))
	assert core_app.key_event(&app, voidptr(&event))
	assert capture.calls == 1
	assert capture.action.action == .open_config

	release := input.KeyEvent{
		...event
		action: .release
	}
	assert !core_app.key_event_is_binding(&app, voidptr(&release))
	assert !core_app.key_event(&app, voidptr(&release))
}

fn test_core_app_key_event_is_binding_includes_leader_entries() {
	mut config := configpkg.Config.default_config()
	config.keybind.set.parse_and_put('ctrl+a>b=new_window') or { panic(err.msg()) }
	mut core_app := CoreApp{}
	app := App{
		core_app: &core_app
		config: config
	}
	event := input.KeyEvent{
		action: .press
		key: .key_a
		mods: input.Mods.init(false, true, false, false, false, false, input.SideInfo{})
		utf8: 'a'
	}

	assert core_app.key_event_is_binding(&app, voidptr(&event))
	assert !core_app.key_event(&app, voidptr(&event))
}

fn test_core_app_focus_limits_non_global_bindings() {
	mut capture := EmbeddedActionCapture{}
	mut config := configpkg.Config.default_config()
	local_trigger := input.Trigger{
		key: input.TriggerKey.new_physical(.f24)
	}
	global_trigger := input.Trigger{
		key: input.TriggerKey.new_physical(.f25)
	}
	config.keybind.set.put(local_trigger, input.ActionOpenConfig{})
	config.keybind.set.put_flags(global_trigger, input.ActionOpenConfig{}, input.Flags.init(true, false, true, false))
	mut core_app := CoreApp{}
	mut app := App{
		core_app: &core_app
		config: config
		opts: AppOptions{
			userdata: voidptr(&capture)
			action_cb: embedded_action_test_callback
		}
	}
	core_app.focus_event(false)
	local_event := input.KeyEvent{ action: .press, key: .f24 }
	assert !core_app.key_event(&app, voidptr(&local_event))
	assert capture.calls == 0
	global_event := input.KeyEvent{ action: .press, key: .f25 }
	assert core_app.key_event(&app, voidptr(&global_event))
	assert capture.calls == 1
}

fn test_core_app_color_scheme_reloads_only_on_change() {
	mut capture := EmbeddedActionCapture{}
	mut core_app := CoreApp{}
	mut app := App{
		core_app: &core_app
		opts: AppOptions{
			userdata: voidptr(&capture)
			action_cb: embedded_action_test_callback
		}
	}
	core_app.color_scheme_event(&app, .light)!
	assert capture.calls == 0
	core_app.color_scheme_event(&app, .dark)!
	assert capture.calls == 1
	assert capture.action.action == .reload_config
	assert action_value[ReloadConfig](capture.action.data).soft
	core_app.color_scheme_event(&app, .dark)!
	assert capture.calls == 1
}

fn test_core_app_update_config_clones_and_propagates() {
	mut capture := EmbeddedActionCapture{}
	mut core_app := CoreApp{}
	mut surface := Surface{}
	core_app.add_surface(voidptr(&surface))!
	mut app := App{
		core_app: &core_app
		config: configpkg.Config.default_config()
		opts: AppOptions{
			userdata: voidptr(&capture)
			action_cb: embedded_action_test_callback
		}
	}
	mut updated := configpkg.Config.default_config()
	updated.font_size = 21
	updated.macos_option_as_alt = .left
	core_app.update_config(&app, voidptr(&updated))!
	assert capture.action.action == .config_change
	assert app.config.font_size == 21
	assert surface.core_surface.config.macos_option_as_alt? == .left

	// The runtime owns a clone; the caller can mutate or release its config as
	// soon as update_config returns.
	updated.font_size = 9
	assert app.config.font_size == 21
}

fn test_core_app_fallback_delete_surface_uses_swap_remove() {
	mut first := Surface{}
	mut second := Surface{}
	mut third := Surface{}
	mut core_app := CoreApp{}
	core_app.add_surface(voidptr(&first))!
	core_app.add_surface(voidptr(&second))!
	core_app.add_surface(voidptr(&third))!

	core_app.delete_surface(voidptr(&first))
	assert core_app.surfaces.len == 2
	assert core_app.surfaces[0] == voidptr(&third)
	assert core_app.surfaces[1] == voidptr(&second)
}

fn test_core_app_fallback_update_config_applies_conditional_state() {
	theme_dir := os.join_path(os.temp_dir(), 'witty-apprt-config-${os.getpid()}')
	os.rmdir_all(theme_dir) or {}
	os.mkdir_all(theme_dir)!
	defer {
		os.rmdir_all(theme_dir) or {}
	}
	light_theme := os.join_path(theme_dir, 'light')
	dark_theme := os.join_path(theme_dir, 'dark')
	os.write_file(light_theme, 'font-size = 17\n')!
	os.write_file(dark_theme, 'font-size = 19\n')!
	mut updated := configpkg.Config.default_config()
	updated.load_string('theme = light:${light_theme},dark:${dark_theme}\n')
	updated.finalize()!

	mut core_app := CoreApp{
		config_conditional_state: configpkg.ConditionalState{ theme: .dark }
	}
	mut app := App{
		core_app: &core_app
		config: configpkg.Config.default_config()
	}
	core_app.update_config(&app, voidptr(&updated))!
	assert app.config.font_size == f32(19)
}

fn test_embedded_capi_enum_validation() {
	assert color_scheme_from_int(int(ColorScheme.light))? == .light
	assert color_scheme_from_int(int(ColorScheme.dark))? == .dark
	assert color_scheme_from_int(-1) == none
	assert color_scheme_from_int(99) == none
}

fn test_embedded_split_helpers_dispatch_surface_actions() {
	mut capture := EmbeddedActionCapture{}
	mut app := App{
		opts: AppOptions{
			userdata: voidptr(&capture)
			action_cb: embedded_action_test_callback
		}
	}
	mut surface := Surface{ app: &app }

	ghostty_surface_split(mut surface, .down)
	assert capture.action.action == .new_split
	assert action_value[SplitDirection](capture.action.data) == .down

	ghostty_surface_split_focus(mut surface, .previous)
	assert capture.action.action == .goto_split
	assert action_value[GotoSplit](capture.action.data) == .previous

	ghostty_surface_split_resize(mut surface, .right, 17)
	assert capture.action.action == .resize_split
	assert action_value[ResizeSplit](capture.action.data).direction == .right
	assert action_value[ResizeSplit](capture.action.data).amount == 17

	ghostty_surface_split_equalize(mut surface)
	assert capture.action.action == .equalize_splits
	match capture.target {
		SurfaceTarget {
			assert capture.target.surface == voidptr(&surface.core_surface)
		}
		AppTarget {
			assert false, 'split helper must target its surface'
		}
	}
	assert capture.calls == 4
}

fn test_embedded_binding_action_rejects_invalid_syntax() {
	mut surface := Surface{}
	assert !ghostty_surface_binding_action(mut surface, 'not_an_action')
}

fn test_embedded_inspector_context_and_input_dispatch() {
	if !cimgui.available() {
		return
	}
	mut capture := EmbeddedActionCapture{}
	mut app := App{
		opts: AppOptions{
			userdata: voidptr(&capture)
			action_cb: embedded_action_test_callback
		}
	}
	mut surface := Surface{ app: &app }
	mut inspector := TerminalInspector{}
	inspector.init(mut surface)!
	assert !isnil(inspector.context.handle)

	inspector.update_size(640, 480)
	width, height := inspector.context.display_size()
	assert width == 640
	assert height == 480
	inspector.update_content_scale(2, 2)
	assert inspector.content_scale == 2

	inspector.mouse_button_callback(.press, .left, input.Mods{})
	inspector.scroll_callback(10, -20, input.ScrollMods.init(true, .none_))
	inspector.cursor_pos_callback(12, 24)
	inspector.focus_callback(true)
	inspector.text_callback('hello')
	inspector.key_callback(.press, .key_a, input.Mods.init(false, false, false, true, false, false, input.SideInfo{}))!
	assert capture.action.action == .render_inspector
	match capture.target {
		SurfaceTarget {
			assert capture.target.surface == voidptr(&surface.core_surface)
		}
		AppTarget {
			assert false, 'inspector redraw must target its surface'
		}
	}

	inspector.deinit()
	assert isnil(inspector.context.handle)
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
		mods: input.Mods.init(true, false, false, false, false, false, input.SideInfo{})
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
	assert core_event.mods.shift() == true
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

// Test EmbeddedKeyEvent.core with the source u21 cast boundary.
fn test_embedded_key_event_u21_codepoint_boundary() {
	in_range := EmbeddedKeyEvent{
		action: .press
		mods: input.Mods{}
		consumed_mods: input.Mods{}
		keycode: 0
		text: none
		unshifted_codepoint: 0x1FFFFF
		composing: false
	}
	core_event := in_range.core() or {
		assert false, 'core() should not return none'
		return
	}
	assert core_event.unshifted_codepoint == 0x1FFFFF

	too_large := EmbeddedKeyEvent{
		action: .press
		mods: input.Mods{}
		consumed_mods: input.Mods{}
		keycode: 0
		text: none
		unshifted_codepoint: 0x200000
		composing: false
	}
	clamped := too_large.core() or {
		assert false, 'core() should not return none'
		return
	}
	assert clamped.unshifted_codepoint == 0
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
	assert event.mods.shift() == true
	assert event.mods.alt() == true
	assert event.mods.ctrl() == false
	assert event.consumed_mods.shift() == true
	assert event.consumed_mods.alt() == false
	assert event.keycode == 10
}

// Test mods_from_int / mods_to_int roundtrip.
fn test_mods_roundtrip() {
	original := input.Mods.init(true, true, true, true, true, true, input.SideInfo.init(.right, .right, .right, .right))

	encoded := mods_to_int(original)
	decoded := mods_from_int(encoded)

	assert decoded.shift() == original.shift()
	assert decoded.ctrl() == original.ctrl()
	assert decoded.alt() == original.alt()
	assert decoded.super_() == original.super_()
	assert decoded.caps_lock() == original.caps_lock()
	assert decoded.num_lock() == original.num_lock()
	assert decoded.sides().shift() == original.sides().shift()
	assert decoded.sides().ctrl() == original.sides().ctrl()
	assert decoded.sides().alt() == original.sides().alt()
	assert decoded.sides().super_() == original.sides().super_()
}

// Test mods_from_int with zero.
fn test_mods_from_int_zero() {
	m := mods_from_int(0)
	assert m.shift() == false
	assert m.ctrl() == false
	assert m.alt() == false
	assert m.super_() == false
}

// Test mods_to_int with all set.
fn test_mods_to_int_all() {
	m := input.Mods.init(true, true, true, true, true, true, input.SideInfo.init(.right, .right, .right, .right))
	assert mods_to_int(m) == 0x3FF
	assert mods_to_int(mods_from_int(0xffff)) == 0xffff
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
		$if !macos && !ios {
			assert err.msg() == 'UnsupportedPlatform'
			return
		}
		assert false, 'should not fail'
		return
	}
	$if !macos && !ios {
		assert false, 'should have failed'
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
		$if macos || ios {
			assert err.msg() == 'NSView must be set'
		} $else {
			assert err.msg() == 'UnsupportedPlatform'
		}
		return
	}
	assert false, 'should have failed'
}

fn test_platform_init_rejects_invalid_tag() {
	for tag in [0, 3, -1] {
		platform_init(tag, PlatformC{}) or {
			assert err.msg() == 'InvalidEnumTag'
			continue
		}
		assert false, 'should have rejected platform tag ${tag}'
	}
}

fn test_surface_init_preserves_explicit_scale_factor() {
	$if macos || ios {
		mut core_app := CoreApp{}
		mut app := App{
			core_app: &core_app
			config: configpkg.Config.default_config()
		}
		mut surface := Surface{}
		surface.init(mut app, SurfaceOptions{
			platform_tag: int(PlatformTag.macos)
			platform: PlatformC{ nsview: voidptr(usize(0xDEAD)) }
			scale_factor: -2.25
		})!
		defer {
			surface.deinit()
			app.config.deinit()
		}
		assert surface.content_scale.x == f32(-2.25)
		assert surface.content_scale.y == f32(-2.25)
	}
}

fn test_surface_init_present_empty_input_clears_configured_input() {
	$if macos || ios {
		previous_bridge := g_core_bridge
		defer {
			install_core_bridge(previous_bridge)
		}
		install_core_bridge(CoreBridge{
			surface_init: embedded_surface_config_capture_init
		})

		mut capture := EmbeddedSurfaceConfigCapture{}
		mut core_app := CoreApp{
			backend: voidptr(&capture)
		}
		mut config := configpkg.Config.default_config()
		config.input.items << configpkg.ReadableIO{
			kind: .raw
			value: 'configured input'
		}
		mut app := App{
			core_app: &core_app
			config: config
		}
		mut surface := Surface{}
		surface.init(mut app, SurfaceOptions{
			platform_tag: int(PlatformTag.macos)
			platform: PlatformC{ nsview: voidptr(usize(0xDEAD)) }
			initial_input: ''
		})!
		defer {
			surface.deinit()
		}

		assert capture.input_items == [configpkg.ReadableIO{
			kind: .raw
			value: ''
		}]
	}
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

fn test_capi_text_length_is_pointer_width() {
	max_len := ~usize(0)
	mut text := CAPIText{ text_len: max_len }
	assert text.text_len == max_len
	text.deinit()
	assert text.text_len == 0
}

// Test CAPIPoint tag values.
fn test_capi_point_tag_values() {
	assert sizeof(CAPIPointTag) == 4
	assert int(CAPIPointTag.active) == 0
	assert int(CAPIPointTag.viewport) == 1
	assert int(CAPIPointTag.screen) == 2
	assert int(CAPIPointTag.history) == 3
}

// Test CAPICoordTag values.
fn test_capi_coord_tag_values() {
	assert sizeof(CAPICoordTag) == 4
	assert int(CAPICoordTag.exact) == 0
	assert int(CAPICoordTag.top_left) == 1
	assert int(CAPICoordTag.bottom_right) == 2
}

fn test_platform_tag_c_abi_layout_and_values() {
	assert sizeof(PlatformTag) == 4
	assert [PlatformTag.macos, .ios].map(i32(it)) == [i32(1), 2]
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
	leader.put_flags(input.Trigger.parse('b')!, input.ActionNewWindow{}, input.Flags.init(true, false, true, false))
	app.config.keybind.set.bindings << input.SetEntry{
		trigger: input.Trigger.parse('ctrl+a')!
		value: input.SetValue{
			typ: .leader
			leader: &leader
		}
	}
	assert !app.has_global_keybinds()
}

fn test_set_window_background_blur_accepts_null_window() {
	mut app := App{}
	// Opaque windows return before entering the platform bridge.
	ghostty_set_window_background_blur(&app, unsafe { nil })

	// A null Objective-C object is also a safe no-op in the bridge. Exercising
	// this branch ensures the platform implementation and private API symbols
	// are compiled and linked by the test executable.
	app.config.background_opacity = 0.5
	app.config.background_blur = configpkg.BackgroundBlur{
		kind: .bool_true
	}
	ghostty_set_window_background_blur(&app, unsafe { nil })
}

fn test_core_surface_retains_embedded_macos_option_as_alt() {
	mut cfg := configpkg.Config.default_config()
	cfg.macos_option_as_alt = .right
	mut core_app := CoreApp{}
	mut app := App{}
	mut surface := CoreSurface{}
	surface.init(&cfg, &core_app, &app, unsafe { nil })!
	assert surface.config.macos_option_as_alt? == .right
}

fn test_surface_key_translation_mods_honors_explicit_option_as_alt() {
	$if macos {
		mut surface := Surface{}
		surface.core_surface.config.macos_option_as_alt = .true_
		mods := input.Mods.init(false, false, true, false, false, false, input.SideInfo.init(.left, .left, .left, .left))
		translated := mods_from_int(ghostty_surface_key_translation_mods(&surface, mods_to_int(mods)))
		assert !translated.alt()
	}
}

// The source reads an action's value as `value.<field>`; V needs the variant.
fn action_value[T](v ActionValue) T {
	if v is T {
		return v
	}
	panic('action value is not the expected variant')
}
