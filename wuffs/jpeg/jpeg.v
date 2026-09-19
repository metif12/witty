module jpeg

import wuffs

// decode translates wuffs.jpeg.decode. Allocation is handled by V's GC.
pub fn decode(source []u8) !wuffs.ImageData {
	return wuffs.jpeg_decode(source)
}
