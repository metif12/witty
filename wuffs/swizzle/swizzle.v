module swizzle

import wuffs

pub fn g_to_rgba(source []u8) ![]u8 {
	return wuffs.g_to_rgba(source)
}

pub fn ga_to_rgba(source []u8) ![]u8 {
	return wuffs.ga_to_rgba(source)
}

pub fn rgb_to_rgba(source []u8) ![]u8 {
	return wuffs.rgb_to_rgba(source)
}

pub fn bgr_to_rgba(source []u8) ![]u8 {
	return wuffs.bgr_to_rgba(source)
}

pub fn bgra_to_rgba(source []u8) ![]u8 {
	return wuffs.bgra_to_rgba(source)
}
