module zigimg

import log

// The host logger handles routing and filtering. IFF/SGI payloads retain the
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
	log.debug('${bitmap}\n')
}
