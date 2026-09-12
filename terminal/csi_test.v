module terminal

// Tests for csi.v (translated from csi.zig)

fn test_csi_erase_display_values() {
	assert u8(EraseDisplay.below) == 0
	assert u8(EraseDisplay.above) == 1
	assert u8(EraseDisplay.complete) == 2
	assert u8(EraseDisplay.scrollback) == 3
	assert u8(EraseDisplay.scroll_complete) == 22
}

fn test_csi_erase_line_values() {
	assert u8(EraseLine.right) == 0
	assert u8(EraseLine.left) == 1
	assert u8(EraseLine.complete) == 2
	assert u8(EraseLine.right_unless_pending_wrap) == 4
}

fn test_tab_clear_values() {
	assert u8(TabClear.current) == 0
	assert u8(TabClear.all) == 3
}

fn test_title_push_pop() {
	assert sizeof(SizeReportStyle) == 4
	assert sizeof(TitlePushPopOp) == 1
	assert sizeof(TitlePushPop) == 4
	assert u8(TitlePushPopOp.push) == 0
	assert u8(TitlePushPopOp.pop) == 1
	pp := TitlePushPop{
		op: .push
		index: 42
	}
	assert pp.op == .push
	assert pp.index == 42
}
