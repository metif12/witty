module zigimg

// B is a direct named alias of an inline square f32 array, such as
// `type FiveRows = [5][5]f32`. For construction, A names [N*N]f32:
// `Matrix.from_array[FiveRows, FiveValues](values)`.
// Storage follows V fixed-array layout rather than Zig's SIMD-vector ABI.
// V cannot express zero-length fixed arrays. Pinned V 0.5.2 also cannot
// inspect an extra alias layer or reliably forward these static factory
// calls from an enclosing generic function; use explicit named types.
// The source requires matrix storage. V 0.5.2 ignores required attributes
// on this generic field; callers must still provide it explicitly.
// Shapes are checked before bounded arithmetic, also in production builds.
pub struct Matrix[B] {
pub mut:
	matrix B @[required]
}

fn matrix_dimension[B](storage B) int {
	$if B.unaliased_typ is $array_fixed {
		row := storage[0]
		$if row is $array_fixed {
			component := row[0]
			$if component is f32 {
				if storage.len != row.len { panic('Matrix requires square fixed-array rows') }
				return storage.len
			} $else {
				$compile_error('Matrix requires f32 components')
			}
		} $else {
			$compile_error('Matrix requires square fixed-array rows')
		}
	} $else {
		$compile_error('Matrix requires square fixed-array storage')
	}
}

pub fn Matrix.identity[B]() Matrix[B] {
	storage := B{}
	return matrix_identity(Matrix[B]{ matrix: storage }, matrix_dimension(storage))
}

@[direct_array_access]
pub fn Matrix.from_array[B, A](values A) Matrix[B] {
	storage := B{}
	dimension := matrix_dimension(storage)
	$if A.unaliased_typ is $array_fixed {
		component := values[0]
		$if component is f32 {
			if values.len != dimension * dimension {
				panic('Matrix.from_array requires N*N components')
			}
			mut result := Matrix[B]{
				matrix: storage
			}
			for row in 0 .. dimension {
				for column in 0 .. dimension {
					result.matrix[row][column] = values[row * dimension + column]
				}
			}
			return result
		} $else {
			$compile_error('Matrix.from_array requires f32 components')
		}
	} $else {
		$compile_error('Matrix.from_array requires an inline fixed array')
	}
}

pub fn (value Matrix[B]) determinant[B]() f32 {
	return matrix_determinant(value, matrix_dimension(value.matrix))
}

pub fn (value Matrix[B]) inverse[B]() Matrix[B] {
	return matrix_inverse(value, matrix_dimension(value.matrix))
}

pub fn (value Matrix[B]) transpose[B]() Matrix[B] {
	return matrix_transpose(value, matrix_dimension(value.matrix))
}

pub fn (value Matrix[B]) mul[B](right Matrix[B]) Matrix[B] {
	return matrix_mul(value, right, matrix_dimension(value.matrix))
}

// The helper infers the full matrix record before inspecting its storage.
// This avoids pinned V 0.5.2 nested receiver type inference failures.
pub fn matrix_mul_vector_fixed[M, V](value M, vector V) V {
	dimension := matrix_dimension(value.matrix)
	$if V.unaliased_typ is $array_fixed {
		component := vector[0]
		$if component is f32 {
			if vector.len != dimension { panic('Matrix.mul_vector requires N components') }
			return matrix_mul_vector(value, vector, dimension)
		} $else {
			$compile_error('matrix_mul_vector_fixed requires f32 components')
		}
	} $else {
		$compile_error('matrix_mul_vector_fixed requires an inline fixed array')
	}
}

// Receiver adapter keeps the fixed vector's concrete V type and inline storage.
pub fn (value Matrix[B]) mul_vector[B, V](vector V) V {
	return matrix_mul_vector_fixed(value, vector)
}
