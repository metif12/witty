module zigimg

fn test_source_color_scaling_and_packed_constructor_basics() {
	assert scale_value[u16, u8](u8(1)) == 257
	assert scale_value[u8, u16](u16(0x12ff)) == 0x12
	assert scale_value[u64, u8](u8(0x12)) == 0x1212121212121212
	assert scale_value[f32, u8](u8(128)) == f32(128) / 255
	assert color_from_u32_rgba[Rgba32](0x12345678) == Rgba32{
		r: 0x12
		g: 0x34
		b: 0x56
		a: 0x78
	}
	assert color_from_u64_rgba[Rgba64](0x123456789abcdef0) == Rgba64{
		r: 0x1234
		g: 0x5678
		b: 0x9abc
		a: 0xdef0
	}
	assert color_from_color[Rgba64, Rgb24](Rgb24{ r: 1, g: 128, b: 255 }) == Rgba64{
		r: 257
		g: 32896
		b: 65535
	}
	assert color_from_grayscale[Rgba32, Grayscale2](Grayscale2{ value: 2 }) == Rgba32{
		r: 170
		g: 170
		b: 170
	}
	assert color_to_u32_rgba(Rgb332{ raw: 0xaf }) == 0xffb6aaff
	assert color_to_u64_rgba(Rgba32{ r: 0x12, g: 0x34, b: 0x56, a: 0x78 }) == 0x1212343456567878
	assert color_from_html_hex[Rgba32]('#1fA8')! == Rgba32{
		r: 0x11
		g: 0xff
		b: 0xaa
		a: 0x88
	}
	assert color_from_html_hex[Bgr24]('#AbCdEf')! == Bgr24{
		r: 0xab
		g: 0xcd
		b: 0xef
	}
}

fn test_source_color_typed_constructors_and_arrays() {
	assert Rgb332.rgb(7, 5, 2).raw == 0xaf
	assert Rgb555.rgb(31, 17, 9).raw == 0x7e29
	assert Bgr555.rgb(31, 17, 9).raw == 0x263f
	assert Rgb565.rgb(31, 35, 9).raw == 0xfc69
	assert Rgb24.rgba(1, 2, 3, NoColorAlpha{}) == Rgb24.rgb(1, 2, 3)
	assert Rgba64.rgba(1, 2, 3, 4) == Rgba64{
		r: 1
		g: 2
		b: 3
		a: 4
	}
	assert Colorf32.rgb(-1, 0.5, 2).a == 1
	arr := [u8(31), 17, 9, 4]!
	assert Rgb555.from_array(arr).to_array() == [u8(31), 17, 9, 31]!
	assert Bgr555.from_array(arr).to_array() == [u8(31), 17, 9, 31]!
	floats := [f32(-1), 0.5, 2, 0.25]!
	assert Colorf32.from_array(floats).to_array() == floats
	assert Rgb24.from_u32_rgb(0xee123456).to_u32_rgba() == 0x123456ff
	assert Rgba64.from_u64_rgb(0xffff123456789abc).a == 65535
	assert Rgba32.from_grayscale(Grayscale16Alpha{ value: 0x12ff, alpha: 0x80ff }) == Rgba32{
		r: 0x12
		g: 0x12
		b: 0x12
		a: 0x80
	}
	assert Rgba64.from_color(Rgb24{ r: 1, g: 128, b: 255 }).a == 65535
	assert Bgra32.from_color(Rgb332{ raw: 0xaf }).to_u32_rgba() == 0xffb6aaff
	assert Rgb24.rgb(1, 2, 3).to_color[Rgba64]() == Rgba64{
		r: 257
		g: 514
		b: 771
	}
}

fn test_source_color_float_rounding_and_premultiplication() {
	zero := f32(0)
	negative_zero_bits := u32(0x80000000)
	negative_zero := unsafe { *(&f32(&negative_zero_bits)) }
	value := Colorf32.rgba(negative_zero, 0.5, -1, 0.5)
	assert value.to_float4()[0] == zero
	premultiplied := value.premultiplied_alpha()
	assert unsafe { *(&u32(&premultiplied.r)) } == negative_zero_bits
	assert premultiplied.g == 0.25
	assert premultiplied.b == -0.5
	assert premultiplied.a == 0.5
	assert Rgba32.rgba(255, 128, 1, 128).premultiplied_alpha() == Rgba32{
		r: 128
		g: 64
		b: 1
		a: 128
	}
	assert Rgba64.rgba(65535, 32768, 1, 32768).premultiplied_alpha() == Rgba64{
		r: 32768
		g: 16384
		b: 1
		a: 32768
	}
	assert Rgb555{
		raw: 0x8001
	}.premultiplied_alpha().raw == 0x8001
	nan_bits := u32(0x7fc00000)
	nan := unsafe { *(&f32(&nan_bits)) }
	assert scale_value[u8, f32](nan) == 255
	assert scale_value[u8, f32](f32(-1)) == 0
	assert scale_value[u8, f32](f32(0.5)) == 128
	assert scale_value[u8, f32](f32(2)) == 255
	assert Colorf32.rgba(0, 0.5, 1, nan).to_u32_rgb() == 0x0080ff
	values := [f32(-1), 0.5, 2, nan]!
	assert Rgba32.from_float4(values) == Rgba32{
		r: 0
		g: 128
		b: 255
		a: 255
	}
}

fn test_source_color_html_validation_and_defaults() {
	assert Rgb24.from_html_hex('#aBc')! == Rgb24.rgb(0xaa, 0xbb, 0xcc)
	assert Rgba32.from_html_hex('#abcdef')!.a == 255
	assert Bgra32.from_html_hex('#aBcD')!.a == 0xdd
	assert Bgra32.from_html_hex('#12345678')! == Bgra32.rgba(0x12, 0x34, 0x56, 0x78)
	for invalid in ['', '#', 'abc', '#12', '#12345', '#1234567', '#xyz', '#12G456', '#1234567z',
		'#abcd0'] {
		if _ := Rgba32.from_html_hex(invalid) {
			assert false
		} else {
			assert err.msg() == 'InvalidHtmlHexString'
		}
	}
	for invalid in ['#1234', '#12345678'] {
		if _ := Bgr24.from_html_hex(invalid) {
			assert false
		} else {
			assert err.msg() == 'InvalidHtmlHexString'
		}
	}
}

struct ColorMethodsF64 {
mut:
	r   f64
	g   f64
	b   f64
	a   f64 = 1
	tag int
}

struct ColorMethodsMixed {
mut:
	r u16
	g f32
	b f64
	a f64 = 1
}

fn test_source_generic_float_precision_and_retained_extra_fields() {
	negative_zero_bits := u64(0x8000000000000000)
	negative_zero := unsafe { *(&f64(&negative_zero_bits)) }
	value := ColorMethodsF64{
		r:   1.0000000000000002
		g:   -1.0000000000000002
		b:   negative_zero
		a:   0.5000000000000001
		tag: 17
	}
	result := color_premultiplied_alpha(value)
	assert result.r == value.r * value.a
	assert result.g == value.g * value.a
	assert unsafe { *(&u64(&result.b)) } == negative_zero_bits
	assert result.a == value.a
	assert result.tag == value.tag
	mixed := ColorMethodsMixed{
		r: 32768
		g: 0.5
		b: 1.0000000000000002
		a: 0.5000000000000001
	}
	premultiplied := color_premultiplied_alpha(mixed)
	assert premultiplied.r == 16384
	assert premultiplied.g == f32(f64(mixed.g) * mixed.a)
	assert premultiplied.b == mixed.b * mixed.a
	assert color_from_color[ColorMethodsF64, Rgb24](Rgb24.rgb(1, 128, 255)).r == f64(1) / 255
}

struct ColorMethodsIgnoredAlpha {
	r u8
	g u16
	b f64
	a string
}

struct ColorMethodsIgnoredGrayAlpha {
	value f64
	alpha string
}

fn test_source_no_alpha_targets_ignore_optional_alpha_fields() {
	value := ColorMethodsIgnoredAlpha{
		r: 0x12
		g: 0x34ff
		b: 0.5
		a: 'unused'
	}
	assert Rgb24.from_color(value) == Rgb24.rgb(0x12, 0x34, 0x80)
	assert Rgb48.from_color(value) == Rgb48.rgb(0x1212, 0x34ff, 0x8000)
	assert Rgb332.from_color(value).raw == 0x88
	gray := ColorMethodsIgnoredGrayAlpha{
		value: 0.5
		alpha: 'unused'
	}
	assert Bgr24.from_grayscale(gray) == Bgr24.rgb(128, 128, 128)
}

type ColorMethodsWord = uint
type ColorMethodsByte = u8
type ColorMethodsFloat = f32

fn test_source_scale_numeric_aliases() {
	assert scale_value[ColorMethodsWord, ColorMethodsByte](ColorMethodsByte(1)) == ColorMethodsWord(~uint(0) / 255)
	assert scale_value[ColorMethodsFloat, ColorMethodsByte](ColorMethodsByte(128)) == ColorMethodsFloat(f32(128) / 255)
	assert scale_value[ColorMethodsByte, ColorMethodsFloat](ColorMethodsFloat(0.5)) == ColorMethodsByte(128)
}

struct ColorMethodsCustomTarget {
	value u8
}

fn ColorMethodsCustomTarget.from_color[S](_ S) ColorMethodsCustomTarget {
	return ColorMethodsCustomTarget{
		value: 17
	}
}

fn test_source_to_color_dispatches_the_targets_constructor() {
	assert Rgb24.rgb(1, 2, 3).to_color[ColorMethodsCustomTarget]().value == 17
	assert Rgb332.rgb(1, 2, 3).to_color[ColorMethodsCustomTarget]().value == 17
	assert Colorf32.rgb(0.1, 0.2, 0.3).to_color[ColorMethodsCustomTarget]().value == 17
}

type ColorMethodsPacked = Rgb555
type ColorMethodsPackedTarget = Bgr555
type ColorMethodsGray = Grayscale2

fn test_source_packed_aliases_retain_logical_channel_widths() {
	value := ColorMethodsPacked{
		raw: 0x7e29
	}
	assert Rgba32.from_color(value) == Rgba32.rgba(255, 140, 74, 255)
	assert color_from_color[ColorMethodsPackedTarget, ColorMethodsPacked](value).raw == 0x263f
	assert Rgb24.from_grayscale(ColorMethodsGray{ value: 2 }) == Rgb24.rgb(170, 170, 170)
	arr := [u8(31), 17, 9, 4]!
	assert color_from_array[ColorMethodsPackedTarget, u8](arr).raw == 0x263f
	assert color_from_u32_rgba[ColorMethodsPackedTarget](0xff8c4aff).raw == 0x263f
}
