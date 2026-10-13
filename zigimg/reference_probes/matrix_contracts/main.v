module main

import os
import strings
import zigimg as p

fn float_value(raw u32) f32 {
	return unsafe { *(&f32(&raw)) }
}

fn emit(mut output strings.Builder, value f32) {
	raw := unsafe { *(&u32(&value)) }
	output.write_string('${raw},')
}

@[direct_array_access]
fn record[M](mut output strings.Builder, value M, n int) {
	for row in 0 .. n {
		for column in 0 .. n {
			emit(mut output, value.matrix[row][column])
		}
	}
}

@[direct_array_access]
fn changed[M](value M, row int, column int, raw u32) M {
	mut result := value
	result.matrix[row][column] = float_value(raw)
	return result
}

@[direct_array_access]
fn finish[M, B, A](mut output strings.Builder, mut original M, constructed M, mut storage B, mut flat A, row int, column int, n int) {
	mut copy := original
	copy.matrix[row][column] = float_value(0x80000000)
	storage[row][column] = float_value(0x7fc01234)
	flat[row * n + column] = float_value(0xff800000)
	mut row_copy := constructed
	row_copy.matrix[row] = storage[row]
	mut replacement := original
	replacement.matrix = storage
	storage[row][column] = float_value(0x3f800000)
	returned := changed(original, row, column, 0x7fc05678)
	record(mut output, original, n)
	record(mut output, constructed, n)
	record(mut output, copy, n)
	record(mut output, row_copy, n)
	record(mut output, replacement, n)
	record(mut output, returned, n)
	for r in 0 .. n {
		for c in 0 .. n {
			emit(mut output, storage[r][c])
		}
	}
	for i in 0 .. n * n {
		emit(mut output, flat[i])
	}
	mut transposed := original.transpose()
	transposed.matrix[column][row] = float_value(0x7fc09abc)
	record(mut output, transposed, n)
	record(mut output, original, n)
	original.matrix[row][column] = float_value(0x40000000)
	record(mut output, original, n)
	record(mut output, replacement, n)
}

type Rows1 = [1][1]f32
type Flat1 = [1]f32
type Rows2 = [2][2]f32
type Flat2 = [4]f32
type Rows3 = [3][3]f32
type Flat3 = [9]f32
type Rows4 = [4][4]f32
type Flat4 = [16]f32
type Rows5 = [5][5]f32
type Flat5 = [25]f32
type Rows8 = [8][8]f32
type Flat8 = [64]f32

@[direct_array_access]
fn run_named2(mut output strings.Builder, row int, column int, values []f32) {
	mut storage := Rows2{}
	mut flat := Flat2{}
	for r in 0 .. 2 {
		for c in 0 .. 2 {
			storage[r][c] = values[r * 2 + c]
			flat[r * 2 + c] = values[r * 2 + c]
		}
	}
	mut original := p.Float2x2{
		matrix: storage
	}
	constructed := p.Float2x2.from_array(flat)
	finish(mut output, mut original, constructed, mut storage, mut flat, row, column, 2)
	record(mut output, p.Float2x2.identity(), 2)
	output.write_string('\n')
}

@[direct_array_access]
fn run_named3(mut output strings.Builder, row int, column int, values []f32) {
	mut storage := Rows3{}
	mut flat := Flat3{}
	for r in 0 .. 3 {
		for c in 0 .. 3 {
			storage[r][c] = values[r * 3 + c]
			flat[r * 3 + c] = values[r * 3 + c]
		}
	}
	mut original := p.Float3x3{
		matrix: storage
	}
	constructed := p.Float3x3.from_array(flat)
	finish(mut output, mut original, constructed, mut storage, mut flat, row, column, 3)
	record(mut output, p.Float3x3.identity(), 3)
	output.write_string('\n')
}

@[direct_array_access]
fn run_named4(mut output strings.Builder, row int, column int, values []f32) {
	mut storage := Rows4{}
	mut flat := Flat4{}
	for r in 0 .. 4 {
		for c in 0 .. 4 {
			storage[r][c] = values[r * 4 + c]
			flat[r * 4 + c] = values[r * 4 + c]
		}
	}
	mut original := p.Float4x4{
		matrix: storage
	}
	constructed := p.Float4x4.from_array(flat)
	finish(mut output, mut original, constructed, mut storage, mut flat, row, column, 4)
	record(mut output, p.Float4x4.identity(), 4)
	output.write_string('\n')
}

@[direct_array_access]
fn run_generic1(mut output strings.Builder, row int, column int, values []f32) {
	mut storage := Rows1{}
	mut flat := Flat1{}
	for r in 0 .. 1 {
		for c in 0 .. 1 {
			storage[r][c] = values[r * 1 + c]
			flat[r * 1 + c] = values[r * 1 + c]
		}
	}
	mut original := p.Matrix[Rows1]{
		matrix: storage
	}
	constructed := p.Matrix.from_array[Rows1, Flat1](flat)
	finish(mut output, mut original, constructed, mut storage, mut flat, row, column, 1)
	record(mut output, p.Matrix.identity[Rows1](), 1)
	output.write_string('\n')
}

@[direct_array_access]
fn run_generic2(mut output strings.Builder, row int, column int, values []f32) {
	mut storage := Rows2{}
	mut flat := Flat2{}
	for r in 0 .. 2 {
		for c in 0 .. 2 {
			storage[r][c] = values[r * 2 + c]
			flat[r * 2 + c] = values[r * 2 + c]
		}
	}
	mut original := p.Matrix[Rows2]{
		matrix: storage
	}
	constructed := p.Matrix.from_array[Rows2, Flat2](flat)
	finish(mut output, mut original, constructed, mut storage, mut flat, row, column, 2)
	record(mut output, p.Matrix.identity[Rows2](), 2)
	output.write_string('\n')
}

@[direct_array_access]
fn run_generic3(mut output strings.Builder, row int, column int, values []f32) {
	mut storage := Rows3{}
	mut flat := Flat3{}
	for r in 0 .. 3 {
		for c in 0 .. 3 {
			storage[r][c] = values[r * 3 + c]
			flat[r * 3 + c] = values[r * 3 + c]
		}
	}
	mut original := p.Matrix[Rows3]{
		matrix: storage
	}
	constructed := p.Matrix.from_array[Rows3, Flat3](flat)
	finish(mut output, mut original, constructed, mut storage, mut flat, row, column, 3)
	record(mut output, p.Matrix.identity[Rows3](), 3)
	output.write_string('\n')
}

@[direct_array_access]
fn run_generic4(mut output strings.Builder, row int, column int, values []f32) {
	mut storage := Rows4{}
	mut flat := Flat4{}
	for r in 0 .. 4 {
		for c in 0 .. 4 {
			storage[r][c] = values[r * 4 + c]
			flat[r * 4 + c] = values[r * 4 + c]
		}
	}
	mut original := p.Matrix[Rows4]{
		matrix: storage
	}
	constructed := p.Matrix.from_array[Rows4, Flat4](flat)
	finish(mut output, mut original, constructed, mut storage, mut flat, row, column, 4)
	record(mut output, p.Matrix.identity[Rows4](), 4)
	output.write_string('\n')
}

@[direct_array_access]
fn run_generic5(mut output strings.Builder, row int, column int, values []f32) {
	mut storage := Rows5{}
	mut flat := Flat5{}
	for r in 0 .. 5 {
		for c in 0 .. 5 {
			storage[r][c] = values[r * 5 + c]
			flat[r * 5 + c] = values[r * 5 + c]
		}
	}
	mut original := p.Matrix[Rows5]{
		matrix: storage
	}
	constructed := p.Matrix.from_array[Rows5, Flat5](flat)
	finish(mut output, mut original, constructed, mut storage, mut flat, row, column, 5)
	record(mut output, p.Matrix.identity[Rows5](), 5)
	output.write_string('\n')
}

@[direct_array_access]
fn run_generic8(mut output strings.Builder, row int, column int, values []f32) {
	mut storage := Rows8{}
	mut flat := Flat8{}
	for r in 0 .. 8 {
		for c in 0 .. 8 {
			storage[r][c] = values[r * 8 + c]
			flat[r * 8 + c] = values[r * 8 + c]
		}
	}
	mut original := p.Matrix[Rows8]{
		matrix: storage
	}
	constructed := p.Matrix.from_array[Rows8, Flat8](flat)
	finish(mut output, mut original, constructed, mut storage, mut flat, row, column, 8)
	record(mut output, p.Matrix.identity[Rows8](), 8)
	output.write_string('\n')
}

fn main() {
	args := os.args
	contents := os.read_file(args[1]) or { panic(err) }
	mut output := strings.new_builder(64 * 1024)
	for line in contents.split_into_lines() {
		fields := line.split('|')
		form := fields[0].int()
		row := fields[1].int()
		column := fields[2].int()
		values := fields[3..].map(float_value(u32(it.u64())))
		match form {
			0 { run_named2(mut output, row, column, values) }
			1 { run_named3(mut output, row, column, values) }
			2 { run_named4(mut output, row, column, values) }
			3 { run_generic1(mut output, row, column, values) }
			4 { run_generic2(mut output, row, column, values) }
			5 { run_generic3(mut output, row, column, values) }
			6 { run_generic4(mut output, row, column, values) }
			7 { run_generic5(mut output, row, column, values) }
			8 { run_generic8(mut output, row, column, values) }
			else { panic('invalid form') }
		}
	}
	print(output.str())
}
