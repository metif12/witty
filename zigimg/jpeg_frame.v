module zigimg

// Locked zigimg/jpeg/Frame.zig. Fixed arrays represent Block and its three
// component lanes. The row operations below retain the source's eight-lane
// f32 arithmetic, permutation indices, and descending alias-safe traversal.
struct JpegBlock {
mut:
	values [64]int
}

struct JpegBlockComponents {
mut:
	blocks [3]JpegBlock
}

@[heap]
pub struct JpegFrame {
pub mut:
	frame_header JpegFrameHeader
	frame_type   u16
mut:
	owner                          &JPEG = unsafe { nil }
	block_storage                  []JpegBlockComponents
	block_height                   int
	block_width                    int
	block_width_actual             int
	block_height_actual            int
	horizontal_sampling_factor_max int
	vertical_sampling_factor_max   int
}

fn jpeg_frame_read(owner &JPEG, frame_type u16, mut stream ReadStream) !&JpegFrame {
	header := JpegFrameHeader.read(mut stream)!
	horizontal := header.max_horizontal_sampling_factor()
	vertical := header.max_vertical_sampling_factor()
	mcu_width := 8 * horizontal
	mcu_height := 8 * vertical
	width_actual := ((int(header.width) + mcu_width - 1) / mcu_width) * mcu_width
	height_actual := ((int(header.height) + mcu_height - 1) / mcu_height) * mcu_height
	return &JpegFrame{
		owner:                          owner
		frame_header:                   header
		frame_type:                     frame_type
		block_storage:                  []JpegBlockComponents{len: width_actual * height_actual / 64}
		block_height_actual:            (height_actual + 7) / 8
		block_width_actual:             (width_actual + 7) / 8
		block_height:                   (int(header.height) + 7) / 8
		block_width:                    (int(header.width) + 7) / 8
		horizontal_sampling_factor_max: horizontal
		vertical_sampling_factor_max:   vertical
	}
}

fn jpeg_clamp_i32(value int, lower int, upper int) int {
	return if value < lower {
		lower
	} else if value > upper {
		upper
	} else {
		value
	}
}

fn jpeg_clamp_f32(value f32, lower f32, upper f32) f32 {
	return if value < lower {
		lower
	} else if value > upper {
		upper
	} else {
		value
	}
}

fn (mut frame JpegFrame) render_to_pixels(mut pixels PixelStorage) ! {
	match frame.frame_header.components.len {
		1 {
			mut gray := pixels as Grayscale8Pixels
			for by in 0 .. frame.block_height {
				for bx in 0 .. frame.block_width {
					block_index := by * frame.block_width_actual + bx
					for y in 0 .. 8 {
						for x in 0 .. 8 {
							py := by * 8 + y
							px := bx * 8 + x
							if py >= int(frame.frame_header.height) || px >= int(frame.frame_header.width) { continue
							 }
							value := frame.block_storage[block_index].blocks[0].values[y * 8 + x]
							gray.data[py * int(frame.frame_header.width) + px] = Grayscale8{
								value: u8(jpeg_clamp_i32(jpeg_add_i32(value, 128), 0, 255))
							}
						}
					}
				}
			}
			pixels = gray
		}
		3 {
			frame.ycbcr_to_rgb()
			mut rgb := pixels as Rgb24Pixels
			for by in 0 .. frame.block_height {
				for bx in 0 .. frame.block_width {
					index := by * frame.block_width_actual + bx
					for y in 0 .. 8 {
						for x in 0 .. 8 {
							py := by * 8 + y
							px := bx * 8 + x
							if py >= int(frame.frame_header.height) || px >= int(frame.frame_header.width) { continue
							 }
							rgb.data[py * int(frame.frame_header.width) + px] = Rgb24{
								r: u8(frame.block_storage[index].blocks[0].values[y * 8 + x])
								g: u8(frame.block_storage[index].blocks[1].values[y * 8 + x])
								b: u8(frame.block_storage[index].blocks[2].values[y * 8 + x])
							}
						}
					}
				}
			}
			pixels = rgb
		}
		else {
			panic('unreachable JPEG pixel format')
		}
	}
}

fn (mut frame JpegFrame) ycbcr_to_rgb_block(y_index int, cbcr_index int, v int, h int) {
	y_step := frame.vertical_sampling_factor_max
	x_step := frame.horizontal_sampling_factor_max
	mut y := 8
	for y > 0 {
		y--
		// Load every lane before storing, since the Y and CbCr blocks may alias.
		mut y_lanes := [8]f32{}
		mut cb_lanes := [8]f32{}
		mut cr_lanes := [8]f32{}
		cbcr_y := y / y_step + (8 / y_step) * v
		for lane in 0 .. 8 {
			mask := lane / x_step + (8 / x_step) * h
			y_lanes[lane] = f32(frame.block_storage[y_index].blocks[0].values[y * 8 + lane])
			cb_lanes[lane] = f32(frame.block_storage[cbcr_index].blocks[1].values[cbcr_y * 8 + mask])
			cr_lanes[lane] = f32(frame.block_storage[cbcr_index].blocks[2].values[cbcr_y * 8 + mask])
		}
		for lane in 0 .. 8 {
			r := y_lanes[lane] + cr_lanes[lane] * f32(1.402) + f32(128)
			b := y_lanes[lane] + cb_lanes[lane] * f32(1.772) + f32(128)
			g := y_lanes[lane] - f32(0.344) * cb_lanes[lane] - f32(0.714) * cr_lanes[lane] +
				f32(128)
			frame.block_storage[y_index].blocks[0].values[y * 8 + lane] = int(jpeg_clamp_f32(r, 0, 255))
			frame.block_storage[y_index].blocks[1].values[y * 8 + lane] = int(jpeg_clamp_f32(g, 0, 255))
			frame.block_storage[y_index].blocks[2].values[y * 8 + lane] = int(jpeg_clamp_f32(b, 0, 255))
		}
	}
}

fn (mut frame JpegFrame) ycbcr_to_rgb() {
	mut y := 0
	for y < frame.block_height {
		mut x := 0
		for x < frame.block_width {
			cbcr_index := y * frame.block_width_actual + x
			mut v := frame.vertical_sampling_factor_max
			for v > 0 {
				v--
				mut h := frame.horizontal_sampling_factor_max
				for h > 0 {
					h--
					if y + v >= frame.block_height || x + h >= frame.block_width { continue
					 }
					frame.ycbcr_to_rgb_block((y + v) * frame.block_width_actual + x + h,
						cbcr_index, v, h)
				}
			}
			x += frame.horizontal_sampling_factor_max
		}
		y += frame.vertical_sampling_factor_max
	}
}

fn (mut frame JpegFrame) dequantize_blocks() ! {
	for component in frame.frame_header.components {
		if frame.owner.quantization_tables[int(component.quantization_table_id)] == none {
			return error('InvalidData')
		}
	}
	mut y := 0
	for y < frame.block_height {
		mut x := 0
		for x < frame.block_width {
			for ci, component in frame.frame_header.components {
				table := frame.owner.quantization_tables[int(component.quantization_table_id)] or {
					return error('InvalidData')
				}
				for v in 0 .. int(component.vertical_sampling_factor) {
					for h in 0 .. int(component.horizontal_sampling_factor) {
						id := (y + v) * frame.block_width_actual + x + h
						if y + v >= frame.block_height {
							frame.block_storage[id].blocks[ci].values = [64]int{}
						} else {
							for si in 0 .. 64 {
								// The source checks the active union field only when a
								// sample is multiplied, after indexing its destination.
								value := frame.block_storage[id].blocks[ci].values[si]
								if table.precision != 0 {
									panic("access of union field 'q8' while field 'q16' is active")
								}
								frame.block_storage[id].blocks[ci].values[si] = jpeg_mul_i32(value,
									int(table.q8[si]))
							}
						}
					}
				}
			}
			x += frame.horizontal_sampling_factor_max
		}
		y += frame.vertical_sampling_factor_max
	}
}

fn (mut frame JpegFrame) idct_blocks() {
	mut y := 0
	for y < frame.block_height {
		mut x := 0
		for x < frame.block_width {
			for ci, component in frame.frame_header.components {
				for v in 0 .. int(component.vertical_sampling_factor) {
					for h in 0 .. int(component.horizontal_sampling_factor) {
						id := (y + v) * frame.block_width_actual + x + h
						jpeg_idct_block(mut frame.block_storage[id].blocks[ci])
					}
				}
			}
			x += frame.horizontal_sampling_factor_max
		}
		y += frame.vertical_sampling_factor_max
	}
}

fn jpeg_f2f(x f32) int {
	return int(x * f32(4096) + f32(0.5))
}

// Zig checks each i32 intermediate, including those before IDCT shifts.
// Checking the widened result before narrowing also keeps these contracts
// active when V's production optimizer removes assertions.
@[inline]
fn jpeg_i32(value i64) int {
	if value < -2147483648 || value > 2147483647 { panic('integer overflow') }
	return int(value)
}

@[inline]
fn jpeg_add_i32(a int, b int) int {
	return jpeg_i32(i64(a) + i64(b))
}

@[inline]
fn jpeg_sub_i32(a int, b int) int {
	return jpeg_i32(i64(a) - i64(b))
}

@[inline]
fn jpeg_mul_i32(a int, b int) int {
	return jpeg_i32(i64(a) * i64(b))
}

fn jpeg_idct_1d(s0 int, s1 int, s2 int, s3 int, s4 int, s5 int, s6 int, s7 int) [8]int {
	mut p2 := s2
	mut p3 := s6
	mut p1 := jpeg_mul_i32(jpeg_add_i32(p2, p3), jpeg_f2f(0.5411961))
	mut t2 := jpeg_add_i32(p1, jpeg_mul_i32(p3, jpeg_f2f(-1.847759065)))
	mut t3 := jpeg_add_i32(p1, jpeg_mul_i32(p2, jpeg_f2f(0.765366865)))
	p2 = s0
	p3 = s4
	mut t0 := jpeg_mul_i32(jpeg_add_i32(p2, p3), 4096)
	mut t1 := jpeg_mul_i32(jpeg_sub_i32(p2, p3), 4096)
	x0 := jpeg_add_i32(t0, t3)
	x3 := jpeg_sub_i32(t0, t3)
	x1 := jpeg_add_i32(t1, t2)
	x2 := jpeg_sub_i32(t1, t2)
	t0 = s7
	t1 = s5
	t2 = s3
	t3 = s1
	p3 = jpeg_add_i32(t0, t2)
	mut p4 := jpeg_add_i32(t1, t3)
	p1 = jpeg_add_i32(t0, t3)
	p2 = jpeg_add_i32(t1, t2)
	p5 := jpeg_mul_i32(jpeg_add_i32(p3, p4), jpeg_f2f(1.175875602))
	t0 = jpeg_mul_i32(t0, jpeg_f2f(0.298631336))
	t1 = jpeg_mul_i32(t1, jpeg_f2f(2.053119869))
	t2 = jpeg_mul_i32(t2, jpeg_f2f(3.072711026))
	t3 = jpeg_mul_i32(t3, jpeg_f2f(1.501321110))
	p1 = jpeg_add_i32(p5, jpeg_mul_i32(p1, jpeg_f2f(-0.899976223)))
	p2 = jpeg_add_i32(p5, jpeg_mul_i32(p2, jpeg_f2f(-2.562915447)))
	p3 = jpeg_mul_i32(p3, jpeg_f2f(-1.961570560))
	p4 = jpeg_mul_i32(p4, jpeg_f2f(-0.390180644))
	t3 = jpeg_add_i32(t3, jpeg_add_i32(p1, p4))
	t2 = jpeg_add_i32(t2, jpeg_add_i32(p2, p3))
	t1 = jpeg_add_i32(t1, jpeg_add_i32(p2, p4))
	t0 = jpeg_add_i32(t0, jpeg_add_i32(p1, p3))
	return [x0, x1, x2, x3, t0, t1, t2, t3]!
}

fn jpeg_idct_block(mut block JpegBlock) {
	for x in 0 .. 8 {
		result := jpeg_idct_1d(block.values[x], block.values[8 + x], block.values[16 + x], block.values[
			24 + x], block.values[32 + x], block.values[40 + x], block.values[48 + x], block.values[
			56 + x])
		x0 := jpeg_add_i32(result[0], 512)
		x1 := jpeg_add_i32(result[1], 512)
		x2 := jpeg_add_i32(result[2], 512)
		x3 := jpeg_add_i32(result[3], 512)
		block.values[x] = jpeg_add_i32(x0, result[7]) >> 10
		block.values[8 + x] = jpeg_add_i32(x1, result[6]) >> 10
		block.values[16 + x] = jpeg_add_i32(x2, result[5]) >> 10
		block.values[24 + x] = jpeg_add_i32(x3, result[4]) >> 10
		block.values[32 + x] = jpeg_sub_i32(x3, result[4]) >> 10
		block.values[40 + x] = jpeg_sub_i32(x2, result[5]) >> 10
		block.values[48 + x] = jpeg_sub_i32(x1, result[6]) >> 10
		block.values[56 + x] = jpeg_sub_i32(x0, result[7]) >> 10
	}
	for y in 0 .. 8 {
		base := y * 8
		result := jpeg_idct_1d(block.values[base], block.values[base + 1], block.values[base + 2], block.values[
			base + 3], block.values[base + 4], block.values[base + 5], block.values[base + 6], block.values[
			base + 7])
		x0 := jpeg_add_i32(result[0], 65536)
		x1 := jpeg_add_i32(result[1], 65536)
		x2 := jpeg_add_i32(result[2], 65536)
		x3 := jpeg_add_i32(result[3], 65536)
		block.values[base] = jpeg_add_i32(x0, result[7]) >> 17
		block.values[base + 1] = jpeg_add_i32(x1, result[6]) >> 17
		block.values[base + 2] = jpeg_add_i32(x2, result[5]) >> 17
		block.values[base + 3] = jpeg_add_i32(x3, result[4]) >> 17
		block.values[base + 4] = jpeg_sub_i32(x3, result[4]) >> 17
		block.values[base + 5] = jpeg_sub_i32(x2, result[5]) >> 17
		block.values[base + 6] = jpeg_sub_i32(x1, result[6]) >> 17
		block.values[base + 7] = jpeg_sub_i32(x0, result[7]) >> 17
	}
}
