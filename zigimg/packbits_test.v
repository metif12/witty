module zigimg

struct PackbitsCase {
	input    []u8
	length   u32
	expected []u8
	position u64
}

fn test_packbits_literal_repeat_noop_and_declared_length_boundaries() {
	for item in [
		PackbitsCase{
			input:    [u8(0), 7]
			length:   2
			expected: [u8(7)]
			position: 2
		},
		PackbitsCase{
			input:    [u8(2), 1, 2, 3, 255, 9]
			length:   6
			expected: [u8(1), 2, 3, 9, 9]
			position: 6
		},
		PackbitsCase{
			input:    [u8(128), 128, 0, 7, 128]
			length:   5
			expected: [u8(7)]
			position: 4
		},
		PackbitsCase{
			input:    [u8(3), 1, 2, 3, 4]
			length:   3
			expected: [u8(1), 2]
			position: 3
		},
		PackbitsCase{
			input:    [u8(128), 255, 9]
			length:   2
			expected: []
			position: 1
		},
		PackbitsCase{
			input:    []
			length:   1
			expected: []
			position: 0
		},
	] {
		mut output := []u8{len: 140, init: 99}
		mut reader := ReadStream.init_memory(item.input)
		packbits_decode(mut reader, mut output, item.length)!
		assert output[..item.expected.len] == item.expected
		assert output[item.expected.len..] == []u8{len: 140 - item.expected.len, init: 99}
		assert reader.get_pos() == item.position
	}
	mut output := []u8{len: 128}
	mut reader := ReadStream.init_memory([u8(129), 8])
	packbits_decode(mut reader, mut output, 2)!
	assert output == []u8{len: 128, init: 8}
	mut literals := [u8(127)]
	literals << []u8{len: 128, init: 6}
	reader = ReadStream.init_memory(literals)
	packbits_decode(mut reader, mut output, 129)!
	assert output == []u8{len: 128, init: 6}
}

fn test_packbits_physical_eof_consumes_available_literal_prefix() {
	for input in [[u8(2), 1, 2], [u8(255)], []u8{}] {
		mut output := []u8{len: 4, init: 99}
		mut reader := ReadStream.init_memory(input)
		packbits_decode(mut reader, mut output, 4) or {
			assert err.msg() == 'EndOfStream' && reader.get_pos() == u64(input.len)
			assert output == if input.len == 3 {
				[u8(1), 2, 99, 99]
			} else {
				[u8(99), 99, 99, 99]
			}
			continue
		}
		assert false
	}
}
