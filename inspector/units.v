module inspector

// to_kibi_bytes translates inspector/units.zig's shared display conversion.
pub fn to_kibi_bytes(bytes usize) usize {
	return bytes / 1024
}
