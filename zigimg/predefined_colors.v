module zigimg

// V carries the source Colors(T) namespace constants as a typed value. The
// supported T values are the translated RGB(A) color types.
pub struct Colors[T] {
pub:
	red     T
	green   T
	blue    T
	white   T
	black   T
	cyan    T
	magenta T
	yellow  T
}

pub fn predefined_colors[T]() Colors[T] {
	return Colors[T]{
		red:     predefined_color[T](true, false, false)
		green:   predefined_color[T](false, true, false)
		blue:    predefined_color[T](false, false, true)
		white:   predefined_color[T](true, true, true)
		black:   predefined_color[T](false, false, false)
		cyan:    predefined_color[T](false, true, true)
		magenta: predefined_color[T](true, false, true)
		yellow:  predefined_color[T](true, true, false)
	}
}

fn predefined_color[T](red bool, green bool, blue bool) T {
	r := if red { u16(65535) } else { u16(0) }
	g := if green { u16(65535) } else { u16(0) }
	b := if blue { u16(65535) } else { u16(0) }
	$if T is Rgb24 {
		return Rgb24{
			r: u8(r)
			g: u8(g)
			b: u8(b)
		}
	} $else $if T is Rgba32 {
		return Rgba32{
			r: u8(r)
			g: u8(g)
			b: u8(b)
		}
	} $else $if T is Bgr24 {
		return Bgr24{
			r: u8(r)
			g: u8(g)
			b: u8(b)
		}
	} $else $if T is Bgra32 {
		return Bgra32{
			r: u8(r)
			g: u8(g)
			b: u8(b)
		}
	} $else $if T is Rgb48 {
		return Rgb48{
			r: r
			g: g
			b: b
		}
	} $else $if T is Rgba64 {
		return Rgba64{
			r: r
			g: g
			b: b
		}
	} $else $if T is Colorf32 {
		return Colorf32{
			r: f32(r) / 65535
			g: f32(g) / 65535
			b: f32(b) / 65535
		}
	} $else $if T is Rgb332 {
		return Rgb332{
			raw: u8((r & 7) | ((g & 7) << 3) | ((b & 3) << 6))
		}
	} $else $if T is Rgb555 {
		return Rgb555{
			raw: ((r & 31) << 10) | ((g & 31) << 5) | (b & 31)
		}
	} $else $if T is Bgr555 {
		return Bgr555{
			raw: ((b & 31) << 10) | ((g & 31) << 5) | (r & 31)
		}
	} $else $if T is Rgb565 {
		return Rgb565{
			raw: ((r & 31) << 11) | ((g & 63) << 5) | (b & 31)
		}
	} $else {
		$compile_error('predefined_colors requires a translated RGB(A) color type')
	}
}
