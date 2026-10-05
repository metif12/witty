module zigimg

import math

fn science_close(actual f32, expected f32, tolerance f32) {
	assert math.abs(actual - expected) <= tolerance
}

fn test_locked_cielab_xyz_and_cylindrical_examples() {
	white := CIExyY{
		x: 0.31271
		y: 0.32902
	}
	lab := CIELab{
		l: 0.48485
		a: 0.47701
		b: -0.67469
	}
	xyz := lab.to_xyz(white)
	science_close(xyz.x, 0.262599, 0.0001)
	science_close(xyz.y, 0.171790, 0.0001)
	science_close(xyz.z, 0.776029, 0.0001)
	cyl := lab.to_lchab()
	science_close(cyl.l, 0.48485, 0.0001)
	science_close(cyl.c, 0.82628, 0.0001)
	science_close(cyl.h, 5.32780, 0.0001)
	actual := CIELCHab{
		l: 0.48485
		c: 0.82628
		h: 5.32780
	}.to_lab()
	science_close(actual.a, lab.a, 0.0001)
	science_close(actual.b, lab.b, 0.0001)
	alpha := CIELabAlpha{
		l:     lab.l
		a:     lab.a
		b:     lab.b
		alpha: 0.4567
	}.to_lchab_alpha()
	assert alpha.alpha == f32(0.4567)
	assert alpha.to_lab_alpha().alpha == f32(0.4567)
}

fn test_locked_oklab_xyza_examples() {
	xyz := [CIEXYZAlpha{ x: 0.950, y: 1, z: 1.089 }, CIEXYZAlpha{ x: 1 },
		CIEXYZAlpha{ y: 1 }, CIEXYZAlpha{ z: 1 }]
	expected := [OklabAlpha{ l: 1 }, OklabAlpha{ l: 0.450, a: 1.236, b: -0.019 },
		OklabAlpha{ l: 0.922, a: -0.671, b: 0.263 }, OklabAlpha{ l: 0.153, a: -1.415, b: -0.449 }]
	for i, input in xyz {
		actual := OklabAlpha.from_xyz_alpha(input)
		science_close(actual.l, expected[i].l, 0.001)
		science_close(actual.a, expected[i].a, 0.001)
		science_close(actual.b, expected[i].b, 0.001)
		assert actual.alpha == expected[i].alpha
	}
}

fn test_scientific_float4_views_and_hsluv_inherited_factory_type() {
	vector := Float4([f32(-1), 2, 3, 0.75]!)
	assert CIEXYZAlpha.from_float4(vector).to_float4() == vector
	assert CIELabAlpha.from_float4(vector).to_float4() == vector
	assert CIELuvAlpha.from_float4(vector).to_float4() == vector
	assert OklabAlpha.from_float4(vector).to_float4() == vector
	assert HSLuvAlpha.from_float4(vector) == CIELuvAlpha{
		l:     -1
		u:     2
		v:     3
		alpha: 0.75
	}
	assert CIELuv{
		l: 0
		u: 1
		v: 2
	}.to_xyz(CIExyY{ x: 0.31271, y: 0.32902 }) == CIEXYZ{}
}

fn test_pinned_private_f32_math_boundaries() {
	assert color_float_bits(color_cbrt_f32(f32(-0.0))) == 0x80000000
	assert color_cbrt_f32(8) == 2
	assert color_pow_f32(-2, 3) == -8
	assert math.is_nan(color_pow_f32(-2, 0.25))
	assert color_float_bits(color_pow_f32(f32(-0.0), 3)) == 0x80000000
	assert color_float_bits(color_pow_f32(f32(-0.0), -3)) == 0xff800000
	assert color_atan2_f32(0, -1) == f32(3.1415927410)
	assert color_float_bits(color_atan2_f32(f32(-0.0), 1)) == 0x80000000
}
