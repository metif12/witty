module zigimg

@[packed]
pub struct Rgb24 {
pub mut:
	r u8
	g u8
	b u8
}

@[packed]
pub struct Rgba32 {
pub mut:
	r u8
	g u8
	b u8
	a u8 = 255
}

@[packed]
pub struct Bgr24 {
pub mut:
	b u8
	g u8
	r u8
}

@[packed]
pub struct Bgra32 {
pub mut:
	b u8
	g u8
	r u8
	a u8 = 255
}

@[packed]
pub struct Rgb48 {
pub mut:
	r u16
	g u16
	b u16
}

@[packed]
pub struct Rgba64 {
pub mut:
	r u16
	g u16
	b u16
	a u16 = 65535
}

@[packed]
pub struct Colorf32 {
pub mut:
	r f32
	g f32
	b f32
	a f32 = 1.0
}

pub struct Rgb332 {
pub mut:
	raw u8
}

pub struct Rgb555 {
pub mut:
	raw u16
}

pub struct Rgb565 {
pub mut:
	raw u16
}

pub struct Bgr555 {
pub mut:
	raw u16
}

pub struct Grayscale1 {
pub mut:
	value u8 @[required]
}

pub struct Grayscale2 {
pub mut:
	value u8 @[required]
}

pub struct Grayscale4 {
pub mut:
	value u8 @[required]
}

pub struct Grayscale8 {
pub mut:
	value u8 @[required]
}

pub struct Grayscale16 {
pub mut:
	value u16 @[required]
}

pub struct Grayscale8Alpha {
pub mut:
	value u8 @[required]
	alpha u8 = 255
}

pub struct Grayscale16Alpha {
pub mut:
	value u16 @[required]
	alpha u16 = 65535
}
