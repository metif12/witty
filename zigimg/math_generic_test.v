module zigimg

import math

type MatrixOneRow = [1][1]f32
type MatrixOneValue = [1]f32
type MatrixFiveRows = [5][5]f32
type MatrixFiveValues = [25]f32
type MatrixEightRows = [8][8]f32
type MatrixEightValues = [64]f32
type MatrixCustomRows = [5][5]f32

fn test_generic_one_component_and_signed_zero() {
	matrix := Matrix.from_array[MatrixOneRow, MatrixOneValue]([f32(2)]!)
	assert matrix.determinant() == 2
	assert matrix.inverse().matrix == [[f32(0.5)]!]!
	vector := [f32(3)]!
	assert matrix.mul_vector(vector) == [f32(6)]!
	assert matrix.mul(Matrix.identity[MatrixOneRow]()) == matrix
	assert matrix.transpose() == matrix
	assert sizeof(Matrix[MatrixOneRow]) == sizeof(f32)
	minus_zero := f32(-0.0)
	zeros := Matrix.from_array[MatrixOneRow, MatrixOneValue]([minus_zero]!)
	result := zeros.mul_vector([f32(1)]!)
	assert unsafe { *(&u32(&result[0])) } == 0x80000000
	assert math.is_inf(zeros.inverse().matrix[0][0], -1)
	assert vector == [f32(3)]!
}

fn test_generic_five_component_diagonal_and_custom_alias() {
	mut flat := MatrixFiveValues{}
	for index in 0 .. 5 {
		flat[index * 5 + index] = f32(index + 2)
	}
	original := flat
	matrix := Matrix.from_array[MatrixCustomRows, MatrixFiveValues](flat)
	assert matrix.determinant() == 720
	inverse := matrix.inverse()
	for row in 0 .. 5 {
		for column in 0 .. 5 {
			expected := if row == column { f32(1) / f32(row + 2) } else { f32(0) }
			assert math.abs(inverse.matrix[row][column] - expected) <= 0.000001
		}
	}
	identity := Matrix.identity[MatrixCustomRows]()
	assert matrix.mul(identity) == matrix && identity.mul(matrix) == matrix
	assert matrix.transpose() == matrix
	assert flat == original
	assert sizeof(Matrix[MatrixCustomRows]) == 25 * sizeof(f32)
}

fn test_generic_eight_component_triangular_matrix() {
	mut flat := MatrixEightValues{}
	for row in 0 .. 8 {
		for column in row .. 8 {
			flat[row * 8 + column] = if column == row { f32(row + 1) } else { f32(1) }
		}
	}
	matrix := Matrix.from_array[MatrixEightRows, MatrixEightValues](flat)
	assert matrix.determinant() == 40320
	inverse := matrix.inverse()
	identity := matrix.mul(inverse)
	for row in 0 .. 8 {
		for column in 0 .. 8 {
			expected := if row == column { f32(1) } else { f32(0) }
			assert math.abs(identity.matrix[row][column] - expected) <= 0.000001
		}
	}
	assert matrix.transpose().transpose() == matrix
	vector := [f32(1), 1, 1, 1, 1, 1, 1, 1]!
	assert matrix.mul_vector(vector) == [f32(8), 8, 8, 8, 8, 8, 8, 8]!
	assert vector == [f32(1), 1, 1, 1, 1, 1, 1, 1]!
	assert sizeof(Matrix[MatrixEightRows]) == 64 * sizeof(f32)
}

fn test_generic_preserves_source_no_pivot_behavior() {
	mut matrix := Matrix.identity[MatrixFiveRows]()
	matrix.matrix[0][0] = 0
	matrix.matrix[1][1] = 0
	matrix.matrix[0][1] = 1
	matrix.matrix[1][0] = 1
	assert math.is_nan(matrix.determinant())
	inverse := matrix.inverse()
	assert math.is_nan(inverse.matrix[0][0])
	assert math.is_nan(inverse.matrix[1][1])
}
