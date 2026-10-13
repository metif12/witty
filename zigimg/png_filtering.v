module zigimg

fn png_average(a u16, b u16) u8 {
	return u8((a + b) / 2)
}

fn png_paeth(a u8, b u8, c u8) u8 {
	p := int(a) + int(b) - int(c)
	da := if p >= int(a) { p - int(a) } else { int(a) - p }
	db := if p >= int(b) { p - int(b) } else { int(b) - p }
	dc := if p >= int(c) { p - int(c) } else { int(c) - p }
	if da <= db && da <= dc { return a }
	if db <= dc { return b }
	return c
}

fn png_filter_byte(filter PngFilterType, sample u8, previous u8, above u8, above_previous u8) u8 {
	return match filter {
		.none { sample }
		.sub { sample - previous }
		.up { sample - above }
		.average { sample - png_average(previous, above) }
		.paeth { sample - png_paeth(previous, above, above_previous) }
	}
}

fn png_filter_choice_heuristic(scanline []u8, previous_scanline []u8) PngFilterType {
	mut previous_bytes := [5]u8{}
	mut combos := [5]usize{}
	mut scores := [5]usize{}
	filters := [PngFilterType.none, .sub, .up, .average, .paeth]!
	// The pinned heuristic uses scanline.len as pixel_len, so the horizontal
	// neighbors are always zero. It does not score the final unfinished run.
	for index, sample in scanline {
		above := previous_scanline[index]
		for filter_index, filter in filters {
			byte := png_filter_byte(filter, sample, 0, above, 0)
			if byte == previous_bytes[filter_index] {
				if combos[filter_index] == ~usize(0) { panic('integer overflow') }
				combos[filter_index]++
			} else {
				combo := combos[filter_index]
				if combo != 0 && combo > ~usize(0) / combo { panic('integer overflow') }
				score := combo * combo
				if scores[filter_index] > ~usize(0) - score { panic('integer overflow') }
				scores[filter_index] += score
				combos[filter_index] = 0
				previous_bytes[filter_index] = byte
			}
		}
	}
	mut best := PngFilterType.none
	mut max_score := usize(0)
	for index, score in scores {
		if score > max_score {
			max_score = score
			best = filters[index]
		}
	}
	return best
}

fn png_fill_scanline(pixels PixelStorage, mut scanline []u8, y usize, width usize) {
	begin := image_pixel_count(y, width)
	if y == ~usize(0) { panic('integer overflow') }
	end := image_pixel_count(y + 1, width)
	// PixelStorage.slice preserves Source's native-width range diagnostics.
	source := pixels.slice(begin, end).as_const_bytes()
	// These two source bitsPerChannel branches are explicitly unreachable.
	if pixels.pixel_format() in [PixelFormat.rgb332, .rgb565] {
		panic('reached unreachable code')
	}
	depth := pixels.pixel_format().bits_per_channel()
	match depth {
		1, 2, 4 {
			for mut byte in scanline {
				byte = 0
			}
			mut destination_index := 0
			mut shift := 8 - int(depth)
			mask := u8((u16(1) << depth) - 1)
			for byte in source {
				if destination_index >= scanline.len {
					panic('index out of bounds: index ${destination_index}, len ${scanline.len}')
				}
				scanline[destination_index] |= (byte & mask) << shift
				shift -= int(depth)
				if shift < 0 {
					destination_index++
					if destination_index >= scanline.len { break
					 }
					shift = 8 - int(depth)
				}
			}
		}
		8 {
			if scanline.len != source.len {
				panic('source and destination arguments have non-equal lengths')
			}
			copy(mut scanline, source)
		}
		16 {
			if source.len % 2 != 0 { panic('exact division produced remainder') }
			if scanline.len % 2 != 0 { panic('exact division produced remainder') }
			for index in 0 .. scanline.len / 2 {
				// Source indexes native u16 slices before loading their bytes.
				if index >= source.len / 2 {
					panic('index out of bounds: index ${index}, len ${source.len / 2}')
				}
				$if little_endian {
					scanline[index * 2] = source[index * 2 + 1]
					scanline[index * 2 + 1] = source[index * 2]
				} $else {
					scanline[index * 2] = source[index * 2]
					scanline[index * 2 + 1] = source[index * 2 + 1]
				}
			}
		}
		else {}
	}
}

// The public filtering function from png/filtering.zig. PNG.write does not
// call it in the pinned revision, whose writeData body is commented out.
pub fn png_filter(mut writer WriteStream, pixels PixelStorage, choice PngFilterChoice, header PngHeaderData) ! {
	line_bytes := header.line_bytes()
	if line_bytes > u32(0xffffffff) / 2 { panic('integer overflow') }
	mut previous := []u8{len: int(line_bytes)}
	mut current := []u8{len: int(line_bytes)}
	pixel_len := int(pixels.pixel_format().pixel_stride())
	for y := u32(0); y < header.height; y++ {
		png_fill_scanline(pixels, mut current, usize(y), usize(header.width))
		filter := match choice {
			PngTryAll { panic('Unimplemented') }
			PngHeuristic { png_filter_choice_heuristic(current, previous) }
			PngSpecified { choice.filter }
		}

		writer.write_byte(u8(filter)) or { return error('InvalidData') }
		for index, sample in current {
			before := if index >= pixel_len { current[index - pixel_len] } else { u8(0) }
			above_before := if index >= pixel_len { previous[index - pixel_len] } else { u8(0) }
			writer.write_byte(png_filter_byte(filter, sample, before, previous[index], above_before)) or {
				return error('InvalidData')
			}
		}
		copy(mut previous, current)
	}
}

fn png_defilter(mut current []u8, previous []u8, stride u8) ! {
	if stride == 0 { panic('integer overflow') }
	filter := current[int(stride) - 1]
	if filter > 4 { return error('InvalidData') }
	current[int(stride) - 1] = 0
	for index in int(stride) .. current.len {
		prediction := match filter {
			0 { u8(0) }
			1 { current[index - stride] }
			2 { previous[index] }
			3 { png_average(current[index - stride], previous[index]) }
			else { png_paeth(current[index - stride], previous[index], previous[index - stride]) }
		}

		current[index] += prediction
	}
}

fn png_spread_row_data(mut destination []u8, source []u8, depth u8, channels u8, stride u8, byteswap bool) {
	mut dest_index := 0
	mut source_index := 0
	match depth {
		1, 2, 4 {
			for dest_index < destination.len {
				mut shift := 8 - int(depth)
				mut mask := u8(u16(255) << shift)
				for shift >= 0 && dest_index < destination.len {
					destination[dest_index] = (source[source_index] & mask) >> shift
					dest_index += int(stride)
					mask >>= depth
					shift -= int(depth)
				}
				source_index++
			}
		}
		8 {
			for dest_index < destination.len {
				for channel in 0 .. int(channels) {
					destination[dest_index + channel] = source[source_index + channel]
				}
				dest_index += int(stride)
				source_index += int(channels)
			}
		}
		16 {
			// Source converts the current row before the destination row.
			if source.len % 2 != 0 { panic('exact division produced remainder') }
			if destination.len % 2 != 0 { panic('exact division produced remainder') }
			stride16 := int(stride / 2)
			for dest_index < destination.len / 2 {
				for channel in 0 .. int(channels) {
					dest_at := (dest_index + channel) * 2
					source_at := (source_index + channel) * 2
					destination[dest_at] = source[source_at + if byteswap { 1 } else { 0 }]
					destination[dest_at + 1] = source[source_at + if byteswap { 0 } else { 1 }]
				}
				dest_index += stride16
				source_index += int(channels)
			}
		}
		else {
			panic('reached unreachable code')
		}
	}
}
