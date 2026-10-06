module vaxis

// Keep the source renderer's checked-width arithmetic explicit in V so ordinary
// and production builds share the traps.
fn session_u16_add(lhs u16, rhs u16) u16 {
	if u32(lhs) + u32(rhs) > 0xffff { panic('integer overflow') }
	return lhs + rhs
}

fn session_u16_sub(lhs u16, rhs u16) u16 {
	if lhs < rhs { panic('integer overflow') }
	return lhs - rhs
}

fn session_u16_mul(lhs u16, rhs u16) u16 {
	if u32(lhs) * u32(rhs) > 0xffff { panic('integer overflow') }
	return lhs * rhs
}

fn session_u8_mul(lhs u8, rhs u8) u8 {
	if u16(lhs) * u16(rhs) > 0xff { panic('integer overflow') }
	return lhs * rhs
}

fn session_usize_add(lhs usize, rhs usize) usize {
	if lhs > ~usize(0) - rhs { panic('integer overflow') }
	return lhs + rhs
}

fn session_usize_mul(lhs usize, rhs usize) usize {
	if rhs > 0 && lhs > ~usize(0) / rhs { panic('integer overflow') }
	return lhs * rhs
}

fn session_mouse_shape_name(shape MouseShape) string {
	return match shape {
		.ew_resize { 'ew-resize' }
		.ns_resize { 'ns-resize' }
		else { shape.str() }
	}
}
