module zigimg

fn io_vector_lanes[E](mut stream WriteStream, format string, options FormatOptions, lanes []E, max_depth usize) ! {
	$if E is $option {
		$compile_error('print_vector requires native numeric or boolean lanes')
	} $else $if E.indirections > 0 || ((int(E.unaliased_typ) >> 16) &0xff) > 0 {
		$compile_error('print_vector requires native numeric or boolean lanes')
	} $else $if E.unaliased_typ is $int || E.unaliased_typ is f32 || E.unaliased_typ is f64 || E.unaliased_typ is bool {
		if max_depth == 0 { return stream.write_all('{ ... }'.bytes()) }
		stream.write_all('{ '.bytes())!
		for i, lane in lanes {
			stream.print_value[E](format, options, lane, max_depth - 1)!
			if i + 1 < lanes.len { stream.write_all(', '.bytes())! }
		}
		return stream.write_all(' }'.bytes())
	} $else {
		$compile_error('print_vector requires native numeric or boolean lanes')
	}
}

// Fixed arrays carry Source SIMD lanes without changing ordinary array dispatch.
pub fn (mut stream WriteStream) print_vector[A](format string, options FormatOptions, value A, max_depth usize) ! {
	$if A.unaliased_typ is $array_fixed {
		return io_vector_lanes(mut stream, format, options, value[..], max_depth)
	} $else {
		$compile_error('print_vector requires an inline fixed array')
	}
}
