module zigimg

// Fixed-size counterparts of locked math.zig's vector and Matrix(T) types.
// Fixed arrays retain inline value storage; arithmetic follows the source's
// elimination and row-by-row operations without pivoting or singular checks.

pub type Float2 = [2]f32

pub struct Float2x2 {
pub mut:
	matrix [2][2]f32
}

pub fn Float2x2.from_array(values [4]f32) Float2x2 {
	mut result := Float2x2{}
	for row in 0 .. 2 {
		for column in 0 .. 2 {
			result.matrix[row][column] = values[row * 2 + column]
		}
	}
	return result
}

pub fn Float2x2.identity() Float2x2 {
	return matrix_identity[Float2x2](2)
}

pub fn (value Float2x2) determinant() f32 {
	return matrix_determinant(value, 2)
}

pub fn (value Float2x2) inverse() Float2x2 {
	return matrix_inverse(value, 2)
}

pub fn (value Float2x2) transpose() Float2x2 {
	return matrix_transpose(value, 2)
}

pub fn (value Float2x2) mul_vector(vector Float2) Float2 {
	return matrix_mul_vector(value, vector, 2)
}

pub fn (value Float2x2) mul(right Float2x2) Float2x2 {
	return matrix_mul(value, right, 2)
}

pub fn clamp2(value Float2, minimum f32, maximum f32) Float2 {
	mut result := value
	for channel in 0 .. 2 {
		result[channel] = color_min_f32(color_max_f32(value[channel], minimum), maximum)
	}
	return result
}

pub type Float3 = [3]f32

pub struct Float3x3 {
pub mut:
	matrix [3][3]f32
}

pub fn Float3x3.from_array(values [9]f32) Float3x3 {
	mut result := Float3x3{}
	for row in 0 .. 3 {
		for column in 0 .. 3 {
			result.matrix[row][column] = values[row * 3 + column]
		}
	}
	return result
}

pub fn Float3x3.identity() Float3x3 {
	return matrix_identity[Float3x3](3)
}

pub fn (value Float3x3) determinant() f32 {
	return matrix_determinant(value, 3)
}

pub fn (value Float3x3) inverse() Float3x3 {
	return matrix_inverse(value, 3)
}

pub fn (value Float3x3) transpose() Float3x3 {
	return matrix_transpose(value, 3)
}

pub fn (value Float3x3) mul_vector(vector Float3) Float3 {
	return matrix_mul_vector(value, vector, 3)
}

pub fn (value Float3x3) mul(right Float3x3) Float3x3 {
	return matrix_mul(value, right, 3)
}

pub fn clamp3(value Float3, minimum f32, maximum f32) Float3 {
	mut result := value
	for channel in 0 .. 3 {
		result[channel] = color_min_f32(color_max_f32(value[channel], minimum), maximum)
	}
	return result
}

pub type Float4 = [4]f32

pub struct Float4x4 {
pub mut:
	matrix [4][4]f32
}

pub fn Float4x4.from_array(values [16]f32) Float4x4 {
	mut result := Float4x4{}
	for row in 0 .. 4 {
		for column in 0 .. 4 {
			result.matrix[row][column] = values[row * 4 + column]
		}
	}
	return result
}

pub fn Float4x4.identity() Float4x4 {
	return matrix_identity[Float4x4](4)
}

pub fn (value Float4x4) determinant() f32 {
	return matrix_determinant(value, 4)
}

pub fn (value Float4x4) inverse() Float4x4 {
	return matrix_inverse(value, 4)
}

pub fn (value Float4x4) transpose() Float4x4 {
	return matrix_transpose(value, 4)
}

pub fn (value Float4x4) mul_vector(vector Float4) Float4 {
	return matrix_mul_vector(value, vector, 4)
}

pub fn (value Float4x4) mul(right Float4x4) Float4x4 {
	return matrix_mul(value, right, 4)
}

pub fn clamp4(value Float4, minimum f32, maximum f32) Float4 {
	mut result := value
	for channel in 0 .. 4 {
		result[channel] = color_min_f32(color_max_f32(value[channel], minimum), maximum)
	}
	return result
}

fn matrix_identity[T](dimension int) T {
	mut result := T{}
	for diagonal in 0 .. dimension {
		result.matrix[diagonal][diagonal] = 1
	}
	return result
}

fn matrix_determinant[T](value T, dimension int) f32 {
	if dimension == 2 {
		left := value.matrix[0][0] * value.matrix[1][1]
		right := value.matrix[0][1] * value.matrix[1][0]
		return left - right
	}
	mut temporary := value
	for row in 0 .. dimension - 1 {
		for next_row in row + 1 .. dimension {
			factor := temporary.matrix[next_row][row] / temporary.matrix[row][row]
			for column in 0 .. dimension {
				product := factor * temporary.matrix[row][column]
				temporary.matrix[next_row][column] -= product
			}
		}
	}
	mut result := temporary.matrix[0][0]
	for diagonal in 1 .. dimension {
		result *= temporary.matrix[diagonal][diagonal]
	}
	return result
}

fn matrix_inverse[T](value T, dimension int) T {
	mut temporary := value
	mut result := matrix_identity[T](dimension)
	for row in 0 .. dimension {
		inverse_pivot := f32(1) / temporary.matrix[row][row]
		for column in 0 .. dimension {
			temporary.matrix[row][column] *= inverse_pivot
			result.matrix[row][column] *= inverse_pivot
		}
		for next_row in row + 1 .. dimension {
			factor := temporary.matrix[next_row][row] / temporary.matrix[row][row]
			for column in 0 .. dimension {
				temporary_product := factor * temporary.matrix[row][column]
				temporary.matrix[next_row][column] -= temporary_product
				result_product := factor * result.matrix[row][column]
				result.matrix[next_row][column] -= result_product
			}
		}
	}
	for row := dimension - 1; row >= 1; row-- {
		for previous_row := row - 1; previous_row >= 0; previous_row-- {
			factor := temporary.matrix[previous_row][row] / temporary.matrix[row][row]
			for column in 0 .. dimension {
				temporary_product := factor * temporary.matrix[row][column]
				temporary.matrix[previous_row][column] -= temporary_product
				result_product := factor * result.matrix[row][column]
				result.matrix[previous_row][column] -= result_product
			}
		}
	}
	return result
}

fn matrix_mul_vector[T, V](value T, vector V, dimension int) V {
	mut result := vector
	for row in 0 .. dimension {
		mut sum := f32(-0.0)
		for column in 0 .. dimension {
			product := value.matrix[row][column] * vector[column]
			sum += product
		}
		result[row] = sum
	}
	return result
}

fn matrix_mul[T](value T, right T, dimension int) T {
	mut result := T{}
	transposed_right := matrix_transpose(right, dimension)
	for row in 0 .. dimension {
		for column in 0 .. dimension {
			mut sum := f32(-0.0)
			for component in 0 .. dimension {
				product := value.matrix[row][component] * transposed_right.matrix[column][component]
				sum += product
			}
			result.matrix[row][column] = sum
		}
	}
	return result
}

fn matrix_transpose[T](value T, dimension int) T {
	mut result := T{}
	for row in 0 .. dimension {
		for column in 0 .. dimension {
			result.matrix[row][column] = value.matrix[column][row]
		}
	}
	return result
}
