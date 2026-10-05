module zigimg

import math

fn science_space_close(actual f32, expected f32, tolerance f32) {
	assert math.abs(actual - expected) <= tolerance
}

fn science_rgba_close(actual Colorf32, expected Colorf32, tolerance f32) {
	science_space_close(actual.r, expected.r, tolerance)
	science_space_close(actual.g, expected.g, tolerance)
	science_space_close(actual.b, expected.b, tolerance)
	science_space_close(actual.a, expected.a, tolerance)
}

fn test_locked_hsluv_srgb_gamma_examples() {
	hsluv := HSLuvAlpha{
		h:     f32(243.0) * f32(math.pi / 180)
		s:     0.61
		l:     0.51
		alpha: 0.12345
	}
	actual := srgb.to_gamma(srgb.from_hsluv_alpha(hsluv, .none))
	science_rgba_close(actual, Colorf32{ r: 0.324444026, g: 0.490519762, b: 0.651108801, a: 0.12345 },
		0.0001)
	source := srgb.to_linear(Colorf32{ r: 0.32549, g: 0.4902, b: 0.65098, a: 0.12345 })
	reverse := srgb.to_hsluv_alpha(source)
	science_space_close(reverse.h, 4.24362755, 0.0001)
	science_space_close(reverse.s, 0.607237875, 0.0001)
	science_space_close(reverse.l, 0.509887099, 0.0001)
	assert reverse.alpha == f32(0.12345)
}

fn test_locked_srgb_oklab_examples() {
	source := Colorf32{
		r: 0.2
		g: 0.1
		b: 0.8
		a: 0.12345
	}
	actual := srgb.to_oklab_alpha(source)
	science_space_close(actual.l, 0.576150835, 0.00001)
	science_space_close(actual.a, 0.0686165094, 0.00001)
	science_space_close(actual.b, -0.193039685, 0.00001)
	assert actual.alpha == source.a
	science_rgba_close(srgb.from_oklab_alpha(actual, .none), source, 0.00001)
}

fn test_colorspace_slice_views_reuse_input_and_copy_keeps_components() {
	original := [Colorf32{ r: 1, a: 0.75 }, Colorf32{ g: 1, a: 0.5 },
		Colorf32{ b: 1, a: 0.25 }]
	mut colors := original.clone()
	copied := srgb.slice_to_oklab_alpha_copy(colors)
	assert colors == original
	assert copied.data != colors.data
	mut borrowed := srgb.slice_to_oklab_alpha_in_place(mut colors)
	assert borrowed.data == colors.data && borrowed.len == colors.len
	assert borrowed == copied
	actual := srgb.slice_from_oklab_alpha_in_place(mut borrowed, .clamp)
	assert actual.data == colors.data
	for index in 0 .. original.len {
		science_rgba_close(actual[index], original[index], 0.00001)
	}
	mut empty := []Colorf32{}
	assert srgb.slice_to_oklab_alpha_in_place(mut empty).len == 0
}

fn test_all_scientific_alpha_slice_families_copy_and_alias() {
	original := [Colorf32{ r: 0.2, g: 0.1, b: 0.8, a: 0.12345 }]
	mut colors := original.clone()
	xyz_copy := srgb.slice_to_xyz_alpha_copy(colors)
	mut xyz_view := srgb.slice_to_xyz_alpha_in_place(mut colors)
	assert xyz_view.data == colors.data && xyz_view == xyz_copy
	xyz_back := srgb.slice_from_xyz_alpha_in_place(mut xyz_view)
	assert xyz_back.data == colors.data
	science_rgba_close(xyz_back[0], original[0], 0.00001)
	colors = original.clone()
	lab_copy := srgb.slice_to_lab_alpha_copy(colors)
	mut lab_view := srgb.slice_to_lab_alpha_in_place(mut colors)
	assert lab_view.data == colors.data && lab_view == lab_copy
	lab_back := srgb.slice_from_lab_alpha_in_place(mut lab_view, .none)
	assert lab_back.data == colors.data
	science_rgba_close(lab_back[0], original[0], 0.00001)
	colors = original.clone()
	luv_copy := srgb.slice_to_luv_alpha_copy(colors)
	mut luv_view := srgb.slice_to_luv_alpha_in_place(mut colors)
	assert luv_view.data == colors.data && luv_view == luv_copy
	luv_back := srgb.slice_from_luv_alpha_in_place(mut luv_view, .none)
	assert luv_back.data == colors.data
	science_rgba_close(luv_back[0], original[0], 0.00001)
	assert srgb.slice_from_xyz_alpha_copy(xyz_copy).data != xyz_copy.data
	assert srgb.slice_from_lab_alpha_copy(lab_copy, .none).data != lab_copy.data
	assert srgb.slice_from_luv_alpha_copy(luv_copy, .none).data != luv_copy.data
}

fn color_test_double(value f32) f32 {
	return value * 2
}

fn color_test_half(value f32) f32 {
	return value / 2
}

fn test_custom_gamma_callbacks_and_alpha_behavior() {
	custom := RgbColorspace.init(RgbColorspaceInitArgs{
		red:            srgb.red
		green:          srgb.green
		blue:           srgb.blue
		white:          srgb.white
		to_gamma:       color_test_double
		to_gamma_fast:  color_test_half
		to_linear:      color_test_half
		to_linear_fast: color_test_double
	})
	value := Colorf32{
		r: 0.25
		g: 0.5
		b: 1
		a: -1
	}
	assert custom.to_gamma(value) == Colorf32{
		r: 0.5
		g: 1
		b: 2
		a: -1
	}
	assert custom.to_linear(value) == Colorf32{
		r: 0.125
		g: 0.25
		b: 0.5
		a: -1
	}
	assert custom.to_gamma_fast(value) == custom.to_linear(value)
	assert custom.to_linear_fast(value) == custom.to_gamma(value)
	assert srgb.from_oklab_alpha(OklabAlpha{ l: 0.5, alpha: -1 }, .none).a == -1
	assert srgb.from_oklab_alpha(OklabAlpha{ l: 0.5, alpha: -1 }, .clamp).a == 0
	assert srgb.from_oklab_alpha(OklabAlpha{ l: 0.5, alpha: 2 }, .clamp).a == 1
}

fn test_presets_white_points_gamma_boundaries_and_adaptation() {
	assert srgb.white == white_point_d65
	assert prophoto_rgb.white == WhitePoints{}.d50
	assert DCIP3{}.theater.white == CIExyY{
		x: 0.314
		y: 0.351
	}
	assert srgb.red == bt709.red && srgb.green == bt709.green && srgb.blue == bt709.blue
	assert rec601_transfer_functions == rec709_transfer_functions
	assert srgb_transfer_functions.to_gamma(0.0031308) == f32(0.0031308) * f32(12.92)
	assert srgb_transfer_functions.to_linear(0.04045) == f32(0.04045) / f32(12.92)
	assert apply_gamma(4, 2) == 2 && remove_gamma(2, 2) == 4
	source := Colorf32{
		r: 0.25
		g: 0.5
		b: 0.75
		a: 0.12345
	}
	expected := RgbColorspace.convert_color(srgb, prophoto_rgb, source)
	mut colors := [source, source]
	RgbColorspace.convert_colors(srgb, prophoto_rgb, mut colors)
	assert colors == [expected, expected]
	science_rgba_close(RgbColorspace.convert_color(prophoto_rgb, srgb, expected), source, 0.00001)
	assert math.is_nan(RgbColorspace.init(RgbColorspaceInitArgs{}).rgba_to_xyza.matrix[0][0])
}
