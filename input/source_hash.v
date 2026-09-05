module input

import internal_hash
import math

// SourceHash accumulates the exact little-endian scalar stream emitted by
// Zig 0.15.2's std.hash.autoHash/autoHashStrat before Wyhash finalization.
struct SourceHash {
mut:
	data []u8
}

fn (mut h SourceHash) put_u8(value u8) {
	h.data << value
}

fn (mut h SourceHash) put_u16(value u16) {
	for shift in [u16(0), 8] {
		h.data << u8(value >> shift)
	}
}

fn (mut h SourceHash) put_i16(value i16) {
	h.put_u16(u16(value))
}

fn (mut h SourceHash) put_u21(value u32) {
	assert value <= 0x1fffff
	for shift in [u32(0), 8, 16] {
		h.data << u8(value >> shift)
	}
}

fn (mut h SourceHash) put_u32(value u32) {
	for shift in [u32(0), 8, 16, 24] {
		h.data << u8(value >> shift)
	}
}

fn (mut h SourceHash) put_i32(value i32) {
	h.put_u32(u32(value))
}

fn (mut h SourceHash) put_u64(value u64) {
	for shift in [u32(0), 8, 16, 24, 32, 40, 48, 56] {
		h.data << u8(value >> shift)
	}
}

fn (mut h SourceHash) put_i64(value i64) {
	h.put_u64(u64(value))
}

fn (mut h SourceHash) put_f32(value f32) {
	h.put_u32(math.f32_bits(value))
}

fn (mut h SourceHash) put_deep_string(value string) {
	h.data << value.bytes()
	// Ghostty's source target is 64-bit, so usize is eight bytes.
	h.put_u64(u64(value.len))
}

fn (h &SourceHash) final() u64 {
	return internal_hash.wyhash(h.data, 0)
}
