module vxfw

// Source i17 values use wider V storage; check each operation before narrowing.
fn vxfw_i17_add(first i32, second i32) i32 {
	value := i64(first) + i64(second)
	if value < -65536 || value > 65535 { panic('integer overflow') }
	return i32(value)
}

fn vxfw_i17_sub(first i32, second i32) i32 {
	value := i64(first) - i64(second)
	if value < -65536 || value > 65535 { panic('integer overflow') }
	return i32(value)
}

fn vxfw_i17_cast(value i64) i32 {
	if value < -65536 || value > 65535 { panic('integer cast truncated bits') }
	return i32(value)
}

fn vxfw_u32_add(first u32, second u32) u32 {
	if second > u32(0xffffffff) - first { panic('integer overflow') }
	return first + second
}

fn vxfw_u32_sub(first u32, second u32) u32 {
	if second > first { panic('integer overflow') }
	return first - second
}

fn vxfw_u32_cast(value u64) u32 {
	if value > 0xffffffff { panic('integer cast truncated bits') }
	return u32(value)
}

fn vxfw_u16_add(first u16, second u16) u16 {
	if second > u16(0xffff) - first { panic('integer overflow') }
	return first + second
}

fn vxfw_u16_sub(first u16, second u16) u16 {
	if second > first { panic('integer overflow') }
	return first - second
}

fn vxfw_u16_cast(value u64) u16 {
	if value > 0xffff { panic('integer cast truncated bits') }
	return u16(value)
}

fn vxfw_u8_cast(value u64) u8 {
	if value > 0xff { panic('integer cast truncated bits') }
	return u8(value)
}

fn vxfw_usize_add(first usize, second usize) usize {
	if second > ~usize(0) - first { panic('integer overflow') }
	return first + second
}

fn vxfw_usize_sub(first usize, second usize) usize {
	if second > first { panic('integer overflow') }
	return first - second
}
