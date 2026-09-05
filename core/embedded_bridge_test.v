module core

import apprt
import configpkg
import font
import input
import macos

fn embedded_bridge_test_view() voidptr {
	$if macos {
		return macos.create_offscreen_terminal_view(800, 600)
	} $else {
		return voidptr(1)
	}
}

fn release_embedded_bridge_test_view(view voidptr) {
	$if macos {
		macos.release_offscreen_terminal_view(view)
	}
}

struct EmbeddedBridgeCapture {
mut:
	actions      []apprt.ActionKey
	reload_soft  []bool
	secure_input []apprt.SecureInput
	closed       bool
	confirm      bool
}

fn embedded_bridge_action(app &apprt.App, target apprt.Target, action apprt.RuntimeAction) bool {
	_ = target
	mut capture := unsafe { &EmbeddedBridgeCapture(app.opts.userdata) }
	capture.actions << action.action
	if action.action == .reload_config {
		capture.reload_soft << action.data.reload_config_.soft
	}
	if action.action == .secure_input {
		capture.secure_input << action.data.secure_input_
	}
	return true
}

fn embedded_bridge_close(userdata voidptr, confirm bool) {
	mut capture := unsafe { &EmbeddedBridgeCapture(userdata) }
	capture.closed = true
	capture.confirm = confirm
}

fn test_embedded_bridge_uses_canonical_core_surface() {
	install_embedded_bridge()
	mut capture := EmbeddedBridgeCapture{}
	mut config := configpkg.Config.default_config()
	config.title = 'Embedded bridge title'
	mut app := apprt.ghostty_app_new(&apprt.AppOptions{
		userdata: voidptr(&capture)
		action_cb: embedded_bridge_action
		close_surface_cb: embedded_bridge_close
	}, &config) or { panic('embedded app initialization failed') }
	view := embedded_bridge_test_view()
	mut surface := apprt.ghostty_surface_new(mut app, &apprt.SurfaceOptions{
		platform_tag: int(apprt.PlatformTag.macos)
		platform: apprt.PlatformC{ nsview: view }
		userdata: voidptr(&capture)
		scale_factor: 1
	}) or { panic('embedded surface initialization failed') }
	defer {
		apprt.ghostty_surface_free(mut surface)
		apprt.ghostty_app_free(mut app)
		release_embedded_bridge_test_view(view)
	}

	assert !isnil(surface.core_surface.backend)
	size := apprt.ghostty_surface_size(surface)
	assert size.width_px == 800
	assert size.height_px == 600
	assert size.columns > 0
	assert size.rows > 0
	assert size.cell_width_px > 0
	assert size.cell_height_px > 0
	assert apprt.ActionKey.quit_timer in capture.actions
	assert apprt.ActionKey.cell_size in capture.actions
	assert apprt.ActionKey.size_limit in capture.actions
	assert apprt.ActionKey.set_title in capture.actions
	assert surface.title? == 'Embedded bridge title'

	apprt.ghostty_surface_set_size(mut surface, 1000, 700)
	resized := apprt.ghostty_surface_size(surface)
	assert resized.width_px == 1000
	assert resized.height_px == 700

	// Feed the canonical terminal emulator and read it back exclusively through
	// the public embedded selection/text API.
	mut backend := unsafe { &EmbeddedSurfaceCore(surface.core_surface.backend) }
	backend.surface.color_scheme_callback(.dark)!
	assert capture.reload_soft.len == 1
	assert capture.reload_soft[0]
	assert backend.surface.perform_binding_action(input.Action.new(.toggle_secure_input))!
	assert capture.secure_input.last() == .toggle
	mut stream := backend.surface.renderer_state.terminal_.vt_stream()
	stream.next_slice('hello')!
	apprt.ghostty_surface_mouse_pos(mut surface, 1, 1, 0)
	mut word := apprt.CAPIText{}
	assert apprt.ghostty_surface_quicklook_word(mut surface, mut word)
	assert word.text? == 'hello'
	assert !apprt.ghostty_surface_has_selection(surface)
	apprt.ghostty_surface_free_text(mut word)

	apprt.ghostty_surface_set_display_id(mut surface, 42)
	$if macos {
		quicklook_font := apprt.ghostty_surface_quicklook_font(surface)
		assert !isnil(quicklook_font)
		font.release_coretext_font(quicklook_font)
	}

	mut text := apprt.CAPIText{}
	assert apprt.ghostty_surface_read_text(mut surface, apprt.CAPISelection{
		tl: apprt.CAPIPoint{
			tag: .active
			coord_tag: .exact
			x: 0
			y: 0
		}
		br: apprt.CAPIPoint{
			tag: .active
			coord_tag: .exact
			x: 4
			y: 0
		}
	}, mut text)
	assert (text.text or { '' }) == 'hello'
	assert text.offset_len == 4

	assert apprt.ghostty_surface_binding_action(mut surface, 'select_all')
	assert apprt.ghostty_surface_has_selection(surface)
	apprt.ghostty_surface_request_close(mut surface)
	assert capture.closed
	assert capture.confirm == apprt.ghostty_surface_needs_confirm_quit(surface)
}

fn test_embedded_bridge_inherits_focused_surface_working_directory() {
	install_embedded_bridge()
	mut config := configpkg.Config.default_config()
	config.tab_inherit_working_directory = true
	mut app := apprt.ghostty_app_new(&apprt.AppOptions{}, &config) or {
		panic('embedded app initialization failed')
	}
	view := embedded_bridge_test_view()
	mut surface := apprt.ghostty_surface_new(mut app, &apprt.SurfaceOptions{
		platform_tag: int(apprt.PlatformTag.macos)
		platform: apprt.PlatformC{ nsview: view }
		scale_factor: 1
	}) or { panic('embedded surface initialization failed') }
	defer {
		apprt.ghostty_surface_free(mut surface)
		apprt.ghostty_app_free(mut app)
		release_embedded_bridge_test_view(view)
	}

	mut backend := unsafe { &EmbeddedSurfaceCore(surface.core_surface.backend) }
	backend.surface.renderer_state.terminal_.set_pwd('/focused/project')!
	// Surfaces begin focused, so exercise the same loss/gain transition that
	// makes this surface the app's last focused surface in Ghostty.
	apprt.ghostty_surface_set_focus(mut surface, false)
	apprt.ghostty_surface_set_focus(mut surface, true)

	inherited := apprt.new_config(app.core_app, &app.config, .tab)
	assert inherited.working_directory? == '/focused/project'

	mut disabled := app.config.clone()
	disabled.tab_inherit_working_directory = false
	not_inherited := apprt.new_config(app.core_app, &disabled, .tab)
	assert not_inherited.working_directory == none
}

fn test_embedded_bridge_app_destroy_deinitializes_live_surfaces() {
	install_embedded_bridge()
	mut config := configpkg.Config.default_config()
	mut app := apprt.ghostty_app_new(&apprt.AppOptions{}, &config) or {
		panic('embedded app initialization failed')
	}
	view := embedded_bridge_test_view()
	mut surface := apprt.ghostty_surface_new(mut app, &apprt.SurfaceOptions{
		platform_tag: int(apprt.PlatformTag.macos)
		platform: apprt.PlatformC{ nsview: view }
	}) or { panic('embedded surface initialization failed') }
	backend := unsafe { &EmbeddedSurfaceCore(surface.core_surface.backend) }
	assert backend.surface.initialized

	apprt.ghostty_app_free(mut app)
	assert isnil(surface.core_surface.backend)
	assert !backend.surface.initialized
	release_embedded_bridge_test_view(view)
}
