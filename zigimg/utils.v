module zigimg

// These names preserve the source's fixed shift order. Its endian wrapper
// selects them using the target's native endian, even on a big-endian target.
pub fn to_magic_number_native(magic []u8) u32 {
	mut result := u32(0)
	for index, byte in magic {
		shift := index * 8
		assert shift <= 31
		result |= u32(byte) << shift
	}
	return result
}

pub fn to_magic_number_foreign(magic []u8) u32 {
	mut result := u32(0)
	for index, byte in magic {
		shift := (magic.len - 1 - index) * 8
		assert shift <= 31
		result |= u32(byte) << shift
	}
	return result
}

pub fn to_magic_number[E](magic []u8, endian E) u32 {
	$if E is BigEndian {
		$if little_endian {
			return to_magic_number_foreign(magic)
		} $else {
			return to_magic_number_native(magic)
		}
	} $else $if E is LittleEndian {
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
	$if T is PngCompressionMethod || T is PngFilterMethod {
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
		$if field.typ is $enum {
			check_enum_field(value.$(field.name))!
		} $else $if field.typ is $struct {
			check_struct_enum_fields(value.$(field.name))!
		}
	}
}

fn swap_struct_field_bytes[T](mut value T) ! {
	$for field in T.fields {
		$if field.typ is $int || field.typ is $enum {
			mut bytes := struct_field_bytes(unsafe { &value.$(field.name) },
				int(sizeof(value.$(field.name))))
			for index in 0 .. bytes.len / 2 {
				opposite := bytes.len - 1 - index
				temporary := bytes[index]
				bytes[index] = bytes[opposite]
				bytes[opposite] = temporary
			}
			$if field.typ is $enum { check_enum_field(value.$(field.name))! }
		} $else $if field.typ is $struct {
			mut nested := value.$(field.name)
			swap_struct_field_bytes(mut nested)!
			unsafe { vmemcpy(&value.$(field.name), &nested, sizeof(nested)) }
		} $else $if field.typ is bool {
			// Source bool fields are unchanged.
		} $else $if field.typ is $array {
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
	$if E is BigEndian {
		$if little_endian {
			return take_struct_foreign[T](mut reader)
		} $else {
			return take_struct_native[T](mut reader)
		}
	} $else $if E is LittleEndian {
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
	$if B.unaliased_typ is []u8 {
		$compile_error('take_struct_foreign requires inline byte arrays')
	} $else {
		element := value[0]
		$if element is u8 {
			_ = element
		} $else {
			$compile_error('take_struct_foreign only supports byte arrays')
		}
	}
}
