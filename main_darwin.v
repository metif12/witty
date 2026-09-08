module main

import apprt
import cli
import configpkg
import global_state
import input
import macos

// The macOS executable is a native host for Ghostty's translated embedded
// runtime. The host owns AppKit windows; terminal, renderer, input, selection,
// configuration, and subprocess behavior stay behind the embedded API.

@[heap]
struct TermState {
mut:
	view    voidptr
	surface &apprt.Surface = unsafe { nil }
	closing bool
	closed  bool
}

struct StandaloneRuntime {
mut:
	app    &apprt.App = unsafe { nil }
	states []&TermState
}

struct StandaloneRuntimeSingleton {
mut:
	runtime StandaloneRuntime
}

const standalone_runtime_instance = &StandaloneRuntimeSingleton{}

fn standalone_runtime() &StandaloneRuntime {
	return unsafe { &standalone_runtime_instance.runtime }
}

fn state_from_userdata(userdata voidptr) ?&TermState {
	if userdata == unsafe { nil } {
		return none
	}
	return unsafe { &TermState(userdata) }
}

fn state_from_target(target apprt.Target) ?&TermState {
	match target {
		apprt.AppTarget {
			return none
		}
		apprt.SurfaceTarget {
			if target.surface == unsafe { nil } {
				return none
			}
			core_surface := unsafe { &apprt.CoreSurface(target.surface) }
			if core_surface.runtime_surface == unsafe { nil } {
				return none
			}
			surface := unsafe { &apprt.Surface(core_surface.runtime_surface) }
			return state_from_userdata(surface.userdata)
		}
	}
}

fn surface_options(view voidptr, userdata voidptr, inherited apprt.SurfaceOptions) apprt.SurfaceOptions {
	return apprt.SurfaceOptions{
		...inherited
		platform_tag: int(apprt.PlatformTag.macos)
		platform: apprt.PlatformC{
			nsview: view
		}
		userdata: userdata
		scale_factor: macos.view_backing_scale(view)
	}
}

fn create_surface(view voidptr, inherited apprt.SurfaceOptions) ?&TermState {
	if view == unsafe { nil } {
		return none
	}
	mut runtime := standalone_runtime()
	if runtime.app == unsafe { nil } {
		return none
	}

	mut state := &TermState{
		view: view
	}
	opts := surface_options(view, voidptr(state), inherited)
	mut app := runtime.app
	state.surface = apprt.ghostty_surface_new(mut app, &opts) or {
		state.closed = true
		macos.close_tab(view)
		return none
	}
	macos.view_set_userdata(view, voidptr(state))
	runtime.states << state

	scale := macos.view_backing_scale(view)
	apprt.ghostty_surface_set_size(mut state.surface, u32(macos.view_width(view) * scale), u32(macos.view_height(view) * scale))
	apprt.ghostty_surface_set_focus(mut state.surface, true)
	return state
}

fn inherited_options(state ?&TermState, context apprt.NewSurfaceContext) apprt.SurfaceOptions {
	if source := state {
		if !source.closed && source.surface != unsafe { nil } {
			return apprt.ghostty_surface_inherited_config(source.surface, context)
		}
	}
	return apprt.SurfaceOptions{
		context: context
	}
}

fn do_new_window(source ?&TermState) bool {
	view := macos.create_window(800, 600, '')
	return create_surface(view, inherited_options(source, .window)) != none
}

fn do_new_tab(source ?&TermState) bool {
	view := macos.new_tab(800, 600, '')
	return create_surface(view, inherited_options(source, .tab)) != none
}

fn close_state_now(mut state TermState) {
	if state.closed {
		return
	}
	state.closing = true
	state.closed = true
	macos.view_set_userdata(state.view, unsafe { nil })
	if state.surface != unsafe { nil } {
		apprt.ghostty_surface_free(mut state.surface)
		state.surface = unsafe { nil }
	}
	macos.close_tab(state.view)
}

fn close_state_main(userdata voidptr) {
	mut state := state_from_userdata(userdata) or { return }
	close_state_now(mut state)
}

fn request_close_state(mut state TermState) {
	if state.closed || state.closing {
		return
	}
	state.closing = true
	macos.dispatch_main(close_state_main, voidptr(&state))
}

fn runtime_close_surface(userdata voidptr, _confirm bool) {
	mut state := state_from_userdata(userdata) or { return }
	request_close_state(mut state)
}

fn runtime_wakeup(userdata voidptr) {
	macos.dispatch_main(runtime_tick_main, userdata)
}

fn runtime_tick_main(userdata voidptr) {
	if userdata == unsafe { nil } {
		return
	}
	mut runtime := unsafe { &StandaloneRuntime(userdata) }
	if runtime.app != unsafe { nil } {
		apprt.ghostty_app_tick(mut runtime.app)
	}
}

fn runtime_read_clipboard(userdata voidptr, _clipboard_type int, request &apprt.ClipboardRequest) {
	mut state := state_from_userdata(userdata) or { return }
	if state.closed || state.surface == unsafe { nil } {
		return
	}
	text := macos.clipboard_get_text() or { '' }
	apprt.ghostty_surface_complete_clipboard_request(mut state.surface, text, request, false)
}

fn runtime_write_clipboard(userdata voidptr, _clipboard_type int, contents []apprt.ClipboardContent, confirm bool) {
	state := state_from_userdata(userdata) or { return }
	if state.closed || confirm {
		return
	}
	for content in contents {
		if content.mime == 'text/plain' {
			macos.clipboard_set_text(content.data)
			return
		}
	}
}

fn reload_runtime_config(app &apprt.App, soft bool) bool {
	mut runtime_app := unsafe { &apprt.App(app) }
	mut config := if soft {
		runtime_app.config.clone()
	} else {
		configpkg.Config.load_args(global_state.get_state().cli_args)
	}
	defer {
		config.deinit()
	}
	apprt.ghostty_app_update_config(mut runtime_app, &config)
	return true
}

fn runtime_action(app &apprt.App, target apprt.Target, action apprt.RuntimeAction) bool {
	state := state_from_target(target)
	match action.action {
		.quit {
			macos.app_terminate()
			return true
		}
		.new_window {
			return do_new_window(state)
		}
		.new_tab {
			return if state != none { do_new_tab(state) } else { do_new_window(none) }
		}
		.close_tab, .close_window {
			if mut current := state {
				if action.action == .close_tab && action.data.close_tab != .this {
					return false
				}
				apprt.ghostty_surface_request_close(mut current.surface)
				return true
			}
		}
		.close_all_windows {
			mut runtime := standalone_runtime()
			for mut candidate in runtime.states.clone() {
				if !candidate.closed && candidate.surface != unsafe { nil } {
					apprt.ghostty_surface_request_close(mut candidate.surface)
				}
			}
			return true
		}
		.render {
			if current := state {
				macos.request_display(current.view)
				return true
			}
		}
		.set_title {
			if current := state {
				macos.set_view_title(current.view, action.data.set_title_.title)
				return true
			}
		}
		.initial_size {
			if current := state {
				macos.set_view_size(current.view, f64(action.data.initial_size_.width), f64(action.data.initial_size_.height))
				return true
			}
		}
		.toggle_fullscreen {
			if current := state {
				macos.toggle_fullscreen(current.view)
				return true
			}
		}
		.goto_tab {
			value := int(action.data.goto_tab)
			if value == int(apprt.GotoTab.previous) {
				macos.select_tab(-1)
				return true
			}
			if value == int(apprt.GotoTab.next) {
				macos.select_tab(1)
				return true
			}
		}
		.present_terminal {
			if current := state {
				macos.present_view(current.view)
				return true
			}
		}
		.open_config {
			cli.run_edit_config([]) or { return false }
			return true
		}
		.open_url {
			return macos.open_url(action.data.open_url_.url)
		}
		.reload_config {
			return reload_runtime_config(app, action.data.reload_config_.soft)
		}
		.config_change, .cell_size, .size_limit, .quit_timer {
			return true
		}
		else {}
	}
	return false
}

fn main() {
	mut global := global_state.get_state_mut()
	global.init() or {
		eprintln('invalid CLI invocation: ${err}')
		return
	}
	defer {
		global.deinit()
	}
	ghostty_cli_try_action()

	mut config := configpkg.Config.load_args(global.cli_args)
	defer {
		config.deinit()
	}

	macos.app_init()
	macos.set_draw_callback(on_draw)
	macos.set_key_callback(on_key)
	macos.set_resize_callback(on_resize)
	macos.set_paste_callback(on_paste)
	macos.set_action_callback(on_action)
	macos.set_mouse_callback(on_mouse)

	mut runtime := standalone_runtime()
	runtime.app = apprt.ghostty_app_new(&apprt.AppOptions{
		userdata: voidptr(runtime)
		wakeup_cb: runtime_wakeup
		action_cb: runtime_action
		read_clipboard_cb: runtime_read_clipboard
		write_clipboard_cb: runtime_write_clipboard
		close_surface_cb: runtime_close_surface
	}, &config) or {
		eprintln('application initialization failed')
		return
	}

	if config.initial_window {
		do_new_window(none)
	}
	macos.app_run()

	for mut state in runtime.states {
		macos.view_set_userdata(state.view, unsafe { nil })
		state.surface = unsafe { nil }
		state.closed = true
	}
	apprt.ghostty_app_free(mut runtime.app)
	runtime.app = unsafe { nil }
	runtime.states.clear()
}

fn on_draw(userdata voidptr, _ctx voidptr, _width f64, _height f64) {
	mut state := state_from_userdata(userdata) or { return }
	if !state.closed && state.surface != unsafe { nil } {
		apprt.ghostty_surface_draw(mut state.surface)
	}
}

fn on_resize(userdata voidptr, width f64, height f64) {
	mut state := state_from_userdata(userdata) or { return }
	if state.closed || state.surface == unsafe { nil } || width <= 0 || height <= 0 {
		return
	}
	scale := macos.view_backing_scale(state.view)
	apprt.ghostty_surface_set_content_scale(mut state.surface, scale, scale)
	apprt.ghostty_surface_set_size(mut state.surface, u32(width * scale), u32(height * scale))
}

fn key_event_text(event voidptr, translated_mods int, fallback string) string {
	mut text := macos.event_characters(event, translated_mods)
	if text.len == 0 {
		text = fallback
	}
	runes := text.runes()
	if runes.len == 1 {
		codepoint := u32(runes[0])
		if codepoint < 0x20 {
			return macos.event_characters(event, translated_mods & ~2)
		}
		if codepoint >= 0xf700 && codepoint <= 0xf8ff {
			return ''
		}
	}
	return text
}

fn on_key(userdata voidptr, event voidptr, key_action macos.KeyEventAction, keycode u16, modflags u64, chars &u8, len int, _uchars &u8, _ulen int) {
	mut state := state_from_userdata(userdata) or { return }
	if state.closed || state.surface == unsafe { nil } {
		return
	}

	mods := int(macos.input_mods(modflags).int())
	translation_mods := apprt.ghostty_surface_key_translation_mods(state.surface, mods)
	fallback := if len > 0 { unsafe { tos(chars, len) } } else { '' }
	text := key_event_text(event, translation_mods, fallback)
	unshifted := macos.event_characters(event, 0).runes()
	action := match key_action {
		.press { input.KeyAction.press }
		.repeat { input.KeyAction.repeat }
		.release { input.KeyAction.release }
	}
	apprt.ghostty_surface_key(mut state.surface, apprt.CAPIKeyEvent{
		action: action
		mods: mods
		consumed_mods: translation_mods & ~(2 | 8 | 128 | 512)
		keycode: u32(keycode)
		text: if text.len > 0 { text } else { none }
		unshifted_codepoint: if unshifted.len > 0 { u32(unshifted[0]) } else { u32(0) }
		composing: false
	})
}

const vt_action_copy = 1
const vt_action_select_all = 2
const vt_action_new_tab = 3
const vt_action_close_tab = 4

fn on_paste(userdata voidptr, _text &u8, _len int) {
	mut state := state_from_userdata(userdata) or { return }
	if !state.closed && state.surface != unsafe { nil } {
		apprt.ghostty_surface_binding_action(mut state.surface, 'paste_from_clipboard')
	}
}

fn on_action(userdata voidptr, action_id int) {
	mut state := state_from_userdata(userdata) or { return }
	if state.closed || state.surface == unsafe { nil } {
		return
	}
	match action_id {
		vt_action_copy {
			apprt.ghostty_surface_binding_action(mut state.surface, 'copy_to_clipboard')
		}
		vt_action_select_all {
			apprt.ghostty_surface_binding_action(mut state.surface, 'select_all')
		}
		vt_action_new_tab {
			do_new_tab(state)
		}
		vt_action_close_tab {
			apprt.ghostty_surface_request_close(mut state.surface)
		}
		else {}
	}
}

const mouse_left_down = 0
const mouse_left_up = 1
const mouse_left_dragged = 2
const mouse_right_down = 3
const mouse_right_up = 4

fn on_mouse(userdata voidptr, event_type int, x f64, y f64, modflags u64) {
	mut state := state_from_userdata(userdata) or { return }
	if state.closed || state.surface == unsafe { nil } {
		return
	}
	mods := int(macos.input_mods(modflags).int())
	apprt.ghostty_surface_mouse_pos(mut state.surface, x, y, mods)
	match event_type {
		mouse_left_down {
			apprt.ghostty_surface_mouse_button(mut state.surface, .press, .left, mods)
		}
		mouse_left_up {
			apprt.ghostty_surface_mouse_button(mut state.surface, .release, .left, mods)
		}
		mouse_left_dragged {}
		mouse_right_down {
			apprt.ghostty_surface_mouse_button(mut state.surface, .press, .right, mods)
		}
		mouse_right_up {
			apprt.ghostty_surface_mouse_button(mut state.surface, .release, .right, mods)
		}
		else {}
	}
}
