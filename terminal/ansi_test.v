module terminal

// Tests for ansi.v (translated from ansi.zig)

fn test_c0_from_int_valid() {
	assert C0.from_int(0x00) or { panic('expected value') } == .nul
	assert C0.from_int(0x07) or { panic('expected value') } == .bel
	assert C0.from_int(0x0D) or { panic('expected value') } == .cr
	assert C0.from_int(0x0A) or { panic('expected value') } == .lf
}

fn test_c0_from_int_invalid() {
	assert C0.from_int(0x03) == none
	assert C0.from_int(0x80) == none
}

fn test_c0_roundtrip() {
	c := C0.from_int(0x08) or { panic('expected value') }
	assert c == .bs
	assert c.int_val() == 0x08
}

fn test_rendition_aspect_from_int() {
	assert RenditionAspect.from_int(0) or { panic('expected value') } == .default_
	assert RenditionAspect.from_int(1) or { panic('expected value') } == .bold
	assert RenditionAspect.from_int(39) or { panic('expected value') } == .default_fg
	assert RenditionAspect.from_int(49) or { panic('expected value') } == .default_bg
	assert RenditionAspect.from_int(999) == none
}

fn test_rendition_aspect_roundtrip() {
	r := RenditionAspect.from_int(39) or { panic('expected value') }
	assert r == .default_fg
	assert r.int_val() == 39
}

fn test_status_line_type_from_int() {
	assert StatusLineType.from_int(0) or { panic('expected value') } == .none_
	assert StatusLineType.from_int(1) or { panic('expected value') } == .indicator
	assert StatusLineType.from_int(2) or { panic('expected value') } == .host_writable
	assert StatusLineType.from_int(99) == none
}

fn test_status_line_type_roundtrip() {
	s := StatusLineType.from_int(2) or { panic('expected value') }
	assert s == .host_writable
	assert s.int_val() == 2
}
