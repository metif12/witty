module zigimg

import log

// These source hooks use the host language's standard debug logger and generic
// struct rendering, as std.log.debug("{}", .{self}) does in the Zig package.
// Type names, enum names and struct presentation follow V's representation.
pub fn (header &BmhdHeader) debug() {
	log.debug('${header}')
}

pub fn (header &DgblHeader) debug() {
	log.debug('${header}')
}

fn (header IffHeader) debug() {
	match header {
		BmhdHeader { header.debug() }
		DgblHeader { header.debug() }
	}
}

pub fn (header &SgiHeader) debug() {
	log.debug('${header}')
}

pub fn (bitmap &TiffBitmapDescriptor) debug() {
	log.debug('${bitmap}\n')
}
