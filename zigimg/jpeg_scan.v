module zigimg

// Locked zigimg/jpeg/Scan.zig, retaining both baseline and progressive scans.
struct JpegScanComponentSpec {
	component_id u8
	dc_table_selector u8
	ac_table_selector u8
}

fn jpeg_scan_component_read(mut stream ReadStream) !JpegScanComponentSpec {
	id := stream.take_byte()!
	selectors := stream.take_byte()!
	return JpegScanComponentSpec{ component_id: id, dc_table_selector: selectors >> 4,
		ac_table_selector: selectors & 3 }
}

struct JpegScanSkips { mut: value u32 }

struct JpegScan {
mut:
	frame &JpegFrame = unsafe { nil }
	reader JpegHuffmanReader
	components []?JpegScanComponentSpec = []?JpegScanComponentSpec{len: 4}
	component_count int
	start_of_spectral_selection int
	end_of_spectral_selection int
	approximation_high u8
	approximation_low u8
	prediction_values [3]int
}

fn jpeg_scan_init(mut frame JpegFrame, mut stream ReadStream) !JpegScan {
	segment_size := jpeg_u16(mut stream)!
	count := int(stream.take_byte()!)
	if count < 1 || count > 4 { return error('InvalidData') }
	mut components := []?JpegScanComponentSpec{len: 4}
	for i in 0 .. count {
		component := jpeg_scan_component_read(mut stream)!
		components[i] = component
		mut valid := false
		for frame_component in frame.frame_header.components {
			if frame_component.id == component.component_id { valid = true }
		}
		// Preserve the source's OR validity tests rather than introducing a
		// stricter component/table validation rule.
		if frame.owner.dc_huffman_tables[int(component.dc_table_selector)] != none { valid = true }
		if frame.owner.ac_huffman_tables[int(component.ac_table_selector)] != none { valid = true }
		if !valid { return error('InvalidData') }
	}
	start := int(stream.take_byte()!)
	end := int(stream.take_byte()!)
	if start > 63 || end > 63 || end < start { return error('InvalidData') }
	if frame.frame_type == 0xffc0 && (start != 0 || end != 63) { return error('InvalidData') }
	if frame.frame_type == 0xffc2 {
		any_zero := start == 0 || end == 0
		both_zero := start == 0 && end == 0
		if any_zero && !both_zero { return error('InvalidData') }
	}
	approximation := stream.take_byte()!
	assert int(segment_size) == 2 * count + 6
	return JpegScan{ frame: &frame, reader: JpegHuffmanReader.init(mut stream), components: components,
		component_count: count, start_of_spectral_selection: start, end_of_spectral_selection: end,
		approximation_high: approximation >> 4, approximation_low: approximation & 15 }
}

fn jpeg_perform_scan(mut frame JpegFrame, restart_interval u16, mut stream ReadStream) ! {
	mut scan := jpeg_scan_init(mut frame, mut stream)!
	mut skips := JpegScanSkips{}
	first := scan.components[0] or { panic('missing JPEG scan component') }
	noninterleaved := scan.component_count == 1 && first.component_id == 1
	y_step := if noninterleaved { 1 } else { frame.vertical_sampling_factor_max }
	x_step := if noninterleaved { 1 } else { frame.horizontal_sampling_factor_max }
	mut y := 0
	for y < frame.block_height {
		mut x := 0
		for x < frame.block_width {
			mcu_id := y * frame.block_width_actual + x
			if restart_interval != 0 && mcu_id % (int(restart_interval) * y_step * x_step) == 0 {
				scan.reader.flush_bits()
				scan.prediction_values = [3]int{}
				skips.value = 0
			}
			for index in 0 .. scan.component_count {
				component := scan.components[index] or { panic('missing JPEG scan component') }
				mut component_index := -1
				mut v_max := 0
				mut h_max := 0
				for i, fc in frame.frame_header.components {
					if fc.id == component.component_id {
						component_index = i
						v_max = if noninterleaved { 1 } else { int(fc.vertical_sampling_factor) }
						h_max = if noninterleaved { 1 } else { int(fc.horizontal_sampling_factor) }
						break
					}
				}
				// The source leaves these values undefined when its earlier OR
				// validation accepts an unknown component. Such input is undefined.
				assert component_index >= 0
				for v in 0 .. v_max {
					for h in 0 .. h_max {
						id := (y + v) * frame.block_width_actual + x + h
						scan.reader.fill_bits(24) or {}
						if frame.frame_type == 0xffc0 {
							scan.decode_block_baseline(component, mut frame.block_storage[id].blocks[component_index], component_index)!
						} else if frame.frame_type == 0xffc2 {
							scan.decode_block_progressive(component, mut frame.block_storage[id].blocks[component_index], component_index, mut skips)!
						}
					}
				}
			}
			x += x_step
		}
		y += y_step
	}
}

fn (mut scan JpegScan) dc_table(component JpegScanComponentSpec) {
	table := scan.frame.owner.dc_huffman_tables[int(component.dc_table_selector)] or { panic('missing JPEG DC table') }
	scan.reader.set_huffman_table(table)
}
fn (mut scan JpegScan) ac_table(component JpegScanComponentSpec) {
	table := scan.frame.owner.ac_huffman_tables[int(component.ac_table_selector)] or { panic('missing JPEG AC table') }
	scan.reader.set_huffman_table(table)
}

fn (mut scan JpegScan) decode_block_baseline(component JpegScanComponentSpec, mut block JpegBlock, destination int) ! {
	scan.dc_table(component)
	mut magnitude := scan.reader.read_code()!
	if magnitude > 11 { return error('InvalidData') }
	diff := scan.reader.read_magnitude_coded(magnitude)!
	dc := diff + scan.prediction_values[destination]
	scan.prediction_values[destination] = dc
	block.values[0] = dc
	scan.ac_table(component)
	mut ac := 1
	for ac < 64 {
		run_magnitude := scan.reader.read_code()!
		if run_magnitude == 0 {
			for ac < 64 { block.values[jpeg_zigzag_offsets[ac]] = 0; ac++ }
			return
		}
		zero_run := run_magnitude >> 4
		magnitude = run_magnitude & 15
		if magnitude > 10 { return error('InvalidData') }
		coefficient := scan.reader.read_magnitude_coded(magnitude)!
		assert coefficient >= -1024 && coefficient <= 1023
		for _ in 0 .. int(zero_run) { block.values[jpeg_zigzag_offsets[ac]] = 0; ac++ }
		block.values[jpeg_zigzag_offsets[ac]] = coefficient
		ac++
	}
}

fn (mut scan JpegScan) decode_block_progressive(component JpegScanComponentSpec, mut block JpegBlock, component_index int, mut skips JpegScanSkips) ! {
	if scan.start_of_spectral_selection == 0 {
		scan.dc_table(component)
		if scan.approximation_high == 0 {
			magnitude := scan.reader.read_code()!
			if magnitude > 11 { return error('InvalidData') }
			diff := scan.reader.read_magnitude_coded(magnitude)!
			dc := diff + scan.prediction_values[component_index]
			scan.prediction_values[component_index] = dc
			block.values[0] = dc << scan.approximation_low
		} else {
			bit := scan.reader.read_bits(1)!
			block.values[0] += int(bit << scan.approximation_low)
		}
	} else {
		scan.ac_table(component)
		if scan.approximation_high == 0 {
			mut ac := scan.start_of_spectral_selection
			if skips.value == 0 {
				for ac <= scan.end_of_spectral_selection {
					mut coefficient := 0
					run_magnitude := scan.reader.read_code()!
					zero_run := run_magnitude >> 4
					magnitude := run_magnitude & 15
					if magnitude == 0 {
						if zero_run < 15 {
							extra := scan.reader.read_bits(zero_run)!
							skips.value = (u32(1) << zero_run) + extra
							break
						}
					} else {
						if magnitude > 10 { return error('InvalidData') }
						coefficient = scan.reader.read_magnitude_coded(magnitude)!
					}
					for _ in 0 .. int(zero_run) { block.values[jpeg_zigzag_offsets[ac]] = 0; ac++ }
					block.values[jpeg_zigzag_offsets[ac]] = coefficient << scan.approximation_low
					ac++
				}
			}
			if skips.value > 0 {
				skips.value--
				for ac <= scan.end_of_spectral_selection { block.values[jpeg_zigzag_offsets[ac]] = 0; ac++ }
			}
		} else {
			bit := int(1) << scan.approximation_low
			mut ac := scan.start_of_spectral_selection
			if skips.value == 0 {
				for ac <= scan.end_of_spectral_selection {
					mut coefficient := 0
					run_magnitude := scan.reader.read_code()!
					mut zero_run := run_magnitude >> 4
					magnitude := run_magnitude & 15
					if magnitude == 0 {
						if zero_run < 15 {
							skips.value = u32(1) << zero_run
							skips.value += scan.reader.read_bits(zero_run)!
							break
						}
					} else { coefficient = if scan.reader.read_bits(1)! == 1 { bit } else { -bit } }
					for ac <= scan.end_of_spectral_selection {
						if block.values[jpeg_zigzag_offsets[ac]] == 0 {
							if zero_run > 0 { zero_run--; ac++ }
							else { block.values[jpeg_zigzag_offsets[ac]] = coefficient; ac++; break }
						} else {
							if scan.reader.read_bits(1)! != 0 {
								block.values[jpeg_zigzag_offsets[ac]] += if block.values[jpeg_zigzag_offsets[ac]] > 0 { bit } else { -bit }
							}
							ac++
						}
					}
				}
			}
			if skips.value > 0 {
				for ac <= scan.end_of_spectral_selection {
					if block.values[jpeg_zigzag_offsets[ac]] != 0 && scan.reader.read_bits(1)! != 0 {
						block.values[jpeg_zigzag_offsets[ac]] += if block.values[jpeg_zigzag_offsets[ac]] > 0 { bit } else { -bit }
					}
					ac++
				}
				skips.value--
			}
		}
	}
}
