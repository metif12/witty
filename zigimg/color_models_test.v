module zigimg

import math

fn color_model_close(actual f32, expected f32, tolerance f32) {
	assert math.abs(actual - expected) <= tolerance
}

fn color_model_rgb_close(actual Colorf32, expected Colorf32, tolerance f32) {
	color_model_close(actual.r, expected.r, tolerance)
	color_model_close(actual.g, expected.g, tolerance)
	color_model_close(actual.b, expected.b, tolerance)
	assert actual.a == 1
}

// The 19 input/expected triples in locked tests/color_test.zig:523-634.
fn test_locked_hsl_hsv_rgb_examples() {
	rgb := [
		Colorf32{
			r: 1
			g: 1
			b: 1
		},
		Colorf32{
			r: 0.5
			g: 0.5
			b: 0.5
		},
		Colorf32{},
		Colorf32{
			r: 1
		},
		Colorf32{
			r: 0.750
			g: 0.750
		},
		Colorf32{
			g: 0.500
		},
		Colorf32{
			r: 0.500
			g: 1
			b: 1
		},
		Colorf32{
			r: 0.500
			g: 0.500
			b: 1
		},
		Colorf32{
			r: 0.750
			g: 0.250
			b: 0.750
		},
		Colorf32{
			r: 0.628
			g: 0.643
			b: 0.142
		},
		Colorf32{
			r: 0.255
			g: 0.104
			b: 0.918
		},
		Colorf32{
			r: 0.116
			g: 0.675
			b: 0.255
		},
		Colorf32{
			r: 0.941
			g: 0.785
			b: 0.053
		},
		Colorf32{
			r: 0.704
			g: 0.187
			b: 0.897
		},
		Colorf32{
			r: 0.931
			g: 0.463
			b: 0.316
		},
		Colorf32{
			r: 0.998
			g: 0.974
			b: 0.532
		},
		Colorf32{
			r: 0.099
			g: 0.795
			b: 0.591
		},
		Colorf32{
			r: 0.211
			g: 0.149
			b: 0.597
		},
		Colorf32{
			r: 0.495
			g: 0.493
			b: 0.721
		},
	]
	hues := [f32(0), 0, 0, 0, 60, 120, 180, 240, 300, 61.8, 251.1, 134.9, 49.5, 283.7, 14.3, 56.9,
		162.4, 248.3, 240.5]
	hsl_saturations := [f32(0), 0, 0, 1, 1, 1, 1, 1, 0.5, 0.638, 0.832, 0.707, 0.893, 0.775, 0.817,
		0.991, 0.779, 0.601, 0.290]
	luminances := [f32(1), 0.5, 0, 0.5, 0.375, 0.25, 0.75, 0.75, 0.5, 0.393, 0.511, 0.396, 0.497,
		0.542, 0.624, 0.765, 0.447, 0.373, 0.607]
	hsv_saturations := [f32(0), 0, 0, 1, 1, 1, 0.5, 0.5, 0.667, 0.779, 0.887, 0.828, 0.944, 0.792,
		0.661, 0.467, 0.875, 0.75, 0.316]
	values := [f32(1), 0.5, 0, 1, 0.75, 0.5, 1, 1, 0.75, 0.643, 0.918, 0.675, 0.941, 0.897, 0.931,
		0.998, 0.795, 0.597, 0.721]
	for i, input in rgb {
		hsl := Hsl.from_rgb(input)
		color_model_close(hsl.hue, hues[i], 0.1)
		color_model_close(hsl.saturation, hsl_saturations[i], 0.1)
		color_model_close(hsl.luminance, luminances[i], 0.1)
		color_model_rgb_close(Hsl{
			hue:        hues[i]
			saturation: hsl_saturations[i]
			luminance:  luminances[i]
		}.to_rgb(), input, 0.1)
		hsv := Hsv.from_rgb(input)
		color_model_close(hsv.hue, hues[i], 0.1)
		color_model_close(hsv.saturation, hsv_saturations[i], 0.1)
		color_model_close(hsv.value, values[i], 0.1)
		color_model_rgb_close(Hsv{ hue: hues[i], saturation: hsv_saturations[i], value: values[i] }.to_rgb(),
			input, 0.1)
	}
}

fn test_locked_hsl_hsv_direct_conversion() {
	hsv := Hsl{
		hue:        300
		saturation: 0.53
		luminance:  0.67
	}.to_hsv()
	assert hsv.hue == 300
	color_model_close(hsv.saturation, 0.4140, 0.0001)
	color_model_close(hsv.value, 0.8449, 0.0001)
	hsl := Hsv{
		hue:        300
		saturation: 0.4140
		value:      0.8449
	}.to_hsl()
	assert hsl.hue == 300
	color_model_close(hsl.saturation, 0.53, 0.0001)
	color_model_close(hsl.luminance, 0.67, 0.0001)
	// The source's white HSV -> HSL path computes 0 / 0.
	white := Hsv{
		value: 1
	}.to_hsl()
	assert math.is_nan(white.saturation)
	assert white.luminance == 1
	assert Hsl.from_rgb(Colorf32{ r: 1, b: 0.5 }).hue == 330
	assert Hsv{
		hue:        -60
		saturation: 1
		value:      1
	}.to_rgb() == Colorf32{
		r: 1
		b: 1
	}
}

// Source CMYK examples at tests/color_test.zig:1176-1250.
fn test_locked_cmyk_examples_and_black_epsilon_boundary() {
	rgb := [Colorf32{ r: 1 }, Colorf32{ g: 1 }, Colorf32{ b: 1 },
		Colorf32{ r: 1, g: 1 }, Colorf32{ r: 1, b: 1 }, Colorf32{ g: 1, b: 1 },
		Colorf32{ r: 1, g: 1, b: 1 }, Colorf32{}, Colorf32{ r: 0.2, g: 0.1, b: 0.8 }]
	cmyk := [Cmykf32{ m: 1, y: 1 }, Cmykf32{ c: 1, y: 1 }, Cmykf32{ c: 1, m: 1 },
		Cmykf32{ y: 1 }, Cmykf32{ m: 1 }, Cmykf32{ c: 1 }, Cmykf32{},
		Cmykf32{ k: 1 }, Cmykf32{ c: 0.75, m: 0.875, k: 0.2 }]
	for i, input in rgb {
		actual := Cmykf32.from_colorf32(input)
		color_model_close(actual.c, cmyk[i].c, 0.0001)
		color_model_close(actual.m, cmyk[i].m, 0.0001)
		color_model_close(actual.y, cmyk[i].y, 0.0001)
		color_model_close(actual.k, cmyk[i].k, 0.0001)
		color_model_rgb_close(cmyk[i].to_colorf32(), input, 0.0001)
	}
	assert Cmykf32.from_colorf32(Colorf32{ r: f32(0.00000011920928955078125) }) == Cmykf32{
		k: f32(1) - f32(0.00000011920928955078125)
	}
	assert Cmykf32.from_colorf32(Colorf32{ r: 0.5, a: 0 }) == Cmykf32.from_colorf32(Colorf32{
		r: 0.5
		a: 1
	})
}

fn test_float_grayscale_preserves_channels() {
	assert Grayscalef32{
		value: -0.25
	}.to_colorf32() == Colorf32{
		r: -0.25
		g: -0.25
		b: -0.25
	}
	assert Grayscalef32Alpha{
		value: 1.5
		alpha: -2
	}.to_colorf32() == Colorf32{
		r: 1.5
		g: 1.5
		b: 1.5
		a: -2
	}
	assert Grayscalef32Alpha{
		value: 0.5
	}.to_colorf32().a == 1
}

fn test_predefined_colors_for_translated_color_types() {
	colors := predefined_colors[Colorf32]()
	assert colors.red == Colorf32{
		r: 1
	}
	assert colors.green == Colorf32{
		g: 1
	}
	assert colors.blue == Colorf32{
		b: 1
	}
	assert colors.white == Colorf32{
		r: 1
		g: 1
		b: 1
	}
	assert colors.black == Colorf32{}
	assert colors.cyan == Colorf32{
		g: 1
		b: 1
	}
	assert colors.magenta == Colorf32{
		r: 1
		b: 1
	}
	assert colors.yellow == Colorf32{
		r: 1
		g: 1
	}
	assert predefined_colors[Rgb24]().red == Rgb24{
		r: 255
	}
	assert predefined_colors[Rgba32]().green == Rgba32{
		g: 255
	}
	assert predefined_colors[Bgr24]().blue == Bgr24{
		b: 255
	}
	assert predefined_colors[Bgra32]().black == Bgra32{}
	assert predefined_colors[Rgb48]().yellow == Rgb48{
		r: 65535
		g: 65535
	}
	assert predefined_colors[Rgba64]().cyan == Rgba64{
		g: 65535
		b: 65535
	}
	assert predefined_colors[Rgb332]().white.raw == 255
	assert predefined_colors[Rgb555]().red.raw == 0x7c00
	assert predefined_colors[Bgr555]().red.raw == 31
	assert predefined_colors[Rgb565]().green.raw == 0x07e0
}
