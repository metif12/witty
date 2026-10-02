module zigimg

// Locked zigimg/jpeg/huffman.zig. The key packs the source pair
// (length_minus_one: u4, code: u16) without changing its comparison semantics.
pub struct JpegHuffmanTable {
pub:
	code_counts [16]u8
	code_map map[u32]u8
	fast_table [512]u8
	fast_size [512]u8
	table_class u8
}

pub fn JpegHuffmanTable.read(table_class u8, mut stream ReadStream) !JpegHuffmanTable {
	if table_class & 1 != table_class { return error('InvalidData') }
	mut counts := [16]u8{}
	mut count_slice := unsafe { (&u8(&counts[0])).vbytes(16) }
	if stream.read_slice_short(mut count_slice)! < 16 { return error('InvalidData') }
	mut codes := map[u32]u8{}
	mut fast := [512]u8{init: 255}
	mut sizes := [512]u8{}
	mut code := u16(0)
	for i, count in counts {
		for _ in 0 .. int(count) {
			if u32(code) == (u32(1) << (i + 1)) - 1 { return error('InvalidData') }
			byte := stream.take_byte()!
			codes[u32(i) << 16 | u32(code)] = byte
			if i + 1 <= 9 {
				first := int(code) << (9 - (i + 1))
				count_indexes := 1 << (9 - (i + 1))
				for index in 0 .. count_indexes {
					assert fast[first + index] == 255
					fast[first + index] = byte
					sizes[first + index] = u8(i + 1)
				}
			}
			assert code < 65535
			code++
		}
		code <<= 1
	}
	return JpegHuffmanTable{ code_counts: counts, code_map: codes,
		fast_table: fast, fast_size: sizes, table_class: table_class }
}

pub struct JpegHuffmanReader {
mut:
	table ?JpegHuffmanTable
	stream &ReadStream = unsafe { nil }
	bit_buffer u32
	bit_count u8
}

pub fn JpegHuffmanReader.init(mut stream ReadStream) JpegHuffmanReader {
	return JpegHuffmanReader{ stream: &stream }
}

pub fn (mut reader JpegHuffmanReader) set_huffman_table(table JpegHuffmanTable) { reader.table = table }

pub fn (mut reader JpegHuffmanReader) peek_bits(num_bits u8) !u32 {
	if num_bits > 16 { return error('InvalidData') }
	reader.fill_bits(num_bits)!
	return (reader.bit_buffer >> 1) >> (31 - num_bits)
}

pub fn (mut reader JpegHuffmanReader) fill_bits(num_bits u8) ! {
	for reader.bit_count < num_bits {
		mut current := u32(reader.stream.take_byte()!)
		for current == 0xff {
			next := reader.stream.take_byte()!
			if next == 0 { break }
			else if next == 0xff { continue }
			else if next >= 0xd0 && next <= 0xd7 { current = u32(reader.stream.take_byte()!) }
			else { reader.stream.seek_by(-2)!; return error('InvalidData') }
		}
		reader.bit_buffer |= current << (24 - reader.bit_count)
		assert reader.bit_count <= 23
		reader.bit_count += 8
	}
}

pub fn (mut reader JpegHuffmanReader) consume_bits(num_bits u8) {
	assert num_bits <= reader.bit_count && num_bits <= 16
	reader.bit_buffer <<= num_bits
	reader.bit_count -= num_bits
}

pub fn (mut reader JpegHuffmanReader) read_bits(num_bits u8) !u32 {
	bits := reader.peek_bits(num_bits)!
	reader.consume_bits(num_bits)
	return bits
}

pub fn (mut reader JpegHuffmanReader) flush_bits() {
	if reader.bit_count > 8 && reader.bit_count % 8 != 0 {
		flush := reader.bit_count % 8
		reader.bit_buffer <<= flush
		reader.bit_count -= flush
	} else if reader.bit_count % 8 == 0 { return }
	else if reader.bit_count < 8 { reader.bit_buffer = 0; reader.bit_count = 0 }
	else { panic('unreachable JPEG bit flush') }
}

pub fn (mut reader JpegHuffmanReader) read_code() !u8 {
	fast_index := reader.peek_bits(9) or { 0 }
	table := reader.table or { panic('missing JPEG Huffman table') }
	if reader.bit_count >= 9 {
		value := table.fast_table[int(fast_index)]
		if value != 255 { reader.consume_bits(table.fast_size[int(fast_index)]); return value }
	}
	mut length := if reader.bit_count < 9 { u8(1) } else { u8(10) }
	for length <= 16 {
		code := reader.peek_bits(length)!
		key := u32(length - 1) << 16 | code
		if key in table.code_map { reader.consume_bits(length); return table.code_map[key] }
		length++
	}
	return error('InvalidData')
}

pub fn (mut reader JpegHuffmanReader) read_magnitude_coded(magnitude u8) !int {
	if magnitude == 0 { return 0 }
	mut coefficient := int(reader.peek_bits(magnitude)!)
	reader.consume_bits(magnitude)
	if coefficient < int(1) << (magnitude - 1) { coefficient -= (int(1) << magnitude) - 1 }
	return coefficient
}
