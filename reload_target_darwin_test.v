module main

import apprt

fn test_reload_rejects_an_unresolved_surface_without_touching_app_config() {
	// The app is deliberately absent: an unresolved surface target must return
	// before entering the app-wide update path, even for a soft reload.
	assert !runtime_action(unsafe { nil }, apprt.SurfaceTarget{surface: unsafe { nil }}, apprt.RuntimeAction{action: .reload_config, data: apprt.ReloadConfig{soft: true}})
}
