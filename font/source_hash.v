module font

import hash
import math

// SourceHash mirrors the ordered scalar writes made by Zig's
// std.hash.autoHash before the bytes are finalized with Wyhash. V's hash
// module exposes Wyhash as a one-shot function, so we retain the ordered
// bytes until final(). Font configuration keys are small and are only built
// when a grid is acquired.
struct SourceHash {
mut:
	data []u8
}

fn (mut h SourceHash) put_u8(value u8) {
	h.data << value
}

fn (mut h SourceHash) put_bool(value bool) {
	h.put_u8(if value { u8(1) } else { u8(0) })
}

fn (mut h SourceHash) put_u16(value u16) {
	for shift in [u32(0), 8] {
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

fn (mut h SourceHash) put_f64(value f64) {
	h.put_u64(math.f64_bits(value))
}

fn (mut h SourceHash) put_bytes(value []u8) {
	h.data << value
}

fn (mut h SourceHash) put_optional_string(value ?string) {
	if text := value {
		h.put_u8(1)
		h.put_u64(u64(text.len))
		h.put_bytes(text.bytes())
	} else {
		h.put_u8(0)
	}
}

fn (h &SourceHash) final() u64 {
	return hash.sum64(h.data, 0)
}
