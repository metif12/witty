module apprt

// Test that action key enum has all expected values.
fn test_action_key_values() {
	// Verify first and last values exist
	assert ActionKey.quit == .quit
	assert ActionKey.readonly == .readonly
}

// Test SplitDirection enum values.
fn test_split_direction() {
	assert SplitDirection.right == .right
	assert SplitDirection.down == .down
	assert SplitDirection.left == .left
	assert SplitDirection.up == .up
}

// Test GotoSplit enum values.
fn test_goto_split() {
	assert GotoSplit.previous == .previous
	assert GotoSplit.next == .next
	assert GotoSplit.up == .up
	assert GotoSplit.right == .right
}

// Test GotoWindow enum values.
fn test_goto_window() {
	assert GotoWindow.previous == .previous
	assert GotoWindow.next == .next
}

// Test GotoTab special values.
fn test_goto_tab() {
	assert int(GotoTab.previous) == -1
	assert int(GotoTab.next) == -2
	assert int(GotoTab.last) == -3
}

// Test Fullscreen enum values.
fn test_fullscreen() {
	assert Fullscreen.native == .native
	assert Fullscreen.macos_non_native == .macos_non_native
}

// Test FloatWindow enum values.
fn test_float_window() {
	assert FloatWindow.on == .on
	assert FloatWindow.off == .off
	assert FloatWindow.toggle == .toggle
}

// Test SecureInput enum values.
fn test_secure_input() {
	assert SecureInput.on == .on
	assert SecureInput.off == .off
	assert SecureInput.toggle == .toggle
}

// Test InspectorAction enum values.
fn test_inspector() {
	assert InspectorAction.toggle == .toggle
	assert InspectorAction.show == .show
	assert InspectorAction.hide == .hide
}

// Test QuitTimer enum values.
fn test_quit_timer() {
	assert QuitTimer.start == .start
	assert QuitTimer.stop == .stop
}

// Test MouseVisibility enum values.
fn test_mouse_visibility() {
	assert MouseVisibility.visible == .visible
	assert MouseVisibility.hidden == .hidden
}

// Test ResizeSplit struct creation.
fn test_resize_split() {
	rs := ResizeSplit{
		amount: 10
		direction: .left
	}
	assert rs.amount == 10
	assert rs.direction == .left
}

// Test MoveTab struct creation.
fn test_move_tab() {
	mt := MoveTab{ amount: -1 }
	assert mt.amount == -1

	mt2 := MoveTab{ amount: 1 }
	assert mt2.amount == 1
}

// Test SizeLimit struct creation.
fn test_size_limit() {
	sl := SizeLimit{
		min_width: 100
		min_height: 50
		max_width: 1920
		max_height: 1080
	}
	assert sl.min_width == 100
	assert sl.max_height == 1080
}

// Test InitialSize struct creation.
fn test_initial_size() {
	is_ := InitialSize{ width: 800, height: 600 }
	assert is_.width == 800
	assert is_.height == 600
}

// Test CellSize struct creation.
fn test_cell_size_action() {
	cs := CellSize{ width: 8, height: 16 }
	assert cs.width == 8
	assert cs.height == 16
}

// Test DesktopNotificationValue struct creation.
fn test_desktop_notification_value() {
	dn := DesktopNotificationValue{
		title: 'Hello'
		body: 'World'
	}
	assert dn.title == 'Hello'
	assert dn.body == 'World'
}

// Test ColorChange struct creation.
fn test_color_change() {
	cc := ColorChange{
		kind: .foreground
		r: 255
		g: 128
		b: 0
	}
	assert cc.r == 255
	assert cc.kind == .foreground
}

// Test ColorKind special values.
fn test_color_kind() {
	assert int(ColorKind.foreground) == -1
	assert int(ColorKind.background) == -2
	assert int(ColorKind.cursor) == -3
}

// Test OpenUrl struct.
fn test_open_url() {
	ou := OpenUrl{
		kind: .text
		url: 'file:///tmp/test.txt'
	}
	assert ou.kind == .text
	assert ou.url == 'file:///tmp/test.txt'
}

// Test CloseTabMode enum values.
fn test_close_tab_mode() {
	assert CloseTabMode.this == .this
	assert CloseTabMode.other == .other
	assert CloseTabMode.right == .right
}

// Test Target sumtype.
fn test_target() {
	t := Target(AppTarget{})
	match t {
		AppTarget { assert true }
		SurfaceTarget { assert false }
	}

	t2 := Target(SurfaceTarget{ surface: unsafe { nil } })
	match t2 {
		SurfaceTarget { assert true }
		AppTarget { assert false }
	}
}

// Test ReloadConfig struct.
fn test_reload_config() {
	rc := ReloadConfig{ soft: true }
	assert rc.soft == true

	rc2 := ReloadConfig{}
	assert rc2.soft == false
}
