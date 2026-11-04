module zigimg

// Default pointer formatting keeps the type/@ vectors separate from the digits.
fn io_value_pointer_bits(mut stream WriteStream, options FormatOptions, name string, address usize) ! {
	mut vectors := [name.bytes(), '@'.bytes()]
	stream.write_vec_all(mut vectors)!
	return stream.print_int[usize](address, 16, .lower, options)
}

fn io_value_pointer[T](mut stream WriteStream, format string, options FormatOptions, value &T, max_depth usize) ! {
	$if T.unaliased_typ is $struct || T.unaliased_typ is $enum || T.unaliased_typ is $sumtype {
		if format != '' && format != 'any' {
			return error('unsupported print_value aggregate-pointer format')
		}
		$if T.unaliased_typ is $sumtype {
			return io_value_pointed_union(mut stream, format, options, value, max_depth)
		} $else {
			payload := *value
			return stream.print_value(format, options, payload, max_depth)
		}
	} $else {
		if format == '*' {
			stream.write_all((io_address_type_name[T]() + '@').bytes())!
			return io_address_integer(mut stream, usize(voidptr(value)))
		}
		if format != '' && format != 'any' {
			return error('unsupported print_value pointer format')
		}
		return io_value_pointer_bits(mut stream, options, io_address_type_name[T](), usize(voidptr(value)))
	}
}

fn io_value_optional_pointer[T](mut stream WriteStream, format string, options FormatOptions, value ?&T, max_depth usize) ! {
	// Extract before pointee reflection: V cannot parse this unwrap inside that branch.
	address := unsafe { usize(voidptr(value or { nil })) }
	$if T is IoValueFormatter {
		if format == 'f' {
			pointer := unsafe { &T(voidptr(address)) }
			return pointer.format(mut stream)
		}
	}
	$if T.unaliased_typ is $struct || T.unaliased_typ is $enum || T.unaliased_typ is $sumtype {
		if format != '' && format != 'any' {
			return error('unsupported print_value aggregate-pointer format')
		}
		pointer := unsafe { &T(voidptr(address)) }
		$if T.unaliased_typ is $sumtype {
			return io_value_pointed_union(mut stream, format, options, pointer, max_depth)
		} $else {
			payload := *pointer
			return stream.print_value(format, options, payload, max_depth)
		}
	} $else {
		if format == '*' {
			stream.write_all((io_address_type_name[T]() + '@').bytes())!
			return io_address_integer(mut stream, address)
		}
		if format != '' && format != 'any' {
			return error('unsupported print_value pointer format')
		}
		return io_value_pointer_bits(mut stream, options, io_address_type_name[T](), address)
	}
}

fn io_value_pointed_union[T](mut stream WriteStream, format string, options FormatOptions, value &T, max_depth usize) ! {
	// Passing a dereferenced generic sum to print_value makes V rebox its first variant.
	$if T.unaliased_typ is $sumtype {
		if format == '' {
			$for method in T.methods {
				if method.name == 'format' { return error('ambiguous print_value union format') }
			}
		}
		if max_depth == 0 { return stream.write_all('.{ ... }'.bytes()) }
		$for variant in T.variants {
			if value is variant {
				stream.write_all('.{ .'.bytes())!
				stream.write_all(typeof(variant.typ).name.bytes())!
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

fn io_value_normalized_optional_address[T](mut stream WriteStream, value &T) ! {
	$if T.unaliased_typ is $struct || T.unaliased_typ is $enum || T.unaliased_typ is $sumtype {
		return error('unsupported print_value aggregate-pointer format')
	} $else {
		stream.write_all(('*' + io_address_type_name[T]() + '@').bytes())!
		return io_address_integer(mut stream, usize(voidptr(value)))
	}
}

fn io_value_optional_direct_address[T](mut stream WriteStream, value ?&T) ! {
	$if T.unaliased_typ is $struct || T.unaliased_typ is $enum || T.unaliased_typ is $sumtype {
		return error('unsupported print_value aggregate-pointer format')
	} $else {
		return stream.print_address(value)
	}
}

fn io_value_optional_address_dispatch[P](mut stream WriteStream, value ?P) ! {
	// Keep optional unwrapping outside reflected branches in V's generic parser.
	payload := value or { $zero(P) }
	$if P.indirections == 0 && ((int(P.unaliased_typ) >> 16) &0xff) == 0 {
		return error('unsupported print_value pointer carrier')
	} $else $if P !is $alias {
		return io_value_optional_direct_address(mut stream, value)
	} $else {
		mut normalized := $zero(P.unaliased_typ)
		unsafe { vmemcpy(&normalized, &payload, int(sizeof(P))) }
		return io_value_normalized_optional_address(mut stream, normalized)
	}
}
