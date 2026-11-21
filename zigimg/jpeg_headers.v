module zigimg

// Locked zigimg/jpeg/{utils,FrameHeader,quantization,JFIFHeader}.zig.
const jpeg_zigzag_offsets = [0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, 12, 19, 26,
	33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28, 35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15,
	23, 30, 37, 44, 51, 58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63]!

fn jpeg_u16(mut stream ReadStream) !u16 {
	bytes := stream.take(2)!
	return u16(bytes[0]) << 8 | u16(bytes[1])
}

pub struct JpegComponent {
pub mut:
	id                         u8 @[required]
	horizontal_sampling_factor u8 @[required]
	vertical_sampling_factor   u8 @[required]
	quantization_table_id      u8 @[required]
}

pub fn JpegComponent.read(mut stream ReadStream) !JpegComponent {
	id := stream.take_byte()!
	sampling := stream.take_byte()!
	quantization_table_id := stream.take_byte()!
	horizontal := sampling >> 4
	vertical := sampling & 15
	if horizontal < 1 || horizontal > 4 || vertical < 1 || vertical > 4 || quantization_table_id > 3 {
		return error('InvalidData')
	}
	return JpegComponent{
		id:                         id
		horizontal_sampling_factor: horizontal
		vertical_sampling_factor:   vertical
		quantization_table_id:      quantization_table_id
	}
}

pub struct JpegFrameHeader {
pub mut:
	sample_precision u8              @[required]
	height           u16             @[required]
	width            u16             @[required]
	components       []JpegComponent @[required]
}

pub fn JpegFrameHeader.read(mut stream ReadStream) !JpegFrameHeader {
	segment_size := jpeg_u16(mut stream)!
	precision := stream.take_byte()!
	height := jpeg_u16(mut stream)!
	width := jpeg_u16(mut stream)!
	count := stream.take_byte()!
	if count != 1 && count != 3 { return error('InvalidData') }
	mut components := []JpegComponent{len: int(count)}
	for i in 0 .. int(count) {
		components[i] = JpegComponent.read(mut stream)!
	}
	if int(segment_size) != 8 + 3 * int(count) { panic('reached unreachable code') }
	return JpegFrameHeader{
		sample_precision: precision
		height:           height
		width:            width
		components:       components
	}
}

// GC owns the component allocation. Like Source, this cleanup hook does not
// replace the caller's header or its slice descriptor.
pub fn (mut header JpegFrameHeader) deinit() {}

pub fn (header JpegFrameHeader) max_horizontal_sampling_factor() uint {
	mut result := uint(0)
	for component in header.components {
		if result < uint(component.horizontal_sampling_factor) {
			result = uint(component.horizontal_sampling_factor)
		}
	}
	return result
}

pub fn (header JpegFrameHeader) max_vertical_sampling_factor() uint {
	mut result := uint(0)
	for component in header.components {
		if result < uint(component.vertical_sampling_factor) {
			result = uint(component.vertical_sampling_factor)
		}
	}
	return result
}

pub struct JpegQuantization8 {
pub mut:
	values [64]u8 @[required]
}

pub struct JpegQuantization16 {
pub mut:
	values [64]u16 @[required]
}

pub type JpegQuantizationTable = JpegQuantization8 | JpegQuantization16

pub fn JpegQuantizationTable.read(precision u8, mut stream ReadStream) !JpegQuantizationTable {
	match precision {
		0 {
			mut q8 := [64]u8{}
			for offset in 0 .. 64 {
				q8[jpeg_zigzag_offsets[offset]] = stream.take_byte()!
			}
			return JpegQuantization8{
				values: q8
			}
		}
		1 {
			mut q16 := [64]u16{}
			for offset in 0 .. 64 {
				q16[jpeg_zigzag_offsets[offset]] = jpeg_u16(mut stream)!
			}
			return JpegQuantization16{
				values: q16
			}
		}
		else {
			return error('InvalidData')
		}
	}
}

pub struct JpegQuantizationHeader {
pub mut:
	table_precision   u8                    @[required]
	table_destination u8                    @[required]
	table             JpegQuantizationTable @[required]
}

pub fn JpegQuantizationHeader.read(mut stream ReadStream) !JpegQuantizationHeader {
	jpeg_u16(mut stream)!
	precision_destination := stream.take_byte()!
	precision := precision_destination >> 4
	return JpegQuantizationHeader{
		table_precision:   precision
		table_destination: precision_destination & 3
		table:             JpegQuantizationTable.read(precision, mut stream)!
	}
}

pub enum JpegDensityUnit as u8 {
	pixels
	dots_per_inch
	dots_per_cm
}

pub struct JpegJfifHeader {
pub mut:
	jfif_revision u16             @[required]
	density_unit  JpegDensityUnit @[required]
	x_density     u16             @[required]
	y_density     u16             @[required]
}

pub fn JpegJfifHeader.read(mut stream ReadStream) !JpegJfifHeader {
	stream.seek_to(2)!
	if jpeg_u16(mut stream)! != 0xffe0 { return error('App0MarkerDoesNotExist') }
	jpeg_u16(mut stream)!
	if stream.take(4)! != 'JFIF'.bytes() { return error('JfifIdentifierNotSet') }
	stream.discard_all(1)!
	revision := jpeg_u16(mut stream)!
	density := stream.take_byte()!
	if density > 2 { panic('invalid enum value') }
	x_density := jpeg_u16(mut stream)!
	y_density := jpeg_u16(mut stream)!
	thumbnail_width := stream.take_byte()!
	thumbnail_height := stream.take_byte()!
	if thumbnail_width != 0 || thumbnail_height != 0 { return error('ThumbnailImagesUnsupported') }
	if jpeg_u16(mut stream)! & 0xfff0 == 0xffe0 { return error('ExtraneousApplicationMarker') }
	stream.seek_by(-2)!
	return JpegJfifHeader{
		jfif_revision: revision
		density_unit:  unsafe { JpegDensityUnit(density) }
		x_density:     x_density
		y_density:     y_density
	}
}
