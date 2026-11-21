module zigimg

// Locked zigimg/jpeg/Scan.zig, retaining both baseline and progressive scans.
pub struct JpegScanComponentSpec {
pub mut:
	component_id      u8 @[required]
	dc_table_selector u8 @[required]
	ac_table_selector u8 @[required]
}

pub fn JpegScanComponentSpec.read(mut stream ReadStream) !JpegScanComponentSpec {
	id := stream.take_byte()!
	selectors := stream.take_byte()!
	return JpegScanComponentSpec{
		component_id:      id
		dc_table_selector: selectors >> 4
		ac_table_selector: selectors & 3
	}
}

struct JpegScanSkips {
mut:
	value u32
}

@[heap]
pub struct JpegScan {
pub mut:
	frame                       &JpegFrame                @[required]
	reader                      JpegHuffmanReader         @[required]
	components                  [4]?JpegScanComponentSpec @[required]
	component_count             u8                        @[required]
	start_of_spectral_selection u8                        @[required]
	end_of_spectral_selection   u8                        @[required]
	approximation_high          u8                        @[required]
	approximation_low           u8                        @[required]
	prediction_values           [3]int                    @[required]
}

pub fn JpegScan.init(frame &JpegFrame, mut stream ReadStream) !JpegScan {
	segment_size := jpeg_u16(mut stream)!
	count := stream.take_byte()!
	if count < 1 || count > 4 { return error('InvalidData') }
	mut components := [4]?JpegScanComponentSpec{init: none}
	for i in 0 .. int(count) {
		component := JpegScanComponentSpec.read(mut stream)!
		components[i] = component
		mut valid := false
		for frame_component in frame.frame_header.components {
			if frame_component.id == component.component_id { valid = true }
		}
		// Preserve the source's OR validity tests rather than introducing a
		// stricter component/table validation rule.
		if component.dc_table_selector >= 4 {
			panic('index out of bounds: index ${component.dc_table_selector}, len 4')
		}
		if frame.dc_huffman_tables.values[int(component.dc_table_selector)] != none { valid = true }
		if frame.ac_huffman_tables.values[int(component.ac_table_selector)] != none { valid = true }
		if !valid { return error('InvalidData') }
	}
	start := stream.take_byte()!
	end := stream.take_byte()!
	if start > 63 || end > 63 || end < start { return error('InvalidData') }
	if frame.frame_type == 0xffc0 && (start != 0 || end != 63) { return error('InvalidData') }
	if frame.frame_type == 0xffc2 {
		any_zero := start == 0 || end == 0
		both_zero := start == 0 && end == 0
		if any_zero && !both_zero { return error('InvalidData') }
	}
	approximation := stream.take_byte()!
	if int(segment_size) != 2 * int(count) + 6 { panic('reached unreachable code') }
	return JpegScan{
		frame:                       frame
		reader:                      JpegHuffmanReader.init(mut stream)
		components:                  components
		component_count:             count
		start_of_spectral_selection: start
		end_of_spectral_selection:   end
		approximation_high:          approximation >> 4
		approximation_low:           approximation & 15
		prediction_values:           [3]int{}
	}
}

pub fn JpegScan.perform_scan(frame &JpegFrame, restart_interval u16, mut stream ReadStream) ! {
	mut scan := JpegScan.init(frame, mut stream)!
	mut skips := JpegScanSkips{}
	entry := scan.components[0]
	first := entry or { panic('attempt to use null value') }
	noninterleaved := scan.component_count == 1 && first.component_id == 1
	y_step := if noninterleaved { uint(1) } else { frame.vertical_sampling_factor_max }
	x_step := if noninterleaved { uint(1) } else { frame.horizontal_sampling_factor_max }
	mut y := uint(0)
	for y < uint(frame.block_height) {
		mut x := uint(0)
		for x < uint(frame.block_width) {
			mcu_id := jpeg_add_usize(jpeg_mul_usize(y, uint(frame.block_width_actual)), x)
			mut restart := false
			if restart_interval != 0 {
				interval := jpeg_mul_usize(jpeg_mul_usize(uint(restart_interval), y_step), x_step)
				if interval == 0 { panic('division by zero') }
				restart = mcu_id % interval == 0
			}
			if restart {
				scan.reader.flush_bits()
				scan.prediction_values = [3]int{}
				skips.value = 0
			}
			for index in 0 .. int(scan.component_count) {
				component_entry := scan.components[index]
				component := component_entry or { panic('attempt to use null value') }
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
				if component_index < 0 { panic('undefined JPEG scan component') }
				for v in 0 .. v_max {
					for h in 0 .. h_max {
						id := jpeg_add_usize(jpeg_mul_usize(jpeg_add_usize(y, uint(v)),
							uint(frame.block_width_actual)), jpeg_add_usize(x, uint(h)))
						block_index := jpeg_index(id, frame.block_storage.len)
						if component_index >= 3 {
							panic('index out of bounds: index ${component_index}, len 3')
						}
						// Source takes this block pointer before attempting entropy fill.
						scan.reader.fill_bits(24) or {}
						if frame.frame_type == 0xffc0 {
							scan.decode_block_baseline(component, mut
								scan.frame.block_storage[block_index].blocks[component_index],
								component_index)!
						} else if frame.frame_type == 0xffc2 {
							scan.decode_block_progressive(component, mut
								scan.frame.block_storage[block_index].blocks[component_index],
								component_index, mut skips)!
						}
					}
				}
			}
			x = jpeg_add_usize(x, x_step)
		}
		y = jpeg_add_usize(y, y_step)
	}
}

fn (mut scan JpegScan) dc_table(component JpegScanComponentSpec) {
	entry := scan.frame.dc_huffman_tables.values[jpeg_index(uint(component.dc_table_selector), 4)]
	table := entry or { panic('attempt to use null value') }

	scan.reader.set_huffman_table(table)
}

fn (mut scan JpegScan) ac_table(component JpegScanComponentSpec) {
	entry := scan.frame.ac_huffman_tables.values[jpeg_index(uint(component.ac_table_selector), 4)]
	table := entry or { panic('attempt to use null value') }

	scan.reader.set_huffman_table(table)
}

fn (mut scan JpegScan) decode_block_baseline(component JpegScanComponentSpec, mut block JpegBlock, destination int) ! {
	scan.dc_table(component)
	mut magnitude := scan.reader.read_code()!
	if magnitude > 11 { return error('InvalidData') }
	diff := scan.reader.read_magnitude_coded(magnitude)!
	dc := jpeg_add_i32(diff, scan.prediction_values[destination])
	scan.prediction_values[destination] = dc
	block.values[0] = dc
	scan.ac_table(component)
	mut ac := 1
	for ac < 64 {
		run_magnitude := scan.reader.read_code()!
		if run_magnitude == 0 {
			for ac < 64 {
				block.values[jpeg_zigzag_offsets[ac]] = 0
				ac++
			}
			return
		}
		zero_run := run_magnitude >> 4
		magnitude = run_magnitude & 15
		if magnitude > 10 { return error('InvalidData') }
		coefficient := scan.reader.read_magnitude_coded(magnitude)!
		if coefficient < -1024 || coefficient > 1023 {
			panic('integer does not fit in destination type')
		}
		for _ in 0 .. int(zero_run) {
			block.values[jpeg_zigzag_offsets[ac]] = 0
			ac++
		}
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
			dc := jpeg_add_i32(diff, scan.prediction_values[component_index])
			scan.prediction_values[component_index] = dc
			block.values[0] = dc << scan.approximation_low
		} else {
			bit := scan.reader.read_bits(1)!
			block.values[0] = jpeg_add_i32(block.values[0], int(bit << scan.approximation_low))
		}
	} else {
		scan.ac_table(component)
		if scan.approximation_high == 0 {
			mut ac := int(scan.start_of_spectral_selection)
			if skips.value == 0 {
				for ac <= int(scan.end_of_spectral_selection) {
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
					for _ in 0 .. int(zero_run) {
						block.values[jpeg_zigzag_offsets[ac]] = 0
						ac++
					}
					block.values[jpeg_zigzag_offsets[ac]] = coefficient << scan.approximation_low
					ac++
				}
			}
			if skips.value > 0 {
				skips.value--
				for ac <= int(scan.end_of_spectral_selection) {
					block.values[jpeg_zigzag_offsets[ac]] = 0
					ac++
				}
			}
		} else {
			bit := int(1) << scan.approximation_low
			mut ac := int(scan.start_of_spectral_selection)
			if skips.value == 0 {
				for ac <= int(scan.end_of_spectral_selection) {
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
					} else {
						coefficient = if scan.reader.read_bits(1)! == 1 { bit } else { -bit }
					}
					for ac <= int(scan.end_of_spectral_selection) {
						if block.values[jpeg_zigzag_offsets[ac]] == 0 {
							if zero_run > 0 {
								zero_run--
								ac++
							} else {
								block.values[jpeg_zigzag_offsets[ac]] = coefficient
								ac++
								break
							}
						} else {
							if scan.reader.read_bits(1)! != 0 {
								block.values[jpeg_zigzag_offsets[ac]] = jpeg_add_i32(block.values[jpeg_zigzag_offsets[ac]], if block.values[jpeg_zigzag_offsets[ac]] > 0 {
									bit
								} else {
									-bit
								})
							}
							ac++
						}
					}
				}
			}
			if skips.value > 0 {
				for ac <= int(scan.end_of_spectral_selection) {
					if block.values[jpeg_zigzag_offsets[ac]] != 0 && scan.reader.read_bits(1)! != 0 {
						block.values[jpeg_zigzag_offsets[ac]] = jpeg_add_i32(block.values[jpeg_zigzag_offsets[ac]], if block.values[jpeg_zigzag_offsets[ac]] > 0 {
							bit
						} else {
							-bit
						})
					}
					ac++
				}
				skips.value--
			}
		}
	}
}
