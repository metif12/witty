module terminal

// Tests for csi.v (translated from csi.zig)

fn test_csi_erase_display_values() {
	assert u8(CsiEraseDisplay.below) == 0
	assert u8(CsiEraseDisplay.above) == 1
	assert u8(CsiEraseDisplay.complete) == 2
	assert u8(CsiEraseDisplay.scrollback) == 3
	assert u8(CsiEraseDisplay.scroll_complete) == 22
}

fn test_csi_erase_line_values() {
	assert u8(CsiEraseLine.right) == 0
	assert u8(CsiEraseLine.left) == 1
	assert u8(CsiEraseLine.complete) == 2
	assert u8(CsiEraseLine.right_unless_pending_wrap) == 4
}

fn test_tab_clear_values() {
	assert u8(TabClear.current) == 0
	assert u8(TabClear.all) == 3
}

fn test_title_push_pop() {
	pp := TitlePushPop{
		op: .push
		index: 42
	}
	assert pp.op == .push
	assert pp.index == 42
}
