module zigimg

fn io_value_base(format string) ?u8 {
	return match format {
		'', 'any', 'd' { u8(10) }
		'b' { u8(2) }
		'o' { u8(8) }
		'x', 'X' { u8(16) }
		else { none }
	}
}

fn io_value_unsigned(mut stream WriteStream, format string, options FormatOptions, value u64) ! {
	if format == 'D' { return stream.print_duration[u64](value, options) }
	if format == 'B' { return stream.print_byte_size(value, .decimal, options) }
	if format == 'Bi' { return stream.print_byte_size(value, .binary, options) }
	base := io_value_base(format) or { return error('unsupported print_value integer format') }
	letter_case := if format == 'X' { FormatCase.upper } else { FormatCase.lower }
	return stream.print_int[u64](value, base, letter_case, options)
}

fn io_value_signed(mut stream WriteStream, format string, options FormatOptions, value i64) ! {
	if format == 'D' { return stream.print_duration[i64](value, options) }
	base := io_value_base(format) or { return error('unsupported print_value integer format') }
	letter_case := if format == 'X' { FormatCase.upper } else { FormatCase.lower }
	return stream.print_int[i64](value, base, letter_case, options)
}

fn io_value_float[T](mut stream WriteStream, format string, options FormatOptions, value T) ! {
	match format {
		'', 'any', 'd' {
			return stream.print_float[T](value, options.to_number(NumberMode.decimal,
				FormatCase.lower))
		}
		'e', 'E' {
			return stream.print_float[T](value, options.to_number(NumberMode.scientific, if format == 'E' {
				FormatCase.upper
			} else {
				FormatCase.lower
			}))
		}
		'x', 'X' {
			return stream.print_float_hex_options[T](value, options.to_number(NumberMode.hex, if format == 'X' {
				FormatCase.upper
			} else {
				FormatCase.lower
			}))
		}
		else {
			return error('unsupported print_value float format')
		}
	}
}

fn io_value_enum[T](mut stream WriteStream, format string, options FormatOptions, value T) ! {
	$if T.unaliased_typ is $enum {
		if format in ['d', 'b', 'o', 'x', 'X'] {
			// Comparing converted values also recognizes signed enums with no negative tags.
			minus_one, zero := i64(-1), i64(0)
			if unsafe { T(minus_one) < T(zero) } {
				return io_value_signed(mut stream, format, options, i64(value))
			}
			return io_value_unsigned(mut stream, format, options, u64(value))
		}
		if format != '' && format != 'any' && format != 't' {
			return error('unsupported print_value enum format')
		}
		if format != 't' {
			if options.precision != none { panic('reached unreachable code') }
			if options.width != none { panic('reached unreachable code') }
		}
		$for entry in T.values {
			if value == unsafe { T(entry.value) } {
				if format == 't' { return stream.align_buffer_options(entry.name.bytes(), options) }
				mut vectors := ['.'.bytes(), entry.name.bytes()]
				return stream.write_vec_all(mut vectors)
			}
		}
		if format == 't' { panic('invalid enum value') }
		$for attribute in T.attributes {
			if attribute.name == 'nonexhaustive' {
				stream.write_all('@enumFromInt('.bytes())!
				minus_one, zero := i64(-1), i64(0)
				if unsafe { T(minus_one) < T(zero) } {
					stream.print_int[i64](i64(value), 10, .lower, FormatOptions{})!
				} else {
					stream.print_int[u64](u64(value), 10, .lower, FormatOptions{})!
				}
				return stream.write_byte(`)`)
			}
		}
		panic('invalid enum value')
	} $else {
		return error('unsupported print_value enum carrier')
	}
}

fn io_value_bytes(mut stream WriteStream, format string, options FormatOptions, bytes []u8, max_depth usize) ! {
	match format {
		's' {
			return stream.align_buffer_options(bytes, options)
		}
		'x', 'X', 'b64' {
			if options.precision != none { panic('reached unreachable code') }
			if options.width != none { panic('reached unreachable code') }
			if format == 'b64' { return stream.print_base64(bytes) }
			return stream.print_hex(bytes, if format == 'X' {
				FormatCase.upper
			} else {
				FormatCase.lower
			})
		}
		'any' {
			if max_depth == 0 { return stream.write_all('{ ... }'.bytes()) }
			stream.write_all('{ '.bytes())!
			for i, byte in bytes {
				io_value_unsigned(mut stream, 'any', options, u64(byte))!
				if i != bytes.len - 1 { stream.write_all(', '.bytes())! }
			}
			return stream.write_all(' }'.bytes())
		}
		else {
			return error('unsupported print_value byte-slice format')
		}
	}
}

fn io_value_slice[T](mut stream WriteStream, format string, options FormatOptions, value []T, max_depth usize) ! {
	if format == '*' {
		$if T.unaliased_typ is $int || T.unaliased_typ is f32 || T.unaliased_typ is f64
			|| T.unaliased_typ is bool {
			return stream.print_address(value)
		} $else {
			return error('unsupported print_value pointer format')
		}
	}
	if format != 'any' { return error('unsupported print_value slice format') }
	if max_depth == 0 { return stream.write_all('{ ... }'.bytes()) }
	stream.write_all('{ '.bytes())!
	for i, element in value {
		stream.print_value(format, options, element, max_depth - 1)!
		if i != value.len - 1 { stream.write_all(', '.bytes())! }
	}
	return stream.write_all(' }'.bytes())
}

fn io_value_field[F](mut stream WriteStream, options FormatOptions, value F, max_depth usize) ! {
	// V 0.5.2 also checks an unused IError specialization for reflected calls.
	// Keep that path out of the public generic dispatcher.
	$if F is IError {
		return error('unsupported print_value field carrier')
	} $else {
		return stream.print_value('any', options, value, max_depth)
	}
}

fn io_value_struct[T](mut stream WriteStream, format string, options FormatOptions, value T, max_depth usize) ! {
	$if T.unaliased_typ is $struct {
		if format != '' && format != 'any' {
			return error('unsupported print_value struct format')
		}
		if format == '' {
			$for method in T.methods {
				if method.name == 'format' { return error('ambiguous print_value struct format') }
			}
		}
		if max_depth == 0 { return stream.write_all('.{ ... }'.bytes()) }
		stream.write_all('.{'.bytes())!
		mut first := true
		$for field in T.fields {
			stream.write_all(if first { ' .'.bytes() } else { ', .'.bytes() })!
			first = false
			stream.write_all(field.name.bytes())!
			stream.write_all(' = '.bytes())!
			io_value_field(mut stream, options, value.$(field.name), max_depth - 1)!
		}
		return stream.write_all(' }'.bytes())
	} $else {
		return error('unsupported print_value struct carrier')
	}
}

// The represented printValue branches; format is a runtime string in V.
pub fn (mut stream WriteStream) print_value[T](format string, options FormatOptions, value T, max_depth usize) ! {
	$if T is $option || T.unaliased_typ is voidptr || T.indirections > 0
		|| ((int(T.unaliased_typ) >> 16) & 0xff) > 0 {
		if format != '*' { return error('unsupported print_value pointer format') }
		return stream.print_address(value)
	} $else $if T.unaliased_typ is $int {
		if format == 'c' {
			$if T.unaliased_typ is u8 {
				return stream.print_ascii_char(u8(value), options)
			} $else {
				return error('unsupported print_value character carrier')
			}
		}
		if format == 'u' {
			$if T.unaliased_typ is u8 || T.unaliased_typ is u16 || T.unaliased_typ is u32 {
				return stream.print_unicode_codepoint(u32(value))
			} $else {
				return error('unsupported print_value codepoint carrier')
			}
		}
		$if T.unaliased_typ is i8 || T.unaliased_typ is i16 || T.unaliased_typ is int
			|| T.unaliased_typ is i64 || T.unaliased_typ is isize {
			return io_value_signed(mut stream, format, options, i64(value))
		} $else {
			return io_value_unsigned(mut stream, format, options, u64(value))
		}
	} $else $if T.unaliased_typ is f32 || T.unaliased_typ is f64 {
		return io_value_float[T](mut stream, format, options, value)
	} $else $if T.unaliased_typ is bool {
		if format != '' && format != 'any' { return error('unsupported print_value boolean format') }
		return stream.align_buffer_options(if bool(value) { 'true'.bytes() } else { 'false'.bytes() },
			options)
	} $else $if T.unaliased_typ is []u8 {
		if format == '*' { return stream.print_address(value) }
		return io_value_bytes(mut stream, format, options, value, max_depth)
	} $else $if T.unaliased_typ is $array_fixed {
		$if typeof(value[0]).unaliased_typ is u8 {
			return io_value_bytes(mut stream, format, options, value[..], max_depth)
		} $else {
			if format != 'any' { return error('unsupported print_value array format') }
			return io_value_slice(mut stream, format, options, value[..], max_depth)
		}
	} $else $if T.unaliased_typ is $array {
		return io_value_slice(mut stream, format, options, value, max_depth)
	} $else $if T.unaliased_typ is $enum {
		return io_value_enum[T](mut stream, format, options, value)
	} $else $if T.unaliased_typ is $struct {
		return io_value_struct[T](mut stream, format, options, value, max_depth)
	} $else {
		$compile_error('print_value supports native scalars, enums, pointers, arrays and records')
	}
}
