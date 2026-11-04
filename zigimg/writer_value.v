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

// Preserve the concrete generic: an IError coercion here makes V heap-lift
// unrelated fixed-array specializations of the public dispatcher.
fn io_value_error[E](mut stream WriteStream, format string, options FormatOptions, value E) ! {
	if format == 't' { return stream.align_buffer_options(value.msg().bytes(), options) }
	if format != '' && format != 'any' { return error('unsupported print_value error format') }
	if options.precision != none { panic('reached unreachable code') }
	if options.width != none { panic('reached unreachable code') }
	mut vectors := ['error.'.bytes(), value.msg().bytes()]
	return stream.write_vec_all(mut vectors)
}

fn io_value_slice[T](mut stream WriteStream, format string, options FormatOptions, value []T, max_depth usize) ! {
	if format == '*' {
		$if T is $option {
			return stream.print_address(value)
		} $else $if T.unaliased_typ is $array_fixed {
			return stream.print_address(value)
		} $else $if T.unaliased_typ is $int || T.unaliased_typ is f32 || T.unaliased_typ is f64
			|| T.unaliased_typ is bool {
			return stream.print_address(value)
		} $else {
			return error('unsupported print_value pointer format')
		}
	}
	if format != 'any' { return error('unsupported print_value slice format') }
	if max_depth == 0 { return stream.write_all('{ ... }'.bytes()) }
	stream.write_all('{ '.bytes())!
	for i in 0 .. value.len {
		stream.print_value[T](format, options, value[i], max_depth - 1)!
		if i != value.len - 1 { stream.write_all(', '.bytes())! }
	}
	return stream.write_all(' }'.bytes())
}

fn io_value_array[T](mut stream WriteStream, format string, options FormatOptions, value []T, max_depth usize) ! {
	// Inspect the element generic directly: typeof(value[0]) strips its option flag in V.
	$if T is $option {
		if format != 'any' { return error('unsupported print_value array format') }
		return io_value_slice(mut stream, format, options, value, max_depth)
	} $else $if T.unaliased_typ is u8 {
		return io_value_bytes(mut stream, format, options, value, max_depth)
	} $else {
		if format != 'any' { return error('unsupported print_value array format') }
		return io_value_slice(mut stream, format, options, value, max_depth)
	}
}

// V also checks an unused IError specialization for reflected field calls.
fn io_value_field[F](mut stream WriteStream, options FormatOptions, value F, max_depth usize) ! {
	$if F is IError {
		return io_value_error(mut stream, 'any', options, value)
	} $else {
		return stream.print_value('any', options, value, max_depth)
	}
}

interface IoNumberFormatter {
	format_number(mut stream WriteStream, options NumberFormat) !
}

interface IoByteSizeFormatter {
	format_byte_size(mut stream WriteStream, units ByteSizeUnits) !
}

interface IoDurationFormatter {
	format_duration(mut stream WriteStream) !
}

fn io_value_struct[T](mut stream WriteStream, format string, options FormatOptions, value T, max_depth usize) ! {
	$if T.unaliased_typ is $struct {
		$if T is IoNumberFormatter {
			if format in ['d', 'b', 'o', 'x', 'X', 'e', 'E'] {
				mode := match format {
					'b' { NumberMode.binary }
					'o' { NumberMode.octal }
					'x', 'X' { NumberMode.hex }
					'e', 'E' { NumberMode.scientific }
					else { NumberMode.decimal }
				}
				letter_case := if format == 'X' || format == 'E' {
					FormatCase.upper
				} else {
					FormatCase.lower
				}
				return value.format_number(mut stream, options.to_number(mode, letter_case))
			}
		}
		$if T is IoByteSizeFormatter {
			if format == 'B' || format == 'Bi' {
				return value.format_byte_size(mut stream, if format == 'Bi' {
					ByteSizeUnits.binary
				} else {
					ByteSizeUnits.decimal
				})
			}
		}
		$if T is IoDurationFormatter {
			if format == 'D' { return value.format_duration(mut stream) }
		}
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

fn io_value_union[T](mut stream WriteStream, format string, options FormatOptions, value T, max_depth usize) ! {
	$if T.unaliased_typ is $sumtype {
		if format != '' && format != 'any' && format != 't' {
			return error('unsupported print_value union format')
		}
		if format == '' {
			$for method in T.methods {
				if method.name == 'format' { return error('ambiguous print_value union format') }
			}
		}
		if format != 't' && max_depth == 0 { return stream.write_all('.{ ... }'.bytes()) }
		$for variant in T.variants {
			if value is variant {
				// V tags are types; use their reflected spelling as the Zig field name.
				tag := typeof(variant.typ).name
				if format == 't' { return stream.align_buffer_options(tag.bytes(), options) }
				stream.write_all('.{ .'.bytes())!
				stream.write_all(tag.bytes())!
				stream.write_all(' = '.bytes())!
				payload := value
				io_value_field(mut stream, options, payload, max_depth - 1)!
				return stream.write_all(' }'.bytes())
			}
		}
		panic('invalid sum type')
	} $else {
		return error('unsupported print_value union carrier')
	}
}

fn io_value_optional[T](mut stream WriteStream, format string, options FormatOptions, value ?T, max_depth usize) ! {
	remaining := if format.starts_with('?') {
		format[1..]
	} else if format == 'any' {
		'any'
	} else {
		return error('unsupported print_value optional format')
	}
	$if T.pointee_type is $array_fixed {
		// V generates an invalid copy when unwrapping optional fixed-array pointers.
		missing := value == none
		if missing { return stream.align_buffer_options('null'.bytes(), options) }
		return error('unsupported print_value optional array-pointer carrier')
	}
	// An or-block preserves each payload type in V's generic specializations.
	payload := value or { return stream.align_buffer_options('null'.bytes(), options) }
	$if T.indirections > 0 || ((int(T.unaliased_typ) >> 16) & 0xff) > 0 {
		$if T is $alias {
			// Normalize the unwrapped alias without interpreting V's optional layout.
			mut normalized := $zero(T.unaliased_typ)
			unsafe { vmemcpy(&normalized, &payload, int(sizeof(T))) }
			return stream.print_value(remaining, options, normalized, max_depth)
		} $else {
			// Keep the optional carrier: forwarding a generic pointer takes its address in V.
			return io_value_optional_pointer(mut stream, remaining, options, value, max_depth)
		}
	} $else {
		return stream.print_value[T](remaining, options, payload, max_depth)
	}
}

interface IoValueFormatter {
	format(mut stream WriteStream) !
}

// The represented printValue branches; format is a runtime string in V.
pub fn (mut stream WriteStream) print_value[T](format string, options FormatOptions, value T, max_depth usize) ! {
	$if T !is $option {
		$if T is IoValueFormatter {
			// Invoke on the concrete carrier; options and depth never reach format.
			if format == 'f' { return value.format(mut stream) }
		}
	}
	$if T is $option {
		if format == '*' {
			$if T.indirections == 1 || ((int(T.unaliased_typ) >> 16) & 0xff) == 1 {
				return io_value_optional_address_dispatch(mut stream, value)
			} $else {
				return error('unsupported print_value pointer carrier')
			}
		}
		return io_value_optional(mut stream, format, options, value, max_depth)
	} $else $if T.unaliased_typ is voidptr || T.indirections > 0
		|| ((int(T.unaliased_typ) >> 16) & 0xff) > 0 {
		$if T.unaliased_typ is voidptr {
			if format == '*' { return stream.print_address(value) }
			if format != '' && format != 'any' { return error('unsupported print_value pointer format') }
			return io_value_pointer_bits(mut stream, options, 'anyopaque', usize(value))
		} $else $if T is $alias {
			mut normalized := $zero(T.unaliased_typ)
			unsafe { vmemcpy(&normalized, &value, int(sizeof(T))) }
			return stream.print_value(format, options, normalized, max_depth)
		} $else {
			return io_value_pointer(mut stream, format, options, value, max_depth)
		}
	} $else $if T is IError {
		return io_value_error(mut stream, format, options, value)
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
	} $else $if T.unaliased_typ is string {
		return io_value_string(mut stream, format, options, string(value), max_depth)
	} $else $if T.unaliased_typ is []u8 {
		if format == '*' { return stream.print_address(value) }
		return io_value_bytes(mut stream, format, options, value, max_depth)
	} $else $if T.unaliased_typ is $array_fixed {
		return io_value_array(mut stream, format, options, value[..], max_depth)
	} $else $if T.unaliased_typ is $array {
		return io_value_slice(mut stream, format, options, value, max_depth)
	} $else $if T.unaliased_typ is $enum {
		return io_value_enum[T](mut stream, format, options, value)
	} $else $if T.unaliased_typ is $sumtype {
		return io_value_union[T](mut stream, format, options, value, max_depth)
	} $else $if T.unaliased_typ is $struct {
		return io_value_struct[T](mut stream, format, options, value, max_depth)
	} $else {
		$compile_error('print_value supports native scalars, strings, enums, errors, pointers, arrays, records, sum types and optionals')
	}
}
