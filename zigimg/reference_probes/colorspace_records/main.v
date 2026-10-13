module main

import math
import os
import strings
import zigimg as p

__global (
	events []u64
)

fn float_value(raw u32) f32 {
	return unsafe { *(&f32(&raw)) }
}

fn log(id u32, value f32) {
	events << (u64(id) << 32) | u64(unsafe { *(&u32(&value)) })
}

fn cb0(x f32) f32 {
	log(0, x)
	return x
}

fn cb1(x f32) f32 {
	log(1, x)
	return -x
}

fn cb2(x f32) f32 {
	log(2, x)
	return x + 1
}

fn cb3(x f32) f32 {
	log(3, x)
	return x * 2
}

fn callback(index u8) fn (f32) f32 {
	return match index % 4 {
		0 { cb0 }
		1 { cb1 }
		2 { cb2 }
		else { cb3 }
	}
}

fn emit(mut output strings.Builder, value f32, canonical bool) {
	raw := if canonical && math.is_nan(value) { u32(0x7fc00000) } else { unsafe { *(&u32(&value)) } }
	output.write_string('${raw},')
}

fn matrix(seed u8) p.Float4x4 {
	mut flat := [16]f32{}
	for i in 0 .. 16 {
		flat[i] = if i % 5 == 0 { f32(1) } else { f32((i + int(seed)) % 16) / 16 }
	}
	return p.Float4x4.from_array(flat)
}

fn args_for(seed u8) p.RgbColorspaceInitArgs {
	return p.RgbColorspaceInitArgs{
		red:            p.CIExyY{
			x: .64
			y: .33
		}
		green:          p.CIExyY{
			x: .3
			y: .6
		}
		blue:           p.CIExyY{
			x: .15
			y: .06
		}
		white:          p.CIExyY{
			x: .3127
			y: .3290
		}
		to_gamma:       callback(seed)
		to_gamma_fast:  callback(seed + u8(1))
		to_linear:      callback(seed + u8(2))
		to_linear_fast: callback(seed + u8(3))
	}
}

fn direct(args p.RgbColorspaceInitArgs, seed u8) p.RgbColorspace {
	return p.RgbColorspace{
		red:               args.red
		green:             args.green
		blue:              args.blue
		white:             args.white
		rgba_to_xyza:      matrix(seed)
		xyza_to_rgba:      matrix(seed + u8(1))
		to_gamma_fn:       args.to_gamma
		to_gamma_fast_fn:  args.to_gamma_fast
		to_linear_fn:      args.to_linear
		to_linear_fast_fn: args.to_linear_fast
	}
}

fn changed(value p.RgbColorspace, field u8, seed u8, whole bool) p.RgbColorspace {
	mut result := value
	xy := p.CIExyY{
		x: f32(seed) / 256
		y: .5
	}
	match field {
		0 {
			result.red = xy
		}
		1 {
			result.green = xy
		}
		2 {
			result.blue = xy
		}
		3 {
			result.white = xy
		}
		4 {
			if whole {
				result.rgba_to_xyza = matrix(seed)
			} else {
				result.rgba_to_xyza.matrix[int(seed % 4)][int((seed / 4) % 4)] = xy.x
			}
		}
		5 {
			if whole {
				result.xyza_to_rgba = matrix(seed)
			} else {
				result.xyza_to_rgba.matrix[int(seed % 4)][int((seed / 4) % 4)] = xy.x
			}
		}
		6 {
			result.to_gamma_fn = callback(seed)
		}
		7 {
			result.to_gamma_fast_fn = callback(seed)
		}
		8 {
			result.to_linear_fn = callback(seed)
		}
		9 {
			result.to_linear_fast_fn = callback(seed)
		}
		else {
			panic('invalid field')
		}
	}

	return result
}

fn observe(mut output strings.Builder, space p.RgbColorspace, value p.Colorf32) {
	for xy in [space.red, space.green, space.blue, space.white] {
		emit(mut output, xy.x, false)
		emit(mut output, xy.y, false)
	}
	for m in [space.rgba_to_xyza, space.xyza_to_rgba] {
		for row in 0 .. 4 {
			for i in 0 .. 4 {
				emit(mut output, m.matrix[row][i], true)
			}
		}
	}
	events = []u64{}
	results := [space.to_gamma(value), space.to_gamma_fast(value),
		space.to_linear(value), space.to_linear_fast(value)]
	for rgba in results {
		emit(mut output, rgba.r, true)
		emit(mut output, rgba.g, true)
		emit(mut output, rgba.b, true)
		emit(mut output, rgba.a, false)
	}
	output.write_string('${events.len}:')
	for event in events {
		output.write_string('${event},')
	}
	output.write_string(';')
}

fn main() {
	contents := os.read_file(os.args[1]) or { panic(err) }
	mut output := strings.new_builder(64 * 1024)
	for line in contents.split_into_lines() {
		fields := line.split('|')
		form := u8(fields[0].int())
		operation := u8(fields[1].int())
		field := u8(fields[2].int())
		seed := u8(fields[3].int())
		pixel := fields[4..].map(float_value(u32(it.u64())))
		value := p.Colorf32{
			r: pixel[0]
			g: pixel[1]
			b: pixel[2]
			a: pixel[3]
		}
		mut args := if form == 2 { p.RgbColorspaceInitArgs{} } else { args_for(seed) }
		mut original := if form == 0 { direct(args, seed) } else { p.RgbColorspace.init(args) }
		mut copy := original
		mut returned := original
		match operation {
			0 {}
			1 {
				copy = changed(copy, field, seed + u8(1), false)
			}
			2 {
				original = changed(original, field, seed + u8(1), false)
			}
			3 {
				copy = changed(copy, field, seed + u8(1), true)
				returned = changed(copy, (field + u8(1)) % 10, seed + u8(2), true)
			}
			4 {
				original = direct(args_for(seed + u8(1)), seed + u8(1))
			}
			5 {
				args.red.x = -99
				args.to_gamma = callback(seed + u8(1))
			}
			else {
				panic('invalid operation')
			}
		}

		observe(mut output, original, value)
		observe(mut output, copy, value)
		observe(mut output, returned, value)
		emit(mut output, args.red.x, false)
		for v in pixel {
			emit(mut output, v, false)
		}
		output.write_string('\n')
	}
	print(output.str())
}
