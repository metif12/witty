module main

import math
import os
import strings
import zigimg

fn float_value(raw u32) f32 {
	return unsafe { *(&f32(&raw)) }
}

fn emit(mut output strings.Builder, value f32) {
	raw := if math.is_nan(value) { u32(0x7fc00000) } else { unsafe { *(&u32(&value)) } }
	output.write_string('${raw},')
}

@[direct_array_access]
fn record[T](mut output strings.Builder, value T, dimension int) {
	for row in 0 .. dimension {
		for column in 0 .. dimension {
			emit(mut output, value.matrix[row][column])
		}
	}
}

@[direct_array_access]
fn run1(mut output strings.Builder, values []f32) {
	storage := Rows1{}
	dimension := storage.len
	size := dimension * dimension
	mut left_array := Flat1{}
	mut right_array := Flat1{}
	mut vector := Vector1{}
	for index in 0 .. size {
		left_array[index] = values[index]
		right_array[index] = values[size + index]
	}
	for index in 0 .. dimension {
		vector[index] = values[2 * size + index]
	}
	left := zigimg.Matrix.from_array[Rows1, Flat1](left_array)
	right := zigimg.Matrix.from_array[Rows1, Flat1](right_array)
	emit(mut output, left.determinant())
	record(mut output, left.inverse(), dimension)
	result := zigimg.matrix_mul_vector_fixed(left, vector)
	for index in 0 .. dimension {
		emit(mut output, result[index])
	}
	record(mut output, left.mul(right), dimension)
	record(mut output, left.transpose(), dimension)
	record(mut output, zigimg.Matrix.identity[Rows1](), dimension)
	record(mut output, left, dimension)
	record(mut output, right, dimension)
	for index in 0 .. dimension {
		emit(mut output, vector[index])
	}
}

@[direct_array_access]
fn run2(mut output strings.Builder, values []f32) {
	storage := Rows2{}
	dimension := storage.len
	size := dimension * dimension
	mut left_array := Flat2{}
	mut right_array := Flat2{}
	mut vector := Vector2{}
	for index in 0 .. size {
		left_array[index] = values[index]
		right_array[index] = values[size + index]
	}
	for index in 0 .. dimension {
		vector[index] = values[2 * size + index]
	}
	left := zigimg.Matrix.from_array[Rows2, Flat2](left_array)
	right := zigimg.Matrix.from_array[Rows2, Flat2](right_array)
	emit(mut output, left.determinant())
	record(mut output, left.inverse(), dimension)
	result := zigimg.matrix_mul_vector_fixed(left, vector)
	for index in 0 .. dimension {
		emit(mut output, result[index])
	}
	record(mut output, left.mul(right), dimension)
	record(mut output, left.transpose(), dimension)
	record(mut output, zigimg.Matrix.identity[Rows2](), dimension)
	record(mut output, left, dimension)
	record(mut output, right, dimension)
	for index in 0 .. dimension {
		emit(mut output, vector[index])
	}
}

@[direct_array_access]
fn run3(mut output strings.Builder, values []f32) {
	storage := Rows3{}
	dimension := storage.len
	size := dimension * dimension
	mut left_array := Flat3{}
	mut right_array := Flat3{}
	mut vector := Vector3{}
	for index in 0 .. size {
		left_array[index] = values[index]
		right_array[index] = values[size + index]
	}
	for index in 0 .. dimension {
		vector[index] = values[2 * size + index]
	}
	left := zigimg.Matrix.from_array[Rows3, Flat3](left_array)
	right := zigimg.Matrix.from_array[Rows3, Flat3](right_array)
	emit(mut output, left.determinant())
	record(mut output, left.inverse(), dimension)
	result := zigimg.matrix_mul_vector_fixed(left, vector)
	for index in 0 .. dimension {
		emit(mut output, result[index])
	}
	record(mut output, left.mul(right), dimension)
	record(mut output, left.transpose(), dimension)
	record(mut output, zigimg.Matrix.identity[Rows3](), dimension)
	record(mut output, left, dimension)
	record(mut output, right, dimension)
	for index in 0 .. dimension {
		emit(mut output, vector[index])
	}
}

@[direct_array_access]
fn run4(mut output strings.Builder, values []f32) {
	storage := Rows4{}
	dimension := storage.len
	size := dimension * dimension
	mut left_array := Flat4{}
	mut right_array := Flat4{}
	mut vector := Vector4{}
	for index in 0 .. size {
		left_array[index] = values[index]
		right_array[index] = values[size + index]
	}
	for index in 0 .. dimension {
		vector[index] = values[2 * size + index]
	}
	left := zigimg.Matrix.from_array[Rows4, Flat4](left_array)
	right := zigimg.Matrix.from_array[Rows4, Flat4](right_array)
	emit(mut output, left.determinant())
	record(mut output, left.inverse(), dimension)
	result := zigimg.matrix_mul_vector_fixed(left, vector)
	for index in 0 .. dimension {
		emit(mut output, result[index])
	}
	record(mut output, left.mul(right), dimension)
	record(mut output, left.transpose(), dimension)
	record(mut output, zigimg.Matrix.identity[Rows4](), dimension)
	record(mut output, left, dimension)
	record(mut output, right, dimension)
	for index in 0 .. dimension {
		emit(mut output, vector[index])
	}
}

@[direct_array_access]
fn run5(mut output strings.Builder, values []f32) {
	storage := Rows5{}
	dimension := storage.len
	size := dimension * dimension
	mut left_array := Flat5{}
	mut right_array := Flat5{}
	mut vector := Vector5{}
	for index in 0 .. size {
		left_array[index] = values[index]
		right_array[index] = values[size + index]
	}
	for index in 0 .. dimension {
		vector[index] = values[2 * size + index]
	}
	left := zigimg.Matrix.from_array[Rows5, Flat5](left_array)
	right := zigimg.Matrix.from_array[Rows5, Flat5](right_array)
	emit(mut output, left.determinant())
	record(mut output, left.inverse(), dimension)
	result := zigimg.matrix_mul_vector_fixed(left, vector)
	for index in 0 .. dimension {
		emit(mut output, result[index])
	}
	record(mut output, left.mul(right), dimension)
	record(mut output, left.transpose(), dimension)
	record(mut output, zigimg.Matrix.identity[Rows5](), dimension)
	record(mut output, left, dimension)
	record(mut output, right, dimension)
	for index in 0 .. dimension {
		emit(mut output, vector[index])
	}
}

@[direct_array_access]
fn run8(mut output strings.Builder, values []f32) {
	storage := Rows8{}
	dimension := storage.len
	size := dimension * dimension
	mut left_array := Flat8{}
	mut right_array := Flat8{}
	mut vector := Vector8{}
	for index in 0 .. size {
		left_array[index] = values[index]
		right_array[index] = values[size + index]
	}
	for index in 0 .. dimension {
		vector[index] = values[2 * size + index]
	}
	left := zigimg.Matrix.from_array[Rows8, Flat8](left_array)
	right := zigimg.Matrix.from_array[Rows8, Flat8](right_array)
	emit(mut output, left.determinant())
	record(mut output, left.inverse(), dimension)
	result := zigimg.matrix_mul_vector_fixed(left, vector)
	for index in 0 .. dimension {
		emit(mut output, result[index])
	}
	record(mut output, left.mul(right), dimension)
	record(mut output, left.transpose(), dimension)
	record(mut output, zigimg.Matrix.identity[Rows8](), dimension)
	record(mut output, left, dimension)
	record(mut output, right, dimension)
	for index in 0 .. dimension {
		emit(mut output, vector[index])
	}
}

@[direct_array_access]
fn custom5(mut output strings.Builder, values []f32) {
	storage := CustomFiveRows{}
	dimension := storage.len
	size := dimension * dimension
	mut left_array := Flat5{}
	mut right_array := Flat5{}
	mut vector := Vector5{}
	for index in 0 .. size {
		left_array[index] = values[index]
		right_array[index] = values[size + index]
	}
	for index in 0 .. dimension {
		vector[index] = values[2 * size + index]
	}
	left := zigimg.Matrix.from_array[CustomFiveRows, Flat5](left_array)
	right := zigimg.Matrix.from_array[CustomFiveRows, Flat5](right_array)
	emit(mut output, left.determinant())
	record(mut output, left.inverse(), dimension)
	result := zigimg.matrix_mul_vector_fixed(left, vector)
	for index in 0 .. dimension {
		emit(mut output, result[index])
	}
	record(mut output, left.mul(right), dimension)
	record(mut output, left.transpose(), dimension)
	record(mut output, zigimg.Matrix.identity[CustomFiveRows](), dimension)
	record(mut output, left, dimension)
	record(mut output, right, dimension)
	for index in 0 .. dimension {
		emit(mut output, vector[index])
	}
}

type Rows1 = [1][1]f32
type Flat1 = [1]f32
type Vector1 = [1]f32

type Rows2 = [2][2]f32
type Flat2 = [4]f32
type Vector2 = [2]f32

type Rows3 = [3][3]f32
type Flat3 = [9]f32
type Vector3 = [3]f32

type Rows4 = [4][4]f32
type Flat4 = [16]f32
type Vector4 = [4]f32

type Rows5 = [5][5]f32
type Flat5 = [25]f32
type Vector5 = [5]f32

type Rows8 = [8][8]f32
type Flat8 = [64]f32
type Vector8 = [8]f32

type CustomFiveRows = [5][5]f32

@[direct_array_access]
fn original2(mut output strings.Builder, values []f32) {
	mut left_array := [4]f32{}
	mut right_array := [4]f32{}
	mut vector := zigimg.Float2{}
	for index in 0 .. 4 {
		left_array[index] = values[index]
		right_array[index] = values[4 + index]
	}
	for index in 0 .. 2 {
		vector[index] = values[8 + index]
	}
	left := zigimg.Float2x2.from_array(left_array)
	right := zigimg.Float2x2.from_array(right_array)
	emit(mut output, left.determinant())
	record(mut output, left.inverse(), 2)
	result := left.mul_vector(vector)
	for index in 0 .. 2 {
		emit(mut output, result[index])
	}
	record(mut output, left.mul(right), 2)
	record(mut output, left.transpose(), 2)
	record(mut output, zigimg.Float2x2.identity(), 2)
	record(mut output, left, 2)
	record(mut output, right, 2)
	for index in 0 .. 2 {
		emit(mut output, vector[index])
	}
}

@[direct_array_access]
fn original3(mut output strings.Builder, values []f32) {
	mut left_array := [9]f32{}
	mut right_array := [9]f32{}
	mut vector := zigimg.Float3{}
	for index in 0 .. 9 {
		left_array[index] = values[index]
		right_array[index] = values[9 + index]
	}
	for index in 0 .. 3 {
		vector[index] = values[18 + index]
	}
	left := zigimg.Float3x3.from_array(left_array)
	right := zigimg.Float3x3.from_array(right_array)
	emit(mut output, left.determinant())
	record(mut output, left.inverse(), 3)
	result := left.mul_vector(vector)
	for index in 0 .. 3 {
		emit(mut output, result[index])
	}
	record(mut output, left.mul(right), 3)
	record(mut output, left.transpose(), 3)
	record(mut output, zigimg.Float3x3.identity(), 3)
	record(mut output, left, 3)
	record(mut output, right, 3)
	for index in 0 .. 3 {
		emit(mut output, vector[index])
	}
}

@[direct_array_access]
fn original4(mut output strings.Builder, values []f32) {
	mut left_array := [16]f32{}
	mut right_array := [16]f32{}
	mut vector := zigimg.Float4{}
	for index in 0 .. 16 {
		left_array[index] = values[index]
		right_array[index] = values[16 + index]
	}
	for index in 0 .. 4 {
		vector[index] = values[32 + index]
	}
	left := zigimg.Float4x4.from_array(left_array)
	right := zigimg.Float4x4.from_array(right_array)
	emit(mut output, left.determinant())
	record(mut output, left.inverse(), 4)
	result := left.mul_vector(vector)
	for index in 0 .. 4 {
		emit(mut output, result[index])
	}
	record(mut output, left.mul(right), 4)
	record(mut output, left.transpose(), 4)
	record(mut output, zigimg.Float4x4.identity(), 4)
	record(mut output, left, 4)
	record(mut output, right, 4)
	for index in 0 .. 4 {
		emit(mut output, vector[index])
	}
}

type RectangularRows = [2][3]f32

fn main() {
	match os.args[1] {
		'rectangular' {
			println(zigimg.Matrix.identity[RectangularRows]())
			return
		}
		'short_array' {
			flat := Flat1{}
			println(zigimg.Matrix.from_array[Rows5, Flat1](flat))
			return
		}
		'short_vector' {
			value := zigimg.Matrix.identity[Rows5]()
			vector := Vector1{}
			println(zigimg.matrix_mul_vector_fixed(value, vector))
			return
		}
		else {}
	}

	for line in os.read_lines(os.args[1]) or { panic(err) } {
		parts := line.split('|')
		values := parts[1..].map(float_value(it.u32()))
		mut output := strings.new_builder(3000)
		match parts[0] {
			'1' {
				run1(mut output, values)
			}
			'2' {
				run2(mut output, values)
				original2(mut output, values)
			}
			'3' {
				run3(mut output, values)
				original3(mut output, values)
			}
			'4' {
				run4(mut output, values)
				original4(mut output, values)
			}
			'5' {
				run5(mut output, values)
				custom5(mut output, values)
			}
			'8' {
				run8(mut output, values)
			}
			else {
				panic('InvalidDimension')
			}
		}

		println(output.str())
	}
}
