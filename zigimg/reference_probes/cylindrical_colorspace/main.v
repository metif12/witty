module main

import math
import os
import strings
import zigimg as p

fn float_value(raw u32) f32 {
	return unsafe { *(&f32(&raw)) }
}

fn emit(mut output strings.Builder, value f32, canonical bool) {
	raw := if canonical && math.is_nan(value) { u32(0x7fc00000) } else { unsafe { *(&u32(&value)) } }
	output.write_string('${raw},')
}

fn main() {
	presets := [p.bt601_ntsc, p.bt601_pal, p.bt709, p.srgb, p.dcip3_display, p.dcip3_theater,
		p.dcip3_aces, p.bt2020, p.adobe_rgb, p.adobe_wide_gamut_rgb, p.prophoto_rgb,
		p.RgbColorspace.init(p.RgbColorspaceInitArgs{})]
	contents := os.read_file(os.args[1]) or { panic(err) }
	mut output := strings.new_builder(64 * 1024)
	for line in contents.split_into_lines() {
		fields := line.split('|')
		space := presets[fields[0].int()]
		kind := fields[1].int()
		alpha := fields[2].int() != 0
		behavior := if fields[3].int() == 0 {
			p.PostConversionBehavior.none
		} else {
			p.PostConversionBehavior.clamp
		}
		values := fields[4..].map(float_value(u32(it.u64())))
		result := match kind {
			0 {
				if alpha {
					space.from_lchab_alpha(p.CIELCHabAlpha{
						l:     values[0]
						c:     values[1]
						h:     values[2]
						alpha: values[3]
					}, behavior)
				} else {
					space.from_lchab(p.CIELCHab{ l: values[0], c: values[1], h: values[2] },
						behavior)
				}
			}
			1 {
				if alpha {
					space.from_lchuv_alpha(p.CIELCHuvAlpha{
						l:     values[0]
						c:     values[1]
						h:     values[2]
						alpha: values[3]
					}, behavior)
				} else {
					space.from_lchuv(p.CIELCHuv{ l: values[0], c: values[1], h: values[2] },
						behavior)
				}
			}
			2 {
				if alpha {
					space.from_ok_lch_alpha(p.OkLChAlpha{
						l:     values[0]
						c:     values[1]
						h:     values[2]
						alpha: values[3]
					}, behavior)
				} else {
					space.from_ok_lch(p.OkLCh{ l: values[0], c: values[1], h: values[2] }, behavior)
				}
			}
			else {
				panic('invalid kind')
			}
		}

		for value in [result.r, result.g, result.b, result.a] {
			emit(mut output, value, true)
		}
		for value in values {
			emit(mut output, value, false)
		}
		output.write_string('\n')
	}
	print(output.str())
}
