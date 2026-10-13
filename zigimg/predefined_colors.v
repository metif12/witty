module zigimg

// V carries the source Colors(T) namespace constants as a typed value. The
// built-in types use their canonical conversion; custom types supply from_color.
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
	value := Colorf32{
		r: if red { f32(1) } else { f32(0) }
		g: if green { f32(1) } else { f32(0) }
		b: if blue { f32(1) } else { f32(0) }
		a: 1
	}
	$if T.unaliased_typ is Rgb24 || T.unaliased_typ is Rgba32 || T.unaliased_typ is Bgr24
		|| T.unaliased_typ is Bgra32 || T.unaliased_typ is Rgb48 || T.unaliased_typ is Rgba64
		|| T.unaliased_typ is Colorf32 || T.unaliased_typ is Rgb332 || T.unaliased_typ is Rgb555
		|| T.unaliased_typ is Bgr555 || T.unaliased_typ is Rgb565 {
		return color_from_color[T, Colorf32](value)
	} $else {
		return T.from_color(value)
	}
}
