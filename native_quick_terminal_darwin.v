module main

import apprt
import configpkg
import macos

fn native_quick_size(size ?configpkg.QuickTerminalSizeValue) macos.NativeQuickSize {
	if value := size {
		return match value {
			configpkg.QuickTerminalSizePercentage { macos.NativeQuickSize{percentage: f64(value.value)} }
			configpkg.QuickTerminalSizePixels { macos.NativeQuickSize{pixels: value.value} }
		}
	}
	return macos.NativeQuickSize{}
}
fn native_quick_config(config &configpkg.Config) macos.NativeQuickConfig {
	return macos.NativeQuickConfig{position: unsafe { macos.NativeQuickPosition(config.quick_terminal_position) }, primary: native_quick_size(config.quick_terminal_size.primary), secondary: native_quick_size(config.quick_terminal_size.secondary), screen: int(config.quick_terminal_screen), duration: config.quick_terminal_animation_duration, autohide: config.quick_terminal_autohide, remain_on_space: config.quick_terminal_space_behavior == .remain, window: native_window_config(config)}
}
fn create_quick_surface(view voidptr) bool {
	mut state := create_surface(view, apprt.SurfaceOptions{env_vars: [apprt.EnvVar{key: 'GHOSTTY_QUICK_TERMINAL', value: '1'}]}) or { return false }
	if state.controller != unsafe { nil } { state.controller.quick = true }
	return true
}
fn quick_surface_process_exited(view voidptr) bool {
	state := state_from_userdata(macos.view_get_userdata(view)) or { return true }
	return state.surface == unsafe { nil } || apprt.ghostty_surface_process_exited(state.surface)
}
fn do_toggle_quick_terminal(app &apprt.App) bool {
	mut quick := macos.quick_terminal(native_quick_config(&app.config), create_quick_surface, quick_surface_process_exited)
	quick.toggle()
	return true
}
