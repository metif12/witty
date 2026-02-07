module terminal

// Tests for csi.v (translated from csi.zig)

fn test_csi_erase_display_from_int() {
	assert CsiEraseDisplay.from_int(0) or { panic('expected value') } == .below
	assert CsiEraseDisplay.from_int(1) or { panic('expected value') } == .above
	assert CsiEraseDisplay.from_int(2) or { panic('expected value') } == .complete
	assert CsiEraseDisplay.from_int(3) or { panic('expected value') } == .scrollback
	assert CsiEraseDisplay.from_int(22) or { panic('expected value') } == .scroll_complete
	assert CsiEraseDisplay.from_int(99) == none
}

fn test_csi_erase_display_roundtrip() {
	d := CsiEraseDisplay.from_int(22) or { panic('expected value') }
	assert d == .scroll_complete
	assert d.int_val() == 22
}

fn test_csi_erase_line_from_int() {
	assert CsiEraseLine.from_int(0) or { panic('expected value') } == .right
	assert CsiEraseLine.from_int(1) or { panic('expected value') } == .left
	assert CsiEraseLine.from_int(2) or { panic('expected value') } == .complete
	assert CsiEraseLine.from_int(4) or { panic('expected value') } == .right_unless_pending_wrap
	assert CsiEraseLine.from_int(3) == none
	assert CsiEraseLine.from_int(5) == none
}

fn test_csi_erase_line_roundtrip() {
	l := CsiEraseLine.from_int(4) or { panic('expected value') }
	assert l == .right_unless_pending_wrap
	assert l.int_val() == 4
}

fn test_tab_clear_from_int() {
	assert TabClear.from_int(0) or { panic('expected value') } == .current
	assert TabClear.from_int(3) or { panic('expected value') } == .all
	assert TabClear.from_int(1) == none
	assert TabClear.from_int(2) == none
}

fn test_tab_clear_roundtrip() {
	t := TabClear.from_int(3) or { panic('expected value') }
	assert t == .all
	assert t.int_val() == 3
}

fn test_title_push_pop() {
	pp := TitlePushPop{
		op: .push
		index: 42
	}
	assert pp.op == .push
	assert pp.index == 42
}
