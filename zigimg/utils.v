module zigimg

// These names preserve the source's fixed shift order. Its endian wrapper
// selects them using the target's native endian, even on a big-endian target.
pub fn to_magic_number_native(magic []u8) u32 {
	mut result := u32(0)
	for index, byte in magic {
		if index > 3 { panic('magic number shift exceeds u32 width') }
		shift := index * 8
		result |= u32(byte) << shift
	}
	return result
}

pub fn to_magic_number_foreign(magic []u8) u32 {
	mut result := u32(0)
	for index, byte in magic {
		remaining := magic.len - 1 - index
		if remaining > 3 { panic('magic number shift exceeds u32 width') }
		shift := remaining * 8
		result |= u32(byte) << shift
	}
	return result
}

pub fn to_magic_number[E](magic []u8, endian E) u32 {
	$if E.unaliased_typ is BigEndian {
		$if little_endian {
			return to_magic_number_foreign(magic)
		} $else {
			return to_magic_number_native(magic)
		}
	} $else $if E.unaliased_typ is LittleEndian {
		$if little_endian {
			return to_magic_number_native(magic)
		} $else {
			return to_magic_number_foreign(magic)
		}
	} $else {
		$compile_error('to_magic_number requires BigEndian or LittleEndian')
	}
	return 0
}

// Deprecated source utilities still underpin PNG's enum-checked header read.
// T must have the corresponding native layout, including field widths/padding.
pub fn take_struct_native[T](mut reader ReadStream) !T {
	bytes := reader.take(int(sizeof(T)))!
	mut result := T{}
	unsafe { vmemcpy(&result, bytes.data, sizeof(T)) }
	check_struct_enum_fields(result)!
	return result
}

fn check_enum_field[T](value T) ! {
	// The source's non-exhaustive PNG enums accept unnamed values. V carries
	// that property explicitly for these two translated enum types.
	$if T.unaliased_typ is PngCompressionMethod || T.unaliased_typ is PngFilterMethod {
		return
	} $else {
		mut valid := false
		$for entry in T.values {
			if i64(value) == i64(entry.value) { valid = true }
		}
		if !valid { return error('InvalidData') }
	}
}

fn check_struct_enum_fields[T](value T) ! {
	$for field in T.fields {
		$if field.unaliased_typ is $enum {
			check_enum_field(value.$(field.name))!
		} $else $if field.unaliased_typ is $struct {
			check_struct_enum_fields(value.$(field.name))!
		}
	}
}

fn swap_struct_field_bytes[T](mut value T) ! {
	$for field in T.fields {
		$if field.unaliased_typ is $int || field.unaliased_typ is $enum {
			mut bytes := struct_field_bytes(unsafe { &value.$(field.name) },
				int(sizeof(value.$(field.name))))
			for index in 0 .. bytes.len / 2 {
				opposite := bytes.len - 1 - index
				temporary := bytes[index]
				bytes[index] = bytes[opposite]
				bytes[opposite] = temporary
			}
			$if field.unaliased_typ is $enum { check_enum_field(value.$(field.name))! }
		} $else $if field.unaliased_typ is $struct {
			mut nested := value.$(field.name)
			swap_struct_field_bytes(mut nested)!
			unsafe { vmemcpy(&value.$(field.name), &nested, sizeof(nested)) }
		} $else $if field.unaliased_typ is bool {
			// Source bool fields are unchanged.
		} $else $if field.unaliased_typ is $array {
			check_struct_byte_array(value.$(field.name))
		} $else {
			$compile_error('unsupported take_struct_foreign field type')
		}
	}
}

fn struct_field_bytes(data voidptr, length int) []u8 {
	return unsafe { (&u8(data)).vbytes(length) }
}

pub fn take_struct_foreign[T](mut reader ReadStream) !T {
	bytes := reader.take(int(sizeof(T)))!
	mut result := T{}
	unsafe { vmemcpy(&result, bytes.data, sizeof(T)) }
	swap_struct_field_bytes(mut result)!
	return result
}

pub fn take_struct[T, E](mut reader ReadStream, endian E) !T {
	$if E.unaliased_typ is BigEndian {
		$if little_endian {
			return take_struct_foreign[T](mut reader)
		} $else {
			return take_struct_native[T](mut reader)
		}
	} $else $if E.unaliased_typ is LittleEndian {
		$if little_endian {
			return take_struct_native[T](mut reader)
		} $else {
			return take_struct_foreign[T](mut reader)
		}
	} $else {
		$compile_error('take_struct requires BigEndian or LittleEndian')
	}
	return T{}
}

fn check_struct_byte_array[B](value B) {
	$if B.unaliased_typ is $array_dynamic {
		$compile_error('take_struct_foreign requires inline byte arrays')
	} $else {
		check_struct_byte(value[0])
	}
}

fn check_struct_byte[T](value T) {
	$if T.unaliased_typ is u8 {
		_ = value
	} $else {
		$compile_error('take_struct_foreign only supports byte arrays')
	}
}
