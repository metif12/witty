module zigimg

// Locked zigimg/src/formats/jpeg.zig. GC owns the tables/frame allocations;
// the parser, segment dispatch, scan algorithms, and codec registry stay V.
@[heap]
pub struct JPEG {
pub mut:
	frame               ?JpegFrame
	quantization_tables JpegQuantizationTables = JpegQuantizationTables{
		values: unsafe { [4]?JpegQuantizationTable{init: none} }
	}
	dc_huffman_tables   JpegHuffmanTables = JpegHuffmanTables{
		values: [4]?JpegHuffmanTable{init: none}
	}
	ac_huffman_tables   JpegHuffmanTables = JpegHuffmanTables{
		values: [4]?JpegHuffmanTable{init: none}
	}
	restart_interval    u16
}

pub fn JPEG.init() JPEG {
	return JPEG{}
}

pub fn (mut jpeg JPEG) deinit() {
	if mut frame := jpeg.frame { frame.deinit() }
}

fn (mut jpeg JPEG) parse_quantization_tables(mut stream ReadStream) ! {
	mut segment_size := int(jpeg_u16(mut stream)!)
	if segment_size < 2 { panic('integer overflow') }
	segment_size -= 2
	for segment_size > 0 {
		precision_destination := stream.take_byte()!
		precision := precision_destination >> 4
		destination := precision_destination & 3
		table := JpegQuantizationTable.read(precision, mut stream)!
		consumed := if precision == 0 { 65 } else { 129 }
		if segment_size < consumed { panic('integer overflow') }
		segment_size -= consumed
		jpeg.quantization_tables.values[int(destination)] = table
	}
}

fn (mut jpeg JPEG) parse_huffman_tables(mut stream ReadStream) ! {
	mut segment_size := int(jpeg_u16(mut stream)!)
	if segment_size < 2 { panic('integer overflow') }
	segment_size -= 2
	for segment_size > 0 {
		class_destination := stream.take_byte()!
		table_class := class_destination >> 4
		destination := int(class_destination & 15)
		table := JpegHuffmanTable.read(table_class, mut stream)!
		if destination >= 4 { panic('index out of bounds: index ${destination}, len 4') }
		if table_class == 0 {
			jpeg.dc_huffman_tables.values[destination] = table
		} else {
			jpeg.ac_huffman_tables.values[destination] = table
		}
		consumed := 17 + table.code_map.len
		if segment_size < consumed { panic('integer overflow') }
		segment_size -= consumed
	}
}

fn (mut jpeg JPEG) parse_restart_interval(mut stream ReadStream) ! {
	length := jpeg_u16(mut stream)!
	if length < 4 { panic('integer overflow') }
	if length != 4 { panic('reached unreachable code') }
	jpeg.restart_interval = jpeg_u16(mut stream)!
}

// Mutable optional sum types require a wrapper in V 0.5.2 to preserve the
// caller's optional storage rather than passing only its payload address.
pub struct JpegPixels {
pub mut:
	value ?PixelStorage
}

pub fn (mut jpeg JPEG) read(mut stream ReadStream, mut pixels_opt JpegPixels) !JpegFrame {
	mut succeeded := false
	defer {
		if !succeeded { pixels_opt.value = none }
	}
	mut marker := jpeg_u16(mut stream)!
	if marker != 0xffd8 { return error('InvalidData') }
	for marker != 0xffd9 {
		marker = jpeg_u16(mut stream)!
		// The source converts this u16 to its exhaustive Markers enum before
		// dispatch. Unknown enum values trap in checked builds.
		if !jpeg_marker_defined(marker) {
			panic('invalid enum value')
		}
		match marker {
			0xffc0, 0xffc2 {
				if jpeg.frame != none { return error('Unsupported') }
				mut frame := JpegFrame.read(marker, &jpeg.quantization_tables,
					&jpeg.dc_huffman_tables, &jpeg.ac_huffman_tables, mut stream)!
				jpeg.frame = frame
				format := match frame.frame_header.components.len {
					1 { PixelFormat.grayscale8 }
					3 { PixelFormat.rgb24 }
					else { panic('unreachable JPEG components') }
				}

				pixels_opt.value = PixelStorage.init(format,
					usize(frame.frame_header.width) * usize(frame.frame_header.height))!
			}
			0xffc1, 0xffc3, 0xffc5, 0xffc6, 0xffc7, 0xffc9, 0xffca, 0xffcb, 0xffcd, 0xffce, 0xffcf {
				return error('Unsupported')
			}
			0xffc4 {
				jpeg.parse_huffman_tables(mut stream)!
			}
			0xffda {
				mut frame := jpeg.frame or { return error('InvalidData') }
				JpegScan.perform_scan(&frame, jpeg.restart_interval, mut stream)!
			}
			0xffdb {
				jpeg.parse_quantization_tables(mut stream)!
			}
			0xfffe, 0xffe0...0xffef {
				length := jpeg_u16(mut stream)!
				if length < 2 { panic('integer overflow') }
				stream.seek_by(i64(length) - 2)!
			}
			0xffdd {
				jpeg.parse_restart_interval(mut stream)!
			}
			0xffd0...0xffd7, 0xffd9 {
				continue
			}
			else {
				return error('InvalidData')
			}
		}
	}
	mut frame := jpeg.frame or { return error('InvalidData') }
	frame.dequantize_blocks()!
	frame.idct_blocks()
	mut pixels := pixels_opt.value or { panic('missing JPEG pixel allocation') }
	frame.render_to_pixels(mut pixels)!
	pixels_opt.value = pixels
	succeeded = true
	return frame
}

fn jpeg_marker_defined(marker u16) bool {
	return (marker >= 0xffc0 && marker <= 0xffef && marker != 0xffc8)
		|| marker == 0xfff0 || marker == 0xfffe
}

pub fn JPEG.format_detect(mut stream ReadStream) !bool {
	return jpeg_u16_peek(mut stream)! == 0xffd8
}

fn jpeg_u16_peek(mut stream ReadStream) !u16 {
	bytes := stream.peek(2)!
	return u16(bytes[0]) << 8 | bytes[1]
}

pub fn JPEG.read_image(mut stream ReadStream) !ImageUnmanaged {
	mut jpeg := JPEG.init()
	defer { jpeg.deinit() }
	mut pixels := JpegPixels{}
	frame := jpeg.read(mut stream, mut pixels) or {
		pixels.value = none
		return err
	}
	return ImageUnmanaged{
		width:  usize(frame.frame_header.width)
		height: usize(frame.frame_header.height)
		pixels: pixels.value or { return error('InvalidData') }
	}
}
