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

fn record[T](mut output strings.Builder, value T, canonical bool) {
	$for field in T.fields {
		emit(mut output, value.$(field.name), canonical)
	}
}

fn changed[T](value T, field_index int, raw u32) T {
	mut result := value
	mut index := 0
	$for field in T.fields {
		if index == field_index { result.$(field.name) = float_value(raw) }
		index++
	}
	return result
}

fn copies[T](mut output strings.Builder, original T, field int) {
	mut copy := changed(original, field, 0x7fc01234)
	returned := changed(original, field, 0x80000000)
	record(mut output, original, false)
	record(mut output, copy, false)
	record(mut output, returned, false)
	copy = original
	record(mut output, copy, false)
	record(mut output, original, false)
}

fn main() {
	contents := os.read_file(os.args[1]) or { panic(err) }
	mut output := strings.new_builder(64 * 1024)
	for line in contents.split_into_lines() {
		fields := line.split('|')
		kind := fields[0].int()
		field := fields[1].int()
		values := fields[2..].map(float_value(u32(it.u64())))
		plain := p.HSLuv{
			h: values[0]
			s: values[1]
			l: values[2]
		}
		alpha := p.HSLuvAlpha{
			h:     values[0]
			s:     values[1]
			l:     values[2]
			alpha: values[3]
		}
		if kind == 0 {
			copies(mut output, plain, field)
		} else {
			copies(mut output, alpha, field)
		}
		mut flat := [16]f32{}
		for index in 0 .. 16 {
			flat[index] = values[4 + index]
		}
		matrix := p.Float4x4.from_array(flat)
		lch := p.CIELCHuv{
			l: values[2]
			c: values[1]
			h: values[0]
		}
		lcha := p.CIELCHuvAlpha{
			l:     values[2]
			c:     values[1]
			h:     values[0]
			alpha: values[3]
		}
		record(mut output, p.HSLuv.from_cielchuv(lch, matrix), true)
		record(mut output, p.HSLuvAlpha.from_cielchuv_alpha(lcha, matrix), true)
		record(mut output, plain.to_cielchuv(matrix), true)
		record(mut output, alpha.to_cielchuv_alpha(matrix), true)
		record(mut output, alpha.to_hsluv(), false)
		vector := p.Float4([values[0], values[1], values[2], values[3]]!)
		wrong_factory := p.HSLuvAlpha.from_float4(vector)
		record(mut output, wrong_factory, false)
		roundtrip := p.HSLuvAlpha.to_float4(wrong_factory)
		for value in roundtrip {
			emit(mut output, value, false)
		}
		record(mut output, plain, false)
		record(mut output, alpha, false)
		output.write_string('\n')
	}
	print(output.str())
}
