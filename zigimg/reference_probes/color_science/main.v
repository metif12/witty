module main

import math
import os
import strings
import zigimg

fn float_value(bits u32) f32 {
	return unsafe { *(&f32(&bits)) }
}

fn emit(mut output strings.Builder, value f32) {
	bits := if math.is_nan(value) { u32(0x7fc00000) } else { unsafe { *(&u32(&value)) } }
	output.write_string('${bits},')
}

fn record[T](mut output strings.Builder, value T) {
	$for field in T.fields {
		emit(mut output, value.$(field.name))
	}
}

fn main() {
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		values := line.split('|').map(float_value(it.u32()))
		vector := zigimg.Float4([values[0], values[1], values[2], values[3]]!)
		xyz := zigimg.CIEXYZ{
			x: values[0]
			y: values[1]
			z: values[2]
		}
		xyza := zigimg.CIEXYZAlpha{
			x: values[0]
			y: values[1]
			z: values[2]
			a: values[3]
		}
		white := zigimg.CIExyY{
			x: values[4]
			y: values[5]
		}
		mut output := strings.new_builder(800)
		emit(mut output, white.z())
		record(mut output, white.to_xyz(1))
		record(mut output, zigimg.CIELab.from_xyz(xyz, white))
		lab := zigimg.CIELab{
			l: values[0]
			a: values[1]
			b: values[2]
		}
		record(mut output, lab.to_xyz(white))
		record(mut output, lab.to_lchab())
		record(mut output, lab.to_lchab().to_lab())
		lab_alpha := zigimg.CIELabAlpha.from_float4(vector)
		record(mut output, lab_alpha.to_xyz_alpha(white))
		record(mut output, lab_alpha.to_lchab_alpha().to_lab_alpha())
		record(mut output, zigimg.CIELuv.from_xyz(xyz, white))
		luv := zigimg.CIELuv{
			l: values[0]
			u: values[1]
			v: values[2]
		}
		record(mut output, luv.to_xyz(white))
		record(mut output, luv.to_lchuv())
		record(mut output, luv.to_lchuv().to_luv())
		luv_alpha := zigimg.CIELuvAlpha.from_float4(vector)
		record(mut output, luv_alpha.to_xyz_alpha(white))
		record(mut output, luv_alpha.to_lchuv_alpha().to_luv_alpha())
		record(mut output, zigimg.Oklab.from_xyz(xyz))
		oklab := zigimg.Oklab{
			l: values[0]
			a: values[1]
			b: values[2]
		}
		record(mut output, oklab.to_xyz())
		record(mut output, oklab.to_ok_lch())
		record(mut output, oklab.to_ok_lch().to_oklab())
		record(mut output, zigimg.OklabAlpha.from_xyz_alpha(xyza))
		record(mut output, zigimg.OklabAlpha.from_float4(vector).to_xyz_alpha())
		matrix := zigimg.Float4x4.identity()
		hsluv := zigimg.HSLuv.from_cielchuv(zigimg.CIELCHuv{
			l: values[0]
			c: values[1]
			h: values[2]
		}, matrix)
		record(mut output, hsluv)
		record(mut output, hsluv.to_cielchuv(matrix))
		hsluva := zigimg.HSLuvAlpha.from_cielchuv_alpha(zigimg.CIELCHuvAlpha{
			l:     values[0]
			c:     values[1]
			h:     values[2]
			alpha: values[3]
		}, matrix)
		record(mut output, hsluva.to_cielchuv_alpha(matrix))
		record(mut output, zigimg.HSLuvAlpha.from_float4(vector))
		println(output.str())
	}
}
