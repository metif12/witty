module zigimg

// Default pointer formatting keeps the type/@ vectors separate from the digits.
fn io_value_pointer_bits(mut stream WriteStream, options FormatOptions, name string, address usize) ! {
	mut vectors := [name.bytes(), '@'.bytes()]
	stream.write_vec_all(mut vectors)!
	return stream.print_int[usize](address, 16, .lower, options)
}

fn io_value_pointer[T](mut stream WriteStream, options FormatOptions, value &T) ! {
	return io_value_pointer_bits(mut stream, options, io_address_type_name[T](), usize(voidptr(value)))
}

fn io_value_optional_pointer[T](mut stream WriteStream, options FormatOptions, value ?&T) ! {
	address := unsafe { usize(voidptr(value or { nil })) }
	return io_value_pointer_bits(mut stream, options, io_address_type_name[T](), address)
}

fn io_value_normalized_optional_address[T](mut stream WriteStream, value &T) ! {
	stream.write_all(('*' + io_address_type_name[T]() + '@').bytes())!
	return io_address_integer(mut stream, usize(voidptr(value)))
}

fn io_value_optional_address_dispatch[P](mut stream WriteStream, value ?P) ! {
	$if P !is $alias {
		return stream.print_address(value)
	}
	mut normalized := $zero(P.unaliased_typ)
	// An or-block avoids V caching the last optional type across specializations.
	payload := value or { return io_value_normalized_optional_address(mut stream, normalized) }
	unsafe { vmemcpy(&normalized, &payload, int(sizeof(P))) }
	return io_value_normalized_optional_address(mut stream, normalized)
}
