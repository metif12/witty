module zigimg

import math

// Locked src/simd.zig's array/vector helpers. B names the inline output lane
// array, such as `type FourWords = [4]u16`. Arrays retain lane values rather
// than Zig's SIMD ABI. Source comptime length is a checked runtime argument;
// zero selects every lane. The permutation retains the native ARM/non-AVX2
// source branch; the AVX2 instruction's masked indexing is not represented.
fn simd_array_count[B](value B) int {
	$if B.unaliased_typ is $array_fixed {
		return value.len
	} $else {
		$compile_error('SIMD output requires an inline fixed array')
	}
}

fn simd_lane_count[B](value B) int {
	capacity := simd_array_count(value)
	simd_check_component(value[0])
	return capacity
}

fn simd_check_width[D, S]() {
	$if sizeof(S) == 8 {
		$if sizeof(D) < 8 { $compile_error('SIMD assignment cannot narrow lanes') }
	} $else $if sizeof(S) == 4 {
		$if sizeof(D) < 4 { $compile_error('SIMD assignment cannot narrow lanes') }
	} $else $if sizeof(S) == 2 {
		$if sizeof(D) < 2 { $compile_error('SIMD assignment cannot narrow lanes') }
	}
}

fn simd_check_unsigned_signed_width[D, S]() {
	$if sizeof(S) == 8 {
		$if sizeof(D) <= 8 {
			$compile_error('SIMD unsigned-to-signed assignment requires a wider lane')
		}
	} $else $if sizeof(S) == 4 {
		$if sizeof(D) <= 4 {
			$compile_error('SIMD unsigned-to-signed assignment requires a wider lane')
		}
	} $else $if sizeof(S) == 2 {
		$if sizeof(D) <= 2 {
			$compile_error('SIMD unsigned-to-signed assignment requires a wider lane')
		}
	} $else $if sizeof(S) == 1 {
		$if sizeof(D) <= 1 {
			$compile_error('SIMD unsigned-to-signed assignment requires a wider lane')
		}
	}
}

fn simd_check_component[D](value D) {
	$if D.indirections > 0 || ((int(D.unaliased_typ) >> 16) & 0xff) > 0 {
		$compile_error('SIMD numeric output cannot use pointer lanes')
	} $else $if D.unaliased_typ is $int || D.unaliased_typ is $float {
		_ = value
	} $else {
		$compile_error('SIMD lanes require native integer or floating point elements')
	}
}

fn simd_check_assignment[D, S](target []D, source []S) {
	_ = target
	_ = source
	// `.unaliased_typ is $pointer` loses the pointer flag in this V version.
	// Its encoded indirection bits also identify aliases of pointers.
	$if ((int(D.unaliased_typ) >> 16) & 0xff) > 0 || ((int(S.unaliased_typ) >> 16) & 0xff) > 0 {
		_ = 0
	} $else $if D.unaliased_typ is bool {
		$if S.unaliased_typ is bool {
			_ = 0
		} $else {
			$compile_error('SIMD assignment requires boolean input for boolean lanes')
		}
	} $else $if D.unaliased_typ is $float {
		$if S.unaliased_typ is $float {
			simd_check_width[D, S]()
		} $else {
			$compile_error('SIMD assignment requires explicit integer-to-float conversion')
		}
	} $else $if D.unaliased_typ is $int {
		$if S.unaliased_typ is $int {
			$if D.unaliased_typ is u8 || D.unaliased_typ is u16 || D.unaliased_typ is u32
				|| D.unaliased_typ is u64 || D.unaliased_typ is uint {
				$if S.unaliased_typ is u8 || S.unaliased_typ is u16 || S.unaliased_typ is u32
					|| S.unaliased_typ is u64 || S.unaliased_typ is uint {
					simd_check_width[D, S]()
				} $else {
					$compile_error('SIMD assignment cannot assign signed lanes to unsigned lanes')
				}
			} $else {
				$if S.unaliased_typ is u8 || S.unaliased_typ is u16 || S.unaliased_typ is u32
					|| S.unaliased_typ is u64 || S.unaliased_typ is uint {
					simd_check_unsigned_signed_width[D, S]()
				} $else {
					simd_check_width[D, S]()
				}
			}
		} $else {
			$compile_error('SIMD assignment requires explicit float-to-integer conversion')
		}
	}
}

@[direct_array_access]
pub fn simd_load[B, S](source []S, length u32) B {
	mut result := B{}
	capacity := simd_lane_count(result)
	simd_check_assignment(result[..], source)
	count := if length == 0 { u32(capacity) } else { length }
	for index := u32(0); index < count; index++ {
		if index >= u32(capacity) || index >= u32(source.len) { panic('index out of bounds') }
		result[int(index)] = source[int(index)]
	}
	return result
}

fn simd_component_width[D](value D) int {
	_ = value
	return int(sizeof(D))
}

@[direct_array_access]
pub fn simd_load_bytes[B](source []u8, length u32) B {
	mut result := B{}
	capacity := simd_lane_count(result)
	stride := simd_component_width(result[0])
	if source.len % stride != 0 { panic('exact division produced remainder') }
	count := if length == 0 { u32(capacity) } else { length }
	for index := u32(0); index < count; index++ {
		if index >= u32(capacity) || uint(index) >= uint(source.len / stride) {
			panic('index out of bounds')
		}
		unsafe { vmemcpy(&result[int(index)], &source[int(index) * stride], stride) }
	}
	return result
}

@[direct_array_access]
pub fn simd_store[D, B](mut destination []D, value B, length u32) {
	capacity := simd_array_count(value)
	simd_check_assignment(destination, value[..])
	count := if length == 0 { u32(capacity) } else { length }
	for index := u32(0); index < count; index++ {
		if index >= u32(capacity) || index >= u32(destination.len) { panic('index out of bounds') }
		destination[int(index)] = value[int(index)]
	}
}

fn simd_int_lane_to_float[D, S](value S, zero D) D {
	_ = zero
	$if D.unaliased_typ is f32 || D.unaliased_typ is f64 {
		$if S.unaliased_typ is $int {
			return D(value)
		} $else {
			$compile_error('simd_int_to_float requires integer input lanes')
		}
	} $else {
		$compile_error('simd_int_to_float requires floating point output lanes')
	}
}

fn simd_float_lane_to_int[D, S](value S, zero D) D {
	_ = zero
	$if D.unaliased_typ is $int {
		$if S.unaliased_typ is f32 || S.unaliased_typ is f64 {
			number := math.trunc(f64(value))
			if number != number {
				$if arm64 {
					// Pinned Zig/ARM64's scalar float cast returns zero for NaN.
					return D(0)
				} $else {
					panic('unverified SIMD NaN float cast on this CPU')
				}
			}
			width := int(sizeof(D)) * 8
			$if D.unaliased_typ is u8 || D.unaliased_typ is u16 || D.unaliased_typ is u32
				|| D.unaliased_typ is u64 || D.unaliased_typ is uint {
				upper := if width == 64 {
					f64(18446744073709551616.0)
				} else {
					f64(u64(1) << width)
				}
				if number < 0 || number >= upper {
					panic('integer part of floating point value out of bounds')
				}
			} $else {
				upper := f64(u64(1) << (width - 1))
				if number < -upper || number >= upper {
					panic('integer part of floating point value out of bounds')
				}
			}
			return D(value)
		} $else {
			$compile_error('simd_float_to_int requires floating point input lanes')
		}
	} $else {
		$compile_error('simd_float_to_int requires integer output lanes')
	}
}

fn simd_check_pointer_depth[S]() {
	$if S.indirections != 1 && ((int(S.unaliased_typ) >> 16) & 0xff) != 1 {
		$compile_error('SIMD conversion requires a single pointer indirection')
	}
}

// Pinned V does not index aliases of scalar pointers directly. Normalize
// their native pointee types before reading; array pointers retain their shape.
fn simd_int_pointer_lane[D, P](source P, index int, zero D) D {
	$if P.indirections > 0 {
		return simd_int_lane_to_float(unsafe { source[index] }, zero)
	} $else {
		mut underlying := $zero(P.unaliased_typ)
		unsafe { vmemcpy(&underlying, &source, int(sizeof(P))) }
		return simd_int_pointer_lane(underlying, index, zero)
	}
}

fn simd_float_pointer_lane[D, P](source P, index int, zero D) D {
	$if P.indirections > 0 {
		return simd_float_lane_to_int(unsafe { source[index] }, zero)
	} $else {
		mut underlying := $zero(P.unaliased_typ)
		unsafe { vmemcpy(&underlying, &source, int(sizeof(P))) }
		return simd_float_pointer_lane(underlying, index, zero)
	}
}

@[direct_array_access]
pub fn simd_int_to_float[B, S](source S) B {
	mut result := B{}
	capacity := simd_lane_count(result)
	$if S.unaliased_typ is $array {
		$if S.indirections > 0 || ((int(S.unaliased_typ) >> 16) & 0xff) > 0 {
			simd_check_pointer_depth[S]()
			$if S.unaliased_typ is $array_fixed {
				_ = 0
			} $else {
				$compile_error('SIMD conversion does not index pointers to slices')
			}
			for index in 0 .. capacity {
				if index >= source.len { panic('index out of bounds') }
				result[index] = simd_int_lane_to_float(unsafe { (*source)[index] }, result[index])
			}
		} $else {
			for index in 0 .. capacity {
				if index >= source.len { panic('index out of bounds') }
				result[index] = simd_int_lane_to_float(source[index], result[index])
			}
		}
	} $else $if S.indirections > 0 || ((int(S.unaliased_typ) >> 16) & 0xff) > 0 {
		simd_check_pointer_depth[S]()
		for index in 0 .. capacity {
			result[index] = simd_int_pointer_lane(source, index, result[index])
		}
	} $else {
		$compile_error('simd_int_to_float requires array or pointer input lanes')
	}
	return result
}

@[direct_array_access]
pub fn simd_float_to_int[B, S](source S) B {
	mut result := B{}
	capacity := simd_lane_count(result)
	$if S.unaliased_typ is $array {
		$if S.indirections > 0 || ((int(S.unaliased_typ) >> 16) & 0xff) > 0 {
			simd_check_pointer_depth[S]()
			$if S.unaliased_typ is $array_fixed {
				_ = 0
			} $else {
				$compile_error('SIMD conversion does not index pointers to slices')
			}
			for index in 0 .. capacity {
				if index >= source.len { panic('index out of bounds') }
				result[index] = simd_float_lane_to_int(unsafe { (*source)[index] }, result[index])
			}
		} $else {
			for index in 0 .. capacity {
				if index >= source.len { panic('index out of bounds') }
				result[index] = simd_float_lane_to_int(source[index], result[index])
			}
		}
	} $else $if S.indirections > 0 || ((int(S.unaliased_typ) >> 16) & 0xff) > 0 {
		simd_check_pointer_depth[S]()
		for index in 0 .. capacity {
			result[index] = simd_float_pointer_lane(source, index, result[index])
		}
	} $else {
		$compile_error('simd_float_to_int requires array or pointer input lanes')
	}
	return result
}

pub type SimdI32x8 = [8]int

pub fn simd_vpermd(value [8]int, mask [8]int) SimdI32x8 {
	mut result := SimdI32x8{}
	for index in 0 .. 8 {
		lane := u32(mask[index])
		if lane >= 8 { panic('index out of bounds') }
		result[index] = value[int(lane)]
	}
	return result
}
