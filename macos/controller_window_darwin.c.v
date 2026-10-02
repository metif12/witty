module macos

// TerminalController.UndoState and DefaultSize use native AppKit window state.
pub struct NativeWindowFrame {
pub:
	x f64
	y f64
	width f64
	height f64
}
pub fn native_window_frame(view voidptr) NativeWindowFrame {
	f := msg_rect(msg_id(view, 'window'), 'frame')
	return NativeWindowFrame{x: f.x, y: f.y, width: f.width, height: f.height}
}
pub fn apply_native_window_frame(view voidptr, frame NativeWindowFrame) { C.witty_macos_msg_void_rect_bool(msg_id(view, 'window'), sel('setFrame:display:'), objc_rect(frame.x, frame.y, frame.width, frame.height), true) }
pub fn native_tab_windows(view voidptr) []voidptr {
	window := msg_id(view, 'window')
	tabs := msg_id(msg_id(window, 'tabGroup'), 'windows')
	mut result := []voidptr{}
	for i in 0 .. int(msg_u64(tabs, 'count')) { result << msg_id_u64(tabs, 'objectAtIndex:', u64(i)) }
	if result.len == 0 && !is_nil(window) { result << window }
	return result
}
pub fn native_window_is_key(window voidptr) bool { return msg_bool(window, 'isKeyWindow') }
pub fn native_window_is_closed(window voidptr) bool { return !msg_bool(window, 'isVisible') && is_nil(msg_id(window, 'tabGroup')) }
pub fn native_tab_group(view voidptr) voidptr { return msg_id(msg_id(view, 'window'), 'tabGroup') }
pub fn restore_native_tab(view voidptr, group voidptr, index int) {
	if is_nil(group) || index < 0 { return }
	tabs := msg_id(group, 'windows')
	count := int(msg_u64(tabs, 'count'))
	if count == 0 { return }
	anchor := msg_id_u64(tabs, 'objectAtIndex:', u64(if index < count { index } else { count-1 }))
	msg_void2(anchor, 'addTabbedWindow:ordered:', msg_id(view, 'window'), ObjId(if index < count { -1 } else { 1 }))
}
pub fn add_native_tab(parent voidptr, child voidptr) { msg_void2(msg_id(parent, 'window'), 'addTabbedWindow:ordered:', msg_id(child, 'window'), ObjId(1)) }
pub fn close_native_window(window voidptr) { msg_void(window, 'close'); if g_window == window { g_window = nil_obj() } }
pub fn focus_native_window(window voidptr) { msg_void1(window, 'makeKeyAndOrderFront:', nil_obj()) }
pub fn invalidate_native_restorable_state(view voidptr) { msg_void(msg_id(view, 'window'), 'invalidateRestorableState') }
pub fn reset_native_window_size(view voidptr, maximize bool, initial NativeWindowFrame, width f64, height f64) {
	window := msg_id(view, 'window')
	if maximize {
		mut screen := msg_id(window, 'screen'); if is_nil(screen) { screen = msg_id(get_class('NSScreen'), 'mainScreen') }
		if !is_nil(screen) { C.witty_macos_msg_void_rect_bool(window, sel('setFrame:display:'), msg_rect(screen, 'visibleFrame'), true) }
	} else if width > 0 && height > 0 {
		msg_void_size(window, 'setContentSize:', objc_size(width,height))
		mut screen := msg_id(window, 'screen'); if is_nil(screen) { screen = msg_id(get_class('NSScreen'), 'mainScreen') }
		if !is_nil(screen) {
			mut frame := msg_rect(window, 'frame'); visible := msg_rect(screen,'visibleFrame')
			// NSWindow.constrainToScreen from the source extension.
			frame.width = if frame.width > visible.width { visible.width } else { frame.width }
			frame.height = if frame.height > visible.height { visible.height } else { frame.height }
			frame.x = if frame.x < visible.x { visible.x } else if frame.x+frame.width > visible.x+visible.width { visible.x+visible.width-frame.width } else { frame.x }
			frame.y = if frame.y < visible.y { visible.y } else if frame.y+frame.height > visible.y+visible.height { visible.y+visible.height-frame.height } else { frame.y }
			C.witty_macos_msg_void_rect_bool(window,sel('setFrame:display:'),frame,true)
		}
	} else { apply_native_window_frame(view, initial) }
}
