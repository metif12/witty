module zigimg

// Default pointer formatting keeps the type/@ vectors separate from the digits.
fn io_value_pointer_bits(mut stream WriteStream, options FormatOptions, name string, address usize) ! {
	mut vectors := [name.bytes(), '@'.bytes()]
	stream.write_vec_all(mut vectors)!
	return stream.print_int[usize](address, 16, .lower, options)
}

fn io_value_pointer[T](mut stream WriteStream, format string, options FormatOptions, value &T, max_depth usize) ! {
	$if T.unaliased_typ is $array_fixed {
		if format == '*' {
			witness := T{}
			name := io_value_array_address_name(witness)!
			stream.write_all((name + '@').bytes())!
			return io_address_integer(mut stream, usize(voidptr(value)))
		}
		// A zero witness binds the element generic without reading or copying the pointee.
		zero := T{}
		view := io_value_array_view(zero[0], voidptr(value), value.len)
		return io_value_array(mut stream, format, options, view, max_depth)
	} $else $if T.unaliased_typ is $struct || T.unaliased_typ is $enum || T.unaliased_typ is $sumtype {
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

// Bind through concrete witnesses: V can reuse element-type metadata across generics.
fn io_value_array_address_name[A](value A) !string {
	$if A is $option {
		return io_value_optional_address_name(value)
	} $else $if A.unaliased_typ is $array_fixed {
		zero := A{}
		element := io_value_array_address_name(zero[0])!
		return '[${zero.len}]' + element
	} $else $if A.unaliased_typ is $array && A.indirections == 0 && ((int(A.unaliased_typ) >> 16) &0xff) == 0 {
		return io_value_slice_address_name(value)
	} $else $if A.unaliased_typ is voidptr {
		return '*anyopaque'
	} $else $if A.indirections > 0 || ((int(A.unaliased_typ) >> 16) &0xff) > 0 {
		return io_value_array_pointer_address_name(value)
	} $else $if A.unaliased_typ is string {
		return '[]const u8'
	} $else $if A.unaliased_typ is u8 || A.unaliased_typ is u16 || A.unaliased_typ is u32 || A.unaliased_typ is u64 || A.unaliased_typ is usize || A.unaliased_typ is i8 || A.unaliased_typ is i16 || A.unaliased_typ is int || A.unaliased_typ is i64 || A.unaliased_typ is isize || A.unaliased_typ is f32 || A.unaliased_typ is f64 || A.unaliased_typ is bool {
		return io_address_type_name[A]()
	} $else {
		return error('unsupported print_value array-pointer address element')
	}
}

// Bind the element type through an empty witness; never index the caller's slice.
fn io_value_slice_address_name[E](_ []E) !string {
	zero := $zero(E)
	name := io_value_array_address_name(zero)!
	return '[]' + name
}

// Bind a separate scalar generic so aliases retain their unaliased pointee type.
fn io_value_array_pointer_address_name[P](_ P) !string {
	$if P is $alias {
		normalized := $zero(P.unaliased_typ)
		return io_value_array_pointer_address_name(normalized)
	} $else $if P.indirections == 1 {
		zero := $zero(P.pointee_type)
		name := io_value_pointer_pointee_address_name(zero)!
		return '*' + name
	}
	return error('unsupported print_value array-pointer address element')
}

fn io_value_pointer_pointee_address_name[T](_ T) !string {
	$if T is $option || T.indirections > 0 || ((int(T.unaliased_typ) >> 16) &0xff) > 0 {
		return error('unsupported print_value array-pointer address element')
	} $else $if T.unaliased_typ is u8 || T.unaliased_typ is u16 || T.unaliased_typ is u32 || T.unaliased_typ is u64 || T.unaliased_typ is usize || T.unaliased_typ is i8 || T.unaliased_typ is i16 || T.unaliased_typ is int || T.unaliased_typ is i64 || T.unaliased_typ is isize || T.unaliased_typ is f32 || T.unaliased_typ is f64 || T.unaliased_typ is bool {
		return io_address_type_name[T]()
	} $else {
		return error('unsupported print_value array-pointer address element')
	}
}

// Name the optional payload type without unwrapping its value or inspecting its layout.
fn io_value_optional_address_name[T](_ ?T) !string {
	$if T is $option {
		return error('unsupported print_value array-pointer address element')
	} $else $if T.unaliased_typ is voidptr {
		return '?*anyopaque'
	} $else $if T.indirections > 0 || ((int(T.unaliased_typ) >> 16) &0xff) > 0 {
		zero := $zero(T)
		name := io_value_array_pointer_address_name(zero)!
		return '?' + name
	} $else $if T.unaliased_typ is string {
		return '?[]const u8'
	} $else $if T.unaliased_typ is $array_fixed || T.unaliased_typ is $array {
		zero := T{}
		name := io_value_array_address_name(zero)!
		return '?' + name
	} $else $if T.unaliased_typ is u8 || T.unaliased_typ is u16 || T.unaliased_typ is u32 || T.unaliased_typ is u64 || T.unaliased_typ is usize || T.unaliased_typ is i8 || T.unaliased_typ is i16 || T.unaliased_typ is int || T.unaliased_typ is i64 || T.unaliased_typ is isize || T.unaliased_typ is f32 || T.unaliased_typ is f64 || T.unaliased_typ is bool {
		return '?' + io_address_type_name[T]()
	} $else {
		return error('unsupported print_value array-pointer address element')
	}
}

// The array header borrows caller storage only for the synchronous formatter call.
fn io_value_array_view[E](_ E, address voidptr, len int) []E {
	return unsafe { array{ data: address, len: len, cap: len, flags: .nofree, element_size: int(sizeof(E)) } }
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
	$if T.unaliased_typ is $array_fixed {
		return error('unsupported print_value optional array-pointer carrier')
	} $else $if T.unaliased_typ is $struct || T.unaliased_typ is $enum || T.unaliased_typ is $sumtype {
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
	$if T.unaliased_typ is $array_fixed {
		return error('unsupported print_value array-pointer address')
	} $else $if T.unaliased_typ is $struct || T.unaliased_typ is $enum || T.unaliased_typ is $sumtype {
		return error('unsupported print_value aggregate-pointer format')
	} $else {
		stream.write_all(('*' + io_address_type_name[T]() + '@').bytes())!
		return io_address_integer(mut stream, usize(voidptr(value)))
	}
}

fn io_value_optional_direct_address[T](mut stream WriteStream, value ?&T) ! {
	$if T.unaliased_typ is $array_fixed {
		return error('unsupported print_value array-pointer address')
	} $else $if T.unaliased_typ is $struct || T.unaliased_typ is $enum || T.unaliased_typ is $sumtype {
		return error('unsupported print_value aggregate-pointer format')
	} $else {
		return stream.print_address(value)
	}
}

fn io_value_optional_address_dispatch[P](mut stream WriteStream, value ?P) ! {
	$if P.pointee_type is $array_fixed {
		return error('unsupported print_value array-pointer address')
	}
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
