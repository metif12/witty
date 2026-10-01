module zigimg

enum TgaRleState {
	read_header
	repeated
	raw
}

// TargaRLEDecoder plus std.Io.Reader's 512-byte buffering. A failed stream
// call advances its source/state but does not commit the newly written buffer.
struct TgaInput {
mut:
	compressed        bool
	bytes_per_pixel   int
	state             TgaRleState
	repeat_count      int
	repeat_data       []u8
	wrote_repeat_data int
	buffer            [512]u8
	seek              int
	end               int
}

fn (mut input TgaInput) take(mut source ReadStream, count int) ![]u8 {
	if !input.compressed { return source.take(count) }
	assert count >= 0 && count <= 512
	if input.seek + count > input.end {
		if 512 - input.seek < count {
			for i in 0 .. input.end - input.seek {
				input.buffer[i] = input.buffer[input.seek + i]
			}
			input.end -= input.seek
			input.seek = 0
		}
		for input.end < input.seek + count {
			// defaultReadVec uses the whole free capacity, rather than count.
			bytes := input.stream(mut source, 512 - input.end)!
			for i, byte in bytes {
				input.buffer[input.end + i] = byte
			}
			input.end += bytes.len
		}
	}
	mut bytes := []u8{len: count}
	for i in 0 .. count {
		bytes[i] = input.buffer[input.seek + i]
	}
	input.seek += count
	return bytes
}

fn (mut input TgaInput) take_byte(mut source ReadStream) !u8 {
	return input.take(mut source, 1)![0]
}

fn (mut input TgaInput) stream(mut source ReadStream, limit int) ![]u8 {
	mut remaining := limit
	mut bytes := []u8{cap: limit}
	for {
		match input.state {
			.read_header {
				header := source.take_byte()!
				input.repeat_count = int(header & 127) + 1
				if header & 128 != 0 {
					input.state = .repeated
					source.read_slice_all(mut input.repeat_data)!
				} else {
					input.state = .raw
					input.repeat_count *= input.bytes_per_pixel
				}
			}
			.raw {
				if input.repeat_count == 0 {
					input.state = .read_header
					continue
				}
				available := source.buffer.len - source.position
				// Fixed Reader.stream reports EOF even for a zero limit at EOF.
				if available == 0 { return error('EndOfStream') }
				mut count := if remaining < input.repeat_count {
					remaining
				} else {
					input.repeat_count
				}
				if available < count { count = available }
				bytes << source.take(count)!
				input.repeat_count -= count
				remaining -= count
				if input.repeat_count == 0 && remaining > 0 {
					input.state = .read_header
				} else {
					return bytes
				}
			}
			.repeated {
				if input.wrote_repeat_data > 0 && input.wrote_repeat_data < input.repeat_data.len {
					count := if input.repeat_data.len - input.wrote_repeat_data < remaining {
						input.repeat_data.len - input.wrote_repeat_data
					} else {
						remaining
					}
					bytes << input.repeat_data[input.wrote_repeat_data..input.wrote_repeat_data +
						count]
					remaining -= count
					if input.wrote_repeat_data + count == input.repeat_data.len {
						input.wrote_repeat_data = 0
						input.repeat_count--
					} else {
						input.wrote_repeat_data += count
					}
				} else {
					repeat_size := input.repeat_count * input.repeat_data.len
					mut count := input.repeat_count
					if remaining <= repeat_size {
						assert input.repeat_data.len != 0
						count = remaining / input.repeat_data.len
						if count > input.repeat_count { count = input.repeat_count }
					}
					written := count * input.repeat_data.len
					for _ in 0 .. count {
						bytes << input.repeat_data
					}
					if written > 0 {
						input.repeat_count -= count
						remaining -= written
					} else {
						partial := if input.repeat_data.len - input.wrote_repeat_data < remaining {
							input.repeat_data.len - input.wrote_repeat_data
						} else {
							remaining
						}
						bytes << input.repeat_data[input.wrote_repeat_data..
							input.wrote_repeat_data + partial]
						remaining -= partial
						if input.wrote_repeat_data + partial == input.repeat_data.len {
							input.wrote_repeat_data = 0
							input.repeat_count--
						} else {
							input.wrote_repeat_data += partial
						}
					}
				}
				if input.repeat_count == 0 { input.state = .read_header }
				if remaining == 0 { return bytes }
			}
		}
	}
	return bytes
}

fn tga_rle_flush(value []u8, count int, mut writer WriteStream) ! {
	mut remaining := count
	for remaining > 0 {
		length := if remaining < 128 { remaining } else { 128 }
		writer.write_byte(u8(length - 1) | if length >= 2 { u8(128) } else { u8(0) })!
		// Common.flush writes a little-endian integer, atomically per value.
		writer.write_all(value)!
		remaining -= length
	}
}

fn tga_rle_simple(data []u8, bpp int, mut writer WriteStream) ! {
	if data.len == 0 { return }
	mut source := ReadStream.init_memory(data)
	mut compared := source.take(bpp)!
	mut count := 1
	for source.position < data.len {
		value := source.take(bpp)!
		if value == compared {
			count++
		} else {
			tga_rle_flush(compared, count, mut writer)!
			compared = unsafe { value }
			count = 1
		}
	}
	tga_rle_flush(compared, count, mut writer)!
}

fn tga_vector_length(bpp int) int {
	// std.simd.suggestVectorLength for the repository's baseline amd64/arm64
	// targets. Other Zig CPU-feature selections remain a build-model boundary.
	$if amd64 { return 16 / bpp }
	$if arm64 { return 16 / bpp }
	return 4
}

fn tga_rle_simd(data []u8, bpp int, vector_length int, mut writer WriteStream) ! {
	if data.len == 0 { return }
	mut source := ReadStream.init_memory(data)
	mut compared := source.take(bpp)!
	source.seek_to(0)!
	mut index := 0
	mut total := 0
	for index + vector_length * bpp <= data.len {
		value := source.take(bpp)!
		mut similar := 0
		for similar < vector_length
			&& data[index + similar * bpp..index + (similar + 1) * bpp] == value {
			similar++
		}
		assert similar > 0
		if similar == vector_length && compared == value {
			total += similar
			compared = unsafe { value }
		} else if compared == value {
			total += similar
			tga_rle_flush(compared, total, mut writer)!
			compared = unsafe { value }
			total = 0
		} else {
			tga_rle_flush(compared, total, mut writer)!
			compared = unsafe { value }
			total = similar
		}
		index += similar * bpp
		source.discard_all(usize((similar - 1) * bpp))!
	}
	tga_rle_flush(compared, total, mut writer)!
	if index < data.len { tga_rle_simple(data[index..], bpp, mut writer)! }
}

struct TgaRleEncoder {
mut:
	value  []u8
	length int
}

fn (mut encoder TgaRleEncoder) encode(mut writer WriteStream, value []u8) ! {
	if encoder.length == 0 {
		encoder.value = value
		encoder.length = 1
		return
	}
	if encoder.value == value {
		encoder.length++
	} else {
		encoder.flush(mut writer)!
		encoder.value = value
		encoder.length = 1
	}
}

fn (encoder TgaRleEncoder) flush(mut writer WriteStream) ! {
	if encoder.length > 0 { tga_rle_flush(encoder.value, encoder.length, mut writer)! }
}
