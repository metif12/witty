module main

import encoding.hex
import os
import zigimg

fn values[T](text string) []T {
	raw := hex.decode(text) or { panic(err) }
	mut result := []T{len: raw.len / int(sizeof(T))}
	if raw.len > 0 { unsafe { vmemcpy(result.data, raw.data, raw.len) } }
	return result
}

fn fixed_hex[B](value B) string {
	return unsafe { (&u8(&value[0])).vbytes(int(sizeof(B))) }.hex()
}

fn slice_hex[T](value []T) string {
	return unsafe { (&u8(value.data)).vbytes(value.len * int(sizeof(T))) }.hex()
}

fn operations[B, T](parts []string) string {
	length := parts[3].u32()
	match parts[0] {
		'L' {
			return fixed_hex(zigimg.simd_load[B, T](values[T](parts[4]), length))
		}
		'B' {
			raw := hex.decode(parts[4]) or { panic(err) }
			return fixed_hex(zigimg.simd_load_bytes[B](raw, length))
		}
		'S' {
			input := zigimg.simd_load[B, T](values[T](parts[4]), 0)
			mut destination := values[T](parts[5])
			zigimg.simd_store[T, B](mut destination, input, length)
			return slice_hex(destination)
		}
		else {
			panic('unknown operation')
		}
	}
}

fn to_float[B, S](text string) string {
	return fixed_hex(zigimg.simd_int_to_float[B, []S](values[S](text)))
}

fn to_int[B, S](text string) string {
	return fixed_hex(zigimg.simd_float_to_int[B, []S](values[S](text)))
}

type Lane1U8 = [1]u8
type Lane1I8 = [1]i8
type Lane1U16 = [1]u16
type Lane1I16 = [1]i16
type Lane1U32 = [1]u32
type Lane1I32 = [1]int
type Lane1U64 = [1]u64
type Lane1I64 = [1]i64
type Lane1Usize = [1]usize
type Lane1Isize = [1]isize
type Lane1F32 = [1]f32
type Lane1F64 = [1]f64
type Lane2U8 = [2]u8
type Lane2I8 = [2]i8
type Lane2U16 = [2]u16
type Lane2I16 = [2]i16
type Lane2U32 = [2]u32
type Lane2I32 = [2]int
type Lane2U64 = [2]u64
type Lane2I64 = [2]i64
type Lane2Usize = [2]usize
type Lane2Isize = [2]isize
type Lane2F32 = [2]f32
type Lane2F64 = [2]f64
type Lane4U8 = [4]u8
type Lane4I8 = [4]i8
type Lane4U16 = [4]u16
type Lane4I16 = [4]i16
type Lane4U32 = [4]u32
type Lane4I32 = [4]int
type Lane4U64 = [4]u64
type Lane4I64 = [4]i64
type Lane4Usize = [4]usize
type Lane4Isize = [4]isize
type Lane4F32 = [4]f32
type Lane4F64 = [4]f64
type Lane8U8 = [8]u8
type Lane8I8 = [8]i8
type Lane8U16 = [8]u16
type Lane8I16 = [8]i16
type Lane8U32 = [8]u32
type Lane8I32 = [8]int
type Lane8U64 = [8]u64
type Lane8I64 = [8]i64
type Lane8Usize = [8]usize
type Lane8Isize = [8]isize
type Lane8F32 = [8]f32
type Lane8F64 = [8]f64
type Lane16U8 = [16]u8
type Lane16I8 = [16]i8
type Lane16U16 = [16]u16
type Lane16I16 = [16]i16
type Lane16U32 = [16]u32
type Lane16I32 = [16]int
type Lane16U64 = [16]u64
type Lane16I64 = [16]i64
type Lane16Usize = [16]usize
type Lane16Isize = [16]isize
type Lane16F32 = [16]f32
type Lane16F64 = [16]f64

fn record(parts []string) string {
	n := parts[2].int()
	if n == 1 {
		if parts[0] == 'I' {
			match parts[3] {
				'u8' {
					if parts[1] == 'f32' { return to_float[Lane1F32, u8](parts[4]) }
					return to_float[Lane1F64, u8](parts[4])
				}
				'i8' {
					if parts[1] == 'f32' { return to_float[Lane1F32, i8](parts[4]) }
					return to_float[Lane1F64, i8](parts[4])
				}
				'u16' {
					if parts[1] == 'f32' { return to_float[Lane1F32, u16](parts[4]) }
					return to_float[Lane1F64, u16](parts[4])
				}
				'i16' {
					if parts[1] == 'f32' { return to_float[Lane1F32, i16](parts[4]) }
					return to_float[Lane1F64, i16](parts[4])
				}
				'u32' {
					if parts[1] == 'f32' { return to_float[Lane1F32, u32](parts[4]) }
					return to_float[Lane1F64, u32](parts[4])
				}
				'i32' {
					if parts[1] == 'f32' { return to_float[Lane1F32, int](parts[4]) }
					return to_float[Lane1F64, int](parts[4])
				}
				'u64' {
					if parts[1] == 'f32' { return to_float[Lane1F32, u64](parts[4]) }
					return to_float[Lane1F64, u64](parts[4])
				}
				'i64' {
					if parts[1] == 'f32' { return to_float[Lane1F32, i64](parts[4]) }
					return to_float[Lane1F64, i64](parts[4])
				}
				'usize' {
					if parts[1] == 'f32' { return to_float[Lane1F32, usize](parts[4]) }
					return to_float[Lane1F64, usize](parts[4])
				}
				'isize' {
					if parts[1] == 'f32' { return to_float[Lane1F32, isize](parts[4]) }
					return to_float[Lane1F64, isize](parts[4])
				}
				else {
					panic('unknown input integer')
				}
			}
		} else if parts[0] == 'F' {
			match parts[1] {
				'u8' {
					if parts[3] == 'f32' { return to_int[Lane1U8, f32](parts[4]) }
					return to_int[Lane1U8, f64](parts[4])
				}
				'i8' {
					if parts[3] == 'f32' { return to_int[Lane1I8, f32](parts[4]) }
					return to_int[Lane1I8, f64](parts[4])
				}
				'u16' {
					if parts[3] == 'f32' { return to_int[Lane1U16, f32](parts[4]) }
					return to_int[Lane1U16, f64](parts[4])
				}
				'i16' {
					if parts[3] == 'f32' { return to_int[Lane1I16, f32](parts[4]) }
					return to_int[Lane1I16, f64](parts[4])
				}
				'u32' {
					if parts[3] == 'f32' { return to_int[Lane1U32, f32](parts[4]) }
					return to_int[Lane1U32, f64](parts[4])
				}
				'i32' {
					if parts[3] == 'f32' { return to_int[Lane1I32, f32](parts[4]) }
					return to_int[Lane1I32, f64](parts[4])
				}
				'u64' {
					if parts[3] == 'f32' { return to_int[Lane1U64, f32](parts[4]) }
					return to_int[Lane1U64, f64](parts[4])
				}
				'i64' {
					if parts[3] == 'f32' { return to_int[Lane1I64, f32](parts[4]) }
					return to_int[Lane1I64, f64](parts[4])
				}
				'usize' {
					if parts[3] == 'f32' { return to_int[Lane1Usize, f32](parts[4]) }
					return to_int[Lane1Usize, f64](parts[4])
				}
				'isize' {
					if parts[3] == 'f32' { return to_int[Lane1Isize, f32](parts[4]) }
					return to_int[Lane1Isize, f64](parts[4])
				}
				else {
					panic('unknown output integer')
				}
			}
		} else {
			match parts[1] {
				'u8' { return operations[Lane1U8, u8](parts) }
				'i8' { return operations[Lane1I8, i8](parts) }
				'u16' { return operations[Lane1U16, u16](parts) }
				'i16' { return operations[Lane1I16, i16](parts) }
				'u32' { return operations[Lane1U32, u32](parts) }
				'i32' { return operations[Lane1I32, int](parts) }
				'u64' { return operations[Lane1U64, u64](parts) }
				'i64' { return operations[Lane1I64, i64](parts) }
				'usize' { return operations[Lane1Usize, usize](parts) }
				'isize' { return operations[Lane1Isize, isize](parts) }
				'f32' { return operations[Lane1F32, f32](parts) }
				'f64' { return operations[Lane1F64, f64](parts) }
				else { panic('unknown type') }
			}
		}
	}
	if n == 2 {
		if parts[0] == 'I' {
			match parts[3] {
				'u8' {
					if parts[1] == 'f32' { return to_float[Lane2F32, u8](parts[4]) }
					return to_float[Lane2F64, u8](parts[4])
				}
				'i8' {
					if parts[1] == 'f32' { return to_float[Lane2F32, i8](parts[4]) }
					return to_float[Lane2F64, i8](parts[4])
				}
				'u16' {
					if parts[1] == 'f32' { return to_float[Lane2F32, u16](parts[4]) }
					return to_float[Lane2F64, u16](parts[4])
				}
				'i16' {
					if parts[1] == 'f32' { return to_float[Lane2F32, i16](parts[4]) }
					return to_float[Lane2F64, i16](parts[4])
				}
				'u32' {
					if parts[1] == 'f32' { return to_float[Lane2F32, u32](parts[4]) }
					return to_float[Lane2F64, u32](parts[4])
				}
				'i32' {
					if parts[1] == 'f32' { return to_float[Lane2F32, int](parts[4]) }
					return to_float[Lane2F64, int](parts[4])
				}
				'u64' {
					if parts[1] == 'f32' { return to_float[Lane2F32, u64](parts[4]) }
					return to_float[Lane2F64, u64](parts[4])
				}
				'i64' {
					if parts[1] == 'f32' { return to_float[Lane2F32, i64](parts[4]) }
					return to_float[Lane2F64, i64](parts[4])
				}
				'usize' {
					if parts[1] == 'f32' { return to_float[Lane2F32, usize](parts[4]) }
					return to_float[Lane2F64, usize](parts[4])
				}
				'isize' {
					if parts[1] == 'f32' { return to_float[Lane2F32, isize](parts[4]) }
					return to_float[Lane2F64, isize](parts[4])
				}
				else {
					panic('unknown input integer')
				}
			}
		} else if parts[0] == 'F' {
			match parts[1] {
				'u8' {
					if parts[3] == 'f32' { return to_int[Lane2U8, f32](parts[4]) }
					return to_int[Lane2U8, f64](parts[4])
				}
				'i8' {
					if parts[3] == 'f32' { return to_int[Lane2I8, f32](parts[4]) }
					return to_int[Lane2I8, f64](parts[4])
				}
				'u16' {
					if parts[3] == 'f32' { return to_int[Lane2U16, f32](parts[4]) }
					return to_int[Lane2U16, f64](parts[4])
				}
				'i16' {
					if parts[3] == 'f32' { return to_int[Lane2I16, f32](parts[4]) }
					return to_int[Lane2I16, f64](parts[4])
				}
				'u32' {
					if parts[3] == 'f32' { return to_int[Lane2U32, f32](parts[4]) }
					return to_int[Lane2U32, f64](parts[4])
				}
				'i32' {
					if parts[3] == 'f32' { return to_int[Lane2I32, f32](parts[4]) }
					return to_int[Lane2I32, f64](parts[4])
				}
				'u64' {
					if parts[3] == 'f32' { return to_int[Lane2U64, f32](parts[4]) }
					return to_int[Lane2U64, f64](parts[4])
				}
				'i64' {
					if parts[3] == 'f32' { return to_int[Lane2I64, f32](parts[4]) }
					return to_int[Lane2I64, f64](parts[4])
				}
				'usize' {
					if parts[3] == 'f32' { return to_int[Lane2Usize, f32](parts[4]) }
					return to_int[Lane2Usize, f64](parts[4])
				}
				'isize' {
					if parts[3] == 'f32' { return to_int[Lane2Isize, f32](parts[4]) }
					return to_int[Lane2Isize, f64](parts[4])
				}
				else {
					panic('unknown output integer')
				}
			}
		} else {
			match parts[1] {
				'u8' { return operations[Lane2U8, u8](parts) }
				'i8' { return operations[Lane2I8, i8](parts) }
				'u16' { return operations[Lane2U16, u16](parts) }
				'i16' { return operations[Lane2I16, i16](parts) }
				'u32' { return operations[Lane2U32, u32](parts) }
				'i32' { return operations[Lane2I32, int](parts) }
				'u64' { return operations[Lane2U64, u64](parts) }
				'i64' { return operations[Lane2I64, i64](parts) }
				'usize' { return operations[Lane2Usize, usize](parts) }
				'isize' { return operations[Lane2Isize, isize](parts) }
				'f32' { return operations[Lane2F32, f32](parts) }
				'f64' { return operations[Lane2F64, f64](parts) }
				else { panic('unknown type') }
			}
		}
	}
	if n == 4 {
		if parts[0] == 'I' {
			match parts[3] {
				'u8' {
					if parts[1] == 'f32' { return to_float[Lane4F32, u8](parts[4]) }
					return to_float[Lane4F64, u8](parts[4])
				}
				'i8' {
					if parts[1] == 'f32' { return to_float[Lane4F32, i8](parts[4]) }
					return to_float[Lane4F64, i8](parts[4])
				}
				'u16' {
					if parts[1] == 'f32' { return to_float[Lane4F32, u16](parts[4]) }
					return to_float[Lane4F64, u16](parts[4])
				}
				'i16' {
					if parts[1] == 'f32' { return to_float[Lane4F32, i16](parts[4]) }
					return to_float[Lane4F64, i16](parts[4])
				}
				'u32' {
					if parts[1] == 'f32' { return to_float[Lane4F32, u32](parts[4]) }
					return to_float[Lane4F64, u32](parts[4])
				}
				'i32' {
					if parts[1] == 'f32' { return to_float[Lane4F32, int](parts[4]) }
					return to_float[Lane4F64, int](parts[4])
				}
				'u64' {
					if parts[1] == 'f32' { return to_float[Lane4F32, u64](parts[4]) }
					return to_float[Lane4F64, u64](parts[4])
				}
				'i64' {
					if parts[1] == 'f32' { return to_float[Lane4F32, i64](parts[4]) }
					return to_float[Lane4F64, i64](parts[4])
				}
				'usize' {
					if parts[1] == 'f32' { return to_float[Lane4F32, usize](parts[4]) }
					return to_float[Lane4F64, usize](parts[4])
				}
				'isize' {
					if parts[1] == 'f32' { return to_float[Lane4F32, isize](parts[4]) }
					return to_float[Lane4F64, isize](parts[4])
				}
				else {
					panic('unknown input integer')
				}
			}
		} else if parts[0] == 'F' {
			match parts[1] {
				'u8' {
					if parts[3] == 'f32' { return to_int[Lane4U8, f32](parts[4]) }
					return to_int[Lane4U8, f64](parts[4])
				}
				'i8' {
					if parts[3] == 'f32' { return to_int[Lane4I8, f32](parts[4]) }
					return to_int[Lane4I8, f64](parts[4])
				}
				'u16' {
					if parts[3] == 'f32' { return to_int[Lane4U16, f32](parts[4]) }
					return to_int[Lane4U16, f64](parts[4])
				}
				'i16' {
					if parts[3] == 'f32' { return to_int[Lane4I16, f32](parts[4]) }
					return to_int[Lane4I16, f64](parts[4])
				}
				'u32' {
					if parts[3] == 'f32' { return to_int[Lane4U32, f32](parts[4]) }
					return to_int[Lane4U32, f64](parts[4])
				}
				'i32' {
					if parts[3] == 'f32' { return to_int[Lane4I32, f32](parts[4]) }
					return to_int[Lane4I32, f64](parts[4])
				}
				'u64' {
					if parts[3] == 'f32' { return to_int[Lane4U64, f32](parts[4]) }
					return to_int[Lane4U64, f64](parts[4])
				}
				'i64' {
					if parts[3] == 'f32' { return to_int[Lane4I64, f32](parts[4]) }
					return to_int[Lane4I64, f64](parts[4])
				}
				'usize' {
					if parts[3] == 'f32' { return to_int[Lane4Usize, f32](parts[4]) }
					return to_int[Lane4Usize, f64](parts[4])
				}
				'isize' {
					if parts[3] == 'f32' { return to_int[Lane4Isize, f32](parts[4]) }
					return to_int[Lane4Isize, f64](parts[4])
				}
				else {
					panic('unknown output integer')
				}
			}
		} else {
			match parts[1] {
				'u8' { return operations[Lane4U8, u8](parts) }
				'i8' { return operations[Lane4I8, i8](parts) }
				'u16' { return operations[Lane4U16, u16](parts) }
				'i16' { return operations[Lane4I16, i16](parts) }
				'u32' { return operations[Lane4U32, u32](parts) }
				'i32' { return operations[Lane4I32, int](parts) }
				'u64' { return operations[Lane4U64, u64](parts) }
				'i64' { return operations[Lane4I64, i64](parts) }
				'usize' { return operations[Lane4Usize, usize](parts) }
				'isize' { return operations[Lane4Isize, isize](parts) }
				'f32' { return operations[Lane4F32, f32](parts) }
				'f64' { return operations[Lane4F64, f64](parts) }
				else { panic('unknown type') }
			}
		}
	}
	if n == 8 {
		if parts[0] == 'I' {
			match parts[3] {
				'u8' {
					if parts[1] == 'f32' { return to_float[Lane8F32, u8](parts[4]) }
					return to_float[Lane8F64, u8](parts[4])
				}
				'i8' {
					if parts[1] == 'f32' { return to_float[Lane8F32, i8](parts[4]) }
					return to_float[Lane8F64, i8](parts[4])
				}
				'u16' {
					if parts[1] == 'f32' { return to_float[Lane8F32, u16](parts[4]) }
					return to_float[Lane8F64, u16](parts[4])
				}
				'i16' {
					if parts[1] == 'f32' { return to_float[Lane8F32, i16](parts[4]) }
					return to_float[Lane8F64, i16](parts[4])
				}
				'u32' {
					if parts[1] == 'f32' { return to_float[Lane8F32, u32](parts[4]) }
					return to_float[Lane8F64, u32](parts[4])
				}
				'i32' {
					if parts[1] == 'f32' { return to_float[Lane8F32, int](parts[4]) }
					return to_float[Lane8F64, int](parts[4])
				}
				'u64' {
					if parts[1] == 'f32' { return to_float[Lane8F32, u64](parts[4]) }
					return to_float[Lane8F64, u64](parts[4])
				}
				'i64' {
					if parts[1] == 'f32' { return to_float[Lane8F32, i64](parts[4]) }
					return to_float[Lane8F64, i64](parts[4])
				}
				'usize' {
					if parts[1] == 'f32' { return to_float[Lane8F32, usize](parts[4]) }
					return to_float[Lane8F64, usize](parts[4])
				}
				'isize' {
					if parts[1] == 'f32' { return to_float[Lane8F32, isize](parts[4]) }
					return to_float[Lane8F64, isize](parts[4])
				}
				else {
					panic('unknown input integer')
				}
			}
		} else if parts[0] == 'F' {
			match parts[1] {
				'u8' {
					if parts[3] == 'f32' { return to_int[Lane8U8, f32](parts[4]) }
					return to_int[Lane8U8, f64](parts[4])
				}
				'i8' {
					if parts[3] == 'f32' { return to_int[Lane8I8, f32](parts[4]) }
					return to_int[Lane8I8, f64](parts[4])
				}
				'u16' {
					if parts[3] == 'f32' { return to_int[Lane8U16, f32](parts[4]) }
					return to_int[Lane8U16, f64](parts[4])
				}
				'i16' {
					if parts[3] == 'f32' { return to_int[Lane8I16, f32](parts[4]) }
					return to_int[Lane8I16, f64](parts[4])
				}
				'u32' {
					if parts[3] == 'f32' { return to_int[Lane8U32, f32](parts[4]) }
					return to_int[Lane8U32, f64](parts[4])
				}
				'i32' {
					if parts[3] == 'f32' { return to_int[Lane8I32, f32](parts[4]) }
					return to_int[Lane8I32, f64](parts[4])
				}
				'u64' {
					if parts[3] == 'f32' { return to_int[Lane8U64, f32](parts[4]) }
					return to_int[Lane8U64, f64](parts[4])
				}
				'i64' {
					if parts[3] == 'f32' { return to_int[Lane8I64, f32](parts[4]) }
					return to_int[Lane8I64, f64](parts[4])
				}
				'usize' {
					if parts[3] == 'f32' { return to_int[Lane8Usize, f32](parts[4]) }
					return to_int[Lane8Usize, f64](parts[4])
				}
				'isize' {
					if parts[3] == 'f32' { return to_int[Lane8Isize, f32](parts[4]) }
					return to_int[Lane8Isize, f64](parts[4])
				}
				else {
					panic('unknown output integer')
				}
			}
		} else {
			match parts[1] {
				'u8' { return operations[Lane8U8, u8](parts) }
				'i8' { return operations[Lane8I8, i8](parts) }
				'u16' { return operations[Lane8U16, u16](parts) }
				'i16' { return operations[Lane8I16, i16](parts) }
				'u32' { return operations[Lane8U32, u32](parts) }
				'i32' { return operations[Lane8I32, int](parts) }
				'u64' { return operations[Lane8U64, u64](parts) }
				'i64' { return operations[Lane8I64, i64](parts) }
				'usize' { return operations[Lane8Usize, usize](parts) }
				'isize' { return operations[Lane8Isize, isize](parts) }
				'f32' { return operations[Lane8F32, f32](parts) }
				'f64' { return operations[Lane8F64, f64](parts) }
				else { panic('unknown type') }
			}
		}
	}
	if n == 16 {
		if parts[0] == 'I' {
			match parts[3] {
				'u8' {
					if parts[1] == 'f32' { return to_float[Lane16F32, u8](parts[4]) }
					return to_float[Lane16F64, u8](parts[4])
				}
				'i8' {
					if parts[1] == 'f32' { return to_float[Lane16F32, i8](parts[4]) }
					return to_float[Lane16F64, i8](parts[4])
				}
				'u16' {
					if parts[1] == 'f32' { return to_float[Lane16F32, u16](parts[4]) }
					return to_float[Lane16F64, u16](parts[4])
				}
				'i16' {
					if parts[1] == 'f32' { return to_float[Lane16F32, i16](parts[4]) }
					return to_float[Lane16F64, i16](parts[4])
				}
				'u32' {
					if parts[1] == 'f32' { return to_float[Lane16F32, u32](parts[4]) }
					return to_float[Lane16F64, u32](parts[4])
				}
				'i32' {
					if parts[1] == 'f32' { return to_float[Lane16F32, int](parts[4]) }
					return to_float[Lane16F64, int](parts[4])
				}
				'u64' {
					if parts[1] == 'f32' { return to_float[Lane16F32, u64](parts[4]) }
					return to_float[Lane16F64, u64](parts[4])
				}
				'i64' {
					if parts[1] == 'f32' { return to_float[Lane16F32, i64](parts[4]) }
					return to_float[Lane16F64, i64](parts[4])
				}
				'usize' {
					if parts[1] == 'f32' { return to_float[Lane16F32, usize](parts[4]) }
					return to_float[Lane16F64, usize](parts[4])
				}
				'isize' {
					if parts[1] == 'f32' { return to_float[Lane16F32, isize](parts[4]) }
					return to_float[Lane16F64, isize](parts[4])
				}
				else {
					panic('unknown input integer')
				}
			}
		} else if parts[0] == 'F' {
			match parts[1] {
				'u8' {
					if parts[3] == 'f32' { return to_int[Lane16U8, f32](parts[4]) }
					return to_int[Lane16U8, f64](parts[4])
				}
				'i8' {
					if parts[3] == 'f32' { return to_int[Lane16I8, f32](parts[4]) }
					return to_int[Lane16I8, f64](parts[4])
				}
				'u16' {
					if parts[3] == 'f32' { return to_int[Lane16U16, f32](parts[4]) }
					return to_int[Lane16U16, f64](parts[4])
				}
				'i16' {
					if parts[3] == 'f32' { return to_int[Lane16I16, f32](parts[4]) }
					return to_int[Lane16I16, f64](parts[4])
				}
				'u32' {
					if parts[3] == 'f32' { return to_int[Lane16U32, f32](parts[4]) }
					return to_int[Lane16U32, f64](parts[4])
				}
				'i32' {
					if parts[3] == 'f32' { return to_int[Lane16I32, f32](parts[4]) }
					return to_int[Lane16I32, f64](parts[4])
				}
				'u64' {
					if parts[3] == 'f32' { return to_int[Lane16U64, f32](parts[4]) }
					return to_int[Lane16U64, f64](parts[4])
				}
				'i64' {
					if parts[3] == 'f32' { return to_int[Lane16I64, f32](parts[4]) }
					return to_int[Lane16I64, f64](parts[4])
				}
				'usize' {
					if parts[3] == 'f32' { return to_int[Lane16Usize, f32](parts[4]) }
					return to_int[Lane16Usize, f64](parts[4])
				}
				'isize' {
					if parts[3] == 'f32' { return to_int[Lane16Isize, f32](parts[4]) }
					return to_int[Lane16Isize, f64](parts[4])
				}
				else {
					panic('unknown output integer')
				}
			}
		} else {
			match parts[1] {
				'u8' { return operations[Lane16U8, u8](parts) }
				'i8' { return operations[Lane16I8, i8](parts) }
				'u16' { return operations[Lane16U16, u16](parts) }
				'i16' { return operations[Lane16I16, i16](parts) }
				'u32' { return operations[Lane16U32, u32](parts) }
				'i32' { return operations[Lane16I32, int](parts) }
				'u64' { return operations[Lane16U64, u64](parts) }
				'i64' { return operations[Lane16I64, i64](parts) }
				'usize' { return operations[Lane16Usize, usize](parts) }
				'isize' { return operations[Lane16Isize, isize](parts) }
				'f32' { return operations[Lane16F32, f32](parts) }
				'f64' { return operations[Lane16F64, f64](parts) }
				else { panic('unknown type') }
			}
		}
	}
	panic('unknown lane count')
}

type AliasU16 = u16
type AliasI32 = int
type AliasUsize = usize
type AliasF32 = f32
type AliasF64 = f64
type AliasFourU16 = [4]AliasU16
type AliasFourI32 = [4]AliasI32
type AliasFourUsize = [4]AliasUsize
type AliasFourF32 = [4]AliasF32
type AliasFourF64 = [4]AliasF64

type AliasU8 = u8
type AliasFourU8 = [4]AliasU8
type AliasPointerU8 = &AliasU8
type AliasArrayPointerU8 = &AliasFourU8
type AliasI8 = i8
type AliasFourI8 = [4]AliasI8
type AliasPointerI8 = &AliasI8
type AliasArrayPointerI8 = &AliasFourI8
type AliasPointerU16 = &AliasU16
type AliasArrayPointerU16 = &AliasFourU16
type AliasI16 = i16
type AliasFourI16 = [4]AliasI16
type AliasPointerI16 = &AliasI16
type AliasArrayPointerI16 = &AliasFourI16
type AliasU32 = u32
type AliasFourU32 = [4]AliasU32
type AliasPointerU32 = &AliasU32
type AliasArrayPointerU32 = &AliasFourU32
type AliasPointerI32 = &AliasI32
type AliasArrayPointerI32 = &AliasFourI32
type AliasU64 = u64
type AliasFourU64 = [4]AliasU64
type AliasPointerU64 = &AliasU64
type AliasArrayPointerU64 = &AliasFourU64
type AliasI64 = i64
type AliasFourI64 = [4]AliasI64
type AliasPointerI64 = &AliasI64
type AliasArrayPointerI64 = &AliasFourI64
type AliasPointerUsize = &AliasUsize
type AliasArrayPointerUsize = &AliasFourUsize
type AliasIsize = isize
type AliasFourIsize = [4]AliasIsize
type AliasPointerIsize = &AliasIsize
type AliasArrayPointerIsize = &AliasFourIsize
type AliasPointerF32 = &AliasF32
type AliasArrayPointerF32 = &AliasFourF32
type AliasPointerF64 = &AliasF64
type AliasArrayPointerF64 = &AliasFourF64

fn aliases(parts []string) string {
	mut p := parts.clone()
	p[0] = parts[0][1..]
	if p[0] == 'I' {
		match p[3] {
			'u16' {
				if p[1] == 'f32' { return to_float[AliasFourF32, AliasU16](p[4]) }
				return to_float[AliasFourF64, AliasU16](p[4])
			}
			'i32' {
				if p[1] == 'f32' { return to_float[AliasFourF32, AliasI32](p[4]) }
				return to_float[AliasFourF64, AliasI32](p[4])
			}
			'usize' {
				if p[1] == 'f32' { return to_float[AliasFourF32, AliasUsize](p[4]) }
				return to_float[AliasFourF64, AliasUsize](p[4])
			}
			else {
				panic('unknown alias integer')
			}
		}
	} else if p[0] == 'F' {
		match p[1] {
			'u16' {
				if p[3] == 'f32' { return to_int[AliasFourU16, AliasF32](p[4]) }
				return to_int[AliasFourU16, AliasF64](p[4])
			}
			'i32' {
				if p[3] == 'f32' { return to_int[AliasFourI32, AliasF32](p[4]) }
				return to_int[AliasFourI32, AliasF64](p[4])
			}
			'usize' {
				if p[3] == 'f32' { return to_int[AliasFourUsize, AliasF32](p[4]) }
				return to_int[AliasFourUsize, AliasF64](p[4])
			}
			else {
				panic('unknown alias integer')
			}
		}
	} else {
		match p[1] {
			'u16' { return operations[AliasFourU16, AliasU16](p) }
			'i32' { return operations[AliasFourI32, AliasI32](p) }
			'usize' { return operations[AliasFourUsize, AliasUsize](p) }
			'f32' { return operations[AliasFourF32, AliasF32](p) }
			'f64' { return operations[AliasFourF64, AliasF64](p) }
			else { panic('unknown alias') }
		}
	}
}

fn pointer_to_float[B, A, S](text string, kind string) string {
	values_ := values[S](text)
	mut input := A{}
	for index in 0 .. 4 {
		input[index] = values_[index]
	}
	if kind == 'M' {
		return fixed_hex(zigimg.simd_int_to_float[B, &S](unsafe { &S(values_.data) }))
	}
	return fixed_hex(zigimg.simd_int_to_float[B, &A](&input))
}

fn pointer_to_int[B, A, S](text string, kind string) string {
	values_ := values[S](text)
	mut input := A{}
	for index in 0 .. 4 {
		input[index] = values_[index]
	}
	if kind == 'M' {
		return fixed_hex(zigimg.simd_float_to_int[B, &S](unsafe { &S(values_.data) }))
	}
	return fixed_hex(zigimg.simd_float_to_int[B, &A](&input))
}

fn pointers(p []string) string {
	kind := p[0][..1]
	if p[0][1..] == 'I' {
		match p[3] {
			'u8' {
				if p[1] == 'f32' { return pointer_to_float[Lane4F32, Lane4U8, u8](p[4], kind) }
				return pointer_to_float[Lane4F64, Lane4U8, u8](p[4], kind)
			}
			'i8' {
				if p[1] == 'f32' { return pointer_to_float[Lane4F32, Lane4I8, i8](p[4], kind) }
				return pointer_to_float[Lane4F64, Lane4I8, i8](p[4], kind)
			}
			'u16' {
				if p[1] == 'f32' { return pointer_to_float[Lane4F32, Lane4U16, u16](p[4], kind) }
				return pointer_to_float[Lane4F64, Lane4U16, u16](p[4], kind)
			}
			'i16' {
				if p[1] == 'f32' { return pointer_to_float[Lane4F32, Lane4I16, i16](p[4], kind) }
				return pointer_to_float[Lane4F64, Lane4I16, i16](p[4], kind)
			}
			'u32' {
				if p[1] == 'f32' { return pointer_to_float[Lane4F32, Lane4U32, u32](p[4], kind) }
				return pointer_to_float[Lane4F64, Lane4U32, u32](p[4], kind)
			}
			'i32' {
				if p[1] == 'f32' { return pointer_to_float[Lane4F32, Lane4I32, int](p[4], kind) }
				return pointer_to_float[Lane4F64, Lane4I32, int](p[4], kind)
			}
			'u64' {
				if p[1] == 'f32' { return pointer_to_float[Lane4F32, Lane4U64, u64](p[4], kind) }
				return pointer_to_float[Lane4F64, Lane4U64, u64](p[4], kind)
			}
			'i64' {
				if p[1] == 'f32' { return pointer_to_float[Lane4F32, Lane4I64, i64](p[4], kind) }
				return pointer_to_float[Lane4F64, Lane4I64, i64](p[4], kind)
			}
			'usize' {
				if p[1] == 'f32' {
					return pointer_to_float[Lane4F32, Lane4Usize, usize](p[4], kind)
				}
				return pointer_to_float[Lane4F64, Lane4Usize, usize](p[4], kind)
			}
			'isize' {
				if p[1] == 'f32' {
					return pointer_to_float[Lane4F32, Lane4Isize, isize](p[4], kind)
				}
				return pointer_to_float[Lane4F64, Lane4Isize, isize](p[4], kind)
			}
			else {
				panic('unknown pointer source')
			}
		}
	} else {
		match p[1] {
			'u8' {
				if p[3] == 'f32' { return pointer_to_int[Lane4U8, Lane4F32, f32](p[4], kind) }
				return pointer_to_int[Lane4U8, Lane4F64, f64](p[4], kind)
			}
			'i8' {
				if p[3] == 'f32' { return pointer_to_int[Lane4I8, Lane4F32, f32](p[4], kind) }
				return pointer_to_int[Lane4I8, Lane4F64, f64](p[4], kind)
			}
			'u16' {
				if p[3] == 'f32' { return pointer_to_int[Lane4U16, Lane4F32, f32](p[4], kind) }
				return pointer_to_int[Lane4U16, Lane4F64, f64](p[4], kind)
			}
			'i16' {
				if p[3] == 'f32' { return pointer_to_int[Lane4I16, Lane4F32, f32](p[4], kind) }
				return pointer_to_int[Lane4I16, Lane4F64, f64](p[4], kind)
			}
			'u32' {
				if p[3] == 'f32' { return pointer_to_int[Lane4U32, Lane4F32, f32](p[4], kind) }
				return pointer_to_int[Lane4U32, Lane4F64, f64](p[4], kind)
			}
			'i32' {
				if p[3] == 'f32' { return pointer_to_int[Lane4I32, Lane4F32, f32](p[4], kind) }
				return pointer_to_int[Lane4I32, Lane4F64, f64](p[4], kind)
			}
			'u64' {
				if p[3] == 'f32' { return pointer_to_int[Lane4U64, Lane4F32, f32](p[4], kind) }
				return pointer_to_int[Lane4U64, Lane4F64, f64](p[4], kind)
			}
			'i64' {
				if p[3] == 'f32' { return pointer_to_int[Lane4I64, Lane4F32, f32](p[4], kind) }
				return pointer_to_int[Lane4I64, Lane4F64, f64](p[4], kind)
			}
			'usize' {
				if p[3] == 'f32' { return pointer_to_int[Lane4Usize, Lane4F32, f32](p[4], kind) }
				return pointer_to_int[Lane4Usize, Lane4F64, f64](p[4], kind)
			}
			'isize' {
				if p[3] == 'f32' { return pointer_to_int[Lane4Isize, Lane4F32, f32](p[4], kind) }
				return pointer_to_int[Lane4Isize, Lane4F64, f64](p[4], kind)
			}
			else {
				panic('unknown pointer destination')
			}
		}
	}
}

fn widen[D, B, A, S](parts []string) string {
	input_ := values[S](parts[4])
	if parts[0].ends_with('L') { return fixed_hex(zigimg.simd_load[B, S](input_, 0)) }
	input := zigimg.simd_load[A, S](input_, 0)
	mut destination := []D{len: 6, init: D(9)}
	zigimg.simd_store[D, A](mut destination, input, 0)
	return slice_hex(destination)
}

fn widening(parts []string) string {
	if parts[1] == 'u16' && parts[3] == 'u8' {
		if parts[0].starts_with('A') {
			return widen[AliasU16, AliasFourU16, AliasFourU8, AliasU8](parts)
		}
		return widen[u16, Lane4U16, Lane4U8, u8](parts)
	}
	if parts[1] == 'i16' && parts[3] == 'u8' {
		if parts[0].starts_with('A') {
			return widen[AliasI16, AliasFourI16, AliasFourU8, AliasU8](parts)
		}
		return widen[i16, Lane4I16, Lane4U8, u8](parts)
	}
	if parts[1] == 'u32' && parts[3] == 'u16' {
		if parts[0].starts_with('A') {
			return widen[AliasU32, AliasFourU32, AliasFourU16, AliasU16](parts)
		}
		return widen[u32, Lane4U32, Lane4U16, u16](parts)
	}
	if parts[1] == 'i32' && parts[3] == 'u16' {
		if parts[0].starts_with('A') {
			return widen[AliasI32, AliasFourI32, AliasFourU16, AliasU16](parts)
		}
		return widen[int, Lane4I32, Lane4U16, u16](parts)
	}
	if parts[1] == 'u64' && parts[3] == 'u32' {
		if parts[0].starts_with('A') {
			return widen[AliasU64, AliasFourU64, AliasFourU32, AliasU32](parts)
		}
		return widen[u64, Lane4U64, Lane4U32, u32](parts)
	}
	if parts[1] == 'i64' && parts[3] == 'u32' {
		if parts[0].starts_with('A') {
			return widen[AliasI64, AliasFourI64, AliasFourU32, AliasU32](parts)
		}
		return widen[i64, Lane4I64, Lane4U32, u32](parts)
	}
	if parts[1] == 'i16' && parts[3] == 'i8' {
		if parts[0].starts_with('A') {
			return widen[AliasI16, AliasFourI16, AliasFourI8, AliasI8](parts)
		}
		return widen[i16, Lane4I16, Lane4I8, i8](parts)
	}
	if parts[1] == 'i32' && parts[3] == 'i16' {
		if parts[0].starts_with('A') {
			return widen[AliasI32, AliasFourI32, AliasFourI16, AliasI16](parts)
		}
		return widen[int, Lane4I32, Lane4I16, i16](parts)
	}
	if parts[1] == 'i64' && parts[3] == 'i32' {
		if parts[0].starts_with('A') {
			return widen[AliasI64, AliasFourI64, AliasFourI32, AliasI32](parts)
		}
		return widen[i64, Lane4I64, Lane4I32, int](parts)
	}
	if parts[1] == 'f64' && parts[3] == 'f32' {
		if parts[0].starts_with('A') {
			return widen[AliasF64, AliasFourF64, AliasFourF32, AliasF32](parts)
		}
		return widen[f64, Lane4F64, Lane4F32, f32](parts)
	}
	panic('unknown widening')
}

fn alias_pointer_float[B, R, A, P, S](text string, kind string) string {
	raw := values[S](text)
	if kind == 'N' {
		base_pointer := &raw[0]
		p := unsafe { *(&P(&base_pointer)) }
		return fixed_hex(zigimg.simd_int_to_float[B, P](p))
	}
	input := zigimg.simd_load[R, S](raw, 0)
	base_pointer := unsafe { &input }
	p := unsafe { *(&A(&base_pointer)) }
	return fixed_hex(zigimg.simd_int_to_float[B, A](p))
}

fn alias_pointer_int[B, R, A, P, S](text string, kind string) string {
	raw := values[S](text)
	if kind == 'N' {
		base_pointer := &raw[0]
		p := unsafe { *(&P(&base_pointer)) }
		return fixed_hex(zigimg.simd_float_to_int[B, P](p))
	}
	input := zigimg.simd_load[R, S](raw, 0)
	base_pointer := unsafe { &input }
	p := unsafe { *(&A(&base_pointer)) }
	return fixed_hex(zigimg.simd_float_to_int[B, A](p))
}

fn alias_pointers(parts []string) string {
	kind := parts[0][..1]
	if parts[0][1..] == 'I' {
		match parts[3] {
			'u8' {
				if parts[1] == 'f32' {
					return alias_pointer_float[AliasFourF32, AliasFourU8, AliasArrayPointerU8, AliasPointerU8, AliasU8](parts[4],
						kind)
				}
				return alias_pointer_float[AliasFourF64, AliasFourU8, AliasArrayPointerU8, AliasPointerU8, AliasU8](parts[4],
					kind)
			}
			'i8' {
				if parts[1] == 'f32' {
					return alias_pointer_float[AliasFourF32, AliasFourI8, AliasArrayPointerI8, AliasPointerI8, AliasI8](parts[4],
						kind)
				}
				return alias_pointer_float[AliasFourF64, AliasFourI8, AliasArrayPointerI8, AliasPointerI8, AliasI8](parts[4],
					kind)
			}
			'u16' {
				if parts[1] == 'f32' {
					return alias_pointer_float[AliasFourF32, AliasFourU16, AliasArrayPointerU16, AliasPointerU16, AliasU16](parts[4],
						kind)
				}
				return alias_pointer_float[AliasFourF64, AliasFourU16, AliasArrayPointerU16, AliasPointerU16, AliasU16](parts[4],
					kind)
			}
			'i16' {
				if parts[1] == 'f32' {
					return alias_pointer_float[AliasFourF32, AliasFourI16, AliasArrayPointerI16, AliasPointerI16, AliasI16](parts[4],
						kind)
				}
				return alias_pointer_float[AliasFourF64, AliasFourI16, AliasArrayPointerI16, AliasPointerI16, AliasI16](parts[4],
					kind)
			}
			'u32' {
				if parts[1] == 'f32' {
					return alias_pointer_float[AliasFourF32, AliasFourU32, AliasArrayPointerU32, AliasPointerU32, AliasU32](parts[4],
						kind)
				}
				return alias_pointer_float[AliasFourF64, AliasFourU32, AliasArrayPointerU32, AliasPointerU32, AliasU32](parts[4],
					kind)
			}
			'i32' {
				if parts[1] == 'f32' {
					return alias_pointer_float[AliasFourF32, AliasFourI32, AliasArrayPointerI32, AliasPointerI32, AliasI32](parts[4],
						kind)
				}
				return alias_pointer_float[AliasFourF64, AliasFourI32, AliasArrayPointerI32, AliasPointerI32, AliasI32](parts[4],
					kind)
			}
			'u64' {
				if parts[1] == 'f32' {
					return alias_pointer_float[AliasFourF32, AliasFourU64, AliasArrayPointerU64, AliasPointerU64, AliasU64](parts[4],
						kind)
				}
				return alias_pointer_float[AliasFourF64, AliasFourU64, AliasArrayPointerU64, AliasPointerU64, AliasU64](parts[4],
					kind)
			}
			'i64' {
				if parts[1] == 'f32' {
					return alias_pointer_float[AliasFourF32, AliasFourI64, AliasArrayPointerI64, AliasPointerI64, AliasI64](parts[4],
						kind)
				}
				return alias_pointer_float[AliasFourF64, AliasFourI64, AliasArrayPointerI64, AliasPointerI64, AliasI64](parts[4],
					kind)
			}
			'usize' {
				if parts[1] == 'f32' {
					return alias_pointer_float[AliasFourF32, AliasFourUsize, AliasArrayPointerUsize, AliasPointerUsize, AliasUsize](parts[4],
						kind)
				}
				return alias_pointer_float[AliasFourF64, AliasFourUsize, AliasArrayPointerUsize, AliasPointerUsize, AliasUsize](parts[4],
					kind)
			}
			'isize' {
				if parts[1] == 'f32' {
					return alias_pointer_float[AliasFourF32, AliasFourIsize, AliasArrayPointerIsize, AliasPointerIsize, AliasIsize](parts[4],
						kind)
				}
				return alias_pointer_float[AliasFourF64, AliasFourIsize, AliasArrayPointerIsize, AliasPointerIsize, AliasIsize](parts[4],
					kind)
			}
			else {
				panic('unknown alias pointer source')
			}
		}
	} else {
		match parts[1] {
			'u8' {
				if parts[3] == 'f32' {
					return alias_pointer_int[AliasFourU8, AliasFourF32, AliasArrayPointerF32, AliasPointerF32, AliasF32](parts[4],
						kind)
				}
				return alias_pointer_int[AliasFourU8, AliasFourF64, AliasArrayPointerF64, AliasPointerF64, AliasF64](parts[4],
					kind)
			}
			'i8' {
				if parts[3] == 'f32' {
					return alias_pointer_int[AliasFourI8, AliasFourF32, AliasArrayPointerF32, AliasPointerF32, AliasF32](parts[4],
						kind)
				}
				return alias_pointer_int[AliasFourI8, AliasFourF64, AliasArrayPointerF64, AliasPointerF64, AliasF64](parts[4],
					kind)
			}
			'u16' {
				if parts[3] == 'f32' {
					return alias_pointer_int[AliasFourU16, AliasFourF32, AliasArrayPointerF32, AliasPointerF32, AliasF32](parts[4],
						kind)
				}
				return alias_pointer_int[AliasFourU16, AliasFourF64, AliasArrayPointerF64, AliasPointerF64, AliasF64](parts[4],
					kind)
			}
			'i16' {
				if parts[3] == 'f32' {
					return alias_pointer_int[AliasFourI16, AliasFourF32, AliasArrayPointerF32, AliasPointerF32, AliasF32](parts[4],
						kind)
				}
				return alias_pointer_int[AliasFourI16, AliasFourF64, AliasArrayPointerF64, AliasPointerF64, AliasF64](parts[4],
					kind)
			}
			'u32' {
				if parts[3] == 'f32' {
					return alias_pointer_int[AliasFourU32, AliasFourF32, AliasArrayPointerF32, AliasPointerF32, AliasF32](parts[4],
						kind)
				}
				return alias_pointer_int[AliasFourU32, AliasFourF64, AliasArrayPointerF64, AliasPointerF64, AliasF64](parts[4],
					kind)
			}
			'i32' {
				if parts[3] == 'f32' {
					return alias_pointer_int[AliasFourI32, AliasFourF32, AliasArrayPointerF32, AliasPointerF32, AliasF32](parts[4],
						kind)
				}
				return alias_pointer_int[AliasFourI32, AliasFourF64, AliasArrayPointerF64, AliasPointerF64, AliasF64](parts[4],
					kind)
			}
			'u64' {
				if parts[3] == 'f32' {
					return alias_pointer_int[AliasFourU64, AliasFourF32, AliasArrayPointerF32, AliasPointerF32, AliasF32](parts[4],
						kind)
				}
				return alias_pointer_int[AliasFourU64, AliasFourF64, AliasArrayPointerF64, AliasPointerF64, AliasF64](parts[4],
					kind)
			}
			'i64' {
				if parts[3] == 'f32' {
					return alias_pointer_int[AliasFourI64, AliasFourF32, AliasArrayPointerF32, AliasPointerF32, AliasF32](parts[4],
						kind)
				}
				return alias_pointer_int[AliasFourI64, AliasFourF64, AliasArrayPointerF64, AliasPointerF64, AliasF64](parts[4],
					kind)
			}
			'usize' {
				if parts[3] == 'f32' {
					return alias_pointer_int[AliasFourUsize, AliasFourF32, AliasArrayPointerF32, AliasPointerF32, AliasF32](parts[4],
						kind)
				}
				return alias_pointer_int[AliasFourUsize, AliasFourF64, AliasArrayPointerF64, AliasPointerF64, AliasF64](parts[4],
					kind)
			}
			'isize' {
				if parts[3] == 'f32' {
					return alias_pointer_int[AliasFourIsize, AliasFourF32, AliasArrayPointerF32, AliasPointerF32, AliasF32](parts[4],
						kind)
				}
				return alias_pointer_int[AliasFourIsize, AliasFourF64, AliasArrayPointerF64, AliasPointerF64, AliasF64](parts[4],
					kind)
			}
			else {
				panic('unknown alias pointer output')
			}
		}
	}
}

struct StoreItem {
	x u16
	y u32
}

type StoreItems = [4]StoreItem
type StoreBools = [4]bool

fn arbitrary_stores(parts []string) string {
	length := parts[1].u32()
	raw := hex.decode(parts[2]) or { panic(err) }
	if parts[0] == 'OB' {
		mut input := StoreBools{}
		for i in 0 .. 4 {
			input[i] = raw[i] != 0
		}
		mut dest := []bool{len: 6}
		zigimg.simd_store[bool, StoreBools](mut dest, input, length)
		return dest.map(if it { '1' } else { '0' }).join('')
	}
	mut input := StoreItems{}
	for i in 0 .. 4 {
		x := u16(raw[i * 6]) | u16(raw[i * 6 + 1]) << 8
		y := u32(raw[i * 6 + 2]) | u32(raw[i * 6 + 3]) << 8 | u32(raw[i * 6 + 4]) << 16 | u32(raw[
			i * 6 + 5]) << 24
		input[i] = StoreItem{
			x: x
			y: y
		}
	}
	mut dest := []StoreItem{len: 6, init: StoreItem{
		x: 9
		y: 99
	}}
	zigimg.simd_store[StoreItem, StoreItems](mut dest, input, length)
	return dest.map('${it.x:04x}${it.y:08x}').join('')
}

fn trap(name string) {
	match name {
		'load_short' {
			_ := zigimg.simd_load[Lane4U16, u16]([u16(1), 2], 0)
		}
		'bytes_short' {
			_ := zigimg.simd_load_bytes[Lane4U16]([u8(1), 2], 0)
		}
		'bytes_remainder' {
			_ := zigimg.simd_load_bytes[Lane4U16]([u8(1), 2, 3], 0)
		}
		'store_short' {
			mut dst := [u16(9), 9]
			zigimg.simd_store[u16, Lane4U16](mut dst, Lane4U16([u16(1), 2, 3, 4]!), 0)
		}
		'int_source_short' {
			_ := zigimg.simd_int_to_float[Lane4F32, []u16]([u16(1), 2])
		}
		'float_source_short' {
			_ := zigimg.simd_float_to_int[Lane4U16, []f32]([f32(1), 2])
		}
		'negative_unsigned' {
			_ := zigimg.simd_float_to_int[Lane1U8, []f64]([f64(-1)])
		}
		'positive_unsigned' {
			_ := zigimg.simd_float_to_int[Lane1U8, []f64]([f64(256)])
		}
		'negative_signed' {
			_ := zigimg.simd_float_to_int[Lane1I8, []f64]([f64(-129)])
		}
		'positive_signed' {
			_ := zigimg.simd_float_to_int[Lane1I8, []f64]([f64(128)])
		}
		'infinity' {
			v := u64(0x7ff0000000000000)
			_ := zigimg.simd_float_to_int[Lane1I64, []f64]([unsafe { *(&f64(&v)) }])
		}
		'negative_infinity' {
			v := u64(0xfff0000000000000)
			_ := zigimg.simd_float_to_int[Lane1I64, []f64]([unsafe { *(&f64(&v)) }])
		}
		'mask_negative' {
			_ := zigimg.simd_vpermd([0, 1, 2, 3, 4, 5, 6, 7]!, [0, 1, 2, 3, 4, 5, 6, -1]!)
		}
		'mask_high' {
			_ := zigimg.simd_vpermd([0, 1, 2, 3, 4, 5, 6, 7]!, [0, 1, 2, 3, 4, 5, 6, 8]!)
		}
		'box_x_add' {
			_ := zigimg.Box{
				x:     ~usize(0)
				width: 2
			}.clamp(8, 8)
		}
		'box_y_add' {
			_ := zigimg.Box{
				y:      ~usize(0)
				height: 2
			}.clamp(8, 8)
		}
		'box_x_sub' {
			_ := zigimg.Box{
				x:     9
				width: 1
			}.clamp(8, 8)
		}
		'box_y_sub' {
			_ := zigimg.Box{
				y:      9
				height: 1
			}.clamp(8, 8)
		}
		'managed_create' {
			_ := zigimg.Image.create(~usize(0), 2, .invalid) or {
				println('UNEXPECTED: error ' + err.str())
				return
			}
		}
		'unmanaged_create' {
			_ := zigimg.ImageUnmanaged.create(~usize(0), 2, .invalid) or {
				println('UNEXPECTED: error ' + err.str())
				return
			}
		}
		'managed_crop' {
			mut image := zigimg.Image.init()
			image.width = ~usize(0)
			image.height = 2
			_ := image.crop(zigimg.Box{ width: ~usize(0), height: 2 }) or {
				println('UNEXPECTED: error ' + err.str())
				return
			}
		}
		'unmanaged_crop' {
			mut image := zigimg.ImageUnmanaged{}
			image.width = ~usize(0)
			image.height = 2
			_ := image.crop(zigimg.Box{ width: ~usize(0), height: 2 }) or {
				println('UNEXPECTED: error ' + err.str())
				return
			}
		}
		'length_excess' {
			_ := zigimg.simd_load[Lane4U16, u16]([u16(1), 2, 3, 4, 5], 5)
		}
		else {
			panic('unknown trap')
		}
	}

	println('UNEXPECTED: operation returned')
}

fn main() {
	if os.args[1].starts_with('trap:') {
		trap(os.args[1][5..])
		return
	}
	contents := os.read_file(os.args[1]) or { panic(err) }
	for line in contents.split_into_lines() {
		p := line.split('|')
		if p[0] == 'C' {
			area := zigimg.Box{
				x:      usize(p[3].u64())
				y:      usize(p[4].u64())
				width:  usize(p[5].u64())
				height: usize(p[6].u64())
			}
			box := area.clamp(usize(p[1].u64()), usize(p[2].u64()))
			println(fixed_hex(Lane4Usize([box.x, box.y, box.width, box.height]!)))
		} else if p[0] == 'Z' {
			width := usize(p[2].u64())
			height := usize(p[3].u64())
			if p[1] == 'managed' {
				mut image := zigimg.Image.create(width, height, .invalid) or { panic(err) }
				println(fixed_hex(Lane4Usize([image.width, image.height, image.image_byte_size(),
					image.pixels.len()]!)))
				image.deinit()
			} else {
				mut image := zigimg.ImageUnmanaged.create(width, height, .invalid) or { panic(err) }
				println(fixed_hex(Lane4Usize([image.width, image.height, image.image_byte_size(),
					image.pixels.len()]!)))
				image.deinit()
			}
		} else if p[0].starts_with('O') {
			println(arbitrary_stores(p))
		} else if p[0].starts_with('N') || p[0].starts_with('X') {
			println(alias_pointers(p))
		} else if p[0].starts_with('W') || p[0].starts_with('AW') {
			println(widening(p))
		} else if p[0].len == 2 && p[0][..1] in ['Q', 'V', 'M'] {
			println(pointers(p))
		} else if p[0] == 'H' {
			mut storage := values[u16](p[1])
			mut destination := unsafe { storage[1..5] }
			lanes := unsafe { &Lane4U16(storage.data) }
			zigimg.simd_store[u16, Lane4U16](mut destination, unsafe { *lanes }, 0)
			println(slice_hex(storage))
		} else if p[0].starts_with('A') {
			println(aliases(p))
		} else if p[0] == 'P' {
			v := values[int](p[1])
			m := values[int](p[2])
			mut value := [8]int{}
			mut mask := [8]int{}
			for i in 0 .. 8 {
				value[i] = v[i]
				mask[i] = m[i]
			}
			result := zigimg.simd_vpermd(value, mask)
			println(fixed_hex(result))
		} else {
			println(record(p))
		}
	}
}
