module zigimg

fn io_vector_lanes[E](mut stream WriteStream, format string, options FormatOptions, lanes []E, max_depth usize) ! {
	$if E is $option {
		$if E.indirections != 1 && ((int(E.unaliased_typ) >> 16) &0xff) != 1 {
			$compile_error('print_vector requires native numeric, boolean or pointer lanes')
		}
	} $else $if E.unaliased_typ !is voidptr && E.indirections == 0 && ((int(E.unaliased_typ) >> 16) &0xff) == 0 {
		$if E.unaliased_typ !is $int && E.unaliased_typ !is f32 && E.unaliased_typ !is f64 && E.unaliased_typ !is bool {
			$compile_error('print_vector requires native numeric, boolean or pointer lanes')
		}
	}
	if max_depth == 0 { return stream.write_all('{ ... }'.bytes()) }
	stream.write_all('{ '.bytes())!
	for i in 0 .. lanes.len {
		$if E !is $option && E is $alias && ((int(E.unaliased_typ) >> 16) &0xff) > 0 {
			// Avoid V merging alias and optional-pointer generic specializations.
			mut normalized := $zero(E.unaliased_typ)
			lane := lanes[i]
			unsafe { vmemcpy(&normalized, &lane, int(sizeof(E))) }
			stream.print_value(format, options, normalized, max_depth - 1)!
		} $else {
			stream.print_value[E](format, options, lanes[i], max_depth - 1)!
		}
		if i + 1 < lanes.len { stream.write_all(', '.bytes())! }
	}
	return stream.write_all(' }'.bytes())
}

// Fixed arrays carry Source SIMD lanes without changing ordinary array dispatch.
pub fn (mut stream WriteStream) print_vector[A](format string, options FormatOptions, value A, max_depth usize) ! {
	$if A.unaliased_typ is $array_fixed {
		return io_vector_lanes(mut stream, format, options, value[..], max_depth)
	} $else {
		$compile_error('print_vector requires an inline fixed array')
	}
}
