module zigimg

// Locked zigimg/jpeg/Frame.zig. Fixed arrays represent Block and its three
// component lanes. The row operations below retain the source's eight-lane
// f32 arithmetic, permutation indices, and descending alias-safe traversal.
pub struct JpegBlock {
pub mut:
	values [64]int @[required]
}

pub struct JpegBlockComponents {
pub mut:
	blocks [3]JpegBlock @[required]
}

// Heap records give Source's borrowed pointers to fixed table arrays stable
// pointees in V. The four optional slots retain their fixed cardinality.
@[heap]
pub struct JpegQuantizationTables {
pub mut:
	values [4]?JpegQuantizationTable @[required]
}

@[heap]
pub struct JpegHuffmanTables {
pub mut:
	values [4]?JpegHuffmanTable @[required]
}

@[heap]
pub struct JpegFrame {
pub mut:
	frame_header                   JpegFrameHeader         @[required]
	quantization_tables            &JpegQuantizationTables @[required]
	dc_huffman_tables              &JpegHuffmanTables      @[required]
	ac_huffman_tables              &JpegHuffmanTables      @[required]
	block_storage                  []JpegBlockComponents   @[required]
	frame_type                     u16
	block_height                   u32
	block_width                    u32
	block_width_actual             u32
	block_height_actual            u32
	horizontal_sampling_factor_max usize
	vertical_sampling_factor_max   usize
}

pub fn JpegFrame.read(frame_type u16, quantization_tables &JpegQuantizationTables,
	dc_huffman_tables &JpegHuffmanTables, ac_huffman_tables &JpegHuffmanTables,
	mut stream ReadStream) !JpegFrame {
	if !jpeg_marker_defined(frame_type) { panic('invalid enum value') }
	header := JpegFrameHeader.read(mut stream)!
	horizontal := header.max_horizontal_sampling_factor()
	vertical := header.max_vertical_sampling_factor()
	mcu_width := 8 * horizontal
	mcu_height := 8 * vertical
	width_actual := ((usize(header.width) + mcu_width - 1) / mcu_width) * mcu_width
	height_actual := ((usize(header.height) + mcu_height - 1) / mcu_height) * mcu_height
	storage := []JpegBlockComponents{len: int(width_actual * height_actual / 64)}
	// These source additions use the header's u16, after allocating storage.
	if header.height > 65528 { panic('integer overflow') }
	block_height := (u32(header.height) + 7) / 8
	if header.width > 65528 { panic('integer overflow') }
	return JpegFrame{
		quantization_tables:            quantization_tables
		dc_huffman_tables:              dc_huffman_tables
		ac_huffman_tables:              ac_huffman_tables
		frame_header:                   header
		frame_type:                     frame_type
		block_storage:                  storage
		block_height_actual:            u32((height_actual + 7) / 8)
		block_width_actual:             u32((width_actual + 7) / 8)
		block_height:                   block_height
		block_width:                    (u32(header.width) + 7) / 8
		horizontal_sampling_factor_max: horizontal
		vertical_sampling_factor_max:   vertical
	}
}

pub fn (mut frame JpegFrame) deinit() {
	// GC reclaims the backing graph; do not reset Source's record descriptors.
	frame.frame_header.deinit()
}

fn jpeg_add_usize(a usize, b usize) usize {
	if b > ~usize(0) - a { panic('integer overflow') }
	return a + b
}

fn jpeg_mul_usize(a usize, b usize) usize {
	if b != 0 && a > ~usize(0) / b { panic('integer overflow') }
	return a * b
}

fn jpeg_div_usize(a usize, b usize) usize {
	if b == 0 { panic('division by zero') }
	return a / b
}

fn jpeg_index(index usize, length int) int {
	if index >= usize(length) { panic('index out of bounds: index ${index}, len ${length}') }
	return int(index)
}

fn jpeg_rgb_byte(value int) u8 {
	if value < 0 || value > 255 { panic('integer does not fit in destination type') }
	return u8(value)
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

pub fn (mut frame JpegFrame) render_to_pixels(mut pixels PixelStorage) ! {
	match frame.frame_header.components.len {
		1 {
			if pixels !is Grayscale8Pixels {
				panic("access of union field 'grayscale8' while field '${pixels.pixel_format()}' is active")
			}
			mut gray := pixels as Grayscale8Pixels
			frame.render_to_pixels_grayscale(mut gray.data)!
		}
		3 {
			frame.ycbcr_to_rgb()!
			if pixels !is Rgb24Pixels {
				panic("access of union field 'rgb24' while field '${pixels.pixel_format()}' is active")
			}
			mut rgb := pixels as Rgb24Pixels
			frame.render_to_pixels_rgb(mut rgb.data)!
		}
		else {
			panic('reached unreachable code')
		}
	}
}

fn (mut frame JpegFrame) render_to_pixels_grayscale(mut pixels []Grayscale8) ! {
	mut by := usize(0)
	for by < usize(frame.block_height) {
		py := jpeg_mul_usize(by, 8)
		mut bx := usize(0)
		for bx < usize(frame.block_width) {
			block_index := jpeg_add_usize(jpeg_mul_usize(by, usize(frame.block_width_actual)), bx)
			px := jpeg_mul_usize(bx, 8)
			for y in 0 .. 8 {
				for x in 0 .. 8 {
					pixel_y := jpeg_add_usize(py, usize(y))
					if pixel_y >= usize(frame.frame_header.height) { continue
					 }
					pixel_x := jpeg_add_usize(px, usize(x))
					if pixel_x >= usize(frame.frame_header.width) { continue
					 }
					pixel_index := jpeg_add_usize(jpeg_mul_usize(pixel_y,
						usize(frame.frame_header.width)), pixel_x)
					value := frame.block_storage[jpeg_index(block_index, frame.block_storage.len)].blocks[0].values[
						y * 8 + x]
					target := jpeg_index(pixel_index, pixels.len)
					sample := jpeg_rgb_byte(jpeg_clamp_i32(jpeg_add_i32(value, 128), 0, 255))
					pixels[target] = Grayscale8{
						value: sample
					}
				}
			}
			bx++
		}
		by++
	}
}

pub fn (mut frame JpegFrame) render_to_pixels_rgb(mut pixels []Rgb24) ! {
	mut by := usize(0)
	for by < usize(frame.block_height) {
		py := jpeg_mul_usize(by, 8)
		mut bx := usize(0)
		for bx < usize(frame.block_width) {
			block_index := jpeg_add_usize(jpeg_mul_usize(by, usize(frame.block_width_actual)), bx)
			px := jpeg_mul_usize(bx, 8)
			for y in 0 .. 8 {
				for x in 0 .. 8 {
					pixel_y := jpeg_add_usize(py, usize(y))
					if pixel_y >= usize(frame.frame_header.height) { continue
					 }
					pixel_x := jpeg_add_usize(px, usize(x))
					if pixel_x >= usize(frame.frame_header.width) { continue
					 }
					pixel_index := jpeg_add_usize(jpeg_mul_usize(pixel_y,
						usize(frame.frame_header.width)), pixel_x)
					target := jpeg_index(pixel_index, pixels.len)
					b := jpeg_index(block_index, frame.block_storage.len)
					// Zig lowers this struct assignment to ordered field stores. A bad
					// green/blue cast leaves the preceding channels written in place.
					pixels[target].r = jpeg_rgb_byte(frame.block_storage[b].blocks[0].values[
						y * 8 + x])
					pixels[target].g = jpeg_rgb_byte(frame.block_storage[b].blocks[1].values[
						y * 8 + x])
					pixels[target].b = jpeg_rgb_byte(frame.block_storage[b].blocks[2].values[
						y * 8 + x])
				}
			}
			bx++
		}
		by++
	}
}

pub fn (mut frame JpegFrame) ycbcr_to_rgb_block(mut y_block JpegBlockComponents,
	cbcr_block &JpegBlockComponents, v usize, h usize) {
	y_step := frame.vertical_sampling_factor_max
	x_step := frame.horizontal_sampling_factor_max
	if x_step > usize(2147483647) { panic('integer does not fit in destination type') }
	offset := jpeg_mul_usize(jpeg_div_usize(8, x_step), h)
	if offset > usize(2147483647) { panic('integer does not fit in destination type') }
	mut mask := [8]int{}
	for lane in 0 .. 8 {
		mask[lane] = jpeg_add_i32(lane / int(x_step), int(offset))
	}
	mut y := usize(8)
	for y > 0 {
		y--
		mut ys := [8]f32{}
		for lane in 0 .. 8 {
			ys[lane] = f32(y_block.blocks[0].values[int(y) * 8 + lane])
		}
		cbcr_y := jpeg_add_usize(jpeg_div_usize(y, y_step),
			jpeg_mul_usize(jpeg_div_usize(8, y_step), v))
		start := jpeg_mul_usize(cbcr_y, 8)
		end := jpeg_add_usize(start, 8)
		if end > 64 { panic('index out of bounds: index ${end}, len 64') }
		mut cb := [8]int{}
		for lane in 0 .. 8 {
			cb[lane] = cbcr_block.blocks[1].values[int(start) + lane]
		}
		mut cbs := [8]f32{}
		for lane in 0 .. 8 {
			cbs[lane] = f32(cb[jpeg_index(usize(mask[lane]), 8)])
		}
		mut cr := [8]int{}
		for lane in 0 .. 8 {
			cr[lane] = cbcr_block.blocks[2].values[int(start) + lane]
		}
		mut crs := [8]f32{}
		for lane in 0 .. 8 {
			crs[lane] = f32(cr[jpeg_index(usize(mask[lane]), 8)])
		}
		mut rs := [8]int{}
		mut gs := [8]int{}
		mut bs := [8]int{}
		for lane in 0 .. 8 {
			r := ys[lane] + crs[lane] * f32(1.402) + f32(128)
			b := ys[lane] + cbs[lane] * f32(1.772) + f32(128)
			g := ys[lane] - f32(0.344) * cbs[lane] - f32(0.714) * crs[lane] + f32(128)
			rs[lane] = int(jpeg_clamp_f32(r, 0, 255))
			gs[lane] = int(jpeg_clamp_f32(g, 0, 255))
			bs[lane] = int(jpeg_clamp_f32(b, 0, 255))
		}
		for lane in 0 .. 8 {
			y_block.blocks[0].values[int(y) * 8 + lane] = rs[lane]
		}
		for lane in 0 .. 8 {
			y_block.blocks[1].values[int(y) * 8 + lane] = gs[lane]
		}
		for lane in 0 .. 8 {
			y_block.blocks[2].values[int(y) * 8 + lane] = bs[lane]
		}
	}
}

pub fn (mut frame JpegFrame) ycbcr_to_rgb() ! {
	mut y := usize(0)
	for y < usize(frame.block_height) {
		mut x := usize(0)
		for x < usize(frame.block_width) {
			cbcr_index := jpeg_index(jpeg_add_usize(jpeg_mul_usize(y,
				usize(frame.block_width_actual)), x), frame.block_storage.len)
			mut v := frame.vertical_sampling_factor_max
			for v > 0 {
				v--
				mut h := frame.horizontal_sampling_factor_max
				for h > 0 {
					h--
					block_y := jpeg_add_usize(y, v)
					if block_y >= usize(frame.block_height) { continue
					 }
					block_x := jpeg_add_usize(x, h)
					if block_x >= usize(frame.block_width) { continue
					 }
					index := jpeg_index(jpeg_add_usize(jpeg_mul_usize(block_y,
						usize(frame.block_width_actual)), block_x), frame.block_storage.len)
					frame.ycbcr_to_rgb_block(mut frame.block_storage[index],
						&frame.block_storage[cbcr_index], v, h)
				}
			}
			x = jpeg_add_usize(x, frame.horizontal_sampling_factor_max)
		}
		y = jpeg_add_usize(y, frame.vertical_sampling_factor_max)
	}
}

pub fn (mut frame JpegFrame) dequantize_blocks() ! {
	for component in frame.frame_header.components {
		if frame.quantization_tables.values[jpeg_index(usize(component.quantization_table_id), 4)] == none {
			return error('InvalidData')
		}
	}
	mut y := usize(0)
	for y < usize(frame.block_height) {
		mut x := usize(0)
		for x < usize(frame.block_width) {
			for ci, component in frame.frame_header.components {
				entry := frame.quantization_tables.values[jpeg_index(usize(component.quantization_table_id), 4)]
				table := entry or { panic('attempt to use null value') }
				for v in 0 .. int(component.vertical_sampling_factor) {
					for h in 0 .. int(component.horizontal_sampling_factor) {
						block_y := jpeg_add_usize(y, usize(v))
						block_x := jpeg_add_usize(x, usize(h))
						id := jpeg_add_usize(jpeg_mul_usize(block_y,
							usize(frame.block_width_actual)), block_x)
						index := jpeg_index(id, frame.block_storage.len)
						if ci >= 3 { panic('index out of bounds: index ${ci}, len 3') }
						if block_y >= usize(frame.block_height) {
							frame.block_storage[index].blocks[ci].values = [64]int{}
						} else {
							for si in 0 .. 64 {
								value := frame.block_storage[index].blocks[ci].values[si]
								if table !is JpegQuantization8 {
									panic("access of union field 'q8' while field 'q16' is active")
								}
								frame.block_storage[index].blocks[ci].values[si] = jpeg_mul_i32(value,
									int((table as JpegQuantization8).values[si]))
							}
						}
					}
				}
			}
			x = jpeg_add_usize(x, frame.horizontal_sampling_factor_max)
		}
		y = jpeg_add_usize(y, frame.vertical_sampling_factor_max)
	}
}

pub fn (mut frame JpegFrame) idct_blocks() {
	mut y := usize(0)
	for y < usize(frame.block_height) {
		mut x := usize(0)
		for x < usize(frame.block_width) {
			for ci, component in frame.frame_header.components {
				for v in 0 .. int(component.vertical_sampling_factor) {
					for h in 0 .. int(component.horizontal_sampling_factor) {
						id := jpeg_add_usize(jpeg_mul_usize(jpeg_add_usize(y, usize(v)),
							usize(frame.block_width_actual)), jpeg_add_usize(x, usize(h)))
						index := jpeg_index(id, frame.block_storage.len)
						if ci >= 3 { panic('index out of bounds: index ${ci}, len 3') }
						jpeg_idct_block(mut frame.block_storage[index].blocks[ci])
					}
				}
			}
			x = jpeg_add_usize(x, frame.horizontal_sampling_factor_max)
		}
		y = jpeg_add_usize(y, frame.vertical_sampling_factor_max)
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
