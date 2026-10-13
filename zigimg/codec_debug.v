module zigimg

import log

// The host logger handles routing and filtering. Codec payloads retain the
// pinned Zig formatter's anonymous-record syntax, field order and enum labels.
pub fn (header &BmhdHeader) debug() {
	log.debug(iff_bmhd_debug_message(header))
}

pub fn (header &DgblHeader) debug() {
	log.debug(iff_dgbl_debug_message(header))
}

fn iff_bmhd_debug_message(header &BmhdHeader) string {
	return '.{ .width = ${header.width}, .height = ${header.height}, .x = ${header.x}, .y = ${header.y}, .planes = ${header.planes}, .mask_type = .${header.mask_type}, .compression_type = .${header.compression_type}, .pad = ${header.pad}, .transparent_color = ${header.transparent_color}, .x_asoect = ${header.x_asoect}, .y_aspect = ${header.y_aspect}, .page_width = ${header.page_width}, .page_height = ${header.page_height} }'
}

fn iff_dgbl_debug_message(header &DgblHeader) string {
	return '.{ .width = ${header.width}, .height = ${header.height}, .compression_type = .${header.compression_type}, .x_aspect = ${header.x_aspect}, .y_aspect = ${header.y_aspect} }'
}

fn (header IffHeader) debug() {
	match header {
		BmhdHeader { header.debug() }
		DgblHeader { header.debug() }
	}
}

pub fn (header &SgiHeader) debug() {
	log.debug(sgi_debug_message(header))
}

fn sgi_debug_message(header &SgiHeader) string {
	name := sgi_debug_bytes(header.image_name[..])
	padding := sgi_debug_bytes(header.dummy2[..])
	return '.{ .compression = .${header.compression}, .bytes_per_channel = ${header.bytes_per_channel}, .dimension = .${header.dimension}, .x_size = ${header.x_size}, .y_size = ${header.y_size}, .z_size = ${header.z_size}, .pix_min = ${header.pix_min}, .pix_max = ${header.pix_max}, .dummy1 = ${header.dummy1}, .image_name = ${name}, .pixel_format = .${header.pixel_format}, .dummy2 = ${padding} }'
}

fn sgi_debug_bytes(bytes []u8) string {
	return '{ ' + bytes.map(it.str()).join(', ') + ' }'
}

pub fn (bitmap &TiffBitmapDescriptor) debug() {
	log.debug(tiff_debug_message(bitmap))
}

fn tiff_debug_message(bitmap &TiffBitmapDescriptor) string {
	offsets := tiff_debug_optional_words(bitmap.strip_offsets)
	counts := tiff_debug_optional_words(bitmap.strip_byte_counts)
	x := tiff_debug_u32_values(bitmap.x_resolution[..])
	y := tiff_debug_u32_values(bitmap.y_resolution[..])
	bits := '.{ .data = ' + tiff_debug_u16_values(bitmap.bits_per_sample.data) + ', .storage = ' +
		tiff_debug_u16_values(bitmap.bits_per_sample.storage[..]) + ' }'
	extra := '.{ .data = ' + tiff_debug_u16_values(bitmap.extra_samples.data) + ', .storage = ' +
		tiff_debug_u16_values(bitmap.extra_samples.storage[..]) + ' }'
	colors := '.{ .data = ' + tiff_debug_palette(bitmap.color_map.data.len) + ', .storage = ' +
		tiff_debug_palette(bitmap.color_map.storage.len) + ' }'
	return '.{ .compression = .${bitmap.compression}, .image_width = ${bitmap.image_width}, .image_height = ${bitmap.image_height}, .photometric_interpretation = ${bitmap.photometric_interpretation}, .rows_per_strip = ${bitmap.rows_per_strip}, .strip_offsets = ${offsets}, .strip_byte_counts = ${counts}, .x_resolution = ${x}, .y_resolution = ${y}, .resolution_unit = .${bitmap.resolution_unit}, .bits_per_sample = ${bits}, .new_subfile_type = ${bitmap.new_subfile_type}, .color_map = ${colors}, .samples_per_pixel = ${bitmap.samples_per_pixel}, .fill_order = ${bitmap.fill_order}, .extra_samples = ${extra}, .planar_configuration = ${bitmap.planar_configuration}, .predictor = ${bitmap.predictor} }\n'
}

fn tiff_debug_optional_words(value ?[]u32) string {
	if words := value { return tiff_debug_u32_values(words) }
	return 'null'
}

fn tiff_debug_u32_values(values []u32) string {
	return '{ ' + values.map(it.str()).join(', ') + ' }'
}

fn tiff_debug_u16_values(values []u16) string {
	return '{ ' + values.map(it.str()).join(', ') + ' }'
}

// At Zig's default depth of three, nested palette entries elide their fields.
fn tiff_debug_palette(count int) string {
	if count == 0 { return '{  }' }
	return '{ ' + '.{ ... }, '.repeat(count - 1) + '.{ ... } }'
}
