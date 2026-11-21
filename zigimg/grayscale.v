module zigimg

// V generic records represent the source's public type factories. The named
// built-in records retain their separate required-field enforcement.
pub struct Grayscale[T] {
pub mut:
	value T @[required]
}

pub fn Grayscale.to_colorf32[T](gray Grayscale[T]) Colorf32 {
	return grayscale_to_colorf32(gray)
}

pub struct GrayscaleAlpha[T] {
pub mut:
	value T @[required]
	alpha T @[required]
}

// The pinned V compiler cannot resolve a type-dependent field initializer.
// Use this constructor when Source would supply its default alpha.
pub fn GrayscaleAlpha.init[T](value T) GrayscaleAlpha[T] {
	return GrayscaleAlpha[T]{
		value: value
		alpha: grayscale_default_alpha(value)
	}
}

pub fn GrayscaleAlpha.to_colorf32[T](gray GrayscaleAlpha[T]) Colorf32 {
	return grayscale_to_colorf32(gray)
}

fn grayscale_to_colorf32[G](gray G) Colorf32 {
	mut value := f32(0)
	mut alpha := f32(1)
	$for field in G.fields {
		$if field.name == 'value' {
			value = color_method_cast[f32](color_method_channel(gray.$(field.name)))
		} $else $if field.name == 'alpha' {
			alpha = color_method_cast[f32](color_method_channel(gray.$(field.name)))
		}
	}
	return gray_colorf32(value, alpha)
}

fn grayscale_default_alpha[T](_ T) T {
	$if T.unaliased_typ is f32 || T.unaliased_typ is f64 {
		return T(1)
	} $else $if T.unaliased_typ is u8 || T.unaliased_typ is u16 || T.unaliased_typ is u32
		|| T.unaliased_typ is u64 || T.unaliased_typ is uint {
		return T(~u64(0) >> (64 - sizeof(T) * 8))
	} $else $if T.unaliased_typ is i8 || T.unaliased_typ is i16 || T.unaliased_typ is int
		|| T.unaliased_typ is i64 || T.unaliased_typ is int {
		return T((u64(1) << (sizeof(T) * 8 - 1)) - 1)
	} $else {
		$compile_error('GrayscaleAlpha default alpha requires an integer or floating point type')
	}
}
