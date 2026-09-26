module terminal

fn test_terminal_main_type_exports() {
	assert sizeof(Cell) == sizeof(CellData)
	assert sizeof(CharsetActiveSlot) == sizeof(ActiveSlot)
	assert sizeof(CSI) == sizeof(CSIAction)
	assert sizeof(DCS) == sizeof(DCSAction)
	assert sizeof(Style) == sizeof(CellStyle)
	assert sizeof(StreamAction) == sizeof(Action)
	assert sizeof(CursorStyleReq) == sizeof(AnsiCursorStyle)
	assert sizeof(Attribute) == sizeof(SgrAttribute)
}
