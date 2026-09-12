module terminal

// Tests for ansi.v (translated from ansi.zig)

fn test_c0_values() {
	assert u8(C0.nul) == 0x00
	assert u8(C0.enq) == 0x05
	assert u8(C0.bel) == 0x07
	assert u8(C0.bs) == 0x08
	assert u8(C0.cr) == 0x0d
	assert u8(C0.si) == 0x0f
}

fn test_rendition_aspect_values() {
	assert u16(RenditionAspect.default_) == 0
	assert u16(RenditionAspect.bold) == 1
	assert u16(RenditionAspect.default_fg) == 39
	assert u16(RenditionAspect.default_bg) == 49
}

fn test_status_line_type_values() {
	assert u16(StatusLineType.none_) == 0
	assert u16(StatusLineType.indicator) == 1
	assert u16(StatusLineType.host_writable) == 2
}

fn test_ansi_enum_source_layouts() {
	// These four go through Ghostty's lib.Enum(.c, ...) in C-ABI builds.
	assert sizeof(DeviceAttributeReq) == 4
	assert sizeof(AnsiCursorStyle) == 4
	assert sizeof(StatusDisplay) == 4
	assert sizeof(ModifyKeyFormat) == 4

	// ProtectedMode is a direct inferred Zig enum even in C-ABI builds.
	assert sizeof(ProtectedMode) == 1
	assert u8(ProtectedMode.off) == 0
	assert u8(ProtectedMode.iso) == 1
	assert u8(ProtectedMode.dec) == 2
}
