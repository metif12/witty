module zigimg

// Pinned compressions/packbits.zig. Output is deliberately not clipped and
// reaching the declared compressed length inside a literal succeeds early.
pub fn packbits_decode(mut stream ReadStream, mut destination []u8, length u32) ! {
	if length == 0 { panic('integer overflow') }
	mut output_offset := u32(0)
	mut input_offset := u32(0)
	for input_offset < length - 1 {
		control := usize(stream.take_byte()!)
		input_offset++
		if control < 128 {
			for _ in 0 .. int(control + 1) {
				if input_offset >= length { return }
				packbits_check_index(output_offset, destination.len)
				destination[int(output_offset)] = stream.take_byte()!
				output_offset++
				input_offset++
			}
		} else if control > 128 {
			if input_offset >= length { return }
			value := stream.take_byte()!
			input_offset++
			for _ in 0 .. int(257 - control) {
				packbits_check_index(output_offset, destination.len)
				destination[int(output_offset)] = value
				output_offset++
			}
		}
	}
}

fn packbits_check_index(index u32, length int) {
	if usize(index) >= usize(length) {
		panic('index out of bounds: index ${index}, len ${length}')
	}
}
