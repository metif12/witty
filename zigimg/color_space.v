module zigimg

pub enum PostConversionBehavior {
	none
	clamp
}

pub struct RgbColorspaceInitArgs {
pub mut:
	red            CIExyY
	green          CIExyY
	blue           CIExyY
	white          CIExyY
	to_gamma       fn (f32) f32 = gamma_no_transfer
	to_gamma_fast  fn (f32) f32 = gamma_no_transfer
	to_linear      fn (f32) f32 = gamma_no_transfer
	to_linear_fast fn (f32) f32 = gamma_no_transfer
}

pub type RgbColorspaceConversionMatrix = Float4x4

pub struct RgbColorspace {
pub mut:
	red               CIExyY
	green             CIExyY
	blue              CIExyY
	white             CIExyY
	rgba_to_xyza      Float4x4
	xyza_to_rgba      Float4x4
	to_gamma_fn       fn (f32) f32 = gamma_no_transfer
	to_gamma_fast_fn  fn (f32) f32 = gamma_no_transfer
	to_linear_fn      fn (f32) f32 = gamma_no_transfer
	to_linear_fast_fn fn (f32) f32 = gamma_no_transfer
}

pub fn RgbColorspace.init(args RgbColorspaceInitArgs) RgbColorspace {
	space := RgbColorspace{
		red:   args.red
		green: args.green
		blue:  args.blue
		white: args.white
	}
	matrix := space.to_xyz_conversion_matrix()
	return RgbColorspace{
		red:               args.red
		green:             args.green
		blue:              args.blue
		white:             args.white
		rgba_to_xyza:      matrix
		xyza_to_rgba:      matrix.inverse()
		to_gamma_fn:       args.to_gamma
		to_gamma_fast_fn:  args.to_gamma_fast
		to_linear_fn:      args.to_linear
		to_linear_fast_fn: args.to_linear_fast
	}
}

fn science_rgba_float4(value Colorf32) Float4 {
	return Float4([value.r, value.g, value.b, value.a]!)
}

fn science_rgba_from_float4(value Float4) Colorf32 {
	return Colorf32{
		r: value[0]
		g: value[1]
		b: value[2]
		a: value[3]
	}
}

fn science_post_conversion(value Colorf32, behavior PostConversionBehavior) Colorf32 {
	if behavior == .none { return value }
	vector := science_rgba_float4(value)
	return science_rgba_from_float4(clamp4(vector, 0, 1))
}

pub fn gamma_no_transfer(value f32) f32 {
	return value
}

pub fn (space RgbColorspace) to_gamma(value Colorf32) Colorf32 {
	return Colorf32{
		r: space.to_gamma_fn(value.r)
		g: space.to_gamma_fn(value.g)
		b: space.to_gamma_fn(value.b)
		a: value.a
	}
}

pub fn (space RgbColorspace) to_gamma_fast(value Colorf32) Colorf32 {
	return Colorf32{
		r: space.to_gamma_fast_fn(value.r)
		g: space.to_gamma_fast_fn(value.g)
		b: space.to_gamma_fast_fn(value.b)
		a: value.a
	}
}

pub fn (space RgbColorspace) to_linear(value Colorf32) Colorf32 {
	return Colorf32{
		r: space.to_linear_fn(value.r)
		g: space.to_linear_fn(value.g)
		b: space.to_linear_fn(value.b)
		a: value.a
	}
}

pub fn (space RgbColorspace) to_linear_fast(value Colorf32) Colorf32 {
	return Colorf32{
		r: space.to_linear_fast_fn(value.r)
		g: space.to_linear_fast_fn(value.g)
		b: space.to_linear_fast_fn(value.b)
		a: value.a
	}
}

pub fn (space RgbColorspace) from_xyz(value CIEXYZ) Colorf32 {
	vector := Float4([value.x, value.y, value.z, f32(1)]!)
	return science_rgba_from_float4(space.xyza_to_rgba.mul_vector(vector))
}

pub fn (space RgbColorspace) to_xyz(value Colorf32) CIEXYZ {
	vector := science_rgba_float4(value)
	result := space.rgba_to_xyza.mul_vector(vector)
	return CIEXYZ{
		x: result[0]
		y: result[1]
		z: result[2]
	}
}

pub fn (space RgbColorspace) from_xyz_alpha(value CIEXYZAlpha) Colorf32 {
	vector := value.to_float4()
	return science_rgba_from_float4(space.xyza_to_rgba.mul_vector(vector))
}

pub fn (space RgbColorspace) to_xyz_alpha(value Colorf32) CIEXYZAlpha {
	vector := science_rgba_float4(value)
	return CIEXYZAlpha.from_float4(space.rgba_to_xyza.mul_vector(vector))
}

pub fn (space RgbColorspace) from_lab(value CIELab, behavior PostConversionBehavior) Colorf32 {
	return science_post_conversion(space.from_xyz(value.to_xyz(space.white)), behavior)
}

pub fn (space RgbColorspace) to_lab(value Colorf32) CIELab {
	return CIELab.from_xyz(space.to_xyz(value), space.white)
}

pub fn (space RgbColorspace) from_lab_alpha(value CIELabAlpha, behavior PostConversionBehavior) Colorf32 {
	return science_post_conversion(space.from_xyz_alpha(value.to_xyz_alpha(space.white)), behavior)
}

pub fn (space RgbColorspace) to_lab_alpha(value Colorf32) CIELabAlpha {
	return CIELabAlpha.from_xyz_alpha(space.to_xyz_alpha(value), space.white)
}

pub fn (space RgbColorspace) from_luv(value CIELuv, behavior PostConversionBehavior) Colorf32 {
	return science_post_conversion(space.from_xyz(value.to_xyz(space.white)), behavior)
}

pub fn (space RgbColorspace) to_luv(value Colorf32) CIELuv {
	return CIELuv.from_xyz(space.to_xyz(value), space.white)
}

pub fn (space RgbColorspace) from_luv_alpha(value CIELuvAlpha, behavior PostConversionBehavior) Colorf32 {
	return science_post_conversion(space.from_xyz_alpha(value.to_xyz_alpha(space.white)), behavior)
}

pub fn (space RgbColorspace) to_luv_alpha(value Colorf32) CIELuvAlpha {
	return CIELuvAlpha.from_xyz_alpha(space.to_xyz_alpha(value), space.white)
}

pub fn (space RgbColorspace) from_oklab(value Oklab, behavior PostConversionBehavior) Colorf32 {
	return science_post_conversion(space.from_xyz(value.to_xyz()), behavior)
}

pub fn (space RgbColorspace) to_oklab(value Colorf32) Oklab {
	return Oklab.from_xyz(space.to_xyz(value))
}

pub fn (space RgbColorspace) from_oklab_alpha(value OklabAlpha, behavior PostConversionBehavior) Colorf32 {
	return science_post_conversion(space.from_xyz_alpha(value.to_xyz_alpha()), behavior)
}

pub fn (space RgbColorspace) to_oklab_alpha(value Colorf32) OklabAlpha {
	return OklabAlpha.from_xyz_alpha(space.to_xyz_alpha(value))
}

pub fn (space RgbColorspace) from_lchab(value CIELCHab, behavior PostConversionBehavior) Colorf32 {
	return space.from_lab(value.to_lab(), behavior)
}

pub fn (space RgbColorspace) to_lchab(value Colorf32) CIELCHab {
	return space.to_lab(value).to_lchab()
}

pub fn (space RgbColorspace) from_lchab_alpha(value CIELCHabAlpha, behavior PostConversionBehavior) Colorf32 {
	return space.from_lab_alpha(value.to_lab_alpha(), behavior)
}

pub fn (space RgbColorspace) to_lchab_alpha(value Colorf32) CIELCHabAlpha {
	return space.to_lab_alpha(value).to_lchab_alpha()
}

pub fn (space RgbColorspace) from_lchuv(value CIELCHuv, behavior PostConversionBehavior) Colorf32 {
	return space.from_luv(value.to_luv(), behavior)
}

pub fn (space RgbColorspace) to_lchuv(value Colorf32) CIELCHuv {
	return space.to_luv(value).to_lchuv()
}

pub fn (space RgbColorspace) from_lchuv_alpha(value CIELCHuvAlpha, behavior PostConversionBehavior) Colorf32 {
	return space.from_luv_alpha(value.to_luv_alpha(), behavior)
}

pub fn (space RgbColorspace) to_lchuv_alpha(value Colorf32) CIELCHuvAlpha {
	return space.to_luv_alpha(value).to_lchuv_alpha()
}

pub fn (space RgbColorspace) from_ok_lch(value OkLCh, behavior PostConversionBehavior) Colorf32 {
	return space.from_oklab(value.to_oklab(), behavior)
}

pub fn (space RgbColorspace) to_ok_lch(value Colorf32) OkLCh {
	return space.to_oklab(value).to_ok_lch()
}

pub fn (space RgbColorspace) from_ok_lch_alpha(value OkLChAlpha, behavior PostConversionBehavior) Colorf32 {
	return space.from_oklab_alpha(value.to_oklab_alpha(), behavior)
}

pub fn (space RgbColorspace) to_ok_lch_alpha(value Colorf32) OkLChAlpha {
	return space.to_oklab_alpha(value).to_ok_lch_alpha()
}

pub fn (space RgbColorspace) from_hsluv(value HSLuv, behavior PostConversionBehavior) Colorf32 {
	return space.from_lchuv(value.to_cielchuv(space.xyza_to_rgba), behavior)
}

pub fn (space RgbColorspace) to_hsluv(value Colorf32) HSLuv {
	return HSLuv.from_cielchuv(space.to_lchuv(value), space.xyza_to_rgba)
}

pub fn (space RgbColorspace) from_hsluv_alpha(value HSLuvAlpha, behavior PostConversionBehavior) Colorf32 {
	return space.from_lchuv_alpha(value.to_cielchuv_alpha(space.xyza_to_rgba), behavior)
}

pub fn (space RgbColorspace) to_hsluv_alpha(value Colorf32) HSLuvAlpha {
	return HSLuvAlpha.from_cielchuv_alpha(space.to_lchuv_alpha(value), space.xyza_to_rgba)
}

// Source slice APIs reinterpret the same four-float records. The borrowed
// array header keeps the caller's allocation; the in-place functions replace
// its component bits. Copy functions allocate independent arrays through V.
fn science_borrowed_view[T, S](values []S) []T {
	assert sizeof(T) == 16 && sizeof(S) == 16
	mut result := []T{}
	unsafe {
		result.data = values.data
		result.len = values.len
		result.cap = values.len
		result.flags = .nofree
	}
	return result
}

pub fn (space RgbColorspace) slice_from_xyz_alpha_copy(values []CIEXYZAlpha) []Colorf32 {
	mut output := []Colorf32{len: values.len}
	for index in 0 .. values.len {
		value := values[index]
		output[index] = science_post_conversion(space.from_xyz_alpha(value),
			PostConversionBehavior.none)
	}
	return output
}

pub fn (space RgbColorspace) slice_to_xyz_alpha_copy(values []Colorf32) []CIEXYZAlpha {
	mut output := []CIEXYZAlpha{len: values.len}
	for index in 0 .. values.len {
		value := values[index]
		output[index] = space.to_xyz_alpha(value)
	}
	return output
}

pub fn (space RgbColorspace) slice_from_xyz_alpha_in_place(mut values []CIEXYZAlpha) []Colorf32 {
	mut output := science_borrowed_view[Colorf32, CIEXYZAlpha](values)
	for index in 0 .. values.len {
		value := values[index]
		output[index] = science_post_conversion(space.from_xyz_alpha(value),
			PostConversionBehavior.none)
	}
	return output
}

pub fn (space RgbColorspace) slice_to_xyz_alpha_in_place(mut values []Colorf32) []CIEXYZAlpha {
	mut output := science_borrowed_view[CIEXYZAlpha, Colorf32](values)
	for index in 0 .. values.len {
		value := values[index]
		output[index] = space.to_xyz_alpha(value)
	}
	return output
}

pub fn (space RgbColorspace) slice_from_lab_alpha_copy(values []CIELabAlpha, behavior PostConversionBehavior) []Colorf32 {
	mut output := []Colorf32{len: values.len}
	white_xyz := space.white.to_xyz(1)
	for index in 0 .. values.len {
		value := values[index]
		output[index] = science_post_conversion(space.from_xyz_alpha(value.to_xyz_alpha_precomputed_white_point(white_xyz)),
			behavior)
	}
	return output
}

pub fn (space RgbColorspace) slice_to_lab_alpha_copy(values []Colorf32) []CIELabAlpha {
	mut output := []CIELabAlpha{len: values.len}
	white_xyz := space.white.to_xyz(1)
	for index in 0 .. values.len {
		value := values[index]
		output[index] = CIELabAlpha.from_xyz_alpha_precomputed_white_point(space.to_xyz_alpha(value),
			white_xyz)
	}
	return output
}

pub fn (space RgbColorspace) slice_from_lab_alpha_in_place(mut values []CIELabAlpha, behavior PostConversionBehavior) []Colorf32 {
	mut output := science_borrowed_view[Colorf32, CIELabAlpha](values)
	white_xyz := space.white.to_xyz(1)
	for index in 0 .. values.len {
		value := values[index]
		output[index] = science_post_conversion(space.from_xyz_alpha(value.to_xyz_alpha_precomputed_white_point(white_xyz)),
			behavior)
	}
	return output
}

pub fn (space RgbColorspace) slice_to_lab_alpha_in_place(mut values []Colorf32) []CIELabAlpha {
	mut output := science_borrowed_view[CIELabAlpha, Colorf32](values)
	white_xyz := space.white.to_xyz(1)
	for index in 0 .. values.len {
		value := values[index]
		output[index] = CIELabAlpha.from_xyz_alpha_precomputed_white_point(space.to_xyz_alpha(value),
			white_xyz)
	}
	return output
}

pub fn (space RgbColorspace) slice_from_luv_alpha_copy(values []CIELuvAlpha, behavior PostConversionBehavior) []Colorf32 {
	mut output := []Colorf32{len: values.len}
	white_xyz := space.white.to_xyz(1)
	for index in 0 .. values.len {
		value := values[index]
		output[index] = science_post_conversion(space.from_xyz_alpha(value.to_xyz_alpha_precomputed_white_point(white_xyz)),
			behavior)
	}
	return output
}

pub fn (space RgbColorspace) slice_to_luv_alpha_copy(values []Colorf32) []CIELuvAlpha {
	mut output := []CIELuvAlpha{len: values.len}
	white_xyz := space.white.to_xyz(1)
	for index in 0 .. values.len {
		value := values[index]
		output[index] = CIELuvAlpha.from_xyz_alpha_precomputed_white_point(space.to_xyz_alpha(value),
			white_xyz)
	}
	return output
}

pub fn (space RgbColorspace) slice_from_luv_alpha_in_place(mut values []CIELuvAlpha, behavior PostConversionBehavior) []Colorf32 {
	mut output := science_borrowed_view[Colorf32, CIELuvAlpha](values)
	white_xyz := space.white.to_xyz(1)
	for index in 0 .. values.len {
		value := values[index]
		output[index] = science_post_conversion(space.from_xyz_alpha(value.to_xyz_alpha_precomputed_white_point(white_xyz)),
			behavior)
	}
	return output
}

pub fn (space RgbColorspace) slice_to_luv_alpha_in_place(mut values []Colorf32) []CIELuvAlpha {
	mut output := science_borrowed_view[CIELuvAlpha, Colorf32](values)
	white_xyz := space.white.to_xyz(1)
	for index in 0 .. values.len {
		value := values[index]
		output[index] = CIELuvAlpha.from_xyz_alpha_precomputed_white_point(space.to_xyz_alpha(value),
			white_xyz)
	}
	return output
}

pub fn (space RgbColorspace) slice_from_oklab_alpha_copy(values []OklabAlpha, behavior PostConversionBehavior) []Colorf32 {
	mut output := []Colorf32{len: values.len}
	for index in 0 .. values.len {
		value := values[index]
		output[index] = science_post_conversion(space.from_xyz_alpha(value.to_xyz_alpha()),
			behavior)
	}
	return output
}

pub fn (space RgbColorspace) slice_to_oklab_alpha_copy(values []Colorf32) []OklabAlpha {
	mut output := []OklabAlpha{len: values.len}
	for index in 0 .. values.len {
		value := values[index]
		output[index] = OklabAlpha.from_xyz_alpha(space.to_xyz_alpha(value))
	}
	return output
}

pub fn (space RgbColorspace) slice_from_oklab_alpha_in_place(mut values []OklabAlpha, behavior PostConversionBehavior) []Colorf32 {
	mut output := science_borrowed_view[Colorf32, OklabAlpha](values)
	for index in 0 .. values.len {
		value := values[index]
		output[index] = science_post_conversion(space.from_xyz_alpha(value.to_xyz_alpha()),
			behavior)
	}
	return output
}

pub fn (space RgbColorspace) slice_to_oklab_alpha_in_place(mut values []Colorf32) []OklabAlpha {
	mut output := science_borrowed_view[OklabAlpha, Colorf32](values)
	for index in 0 .. values.len {
		value := values[index]
		output[index] = OklabAlpha.from_xyz_alpha(space.to_xyz_alpha(value))
	}
	return output
}

pub fn RgbColorspace.convert_color(source RgbColorspace, target RgbColorspace, value Colorf32) Colorf32 {
	matrix := rgb_compute_conversion_matrix(source, target)
	vector := science_rgba_float4(value)
	return science_rgba_from_float4(matrix.mul_vector(vector))
}

pub fn RgbColorspace.convert_colors(source RgbColorspace, target RgbColorspace, mut values []Colorf32) {
	matrix := rgb_compute_conversion_matrix(source, target)
	for index in 0 .. values.len {
		vector := science_rgba_float4(values[index])
		values[index] = science_rgba_from_float4(matrix.mul_vector(vector))
	}
}

fn (space RgbColorspace) to_xyz_conversion_matrix() Float4x4 {
	d_left := (space.red.x - space.blue.x) * (space.green.y - space.blue.y)
	d_right := (space.red.y - space.blue.y) * (space.green.x - space.blue.x)
	determinant := d_left - d_right
	u_left := (space.white.x - space.blue.x) * (space.green.y - space.blue.y)
	u_right := (space.white.y - space.blue.y) * (space.green.x - space.blue.x)
	v_left := (space.red.x - space.blue.x) * (space.white.y - space.blue.y)
	v_right := (space.red.y - space.blue.y) * (space.white.x - space.blue.x)
	u := (u_left - u_right) / determinant
	v := (v_left - v_right) / determinant
	w := f32(1) - u - v
	return Float4x4.from_array([
		u * (space.red.x / space.white.y),
		v * (space.green.x / space.white.y),
		w * (space.blue.x / space.white.y),
		f32(0),
		u * (space.red.y / space.white.y),
		v * (space.green.y / space.white.y),
		w * (space.blue.y / space.white.y),
		f32(0),
		u * (space.red.z() / space.white.y),
		v * (space.green.z() / space.white.y),
		w * (space.blue.z() / space.white.y),
		f32(0),
		f32(0),
		0,
		0,
		1,
	]!)
}

fn rgb_compute_conversion_matrix(source RgbColorspace, target RgbColorspace) Float4x4 {
	if source.white.equals(target.white) { return target.xyza_to_rgba.mul(source.rgba_to_xyza) }
	bradford_mapping := Float4x4.from_array([f32(0.8951000), 0.2664000, -0.1614000, 0, -0.7502000,
		1.7135000, 0.0367000, 0, 0.0389000, -0.0685000, 1.0296000, 0, 0, 0, 0, 1]!)
	bradford_inverse := Float4x4.from_array([f32(0.9869929), -0.1470543, 0.1599627, 0, 0.4323053,
		0.5183603, 0.0492912, 0, -0.0085287, 0.0400428, 0.9684867, 0, 0, 0, 0, 1]!)
	source_xyz := source.white.to_xyz(1)
	target_xyz := target.white.to_xyz(1)
	source_vector := Float4([source_xyz.x, source_xyz.y, source_xyz.z, f32(1)]!)
	target_vector := Float4([target_xyz.x, target_xyz.y, target_xyz.z, f32(1)]!)
	source_cones := bradford_mapping.mul_vector(source_vector)
	target_cones := bradford_mapping.mul_vector(target_vector)
	scale := Float4x4.from_array([target_cones[0] / source_cones[0], f32(0), 0, 0, 0,
		target_cones[1] / source_cones[1], 0, 0, 0, 0, target_cones[2] / source_cones[2], 0, 0,
		0, 0, 1]!)
	adaptation := bradford_inverse.mul(scale).mul(bradford_mapping)
	return target.xyza_to_rgba.mul(adaptation).mul(source.rgba_to_xyza)
}
