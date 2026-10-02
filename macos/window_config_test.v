module macos

fn test_configured_window_geometry_and_fullscreen_opacity() {
	frame := SplitBounds{width: 800, height: 600}
	visible := SplitBounds{x: -1920, y: 100, width: 1920, height: 1080}
	pos := native_window_position(frame, visible, 10, 20)
	assert pos.x == -1910 && pos.y == 560
	assert restore_last_native_window_position(frame, visible, -3000, -100).x == -1920
	assert restore_last_native_window_position(frame, visible, 3000, -100).x == -800
	assert restore_last_native_window_position(frame, visible, -1000, 900).y == 900 // origin valid; source does not clamp whole rect
	assert native_window_transparent(NativeWindowConfig{opacity: 0.5}, false, false)
	assert !native_window_transparent(NativeWindowConfig{opacity: 0.5}, true, false)
	assert !native_window_transparent(NativeWindowConfig{opacity: 0.5}, false, true)
	assert native_window_transparent(NativeWindowConfig{blur: -1}, false, false)
}
