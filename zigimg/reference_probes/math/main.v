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

fn matrix[T](mut output strings.Builder, value T) {
	for row in value.matrix {
		for component in row {
			emit(mut output, component)
		}
	}
}

fn run2(mut output strings.Builder, values []f32) {
	mut left_values := [4]f32{}
	mut right_values := [4]f32{}
	for i in 0 .. 4 {
		left_values[i] = values[i]
		right_values[i] = values[4 + i]
	}
	left := zigimg.Float2x2.from_array(left_values)
	right := zigimg.Float2x2.from_array(right_values)
	vector := zigimg.Float2([values[8], values[9]]!)
	emit(mut output, left.determinant())
	matrix(mut output, left.inverse())
	for component in left.mul_vector(vector) {
		emit(mut output, component)
	}
	matrix(mut output, left.mul(right))
	matrix(mut output, left.transpose())
	for component in zigimg.clamp2(vector, values[10], values[11]) {
		emit(mut output, component)
	}
	matrix(mut output, zigimg.Float2x2.identity())
	matrix(mut output, left)
	for component in vector {
		emit(mut output, component)
	}
}

fn run3(mut output strings.Builder, values []f32) {
	mut left_values := [9]f32{}
	mut right_values := [9]f32{}
	for i in 0 .. 9 {
		left_values[i] = values[i]
		right_values[i] = values[9 + i]
	}
	left := zigimg.Float3x3.from_array(left_values)
	right := zigimg.Float3x3.from_array(right_values)
	vector := zigimg.Float3([values[18], values[19], values[20]]!)
	emit(mut output, left.determinant())
	matrix(mut output, left.inverse())
	for component in left.mul_vector(vector) {
		emit(mut output, component)
	}
	matrix(mut output, left.mul(right))
	matrix(mut output, left.transpose())
	for component in zigimg.clamp3(vector, values[21], values[22]) {
		emit(mut output, component)
	}
	matrix(mut output, zigimg.Float3x3.identity())
	matrix(mut output, left)
	for component in vector {
		emit(mut output, component)
	}
}

fn run4(mut output strings.Builder, values []f32) {
	mut left_values := [16]f32{}
	mut right_values := [16]f32{}
	for i in 0 .. 16 {
		left_values[i] = values[i]
		right_values[i] = values[16 + i]
	}
	left := zigimg.Float4x4.from_array(left_values)
	right := zigimg.Float4x4.from_array(right_values)
	vector := zigimg.Float4([values[32], values[33], values[34], values[35]]!)
	emit(mut output, left.determinant())
	matrix(mut output, left.inverse())
	for component in left.mul_vector(vector) {
		emit(mut output, component)
	}
	matrix(mut output, left.mul(right))
	matrix(mut output, left.transpose())
	for component in zigimg.clamp4(vector, values[36], values[37]) {
		emit(mut output, component)
	}
	matrix(mut output, zigimg.Float4x4.identity())
	matrix(mut output, left)
	for component in vector {
		emit(mut output, component)
	}
}

fn main() {
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		fields := line.split('|')
		values := fields[1..].map(float_value(it.u32()))
		mut output := strings.new_builder(800)
		match fields[0] {
			'2' { run2(mut output, values) }
			'3' { run3(mut output, values) }
			'4' { run4(mut output, values) }
			else { panic('InvalidDimension') }
		}

		println(output.str())
	}
}
