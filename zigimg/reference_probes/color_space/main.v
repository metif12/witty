module main

import os
import math
import strings
import zigimg

fn float_value(bits u32) f32 {
	return unsafe { *(&f32(&bits)) }
}

fn emit(mut output strings.Builder, value f32) {
	raw := if math.is_nan(value) { u32(0x7fc00000) } else { unsafe { *(&u32(&value)) } }
	output.write_string('${raw},')
}

fn record[T](mut output strings.Builder, value T) {
	$for field in T.fields {
		emit(mut output, value.$(field.name))
	}
}

fn matrix(mut output strings.Builder, value zigimg.Float4x4) {
	for row in 0 .. 4 {
		for column in 0 .. 4 {
			emit(mut output, value.matrix[row][column])
		}
	}
}

fn main() {
	presets := [zigimg.bt601_ntsc, zigimg.bt601_pal, zigimg.bt709, zigimg.srgb, zigimg.dcip3_display,
		zigimg.dcip3_theater, zigimg.dcip3_aces, zigimg.bt2020, zigimg.adobe_rgb,
		zigimg.adobe_wide_gamut_rgb, zigimg.prophoto_rgb,
		zigimg.RgbColorspace.init(zigimg.RgbColorspaceInitArgs{})]
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		parts := line.split('|')
		space := presets[parts[0].int()]
		target := presets[parts[1].int()]
		vals := parts[2..].map(float_value(it.u32()))
		value := zigimg.Colorf32{
			r: vals[0]
			g: vals[1]
			b: vals[2]
			a: vals[3]
		}
		mut output := strings.new_builder(4096)
		matrix(mut output, space.rgba_to_xyza)
		matrix(mut output, space.xyza_to_rgba)
		record(mut output, space.to_gamma(value))
		record(mut output, space.to_gamma_fast(value))
		record(mut output, space.to_linear(value))
		record(mut output, space.to_linear_fast(value))
		record(mut output, space.to_xyz(value))
		record(mut output, space.to_xyz_alpha(value))
		record(mut output, space.from_xyz(zigimg.CIEXYZ{ x: vals[0], y: vals[1], z: vals[2] }))
		record(mut output, space.from_xyz_alpha(zigimg.CIEXYZAlpha{
			x: vals[0]
			y: vals[1]
			z: vals[2]
			a: vals[3]
		}))
		record(mut output, space.from_lab(zigimg.CIELab{ l: vals[0], a: vals[1], b: vals[2] },
			.none))
		record(mut output, space.from_lab(zigimg.CIELab{ l: vals[0], a: vals[1], b: vals[2] },
			.clamp))
		record(mut output, space.to_lab(value))
		record(mut output, space.from_lab_alpha(zigimg.CIELabAlpha{
			l:     vals[0]
			a:     vals[1]
			b:     vals[2]
			alpha: vals[3]
		}, .none))
		record(mut output, space.from_lab_alpha(zigimg.CIELabAlpha{
			l:     vals[0]
			a:     vals[1]
			b:     vals[2]
			alpha: vals[3]
		}, .clamp))
		record(mut output, space.to_lab_alpha(value))
		record(mut output, space.from_luv(zigimg.CIELuv{ l: vals[0], u: vals[1], v: vals[2] },
			.none))
		record(mut output, space.from_luv(zigimg.CIELuv{ l: vals[0], u: vals[1], v: vals[2] },
			.clamp))
		record(mut output, space.to_luv(value))
		record(mut output, space.from_luv_alpha(zigimg.CIELuvAlpha{
			l:     vals[0]
			u:     vals[1]
			v:     vals[2]
			alpha: vals[3]
		}, .none))
		record(mut output, space.from_luv_alpha(zigimg.CIELuvAlpha{
			l:     vals[0]
			u:     vals[1]
			v:     vals[2]
			alpha: vals[3]
		}, .clamp))
		record(mut output, space.to_luv_alpha(value))
		record(mut output, space.from_lchab(zigimg.CIELCHab{ l: vals[0], c: vals[1], h: vals[2] },
			.none))
		record(mut output, space.from_lchab(zigimg.CIELCHab{ l: vals[0], c: vals[1], h: vals[2] },
			.clamp))
		record(mut output, space.to_lchab(value))
		record(mut output, space.from_lchab_alpha(zigimg.CIELCHabAlpha{
			l:     vals[0]
			c:     vals[1]
			h:     vals[2]
			alpha: vals[3]
		}, .none))
		record(mut output, space.from_lchab_alpha(zigimg.CIELCHabAlpha{
			l:     vals[0]
			c:     vals[1]
			h:     vals[2]
			alpha: vals[3]
		}, .clamp))
		record(mut output, space.to_lchab_alpha(value))
		record(mut output, space.from_lchuv(zigimg.CIELCHuv{ l: vals[0], c: vals[1], h: vals[2] },
			.none))
		record(mut output, space.from_lchuv(zigimg.CIELCHuv{ l: vals[0], c: vals[1], h: vals[2] },
			.clamp))
		record(mut output, space.to_lchuv(value))
		record(mut output, space.from_lchuv_alpha(zigimg.CIELCHuvAlpha{
			l:     vals[0]
			c:     vals[1]
			h:     vals[2]
			alpha: vals[3]
		}, .none))
		record(mut output, space.from_lchuv_alpha(zigimg.CIELCHuvAlpha{
			l:     vals[0]
			c:     vals[1]
			h:     vals[2]
			alpha: vals[3]
		}, .clamp))
		record(mut output, space.to_lchuv_alpha(value))
		record(mut output, space.from_hsluv(zigimg.HSLuv{ h: vals[0], s: vals[1], l: vals[2] },
			.none))
		record(mut output, space.from_hsluv(zigimg.HSLuv{ h: vals[0], s: vals[1], l: vals[2] },
			.clamp))
		record(mut output, space.to_hsluv(value))
		record(mut output, space.from_hsluv_alpha(zigimg.HSLuvAlpha{
			h:     vals[0]
			s:     vals[1]
			l:     vals[2]
			alpha: vals[3]
		}, .none))
		record(mut output, space.from_hsluv_alpha(zigimg.HSLuvAlpha{
			h:     vals[0]
			s:     vals[1]
			l:     vals[2]
			alpha: vals[3]
		}, .clamp))
		record(mut output, space.to_hsluv_alpha(value))
		record(mut output, space.from_oklab(zigimg.Oklab{ l: vals[0], a: vals[1], b: vals[2] },
			.none))
		record(mut output, space.from_oklab(zigimg.Oklab{ l: vals[0], a: vals[1], b: vals[2] },
			.clamp))
		record(mut output, space.to_oklab(value))
		record(mut output, space.from_oklab_alpha(zigimg.OklabAlpha{
			l:     vals[0]
			a:     vals[1]
			b:     vals[2]
			alpha: vals[3]
		}, .none))
		record(mut output, space.from_oklab_alpha(zigimg.OklabAlpha{
			l:     vals[0]
			a:     vals[1]
			b:     vals[2]
			alpha: vals[3]
		}, .clamp))
		record(mut output, space.to_oklab_alpha(value))
		record(mut output, space.from_ok_lch(zigimg.OkLCh{ l: vals[0], c: vals[1], h: vals[2] },
			.none))
		record(mut output, space.from_ok_lch(zigimg.OkLCh{ l: vals[0], c: vals[1], h: vals[2] },
			.clamp))
		record(mut output, space.to_ok_lch(value))
		record(mut output, space.from_ok_lch_alpha(zigimg.OkLChAlpha{
			l:     vals[0]
			c:     vals[1]
			h:     vals[2]
			alpha: vals[3]
		}, .none))
		record(mut output, space.from_ok_lch_alpha(zigimg.OkLChAlpha{
			l:     vals[0]
			c:     vals[1]
			h:     vals[2]
			alpha: vals[3]
		}, .clamp))
		record(mut output, space.to_ok_lch_alpha(value))
		record(mut output, zigimg.RgbColorspace.convert_color(space, target, value))
		mut conversions := [value, value]
		zigimg.RgbColorspace.convert_colors(space, target, mut conversions)
		for actual in conversions {
			record(mut output, actual)
		}
		mut xyz_colors := [value, value]
		xyz_copy := space.slice_to_xyz_alpha_copy(xyz_colors)
		for actual in xyz_copy {
			record(mut output, actual)
		}
		for original in xyz_colors {
			record(mut output, original)
		}
		mut xyz_inplace := space.slice_to_xyz_alpha_in_place(mut xyz_colors)
		emit(mut output, if xyz_inplace.data == xyz_colors.data { f32(1) } else { f32(0) })
		emit(mut output, if xyz_copy.data != xyz_colors.data { f32(1) } else { f32(0) })
		for actual in xyz_inplace {
			record(mut output, actual)
		}
		xyz_back := space.slice_from_xyz_alpha_copy(xyz_copy)
		for actual in xyz_back {
			record(mut output, actual)
		}
		xyz_back_inplace := space.slice_from_xyz_alpha_in_place(mut xyz_inplace)
		emit(mut output, if xyz_back_inplace.data == xyz_colors.data { f32(1) } else { f32(0) })
		for actual in xyz_back_inplace {
			record(mut output, actual)
		}
		mut xyz_empty := []zigimg.CIEXYZAlpha{}
		emit(mut output, f32(space.slice_from_xyz_alpha_in_place(mut xyz_empty).len))
		mut lab_colors := [value, value]
		lab_copy := space.slice_to_lab_alpha_copy(lab_colors)
		for actual in lab_copy {
			record(mut output, actual)
		}
		for original in lab_colors {
			record(mut output, original)
		}
		mut lab_inplace := space.slice_to_lab_alpha_in_place(mut lab_colors)
		emit(mut output, if lab_inplace.data == lab_colors.data { f32(1) } else { f32(0) })
		emit(mut output, if lab_copy.data != lab_colors.data { f32(1) } else { f32(0) })
		for actual in lab_inplace {
			record(mut output, actual)
		}
		lab_back_none := space.slice_from_lab_alpha_copy(lab_copy, .none)
		for actual in lab_back_none {
			record(mut output, actual)
		}
		lab_back_clamp := space.slice_from_lab_alpha_copy(lab_copy, .clamp)
		for actual in lab_back_clamp {
			record(mut output, actual)
		}
		lab_back_inplace := space.slice_from_lab_alpha_in_place(mut lab_inplace, .clamp)
		emit(mut output, if lab_back_inplace.data == lab_colors.data { f32(1) } else { f32(0) })
		for actual in lab_back_inplace {
			record(mut output, actual)
		}
		mut lab_empty := []zigimg.CIELabAlpha{}
		emit(mut output, f32(space.slice_from_lab_alpha_in_place(mut lab_empty, .clamp).len))
		mut luv_colors := [value, value]
		luv_copy := space.slice_to_luv_alpha_copy(luv_colors)
		for actual in luv_copy {
			record(mut output, actual)
		}
		for original in luv_colors {
			record(mut output, original)
		}
		mut luv_inplace := space.slice_to_luv_alpha_in_place(mut luv_colors)
		emit(mut output, if luv_inplace.data == luv_colors.data { f32(1) } else { f32(0) })
		emit(mut output, if luv_copy.data != luv_colors.data { f32(1) } else { f32(0) })
		for actual in luv_inplace {
			record(mut output, actual)
		}
		luv_back_none := space.slice_from_luv_alpha_copy(luv_copy, .none)
		for actual in luv_back_none {
			record(mut output, actual)
		}
		luv_back_clamp := space.slice_from_luv_alpha_copy(luv_copy, .clamp)
		for actual in luv_back_clamp {
			record(mut output, actual)
		}
		luv_back_inplace := space.slice_from_luv_alpha_in_place(mut luv_inplace, .clamp)
		emit(mut output, if luv_back_inplace.data == luv_colors.data { f32(1) } else { f32(0) })
		for actual in luv_back_inplace {
			record(mut output, actual)
		}
		mut luv_empty := []zigimg.CIELuvAlpha{}
		emit(mut output, f32(space.slice_from_luv_alpha_in_place(mut luv_empty, .clamp).len))
		mut oklab_colors := [value, value]
		oklab_copy := space.slice_to_oklab_alpha_copy(oklab_colors)
		for actual in oklab_copy {
			record(mut output, actual)
		}
		for original in oklab_colors {
			record(mut output, original)
		}
		mut oklab_inplace := space.slice_to_oklab_alpha_in_place(mut oklab_colors)
		emit(mut output, if oklab_inplace.data == oklab_colors.data { f32(1) } else { f32(0) })
		emit(mut output, if oklab_copy.data != oklab_colors.data { f32(1) } else { f32(0) })
		for actual in oklab_inplace {
			record(mut output, actual)
		}
		oklab_back_none := space.slice_from_oklab_alpha_copy(oklab_copy, .none)
		for actual in oklab_back_none {
			record(mut output, actual)
		}
		oklab_back_clamp := space.slice_from_oklab_alpha_copy(oklab_copy, .clamp)
		for actual in oklab_back_clamp {
			record(mut output, actual)
		}
		oklab_back_inplace := space.slice_from_oklab_alpha_in_place(mut oklab_inplace, .clamp)
		emit(mut output, if oklab_back_inplace.data == oklab_colors.data { f32(1) } else { f32(0) })
		for actual in oklab_back_inplace {
			record(mut output, actual)
		}
		mut oklab_empty := []zigimg.OklabAlpha{}
		emit(mut output, f32(space.slice_from_oklab_alpha_in_place(mut oklab_empty, .clamp).len))
		for transfer in [zigimg.srgb_transfer_functions, zigimg.rec601_transfer_functions,
			zigimg.rec709_transfer_functions, zigimg.bt2020_transfer_functions,
			zigimg.prophoto_rgb_transfer_functions, zigimg.NonLinearGammaTransferFunctions{}] {
			emit(mut output, transfer.to_gamma(value.r))
			emit(mut output, transfer.to_gamma_fast(value.r))
			emit(mut output, transfer.to_linear(value.r))
			emit(mut output, transfer.to_linear_fast(value.r))
		}
		for transfer in [zigimg.dcip3_transfer_functions, zigimg.adobe_rgb_transfer_functions,
			zigimg.CurveGammaTransferFunctions{ gamma: 0 }, zigimg.CurveGammaTransferFunctions{
				gamma: -2
			}] {
			emit(mut output, transfer.to_gamma(value.r))
			emit(mut output, transfer.to_gamma_fast(value.r))
			emit(mut output, transfer.to_linear(value.r))
			emit(mut output, transfer.to_linear_fast(value.r))
		}
		emit(mut output, zigimg.apply_gamma(value.r, value.g))
		emit(mut output, zigimg.remove_gamma(value.r, value.g))
		white_points := zigimg.WhitePoints{}
		$for field in zigimg.WhitePoints.fields {
			record(mut output, white_points.$(field.name))
		}
		println(output.str())
	}
}
