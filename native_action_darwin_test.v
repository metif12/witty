module main

import apprt
import macos

fn test_native_void_dispatch_preserves_source_missing_surface_return() {
	app := unsafe { &apprt.App(nil) }
	target := apprt.SurfaceTarget{}
	for kind in [apprt.ActionKey.reset_window_size, .float_window, .renderer_health, .mouse_shape,
		.pwd, .start_search, .close_tab, .cell_size] {
		assert runtime_native_action(app, target, none, apprt.RuntimeAction{ target: target, action: kind })
		closed := &TermState{ closed: true }
		assert runtime_native_action(app, target, closed, apprt.RuntimeAction{ target: target, action: kind })
	}
	assert runtime_native_action(app, target, none, apprt.RuntimeAction{ target: target, action: .secure_input, data: apprt.SecureInput.on })
	for kind in [apprt.ActionKey.prompt_title, .move_tab, .resize_split, .toggle_split_zoom,
		.size_limit, .quit_timer, .render] {
		assert !runtime_native_action(app, target, none, apprt.RuntimeAction{ target: target, action: kind })
	}
}

fn test_native_reset_dispatch_ignores_internal_controller_performability() {
	app := unsafe { &apprt.App(nil) }
	current := &TermState{ actions: &macos.NativeActionSurface{ closed: true } }
	assert runtime_native_action(app, apprt.SurfaceTarget{}, current, apprt.RuntimeAction{ target: apprt.SurfaceTarget{}, action: .reset_window_size })
	assert !runtime_native_action(app, apprt.SurfaceTarget{}, current, apprt.RuntimeAction{ target: apprt.SurfaceTarget{}, action: .prompt_title })
}
