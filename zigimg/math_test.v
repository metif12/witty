module zigimg

import math

fn test_locked_two_component_matrix_examples() {
	identity := Float2x2.identity()
	assert identity.matrix == [[f32(1), 0]!, [f32(0), 1]!]!
	matrix := Float2x2.from_array([f32(1), 2, 3, 4]!)
	assert matrix.matrix == [[f32(1), 2]!, [f32(3), 4]!]!
	assert matrix.determinant() == -2
	inverse := matrix.inverse()
	expected := [[f32(-2), 1]!, [f32(1.5), -0.5]!]!
	for row in 0 .. 2 {
		for column in 0 .. 2 {
			assert math.abs(inverse.matrix[row][column] - expected[row][column]) <= 0.1
		}
	}
	vector := Float2([f32(5), 6]!)
	assert matrix.mul_vector(vector) == Float2([f32(17), 39]!)
	assert vector == Float2([f32(5), 6]!)
	assert matrix.mul(Float2x2.from_array([f32(5), 6, 7, 8]!)).matrix == [
		[f32(19), 22]!,
		[f32(43), 50]!,
	]!
	assert matrix.transpose().matrix == [[f32(1), 3]!, [f32(2), 4]!]!
	assert matrix.matrix == [[f32(1), 2]!, [f32(3), 4]!]!
}

fn test_locked_three_component_matrix_examples() {
	assert Float3x3.identity().matrix == [[f32(1), 0, 0]!, [f32(0), 1, 0]!,
		[f32(0), 0, 1]!]!
	matrix := Float3x3.from_array([f32(2), 3, 4, 4, 4, 6, 5, 6, 6]!)
	assert matrix.determinant() == 10
	inverse := matrix.inverse()
	expected := [[f32(-1.2), 0.6, 0.2]!, [f32(0.6), -0.8, 0.4]!,
		[f32(0.4), 0.3, -0.4]!]!
	for row in 0 .. 3 {
		for column in 0 .. 3 {
			assert math.abs(inverse.matrix[row][column] - expected[row][column]) <= 0.1
		}
	}
	sequential := Float3x3.from_array([f32(1), 2, 3, 4, 5, 6, 7, 8, 9]!)
	assert sequential.determinant() == 0
	assert sequential.mul_vector(Float3([f32(5), 6, 7]!)) == Float3([f32(38), 92, 146]!)
	product := sequential.mul(Float3x3.from_array([f32(9), 8, 7, 6, 5, 4, 3, 2, 11]!))
	assert product.matrix == [[f32(30), 24, 48]!, [f32(84), 69, 114]!,
		[f32(138), 114, 180]!]!
	assert sequential.transpose().matrix == [[f32(1), 4, 7]!,
		[f32(2), 5, 8]!, [f32(3), 6, 9]!]!
}

fn test_four_component_matrix_and_source_singular_behavior() {
	identity := Float4x4.identity()
	matrix := Float4x4.from_array([f32(1), 2, 3, 4, 0, 2, 3, 4, 0, 0, 3, 4, 0, 0, 0, 4]!)
	assert matrix.determinant() == 24
	assert matrix.mul(identity) == matrix
	assert identity.mul(matrix) == matrix
	assert identity.inverse() == identity
	assert matrix.transpose().transpose() == matrix
	assert matrix.mul_vector(Float4([f32(1), 2, 3, 4]!)) == Float4([f32(30), 29, 25, 16]!)
	// The source does not pivot even when a nonsingular matrix has a zero pivot.
	zero_pivot := Float2x2.from_array([f32(0), 1, 1, 0]!).inverse()
	assert math.is_nan(zero_pivot.matrix[0][0])
	assert math.is_nan(zero_pivot.matrix[1][1])
}

fn test_locked_four_component_matrix_examples() {
	matrix := Float4x4.from_array([f32(2), 3, 4, 5, 4, 4, 6, 7, 5, 6, 6, 8, 6, 1, 2, 3]!)
	assert matrix.determinant() == 18
	inverse := matrix.inverse()
	expected := [[f32(-0.5), 0.2, 0.1, 0.1]!, [f32(-1.3), 0.3, 0.6, -0.3]!,
		[f32(-2.5), 2, 0, -0.5]!, [f32(3.2), -1.8, -0.4, 0.5]!]!
	for row in 0 .. 4 {
		for column in 0 .. 4 {
			assert math.abs(inverse.matrix[row][column] - expected[row][column]) <= 0.1
		}
	}
	left := Float4x4.from_array([f32(2), 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]!)
	assert left.mul_vector(Float4([f32(2), 3, 4, 5]!)) == Float4([f32(54), 110, 166, 222]!)
	right := Float4x4.from_array([f32(1), 5, 9, 13, 2, 6, 10, 14, 3, 7, 11, 15, 4, 8, 12, 16]!)
	assert left.mul(right).matrix == [[f32(40), 96, 152, 208]!,
		[f32(80), 200, 320, 440]!, [f32(120), 304, 488, 672]!,
		[f32(160), 408, 656, 904]!]!
	assert left.transpose().matrix == [[f32(2), 6, 10, 14]!, [f32(3), 7, 11, 15]!,
		[f32(4), 8, 12, 16]!, [f32(5), 9, 13, 17]!]!
}

fn test_vector_clamp_keeps_source_nan_and_signed_zero_behavior() {
	vector := Float4([f32(-1), 0.25, 2, f32(math.nan())]!)
	assert clamp4(vector, 0, 1) == Float4([f32(0), 0.25, 1, 0]!)
	assert vector[0] == -1
	assert vector[1] == 0.25
	assert vector[2] == 2
	assert math.is_nan(vector[3])
	assert clamp2(Float2([f32(-1), 2]!), 0, 1) == Float2([f32(0), 1]!)
	assert clamp3(Float3([f32(-1), 0.25, 2]!), 0, 1) == Float3([f32(0), 0.25, 1]!)
}
