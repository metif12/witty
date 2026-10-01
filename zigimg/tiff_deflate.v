module zigimg

// The zlib/indirect-reader path of Zig 0.15.2 std.compress.flate.Decompress,
// as used by pinned TIFF. This is deliberately not V's zlib decoder: the
// source ignores FCHECK/FDICT/checksums and buffers output before streaming it.
const tiff_flate_length_base = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43,
	51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]!
const tiff_flate_length_extra = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4,
	4, 4, 4, 5, 5, 5, 5, 0]!
const tiff_flate_distance_base = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257,
	385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]!
const tiff_flate_distance_extra = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8,
	9, 9, 10, 10, 11, 11, 12, 12, 13, 13]!
const tiff_flate_codegen_order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1,
	15]!

enum TiffFlateState {
	protocol_header
	block_header
	stored_block
	fixed_block
	dynamic_block
	dynamic_block_literal
	dynamic_block_match
	protocol_footer
	end
}

struct TiffFlateSymbol {
	value int
	bits  u8
}

struct TiffFlateTree {
	max_bits int
	lookup   []TiffFlateSymbol
}

fn tiff_flate_tree(lengths []u8, alphabet int, max_bits int) !TiffFlateTree {
	if alphabet == 286 && lengths[256] == 0 { return error('MissingEndOfBlockCode') }
	mut counts := []int{len: max_bits + 1}
	mut longest := 0
	for length in lengths {
		if length == 0 { continue
		 }
		if int(length) > longest { longest = int(length) }
		counts[int(length)]++
	}
	if longest != 0 {
		mut left := 1
		for length in 1 .. counts.len {
			left <<= 1
			if counts[length] > left { return error('OversubscribedHuffmanTree') }
			left -= counts[length]
		}
		if left > 0 && !(max_bits > 7 && longest == counts[0] + counts[1]) {
			return error('IncompleteHuffmanTree')
		}
	}
	// Canonical codes have the same order as Symbol.asc (length, kind, symbol).
	// A full table replaces the source's small lookup and linked-list fallback.
	mut lookup := []TiffFlateSymbol{len: 1 << max_bits}
	mut code := 0
	for length in 1 .. max_bits + 1 {
		for symbol in 0 .. alphabet {
			if symbol >= lengths.len || lengths[symbol] != length { continue
			 }
			span := 1 << (max_bits - length)
			for index in code .. code + span {
				lookup[index] = TiffFlateSymbol{
					value: symbol
					bits:  u8(length)
				}
			}
			code += span
		}
	}
	return TiffFlateTree{
		max_bits: max_bits
		lookup:   lookup
	}
}

fn (tree TiffFlateTree) find(code u64) !TiffFlateSymbol {
	symbol := tree.lookup[int(code)]
	if symbol.bits == 0 { return error('InvalidCode') }
	return symbol
}

struct TiffFlate {
mut:
	bits           u64
	remaining_bits int
	state          TiffFlateState = .protocol_header
	final_block    bool
	stored_length  int
	literal        u8
	match_length   int
	literal_tree   TiffFlateTree
	distance_tree  TiffFlateTree
	window         []u8 = []u8{len: 65536}
	seek           int
	end            int
}

fn tiff_flate_reverse(value u64, count int) u64 {
	mut result := u64(0)
	for index in 0 .. count {
		result = (result << 1) | ((value >> index) & 1)
	}
	return result
}

fn tiff_flate_word(bytes []u8) u64 {
	mut result := u64(0)
	for index, byte in bytes {
		result |= u64(byte) << (index * 8)
	}
	return result
}

fn (mut decoder TiffFlate) take_bits(mut input ReadStream, count int) !u64 {
	mask := (u64(1) << count) - 1
	if decoder.remaining_bits >= count {
		result := decoder.bits & mask
		decoder.bits >>= count
		decoder.remaining_bits -= count
		return result
	}
	word_size := int(sizeof(usize))
	available := input.buffer.len - input.position
	read_size := if available >= word_size { word_size } else { available }
	needed := count - decoder.remaining_bits
	if read_size * 8 < needed { return error('EndOfStream') }
	word := tiff_flate_word(input.take(read_size)!)
	result := (((word & ((u64(1) << needed) - 1)) << decoder.remaining_bits) | decoder.bits) & mask
	decoder.bits = word >> needed
	decoder.remaining_bits = read_size * 8 - needed
	return result
}

fn (decoder TiffFlate) peek_bits(input ReadStream, count int) !u64 {
	mask := (u64(1) << count) - 1
	if decoder.remaining_bits >= count { return decoder.bits & mask }
	word_size := int(sizeof(usize))
	available := input.buffer.len - input.position
	mut read_size := word_size
	if available < word_size {
		needed := (count - decoder.remaining_bits + 7) / 8
		read_size = if available < needed { available } else { needed }
		if decoder.remaining_bits == 0 && read_size == 0 { return error('EndOfStream') }
	}
	word := tiff_flate_word(input.peek(read_size)!)
	return ((word << decoder.remaining_bits) | decoder.bits) & mask
}

fn (mut decoder TiffFlate) toss_bits(mut input ReadStream, count int) ! {
	if decoder.remaining_bits >= count {
		decoder.bits >>= count
		decoder.remaining_bits -= count
		return
	}
	word_size := int(sizeof(usize))
	available := input.buffer.len - input.position
	read_size := if available >= word_size { word_size } else { available }
	if read_size == 0 { return error('EndOfStream') }
	needed := count - decoder.remaining_bits
	word := tiff_flate_word(input.take(read_size)!)
	decoder.bits = word >> needed
	decoder.remaining_bits = if read_size * 8 > needed { read_size * 8 - needed } else { 0 }
}

fn (mut decoder TiffFlate) runtime_bits(mut input ReadStream, count int) !int {
	value := decoder.peek_bits(input, 16)!
	result := int(value & ((u64(1) << count) - 1))
	decoder.toss_bits(mut input, count)!
	return result
}

fn (mut decoder TiffFlate) align_bits(mut input ReadStream) {
	input.position -= decoder.remaining_bits / 8
	decoder.remaining_bits = 0
	decoder.bits = 0
}

fn (mut decoder TiffFlate) symbol(mut input ReadStream, tree TiffFlateTree) !TiffFlateSymbol {
	peeked := decoder.peek_bits(input, tree.max_bits)!
	symbol := tree.find(tiff_flate_reverse(peeked, tree.max_bits))!
	decoder.toss_bits(mut input, int(symbol.bits))!
	return symbol
}

fn (mut decoder TiffFlate) length(mut input ReadStream, code int) !int {
	if code > 28 { return error('InvalidCode') }
	extra := tiff_flate_length_extra[code]
	return tiff_flate_length_base[code] + if extra == 0 {
		0
	} else {
		decoder.runtime_bits(mut input, extra)!
	}
}

fn (mut decoder TiffFlate) distance(mut input ReadStream, code int) !int {
	if code > 29 { return error('InvalidCode') }
	extra := tiff_flate_distance_extra[code]
	return tiff_flate_distance_base[code] + if extra == 0 {
		0
	} else {
		decoder.runtime_bits(mut input, extra)!
	}
}

fn (mut decoder TiffFlate) write_match(length int, distance int) ! {
	if decoder.end < distance || length < 3 || length > 258 || distance < 1 || distance > 32768 {
		return error('InvalidMatch')
	}
	// The source's indirect writer uses unreachableRebase, including when a
	// fixed-block match straddles the end of the 64 KiB window.
	assert length <= decoder.window.len - decoder.end
	start := decoder.end
	decoder.end += length
	for index in 0 .. length {
		decoder.window[start + index] = decoder.window[start - distance + index]
	}
}

fn (mut decoder TiffFlate) fixed_code(mut input ReadStream) !int {
	code := int(tiff_flate_reverse(decoder.take_bits(mut input, 7)!, 7))
	if code <= 23 { return code + 256 }
	if code <= 95 { return code * 2 + int(decoder.take_bits(mut input, 1)!) - 48 }
	if code <= 99 { return (code - 96) * 2 + int(decoder.take_bits(mut input, 1)!) + 280 }
	return (code - 100) * 4 + int(tiff_flate_reverse(decoder.take_bits(mut input, 2)!, 2)) + 144
}

fn (mut decoder TiffFlate) dynamic_header(mut input ReadStream) ! {
	hlit := int(decoder.take_bits(mut input, 5)!) + 257
	hdist := int(decoder.take_bits(mut input, 5)!) + 1
	hclen := int(decoder.take_bits(mut input, 4)!) + 4
	if hlit > 286 || hdist > 30 { return error('InvalidDynamicBlockHeader') }
	mut code_lengths := []u8{len: 19}
	for index in 0 .. hclen {
		code_lengths[tiff_flate_codegen_order[index]] = u8(decoder.take_bits(mut input, 3)!)
	}
	tree := tiff_flate_tree(code_lengths, 19, 7)!
	mut lengths := []u8{len: 316}
	mut position := 0
	for position < hlit + hdist {
		code := decoder.symbol(mut input, tree)!.value
		if position >= lengths.len { return error('InvalidDynamicBlockHeader') }
		match code {
			0...15 {
				lengths[position] = u8(code)
				position++
			}
			16 {
				count := int(decoder.take_bits(mut input, 2)!) + 3
				if position == 0 || position + count > lengths.len {
					return error('InvalidDynamicBlockHeader')
				}
				for index in 0 .. count {
					lengths[position + index] = lengths[position + index - 1]
				}
				position += count
			}
			17 {
				position += int(decoder.take_bits(mut input, 3)!) + 3
			}
			18 {
				position += int(decoder.take_bits(mut input, 7)!) + 11
			}
			else {
				return error('InvalidDynamicBlockHeader')
			}
		}
	}
	if position > hlit + hdist { return error('InvalidDynamicBlockHeader') }
	decoder.literal_tree = tiff_flate_tree(lengths[..hlit], 286, 15)!
	decoder.distance_tree = tiff_flate_tree(lengths[hlit..hlit + hdist], 30, 15)!
}

fn (mut decoder TiffFlate) fill_window(mut input ReadStream) ! {
	if decoder.window.len - decoder.end < 32768 {
		discard := if decoder.seek < decoder.end - 32768 {
			decoder.seek
		} else {
			decoder.end - 32768
		}
		keep := decoder.end - discard
		for index in 0 .. keep {
			decoder.window[index] = decoder.window[discard + index]
		}
		decoder.end = keep
		decoder.seek -= discard
	}
	mut remaining := decoder.window.len - decoder.end
	// Local state matches Zig's labeled switch: only the explicit yield points
	// update the saved state. Errors abandon this fill's output before streaming.
	mut state := decoder.state
	for {
		match state {
			.protocol_header {
				header := input.take(2)!
				if header[0] & 15 != 8 || header[0] >> 4 > 7 { return error('BadZlibHeader') }
				state = .block_header
			}
			.block_header {
				decoder.final_block = decoder.take_bits(mut input, 1)! != 0
				match int(decoder.take_bits(mut input, 2)!) {
					0 {
						decoder.align_bits(mut input)
						length := int(tiff_u16(input.take(2)!, .little))
						complement := tiff_u16(input.take(2)!, .little)
						if u16(length) != u16(~complement) { return error('WrongStoredBlockNlen') }
						decoder.stored_length = length
						state = .stored_block
					}
					1 {
						state = .fixed_block
					}
					2 {
						decoder.dynamic_header(mut input)!
						state = .dynamic_block
					}
					else {
						return error('InvalidBlockType')
					}
				}
			}
			.stored_block {
				assert decoder.end < decoder.window.len
				count := if decoder.stored_length < remaining {
					decoder.stored_length
				} else {
					remaining
				}
				available := input.buffer.len - input.position
				if count > 0 && available == 0 { return error('EndOfStream') }
				read_count := if available < count { available } else { count }
				bytes := input.take(read_count)!
				for index, byte in bytes {
					decoder.window[decoder.end + index] = byte
				}
				decoder.end += read_count
				decoder.stored_length -= read_count
				decoder.state = if decoder.stored_length == 0 {
					if decoder.final_block {
						TiffFlateState.protocol_footer
					} else {
						TiffFlateState.block_header
					}
				} else {
					TiffFlateState.stored_block
				}
				return
			}
			.fixed_block {
				for remaining > 0 {
					code := decoder.fixed_code(mut input)!
					if code < 256 {
						decoder.window[decoder.end] = u8(code)
						decoder.end++
						remaining--
					} else if code == 256 {
						decoder.state = if decoder.final_block {
							TiffFlateState.protocol_footer
						} else {
							TiffFlateState.block_header
						}
						return
					} else if code <= 285 {
						length := decoder.length(mut input, code - 257)!
						distance := decoder.distance(mut input,
							int(tiff_flate_reverse(decoder.take_bits(mut input, 5)!, 5)))!
						decoder.write_match(length, distance)!
						assert remaining >= length
						remaining -= length
					} else {
						return error('InvalidCode')
					}
				}
				decoder.state = .fixed_block
				return
			}
			.dynamic_block {
				symbol := decoder.symbol(mut input, decoder.literal_tree)!.value
				if symbol < 256 {
					if remaining > 0 {
						decoder.window[decoder.end] = u8(symbol)
						decoder.end++
						remaining--
					} else {
						decoder.literal = u8(symbol)
						decoder.state = .dynamic_block_literal
						return
					}
				} else if symbol == 256 {
					decoder.state = if decoder.final_block {
						TiffFlateState.protocol_footer
					} else {
						TiffFlateState.block_header
					}
					state = decoder.state
				} else {
					decoder.match_length = decoder.length(mut input, symbol - 257)!
					state = .dynamic_block_match
				}
			}
			.dynamic_block_literal {
				assert remaining > 0
				decoder.window[decoder.end] = decoder.literal
				decoder.end++
				remaining--
				state = .dynamic_block
			}
			.dynamic_block_match {
				if remaining >= decoder.match_length {
					remaining -= decoder.match_length
					code := decoder.symbol(mut input, decoder.distance_tree)!.value
					distance := decoder.distance(mut input, code)!
					decoder.write_match(decoder.match_length, distance)!
					state = .dynamic_block
				} else {
					decoder.state = .dynamic_block_match
					return
				}
			}
			.protocol_footer {
				decoder.align_bits(mut input)
				// Zig stores this little-endian word as metadata without checking it.
				input.take(4)!
				decoder.state = .end
				return
			}
			.end {
				return error('EndOfStream')
			}
		}
	}
}

fn tiff_zlib_stream(mut input ReadStream, mut output WriteStream) ! {
	mut decoder := TiffFlate{}
	for {
		if decoder.end > decoder.seek {
			output.write_all(decoder.window[decoder.seek..decoder.end])!
			decoder.seek = decoder.end
		} else {
			decoder.fill_window(mut input) or {
				if err.msg() == 'EndOfStream' && decoder.state == .end { return }
				return error('ReadFailed')
			}
		}
	}
}
