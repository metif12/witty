module main

import apprt

fn test_reload_ignores_an_unresolved_surface_without_touching_app_config() {
	// The app is deliberately absent: an unresolved surface target must return
	// before entering the app-wide update path, even for a soft reload.
	assert runtime_action(unsafe { nil }, apprt.SurfaceTarget{surface: unsafe { nil }}, apprt.RuntimeAction{action: .reload_config, data: apprt.ReloadConfig{soft: true}})
}

fn test_native_void_actions_acknowledge_missing_surfaces_without_creating_windows() {
	// These source helpers return void. App.action acknowledges their tags even
	// when the source helper's surface guard prevents any operation.
	for action in [apprt.ActionKey.new_window, .new_tab, .new_split, .close_tab, .close_window] {
		assert runtime_action(unsafe { nil }, apprt.SurfaceTarget{surface: unsafe { nil }}, apprt.RuntimeAction{action: action, data: apprt.ActionVoid{}})
	}
	for action in [apprt.ActionKey.new_tab, .new_split] {
		assert runtime_action(unsafe { nil }, apprt.AppTarget{}, apprt.RuntimeAction{action: action, data: apprt.ActionVoid{}})
	}
	assert !runtime_action(unsafe { nil }, apprt.AppTarget{}, apprt.RuntimeAction{action: .goto_split, data: apprt.GotoSplit.next})
	assert !runtime_action(unsafe { nil }, apprt.AppTarget{}, apprt.RuntimeAction{action: .size_limit, data: apprt.ActionVoid{}})
	assert !runtime_action(unsafe { nil }, apprt.SurfaceTarget{surface: unsafe { nil }}, apprt.RuntimeAction{action: .undo, data: apprt.ActionVoid{}})
	assert !runtime_action(unsafe { nil }, apprt.SurfaceTarget{surface: unsafe { nil }}, apprt.RuntimeAction{action: .redo, data: apprt.ActionVoid{}})
	assert !runtime_action(unsafe { nil }, apprt.AppTarget{}, apprt.RuntimeAction{action: .render, data: apprt.ActionVoid{}})
}
