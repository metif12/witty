module main

import os
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
	native_config macos.NativeWindowConfig
	background_color ?u32
	actions &macos.NativeActionSurface = unsafe { nil }
	controller &TerminalController = unsafe { nil }
	surface &apprt.Surface = unsafe { nil }
	closing bool
	closed  bool
}

@[heap]
struct TerminalController {
mut:
	host &macos.NativeSplitHost = unsafe { nil }
	focused &TermState = unsafe { nil }
	force_opaque bool
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
		platform:     apprt.PlatformC{
			nsview: view
		}
		userdata:     userdata
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
		native_config: native_window_config(&runtime.app.config)
	}
	macos.view_set_userdata(view, voidptr(state))
	state.actions = macos.new_action_surface(view, voidptr(state), macos.ActionCallbacks{binding: native_binding_action})
	state.actions.bell_border = runtime.app.config.bell_features.border()
	state.actions.secure_indication = runtime.app.config.macos_secure_input_indication
	opts := surface_options(view, voidptr(state), inherited)
	mut app := runtime.app
	state.surface = apprt.ghostty_surface_new(mut app, &opts) or {
		state.closed = true
		state.actions.deinit()
		macos.view_set_userdata(view, unsafe { nil })
		macos.close_tab(view)
		return none
	}
	runtime.states << state
	if macos.view_window(view) != unsafe { nil } {
		state.controller = &TerminalController{host: macos.create_split_host(view), focused: state}
		macos.apply_native_window_config(view, state.native_config, true, state.native_config.background, state.native_config.opacity, false)
	}

	scale := macos.view_backing_scale(view)
	apprt.ghostty_surface_set_size(mut state.surface, u32(macos.view_width(view) * scale),
		u32(macos.view_height(view) * scale))
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
	if state.actions != unsafe { nil } { state.actions.deinit() }
	macos.view_set_userdata(state.view, unsafe { nil })
	if state.surface != unsafe { nil } {
		apprt.ghostty_surface_free(mut state.surface)
		state.surface = unsafe { nil }
	}
	if state.controller != unsafe { nil } && state.controller.host.tree.root.leaves().len > 1 {
		mut controller := state.controller
		old_tree := controller.host.tree
		node := old_tree.root.find(state.view) or { return }
		next := old_tree.focus_target(if old_tree.root.leaves()[0] == state.view { macos.SplitFocusDirection.next } else { macos.SplitFocusDirection.previous }, node)
		controller.host.replace_tree(old_tree.removing(node))
		if view := next { macos.focus_split_view(view) }
	} else {
		macos.close_tab(state.view)
	}
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

fn runtime_close_surface(userdata voidptr, confirm bool) {
	mut state := state_from_userdata(userdata) or { return }
	if confirm && !macos.confirm_close(state.view) {
		return
	}
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

fn on_app_focus(focused bool) {
	macos.secure_app_focus(focused)
	macos.notification_app_focus(focused)
	mut runtime := standalone_runtime()
	if runtime.app != unsafe { nil } {
		apprt.ghostty_app_set_focus(mut runtime.app, focused)
	}
}

fn on_keyboard_changed() {
	mut runtime := standalone_runtime()
	if runtime.app != unsafe { nil } {
		apprt.ghostty_app_keyboard_changed(mut runtime.app)
	}
}

fn on_should_quit_after_last_window() bool {
	runtime := standalone_runtime()
	if runtime.app == unsafe { nil } {
		return false
	}
	return runtime.app.config.quit_after_last_window_closed
}

fn on_should_terminate() bool {
	runtime := standalone_runtime()
	if runtime.app == unsafe { nil } || !macos.termination_requires_confirmation(apprt.ghostty_app_needs_confirm_quit(runtime.app)) {
		return true
	}
	return macos.confirm_quit()
}

fn on_reopen() bool {
	runtime := standalone_runtime()
	controllers := runtime.states.filter(!it.closed).len
	if !macos.should_create_reopen_window(false, controllers, macos.application_has_become_active()) {
		return true
	}
	do_new_window(none)
	return false
}

fn runtime_read_clipboard(userdata voidptr, clipboard_type int, request &apprt.ClipboardRequest) {
	mut state := state_from_userdata(userdata) or { return }
	if state.closed || state.surface == unsafe { nil } {
		return
	}
	text := macos.clipboard_get_text_for(clipboard_type) or { '' }
	apprt.ghostty_surface_complete_clipboard_request(mut state.surface, text, request, false)
}

fn runtime_confirm_read_clipboard(userdata voidptr, value string, request &apprt.ClipboardRequest, request_type apprt.ClipboardRequestType) {
	mut state := state_from_userdata(userdata) or { return }
	if state.closed || state.surface == unsafe { nil } {
		return
	}
	confirmed := macos.confirm_clipboard(value, int(request_type))
	apprt.ghostty_surface_complete_clipboard_request(mut state.surface, if confirmed {
		value
	} else {
		''
	}, request, true)
}

fn runtime_write_clipboard(userdata voidptr, clipboard_type int, contents []apprt.ClipboardContent, confirm bool) {
	state := state_from_userdata(userdata) or { return }
	if state.closed || contents.len == 0 {
		return
	}
	if confirm {
		mut text := ''
		mut found := false
		for content in contents {
			if content.mime == 'text/plain' {
				text = content.data
				found = true
				break
			}
		}
		if !found || !macos.confirm_clipboard(text, int(apprt.ClipboardRequestType.osc_52_write)) {
			return
		}
	}
	if !macos.clipboard_clear(clipboard_type) {
		return
	}
	for content in contents {
		macos.clipboard_set_value(clipboard_type, content.mime, content.data)
	}
}

fn reload_runtime_config(app &apprt.App, target ?&TermState, soft bool) bool {
	mut runtime_app := unsafe { &apprt.App(app) }
	mut config := if soft {
		runtime_app.config.clone()
	} else {
		configpkg.Config.load_args(global_state.get_state().cli_args) or {
			eprintln('error loading config: ${err}')
			return false
		}
	}
	defer {
		config.deinit()
	}
	if mut state := target {
		if state.closed || state.surface == unsafe { nil } {
			return false
		}
		apprt.ghostty_surface_update_config(mut state.surface, &config)
	} else {
		apprt.ghostty_app_update_config(mut runtime_app, &config)
		sync_config_menu(&config)
	}
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
		.new_split {
			if current := state {
				data := action.data
				if data is apprt.SplitDirection { return do_new_split(current, data) }
			}
		}
		.goto_split {
			if current := state {
				data := action.data
				if data is apprt.GotoSplit { return do_goto_split(current, data) }
			}
		}
		.resize_split {
			if current := state {
				data := action.data
				if data is apprt.ResizeSplit { return do_resize_split(current, data) }
			}
		}
		.equalize_splits {
			if current := state { if current.controller != unsafe { nil } { mut host := current.controller.host; host.replace_tree(host.tree.equalized()); return true } }
		}
		.toggle_split_zoom {
			if current := state {
				if current.controller != unsafe { nil } {
					mut host := current.controller.host
					node := host.tree.root.find(current.view) or { return false }
					host.replace_tree(macos.NativeSplitTree{root: host.tree.root, zoomed: if host.tree.zoomed == unsafe { nil } { node } else { unsafe { &macos.NativeSplitNode(nil) } }})
					return true
				}
			}
		}
		.new_tab {
			return if state != none { do_new_tab(state) } else { do_new_window(none) }
		}
		.close_tab, .close_window {
			if mut current := state {
				data := action.data
				if action.action == .close_tab && data is apprt.CloseTabMode && data != .this {
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
			if mut current := state {
				data := action.data
				if data is apprt.SetTitle {
					current.actions.title = data.title
					macos.set_view_title(current.view, data.title)
				}
				return true
			}
		}
		.initial_size {
			if current := state {
				data := action.data
				if data is apprt.InitialSize {
					macos.set_view_size(current.view, f64(data.width), f64(data.height))
				}
				return true
			}
		}
		.toggle_fullscreen {
			if current := state {
				data := action.data
				if data is apprt.Fullscreen {
					macos.toggle_fullscreen_mode(current.view, match data { .native { macos.NativeFullscreenMode.native } .macos_non_native { .non_native } .macos_non_native_visible_menu { .visible_menu } .macos_non_native_padded_notch { .padded_notch } })
				}
				return true
			}
		}
		.goto_tab {
			data := action.data
			value := if data is apprt.GotoTab { int(data) } else { 0 }
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
			data := action.data
			if data is apprt.OpenUrl {
				return macos.open_url(data.url)
			}
			return false
		}
		.reload_config {
			if target is apprt.SurfaceTarget && state == none {
				return false
			}
			data := action.data
			soft := if data is apprt.ReloadConfig { data.soft } else { false }
			return reload_runtime_config(app, state, soft)
		}
		.config_change, .cell_size, .size_limit, .quit_timer {
			return true
		}
		else {}
	}

	return runtime_native_action(app, state, action)
}

fn main() {
	mut global := global_state.get_state_mut()
	global.init() or {
		eprintln(startup_error_message(err))
		exit(1)
	}
	defer {
		global.deinit()
	}
	ghostty_cli_try_action()

	mut config := configpkg.Config.load_args(global.cli_args) or {
		eprintln('error loading config: ${err}')
		exit(1)
	}
	defer {
		config.deinit()
	}

	macos.app_init()
	macos.set_draw_callback(on_draw)
	macos.set_resize_callback(on_resize)
	macos.set_display_callback(on_display)
	macos.set_paste_callback(on_paste)
	macos.set_action_callback(on_action)
	macos.set_mouse_callback(on_mouse)
	macos.set_scroll_callback(on_scroll)
	macos.set_pressure_callback(on_pressure)
	macos.set_focus_callback(on_focus)
	macos.set_app_focus_callback(on_app_focus)
	macos.set_keyboard_changed_callback(on_keyboard_changed)
	install_native_input_callbacks()
	macos.set_should_quit_after_last_window_callback(on_should_quit_after_last_window)
	macos.set_should_terminate_callback(on_should_terminate)
	macos.set_reopen_callback(on_reopen)

	mut runtime := standalone_runtime()
	runtime.app = apprt.ghostty_app_new(&apprt.AppOptions{
		userdata:                     voidptr(runtime)
		supports_selection_clipboard: true
		wakeup_cb:                    runtime_wakeup
		action_cb:                    runtime_action
		read_clipboard_cb:            runtime_read_clipboard
		confirm_read_clipboard_cb:    runtime_confirm_read_clipboard
		write_clipboard_cb:           runtime_write_clipboard
		close_surface_cb:             runtime_close_surface
	}, &config) or {
		eprintln('application initialization failed')
		exit(1)
	}
	apprt.ghostty_app_set_focus(mut runtime.app, macos.app_is_active())
	sync_config_menu(&config)

	if config.initial_window {
		do_new_window(none)
	}
	macos.app_run()

	for mut state in runtime.states {
		state.closed = true
		if state.actions != unsafe { nil } { state.actions.deinit() }
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
	if state.actions != unsafe { nil } { state.actions.resize() }
}

fn on_display(userdata voidptr, display_id u32) {
	mut state := state_from_userdata(userdata) or { return }
	if !state.closed && state.surface != unsafe { nil } {
		apprt.ghostty_surface_set_display_id(mut state.surface, display_id)
	}
}

fn on_focus(userdata voidptr, focused bool) {
	mut state := state_from_userdata(userdata) or { return }
	if !state.closed && state.surface != unsafe { nil } {
		apprt.ghostty_surface_set_focus(mut state.surface, focused)
		if state.actions != unsafe { nil } { state.actions.focus(focused) }
		if focused && state.controller != unsafe { nil } { state.controller.focused = state; sync_native_window(state) }
	}
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

fn mouse_button_from_number(number i64) input.MouseButton {
	return match number {
		0 { .left }
		1 { .right }
		2 { .middle }
		3 { .eight }
		4 { .nine }
		5 { .six }
		6 { .seven }
		7 { .four }
		8 { .five }
		9 { .ten }
		10 { .eleven }
		else { .unknown }
	}
}

fn on_mouse(userdata voidptr, event_type int, x f64, y f64, modflags u64, button_number i64) bool {
	mut state := state_from_userdata(userdata) or { return false }
	if state.closed || state.surface == unsafe { nil } {
		return false
	}
	mods := int(macos.input_mods(modflags).int())
	apprt.ghostty_surface_mouse_pos(mut state.surface, x, y, mods)
	return match event_type {
		mouse_left_down {
			apprt.ghostty_surface_mouse_button(mut state.surface, .press, .left, mods)
		}
		mouse_left_up {
			apprt.ghostty_surface_mouse_button(mut state.surface, .release, .left, mods)
		}
		mouse_left_dragged {
			false
		}
		mouse_right_down {
			apprt.ghostty_surface_mouse_button(mut state.surface, .press, .right, mods)
		}
		mouse_right_up {
			apprt.ghostty_surface_mouse_button(mut state.surface, .release, .right, mods)
		}
		5 {
			apprt.ghostty_surface_mouse_button(mut state.surface, .press,
				mouse_button_from_number(button_number), mods)
		}
		6 {
			apprt.ghostty_surface_mouse_button(mut state.surface, .release,
				mouse_button_from_number(button_number), mods)
		}
		else {
			false
		}
	}
}

fn on_scroll(userdata voidptr, x f64, y f64, scroll_mods int) {
	mut state := state_from_userdata(userdata) or { return }
	if !state.closed && state.surface != unsafe { nil } {
		apprt.ghostty_surface_mouse_scroll(mut state.surface, x, y, scroll_mods)
	}
}

fn on_pressure(userdata voidptr, stage u32, pressure f64) {
	mut state := state_from_userdata(userdata) or { return }
	if !state.closed && state.surface != unsafe { nil } {
		apprt.ghostty_surface_mouse_pressure(mut state.surface, stage, pressure)
	}
}
