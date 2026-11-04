module zigimg

struct IoPrintSize {
	value ?usize
}

struct IoPrintPart {
	literal   []u8
	index     ?usize
	specifier string
	options   FormatOptions
}

fn io_print_field_index[T](name string) !usize {
	mut index := usize(0)
	$for field in T.fields {
		if field.name == name { return index }
		index++
	}
	return error("no argument with name '${name}'")
}

fn io_print_arg_index[T](specifier FormatSpecifier) !IoPrintSize {
	return match specifier {
		FormatNone { IoPrintSize{} }
		FormatNumber { IoPrintSize{ value: specifier.value } }
		FormatNamed { IoPrintSize{ value: io_print_field_index[T](specifier.bytes.bytestr())! } }
	}
}

fn io_print_optional_size[T](value ?T) !IoPrintSize {
	// Zig can coerce an optional only when its integer child has usize's width.
	if sizeof(T) != sizeof(usize) {
		return error('named format size requires an unsigned integer or usize-sized optional unsigned integer')
	}
	$if T.unaliased_typ !is u8 && T.unaliased_typ !is u16 && T.unaliased_typ !is u32 && T.unaliased_typ !is u64 && T.unaliased_typ !is usize {
		return error('named format size requires an unsigned integer or usize-sized optional unsigned integer')
	}
	payload := value or { return IoPrintSize{} }
	return io_print_size_value[T](payload)
}

fn io_print_size_value[T](value T) !IoPrintSize {
	$if T is $option {
		return io_print_optional_size(value)
	} $else $if T.unaliased_typ is u8 || T.unaliased_typ is u16 || T.unaliased_typ is u32 || T.unaliased_typ is u64 || T.unaliased_typ is usize {
		if u64(value) > u64(~usize(0)) { return error('format size exceeds usize') }
		return IoPrintSize{ value: usize(value) }
	} $else {
		return error('named format size requires an unsigned integer or usize-sized optional unsigned integer')
	}
}

fn io_print_size[T](args T, specifier FormatSpecifier, mut state FormatArgState) !IoPrintSize {
	match specifier {
		FormatNone { return IoPrintSize{} }
		FormatNumber { return IoPrintSize{ value: specifier.value } }
		FormatNamed {
			index := io_print_field_index[T](specifier.bytes.bytestr())!
			state.next_arg(index) or { return error('too few arguments') }
			mut current := usize(0)
			$for field in T.fields {
				if current == index { return io_print_size_value(args.$(field.name)) }
				current++
			}
			return error('too few arguments')
		}
	}
}

fn io_print_value[T](mut stream WriteStream, args T, part IoPrintPart) ! {
	index := part.index or { return stream.write_all(part.literal) }
	mut current := usize(0)
	$for field in T.fields {
		if current == index {
			return io_print_field(mut stream, part, args.$(field.name))
		}
		current++
	}
	return error('too few arguments')
}

// Keep reflected error fields out of V's unused print_value specializations.
fn io_print_field[F](mut stream WriteStream, part IoPrintPart, value F) ! {
	$if F is IError {
		$if F is IoValueFormatter {
			if part.specifier == 'f' { return value.format(mut stream) }
		}
		return io_value_error(mut stream, part.specifier, part.options, value)
	} $else {
		return stream.print_value(part.specifier, part.options, value, 3)
	}
}

// Writer.print's record argument form. V validates the format at runtime.
pub fn (mut stream WriteStream) print[T](format string, args T) ! {
	$if T.unaliased_typ is $struct {
		mut count := usize(0)
		$for field in T.fields {
			_ = field.name
			count++
		}
		if count > 32 { return error('32 arguments max are supported per format call') }
		mut state := FormatArgState{ args_len: count }
		mut parts := []IoPrintPart{}
		mut literal := []u8{}
		mut i := 0
		for {
			start := i
			for i < format.len && format[i] != `{` && format[i] != `}` { i++ }
			literal << format[start..i].bytes()
			if i + 1 < format.len && format[i + 1] == format[i] {
				literal << format[i]
				i += 2
				continue
			}
			if literal.len != 0 {
				parts << IoPrintPart{ literal: literal, index: none }
				literal = []u8{}
			}
			if i >= format.len { break }
			if format[i] == `}` { return error('missing opening {') }
			i++
			begin := i
			for i < format.len && format[i] != `}` { i++ }
			if i >= format.len { return error('missing closing }') }
			placeholder := FormatPlaceholder.parse(format[begin..i].bytes())!
			i++
			position := io_print_arg_index[T](placeholder.arg)!
			width := io_print_size(args, placeholder.width, mut state)!
			precision := io_print_size(args, placeholder.precision, mut state)!
			index := state.next_arg(position.value) or { return error('too few arguments') }
			parts << IoPrintPart{
				index:     index
				specifier: placeholder.specifier_arg.bytestr()
				options:   FormatOptions{
					fill:      placeholder.fill
					alignment: placeholder.alignment
					width:     width.value
					precision: precision.value
				}
			}
		}
		if state.has_unused_args() { return error('unused arguments') }
		for part in parts { io_print_value(mut stream, args, part)! }
	} $else {
		return error('expected struct argument')
	}
}
