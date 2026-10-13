module main

import zigimg as p

pub struct Encoded {
pub mut:
	bits u32
}

pub fn Encoded.from_color(value p.Colorf32) Encoded {
	return Encoded{
		bits: u32(value.r == 1) | u32(value.g == 1) << 1 | u32(value.b == 1) << 2 | u32(value.a == 1) << 3 | 0x12340000
	}
}

pub struct Swizzled {
pub mut:
	r u16
	g u16
	b u16
	a u16
}

pub fn Swizzled.from_color(value p.Colorf32) Swizzled {
	return Swizzled{
		r: u16(value.g * 65535)
		g: u16(value.b * 65535)
		b: u16(value.r * 65535)
		a: 17
	}
}

pub struct Snapshot {
pub mut:
	channel_bits [4]u32
}

pub fn Snapshot.from_color(value p.Colorf32) Snapshot {
	return Snapshot{
		channel_bits: [raw(value.r), raw(value.g), raw(value.b),
			raw(value.a)]!
	}
}

pub struct Marked {
pub mut:
	tag       int
	is_opaque bool
	sentinel  f32
}

pub fn Marked.from_color(value p.Colorf32) Marked {
	bits := if value.r == 1 { u32(0x7fc01234) } else { u32(0x80000000) }
	return Marked{
		tag:       int(value.r * 2 + value.g * 3 + value.b * 5) - 15
		is_opaque: value.a == 1
		sentinel:  unsafe { *(&f32(&bits)) }
	}
}

fn raw(value f32) u32 {
	return unsafe { *(&u32(&value)) }
}

type RgbAlias = p.Rgb24
type FloatAlias = p.Colorf32
